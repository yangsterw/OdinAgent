import Foundation
import Testing
@testable import OdinAgent

struct OdinMaintainabilityTests {

    @Test func brainPromptBuilderIncludesInjectedContext() {
        let prompt = OdinBrainPromptBuilder().buildPrompt(
            command: "what should I do next",
            promptMemory: "User likes focused work.",
            recentConversation: "User: hello\nOdin: awoo"
        )

        #expect(prompt.contains("what should I do next"))
        #expect(prompt.contains("User likes focused work."))
        #expect(prompt.contains("User: hello\nOdin: awoo"))
    }

    @Test func trelloPromptBuilderIncludesLiveBoardContext() {
        let prompt = OdinTrelloIntentPromptBuilder().buildPrompt(
            command: "what cards are in QA on Work",
            availableLists: [
                OdinTrelloList(
                    id: "list-1",
                    name: "QA",
                    boardID: "board-1",
                    boardName: "Work"
                )
            ],
            boardSummaries: [
                OdinTrelloBoardSummary(
                    board: OdinTrelloBoard(id: "board-1", name: "Work"),
                    lists: [
                        OdinTrelloList(
                            id: "list-1",
                            name: "QA",
                            boardID: "board-1",
                            boardName: "Work"
                        )
                    ]
                )
            ],
            defaultListName: "today"
        )

        #expect(prompt.contains("- Work: QA"))
        #expect(prompt.contains("- QA"))
        #expect(prompt.contains("what cards are in QA on Work"))
    }

    @Test func calendarPromptBuilderUsesProvidedDate() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let now = formatter.date(from: "2026-05-27 10:15")!

        let prompt = OdinCalendarIntentPromptBuilder().buildPrompt(
            command: "schedule planning tomorrow at 3 pm",
            now: now
        )

        #expect(prompt.contains("Current local date and time: 2026-05-27 10:15"))
        #expect(prompt.contains("schedule planning tomorrow at 3 pm"))
    }

    @Test func brainRecordsBuiltInResponseWithoutCallingLLM() async throws {
        let memory = RecordingMemoryService()
        let conversation = RecordingConversationService()
        let languageModel = RecordingLanguageModel(streamResponse: "unused")
        let brain = OdinBrainService(
            ollamaService: languageModel,
            memoryService: memory,
            commandService: StaticCommandHandler(response: nil),
            conversationService: conversation
        )

        let response = await brain.respond(
            to: "good boy",
            modelName: "test-model",
            onPartialResponse: { _ in }
        )

        #expect(response == "Awoo! Thank you. I am a very good boy.")
        #expect(await memory.savedCount() == 1)
        #expect(await languageModel.streamCallCount() == 0)
    }

    @Test func brainRecordsCommandServiceResponseWithoutCallingLLM() async throws {
        let memory = RecordingMemoryService()
        let languageModel = RecordingLanguageModel(streamResponse: "unused")
        let brain = OdinBrainService(
            ollamaService: languageModel,
            memoryService: memory,
            commandService: StaticCommandHandler(response: "Done."),
            conversationService: RecordingConversationService()
        )

        let response = await brain.respond(
            to: "add a task",
            modelName: "test-model",
            onPartialResponse: { _ in }
        )

        #expect(response == "Done.")
        #expect(await memory.savedCount() == 1)
        #expect(await languageModel.streamCallCount() == 0)
    }

    @Test func commandServiceConfirmsPendingCalendarCreate() async throws {
        let startDate = Date(timeIntervalSince1970: 1_800)
        let pendingActions = TestPendingActionService(
            action: .calendarCreateConfirmation(
                title: "Planning",
                startDate: startDate,
                duration: 30 * 60,
                createdAt: Date()
            )
        )
        let calendarService = TestCalendarService(
            addEventResponse: "I added Planning."
        )
        let commandService = OdinCommandService(
            trelloService: TestTrelloManager(),
            calendarService: calendarService,
            calendarIntentService: TestCalendarIntentParser(),
            pendingActionService: pendingActions,
            intentRouterService: StaticIntentRouter(intent: .none)
        )

        let response = await commandService.handle(
            "yes",
            modelName: "test-model"
        )

        #expect(response == "I added Planning.")
        #expect(pendingActions.current() == nil)
        #expect(await calendarService.addEventCallCount() == 1)
    }

    @Test func trelloRepositoryResolvesListOnNamedBoard() async throws {
        let config = OdinTrelloConfiguration(
            apiBaseURL: URL(string: "https://example.test/1")!,
            apiKey: "key",
            token: "token",
            listCacheDuration: 600,
            defaultListName: "today",
            listIDs: ["today": "list-default"]
        )
        let client = TestTrelloClient(
            boards: [
                OdinTrelloBoard(id: "board-1", name: "Work")
            ],
            listsByBoardID: [
                "board-1": [
                    OdinTrelloList(
                        id: "list-qa",
                        name: "QA",
                        boardID: "board-1",
                        boardName: "Work"
                    )
                ]
            ]
        )
        let repository = OdinTrelloRepository(
            configuration: config,
            client: client
        )

        let list = await repository.resolveList(
            named: "qa",
            onBoard: "work"
        )

        #expect(list?.id == "list-qa")
        #expect(client.openListsCalls == 2)
    }
}

