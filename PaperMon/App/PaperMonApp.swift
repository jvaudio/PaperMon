import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct PaperMonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("PaperMon", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1_080, height: 720)

        MenuBarExtra("PaperMon", systemImage: "rectangle.3.group") {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
    }
}

