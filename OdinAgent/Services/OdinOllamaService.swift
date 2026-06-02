import Foundation

final class OdinOllamaService {
    private struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }

    private struct GenerateStreamResponse: Decodable {
        let response: String
        let done: Bool
    }

    func generateResponse(
        for prompt: String
    ) async throws -> String {

        guard let url = URL(
            string: "http://127.0.0.1:11434/api/generate"
        ) else {
            throw URLError(.badURL)
        }

        let requestBody = GenerateRequest(
            model: "llama3.2:3b",
            prompt: prompt,
            stream: false
        )
        let jsonData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(
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
        onPartialResponse: @escaping (String) async -> Void
    ) async throws -> String {

        guard let url = URL(
            string: "http://127.0.0.1:11434/api/generate"
        ) else {
            throw URLError(.badURL)
        }

        let requestBody = GenerateRequest(
            model: "llama3.2:3b",
            prompt: prompt,
            stream: true
        )
        let jsonData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = jsonData

        let (bytes, response) = try await URLSession.shared.bytes(
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
}
