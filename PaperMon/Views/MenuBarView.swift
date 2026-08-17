import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open PaperMon") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        SettingsLink()

        Divider()

        Button("Quit PaperMon") {
            NSApplication.shared.terminate(nil)
        }
    }
}

