import Foundation

struct ManagedImageMigrator {
    let sourceDirectory: URL
    let destinationDirectory: URL
    var fileManager: FileManager = .default

    @discardableResult
    func migrateIfNeeded() throws -> Int {
        guard sourceDirectory.standardizedFileURL != destinationDirectory.standardizedFileURL,
              fileManager.fileExists(atPath: sourceDirectory.path) else {
            return 0
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let sourceFiles = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var migratedFileCount = 0

        for sourceFile in sourceFiles {
            let values = try sourceFile.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let destinationFile = destinationDirectory.appendingPathComponent(
                sourceFile.lastPathComponent,
                isDirectory: false
            )
            guard !fileManager.fileExists(atPath: destinationFile.path) else { continue }

            try fileManager.copyItem(at: sourceFile, to: destinationFile)
            migratedFileCount += 1
        }

        return migratedFileCount
    }
}
