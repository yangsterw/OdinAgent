import Foundation

final class OdinBrainService {

    private let ollamaService =
        OdinOllamaService()

    func respond(to command: String) async -> String {

        let lower = command.lowercased()

        // fast local rules first

        if lower.contains("good boy") {
            return "Awoo! Thank you. I am a very good boy."
        }

        if lower.contains("bark") {
            return "Woof woof! Ruff!"
        }

        do {

            let aiResponse =
                try await ollamaService.generateResponse(
                    for: command
                )

            return aiResponse

        } catch {

            print("Ollama error:", error)

            return "Ruff... my brain is currently offline."
        }
    }
}
