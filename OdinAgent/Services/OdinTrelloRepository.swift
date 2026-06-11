import Foundation

final class OdinTrelloRepository: OdinTrelloRepositorying {
    private let configuration: OdinTrelloConfiguration
    private let client: any OdinTrelloClienting

    private var cachedLists: [OdinTrelloList] = []
    private var cachedListsDate: Date?
    private var cachedBoardSummaries: [OdinTrelloBoardSummary] = []
    private var cachedBoardSummariesDate: Date?
    private var cachedBoardID: String?

    init(
        configuration: OdinTrelloConfiguration = .live,
        client: (any OdinTrelloClienting)? = nil
    ) {
        self.configuration = configuration
        self.client = client ?? OdinTrelloClient(configuration: configuration)
    }

    var defaultListName: String {
        configuration.defaultListName
    }

    func availableLists() async -> [OdinTrelloList] {
        if let cachedListsDate,
           Date().timeIntervalSince(cachedListsDate) < configuration.listCacheDuration,
           !cachedLists.isEmpty {
            return cachedLists
        }

        do {
            let boardID = try await boardID()
            let board = await currentBoard()
            let lists = try await client.openLists(
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
           Date().timeIntervalSince(cachedBoardSummariesDate) < configuration.listCacheDuration,
           !cachedBoardSummaries.isEmpty {
            return cachedBoardSummaries
        }

        do {
            let boards = try await client.openBoards()

            var summaries: [OdinTrelloBoardSummary] = []

            for board in boards {
                let lists = try await client.openLists(
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

    func resolveList(
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

        if let legacyListID = configuration.listIDs[listName.lowercased()] {
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

    func openCards(listID: String) async throws -> [OdinTrelloCard] {
        try await client.openCards(listID: listID)
    }

    func addCard(title: String, toListID listID: String) async throws {
        try await client.addCard(title: title, toListID: listID)
    }

    private func boardID() async throws -> String {
        if let cachedBoardID {
            return cachedBoardID
        }

        guard let seedListID = configuration.listIDs[defaultListName] ??
            configuration.listIDs.values.first else {
            throw URLError(.badURL)
        }

        let id = try await client.boardID(forListID: seedListID)
        cachedBoardID = id
        return id
    }

    private func currentBoard() async -> OdinTrelloBoard? {
        do {
            let currentBoardID = try await boardID()

            if let board = try await client.openBoards().first(where: {
                $0.id == currentBoardID
            }) {
                return board
            }

            return OdinTrelloBoard(
                id: currentBoardID,
                name: "Configured Trello board"
            )

        } catch {
            print("Trello current board fetch error:", error)
            return nil
        }
    }

    private func fallbackLists(boardName: String? = nil) -> [OdinTrelloList] {
        configuration.listIDs.map { key, value in
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
