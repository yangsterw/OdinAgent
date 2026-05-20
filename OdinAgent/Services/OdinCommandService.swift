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

        if let trelloTask = parseTrelloTask(command) {
            return await trelloService.addTask(
                title: trelloTask.title,
                toList: trelloTask.listName
            )
        }
        
        let lower = command.lowercased()

        if lower.contains("open spotify") {
            await openApp(named: "Spotify")
            return "Opening Spotify."
        }

        if lower.contains("open safari") {
            await openApp(named: "Safari")
            return "Opening Safari."
        }

        if lower.contains("open xcode") {
            await openApp(named: "Xcode")
            return "Opening Xcode."
        }

        if lower.contains("open visual studio code") ||
            lower.contains("open vscode") {

            await openApp(named: "Visual Studio Code")
            return "Opening Visual Studio Code."
        }
        
        if lower.contains("open visual studio code") ||
            lower.contains("open vs code") {

            await openApp(named: "Visual Studio Code")
            return "Opening Visual Studio Code."
        }

        if lower.contains("open terminal") {
            await openApp(named: "Terminal")
            return "Opening Terminal."
        }

        if lower.contains("open outlook") {
            await openApp(named: "Microsoft Outlook")
            return "Opening Outlook."
        }
        
        if lower.contains("open email") {
            await openApp(named: "Microsoft Outlook")
            return "Opening Email."
        }
        
        if lower.contains("quit spotify") ||
            lower.contains("close spotify") {
            await quitApp(named: "Spotify")
            return "Closing Spotify."
        }

        if lower.contains("quit safari") ||
            lower.contains("close safari") {
            await quitApp(named: "Safari")
            return "Closing Safari."
        }

        if lower.contains("quit outlook") ||
            lower.contains("close outlook") {
            await quitApp(named: "Microsoft Outlook")
            return "Closing Outlook."
        }

        if lower.contains("quit visual studio code") ||
            lower.contains("close visual studio code") ||
            lower.contains("quit vscode") ||
            lower.contains("close vscode") {
            await quitApp(named: "Visual Studio Code")
            return "Closing Visual Studio Code."
        }

        if lower.contains("quit xcode") ||
            lower.contains("close xcode") {
            await quitApp(named: "Xcode")
            return "Closing Xcode."
        }

        if lower.contains("quit terminal") ||
            lower.contains("close terminal") {
            await quitApp(named: "Terminal")
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
