import Foundation
import Testing

@testable import PaperMon

struct ProfileLibraryMigratorTests {
    @Test func copiesLegacyLibraryWhenDestinationIsMissing() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy/profiles.json")
        let destination = root.appendingPathComponent("Pictures/PaperMon/profiles.json")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let profileData = Data("{\"profiles\":[\"JKBK\"]}".utf8)
        try profileData.write(to: source)

        let migrated = try ProfileLibraryMigrator(
            sourceURL: source,
            destinationURL: destination
        ).migrateIfNeeded()

        #expect(migrated)
        #expect(try Data(contentsOf: destination) == profileData)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func preservesExistingDestinationLibrary() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy/profiles.json")
        let destination = root.appendingPathComponent("Pictures/PaperMon/profiles.json")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let profile = WallpaperProfile(name: "Current", assignments: [])
        let sourceLibrary = ProfileLibrary(profiles: [profile])
        let destinationLibrary = ProfileLibrary(profiles: [profile])
        try ProfileRepository(libraryURL: source).save(sourceLibrary)
        try ProfileRepository(libraryURL: destination).save(destinationLibrary)

        let migrated = try ProfileLibraryMigrator(
            sourceURL: source,
            destinationURL: destination
        ).migrateIfNeeded()

        #expect(!migrated)
        #expect(try ProfileRepository(libraryURL: destination).load() == destinationLibrary)
    }

    @Test func mergesLegacyProfilesIntoExistingDestination() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy/profiles.json")
        let destination = root.appendingPathComponent("Pictures/PaperMon/profiles.json")
        let legacyProfile = WallpaperProfile(name: "Recovered Desk", assignments: [])
        let currentProfile = WallpaperProfile(name: "New Profile", assignments: [])
        try ProfileRepository(libraryURL: source).save(
            ProfileLibrary(profiles: [legacyProfile], activeProfileID: legacyProfile.id)
        )
        try ProfileRepository(libraryURL: destination).save(
            ProfileLibrary(profiles: [currentProfile], activeProfileID: nil)
        )

        let migrated = try ProfileLibraryMigrator(
            sourceURL: source,
            destinationURL: destination
        ).migrateIfNeeded()
        let merged = try ProfileRepository(libraryURL: destination).load()

        #expect(migrated)
        #expect(Set(merged.profiles.map(\.id)) == Set([legacyProfile.id, currentProfile.id]))
        #expect(merged.activeProfileID == legacyProfile.id)
        #expect(try ProfileRepository(libraryURL: source).load().profiles == [legacyProfile])
    }

    @Test func newerLegacyRevisionRepairsMatchingDestinationProfile() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy/profiles.json")
        let destination = root.appendingPathComponent("Pictures/PaperMon/profiles.json")
        var currentProfile = WallpaperProfile(name: "Incomplete", assignments: [])
        currentProfile.updatedAt = Date(timeIntervalSince1970: 1)
        var recoveredProfile = currentProfile
        recoveredProfile.name = "Recovered"
        recoveredProfile.updatedAt = Date(timeIntervalSince1970: 2)
        try ProfileRepository(libraryURL: source).save(ProfileLibrary(profiles: [recoveredProfile]))
        try ProfileRepository(libraryURL: destination).save(ProfileLibrary(profiles: [currentProfile]))

        _ = try ProfileLibraryMigrator(
            sourceURL: source,
            destinationURL: destination
        ).migrateIfNeeded()

        let merged = try ProfileRepository(libraryURL: destination).load()
        #expect(merged.profiles == [recoveredProfile])
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
