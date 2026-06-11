import Foundation

protocol OdinTrelloClienting {
    func boardID(forListID listID: String) async throws -> String
    func openBoards() async throws -> [OdinTrelloBoard]
    func openLists(
        boardID: String,
        boardName: String?
    ) async throws -> [OdinTrelloList]
    func openCards(listID: String) async throws -> [OdinTrelloCard]
    func addCard(title: String, toListID listID: String) async throws
}

final class OdinTrelloClient: OdinTrelloClienting {
    private let configuration: OdinTrelloConfiguration
    private let httpClient: any OdinHTTPClient

    private struct TrelloBoardLookupResponse: Decodable {
        let idBoard: String
    }

    private struct TrelloBoardResponse: Decodable {
        let id: String
        let name: String
    }

    private struct TrelloListResponse: Decodable {
        let id: String
        let name: String
    }

    private struct TrelloCardResponse: Decodable {
        let name: String
    }

    init(
        configuration: OdinTrelloConfiguration = .live,
        httpClient: (any OdinHTTPClient)? = nil
    ) {
        self.configuration = configuration
        self.httpClient = httpClient ?? URLSessionOdinHTTPClient(
            requestTimeout: 60,
            resourceTimeout: 120
        )
    }

    func boardID(forListID listID: String) async throws -> String {
        var request = URLRequest(
            url: endpoint("lists", listID)
        )
        request.url = authenticatedURL(
            for: request.url!,
            queryItems: [
                URLQueryItem(name: "fields", value: "idBoard")
            ]
        )

        let (data, _) = try await httpClient.data(for: request)
        let decoded = try JSONDecoder().decode(
            TrelloBoardLookupResponse.self,
            from: data
        )

        return decoded.idBoard
    }

    func openBoards() async throws -> [OdinTrelloBoard] {
        var request = URLRequest(
            url: endpoint("members", "me", "boards")
        )
        request.url = authenticatedURL(
            for: request.url!,
            queryItems: [
                URLQueryItem(name: "fields", value: "name"),
                URLQueryItem(name: "filter", value: "open")
            ]
        )

        let (data, _) = try await httpClient.data(for: request)

        return try JSONDecoder()
            .decode([TrelloBoardResponse].self, from: data)
            .map { OdinTrelloBoard(id: $0.id, name: $0.name) }
    }

    func openLists(
        boardID: String,
        boardName: String?
    ) async throws -> [OdinTrelloList] {
        var request = URLRequest(
            url: endpoint("boards", boardID, "lists")
        )
        request.url = authenticatedURL(
            for: request.url!,
            queryItems: [
                URLQueryItem(name: "fields", value: "name"),
                URLQueryItem(name: "filter", value: "open")
            ]
        )

        let (data, _) = try await httpClient.data(for: request)

        return try JSONDecoder()
            .decode([TrelloListResponse].self, from: data)
            .map {
                OdinTrelloList(
                    id: $0.id,
                    name: $0.name,
                    boardID: boardID,
                    boardName: boardName
                )
            }
    }

    func openCards(listID: String) async throws -> [OdinTrelloCard] {
        var request = URLRequest(
            url: endpoint("lists", listID, "cards")
        )
        request.url = authenticatedURL(
            for: request.url!,
            queryItems: [
                URLQueryItem(name: "fields", value: "name"),
                URLQueryItem(name: "filter", value: "open")
            ]
        )

        let (data, _) = try await httpClient.data(for: request)

        return try JSONDecoder()
            .decode([TrelloCardResponse].self, from: data)
            .map { OdinTrelloCard(name: $0.name) }
    }

    func addCard(title: String, toListID listID: String) async throws {
        var request = URLRequest(
            url: endpoint("cards")
        )
        request.url = authenticatedURL(
            for: request.url!,
            queryItems: [
                URLQueryItem(name: "idList", value: listID),
                URLQueryItem(name: "name", value: title)
            ]
        )
        request.httpMethod = "POST"

        _ = try await httpClient.data(for: request)
    }

    private func endpoint(_ pathComponents: String...) -> URL {
        pathComponents.reduce(configuration.apiBaseURL) { url, pathComponent in
            url.appendingPathComponent(pathComponent)
        }
    }

    private func authenticatedURL(
        for url: URL,
        queryItems: [URLQueryItem]
    ) -> URL {
        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems + [
            URLQueryItem(name: "key", value: configuration.apiKey),
            URLQueryItem(name: "token", value: configuration.token)
        ]

        return components.url!
    }
}
