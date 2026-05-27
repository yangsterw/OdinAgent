//
//  OdinTrelloService.swift
//  OdinAgent
//
//  Created by yang on 5/20/26.
//


import Foundation

struct OdinTrelloList {
    let id: String
    let name: String
    let boardID: String?
    let boardName: String?
}

struct OdinTrelloBoard {
    let id: String
    let name: String
}

struct OdinTrelloBoardSummary {
    let board: OdinTrelloBoard
    let lists: [OdinTrelloList]
}

final class OdinTrelloService {

    private let apiKey = Secrets.trelloAPIKey
    private let token = Secrets.trelloToken
    private let listCacheSeconds: TimeInterval = 10 * 60

    private var cachedLists: [OdinTrelloList] = []
    private var cachedListsDate: Date?
    private var cachedBoardSummaries: [OdinTrelloBoardSummary] = []
    private var cachedBoardSummariesDate: Date?
    private var cachedBoardID: String?

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

    var defaultListName: String {
        "today's highest priority"
    }

    func availableLists() async -> [OdinTrelloList] {
        if let cachedListsDate,
           Date().timeIntervalSince(cachedListsDate) < listCacheSeconds,
           !cachedLists.isEmpty {
            return cachedLists
        }

        do {
            let boardID = try await boardID()
            let board = await currentBoard()
            let lists = try await fetchOpenLists(
                boardID: boardID,
                boardName: board?.name
            )

            cachedLists = lists
            cachedListsDate = Date()

            return lists

        } catch {
            print("Trello list fetch error:", error)
            return fallbackLists()
        }
    }

    func boardSummaries() async -> [OdinTrelloBoardSummary] {
        if let cachedBoardSummariesDate,
           Date().timeIntervalSince(cachedBoardSummariesDate) < listCacheSeconds,
           !cachedBoardSummaries.isEmpty {
            return cachedBoardSummaries
        }

        do {
            let boards = try await fetchOpenBoards()

            var summaries: [OdinTrelloBoardSummary] = []

            for board in boards {
                let lists = try await fetchOpenLists(
                    boardID: board.id,
                    boardName: board.name
                )

                summaries.append(
                    OdinTrelloBoardSummary(
                        board: board,
                        lists: lists
                    )
                )
            }

            cachedBoardSummaries = summaries
            cachedBoardSummariesDate = Date()

            return summaries

        } catch {
            print("Trello board summary fetch error:", error)

            let board = await currentBoard() ??
                OdinTrelloBoard(id: "", name: "Configured Trello board")

            return [
                OdinTrelloBoardSummary(
                    board: board,
                    lists: fallbackLists(boardName: board.name)
                )
            ]
        }
    }

    func boardsAndColumnsSummary() async -> String {
        let summaries = await boardSummaries()

        guard !summaries.isEmpty else {
            return "I could not find any open Trello boards."
        }

        let lines = summaries.map { summary in
            let listNames = summary.lists
                .map(\.name)
                .joined(separator: ", ")

            if listNames.isEmpty {
                return "\(summary.board.name): no open columns."
            }

            return "\(summary.board.name): \(listNames)."
        }

        return "Your Trello boards and columns are: " +
            lines.joined(separator: " ")
    }

    func tasks(
        inList listName: String,
        onBoard boardName: String?
    ) async -> String {
        guard let list = await resolveList(
            named: listName,
            onBoard: boardName
        ) else {
            let summaries = await boardSummaries()
            let availableLists = summaries
                .flatMap(\.lists)
                .map { list in
                    if let boardName = list.boardName {
                        return "\(list.name) on \(boardName)"
                    }

                    return list.name
                }
                .joined(separator: ", ")

            if availableLists.isEmpty {
                return "I could not find the Trello column named \(listName)."
            }

            return "I could not find the Trello column named \(listName). Available columns are: \(availableLists)."
        }

        do {
            let cards = try await fetchOpenCards(listID: list.id)

            let boardText = list.boardName.map { " on \($0)" } ?? ""

            guard !cards.isEmpty else {
                return "\(list.name)\(boardText) has no open Trello cards."
            }

            let cardNames = cards
                .prefix(12)
                .map(\.name)
                .joined(separator: "; ")

            if cards.count > 12 {
                return "\(list.name)\(boardText) has \(cards.count) open Trello cards. First up: \(cardNames)."
            }

            return "\(list.name)\(boardText) has \(cards.count) open Trello cards: \(cardNames)."

        } catch {
            print("Trello cards fetch error:", error)
            return "I could not fetch the Trello cards in \(list.name)."
        }
    }

