import Foundation
import EventKit

protocol OdinCalendarManaging {
    func todaysSchedule() async -> String
    func tomorrowsSchedule() async -> String
    func thisWeeksSchedule() async -> String
    func nextWeeksSchedule() async -> String
    func upcomingWeeksSchedule(_ weekCount: Int) async -> String

    func addEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval
    ) async -> String
}

final class OdinCalendarService {

    private let eventStore = EKEventStore()

    func todaysSchedule() async -> String {
        await schedule(forDayOffset: 0, label: "today")
    }

    func tomorrowsSchedule() async -> String {
        await schedule(forDayOffset: 1, label: "tomorrow")
    }

    func thisWeeksSchedule() async -> String {
        let calendar = Calendar.current
        let now = Date()

        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return "I could not work out this week's calendar range."
        }

        return await schedule(
            from: week.start,
            to: week.end,
            label: "this week",
            maxEventsToSpeak: 10
        )
    }

    func nextWeeksSchedule() async -> String {
        let calendar = Calendar.current
        let now = Date()

        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let nextWeekStart = calendar.date(
                byAdding: .weekOfYear,
                value: 1,
                to: thisWeek.start
              ),
              let nextWeek = calendar.dateInterval(
                of: .weekOfYear,
                for: nextWeekStart
              ) else {
            return "I could not work out next week's calendar range."
        }

        return await schedule(
            from: nextWeek.start,
            to: nextWeek.end,
            label: "next week",
            maxEventsToSpeak: 10
        )
    }

    func upcomingWeeksSchedule(_ weekCount: Int) async -> String {
        let calendar = Calendar.current
        let now = Date()
        let safeWeekCount = min(max(weekCount, 1), 8)
        let start = calendar.startOfDay(for: now)

        guard let end = calendar.date(
            byAdding: .weekOfYear,
            value: safeWeekCount,
            to: start
        ) else {
            return "I could not work out the calendar range."
        }

        let label = safeWeekCount == 1
            ? "the next week"
            : "the next \(safeWeekCount) weeks"

        return await schedule(
            from: start,
            to: end,
            label: label,
            maxEventsToSpeak: 12
        )
    }

    func addEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval
    ) async -> String {

        guard await requestCalendarAccess() else {
            return "I need Calendar access before I can add events."
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            return "I could not find a default calendar to add the event to."
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return "I need an event title before I can add it to your calendar."
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = trimmedTitle
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)

            return "I added \(trimmedTitle) to your calendar for \(formatEventTime(startDate))."

        } catch {
            print("Calendar save error:", error)
            return "I could not save that calendar event."
        }
    }

    private func schedule(forDayOffset dayOffset: Int, label: String) async -> String {
        guard await requestCalendarAccess() else {
            return "I need Calendar access before I can check your schedule."
        }

        let calendar = Calendar.current
        let now = Date()

        guard let day = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
            return "I could not work out the calendar date."
        }

        return await schedule(
            from: day,
            to: nextDay,
            label: label,
            maxEventsToSpeak: 6
        )
    }

    private func schedule(
        from startDate: Date,
        to endDate: Date,
        label: String,
        maxEventsToSpeak: Int
    ) async -> String {
        guard await requestCalendarAccess() else {
            return "I need Calendar access before I can check your schedule."
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        guard !events.isEmpty else {
            return "Your calendar is clear \(label)."
        }

        let eventLines = events
            .prefix(maxEventsToSpeak)
            .map(formatScheduleEvent)
            .joined(separator: "; ")

        if events.count > maxEventsToSpeak {
            return "You have \(events.count) events \(label). First up: \(eventLines)."
        }

        return "You have \(events.count) events \(label): \(eventLines)."
    }

    private func formatScheduleEvent(_ event: EKEvent) -> String {
        let title = event.title ?? "Untitled event"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        if event.isAllDay {
            return "\(dateFormatter.string(from: event.startDate)): All day, \(title)"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short

        return "\(timeFormatter.string(from: event.startDate)): \(title)"
    }

    private func requestCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            return true

        case .notDetermined:
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        print("Calendar permission error:", error)
                    }

                    continuation.resume(returning: granted)
                }
            }

        case .denied, .restricted, .writeOnly:
            return false

        @unknown default:
            return false
        }
    }

    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension OdinCalendarService: OdinCalendarManaging {}
