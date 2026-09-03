import Darwin
import Foundation
import OSLog

@MainActor
enum WallpaperStoreCompatibilityService {
    private typealias DisplayInfoFunction = @convention(c) (UInt32) -> Unmanaged<CFDictionary>?

    private static let logger = Logger(
        subsystem: "com.papermon.app",
        category: "WallpaperCompatibility"
    )
    private static let displayInfoFunction: DisplayInfoFunction? = {
        guard let handle = dlopen(
            "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
            RTLD_LAZY
        ), let symbol = dlsym(handle, "CoreDisplay_DisplayCreateInfoDictionary") else {
            return nil
        }

        return unsafeBitCast(symbol, to: DisplayInfoFunction.self)
    }()

    static func currentImageURL(for displayID: UInt32) -> URL? {
        guard let displayUUID = displayUUID(for: displayID),
              let storeData = try? Data(contentsOf: storeURL),
              let root = try? propertyList(from: storeData),
              let displays = root["Displays"] as? NSDictionary,
              let display = displays[displayUUID] as? NSDictionary else {
            return nil
        }

        return imageURL(in: display)
    }

    static func apply(_ requests: [WallpaperRequest]) async throws {
        guard !requests.isEmpty else { return }
        try Task.checkCancellation()

        var changes: [String: URL] = [:]
        for request in requests {
            guard FileManager.default.isReadableFile(atPath: request.imageURL.path) else {
                throw WallpaperStoreCompatibilityError.imageUnavailable(request.imageURL.lastPathComponent)
            }
            guard let displayUUID = displayUUID(for: request.displayID) else {
                throw WallpaperStoreCompatibilityError.displayIdentityUnavailable(request.displayID)
            }
            changes[displayUUID] = request.imageURL
        }

        logger.info("Applying \(changes.count, privacy: .public) wallpapers through the macOS 27 compatibility store")

        let originalData: Data
        let updatedData: Data
        do {
            originalData = try Data(contentsOf: storeURL)
            try originalData.write(to: backupURL, options: .atomic)
            updatedData = try updatedStoreData(originalData, changes: changes)
        } catch let error as WallpaperStoreCompatibilityError {
            throw error
        } catch {
            throw WallpaperStoreCompatibilityError.storeUpdateFailed(error.localizedDescription)
        }

        var agentIsStopped = false
        do {
            // WallpaperAgent watches Index.plist and also writes its in-memory state back to
            // that file. Freeze only the agent while replacing the complete transaction so
            // it cannot race the atomic write. Killing WallpaperImageExtension directly can
            // strand its ExtensionKit connection and make macOS fall back to the default
            // wallpaper on the next rebuild.
            let previousAgentPIDs = try await wallpaperAgentPIDs()

            _ = try await run(
                executable: "/usr/bin/pkill",
                arguments: ["-STOP", "-x", "WallpaperAgent"],
                allowedExitCodes: [0, 1]
            )
            agentIsStopped = true

            try updatedData.write(to: storeURL, options: .atomic)

            let persistedData = try Data(contentsOf: storeURL)
            guard storeData(persistedData, contains: changes) else {
                try? originalData.write(to: storeURL, options: .atomic)
                throw WallpaperStoreCompatibilityError.storeUpdateNotRetained
            }

            _ = try await run(
                executable: "/usr/bin/pkill",
                arguments: ["-KILL", "-x", "WallpaperAgent"],
                allowedExitCodes: [0, 1]
            )
            agentIsStopped = false

            // WallpaperAgent is a launchd-managed system process. Asking LaunchServices
            // to open its app wrapper can fail even though launchd is already replacing
            // it, which previously made a successful write look like a failed apply and
            // triggered a display-by-display rollback. Wait for the replacement process
            // that launchd owns instead.
            try await waitForWallpaperAgent(replacing: previousAgentPIDs)
            try await Task.sleep(for: .seconds(3))

            guard try await waitForStore(changes) else {
                throw WallpaperStoreCompatibilityError.storeUpdateNotRetained
            }
        } catch {
            logger.error(
                "macOS 27 compatibility apply failed: \(error.localizedDescription, privacy: .public)"
            )
            if agentIsStopped {
                _ = try? await run(
                    executable: "/usr/bin/pkill",
                    arguments: ["-CONT", "-x", "WallpaperAgent"],
                    allowedExitCodes: [0, 1]
                )
            }
            if let compatibilityError = error as? WallpaperStoreCompatibilityError {
                throw compatibilityError
            }
            throw WallpaperStoreCompatibilityError.agentRestartFailed(error.localizedDescription)
        }

        logger.info("macOS 27 wallpaper store retained all requested displays after agent restart")
    }

