import AppKit
import CryptoKit
import Foundation

enum ImageImportMode: Sendable {
    case managedCopy
    case referenceOriginal
}

enum ImageLibraryError: LocalizedError {
    case unreadableImage
    case missingManagedImage(String)
    case staleBookmark

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "The selected file is not a readable image."
        case let .missingManagedImage(name):
            "The imported image “\(name)” is missing."
        case .staleBookmark:
            "PaperMon can no longer access this image. Choose it again to repair the profile."
        }
    }
}

final class ResolvedImageAccess: @unchecked Sendable {
    let url: URL
    private let shouldStopAccessing: Bool

    init(url: URL, shouldStopAccessing: Bool) {
        self.url = url
        self.shouldStopAccessing = shouldStopAccessing
    }

    deinit {
        if shouldStopAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

struct ImageLibraryService: Sendable {
    let imagesDirectory: URL

    init(imagesDirectory: URL = Self.defaultImagesDirectory()) {
        self.imagesDirectory = imagesDirectory
    }

    func importImage(from sourceURL: URL, mode: ImageImportMode) throws -> ImageAsset {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard NSImage(contentsOf: sourceURL) != nil else {
            throw ImageLibraryError.unreadableImage
        }

        let data = try Data(contentsOf: sourceURL)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        switch mode {
        case .managedCopy:
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            let safeName = sourceURL.lastPathComponent.replacingOccurrences(of: "/", with: "-")
            let relativePath = "\(UUID().uuidString)-\(safeName)"
            let destination = imagesDirectory.appendingPathComponent(relativePath, isDirectory: false)
            try data.write(to: destination, options: .atomic)
            return ImageAsset(displayName: sourceURL.lastPathComponent, storage: .managed(relativePath: relativePath), contentHash: hash)

        case .referenceOriginal:
            let bookmark = try sourceURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return ImageAsset(displayName: sourceURL.lastPathComponent, storage: .securityScopedBookmark(bookmark), contentHash: hash)
        }
    }

    func resolve(_ asset: ImageAsset) throws -> ResolvedImageAccess {
        switch asset.storage {
        case let .managed(relativePath):
            let url = imagesDirectory.appendingPathComponent(relativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ImageLibraryError.missingManagedImage(asset.displayName)
            }
            return ResolvedImageAccess(url: url, shouldStopAccessing: false)

        case let .securityScopedBookmark(data):
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard !isStale else { throw ImageLibraryError.staleBookmark }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            return ResolvedImageAccess(url: url, shouldStopAccessing: didStartAccessing)
        }
    }

    static func defaultImagesDirectory(fileManager: FileManager = .default) -> URL {
        let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        return pictures.appendingPathComponent("PaperMon", isDirectory: true)
    }

    static func legacyManagedImagesDirectory(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("PaperMon", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

}
