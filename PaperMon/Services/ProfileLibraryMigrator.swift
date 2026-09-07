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
              fileManager.fileExists(atPath: sourceURL.path) else {
            return false
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return true
        }

        let sourceRepository = ProfileRepository(libraryURL: sourceURL)
        let destinationRepository = ProfileRepository(libraryURL: destinationURL)
        let sourceLibrary = try sourceRepository.load()
        var destinationLibrary = try destinationRepository.load()
        var changed = false

        for sourceProfile in sourceLibrary.profiles {
            if let index = destinationLibrary.profiles.firstIndex(where: { $0.id == sourceProfile.id }) {
                guard sourceProfile.updatedAt > destinationLibrary.profiles[index].updatedAt else { continue }
                destinationLibrary.profiles[index] = sourceProfile
            } else {
                destinationLibrary.profiles.append(sourceProfile)
            }
            changed = true
        }

        if destinationLibrary.activeProfileID == nil,
           let sourceActiveProfileID = sourceLibrary.activeProfileID,
           destinationLibrary.profiles.contains(where: { $0.id == sourceActiveProfileID }) {
            destinationLibrary.activeProfileID = sourceActiveProfileID
            changed = true
        }

        guard changed else { return false }
        try destinationRepository.save(destinationLibrary)
        return true
    }
}
