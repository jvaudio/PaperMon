import AppKit
import Sparkle
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
    @State private var appModel: AppModel
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let imageLibrary = ImageLibraryService()
        let model = AppModel(imageLibrary: imageLibrary)
        _appModel = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup("PaperMon", id: "main") {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 1_360, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
            }

            CommandMenu("Profile") {
                Button("New Profile") {
                    appModel.createProfile()
                }
                .keyboardShortcut("n")

                Button("Apply Profile") {
                    appModel.applySelectedProfile()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(appModel.profiles.selectedProfileID == nil)
            }
        }

        MenuBarExtra("PaperMon", systemImage: "rectangle.3.group") {
            MenuBarView()
                .environment(appModel)
        }

        Settings {
            SettingsView(updaterController: updaterController)
                .environment(appModel)
        }
        .defaultSize(width: 560, height: 570)
        .windowResizability(.contentSize)
    }
}
