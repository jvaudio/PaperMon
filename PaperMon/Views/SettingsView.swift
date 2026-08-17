import SwiftUI

struct SettingsView: View {
    @AppStorage("restoreActiveProfileOnLaunch") private var restoreOnLaunch = true
    @AppStorage("restoreActiveProfileOnDisplayChange") private var restoreOnDisplayChange = true
    @AppStorage("imageImportMode") private var imageImportMode = "managed"

    var body: some View {
        Form {
            Section("Restoration") {
                Toggle("Restore the active profile when PaperMon opens", isOn: $restoreOnLaunch)
                Toggle("Restore when the display arrangement changes", isOn: $restoreOnDisplayChange)
            }

            Section("Images") {
                Picker("When choosing an image", selection: $imageImportMode) {
                    Text("Copy into PaperMon").tag("managed")
                    Text("Reference the original").tag("reference")
                }
                Text(imageImportMode == "managed"
                     ? "Imported images remain available if the original is moved or deleted."
                     : "PaperMon keeps permission to access the original file without duplicating it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 330)
        .navigationTitle("PaperMon Settings")
    }
}