private actor RecordingMemoryService: OdinMemoryManaging {
    private var savedInteractions: [(user: String, odin: String)] = []
    private var memory = ""
    private(set) var didClear = false

    func loadMemory() async -> String {
        memory
    }

    func saveInteraction(user: String, odin: String) async {
        savedInteractions.append((user: user, odin: odin))
    }

    func clearMemory() async {
        didClear = true
        memory = ""
    }

    func savedCount() -> Int {
        savedInteractions.count
    }
}

private actor RecordingConversationService: OdinConversationManaging {
    private var messages: [String] = []

    func addUserMessage(_ text: String) async {
        messages.append("User: \(text)")
    }

    func addOdinMessage(_ text: String) async {
        messages.append("Odin: \(text)")
    }

    func contextText() async -> String {
        messages.joined(separator: "\n")
    }

    func clear() async {
        messages.removeAll()
    }
}

private actor RecordingLanguageModel: OdinLanguageModelServicing {
    private let streamResponseText: String
    private var streamCalls = 0
    private var generateCalls = 0

    init(streamResponse: String) {
        streamResponseText = streamResponse
    }

    func generateResponse(
        for prompt: String,
        modelName: String
    ) async throws -> String {
        generateCalls += 1
        return streamResponseText
    }

    func streamResponse(
        for prompt: String,
        modelName: String,
        onPartialResponse: @escaping (String) async -> Void
    ) async throws -> String {
        streamCalls += 1
        await onPartialResponse(streamResponseText)
        return streamResponseText
    }

    func availableModels() async throws -> [OdinOllamaService.OllamaModel] {
        []
    }

    func streamCallCount() -> Int {
        streamCalls
    }
}

private final class StaticCommandHandler: OdinCommandHandling {
    private let response: String?

    init(response: String?) {
        self.response = response
    }

    func handle(
        _ command: String,
        modelName: String
    ) async -> String? {
        response
    }
}

private final class TestPendingActionService: OdinPendingActionManaging {
    private var action: OdinPendingAction?

    init(action: OdinPendingAction?) {
        self.action = action
    }

    func set(_ action: OdinPendingAction) {
        self.action = action
    }

    func clear() {
        action = nil
    }

    func current() -> OdinPendingAction? {
        action
    }
}

private actor TestCalendarService: OdinCalendarManaging {
    private let addEventResponse: String
    private var addEventCalls = 0

    init(addEventResponse: String) {
        self.addEventResponse = addEventResponse
    }

    func todaysSchedule() async -> String {
        ""
    }

    func tomorrowsSchedule() async -> String {
        ""
    }

    func thisWeeksSchedule() async -> String {
        ""
    }

    func nextWeeksSchedule() async -> String {
        ""
    }

    func upcomingWeeksSchedule(_ weekCount: Int) async -> String {
        ""
    }

    func addEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval
    ) async -> String {
        addEventCalls += 1
        return addEventResponse
    }

    func addEventCallCount() -> Int {
        addEventCalls
    }
}

private final class TestTrelloManager: OdinTrelloManaging {
    let defaultListName = "today"

    func availableLists() async -> [OdinTrelloList] {
        []
    }

    func boardSummaries() async -> [OdinTrelloBoardSummary] {
        []
    }

    func boardsAndColumnsSummary() async -> String {
        ""
    }

    func tasks(
        inList listName: String,
        onBoard boardName: String?
    ) async -> String {
        ""
    }

    func addTask(
        title: String,
        toList listName: String
    ) async -> String {
        ""
    }
}

private final class TestCalendarIntentParser: OdinCalendarIntentParsing {
    func parseRuleBased(_ command: String) -> OdinParsedCalendarIntent? {
        nil
    }

    func parse(
        _ command: String,
        modelName: String
    ) async -> OdinParsedCalendarIntent? {
        nil
    }
}

private final class StaticIntentRouter: OdinIntentRouting {
    private let intent: OdinRoutedIntent

    init(intent: OdinRoutedIntent) {
        self.intent = intent
    }

    func route(
        _ command: String,
        modelName: String
    ) async -> OdinRoutedIntent {
        intent
    }
}

private final class TestTrelloClient: OdinTrelloClienting {
    private let boards: [OdinTrelloBoard]
    private let listsByBoardID: [String: [OdinTrelloList]]
    private(set) var openListsCalls = 0

    init(
        boards: [OdinTrelloBoard],
        listsByBoardID: [String: [OdinTrelloList]]
    ) {
        self.boards = boards
        self.listsByBoardID = listsByBoardID
    }

    func boardID(forListID listID: String) async throws -> String {
        boards.first?.id ?? "board-1"
    }

    func openBoards() async throws -> [OdinTrelloBoard] {
        boards
    }

    func openLists(
        boardID: String,
        boardName: String?
    ) async throws -> [OdinTrelloList] {
        openListsCalls += 1
        return listsByBoardID[boardID] ?? []
    }

    func openCards(listID: String) async throws -> [OdinTrelloCard] {
        []
    }

    func addCard(title: String, toListID listID: String) async throws {}
}
