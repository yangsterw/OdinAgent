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
}
