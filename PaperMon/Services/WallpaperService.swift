import AppKit
import Foundation

@MainActor
protocol WallpaperApplying {
    func currentState(for displayID: UInt32) -> DesktopWallpaperState?
    func apply(imageURL: URL, presentation: WallpaperPresentation, to displayID: UInt32) async throws
    func apply(_ requests: [WallpaperRequest]) async throws
    func restore(_ state: DesktopWallpaperState, to displayID: UInt32) async throws
}

extension WallpaperApplying {
    func apply(_ requests: [WallpaperRequest]) async throws {
        for request in requests {
            try await apply(
                imageURL: request.imageURL,
                presentation: request.presentation,
                to: request.displayID
            )
        }
    }
}

struct WallpaperRequest {
    let displayID: UInt32
    let imageURL: URL
    let presentation: WallpaperPresentation
}

struct DesktopWallpaperState {
    let imageURL: URL
    let options: [NSWorkspace.DesktopImageOptionKey: Any]
}

@MainActor
struct WallpaperService: WallpaperApplying {
    private let workspace = NSWorkspace.shared

    func currentState(for displayID: UInt32) -> DesktopWallpaperState? {
        if Self.requiresMacOS27CompatibilityPath,
           let imageURL = WallpaperStoreCompatibilityService.currentImageURL(for: displayID) {
            return DesktopWallpaperState(imageURL: imageURL, options: [:])
        }

        guard let screen = screen(for: displayID),
              let imageURL = workspace.desktopImageURL(for: screen) else {
            return nil
        }

        return DesktopWallpaperState(
            imageURL: imageURL,
            options: workspace.desktopImageOptions(for: screen) ?? [:]
        )
    }

    func apply(imageURL: URL, presentation: WallpaperPresentation, to displayID: UInt32) async throws {
        guard let screen = screen(for: displayID) else {
            throw WallpaperServiceError.displayDisconnected
        }

        if Self.requiresMacOS27CompatibilityPath {
            try await WallpaperStoreCompatibilityService.apply(
                [WallpaperRequest(displayID: displayID, imageURL: imageURL, presentation: presentation)]
            )
            return
        }

        try await setAndConfirm(
            imageURL,
            for: screen,
            options: options(for: presentation)
        )
    }

    func apply(_ requests: [WallpaperRequest]) async throws {
        if Self.requiresMacOS27CompatibilityPath {
            try await WallpaperStoreCompatibilityService.apply(requests)
            return
        }

        for request in requests {
            try await apply(
                imageURL: request.imageURL,
                presentation: request.presentation,
                to: request.displayID
            )
        }
    }

    func restore(_ state: DesktopWallpaperState, to displayID: UInt32) async throws {
        guard let screen = screen(for: displayID) else {
            throw WallpaperServiceError.displayDisconnected
        }

        if Self.requiresMacOS27CompatibilityPath {
            try await WallpaperStoreCompatibilityService.apply(
                [
                    WallpaperRequest(
                        displayID: displayID,
                        imageURL: state.imageURL,
                        presentation: WallpaperPresentation()
                    ),
                ]
            )
            return
        }

        try await setAndConfirm(state.imageURL, for: screen, options: state.options)
    }

    private static var requiresMacOS27CompatibilityPath: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

    private func screen(for displayID: UInt32) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
    }

    private func setAndConfirm(
        _ imageURL: URL,
        for screen: NSScreen,
        options: [NSWorkspace.DesktopImageOptionKey: Any]
    ) async throws {
        try Task.checkCancellation()

        if urlsReferToSameFile(workspace.desktopImageURL(for: screen), imageURL) {
            return
        }

        try workspace.setDesktopImageURL(imageURL, for: screen, options: options)

        // WallpaperImageExtension processes these requests asynchronously and can reject
        // overlapping changes. Give it time to consume this image before checking or
        // submitting work for the next display.
        try await Task.sleep(for: .seconds(4))

        if try await waitForWallpaper(imageURL, on: screen) {
            return
        }

        throw WallpaperServiceError.applicationNotConfirmed(screen.localizedName)
    }

    private func waitForWallpaper(_ expectedURL: URL, on screen: NSScreen) async throws -> Bool {
        for poll in 0..<6 {
            if urlsReferToSameFile(workspace.desktopImageURL(for: screen), expectedURL) {
                return true
            }

            if poll < 5 {
                try await Task.sleep(for: .seconds(1))
            }
        }

        return false
    }

    private func urlsReferToSameFile(_ currentURL: URL?, _ expectedURL: URL) -> Bool {
        guard let currentURL else { return false }
        return currentURL.standardizedFileURL.resolvingSymlinksInPath()
            == expectedURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func options(for presentation: WallpaperPresentation) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        let scaling: NSImageScaling
        let allowClipping: Bool

        switch presentation.scaling {
        case .fill:
            scaling = .scaleProportionallyUpOrDown
            allowClipping = true
        case .fit:
            scaling = .scaleProportionallyUpOrDown
            allowClipping = false
        case .stretch:
            scaling = .scaleAxesIndependently
            allowClipping = true
        case .center:
            scaling = .scaleNone
            allowClipping = true
        }

        return [
            .imageScaling: NSNumber(value: scaling.rawValue),
            .allowClipping: NSNumber(value: allowClipping),
            .fillColor: NSColor(hex: presentation.fillColorHex) ?? .black,
        ]
    }
}

enum WallpaperServiceError: LocalizedError {
    case displayDisconnected
    case applicationNotConfirmed(String)

    var errorDescription: String? {
        switch self {
        case .displayDisconnected:
            "The display disconnected before its wallpaper could be changed."
        case let .applicationNotConfirmed(displayName):
            "macOS did not confirm the wallpaper change for \(displayName)."
        }
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard normalized.count == 6, let value = Int(normalized, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