    func addTask(
        title: String,
        toList listName: String
    ) async -> String {

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "I could not add an empty Trello task."
        }

        guard let list = await resolveList(named: listName) else {
            let availableListNames = await boardSummaries()
                .flatMap(\.lists)
                .map(\.name)
                .joined(separator: ", ")

            if availableListNames.isEmpty {
                return "I could not find the Trello list named \(listName)."
            }

            return "I could not find the Trello list named \(listName). Available lists are: \(availableListNames)."
        }

        var components = URLComponents(
            string: "https://api.trello.com/1/cards"
        )!

        components.queryItems = [
            URLQueryItem(name: "idList", value: list.id),
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

            return "I added \(title) to \(list.name)."

        } catch {
            print("Trello error:", error)
            return "I could not connect to Trello."
        }
    }

    private func resolveList(named listName: String) async -> OdinTrelloList? {
        await resolveList(named: listName, onBoard: nil)
    }

    private func resolveList(
        named listName: String,
        onBoard boardName: String?
    ) async -> OdinTrelloList? {
        let normalizedListName = normalize(listName)
        let normalizedBoardName = boardName.map(normalize)
        let currentBoardLists = await availableLists()

        if normalizedBoardName == nil,
           let exactMatch = currentBoardLists.first(where: {
            normalize($0.name) == normalizedListName
        }) {
            return exactMatch
        }

        let allLists = await boardSummaries()
            .flatMap(\.lists)

        let matchingLists = allLists.filter { list in
            let listMatches = normalize(list.name) == normalizedListName
            let boardMatches = normalizedBoardName == nil ||
                normalize(list.boardName ?? "") == normalizedBoardName

            return listMatches && boardMatches
        }

        if matchingLists.count == 1 {
            return matchingLists[0]
        }

        if let legacyListID = listIDs[listName.lowercased()] {
            return currentBoardLists.first { $0.id == legacyListID } ??
                OdinTrelloList(
                    id: legacyListID,
                    name: listName,
                    boardID: nil,
                    boardName: nil
                )
        }

        return nil
    }

    private func currentBoard() async -> OdinTrelloBoard? {
        do {
            let currentBoardID = try await boardID()

            if let board = try await fetchOpenBoards().first(where: {
                $0.id == currentBoardID
            }) {
                return board
            }

            return OdinTrelloBoard(id: currentBoardID, name: "Configured Trello board")

        } catch {
            print("Trello current board fetch error:", error)
            return nil
        }
    }

    private func boardID() async throws -> String {
        if let cachedBoardID {
            return cachedBoardID
        }

        guard let seedListID = listIDs[defaultListName] ?? listIDs.values.first else {
            throw URLError(.badURL)
        }

        var components = URLComponents(
            string: "https://api.trello.com/1/lists/\(seedListID)"
        )!

        components.queryItems = [
            URLQueryItem(name: "fields", value: "idBoard"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(
            TrelloBoardLookupResponse.self,
            from: data
        )

        cachedBoardID = decoded.idBoard
        return decoded.idBoard
    }

    private func fetchOpenBoards() async throws -> [OdinTrelloBoard] {
        var components = URLComponents(
            string: "https://api.trello.com/1/members/me/boards"
        )!

        components.queryItems = [
            URLQueryItem(name: "fields", value: "name"),
            URLQueryItem(name: "filter", value: "open"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder()
            .decode([TrelloBoardResponse].self, from: data)
            .map { OdinTrelloBoard(id: $0.id, name: $0.name) }
    }

    private func fetchOpenLists(
        boardID: String,
        boardName: String?
    ) async throws -> [OdinTrelloList] {
        var components = URLComponents(
            string: "https://api.trello.com/1/boards/\(boardID)/lists"
        )!

        components.queryItems = [
            URLQueryItem(name: "fields", value: "name"),
            URLQueryItem(name: "filter", value: "open"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

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

    private func fetchOpenCards(listID: String) async throws -> [TrelloCardResponse] {
        var components = URLComponents(
            string: "https://api.trello.com/1/lists/\(listID)/cards"
        )!

        components.queryItems = [
            URLQueryItem(name: "fields", value: "name"),
            URLQueryItem(name: "filter", value: "open"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(
            [TrelloCardResponse].self,
            from: data
        )
    }

    private func fallbackLists(boardName: String? = nil) -> [OdinTrelloList] {
        listIDs.map { key, value in
            OdinTrelloList(
                id: value,
                name: key,
                boardID: nil,
                boardName: boardName
            )
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
