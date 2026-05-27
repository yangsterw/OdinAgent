//
//  OdinCommandService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//

import Foundation
import AppKit

final class OdinCommandService {
    private let trelloService = OdinTrelloService()
    private let trelloIntentService = OdinTrelloIntentService()
    private let calendarService = OdinCalendarService()
    private let calendarIntentService = OdinCalendarIntentService()
    
    private let bundleIDs: [String: String] = [
        "Spotify": "com.spotify.client",
        "Safari": "com.apple.Safari",
        "Visual Studio Code": "com.microsoft.VSCode",
        "Xcode": "com.apple.dt.Xcode",
        "Terminal": "com.apple.Terminal",
        "Microsoft Outlook": "com.microsoft.Outlook"
    ]
    
    private func parseTrelloTask(
        _ command: String
    ) -> (listName: String, title: String)? {

        let lower = command.lowercased()

        guard lower.contains("add a task") ||
              lower.contains("add task") else {
            return nil
        }

        let listAliases: [String: String] = [
            "today's highest priority": "today's highest priority",
            "todays highest priority": "today's highest priority",
            "today highest priority": "today's highest priority",
            "highest priority": "today's highest priority",

            "in progress": "in progress",
            "progress": "in progress",

            "upcoming priorities": "upcoming priorities",
            "upcoming priority": "upcoming priorities",
            "upcoming": "upcoming priorities",

            "future consideration": "future consideration",
            "future": "future consideration",

            "blocked": "blocked"
        ]

        var matchedListName = "today's highest priority"

        for alias in listAliases.keys.sorted(by: { $0.count > $1.count }) {
            if lower.contains(alias) {
                matchedListName = listAliases[alias] ?? matchedListName
                break
            }
        }

        let titleMarkers = [
            "the task is",
            "task is",
            "called",
            "named",
            "to do",
            "todo"
        ]

        for marker in titleMarkers {
            if let range = command.range(of: marker, options: .caseInsensitive) {
                let titleSlice = command[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'., "))

                if !titleSlice.isEmpty {
                    return (
                        listName: matchedListName,
                        title: String(titleSlice)
                    )
                }
            }
        }

        return nil
    }
    
    func handle(_ command: String) async -> String? {
        let lower = command.lowercased()

        if shouldTryTrelloIntentParser(lower),
           let intentResponse = await handleTrelloIntent(command) {
            return intentResponse
        }

        if let trelloTask = parseTrelloTask(command) {
            return await trelloService.addTask(
                title: trelloTask.title,
                toList: trelloTask.listName
            )
        }

        if shouldTryCalendarIntentParser(lower),
           let intentResponse = await handleCalendarIntent(command) {
            return intentResponse
        }

        if isTodayCalendarQuery(lower) {
            return await calendarService.todaysSchedule()
        }

        if isTomorrowCalendarQuery(lower) {
            return await calendarService.tomorrowsSchedule()
        }

        if let weekCount = parseUpcomingWeeksCalendarQuery(lower) {
            return await calendarService.upcomingWeeksSchedule(weekCount)
        }

        if isThisWeekCalendarQuery(lower) {
            return await calendarService.thisWeeksSchedule()
        }

        if isNextWeekCalendarQuery(lower) {
            return await calendarService.nextWeeksSchedule()
        }

        if let eventRequest = parseCalendarEvent(command) {
            return await calendarService.addEvent(
                title: eventRequest.title,
                startDate: eventRequest.startDate,
                duration: eventRequest.duration
            )
        }

        if lower.contains("open spotify") {
            openApp(named: "Spotify")
            return "Opening Spotify."
        }

        if lower.contains("open safari") {
            openApp(named: "Safari")
            return "Opening Safari."
        }

        if lower.contains("open xcode") {
            openApp(named: "Xcode")
            return "Opening Xcode."
        }

        if lower.contains("open visual studio code") ||
            lower.contains("open vscode") {

            openApp(named: "Visual Studio Code")
            return "Opening Visual Studio Code."
        }
        
        if lower.contains("open visual studio code") ||
            lower.contains("open vs code") {

            openApp(named: "Visual Studio Code")
            return "Opening Visual Studio Code."
        }

        if lower.contains("open terminal") {
            openApp(named: "Terminal")
            return "Opening Terminal."
        }

        if lower.contains("open outlook") {
            openApp(named: "Microsoft Outlook")
            return "Opening Outlook."
        }
        
        if lower.contains("open email") {
            openApp(named: "Microsoft Outlook")
            return "Opening Email."
        }
        
        if lower.contains("quit spotify") ||
            lower.contains("close spotify") {
            quitApp(named: "Spotify")
            return "Closing Spotify."
        }

        if lower.contains("quit safari") ||
            lower.contains("close safari") {
            quitApp(named: "Safari")
            return "Closing Safari."
        }

        if lower.contains("quit outlook") ||
            lower.contains("close outlook") {
            quitApp(named: "Microsoft Outlook")
            return "Closing Outlook."
        }

        if lower.contains("quit visual studio code") ||
            lower.contains("close visual studio code") ||
            lower.contains("quit vscode") ||
            lower.contains("close vscode") {
            quitApp(named: "Visual Studio Code")
            return "Closing Visual Studio Code."
        }

        if lower.contains("quit xcode") ||
            lower.contains("close xcode") {
            quitApp(named: "Xcode")
            return "Closing Xcode."
        }

        if lower.contains("quit terminal") ||
            lower.contains("close terminal") {
            quitApp(named: "Terminal")
            return "Closing Terminal."
        }
        if lower.contains("quit odin") ||
            lower.contains("close odin") ||
            lower.contains("exit odin") {

            await MainActor.run {
                NSApplication.shared.terminate(nil)
            }
            return "Goodbye."
        }

        return nil
    }

    private func handleTrelloIntent(_ command: String) async -> String? {
        guard let intent = await trelloIntentService.parse(command) else {
            return nil
        }

        switch intent {
        case .none:
            return nil

        case .clarify(let question):
            return question

        case .addTask(let title, let listName):
            return await trelloService.addTask(
                title: title,
                toList: listName
            )
        }
    }

    private func shouldTryTrelloIntentParser(_ lower: String) -> Bool {
        let trelloSignals = [
            "trello",
            "task",
            "tasks",
            "card",
            "cards",
            "todo",
            "to do",
            "highest priority",
            "priority",
            "in progress",
            "upcoming",
            "future consideration",
            "blocked"
        ]

        let createSignals = [
            "add",
            "create",
            "put",
            "make",
            "remember"
        ]

        return trelloSignals.contains { lower.contains($0) } &&
            createSignals.contains { lower.contains($0) }
    }

    private func handleCalendarIntent(_ command: String) async -> String? {
        guard let intent = await calendarIntentService.parse(command) else {
            return nil
        }

        switch intent {
        case .none:
            return nil

        case .clarify(let question):
            return question

        case .read(let range):
            switch range {
            case .today:
                return await calendarService.todaysSchedule()

            case .tomorrow:
                return await calendarService.tomorrowsSchedule()

            case .thisWeek:
                return await calendarService.thisWeeksSchedule()

            case .nextWeek:
                return await calendarService.nextWeeksSchedule()

            case .nextWeeks(let weekCount):
                return await calendarService.upcomingWeeksSchedule(weekCount)
            }

        case .create(let title, let startDate, let duration):
            return await calendarService.addEvent(
                title: title,
                startDate: startDate,
                duration: duration
            )
        }
    }

    private func shouldTryCalendarIntentParser(_ lower: String) -> Bool {
        let calendarSignals = [
            "calendar",
            "schedule",
            "agenda",
            "meeting",
            "meetings",
            "appointment",
            "appointments",
            "busy",
            "free",
            "available",
            "availability",
            "coming up",
            "this week",
            "next week",
            "next few weeks",
            "week looking",
            "my week",
            "tomorrow",
            "today"
        ]

        return calendarSignals.contains { lower.contains($0) }
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

    @MainActor
    private func openApp(named appName: String) {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/Applications/\(appName).app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
    
    @MainActor
    private func quitApp(named appName: String) {
        guard let bundleID = bundleIDs[appName] else {
            print("Unknown bundle ID for \(appName)")
            return
        }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

        if let app = runningApps.first {
            app.terminate()
            print("Terminate command sent to \(appName)")
        } else {
            print("\(appName) is not running")
        }
    }
}
