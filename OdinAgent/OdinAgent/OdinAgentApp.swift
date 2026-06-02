import SwiftUI

@main
struct OdinAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Odin", id: "main") {
            OdinMainView()
                .onOpenURL { url in
                    print("Opened from URL:", url)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 380, height: 540)
    }
}
