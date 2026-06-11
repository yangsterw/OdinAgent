import Foundation

enum OdinCalendarReadRange {
    case today
    case tomorrow
    case thisWeek
    case nextWeek
    case nextWeeks(Int)
}

enum OdinParsedCalendarIntent {
    case none
    case clarify(String)
    case read(OdinCalendarReadRange)
    case create(title: String, startDate: Date, duration: TimeInterval)
}

final class OdinCalendarIntentService {

    private struct CalendarIntentResponse: Decodable {
        let intent: String
        let range: String?
        let weekCount: Int?
        let title: String?
        let startDateTime: String?
        let durationMinutes: Int?
        let question: String?
    }

    private let ollamaService = OdinOllamaService()

    func parseRuleBased(_ command: String) -> OdinParsedCalendarIntent? {
        let lower = command.lowercased()

        if isTodayCalendarQuery(lower) {
            return .read(.today)
        }

        if isTomorrowCalendarQuery(lower) {
            return .read(.tomorrow)
        }

        if let weekCount = parseUpcomingWeeksCalendarQuery(lower) {
            return .read(.nextWeeks(weekCount))
        }

        if isThisWeekCalendarQuery(lower) {
            return .read(.thisWeek)
        }

        if isNextWeekCalendarQuery(lower) {
            return .read(.nextWeek)
        }

        if let event = parseCalendarEvent(command) {
            return .create(
                title: event.title,
                startDate: event.startDate,
                duration: event.duration
            )
        }

        return nil
    }

    func parse(
        _ command: String,
        modelName: String = OdinOllamaService.preferredModelName
    ) async -> OdinParsedCalendarIntent? {
        let prompt = buildPrompt(command: command)

        do {
            let response = try await ollamaService.generateResponse(
                for: prompt,
                modelName: modelName
            )

            guard let jsonData = extractJSONObject(from: response)
                .data(using: .utf8) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(
                CalendarIntentResponse.self,
                from: jsonData
            )

            return map(decoded)

        } catch {
            print("Calendar intent parse error:", error)
            return nil
        }
    }

