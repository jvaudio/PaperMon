import Foundation

struct ProfileLibraryMigrator {
    let sourceURL: URL
    let destinationURL: URL
    let fileManager: FileManager

    init(
        sourceURL: URL,
        destinationURL: URL,
        fileManager: FileManager = .default
    ) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.fileManager = fileManager
    }

    @discardableResult
    func migrateIfNeeded() throws -> Bool {
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL,
              fileManager.fileExists(atPath: sourceURL.path),
              !fileManager.fileExists(atPath: destinationURL.path) else {
            return false
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return true
    }
}
