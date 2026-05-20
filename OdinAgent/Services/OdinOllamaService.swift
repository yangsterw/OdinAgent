//
//  OdinOllamaService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation

final class OdinOllamaService {

    func generateResponse(
        for prompt: String
    ) async throws -> String {

        guard let url = URL(
            string: "http://127.0.0.1:11434/api/generate"
        ) else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "model": "llama3.2:3b",
            "prompt": """
            You are Odin, a cute male desktop dog assistant.

            Personality:
            - playful
            - friendly
            - concise
            - slightly funny
            - dog-like sometimes
            - never overly verbose

            User said:
            \(prompt)

            Respond as Odin:
            """,
            "stream": false
        ]

        let jsonData = try JSONSerialization.data(
            withJSONObject: body
        )

        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(
            for: request
        )

        guard let json = try JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {

            throw NSError(
                domain: "OdinOllamaService",
                code: 1
            )
        }

        let response =
            json["response"] as? String ?? ""

        return response.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