    private func buildPrompt(command: String) -> String {
        let now = Date()
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

    private func map(_ response: CalendarIntentResponse) -> OdinParsedCalendarIntent {
        switch response.intent {
        case "none":
            return .none

        case "clarify":
            let question = response.question?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return .clarify(
                question?.isEmpty == false
                    ? question!
                    : "What calendar details should I use?"
            )

        case "read":
            guard let range = response.range else {
                return .none
            }

            switch range {
            case "today":
                return .read(.today)

            case "tomorrow":
                return .read(.tomorrow)

            case "this_week":
                return .read(.thisWeek)

            case "next_week":
                return .read(.nextWeek)

            case "next_weeks":
                let weekCount = min(max(response.weekCount ?? 3, 1), 8)
                return .read(.nextWeeks(weekCount))

            default:
                return .none
            }

        case "create":
            guard let title = response.title?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  let startDateTime = response.startDateTime,
                  let startDate = parseDate(startDateTime) else {
                return .clarify("What date and time should I use for that event?")
            }

            let durationMinutes = min(max(response.durationMinutes ?? 30, 5), 24 * 60)

            return .create(
                title: title,
                startDate: startDate,
                duration: TimeInterval(durationMinutes * 60)
            )

        default:
            return .none
        }
    }

    private func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)
    }

    private func isTodayCalendarQuery(_ lower: String) -> Bool {
        let mentionsCalendar =
            lower.contains("calendar") ||
            lower.contains("schedule") ||
            lower.contains("agenda")

        let asksToday =
            lower.contains("today") ||
            lower.contains("this morning") ||
            lower.contains("this afternoon") ||
            lower.contains("tonight")

        let asksToRead =
            lower.contains("what") ||
            lower.contains("check") ||
            lower.contains("show") ||
            lower.contains("tell me") ||
            lower.contains("do i have")

        return mentionsCalendar && asksToday && asksToRead
    }

    private func isTomorrowCalendarQuery(_ lower: String) -> Bool {
        let mentionsCalendar =
            lower.contains("calendar") ||
            lower.contains("schedule") ||
            lower.contains("agenda")

        let asksToRead =
            lower.contains("what") ||
            lower.contains("check") ||
            lower.contains("show") ||
            lower.contains("tell me") ||
            lower.contains("do i have")

        return mentionsCalendar && lower.contains("tomorrow") && asksToRead
    }

    private func isThisWeekCalendarQuery(_ lower: String) -> Bool {
        calendarReadIntent(lower) &&
            (lower.contains("this week") ||
             lower.contains("happening this week"))
    }

    private func isNextWeekCalendarQuery(_ lower: String) -> Bool {
        calendarReadIntent(lower) &&
            lower.contains("next week") &&
            parseUpcomingWeeksCalendarQuery(lower) == nil
    }

    private func parseUpcomingWeeksCalendarQuery(_ lower: String) -> Int? {
        guard calendarReadIntent(lower) else {
            return nil
        }

        let pattern = #"\bnext\s+(\d+|one|two|three|four|five|six|seven|eight)\s+weeks?\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: lower,
                range: NSRange(lower.startIndex..., in: lower)
              ),
              let amountRange = Range(match.range(at: 1), in: lower) else {
            return nil
        }

        let amountText = String(lower[amountRange])
        let wordNumbers = [
            "one": 1,
            "two": 2,
            "three": 3,
            "four": 4,
            "five": 5,
            "six": 6,
            "seven": 7,
            "eight": 8
        ]

        return Int(amountText) ?? wordNumbers[amountText]
    }

    private func calendarReadIntent(_ lower: String) -> Bool {
        let mentionsCalendar =
            lower.contains("calendar") ||
            lower.contains("schedule") ||
            lower.contains("agenda") ||
            lower.contains("happening")

        let asksToRead =
            lower.contains("what") ||
            lower.contains("check") ||
            lower.contains("show") ||
            lower.contains("tell me") ||
            lower.contains("do i have") ||
            lower.contains("what's") ||
            lower.contains("whats")

        return mentionsCalendar && asksToRead
    }

    private func parseCalendarEvent(
        _ command: String
    ) -> (title: String, startDate: Date, duration: TimeInterval)? {

        let lower = command.lowercased()

        guard lower.contains("calendar event") ||
              lower.contains("add event") ||
              lower.contains("create event") ||
              lower.contains("schedule ") else {
            return nil
        }

        guard let startDate = parseEventStartDate(from: lower) else {
            return nil
        }

        let duration = parseEventDuration(from: lower) ?? 30 * 60
        let title = parseEventTitle(from: command)

        guard !title.isEmpty else {
            return nil
        }

        return (title: title, startDate: startDate, duration: duration)
    }

    private func parseEventTitle(from command: String) -> String {
        var title = command

        let leadingPatterns = [
            #"(?i)^\s*please\s+"#,
            #"(?i)^\s*add\s+(a\s+)?"#,
            #"(?i)^\s*create\s+(a\s+)?"#,
            #"(?i)^\s*schedule\s+"#,
            #"(?i)^\s*put\s+"#,
            #"(?i)\s+on\s+my\s+calendar\s*"#,
            #"(?i)\s+to\s+my\s+calendar\s*"#,
            #"(?i)\s+calendar\s+event\s+"#,
            #"(?i)\s+event\s+(called|named)\s+"#,
            #"(?i)^\s*(called|named)\s+"#,
            #"(?i)^\s*event\s+"#
        ]

        for pattern in leadingPatterns {
            title = title.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        let cutoffPatterns = [
            #"(?i)\s+(today|tomorrow)\b"#,
            #"(?i)\s+at\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b"#,
            #"(?i)\s+for\s+\d+\s*(minutes?|mins?|hours?|hrs?)\b"#
        ]

        for pattern in cutoffPatterns {
            if let range = title.range(
                of: pattern,
                options: .regularExpression
            ) {
                title = String(title[..<range.lowerBound])
            }
        }

        return title
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'.,"))
    }

    private func parseEventStartDate(from lower: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        let dayOffset: Int

        if lower.contains("tomorrow") {
            dayOffset = 1
        } else if lower.contains("today") {
            dayOffset = 0
        } else {
            return nil
        }

        guard let day = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ) else {
            return nil
        }

        guard let time = parseClockTime(from: lower) else {
            return nil
        }

        return calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: day
        )
    }

    private func parseClockTime(from lower: String) -> (hour: Int, minute: Int)? {
        let pattern = #"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: lower,
                range: NSRange(lower.startIndex..., in: lower)
              ),
              let hourRange = Range(match.range(at: 1), in: lower),
              var hour = Int(lower[hourRange]) else {
            return nil
        }

        var minute = 0

        if let minuteRange = Range(match.range(at: 2), in: lower),
           let parsedMinute = Int(lower[minuteRange]) {
            minute = parsedMinute
        }

        if let meridiemRange = Range(match.range(at: 3), in: lower) {
            let meridiem = String(lower[meridiemRange])

            if meridiem == "pm", hour < 12 {
                hour += 12
            }

            if meridiem == "am", hour == 12 {
                hour = 0
            }
        }

        guard (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return (hour: hour, minute: minute)
    }

    private func parseEventDuration(from lower: String) -> TimeInterval? {
        let pattern = #"\bfor\s+(\d+)\s*(minutes?|mins?|hours?|hrs?)\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: lower,
                range: NSRange(lower.startIndex..., in: lower)
              ),
              let amountRange = Range(match.range(at: 1), in: lower),
              let unitRange = Range(match.range(at: 2), in: lower),
              let amount = Double(lower[amountRange]) else {
            return nil
        }

        let unit = String(lower[unitRange])

        if unit.hasPrefix("hour") || unit.hasPrefix("hr") {
            return amount * 60 * 60
        }

        return amount * 60
    }

    private func extractJSONObject(from response: String) -> String {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}"),
              start <= end else {
            return response
        }

        return String(response[start...end])
    }
}
