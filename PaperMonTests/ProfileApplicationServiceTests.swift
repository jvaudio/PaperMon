import Foundation
import Testing

@testable import PaperMon

@MainActor
struct ProfileApplicationServiceTests {
    @Test func appliesEveryMatchedWallpaper() async throws {
        let fixture = try makeFixture()
        let wallpaperService = FakeWallpaperService()
        let service = ProfileApplicationService(
            imageLibrary: fixture.imageLibrary,
            wallpaperService: wallpaperService
        )

        let result = await service.apply(fixture.profile, to: fixture.displays)

        #expect(result.isCompleteSuccess)
        #expect(wallpaperService.appliedDisplayIDs == [10, 11])
    }

    @Test func rollsBackPreviouslyAppliedWallpapersWhenOneFails() async throws {
        let fixture = try makeFixture()
        let wallpaperService = FakeWallpaperService(failingDisplayID: 11)
        let service = ProfileApplicationService(
            imageLibrary: fixture.imageLibrary,
            wallpaperService: wallpaperService
        )

        let result = await service.apply(fixture.profile, to: fixture.displays)

        #expect(result.rolledBack)
        #expect(result.appliedDisplayNames.isEmpty)
        #expect(result.failures.count == 1)
        #expect(wallpaperService.restoredDisplayIDs == [11, 10])
    }

    private func makeFixture() throws -> Fixture {
        let imagesDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try Data([0x01]).write(to: imagesDirectory.appendingPathComponent("left.image"))
        try Data([0x02]).write(to: imagesDirectory.appendingPathComponent("right.image"))

        let left = snapshot(id: 10, serial: 100, x: 0)
        let right = snapshot(id: 11, serial: 200, x: 1_920)
        let displays = [left, right]
        let frames = DisplayLayoutNormalizer().normalizedFrames(for: displays)
        let assignments = [
            assignment(for: left, frame: frames[left.id] ?? .zero, imagePath: "left.image"),
            assignment(for: right, frame: frames[right.id] ?? .zero, imagePath: "right.image"),
        ]

        return Fixture(
            imageLibrary: ImageLibraryService(imagesDirectory: imagesDirectory),
            profile: WallpaperProfile(name: "Desk", assignments: assignments),
            displays: displays
        )
    }

    private func snapshot(id: UInt32, serial: UInt32, x: Double) -> DisplaySnapshot {
        DisplaySnapshot(
            id: id,
            fingerprint: DisplayFingerprint(
                vendorNumber: 1,
                modelNumber: 2,
                serialNumber: serial,
                localizedName: "Display \(serial)",
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                orientation: .landscape,
                isBuiltIn: false
            ),
            frame: DisplayFrame(x: x, y: 0, width: 1_920, height: 1_080),
            isMain: x == 0
        )
    }

    private func assignment(
        for display: DisplaySnapshot,
        frame: DisplayFrame,
        imagePath: String
    ) -> DisplayAssignment {
        DisplayAssignment(
            displayName: display.fingerprint.localizedName,
            fingerprint: display.fingerprint,
            normalizedFrame: frame,
            image: ImageAsset(displayName: imagePath, storage: .managed(relativePath: imagePath))
        )
    }
}

private struct Fixture {
    let imageLibrary: ImageLibraryService
    let profile: WallpaperProfile
    let displays: [DisplaySnapshot]
}

@MainActor
private final class FakeWallpaperService: WallpaperApplying {
    let failingDisplayID: UInt32?
    private(set) var appliedDisplayIDs: [UInt32] = []
    private(set) var restoredDisplayIDs: [UInt32] = []

    init(failingDisplayID: UInt32? = nil) {
        self.failingDisplayID = failingDisplayID
    }

    func currentState(for displayID: UInt32) -> DesktopWallpaperState? {
        DesktopWallpaperState(
            imageURL: URL(fileURLWithPath: "/tmp/original-\(displayID).jpg"),
            options: [:]
        )
    }

    func apply(imageURL: URL, presentation: WallpaperPresentation, to displayID: UInt32) async throws {
        if displayID == failingDisplayID {
            throw FakeWallpaperError.expectedFailure
        }
        appliedDisplayIDs.append(displayID)
    }

    func restore(_ state: DesktopWallpaperState, to displayID: UInt32) async throws {
        restoredDisplayIDs.append(displayID)
    }
}

private enum FakeWallpaperError: Error {
    case expectedFailure
}
