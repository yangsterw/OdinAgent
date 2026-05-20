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
    
    private func quitApp(named appName: String) {
        let script = """
        tell application "\(appName)"
            quit
        end tell
        """

        var error: NSDictionary?

        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error {
                print("AppleScript quit error:", error)
            } else {
                print("Quit command sent to \(appName)")
            }
        }
    }
}
