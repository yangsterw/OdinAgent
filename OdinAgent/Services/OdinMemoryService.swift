import Foundation

final class OdinMemoryService {

    private let fileName = "OdinMemory.txt"
    private let maxCharacters = 20_000

    private var memoryURL: URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        return documents.appendingPathComponent(fileName)
    }

    func loadMemory() -> String {
        do {
            return try String(
                contentsOf: memoryURL,
                encoding: .utf8
            )
        } catch {
            return ""
        }
    }

    func saveInteraction(user: String, odin: String) {
        let timestamp = Date().formatted()

        let entry = """

        [\(timestamp)]
        User: \(user)
        Odin: \(odin)

        """

        do {
            let oldMemory = loadMemory()
            let newMemory = oldMemory + entry
            let limitedMemory = limitMemory(newMemory)

            try limitedMemory.write(
                to: memoryURL,
                atomically: true,
                encoding: .utf8
            )

            print("Saved Odin memory to:", memoryURL.path)

        } catch {
            print("Failed to save Odin memory:", error)
        }
    }

    func clearMemory() {
        do {
            try "".write(
                to: memoryURL,
                atomically: true,
                encoding: .utf8
            )

            print("Odin memory cleared")

        } catch {
            print("Failed to clear Odin memory:", error)
        }
    }

    private func limitMemory(_ memory: String) -> String {
        guard memory.count > maxCharacters else {
            return memory
        }

        return String(memory.suffix(maxCharacters))
    }
}
