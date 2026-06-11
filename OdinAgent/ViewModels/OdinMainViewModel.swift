import Combine
import Foundation

enum OdinState: String, Equatable {
    case idle = "Idle"
    case listening = "Listening"
    case thinking = "Thinking"
    case speaking = "Speaking"

    var displayText: String {
        rawValue
    }

    var disablesCommands: Bool {
        self == .thinking
    }
}

@MainActor
final class OdinMainViewModel: ObservableObject {
    @Published var odinState: OdinState = .idle
    @Published var latestResponse = ""
    @Published var typedCommand = ""
    @Published var availableModels: [OdinOllamaService.OllamaModel] = []
    @Published var selectedModelName = OdinOllamaService.preferredModelName
    @Published var isLoadingModels = false
    @Published var isHoveringOdin = false
    @Published var isNightMode: Bool

    let idleAnimationService: DogIdleAnimationService
    let speechService: OdinSpeechService
    let mouthAnimationService: DogMouthAnimationService

    private let whisperService: WhisperSoundListeningService
    private let phonemeService: DogPhonemeAnimatorService
    private let brainService: any OdinBrainResponding
    private let ollamaService: any OdinLanguageModelServicing

    private var currentBrainTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    init(dependencies: OdinDependencyContainer = .live) {
        idleAnimationService = dependencies.idleAnimationService
        speechService = dependencies.speechService
        mouthAnimationService = dependencies.mouthAnimationService
        whisperService = dependencies.whisperService
        phonemeService = dependencies.phonemeService
        brainService = dependencies.brainService
        ollamaService = dependencies.ollamaService
        isNightMode = dependencies.configuration.theme.defaultIsNightMode()

        selectedModelName =
            dependencies.configuration.ollama.preferredModelName

        forwardServiceChanges()
    }

    deinit {
        currentBrainTask?.cancel()
    }

    var currentDogImageName: String {
        speechService.isSpeaking
            ? mouthAnimationService.currentImageName
            : idleAnimationService.idleImageName
    }

    var canSubmitTypedCommand: Bool {
        !typedCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty && !odinState.disablesCommands
    }

    var bubbleText: String {
        let response = latestResponse
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if response.isEmpty {
            return defaultBubbleText
        }

        return response
    }

    var defaultBubbleText: String {
        switch odinState {
        case .thinking:
            return "Thinking..."
        case .speaking:
            return latestResponse.isEmpty ? "Awoo." : latestResponse
        case .listening, .idle:
            return "..."
        }
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        odinState = .listening
        idleAnimationService.start()
        loadAvailableModels()
        wireSpeechCallbacks()
        wireWhisperCallbacks()
        whisperService.startListening()
    }

    func toggleNightMode() {
        isNightMode.toggle()
    }

    func stopSpeaking() {
        speechService.stop()
        mouthAnimationService.stop()
        idleAnimationService.start()
        odinState = .listening
    }

    func petOdin() {
        guard odinState != .thinking else {
            return
        }

        latestResponse = "Awoo."
    }

    func submitTypedCommand() {
        let command = typedCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !command.isEmpty else {
            return
        }

        typedCommand = ""
        handleCommand(command)
    }

    func loadAvailableModels() {
        guard !isLoadingModels else {
            return
        }

        isLoadingModels = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let models = try await ollamaService.availableModels()

                guard !Task.isCancelled else {
                    return
                }

                availableModels = models
                selectedModelName = defaultModelName(from: models)
                isLoadingModels = false

            } catch {
                print("Ollama model list error:", error)

                guard !Task.isCancelled else {
                    return
                }

                availableModels = []
                selectedModelName = OdinOllamaService.preferredModelName
                isLoadingModels = false
            }
        }
    }

    private func handleCommand(_ command: String) {
        let modelName = selectedModelName

        odinState = .thinking
        latestResponse = "Thinking..."

        currentBrainTask?.cancel()
        currentBrainTask = Task { [weak self] in
            guard let self else { return }

            let response = await brainService.respond(
                to: command,
                modelName: modelName,
                onPartialResponse: { [weak self] partialResponse in
                    await MainActor.run {
                        self?.latestResponse = partialResponse
                    }
                }
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.latestResponse = response
                self.speechService.speak(response)
            }
        }
    }

    private func wireSpeechCallbacks() {
        speechService.onSpeechStarted = { [weak self] spokenText in
            Task { @MainActor in
                self?.speechStarted(spokenText)
            }
        }

        speechService.onSpeechFinished = { [weak self] in
            Task { @MainActor in
                self?.speechFinished()
            }
        }
    }

    private func wireWhisperCallbacks() {
        whisperService.onTranscript = { [weak self] transcript in
            Task { @MainActor in
                self?.handleCommand(transcript)
            }
        }
    }

    private func speechStarted(_ spokenText: String) {
        odinState = .speaking
        whisperService.stopListening()
        idleAnimationService.stop()

        let frames = phonemeService.frames(for: spokenText)
        mouthAnimationService.play(frames: frames)
    }

    private func speechFinished() {
        odinState = .listening
        mouthAnimationService.stop()
        idleAnimationService.start()
        whisperService.startListening()
    }

    private func defaultModelName(
        from models: [OdinOllamaService.OllamaModel]
    ) -> String {
        if models.contains(where: { $0.name == OdinOllamaService.preferredModelName }) {
            return OdinOllamaService.preferredModelName
        }

        return models.first?.name ?? OdinOllamaService.preferredModelName
    }

    private func forwardServiceChanges() {
        idleAnimationService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        speechService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        mouthAnimationService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
