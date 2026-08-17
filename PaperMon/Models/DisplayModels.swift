import Foundation

enum DisplayOrientation: String, Codable, CaseIterable, Sendable {
    case landscape
    case portrait
    case square

    init(width: Double, height: Double) {
        if abs(width - height) < 1 {
            self = .square
        } else if width > height {
            self = .landscape
        } else {
            self = .portrait
        }
    }
}

struct DisplayFrame: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = DisplayFrame(x: 0, y: 0, width: 0, height: 0)

    var orientation: DisplayOrientation {
        DisplayOrientation(width: width, height: height)
    }
}

struct DisplayFingerprint: Codable, Hashable, Sendable {
    var vendorNumber: UInt32?
    var modelNumber: UInt32?
    var serialNumber: UInt32?
    var localizedName: String
    var pixelWidth: Int
    var pixelHeight: Int
    var orientation: DisplayOrientation
    var isBuiltIn: Bool

    var hardwareKey: String? {
        guard let vendorNumber, let modelNumber, let serialNumber, serialNumber != 0 else {
            return nil
        }

        return "\(vendorNumber)-\(modelNumber)-\(serialNumber)"
    }
}

struct DisplaySnapshot: Identifiable, Hashable, Sendable {
    let id: UInt32
    var fingerprint: DisplayFingerprint
    var frame: DisplayFrame
    var isMain: Bool

    var orientation: DisplayOrientation {
        frame.orientation
    }
}

