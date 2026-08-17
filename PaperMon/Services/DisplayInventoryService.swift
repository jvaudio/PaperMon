import AppKit
import CoreGraphics

@MainActor
protocol DisplayInventoryProviding {
    func currentDisplays() -> [DisplaySnapshot]
}

@MainActor
struct DisplayInventoryService: DisplayInventoryProviding {
    func currentDisplays() -> [DisplaySnapshot] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else { return nil }

            let frame = DisplayFrame(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: screen.frame.height
            )
            let pixelWidth = Int(CGDisplayPixelsWide(displayID))
            let pixelHeight = Int(CGDisplayPixelsHigh(displayID))
            let fingerprint = DisplayFingerprint(
                vendorNumber: nonzero(CGDisplayVendorNumber(displayID)),
                modelNumber: nonzero(CGDisplayModelNumber(displayID)),
                serialNumber: nonzero(CGDisplaySerialNumber(displayID)),
                localizedName: screen.localizedName,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                orientation: frame.orientation,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0
            )

            return DisplaySnapshot(
                id: displayID,
                fingerprint: fingerprint,
                frame: frame,
                isMain: displayID == CGMainDisplayID()
            )
        }
    }

    private func nonzero(_ value: UInt32) -> UInt32? {
        value == 0 ? nil : value
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

