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
        try Data("legacy".utf8).write(to: source)
        try Data("current".utf8).write(to: destination)

        let migrated = try ProfileLibraryMigrator(
            sourceURL: source,
            destinationURL: destination
        ).migrateIfNeeded()

        #expect(!migrated)
        #expect(try Data(contentsOf: destination) == Data("current".utf8))
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
