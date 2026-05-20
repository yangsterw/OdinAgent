import Foundation

final class OdinBrainService {

    private let ollamaService =
        OdinOllamaService()

    private let memoryService =
        OdinMemoryService()

    private let commandService =
        OdinCommandService()

    func respond(to command: String) async -> String {

        if let commandResponse = commandService.handle(command) {
            return commandResponse
        }

        let lower = command.lowercased()

        if lower.contains("good boy") {
            return "Awoo! Thank you. I am a very good boy."
        }

        if lower.contains("bark") {
            return "Woof woof! Ruff!"
        }

        if lower.contains("clear memory") {
            memoryService.clearMemory()
            return "Okay. I cleared my memory."
        }

        let memory = memoryService.loadMemory()

        let prompt = """
        You are Odin, a cute male desktop dog assistant.

        Use this saved memory as context:
        \(memory)

        Current user message:
        \(command)

        Respond as Odin. Be concise, friendly, and helpful.
        """

        do {
            let response =
                try await ollamaService.generateResponse(for: prompt)

            memoryService.saveInteraction(
                user: command,
                odin: response
            )

            return response

        } catch {
            print("Ollama error:", error)
            return "Ruff... my brain is currently offline."
        }
    }
}
