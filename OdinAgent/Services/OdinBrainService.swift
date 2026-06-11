import Foundation

protocol OdinBrainResponding {
    func respond(
        to command: String,
        modelName: String,
        onPartialResponse: @escaping (String) async -> Void
    ) async -> String
}

final class OdinBrainService {
    private static let maxPromptMemoryCharacters = 4_000

    private let ollamaService: any OdinLanguageModelServicing

    private let memoryService: any OdinMemoryManaging

    private let commandService: any OdinCommandHandling

    private let conversationService: any OdinConversationManaging

    private let promptBuilder: any OdinBrainPromptBuilding

    init(
        ollamaService: any OdinLanguageModelServicing = OdinOllamaService(),
        memoryService: any OdinMemoryManaging = OdinMemoryService(),
        commandService: any OdinCommandHandling = OdinCommandService(),
        conversationService: any OdinConversationManaging = OdinConversationService(),
        promptBuilder: any OdinBrainPromptBuilding = OdinBrainPromptBuilder()
    ) {
        self.ollamaService = ollamaService
        self.memoryService = memoryService
        self.commandService = commandService
        self.conversationService = conversationService
        self.promptBuilder = promptBuilder
    }

    private func recordAndReturn(_ user: String, _ odin: String) async -> String {
        await conversationService.addUserMessage(user)
        await conversationService.addOdinMessage(odin)
        await memoryService.saveInteraction(user: user, odin: odin)
        return odin
    }

    func respond(
        to command: String,
        modelName: String = OdinOllamaService.preferredModelName,
        onPartialResponse: @escaping (String) async -> Void = { _ in }
    ) async -> String {

        let lower = command.lowercased()

        if lower.contains("clear conversation") {
            await conversationService.clear()
            let response = "Okay. I cleared our current conversation."
            await onPartialResponse(response)
            return response
        }

        if lower.contains("clear memory") {
            await memoryService.clearMemory()
            await conversationService.clear()
            let response = "Okay. I cleared my memory."
            await onPartialResponse(response)
            return response
        }

        if lower.contains("good boy") {
            let response = "Awoo! Thank you. I am a very good boy."
            await onPartialResponse(response)
            return await recordAndReturn(command, response)
        }

        if lower.contains("bark") {
            let response = "Woof woof! Ruff!"
            await onPartialResponse(response)
            return await recordAndReturn(command, response)
        }

        if let commandResponse = await commandService.handle(
            command,
            modelName: modelName
        ) {
            await onPartialResponse(commandResponse)
            return await recordAndReturn(command, commandResponse)
        }

        await conversationService.addUserMessage(command)

        let memory = await memoryService.loadMemory()
        let promptMemory = String(memory.suffix(Self.maxPromptMemoryCharacters))
        let recentConversation = await conversationService.contextText()

        let prompt = promptBuilder.buildPrompt(
            command: command,
            promptMemory: promptMemory,
            recentConversation: recentConversation
        )

        do {
            let response =
                try await ollamaService.streamResponse(
                    for: prompt,
                    modelName: modelName,
                    onPartialResponse: onPartialResponse
                )

            await conversationService.addOdinMessage(response)
            await memoryService.saveInteraction(
                user: command,
                odin: response
            )

            return response

        } catch {
            print("Ollama error:", error)

            let fallback =
                "Ruff... my brain is currently offline."

            await onPartialResponse(fallback)
            await conversationService.addOdinMessage(fallback)

            return fallback
        }
    }
}

extension OdinBrainService: OdinBrainResponding {}