    static func updatedStoreData(
        _ data: Data,
        changes: [String: URL],
        date: Date = Date()
    ) throws -> Data {
        let root = try propertyList(from: data)
        guard let displays = root["Displays"] as? NSMutableDictionary else {
            throw WallpaperStoreCompatibilityError.invalidStore
        }

        var configurations: [String: Data] = [:]
        for (displayUUID, imageURL) in changes {
            guard let display = displays[displayUUID] as? NSMutableDictionary else {
                throw WallpaperStoreCompatibilityError.displayRecordMissing(displayUUID)
            }

            let configuration = try imageConfiguration(for: imageURL)
            configurations[displayUUID] = configuration
            try updateDesktop(
                in: display,
                configuration: configuration,
                date: date
            )
        }

        if let spaces = root["Spaces"] as? NSMutableDictionary {
            for value in spaces.allValues {
                guard let space = value as? NSMutableDictionary,
                      let spaceDisplays = space["Displays"] as? NSMutableDictionary else {
                    continue
                }

                let originalDefaultImageURL = (space["Default"] as? NSDictionary)
                    .flatMap(imageURL(in:))
                var replacementDefaultConfiguration: Data?

                for (displayUUID, configuration) in configurations {
                    guard let spaceDisplay = spaceDisplays[displayUUID] as? NSMutableDictionary else {
                        continue
                    }

                    if let originalDefaultImageURL,
                       let originalDisplayImageURL = imageURL(in: spaceDisplay),
                       urlsReferToSameFile(originalDisplayImageURL, originalDefaultImageURL) {
                        replacementDefaultConfiguration = configuration
                    }
                    try updateDesktop(
                        in: spaceDisplay,
                        configuration: configuration,
                        date: date
                    )
                }

                if let replacementDefaultConfiguration,
                   let defaultEntry = space["Default"] as? NSMutableDictionary {
                    try updateDesktop(
                        in: defaultEntry,
                        configuration: replacementDefaultConfiguration,
                        date: date
                    )
                }
            }
        }

        return try PropertyListSerialization.data(
            fromPropertyList: root,
            format: .binary,
            options: 0
        )
    }

    private static var storeURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    private static var backupURL: URL {
        storeURL.deletingLastPathComponent()
            .appendingPathComponent("Index.plist.papermon-backup")
    }

    private static func propertyList(from data: Data) throws -> NSMutableDictionary {
        guard let root = try PropertyListSerialization.propertyList(
            from: data,
            options: [.mutableContainersAndLeaves],
            format: nil
        ) as? NSMutableDictionary else {
            throw WallpaperStoreCompatibilityError.invalidStore
        }
        return root
    }

    private static func displayUUID(for displayID: UInt32) -> String? {
        guard let displayInfoFunction,
              let info = displayInfoFunction(displayID)?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return info["kCGDisplayUUID"] as? String
    }

