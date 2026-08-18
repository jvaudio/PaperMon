import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let profiles: ProfileStore
    let displays: DisplayStore
    private(set) var applicationStatus: ApplicationStatus = .idle
    var notice: AppNotice?

    @ObservationIgnored private let normalizer = DisplayLayoutNormalizer()
    @ObservationIgnored private let matcher = DisplayMatcher()
    @ObservationIgnored private let imageLibrary: ImageLibraryService
    @ObservationIgnored private let applicationService: ProfileApplicationService
    @ObservationIgnored private var systemEventMonitor: SystemEventMonitor?
    @ObservationIgnored private var displayChangeTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    init(
        profiles: ProfileStore? = nil,
        displays: DisplayStore? = nil,
        imageLibrary: ImageLibraryService = ImageLibraryService(),
        applicationService: ProfileApplicationService? = nil
    ) {
        self.profiles = profiles ?? ProfileStore()
        self.displays = displays ?? DisplayStore()
        self.imageLibrary = imageLibrary
        self.applicationService = applicationService ?? ProfileApplicationService(imageLibrary: imageLibrary)

        systemEventMonitor = SystemEventMonitor(
            onDisplayChange: { [weak self] in self?.scheduleDisplayRefresh() },
            onWake: { [weak self] in self?.scheduleDisplayRefresh(delay: .seconds(1)) }
        )
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        displays.refresh()

        if UserDefaults.standard.object(forKey: "restoreActiveProfileOnLaunch") as? Bool ?? true,
           let activeProfileID = profiles.library.activeProfileID {
            applyProfile(activeProfileID, showsSuccessNotice: false)
        }
    }

    func createProfile() {
        displays.refresh()
        let normalizedFrames = normalizer.normalizedFrames(for: displays.displays)
        let assignments = displays.displays.map { display in
            DisplayAssignment(
                displayName: display.fingerprint.localizedName,
                fingerprint: display.fingerprint,
                normalizedFrame: normalizedFrames[display.id] ?? .zero
            )
        }
        _ = profiles.createProfile(name: "New Profile", assignments: assignments)
    }

    func renameProfile(_ profileID: WallpaperProfile.ID, to name: String) {
        guard var profile = profile(withID: profileID) else { return }
        profile.name = name
        profiles.updateProfile(profile)
    }

    func syncSelectedProfileWithCurrentDisplays() {
        guard var profile = profiles.selectedProfile else { return }
        displays.refresh()

        let result = matcher.match(assignments: profile.assignments, to: displays.displays)
        let normalizedFrames = normalizer.normalizedFrames(for: displays.displays)
        let additions = displays.displays
            .filter { result.unmatchedDisplayIDs.contains($0.id) }
            .map { display in
                DisplayAssignment(
                    displayName: display.fingerprint.localizedName,
                    fingerprint: display.fingerprint,
                    normalizedFrame: normalizedFrames[display.id] ?? .zero
                )
            }

        guard !additions.isEmpty else {
            applicationStatus = .applied("Profile already matches the connected displays")
            return
        }

        profile.assignments.append(contentsOf: additions)
        profiles.updateProfile(profile)
        applicationStatus = .applied("Added \(additions.count) connected display\(additions.count == 1 ? "" : "s")")
    }

    func assignImage(_ url: URL, to assignmentID: DisplayAssignment.ID) {
        guard var profile = profiles.selectedProfile,
              let index = profile.assignments.firstIndex(where: { $0.id == assignmentID }) else {
            return
        }

        do {
            let configuredMode = UserDefaults.standard.string(forKey: "imageImportMode")
            let mode: ImageImportMode = configuredMode == "reference" ? .referenceOriginal : .managedCopy
            profile.assignments[index].image = try imageLibrary.importImage(from: url, mode: mode)
            profiles.updateProfile(profile)
        } catch {
            notice = AppNotice(title: "Couldn’t Add Image", message: error.localizedDescription)
        }
    }

    func removeImage(from assignmentID: DisplayAssignment.ID) {
        updateAssignment(assignmentID) { assignment in
            assignment.image = nil
        }
    }

    func updateScaling(_ scaling: WallpaperScaling, for assignmentID: DisplayAssignment.ID) {
        updateAssignment(assignmentID) { assignment in
            assignment.presentation.scaling = scaling
        }
    }

    func updateDisplayName(_ name: String, for assignmentID: DisplayAssignment.ID) {
        updateAssignment(assignmentID) { assignment in
            assignment.displayName = name
        }
    }

    func preview(for asset: ImageAsset?) -> NSImage? {
        guard let asset,
              let access = try? imageLibrary.resolve(asset) else {
            return nil
        }
        return NSImage(contentsOf: access.url)
    }

    func applySelectedProfile() {
        guard let profileID = profiles.selectedProfileID else { return }
        applyProfile(profileID)
    }

    func applyProfile(_ profileID: WallpaperProfile.ID, showsSuccessNotice: Bool = true) {
        guard let profile = profile(withID: profileID) else { return }
        displays.refresh()
        applicationStatus = .applying

        let result = applicationService.apply(profile, to: displays.displays)
        let issueCount = result.unavailableDisplayNames.count
            + result.ambiguousDisplayNames.count
            + result.missingImageDisplayNames.count
            + result.failures.count

        if issueCount == 0, !result.appliedDisplayNames.isEmpty {
            profiles.setActiveProfile(profile.id)
            profiles.selectedProfileID = profile.id
            applicationStatus = .applied("Applied \(profile.name)")
            return
        }

        let summary = applicationSummary(for: profile, result: result)
        applicationStatus = .needsAttention(summary)
        if showsSuccessNotice || issueCount > 0 {
            notice = AppNotice(title: "Profile Needs Attention", message: summary)
        }
    }

    func scheduleDisplayRefresh(delay: Duration = .milliseconds(700)) {
        displayChangeTask?.cancel()
        displayChangeTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard let self else { return }
            displays.refresh()
            let shouldRestore = UserDefaults.standard.object(forKey: "restoreActiveProfileOnDisplayChange") as? Bool ?? true
            if shouldRestore, let activeProfileID = profiles.library.activeProfileID {
                applyProfile(activeProfileID, showsSuccessNotice: false)
            }
        }
    }

    private func updateAssignment(
        _ assignmentID: DisplayAssignment.ID,
        mutation: (inout DisplayAssignment) -> Void
    ) {
        guard var profile = profiles.selectedProfile,
              let index = profile.assignments.firstIndex(where: { $0.id == assignmentID }) else {
            return
        }

        mutation(&profile.assignments[index])
        profiles.updateProfile(profile)
    }

    private func profile(withID id: WallpaperProfile.ID) -> WallpaperProfile? {
        profiles.profiles.first { $0.id == id }
    }

    private func applicationSummary(
        for profile: WallpaperProfile,
        result: ProfileApplicationResult
    ) -> String {
        var details: [String] = []

        if !result.unavailableDisplayNames.isEmpty {
            details.append("Disconnected: \(result.unavailableDisplayNames.joined(separator: ", "))")
        }
        if !result.ambiguousDisplayNames.isEmpty {
            details.append("Couldn’t identify: \(result.ambiguousDisplayNames.joined(separator: ", "))")
        }
        if !result.missingImageDisplayNames.isEmpty {
            details.append("No image assigned: \(result.missingImageDisplayNames.joined(separator: ", "))")
        }
        details.append(contentsOf: result.failures)

        if result.appliedDisplayNames.isEmpty {
            return "“\(profile.name)” wasn’t applied. " + details.joined(separator: "\n")
        }

        return "Applied \(result.appliedDisplayNames.count) display\(result.appliedDisplayNames.count == 1 ? "" : "s"). "
            + details.joined(separator: "\n")
    }
}
