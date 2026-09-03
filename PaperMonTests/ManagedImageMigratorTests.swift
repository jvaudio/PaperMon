import Foundation
import Testing

@testable import PaperMon

struct ManagedImageMigratorTests {
    @Test func copiesLegacyImagesAndPreservesTheirNames() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy", isDirectory: true)
        let destination = root.appendingPathComponent("Pictures/PaperMon", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: source.appendingPathComponent("first.jpg"))
        try Data("second".utf8).write(to: source.appendingPathComponent("second.png"))

        let migratedCount = try ManagedImageMigrator(
            sourceDirectory: source,
            destinationDirectory: destination
        ).migrateIfNeeded()

        #expect(migratedCount == 2)
        #expect(try Data(contentsOf: destination.appendingPathComponent("first.jpg")) == Data("first".utf8))
        #expect(try Data(contentsOf: destination.appendingPathComponent("second.png")) == Data("second".utf8))
        #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("first.jpg").path))
    }

    @Test func preservesExistingDestinationFiles() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Legacy", isDirectory: true)
        let destination = root.appendingPathComponent("Pictures/PaperMon", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: source.appendingPathComponent("same.jpg"))
        let destinationFile = destination.appendingPathComponent("same.jpg")
        try Data("current".utf8).write(to: destinationFile)

        let migratedCount = try ManagedImageMigrator(
            sourceDirectory: source,
            destinationDirectory: destination
        ).migrateIfNeeded()

        #expect(migratedCount == 0)
        #expect(try Data(contentsOf: destinationFile) == Data("current".utf8))
    }

    @Test func missingLegacyDirectoryIsANoOp() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let migratedCount = try ManagedImageMigrator(
            sourceDirectory: root.appendingPathComponent("Missing", isDirectory: true),
            destinationDirectory: root.appendingPathComponent("Pictures/PaperMon", isDirectory: true)
        ).migrateIfNeeded()

        #expect(migratedCount == 0)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
