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
    @State private var appModel: AppModel

    init() {
        var migrationError: Error?
        let imageLibrary = ImageLibraryService()

        do {
            try ManagedImageMigrator(
                sourceDirectory: ImageLibraryService.legacyManagedImagesDirectory(),
                destinationDirectory: imageLibrary.imagesDirectory
            ).migrateIfNeeded()

            try ProfileLibraryMigrator(
                sourceURL: ProfileRepository.legacyLibraryURL(),
                destinationURL: ProfileRepository.defaultLibraryURL()
            ).migrateIfNeeded()
        } catch {
            migrationError = error
        }

        let model = AppModel(imageLibrary: imageLibrary)
        if let migrationError {
            model.notice = AppNotice(
                title: "Couldn’t Prepare Wallpaper Library",
                message: "Your existing profiles and images are still safe, but PaperMon couldn’t copy its wallpaper library to the Pictures folder. \(migrationError.localizedDescription)"
            )
        }
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
            SettingsView()
                .environment(appModel)
        }
    }
}
