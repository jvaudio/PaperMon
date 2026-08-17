import Foundation

struct ProfileRepository: Sendable {
    enum RepositoryError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                "This profile library uses unsupported schema version \(version)."
            }
        }
    }

    let libraryURL: URL

    init(libraryURL: URL = Self.defaultLibraryURL()) {
        self.libraryURL = libraryURL
    }

    func load() throws -> ProfileLibrary {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: libraryURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let library = try decoder.decode(ProfileLibrary.self, from: data)

        guard library.schemaVersion <= ProfileLibrary.currentSchemaVersion else {
            throw RepositoryError.unsupportedSchema(library.schemaVersion)
        }

        return library
    }

    func save(_ library: ProfileLibrary) throws {
        let directory = libraryURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(library)
        try data.write(to: libraryURL, options: .atomic)
    }

    static func defaultLibraryURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("PaperMon", isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
    }
}

