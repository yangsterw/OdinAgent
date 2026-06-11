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

struct OdinTrelloCard {
    let name: String
}

protocol OdinTrelloManaging: OdinTrelloRoutingDataSource {
    func boardsAndColumnsSummary() async -> String

    func tasks(
        inList listName: String,
        onBoard boardName: String?
    ) async -> String

    func addTask(
        title: String,
        toList listName: String
    ) async -> String
}

protocol OdinTrelloRepositorying: OdinTrelloRoutingDataSource {
    func resolveList(
        named listName: String,
        onBoard boardName: String?
    ) async -> OdinTrelloList?

    func openCards(listID: String) async throws -> [OdinTrelloCard]

    func addCard(
        title: String,
        toListID listID: String
    ) async throws
}

final class OdinTrelloService {
    private let repository: any OdinTrelloRepositorying

    init(
        repository: any OdinTrelloRepositorying = OdinTrelloRepository()
    ) {
        self.repository = repository
    }

    convenience init(configuration: OdinTrelloConfiguration) {
        self.init(
            repository: OdinTrelloRepository(configuration: configuration)
        )
    }

    var defaultListName: String {
        repository.defaultListName
    }

    func availableLists() async -> [OdinTrelloList] {
        await repository.availableLists()
    }

    func boardSummaries() async -> [OdinTrelloBoardSummary] {
        await repository.boardSummaries()
    }

    func boardsAndColumnsSummary() async -> String {
        let summaries = await repository.boardSummaries()

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
        guard let list = await repository.resolveList(
            named: listName,
            onBoard: boardName
        ) else {
            let availableLists = await availableListDescription()

            if availableLists.isEmpty {
                return "I could not find the Trello column named \(listName)."
            }

            return "I could not find the Trello column named \(listName). Available columns are: \(availableLists)."
        }

        do {
            let cards = try await repository.openCards(listID: list.id)
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

        guard let list = await repository.resolveList(
            named: listName,
            onBoard: nil
        ) else {
            let availableListNames = await repository.boardSummaries()
                .flatMap(\.lists)
                .map(\.name)
                .joined(separator: ", ")

            if availableListNames.isEmpty {
                return "I could not find the Trello list named \(listName)."
            }

            return "I could not find the Trello list named \(listName). Available lists are: \(availableListNames)."
        }

        do {
            try await repository.addCard(title: title, toListID: list.id)
            return "I added \(title) to \(list.name)."

        } catch let error as OdinHTTPError {
            print("Trello error:", error)

            if case .badStatusCode(let statusCode) = error {
                return "Trello rejected the task request. Status code \(statusCode)."
            }

            return "I could not connect to Trello."

        } catch {
            print("Trello error:", error)
            return "I could not connect to Trello."
        }
    }

    private func availableListDescription() async -> String {
        await repository.boardSummaries()
            .flatMap(\.lists)
            .map { list in
                if let boardName = list.boardName {
                    return "\(list.name) on \(boardName)"
                }

                return list.name
            }
            .joined(separator: ", ")
    }
}

extension OdinTrelloService: OdinTrelloManaging {}
