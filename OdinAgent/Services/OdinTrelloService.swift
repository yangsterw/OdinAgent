//
//  OdinTrelloService.swift
//  OdinAgent
//
//  Created by yang on 5/20/26.
//


import Foundation

final class OdinTrelloService {

    private let apiKey = Secrets.trelloAPIKey
    private let token = Secrets.trelloToken

    private var listIDs: [String: String] {
        [
            "today's highest priority": Secrets.trelloListToday,
            "todays highest priority": Secrets.trelloListToday,
            "in progress": Secrets.trelloListInProgress,
            "upcoming priorities": Secrets.trelloListUpcoming,
            "future consideration": Secrets.trelloListFuture,
            "blocked": Secrets.trelloListBlocked
        ]
    }

    func addTask(
        title: String,
        toList listName: String
    ) async -> String {

        guard let listID = listIDs[listName.lowercased()] else {
            return "I could not find the Trello list named \(listName)."
        }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "I could not add an empty Trello task."
        }

        var components = URLComponents(
            string: "https://api.trello.com/1/cards"
        )!

        components.queryItems = [
            URLQueryItem(name: "idList", value: listID),
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else {
            return "I could not build the Trello request."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                return "I did not get a valid response from Trello."
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                return "Trello rejected the task request. Status code \(httpResponse.statusCode)."
            }

            return "I added \(title) to \(listName)."

        } catch {
            print("Trello error:", error)
            return "I could not connect to Trello."
        }
    }
}