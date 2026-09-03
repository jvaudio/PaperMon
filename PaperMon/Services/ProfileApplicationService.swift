import Foundation

struct ProfileApplicationResult: Sendable {
    var appliedDisplayNames: [String] = []
    var unavailableDisplayNames: [String] = []
    var ambiguousDisplayNames: [String] = []
    var missingImageDisplayNames: [String] = []
    var failures: [String] = []
    var rolledBack = false

    var isCompleteSuccess: Bool {
        !appliedDisplayNames.isEmpty
            && unavailableDisplayNames.isEmpty
            && ambiguousDisplayNames.isEmpty
            && missingImageDisplayNames.isEmpty
            && failures.isEmpty
    }
}

@MainActor
struct ProfileApplicationService {
    private let matcher: DisplayMatcher
    private let imageLibrary: ImageLibraryService
    private let wallpaperService: any WallpaperApplying

    init(
        matcher: DisplayMatcher = DisplayMatcher(),
        imageLibrary: ImageLibraryService = ImageLibraryService(),
        wallpaperService: (any WallpaperApplying)? = nil
    ) {
        self.matcher = matcher
        self.imageLibrary = imageLibrary
        self.wallpaperService = wallpaperService ?? WallpaperService()
    }

    func apply(_ profile: WallpaperProfile, to displays: [DisplaySnapshot]) async -> ProfileApplicationResult {
        let matchResult = matcher.match(assignments: profile.assignments, to: displays)
        var result = ProfileApplicationResult()
        var resolvedImages: [DisplayAssignment.ID: ResolvedImageAccess] = [:]

        for assignment in profile.assignments {
            if matchResult.ambiguousAssignmentIDs.contains(assignment.id) {
                result.ambiguousDisplayNames.append(assignment.displayName)
                continue
            }

            guard matchResult.displayID(for: assignment.id) != nil else {
                result.unavailableDisplayNames.append(assignment.displayName)
                continue
            }

            guard let image = assignment.image else {
                result.missingImageDisplayNames.append(assignment.displayName)
                continue
            }

            do {
                resolvedImages[assignment.id] = try imageLibrary.resolve(image)
            } catch {
                result.failures.append("\(assignment.displayName): \(error.localizedDescription)")
            }
        }

        guard result.failures.isEmpty else { return result }

        var previousStates: [(displayID: UInt32, state: DesktopWallpaperState)] = []
        var requests: [WallpaperRequest] = []
        var requestedDisplayNames: [String] = []

        for assignment in profile.assignments {
            guard let displayID = matchResult.displayID(for: assignment.id),
                  let resolvedImage = resolvedImages[assignment.id] else {
                continue
            }

            if let state = wallpaperService.currentState(for: displayID) {
                previousStates.append((displayID, state))
            }

            requests.append(
                WallpaperRequest(
                    displayID: displayID,
                    imageURL: resolvedImage.url,
                    presentation: assignment.presentation
                )
            )
            requestedDisplayNames.append(assignment.displayName)
        }

        do {
            try await wallpaperService.apply(requests)
            result.appliedDisplayNames = requestedDisplayNames
        } catch {
            result.failures.append(error.localizedDescription)
            await rollback(previousStates)
            result.rolledBack = true
        }

        return result
    }

    private func rollback(_ states: [(displayID: UInt32, state: DesktopWallpaperState)]) async {
        for previous in states.reversed() {
            try? await wallpaperService.restore(previous.state, to: previous.displayID)
        }
    }
}
