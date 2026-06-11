import Foundation

final class OdinOllamaService {
    nonisolated static let preferredModelName = "gemma4:31b-it-qat"
    nonisolated static let defaultContextWindow = 16_384

    private let session: URLSession

    init(session: URLSession = OdinOllamaService.makeSession()) {
        self.session = session
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 1_800

        return URLSession(configuration: configuration)
    }

    private struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
        let think: Bool
        let options: GenerateOptions
    }

    private struct GenerateOptions: Encodable {
        let numCtx: Int

        enum CodingKeys: String, CodingKey {
            case numCtx = "num_ctx"
        }
    }

    private struct ModelsResponse: Decodable {
        let models: [OllamaModel]
    }

    struct OllamaModel: Decodable, Identifiable {
        let name: String

        var id: String {
            name
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }

    private struct GenerateStreamResponse: Decodable {
        let response: String
        let done: Bool
    }

    func generateResponse(
        for prompt: String,
        modelName: String = OdinOllamaService.preferredModelName
    ) async throws -> String {

        guard let url = URL(
            string: "http://127.0.0.1:11434/api/generate"
        ) else {
            throw URLError(.badURL)
        }

        let requestBody = GenerateRequest(
            model: modelName,
            prompt: prompt,
            stream: false,
            think: false,
            options: GenerateOptions(
                numCtx: Self.defaultContextWindow
            )
        )
        let jsonData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = jsonData

        let (data, response) = try await session.data(
            for: request
        )
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func streamResponse(
        for prompt: String,
        modelName: String = OdinOllamaService.preferredModelName,
        onPartialResponse: @escaping (String) async -> Void
    ) async throws -> String {

        guard let url = URL(
            string: "http://127.0.0.1:11434/api/generate"
        ) else {
            throw URLError(.badURL)
        }

        let requestBody = GenerateRequest(
            model: modelName,
            prompt: prompt,
            stream: true,
            think: false,
            options: GenerateOptions(
                numCtx: Self.defaultContextWindow
            )
        )
        let jsonData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = jsonData

        let (bytes, response) = try await session.bytes(
            for: request
        )
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        var fullResponse = ""

        for try await line in bytes.lines {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let data = Data(line.utf8)
            let decoded = try JSONDecoder().decode(
                GenerateStreamResponse.self,
                from: data
            )

            if !decoded.response.isEmpty {
                fullResponse += decoded.response
                await onPartialResponse(fullResponse)
            }

            if decoded.done {
                break
            }
        }

        return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func availableModels() async throws -> [OllamaModel] {
        guard let url = URL(
            string: "http://127.0.0.1:11434/api/tags"
        ) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ModelsResponse.self, from: data).models
    }
}
