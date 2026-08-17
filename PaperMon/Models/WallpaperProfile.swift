import Foundation

enum WallpaperScaling: String, Codable, CaseIterable, Identifiable, Sendable {
    case fill
    case fit
    case stretch
    case center

    var id: Self { self }

    var title: String {
        switch self {
        case .fill: "Fill Screen"
        case .fit: "Fit to Screen"
        case .stretch: "Stretch to Fill"
        case .center: "Center"
        }
    }
}

struct WallpaperPresentation: Codable, Hashable, Sendable {
    var scaling: WallpaperScaling = .fill
    var fillColorHex = "#000000"
}

enum ImageStorage: Codable, Hashable, Sendable {
    case managed(relativePath: String)
    case securityScopedBookmark(Data)
}

struct ImageAsset: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var displayName: String
    var storage: ImageStorage
    var contentHash: String?
}

struct DisplayAssignment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var displayName: String
    var fingerprint: DisplayFingerprint
    var normalizedFrame: DisplayFrame
    var image: ImageAsset?
    var presentation = WallpaperPresentation()
}

struct WallpaperProfile: Identifiable, Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var id = UUID()
    var schemaVersion = currentSchemaVersion
    var name: String
    var createdAt = Date()
    var updatedAt = Date()
    var assignments: [DisplayAssignment]

    mutating func markUpdated() {
        updatedAt = Date()
    }
}

struct ProfileLibrary: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var profiles: [WallpaperProfile] = []
    var activeProfileID: WallpaperProfile.ID?

    static let empty = ProfileLibrary()
}

