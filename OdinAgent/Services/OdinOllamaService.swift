import Foundation

final class OdinOllamaService {
    nonisolated static let preferredModelName =
        OdinOllamaConfiguration.live.preferredModelName
    nonisolated static let defaultContextWindow =
        OdinOllamaConfiguration.live.defaultContextWindow

    private let configuration: OdinOllamaConfiguration
    private let httpClient: any OdinHTTPClient

    init(
        configuration: OdinOllamaConfiguration = .live,
        httpClient: (any OdinHTTPClient)? = nil
    ) {
        self.configuration = configuration
        self.httpClient = httpClient ?? URLSessionOdinHTTPClient(
            requestTimeout: configuration.requestTimeout,
            resourceTimeout: configuration.resourceTimeout
        )
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

        let url = configuration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("generate")

        let requestBody = GenerateRequest(
            model: modelName,
            prompt: prompt,
            stream: false,
            think: false,
            options: GenerateOptions(
                numCtx: configuration.defaultContextWindow
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

        let (data, _) = try await httpClient.data(for: request)

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func streamResponse(
        for prompt: String,
        modelName: String = OdinOllamaService.preferredModelName,
        onPartialResponse: @escaping (String) async -> Void
    ) async throws -> String {

        let url = configuration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("generate")

        let requestBody = GenerateRequest(
            model: modelName,
            prompt: prompt,
            stream: true,
            think: false,
            options: GenerateOptions(
                numCtx: configuration.defaultContextWindow
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

        let (bytes, _) = try await httpClient.bytes(for: request)

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
        let url = configuration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("tags")

        let request = URLRequest(url: url)
        let (data, _) = try await httpClient.data(for: request)

        return try JSONDecoder().decode(ModelsResponse.self, from: data).models
    }
}

protocol OdinLanguageModelServicing {
    func generateResponse(
        for prompt: String,
        modelName: String
    ) async throws -> String

    func streamResponse(
        for prompt: String,
        modelName: String,
        onPartialResponse: @escaping (String) async -> Void
    ) async throws -> String

    func availableModels() async throws -> [OdinOllamaService.OllamaModel]
}

extension OdinOllamaService: OdinLanguageModelServicing {}
