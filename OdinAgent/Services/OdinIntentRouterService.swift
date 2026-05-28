import Foundation

protocol OdinTrelloRoutingDataSource {
    var defaultListName: String { get }

    func availableLists() async -> [OdinTrelloList]
    func boardSummaries() async -> [OdinTrelloBoardSummary]
}

protocol OdinTrelloIntentParsing {
    func parseRuleBased(_ command: String) -> OdinParsedTrelloIntent?

    func parse(
        _ command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) async -> OdinParsedTrelloIntent?
}

protocol OdinCalendarIntentParsing {
    func parseRuleBased(_ command: String) -> OdinParsedCalendarIntent?
    func parse(_ command: String) async -> OdinParsedCalendarIntent?
}

enum OdinAppIntent {
    case open(appName: String, spokenName: String)
    case quit(appName: String, spokenName: String)
    case quitOdin
}

enum OdinRoutedIntent {
    case none
    case app(OdinAppIntent)
    case calendar(OdinParsedCalendarIntent, originalCommand: String)
    case trello(OdinParsedTrelloIntent, originalCommand: String)
}

final class OdinIntentRouterService {

    private let trelloService: any OdinTrelloRoutingDataSource
    private let trelloIntentService: any OdinTrelloIntentParsing
    private let calendarIntentService: any OdinCalendarIntentParsing

    init(
        trelloService: any OdinTrelloRoutingDataSource,
        trelloIntentService: any OdinTrelloIntentParsing,
        calendarIntentService: any OdinCalendarIntentParsing
    ) {
        self.trelloService = trelloService
        self.trelloIntentService = trelloIntentService
        self.calendarIntentService = calendarIntentService
    }

    func route(_ command: String) async -> OdinRoutedIntent {
        let lower = command.lowercased()

        if let appIntent = routeAppCommand(lower) {
            return .app(appIntent)
        }

        if let ruleBasedTrelloIntent = trelloIntentService.parseRuleBased(command) {
            return .trello(ruleBasedTrelloIntent, originalCommand: command)
        }

        if let ruleBasedCalendarIntent = calendarIntentService.parseRuleBased(command) {
            return .calendar(ruleBasedCalendarIntent, originalCommand: command)
        }

        if await shouldTryTrelloIntentParser(lower),
           let intent = await parseTrelloIntent(command),
           !intent.isNone {
            return .trello(intent, originalCommand: command)
        }

        if shouldTryCalendarIntentParser(lower),
           let intent = await calendarIntentService.parse(command),
           !intent.isNone {
            return .calendar(intent, originalCommand: command)
        }

        return .none
    }

    private func parseTrelloIntent(_ command: String) async -> OdinParsedTrelloIntent? {
        let availableLists = await trelloService.availableLists()
        let boardSummaries = await trelloService.boardSummaries()

        return await trelloIntentService.parse(
            command,
            availableLists: availableLists,
            boardSummaries: boardSummaries,
            defaultListName: trelloService.defaultListName
        )
    }

    private func routeAppCommand(_ lower: String) -> OdinAppIntent? {
        if lower.contains("quit odin") ||
            lower.contains("close odin") ||
            lower.contains("exit odin") {
            return .quitOdin
        }

        let appAliases: [(open: [String], quit: [String], appName: String, spokenName: String)] = [
            (
                open: ["open spotify"],
                quit: ["quit spotify", "close spotify"],
                appName: "Spotify",
                spokenName: "Spotify"
            ),
            (
                open: ["open safari"],
                quit: ["quit safari", "close safari"],
                appName: "Safari",
                spokenName: "Safari"
            ),
            (
                open: ["open xcode"],
                quit: ["quit xcode", "close xcode"],
                appName: "Xcode",
                spokenName: "Xcode"
            ),
            (
                open: ["open visual studio code", "open vscode", "open vs code"],
                quit: [
                    "quit visual studio code",
                    "close visual studio code",
                    "quit vscode",
                    "close vscode",
                    "quit vs code",
                    "close vs code"
                ],
                appName: "Visual Studio Code",
                spokenName: "Visual Studio Code"
            ),
            (
                open: ["open terminal"],
                quit: ["quit terminal", "close terminal"],
                appName: "Terminal",
                spokenName: "Terminal"
            ),
            (
                open: ["open outlook", "open email"],
                quit: ["quit outlook", "close outlook", "quit email", "close email"],
                appName: "Microsoft Outlook",
                spokenName: "Outlook"
            )
        ]

        for alias in appAliases {
            if alias.open.contains(where: { lower.contains($0) }) {
                return .open(appName: alias.appName, spokenName: alias.spokenName)
            }

            if alias.quit.contains(where: { lower.contains($0) }) {
                return .quit(appName: alias.appName, spokenName: alias.spokenName)
            }
        }

        return nil
    }

    private func shouldTryTrelloIntentParser(_ lower: String) async -> Bool {
        let trelloSignals = [
            "trello",
            "task",
            "tasks",
            "card",
            "cards",
            "todo",
            "to do",
            "highest priority",
            "priority",
            "in progress",
            "upcoming",
            "future consideration",
            "blocked"
        ]

        let createSignals = [
            "add",
            "create",
            "put",
            "make",
            "remember"
        ]

        let readSignals = [
            "what",
            "which",
            "show",
            "list",
            "tell me",
            "do i have",
            "what's",
            "whats"
        ]

        let hasCreateSignal = createSignals.contains { lower.contains($0) }
        let hasReadSignal = readSignals.contains { lower.contains($0) }

        if trelloSignals.contains(where: { lower.contains($0) }) &&
            (hasCreateSignal || hasReadSignal) {
            return true
        }

        guard hasCreateSignal || hasReadSignal else {
            return false
        }

        let normalizedCommand = normalize(lower)
        let boardSummaries = await trelloService.boardSummaries()
        let liveListNames = boardSummaries
            .flatMap(\.lists)
            .map { normalize($0.name) }
        let liveBoardNames = boardSummaries
            .map { normalize($0.board.name) }

        return liveListNames.contains { listName in
            !listName.isEmpty && normalizedCommand.contains(listName)
        } || liveBoardNames.contains { boardName in
            !boardName.isEmpty && normalizedCommand.contains(boardName)
        }
    }

    private func shouldTryCalendarIntentParser(_ lower: String) -> Bool {
        let calendarSignals = [
            "calendar",
            "schedule",
            "agenda",
            "meeting",
            "meetings",
            "appointment",
            "appointments",
            "busy",
            "free",
            "available",
            "availability",
            "coming up",
            "this week",
            "next week",
            "next few weeks",
            "week looking",
            "my week",
            "tomorrow",
            "today"
        ]

        return calendarSignals.contains { lower.contains($0) }
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

extension OdinTrelloService: OdinTrelloRoutingDataSource {}
extension OdinTrelloIntentService: OdinTrelloIntentParsing {}
extension OdinCalendarIntentService: OdinCalendarIntentParsing {}

private extension OdinParsedCalendarIntent {
    var isNone: Bool {
        if case .none = self {
            return true
        }

        return false
    }
}

private extension OdinParsedTrelloIntent {
    var isNone: Bool {
        if case .none = self {
            return true
        }

        return false
    }
}
