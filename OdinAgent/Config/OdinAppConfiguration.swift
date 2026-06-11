import Foundation

struct OdinAppConfiguration {
    let ollama: OdinOllamaConfiguration
    let trello: OdinTrelloConfiguration
    let theme: OdinThemeConfiguration

    static let live = OdinAppConfiguration(
        ollama: .live,
        trello: .live,
        theme: .live
    )
}

struct OdinOllamaConfiguration {
    let baseURL: URL
    let preferredModelName: String
    let defaultContextWindow: Int
    let requestTimeout: TimeInterval
    let resourceTimeout: TimeInterval

    static let live = OdinOllamaConfiguration(
        baseURL: URL(string: "http://127.0.0.1:11434")!,
        preferredModelName: "gemma4:31b-it-qat",
        defaultContextWindow: 16_384,
        requestTimeout: 600,
        resourceTimeout: 1_800
    )
}

struct OdinTrelloConfiguration {
    let apiBaseURL: URL
    let apiKey: String
    let token: String
    let listCacheDuration: TimeInterval
    let defaultListName: String
    let listIDs: [String: String]

    static let live = OdinTrelloConfiguration(
        apiBaseURL: URL(string: "https://api.trello.com/1")!,
        apiKey: Secrets.trelloAPIKey,
        token: Secrets.trelloToken,
        listCacheDuration: 10 * 60,
        defaultListName: "today's highest priority",
        listIDs: [
            "today's highest priority": Secrets.trelloListToday,
            "todays highest priority": Secrets.trelloListToday,
            "in progress": Secrets.trelloListInProgress,
            "upcoming priorities": Secrets.trelloListUpcoming,
            "future consideration": Secrets.trelloListFuture,
            "blocked": Secrets.trelloListBlocked
        ]
    )
}

struct OdinThemeConfiguration {
    let dayStartHour: Int
    let nightStartHour: Int

    static let live = OdinThemeConfiguration(
        dayStartHour: 7,
        nightStartHour: 19
    )

    func defaultIsNightMode(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)

        return hour < dayStartHour || hour >= nightStartHour
    }
}
