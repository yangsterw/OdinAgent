import Foundation

struct OdinDependencyContainer {
    let configuration: OdinAppConfiguration
    let idleAnimationService: DogIdleAnimationService
    let speechService: OdinSpeechService
    let mouthAnimationService: DogMouthAnimationService
    let whisperService: WhisperSoundListeningService
    let phonemeService: DogPhonemeAnimatorService
    let brainService: any OdinBrainResponding
    let ollamaService: any OdinLanguageModelServicing

    static let live = makeLive(configuration: .live)

    static func makeLive(
        configuration: OdinAppConfiguration
    ) -> OdinDependencyContainer {
        let ollamaService = OdinOllamaService(
            configuration: configuration.ollama
        )
        let trelloService = OdinTrelloService(
            configuration: configuration.trello
        )
        let trelloIntentService = OdinTrelloIntentService(
            ollamaService: ollamaService
        )
        let calendarService = OdinCalendarService()
        let calendarIntentService = OdinCalendarIntentService(
            ollamaService: ollamaService
        )
        let pendingActionService = OdinPendingActionService()
        let intentRouterService = OdinIntentRouterService(
            trelloService: trelloService,
            trelloIntentService: trelloIntentService,
            calendarIntentService: calendarIntentService
        )
        let commandService = OdinCommandService(
            trelloService: trelloService,
            trelloIntentService: trelloIntentService,
            calendarService: calendarService,
            calendarIntentService: calendarIntentService,
            pendingActionService: pendingActionService,
            intentRouterService: intentRouterService
        )
        let memoryService = OdinMemoryService()
        let conversationService = OdinConversationService()
        let brainService = OdinBrainService(
            ollamaService: ollamaService,
            memoryService: memoryService,
            commandService: commandService,
            conversationService: conversationService
        )

        return OdinDependencyContainer(
            configuration: configuration,
            idleAnimationService: DogIdleAnimationService(),
            speechService: OdinSpeechService(),
            mouthAnimationService: DogMouthAnimationService(),
            whisperService: WhisperSoundListeningService(),
            phonemeService: DogPhonemeAnimatorService(),
            brainService: brainService,
            ollamaService: ollamaService
        )
    }
}
