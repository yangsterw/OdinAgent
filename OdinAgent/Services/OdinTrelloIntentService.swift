import Foundation

enum OdinParsedTrelloIntent {
    case none
    case clarify(String)
    case showBoardsAndColumns
    case showTasks(listName: String, boardName: String?)
    case addTask(title: String, listName: String)
}

final class OdinTrelloIntentService {

    private struct TrelloIntentResponse: Decodable {
        let intent: String
        let title: String?
        let listName: String?
        let boardName: String?
        let question: String?
    }

    private let ollamaService = OdinOllamaService()

    func parse(
        _ command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) async -> OdinParsedTrelloIntent? {
        let prompt = buildPrompt(
            command: command,
            availableLists: availableLists,
            boardSummaries: boardSummaries,
            defaultListName: defaultListName
        )

        do {
            let response = try await ollamaService.generateResponse(for: prompt)
            let jsonText = extractJSONObject(from: response)

            guard let jsonData = jsonText.data(using: .utf8) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(
                TrelloIntentResponse.self,
                from: jsonData
            )

            return map(
                decoded,
                availableLists: availableLists,
                boardSummaries: boardSummaries,
                defaultListName: defaultListName
            )

        } catch {
            print("Trello intent parse error:", error)
            return nil
        }
    }

    private func buildPrompt(
        command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) -> String {
        let availableListLines = availableLists
            .map { "- \($0.name)" }
            .joined(separator: "\n")

        let boardLines = boardSummaries
            .map { summary in
                let columns = summary.lists
                    .map(\.name)
                    .joined(separator: ", ")

                return "- \(summary.board.name): \(columns)"
            }
            .joined(separator: "\n")

        return """
        You classify only Trello task commands for a macOS assistant named Odin.
        Return only one JSON object. Do not use markdown.

        Available Trello boards and columns:
        \(boardLines)

        Allowed Trello lists:
        \(availableListLines)

        JSON shapes:
        {"intent":"none"}
        {"intent":"clarify","question":"What should I name the Trello task?"}
        {"intent":"show_boards_and_columns"}
        {"intent":"show_tasks","listName":"In Progress","boardName":"Work Board"}
        {"intent":"add_task","title":"Review pull request","listName":"\(defaultListName)"}

        Rules:
        - Only classify Trello requests.
        - If the user is not asking about Trello boards, columns, tasks, cards, or card creation, return {"intent":"none"}.
        - If the user asks what Trello boards, columns, lists, or statuses they have, return show_boards_and_columns.
        - If the user asks what tasks/cards are in a specific Trello column/list, return show_tasks.
        - For show_tasks, listName must be exactly one of the shown column names.
        - For show_tasks, include boardName only when the user names a board.
        - If the task title is missing or unclear, return clarify with a short question.
        - If the Trello list is missing, use "\(defaultListName)".
        - The listName must be exactly one of the allowed Trello lists.
        - Match the user's wording to the closest allowed list name.
        - Prefer exact list names when the user names a board column.
        - If the command includes "Previous incomplete Trello command" and "User follow-up", combine them into one Trello request.

        Examples:
        User: add follow up with Alex to Trello
        {"intent":"add_task","title":"Follow up with Alex","listName":"\(defaultListName)"}

        User: what Trello boards and columns do I have
        {"intent":"show_boards_and_columns"}

        User: what is in the in progress column
        {"intent":"show_tasks","listName":"In Progress","boardName":null}

        User: what cards are in QA on Work Board
        {"intent":"show_tasks","listName":"QA","boardName":"Work Board"}

        User: put fix login bug in the in progress column
        {"intent":"add_task","title":"Fix login bug","listName":"In Progress"}

        User: add a card for researching pricing to upcoming priorities
        {"intent":"add_task","title":"Research pricing","listName":"Upcoming Priorities"}

        User: add waiting on API credentials to blocked
        {"intent":"add_task","title":"Waiting on API credentials","listName":"Blocked"}

        User: add a Trello task
        {"intent":"clarify","question":"What should I name the Trello task?"}

        User: Previous incomplete Trello command: add a Trello task
        User follow-up: Fix the login bug
        {"intent":"add_task","title":"Fix the login bug","listName":"\(defaultListName)"}

        User command:
        \(command)
        """
    }

    private func map(
        _ response: TrelloIntentResponse,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) -> OdinParsedTrelloIntent {
        switch response.intent {
        case "none":
            return .none

        case "show_boards_and_columns":
            return .showBoardsAndColumns

        case "show_tasks":
            guard let requestedListName = response.listName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !requestedListName.isEmpty else {
                return .clarify("Which Trello column should I check?")
            }

            let boardName = matchBoardName(
                response.boardName,
                boardSummaries: boardSummaries
            )

            let listName = matchListName(
                requestedListName,
                availableLists: boardSummaries.flatMap(\.lists)
            ) ?? requestedListName

            return .showTasks(
                listName: listName,
                boardName: boardName
            )

        case "clarify":
            let question = response.question?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return .clarify(
                question?.isEmpty == false
                    ? question!
                    : "What should I name the Trello task?"
            )

        case "add_task":
            guard let title = response.title?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else {
                return .clarify("What should I name the Trello task?")
            }

            let requestedListName = response.listName?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let listName = matchListName(
                requestedListName,
                availableLists: availableLists
            ) ?? defaultListName

            return .addTask(title: title, listName: listName)

        default:
            return .none
        }
    }

    private func matchListName(
        _ requestedListName: String?,
        availableLists: [OdinTrelloList]
    ) -> String? {
        guard let requestedListName,
              !requestedListName.isEmpty else {
            return nil
        }

        return availableLists.first {
            normalize($0.name) == normalize(requestedListName)
        }?.name
    }

    private func matchBoardName(
        _ requestedBoardName: String?,
        boardSummaries: [OdinTrelloBoardSummary]
    ) -> String? {
        guard let requestedBoardName,
              !requestedBoardName.isEmpty else {
            return nil
        }

        return boardSummaries.first {
            normalize($0.board.name) == normalize(requestedBoardName)
        }?.board.name
    }

    private func extractJSONObject(from response: String) -> String {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}"),
              start <= end else {
            return response
        }

        return String(response[start...end])
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
