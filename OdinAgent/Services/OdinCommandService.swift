//
//  OdinCommandService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation
import AppKit

final class OdinCommandService {

    func handle(_ command: String) -> String? {

        let lower = command.lowercased()

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
        if lower.contains("quit odin") ||
            lower.contains("close odin") ||
            lower.contains("exit odin") {

            NSApplication.shared.terminate(nil)
            return "Goodbye."
        }

        return nil
    }

    private func openApp(named appName: String) {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/Applications/\(appName).app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
