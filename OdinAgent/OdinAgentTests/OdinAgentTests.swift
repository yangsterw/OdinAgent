//
//  OdinAgentTests.swift
//  OdinAgentTests
//
//  Created by yang on 5/19/26.
//

import Testing
@testable import OdinAgent

struct OdinAgentTests {

    @Test func routesAppOpenCommand() async throws {
        let router = makeRouter()

        let intent = await router.route("open Spotify")

        guard case .app(.open(let appName, let spokenName)) = intent else {
            Issue.record("Expected app open intent.")
            return
        }

        #expect(appName == "Spotify")
        #expect(spokenName == "Spotify")
    }

    @Test func routesAppQuitAliasCommand() async throws {
        let router = makeRouter()

        let intent = await router.route("close vs code")

        guard case .app(.quit(let appName, let spokenName)) = intent else {
            Issue.record("Expected app quit intent.")
            return
        }

        #expect(appName == "Visual Studio Code")
        #expect(spokenName == "Visual Studio Code")
    }

    @Test func routesCalendarRuleBasedIntentBeforeLLMParser() async throws {
        let calendarParser = StubCalendarIntentParser(
            ruleBasedIntent: .read(.thisWeek),
            llmIntent: nil
        )
        let router = makeRouter(calendarIntentService: calendarParser)

        let intent = await router.route("what is happening this week")

        guard case .calendar(.read(.thisWeek), let originalCommand) = intent else {
            Issue.record("Expected this-week calendar read intent.")
            return
        }

        #expect(originalCommand == "what is happening this week")
        #expect(calendarParser.llmParseCallCount == 0)
    }

    @Test func routesTrelloRuleBasedIntentBeforeLLMParser() async throws {
        let trelloParser = StubTrelloIntentParser(
            ruleBasedIntent: .addTask(
                title: "Review logs",
                listName: "blocked"
            ),
            llmIntent: nil
        )
        let router = makeRouter(trelloIntentService: trelloParser)

        let intent = await router.route("add a task called Review logs to blocked")

        guard case .trello(.addTask(let title, let listName), let originalCommand) = intent else {
            Issue.record("Expected Trello add-task intent.")
            return
        }

        #expect(title == "Review logs")
        #expect(listName == "blocked")
        #expect(originalCommand == "add a task called Review logs to blocked")
        #expect(trelloParser.llmParseCallCount == 0)
    }

    @Test func routesTrelloLLMIntentWithBoardContext() async throws {
        let board = OdinTrelloBoard(id: "board-1", name: "Work")
        let list = OdinTrelloList(
            id: "list-1",
            name: "QA",
            boardID: "board-1",
            boardName: "Work"
        )
        let trelloService = StubTrelloRoutingDataSource(
            availableLists: [list],
            boardSummaries: [
                OdinTrelloBoardSummary(
                    board: board,
                    lists: [list]
                )
            ]
        )
        let trelloParser = StubTrelloIntentParser(
            ruleBasedIntent: nil,
            llmIntent: .showTasks(
                listName: "QA",
                boardName: "Work"
            )
        )
        let router = makeRouter(
            trelloService: trelloService,
            trelloIntentService: trelloParser
        )

        let intent = await router.route("what cards are in QA on Work")

        guard case .trello(.showTasks(let listName, let boardName), _) = intent else {
            Issue.record("Expected Trello show-tasks intent.")
            return
        }

        #expect(listName == "QA")
        #expect(boardName == "Work")
        #expect(trelloService.availableListsCallCount == 1)
        #expect(trelloService.boardSummariesCallCount == 1)
        #expect(trelloParser.llmParseCallCount == 1)
    }

    @Test func routesUnknownCommandToNone() async throws {
        let router = makeRouter()

        let intent = await router.route("tell me a joke")

        guard case .none = intent else {
            Issue.record("Expected no routed intent.")
            return
        }
    }

    private func makeRouter(
        trelloService: StubTrelloRoutingDataSource = StubTrelloRoutingDataSource(),
        trelloIntentService: StubTrelloIntentParser = StubTrelloIntentParser(),
        calendarIntentService: StubCalendarIntentParser = StubCalendarIntentParser()
    ) -> OdinIntentRouterService {
        OdinIntentRouterService(
            trelloService: trelloService,
            trelloIntentService: trelloIntentService,
            calendarIntentService: calendarIntentService
        )
    }
}

private final class StubTrelloRoutingDataSource: OdinTrelloRoutingDataSource {
    let defaultListName = "today's highest priority"
    private let availableListsResult: [OdinTrelloList]
    private let boardSummariesResult: [OdinTrelloBoardSummary]
    private(set) var availableListsCallCount = 0
    private(set) var boardSummariesCallCount = 0

    init(
        availableLists: [OdinTrelloList] = [],
        boardSummaries: [OdinTrelloBoardSummary] = []
    ) {
        availableListsResult = availableLists
        boardSummariesResult = boardSummaries
    }

    func availableLists() async -> [OdinTrelloList] {
        availableListsCallCount += 1
        return availableListsResult
    }

    func boardSummaries() async -> [OdinTrelloBoardSummary] {
        boardSummariesCallCount += 1
        return boardSummariesResult
    }
}

private final class StubTrelloIntentParser: OdinTrelloIntentParsing {
    private let ruleBasedIntent: OdinParsedTrelloIntent?
    private let llmIntent: OdinParsedTrelloIntent?
    private(set) var llmParseCallCount = 0

    init(
        ruleBasedIntent: OdinParsedTrelloIntent? = nil,
        llmIntent: OdinParsedTrelloIntent? = nil
    ) {
        self.ruleBasedIntent = ruleBasedIntent
        self.llmIntent = llmIntent
    }

    func parseRuleBased(_ command: String) -> OdinParsedTrelloIntent? {
        ruleBasedIntent
    }

    func parse(
        _ command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) async -> OdinParsedTrelloIntent? {
        llmParseCallCount += 1
        return llmIntent
    }
}

private final class StubCalendarIntentParser: OdinCalendarIntentParsing {
    private let ruleBasedIntent: OdinParsedCalendarIntent?
    private let llmIntent: OdinParsedCalendarIntent?
    private(set) var llmParseCallCount = 0

    init(
        ruleBasedIntent: OdinParsedCalendarIntent? = nil,
        llmIntent: OdinParsedCalendarIntent? = nil
    ) {
        self.ruleBasedIntent = ruleBasedIntent
        self.llmIntent = llmIntent
    }

    func parseRuleBased(_ command: String) -> OdinParsedCalendarIntent? {
        ruleBasedIntent
    }

    func parse(_ command: String) async -> OdinParsedCalendarIntent? {
        llmParseCallCount += 1
        return llmIntent
    }
}
