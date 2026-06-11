import Foundation

protocol OdinBrainPromptBuilding {
    func buildPrompt(
        command: String,
        promptMemory: String,
        recentConversation: String
    ) -> String
}

struct OdinBrainPromptBuilder: OdinBrainPromptBuilding {
    func buildPrompt(
        command: String,
        promptMemory: String,
        recentConversation: String
    ) -> String {
        """
        You are Odin, a cute male desktop dog assistant.

        Personality:
        - friendly
        - playful
        - concise
        - helpful
        - dog-like sometimes
        - do not be overly verbose

        Long-term memory:
        \(promptMemory)

        Recent conversation:
        \(recentConversation)

        Current user message:
        \(command)

        Respond as Odin:
        """
    }
}

protocol OdinCalendarIntentPromptBuilding {
    func buildPrompt(command: String, now: Date) -> String
}

struct OdinCalendarIntentPromptBuilder: OdinCalendarIntentPromptBuilding {
    func buildPrompt(command: String, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let calendar = Calendar.current
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: now
        ) ?? now
        let tomorrowAtThree = calendar.date(
            bySettingHour: 15,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? tomorrow

        return """
        You classify only calendar commands for a macOS assistant named Odin.
        Return only one JSON object. Do not use markdown.

        Current local date and time: \(formatter.string(from: now))
        Local time zone: \(TimeZone.current.identifier)

        JSON shapes:
        {"intent":"none"}
        {"intent":"clarify","question":"What time should I schedule it?"}
        {"intent":"read","range":"today"}
        {"intent":"read","range":"tomorrow"}
        {"intent":"read","range":"this_week"}
        {"intent":"read","range":"next_week"}
        {"intent":"read","range":"next_weeks","weekCount":3}
        {"intent":"create","title":"Dentist","startDateTime":"2026-05-28 15:00","durationMinutes":30}

        Rules:
        - Only classify calendar read or calendar create requests.
        - If the user is not asking about their calendar, return {"intent":"none"}.
        - Treat schedule, agenda, meetings, appointments, availability, free time, busy, coming up, and week looking like as calendar language.
        - For read requests, infer the range from natural language.
        - For "next few weeks", use next_weeks with weekCount 3.
        - For create requests, require a title, date, and specific time.
        - If a create request is missing a title, date, or specific time, return clarify with a short question.
        - Use 30 minutes when a create request has no duration.
        - Cap weekCount at 8.
        - If the command includes "Previous incomplete calendar command" and "User follow-up", combine them into one calendar request.

        Examples:
        User: what's my week looking like
        {"intent":"read","range":"this_week"}

        User: am I busy next week
        {"intent":"read","range":"next_week"}

        User: what's coming up over the next few weeks
        {"intent":"read","range":"next_weeks","weekCount":3}

        User: put dentist on my calendar tomorrow at 3 pm
        {"intent":"create","title":"Dentist","startDateTime":"\(formatter.string(from: tomorrowAtThree))","durationMinutes":30}

        User: schedule planning tomorrow afternoon
        {"intent":"clarify","question":"What time tomorrow should I schedule planning?"}

        User: Previous incomplete calendar command: schedule planning tomorrow
        User follow-up: 3 pm
        {"intent":"create","title":"Planning","startDateTime":"\(formatter.string(from: tomorrowAtThree))","durationMinutes":30}

        User command:
        \(command)
        """
    }
}

protocol OdinTrelloIntentPromptBuilding {
    func buildPrompt(
        command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) -> String
}

struct OdinTrelloIntentPromptBuilder: OdinTrelloIntentPromptBuilding {
    func buildPrompt(
        command: String,
        availableLists: [OdinTrelloList],
        boardSummaries: [OdinTrelloBoardSummary],
        defaultListName: String
    ) -> String {
        let availableListLines = availableLists
            .map { "- \($0.name)" }
            .joined(separator: "\n")

        let boardLines = boardSummaries
            .map { summary in
                let columns = summary.lists
                    .map(\.name)
                    .joined(separator: ", ")

                return "- \(summary.board.name): \(columns)"
            }
            .joined(separator: "\n")

        return """
        You classify only Trello task commands for a macOS assistant named Odin.
        Return only one JSON object. Do not use markdown.

        Available Trello boards and columns:
        \(boardLines)

        Allowed Trello lists:
        \(availableListLines)

        JSON shapes:
        {"intent":"none"}
        {"intent":"clarify","question":"What should I name the Trello task?"}
        {"intent":"show_boards_and_columns"}
        {"intent":"show_tasks","listName":"In Progress","boardName":"Work Board"}
        {"intent":"add_task","title":"Review pull request","listName":"\(defaultListName)"}

        Rules:
        - Only classify Trello requests.
        - If the user is not asking about Trello boards, columns, tasks, cards, or card creation, return {"intent":"none"}.
        - If the user asks what Trello boards, columns, lists, or statuses they have, return show_boards_and_columns.
        - If the user asks what tasks/cards are in a specific Trello column/list, return show_tasks.
        - For show_tasks, listName must be exactly one of the shown column names.
        - For show_tasks, include boardName only when the user names a board.
        - If the task title is missing or unclear, return clarify with a short question.
        - For phrases like "add a task that I am making pizza", use the text after "that I am" as the task title.
        - For phrases like "add a task that I need to buy flour", use the text after "that I need to" as the task title.
        - If the Trello list is missing, use "\(defaultListName)".
        - The listName must be exactly one of the allowed Trello lists.
        - Match the user's wording to the closest allowed list name.
        - Prefer exact list names when the user names a board column.
        - If the command includes "Previous incomplete Trello command" and "User follow-up", combine them into one Trello request.

        Examples:
        User: add follow up with Alex to Trello
        {"intent":"add_task","title":"Follow up with Alex","listName":"\(defaultListName)"}

        User: add a task that I am making pizza
        {"intent":"add_task","title":"Making pizza","listName":"\(defaultListName)"}

        User: add a task that I need to buy flour
        {"intent":"add_task","title":"Buy flour","listName":"\(defaultListName)"}

        User: what Trello boards and columns do I have
        {"intent":"show_boards_and_columns"}

        User: what is in the in progress column
        {"intent":"show_tasks","listName":"In Progress","boardName":null}

        User: what cards are in QA on Work Board
        {"intent":"show_tasks","listName":"QA","boardName":"Work Board"}

        User: put fix login bug in the in progress column
        {"intent":"add_task","title":"Fix login bug","listName":"In Progress"}

        User: add a card for researching pricing to upcoming priorities
        {"intent":"add_task","title":"Research pricing","listName":"Upcoming Priorities"}

        User: add waiting on API credentials to blocked
        {"intent":"add_task","title":"Waiting on API credentials","listName":"Blocked"}

        User: add a Trello task
        {"intent":"clarify","question":"What should I name the Trello task?"}

        User: Previous incomplete Trello command: add a Trello task
        User follow-up: Fix the login bug
        {"intent":"add_task","title":"Fix the login bug","listName":"\(defaultListName)"}

        User command:
        \(command)
        """
    }
}
