import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if appModel.profiles.profiles.isEmpty {
            Text("No profiles yet")
        } else {
            ForEach(appModel.profiles.profiles) { profile in
                Button {
                    appModel.applyProfile(profile.id)
                } label: {
                    if appModel.profiles.library.activeProfileID == profile.id {
                        Label(shortTitle(profile.name), systemImage: "checkmark")
                    } else {
                        Text(shortTitle(profile.name))
                    }
                }
            }
        }

        Divider()

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

    private func shortTitle(_ title: String) -> String {
        title.count <= 30 ? title : String(title.prefix(27)) + "..."
    }
}
