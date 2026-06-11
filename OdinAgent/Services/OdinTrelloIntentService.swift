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

    private let ollamaService: any OdinLanguageModelServicing
    private let promptBuilder: any OdinTrelloIntentPromptBuilding
    private let defaultRuleBasedListName = "today's highest priority"

    init(
        ollamaService: any OdinLanguageModelServicing = OdinOllamaService(),
        promptBuilder: any OdinTrelloIntentPromptBuilding =
            OdinTrelloIntentPromptBuilder()
    ) {
        self.ollamaService = ollamaService
        self.promptBuilder = promptBuilder
    }

    private let listAliases: [String: String] = [
        "today's highest priority": "today's highest priority",
        "todays highest priority": "today's highest priority",
        "today highest priority": "today's highest priority",
        "highest priority": "today's highest priority",
        "in progress": "in progress",
        "upcoming priorities": "upcoming priorities",
        "upcoming priority": "upcoming priorities",
        "upcoming": "upcoming priorities",
        "future consideration": "future consideration",
        "future": "future consideration",
        "blocked": "blocked"
    ]

    private let createTaskPhrases = [
        "add a trello task",
        "add trello task",
        "add a task",
        "add task",
        "create a trello task",
        "create trello task",
        "create a task",
        "create task",
        "make a trello task",
        "make trello task",
        "make a task",
        "make task",
        "add a trello card",
        "add trello card",
        "add a card",
        "add card",
        "create a trello card",
        "create trello card",
        "create a card",
        "create card"
    ]

    private let titleMarkers = [
        "that i need to",
        "that i should",
        "that i am",
        "that i'm",
        "that im",
        "the task is",
        "task is",
        "called",
        "named",
        "to do",
        "todo",
        "about",
        "for",
        "that"
    ]

    private let titleTrimCharacters =
        CharacterSet(charactersIn: "\"'.,!? \n\t")

    func parseRuleBased(_ command: String) -> OdinParsedTrelloIntent? {
        let lower = command.lowercased()

        guard isCreateTaskCommand(lower) else {
            return nil
        }

        if let followUpTitle = extractUserFollowUp(from: command) {
            return .addTask(
                title: followUpTitle.title,
                listName: followUpTitle.listName ?? defaultRuleBasedListName
            )
        }

        guard let rawTitle = extractTaskTitle(from: command) else {
            return nil
        }

        let parsedTitle = cleanTaskTitle(rawTitle)

        guard !parsedTitle.title.isEmpty else {
            return nil
        }

        return .addTask(
            title: parsedTitle.title,
            listName: parsedTitle.listName ?? defaultRuleBasedListName
        )
    }

    private func isCreateTaskCommand(_ lower: String) -> Bool {
        createTaskPhrases.contains { lower.contains($0) }
    }

    private func extractUserFollowUp(
        from command: String
    ) -> (title: String, listName: String?)? {
        guard let range = command.range(
            of: "User follow-up:",
            options: .caseInsensitive
        ) else {
            return nil
        }

        let previousCommandContext = String(command[..<range.lowerBound])
        let contextListName = recognizedListNameAtEnd(
            of: previousCommandContext
        )
        let followUp = String(command[range.upperBound...])
        let parsedTitle = cleanTaskTitle(followUp)

        guard !parsedTitle.title.isEmpty else {
            return nil
        }

        return (
            title: parsedTitle.title,
            listName: parsedTitle.listName ?? contextListName
        )
    }

    private func extractTaskTitle(from command: String) -> String? {
        for marker in titleMarkers {
            if let range = command.range(of: marker, options: .caseInsensitive) {
                return String(command[range.upperBound...])
            }
        }

        for phrase in createTaskPhrases.sorted(by: { $0.count > $1.count }) {
            if let range = command.range(of: phrase, options: .caseInsensitive) {
                return String(command[range.upperBound...])
            }
        }

        return nil
    }

    private func cleanTaskTitle(
        _ rawTitle: String
    ) -> (title: String, listName: String?) {
        let trimmedTitle = rawTitle.trimmingCharacters(in: titleTrimCharacters)
        let titleWithoutLeadingFillers =
            removeLeadingTaskFillers(from: trimmedTitle)
        let titleWithList = removeRecognizedListSuffix(
            from: titleWithoutLeadingFillers
        )

        return (
            title: titleWithList.title.trimmingCharacters(
                in: titleTrimCharacters
            ),
            listName: titleWithList.listName
        )
    }

    private func removeLeadingTaskFillers(from title: String) -> String {
        var cleanedTitle = title

        let leadingFillers = [
            "that i need to ",
            "that i should ",
            "that i am ",
            "that i'm ",
            "that im ",
            "that ",
            "i need to ",
            "i should ",
            "i am ",
            "i'm ",
            "im ",
            "to "
        ]

        for filler in leadingFillers {
            if cleanedTitle.range(
                of: filler,
                options: [.caseInsensitive, .anchored]
            ) != nil {
                cleanedTitle.removeFirst(filler.count)
                return cleanedTitle
            }
        }

        return cleanedTitle
    }

    private func removeRecognizedListSuffix(
        from title: String
    ) -> (title: String, listName: String?) {
        let sortedAliases = listAliases.keys.sorted { $0.count > $1.count }

        for alias in sortedAliases {
            guard let listName = listAliases[alias] else {
                continue
            }

            for suffix in listSuffixes(for: alias) {
                guard let range = title.range(
                    of: suffix,
                    options: [.caseInsensitive, .backwards]
                ) else {
                    continue
                }

                let trailingText = title[range.upperBound...]
                    .trimmingCharacters(in: titleTrimCharacters)

                guard trailingText.isEmpty else {
                    continue
                }

                let titleWithoutSuffix = String(title[..<range.lowerBound])
                    .trimmingCharacters(in: titleTrimCharacters)

                guard !titleWithoutSuffix.isEmpty else {
                    continue
                }

                return (title: titleWithoutSuffix, listName: listName)
            }
        }

        return (title: title, listName: nil)
    }

    private func recognizedListNameAtEnd(of text: String) -> String? {
        let sortedAliases = listAliases.keys.sorted { $0.count > $1.count }

        for alias in sortedAliases {
            guard let listName = listAliases[alias] else {
                continue
            }

            for suffix in listSuffixes(for: alias) {
                guard let range = text.range(
                    of: suffix,
                    options: [.caseInsensitive, .backwards]
                ) else {
                    continue
                }

                let trailingText = text[range.upperBound...]
                    .trimmingCharacters(in: titleTrimCharacters)

                if trailingText.isEmpty {
                    return listName
                }
            }
        }

        return nil
    }

    private func listSuffixes(for alias: String) -> [String] {
        let connectors = [
            "to",
            "in",
            "on",
            "into",
            "under"
        ]

        let targets = [
            alias,
            "the \(alias)",
            "\(alias) column",
            "the \(alias) column",
            "\(alias) list",
            "the \(alias) list"
        ]

        return connectors.flatMap { connector in
            targets.map { target in
                " \(connector) \(target)"
            }
        }
    }

    func parse(
        _ command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String,
        modelName: String = OdinOllamaService.preferredModelName
    ) async -> OdinParsedTrelloIntent? {
        let prompt = promptBuilder.buildPrompt(
            command: command,
            availableLists: availableLists,
            boardSummaries: boardSummaries,
            defaultListName: defaultListName
        )

        do {
            let response = try await ollamaService.generateResponse(
                for: prompt,
                modelName: modelName
            )
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
