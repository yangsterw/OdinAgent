import Foundation

final class OdinBrainService {

    private let ollamaService =
        OdinOllamaService()

    private let memoryService =
        OdinMemoryService()

    private let commandService =
        OdinCommandService()

    private let conversationService =
        OdinConversationService()

    func respond(to command: String) async -> String {

        let lower = command.lowercased()

        if lower.contains("clear conversation") {
            conversationService.clear()
            return "Okay. I cleared our current conversation."
        }

        if lower.contains("clear memory") {
            memoryService.clearMemory()
            conversationService.clear()
            return "Okay. I cleared my memory."
        }

        if lower.contains("good boy") {
            let response = "Awoo! Thank you. I am a very good boy."
            conversationService.addUserMessage(command)
            conversationService.addOdinMessage(response)
            memoryService.saveInteraction(user: command, odin: response)
            return response
        }

        if lower.contains("bark") {
            let response = "Woof woof! Ruff!"
            conversationService.addUserMessage(command)
            conversationService.addOdinMessage(response)
            memoryService.saveInteraction(user: command, odin: response)
            return response
        }

        if let commandResponse = commandService.handle(command) {
            conversationService.addUserMessage(command)
            conversationService.addOdinMessage(commandResponse)
            memoryService.saveInteraction(user: command, odin: commandResponse)
            return commandResponse
        }

        conversationService.addUserMessage(command)

        let memory = memoryService.loadMemory()
        let recentConversation = conversationService.contextText()

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
        \(memory)

        Recent conversation:
        \(recentConversation)

        Current user message:
        \(command)

        Respond as Odin:
        """

        do {
            let response =
                try await ollamaService.generateResponse(
                    for: prompt
                )

            conversationService.addOdinMessage(response)

            memoryService.saveInteraction(
                user: command,
                odin: response
            )

            return response

        } catch {
            print("Ollama error:", error)

            let fallback =
                "Ruff... my brain is currently offline."

            conversationService.addOdinMessage(fallback)

            return fallback
        }
    }
}
