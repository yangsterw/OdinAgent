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

    private let memoryService: OdinMemoryService

    private let commandService: any OdinCommandHandling

    private let conversationService: OdinConversationService

    init(
        ollamaService: any OdinLanguageModelServicing = OdinOllamaService(),
        memoryService: OdinMemoryService = OdinMemoryService(),
        commandService: any OdinCommandHandling = OdinCommandService(),
        conversationService: OdinConversationService = OdinConversationService()
    ) {
        self.ollamaService = ollamaService
        self.memoryService = memoryService
        self.commandService = commandService
        self.conversationService = conversationService
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

        let prompt = """
        You are Odin, a cute male desktop dog assistant.

        Personality:
        - friendly
        - playful
        - concise
        - helpful
        - dog-like sometimes
        - do not be overly verbose

        Long-term memory:
        \(promptMemory)

        Recent conversation:
        \(recentConversation)

        Current user message:
        \(command)

        Respond as Odin:
        """

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