    private static func imageConfiguration(for imageURL: URL) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: [
                "type": "imageFile",
                "url": ["relative": imageURL.absoluteString],
            ],
            format: .binary,
            options: 0
        )
    }

    private static func updateDesktop(
        in owner: NSMutableDictionary,
        configuration: Data,
        date: Date
    ) throws {
        guard let desktop = owner["Desktop"] as? NSMutableDictionary,
              let content = desktop["Content"] as? NSMutableDictionary,
              let choices = content["Choices"] as? NSMutableArray,
              let choice = choices.firstObject as? NSMutableDictionary else {
            throw WallpaperStoreCompatibilityError.invalidStore
        }

        choice["Configuration"] = configuration
        desktop["LastSet"] = date
        desktop["LastUse"] = date
    }

    private static func configurationData(in owner: NSDictionary) -> Data? {
        guard let desktop = owner["Desktop"] as? NSDictionary,
              let content = desktop["Content"] as? NSDictionary,
              let choices = content["Choices"] as? NSArray,
              let choice = choices.firstObject as? NSDictionary else {
            return nil
        }
        return choice["Configuration"] as? Data
    }

    private static func imageURL(in owner: NSDictionary) -> URL? {
        guard let configuration = configurationData(in: owner) else { return nil }
        return imageURL(inConfiguration: configuration)
    }

    private static func imageURL(inConfiguration configuration: Data) -> URL? {
        guard let decoded = try? PropertyListSerialization.propertyList(
            from: configuration,
            format: nil
        ) as? [String: Any],
              let url = decoded["url"] as? [String: Any],
              let relative = url["relative"] as? String else {
            return nil
        }
        return URL(string: relative)
    }

    private static func storeData(_ data: Data, contains changes: [String: URL]) -> Bool {
        guard let root = try? propertyList(from: data),
              let displays = root["Displays"] as? NSDictionary else {
            return false
        }

        return changes.allSatisfy { displayUUID, expectedURL in
            guard let display = displays[displayUUID] as? NSDictionary,
                  let actualURL = imageURL(in: display) else {
                return false
            }
            return urlsReferToSameFile(actualURL, expectedURL)
        }
    }

    private static func waitForStore(_ changes: [String: URL]) async throws -> Bool {
        for poll in 0..<10 {
            try Task.checkCancellation()

            if let data = try? Data(contentsOf: storeURL),
               storeData(data, contains: changes) {
                return true
            }

            if poll < 9 {
                try await Task.sleep(for: .milliseconds(500))
            }
        }

        return false
    }

    private static func wallpaperAgentPIDs() async throws -> Set<Int32> {
        let output = try await run(
            executable: "/usr/bin/pgrep",
            arguments: ["-x", "WallpaperAgent"],
            allowedExitCodes: [0, 1]
        )

        return Set(
            output.split(whereSeparator: \Character.isWhitespace)
                .compactMap { Int32($0) }
        )
    }

    private static func waitForWallpaperAgent(replacing previousPIDs: Set<Int32>) async throws {
        for poll in 0..<40 {
            try Task.checkCancellation()

            let currentPIDs = try await wallpaperAgentPIDs()
            if !currentPIDs.isEmpty, currentPIDs.isDisjoint(with: previousPIDs) {
                return
            }

            if poll < 39 {
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        throw WallpaperStoreCompatibilityError.agentRestartTimedOut
    }

    private static func urlsReferToSameFile(_ first: URL, _ second: URL) -> Bool {
        first.standardizedFileURL.resolvingSymlinksInPath()
            == second.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func run(
        executable: String,
        arguments: [String],
        allowedExitCodes: Set<Int32> = [0]
    ) async throws -> String {
        let capture = WallpaperProcessCapture(executable: executable, arguments: arguments)

        return try await withCheckedThrowingContinuation { continuation in
            capture.process.terminationHandler = { process in
                let output = capture.standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = capture.standardError.fileHandleForReading.readDataToEndOfFile()

                guard allowedExitCodes.contains(process.terminationStatus) else {
                    let message = String(decoding: errorOutput, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(
                        throwing: WallpaperStoreCompatibilityError.commandFailed(
                            message.isEmpty
                                ? "Command exited with status \(process.terminationStatus)."
                                : message
                        )
                    )
                    return
                }

                continuation.resume(returning: String(decoding: output, as: UTF8.self))
            }

            do {
                try capture.process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class WallpaperProcessCapture: @unchecked Sendable {
    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()

    init(executable: String, arguments: [String]) {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
    }
}

enum WallpaperStoreCompatibilityError: LocalizedError {
    case commandFailed(String)
    case displayIdentityUnavailable(UInt32)
    case displayRecordMissing(String)
    case imageUnavailable(String)
    case invalidStore
    case storeUpdateFailed(String)
    case storeUpdateNotRetained
    case agentRestartFailed(String)
    case agentRestartTimedOut

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            "macOS wallpaper support command failed. \(message)"
        case let .displayIdentityUnavailable(displayID):
            "macOS did not provide a stable identity for display \(displayID)."
        case let .displayRecordMissing(displayUUID):
            "macOS has no wallpaper record for display \(displayUUID)."
        case let .imageUnavailable(filename):
            "The wallpaper image \(filename) is not readable."
        case .invalidStore:
            "The macOS wallpaper store has an unexpected format."
        case let .storeUpdateFailed(message):
            "The macOS wallpaper store could not be updated. \(message)"
        case .storeUpdateNotRetained:
            "The macOS wallpaper store did not retain the requested profile transaction."
        case let .agentRestartFailed(message):
            "The macOS wallpaper service could not be restarted. \(message)"
        case .agentRestartTimedOut:
            "macOS did not relaunch its wallpaper service after the profile was written."
        }
    }
}
