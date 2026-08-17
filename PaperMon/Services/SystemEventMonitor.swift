import AppKit

@MainActor
final class SystemEventMonitor: NSObject {
    private let onDisplayChange: () -> Void
    private let onWake: () -> Void

    init(onDisplayChange: @escaping () -> Void, onWake: @escaping () -> Void) {
        self.onDisplayChange = onDisplayChange
        self.onWake = onWake
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func displayConfigurationChanged() {
        onDisplayChange()
    }

    @objc private func workspaceDidWake() {
        onWake()
    }
}

