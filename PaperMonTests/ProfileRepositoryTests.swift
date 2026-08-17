import Foundation
import Testing

@testable import PaperMon

struct ProfileRepositoryTests {
    @Test func missingLibraryLoadsAsEmpty() throws {
        let repository = ProfileRepository(libraryURL: temporaryLibraryURL())

        let library = try repository.load()

        #expect(library == .empty)
    }

    @Test func roundTripsProfileLibrary() throws {
        let repository = ProfileRepository(libraryURL: temporaryLibraryURL())
        let profile = WallpaperProfile(name: "Four Displays", assignments: [])
        let library = ProfileLibrary(profiles: [profile], activeProfileID: profile.id)

        try repository.save(library)
        let restored = try repository.load()

        #expect(restored == library)
    }

    @Test func rejectsFutureSchema() throws {
        let url = temporaryLibraryURL()
        let repository = ProfileRepository(libraryURL: url)
        let futureLibrary = ProfileLibrary(
            schemaVersion: ProfileLibrary.currentSchemaVersion + 1,
            profiles: [],
            activeProfileID: nil
        )
        try repository.save(futureLibrary)

        #expect(throws: ProfileRepository.RepositoryError.self) {
            try repository.load()
        }
    }

    private func temporaryLibraryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }
}

