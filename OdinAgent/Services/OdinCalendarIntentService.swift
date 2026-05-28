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

    func parse(_ command: String) async -> OdinParsedCalendarIntent? {
        let prompt = buildPrompt(command: command)

        do {
            let response = try await ollamaService.generateResponse(for: prompt)

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

    private func extractJSONObject(from response: String) -> String {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}"),
              start <= end else {
            return response
        }

        return String(response[start...end])
    }
}
