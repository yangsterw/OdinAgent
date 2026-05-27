import Foundation

enum OdinParsedTrelloIntent {
    case none
    case clarify(String)
    case addTask(title: String, listName: String)
}

final class OdinTrelloIntentService {

    private struct TrelloIntentResponse: Decodable {
        let intent: String
        let title: String?
        let listName: String?
        let question: String?
    }

    private enum TrelloList {
        static let today = "today's highest priority"
        static let inProgress = "in progress"
        static let upcoming = "upcoming priorities"
        static let future = "future consideration"
        static let blocked = "blocked"

        static let all = [
            today,
            inProgress,
            upcoming,
            future,
            blocked
        ]
    }

    private let ollamaService = OdinOllamaService()

    func parse(_ command: String) async -> OdinParsedTrelloIntent? {
        let prompt = buildPrompt(command: command)

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

            return map(decoded)

        } catch {
            print("Trello intent parse error:", error)
            return nil
        }
    }

    private func buildPrompt(command: String) -> String {
        """
        You classify only Trello task commands for a macOS assistant named Odin.
        Return only one JSON object. Do not use markdown.

        Allowed Trello lists:
        - \(TrelloList.today)
        - \(TrelloList.inProgress)
        - \(TrelloList.upcoming)
        - \(TrelloList.future)
        - \(TrelloList.blocked)

        JSON shapes:
        {"intent":"none"}
        {"intent":"clarify","question":"What should I name the Trello task?"}
        {"intent":"add_task","title":"Review pull request","listName":"today's highest priority"}

        Rules:
        - Only classify requests to add/create/put a task, card, todo, or reminder-like work item in Trello.
        - If the user is not asking to create a Trello task/card, return {"intent":"none"}.
        - If the task title is missing or unclear, return clarify with a short question.
        - If the Trello list is missing, use "\(TrelloList.today)".
        - The listName must be exactly one of the allowed Trello lists.
        - Map urgent, highest priority, priority, today, and important to "\(TrelloList.today)".
        - Map doing, working on, started, active, and currently working to "\(TrelloList.inProgress)".
        - Map later, upcoming, soon, next, backlog, and planned to "\(TrelloList.upcoming)".
        - Map someday, idea, maybe, and future to "\(TrelloList.future)".
        - Map blocked, stuck, waiting, and cannot move to "\(TrelloList.blocked)".

        Examples:
        User: add follow up with Alex to Trello
        {"intent":"add_task","title":"Follow up with Alex","listName":"today's highest priority"}

        User: put fix login bug in progress
        {"intent":"add_task","title":"Fix login bug","listName":"in progress"}

        User: add a card for researching pricing later
        {"intent":"add_task","title":"Research pricing","listName":"upcoming priorities"}

        User: add blocked task waiting on API credentials
        {"intent":"add_task","title":"Waiting on API credentials","listName":"blocked"}

        User: add a Trello task
        {"intent":"clarify","question":"What should I name the Trello task?"}

        User command:
        \(command)
        """
    }

    private func map(_ response: TrelloIntentResponse) -> OdinParsedTrelloIntent {
        switch response.intent {
        case "none":
            return .none

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

            let requestedList = response.listName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let listName = TrelloList.all.first {
                $0.lowercased() == requestedList
            } ?? TrelloList.today

            return .addTask(title: title, listName: listName)

        default:
            return .none
        }
    }

    private func extractJSONObject(from response: String) -> String {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}"),
              start <= end else {
            return response
        }

        return String(response[start...end])
    }
}
