import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("restoreActiveProfileOnLaunch") private var restoreOnLaunch = true
    @AppStorage("restoreActiveProfileOnDisplayChange") private var restoreOnDisplayChange = true
    @AppStorage("imageImportMode") private var imageImportMode = "managed"
    @State private var loginItemManager = LoginItemManager()

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Open PaperMon at login",
                    isOn: Binding(
                        get: { loginItemManager.status.isEnabled },
                        set: { loginItemManager.setEnabled($0) }
                    )
                )
                .disabled(loginItemManager.isChanging || loginItemManager.status == .unavailable)

                if loginItemManager.status == .requiresApproval {
                    LabeledContent {
                        Button("Open Login Items") {
                            loginItemManager.openSystemSettings()
                        }
                    } label: {
                        Text("Approval is required in System Settings before PaperMon can open automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if loginItemManager.status == .unavailable {
                    Text("Launch at Login is unavailable for this copy of PaperMon. Move the app to Applications and try again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
        .frame(width: 560, height: 440)
        .navigationTitle("PaperMon Settings")
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                loginItemManager.refresh()
            }
        }
        .alert(
            "Couldn’t Update Launch at Login",
            isPresented: Binding(
                get: { loginItemManager.errorMessage != nil },
                set: { if !$0 { loginItemManager.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                loginItemManager.errorMessage = nil
            }
        } message: {
            Text(loginItemManager.errorMessage ?? "An unknown error occurred.")
        }
    }
}
