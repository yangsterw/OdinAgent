//
//  OdinCommandService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//

import Foundation
import AppKit

protocol OdinCommandHandling {
    func handle(
        _ command: String,
        modelName: String
    ) async -> String?
}

final class OdinCommandService {
    private let trelloService: any OdinTrelloManaging
    private let calendarService: any OdinCalendarManaging
    private let calendarIntentService: any OdinCalendarIntentParsing
    private let pendingActionService: any OdinPendingActionManaging
    private let intentRouterService: any OdinIntentRouting

    private let bundleIDs: [String: String] = [
        "Spotify": "com.spotify.client",
        "Safari": "com.apple.Safari",
        "Visual Studio Code": "com.microsoft.VSCode",
        "Xcode": "com.apple.dt.Xcode",
        "Terminal": "com.apple.Terminal",
        "Microsoft Outlook": "com.microsoft.Outlook"
    ]

    init(
        trelloService: any OdinTrelloManaging = OdinTrelloService(),
        trelloIntentService: any OdinTrelloIntentParsing = OdinTrelloIntentService(),
        calendarService: any OdinCalendarManaging = OdinCalendarService(),
        calendarIntentService: any OdinCalendarIntentParsing = OdinCalendarIntentService(),
        pendingActionService: any OdinPendingActionManaging = OdinPendingActionService(),
        intentRouterService: (any OdinIntentRouting)? = nil
    ) {
        self.trelloService = trelloService
        self.calendarService = calendarService
        self.calendarIntentService = calendarIntentService
        self.pendingActionService = pendingActionService
        self.intentRouterService = intentRouterService ?? OdinIntentRouterService(
            trelloService: trelloService,
            trelloIntentService: trelloIntentService,
            calendarIntentService: calendarIntentService
        )
    }

    func handle(
        _ command: String,
        modelName: String = OdinOllamaService.preferredModelName
    ) async -> String? {
        if let pendingResponse = await handlePendingAction(
            command,
            modelName: modelName
        ) {
            return pendingResponse
        }

        switch await intentRouterService.route(command, modelName: modelName) {
        case .none:
            return nil

        case .app(let intent):
            return await handleAppIntent(intent)

        case .calendar(let intent, let originalCommand):
            return await handleCalendarIntent(
                intent,
                originalCommand: originalCommand
            )

        case .trello(let intent, let originalCommand):
            return await handleTrelloIntent(
                intent,
                originalCommand: originalCommand
            )
        }
    }

    private func handlePendingAction(
        _ command: String,
        modelName: String
    ) async -> String? {
        guard let pendingAction = pendingActionService.current() else {
            return nil
        }

        let lower = command.lowercased()

        if isCancelResponse(lower) {
            pendingActionService.clear()
            return "Okay. I cancelled that."
        }

        switch pendingAction {
        case .calendarCreateConfirmation(let title, let startDate, let duration, _):
            if isYesResponse(lower) {
                pendingActionService.clear()
                return await calendarService.addEvent(
                    title: title,
                    startDate: startDate,
                    duration: duration
                )
            }

            if isNoResponse(lower) {
                pendingActionService.clear()
                return "Okay. I did not add that calendar event."
            }

            return calendarCreateConfirmationMessage(
                title: title,
                startDate: startDate
            )

        case .calendarClarification(let originalCommand, _):
            let combinedCommand = """
            Previous incomplete calendar command: \(originalCommand)
            User follow-up: \(command)
            """

            guard let intent = await calendarIntentService.parse(
                combinedCommand,
                modelName: modelName
            ) else {
                return nil
            }

            return await handleCalendarIntent(
                intent,
                originalCommand: combinedCommand
            )

        case .trelloClarification(let originalCommand, _):
            let combinedCommand = """
            Previous incomplete Trello command: \(originalCommand)
            User follow-up: \(command)
            """

            switch await intentRouterService.route(
                combinedCommand,
                modelName: modelName
            ) {
            case .trello(let intent, let originalCommand):
                return await handleTrelloIntent(
                    intent,
                    originalCommand: originalCommand
                )

            default:
                return nil
            }
        }
    }

    private func handleAppIntent(_ intent: OdinAppIntent) async -> String {
        switch intent {
        case .open(let appName, let spokenName):
            await MainActor.run {
                openApp(named: appName)
            }
            return "Opening \(spokenName)."

        case .quit(let appName, let spokenName):
            await MainActor.run {
                quitApp(named: appName)
            }
            return "Closing \(spokenName)."

        case .quitOdin:
            await MainActor.run {
                NSApplication.shared.terminate(nil)
            }
            return "Goodbye."
        }
    }

    private func handleCalendarIntent(
        _ intent: OdinParsedCalendarIntent,
        originalCommand: String
    ) async -> String? {

        switch intent {
        case .none:
            return nil

        case .clarify(let question):
            pendingActionService.set(
                .calendarClarification(
                    originalCommand: originalCommand,
                    createdAt: Date()
                )
            )
            return question

        case .read(let range):
            pendingActionService.clear()
            return await handleCalendarRead(range)

        case .create(let title, let startDate, let duration):
            pendingActionService.set(
                .calendarCreateConfirmation(
                    title: title,
                    startDate: startDate,
                    duration: duration,
                    createdAt: Date()
                )
            )

            return calendarCreateConfirmationMessage(
                title: title,
                startDate: startDate
            )
        }
    }

    private func handleCalendarRead(_ range: OdinCalendarReadRange) async -> String {
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
    }

    private func handleTrelloIntent(
        _ intent: OdinParsedTrelloIntent,
        originalCommand: String
    ) async -> String? {

        switch intent {
        case .none:
            return nil

        case .clarify(let question):
            pendingActionService.set(
                .trelloClarification(
                    originalCommand: originalCommand,
                    createdAt: Date()
                )
            )
            return question

        case .showBoardsAndColumns:
            pendingActionService.clear()
            return await trelloService.boardsAndColumnsSummary()

        case .showTasks(let listName, let boardName):
            pendingActionService.clear()
            return await trelloService.tasks(
                inList: listName,
                onBoard: boardName
            )

        case .addTask(let title, let listName):
            pendingActionService.clear()
            return await trelloService.addTask(
                title: title,
                toList: listName
            )
        }
    }

    private func calendarCreateConfirmationMessage(
        title: String,
        startDate: Date
    ) -> String {
        "Should I add \(title) to your calendar for \(formatCalendarConfirmationTime(startDate))?"
    }

    private func isYesResponse(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)

        let exactMatches = [
            "yes",
            "yeah",
            "yep",
            "sure",
            "confirm",
            "do it",
            "please do",
            "go ahead",
            "that's right",
            "thats right"
        ]

        return exactMatches.contains(trimmed) ||
            trimmed.hasPrefix("yes ") ||
            trimmed.hasPrefix("yeah ") ||
            trimmed.hasPrefix("yep ")
    }

    private func isNoResponse(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)

        let exactMatches = [
            "no",
            "nope",
            "don't",
            "dont",
            "do not",
            "not now",
            "never mind",
            "nevermind"
        ]

        return exactMatches.contains(trimmed) ||
            trimmed.hasPrefix("no ") ||
            trimmed.hasPrefix("nope ")
    }

    private func isCancelResponse(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            "cancel",
            "stop",
            "forget it",
            "never mind",
            "nevermind"
        ].contains(trimmed)
    }

    private func formatCalendarConfirmationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleID
        )

        if let app = runningApps.first {
            app.terminate()
            print("Terminate command sent to \(appName)")
        } else {
            print("\(appName) is not running")
        }
    }
}

extension OdinCommandService: OdinCommandHandling {}
