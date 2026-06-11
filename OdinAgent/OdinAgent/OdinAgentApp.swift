import SwiftUI

@main
struct OdinAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let dependencies = OdinDependencyContainer.live

    var body: some Scene {
        Window("Odin", id: "main") {
            OdinMainView(dependencies: dependencies)
                .onOpenURL { url in
                    print("Opened from URL:", url)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 380, height: 540)
    }
}
