import SwiftUI

struct SettingsView: View {
    @AppStorage("restoreActiveProfileOnLaunch") private var restoreOnLaunch = true
    @AppStorage("restoreActiveProfileOnDisplayChange") private var restoreOnDisplayChange = true

    var body: some View {
        Form {
            Section("Restoration") {
                Toggle("Restore the active profile when PaperMon opens", isOn: $restoreOnLaunch)
                Toggle("Restore when the display arrangement changes", isOn: $restoreOnDisplayChange)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 230)
        .navigationTitle("PaperMon Settings")
    }
}

