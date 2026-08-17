import AppKit
import Foundation

@MainActor
protocol WallpaperApplying {
    func currentState(for displayID: UInt32) -> DesktopWallpaperState?
    func apply(imageURL: URL, presentation: WallpaperPresentation, to displayID: UInt32) throws
    func restore(_ state: DesktopWallpaperState, to displayID: UInt32) throws
}

struct DesktopWallpaperState {
    let imageURL: URL
    let options: [NSWorkspace.DesktopImageOptionKey: Any]
}

@MainActor
struct WallpaperService: WallpaperApplying {
    private let workspace = NSWorkspace.shared

    func currentState(for displayID: UInt32) -> DesktopWallpaperState? {
        guard let screen = screen(for: displayID),
              let imageURL = workspace.desktopImageURL(for: screen) else {
            return nil
        }

        return DesktopWallpaperState(
            imageURL: imageURL,
            options: workspace.desktopImageOptions(for: screen) ?? [:]
        )
    }

    func apply(imageURL: URL, presentation: WallpaperPresentation, to displayID: UInt32) throws {
        guard let screen = screen(for: displayID) else {
            throw WallpaperServiceError.displayDisconnected
        }

        try workspace.setDesktopImageURL(imageURL, for: screen, options: options(for: presentation))
    }

    func restore(_ state: DesktopWallpaperState, to displayID: UInt32) throws {
        guard let screen = screen(for: displayID) else {
            throw WallpaperServiceError.displayDisconnected
        }

        try workspace.setDesktopImageURL(state.imageURL, for: screen, options: state.options)
    }

    private func screen(for displayID: UInt32) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID }
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

    var errorDescription: String? {
        "The display disconnected before its wallpaper could be changed."
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

