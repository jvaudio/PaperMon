import Foundation
import Observation

@Observable
@MainActor
final class ProfileStore {
    private(set) var library: ProfileLibrary
    var selectedProfileID: WallpaperProfile.ID?
    private(set) var lastPersistenceError: String?

    @ObservationIgnored
    private let repository: ProfileRepository

    init(repository: ProfileRepository = ProfileRepository()) {
        self.repository = repository

        do {
            let library = try repository.load()
            self.library = library
            selectedProfileID = library.activeProfileID ?? library.profiles.first?.id
        } catch {
            library = .empty
            lastPersistenceError = error.localizedDescription
        }
    }

    var profiles: [WallpaperProfile] {
        library.profiles
    }

    var selectedProfile: WallpaperProfile? {
        guard let selectedProfileID else { return nil }
        return library.profiles.first { $0.id == selectedProfileID }
    }

    var activeProfile: WallpaperProfile? {
        guard let activeProfileID = library.activeProfileID else { return nil }
        return library.profiles.first { $0.id == activeProfileID }
    }

    @discardableResult
    func createProfile(name: String, assignments: [DisplayAssignment] = []) -> WallpaperProfile {
        let profile = WallpaperProfile(name: uniqueName(for: name), assignments: assignments)
        library.profiles.append(profile)
        selectedProfileID = profile.id
        persist()
        return profile
    }

    func updateProfile(_ profile: WallpaperProfile) {
        guard let index = library.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updatedProfile = profile
        updatedProfile.markUpdated()
        library.profiles[index] = updatedProfile
        persist()
    }

    func updateDisplayName(_ name: String, matching source: DisplayAssignment) {
        var changedProfileIDs = Set<WallpaperProfile.ID>()

        for profileIndex in library.profiles.indices {
            guard let assignmentIndex = matchingAssignmentIndex(
                for: source,
                in: library.profiles[profileIndex].assignments
            ), library.profiles[profileIndex].assignments[assignmentIndex].displayName != name else {
                continue
            }

            library.profiles[profileIndex].assignments[assignmentIndex].displayName = name
            changedProfileIDs.insert(library.profiles[profileIndex].id)
        }

        guard !changedProfileIDs.isEmpty else { return }

        for profileIndex in library.profiles.indices
        where changedProfileIDs.contains(library.profiles[profileIndex].id) {
            library.profiles[profileIndex].markUpdated()
        }
        persist()
    }

    func displayName(
        for fingerprint: DisplayFingerprint,
        normalizedFrame: DisplayFrame
    ) -> String? {
        let source = DisplayAssignment(
            displayName: fingerprint.localizedName,
            fingerprint: fingerprint,
            normalizedFrame: normalizedFrame
        )
        let preferredProfileIDs = [selectedProfileID, library.activeProfileID].compactMap { $0 }
        let orderedProfiles = library.profiles.sorted { lhs, rhs in
            let lhsPriority = preferredProfileIDs.firstIndex(of: lhs.id) ?? preferredProfileIDs.count
            let rhsPriority = preferredProfileIDs.firstIndex(of: rhs.id) ?? preferredProfileIDs.count
            return lhsPriority < rhsPriority
        }

        for profile in orderedProfiles {
            if let index = matchingAssignmentIndex(for: source, in: profile.assignments) {
                return profile.assignments[index].displayName
            }
        }

        return nil
    }

    func duplicateProfile(_ profileID: WallpaperProfile.ID) {
        guard var duplicate = library.profiles.first(where: { $0.id == profileID }) else { return }
        duplicate.id = UUID()
        duplicate.name = uniqueName(for: "\(duplicate.name) Copy")
        duplicate.createdAt = Date()
        duplicate.updatedAt = duplicate.createdAt
        library.profiles.append(duplicate)
        selectedProfileID = duplicate.id
        persist()
    }

    func deleteProfile(_ profileID: WallpaperProfile.ID) {
        library.profiles.removeAll { $0.id == profileID }

        if library.activeProfileID == profileID {
            library.activeProfileID = nil
        }

        if selectedProfileID == profileID {
            selectedProfileID = library.profiles.first?.id
        }

        persist()
    }

    func setActiveProfile(_ profileID: WallpaperProfile.ID?) {
        library.activeProfileID = profileID
        persist()
    }

    func clearPersistenceError() {
        lastPersistenceError = nil
    }

    private func persist() {
        do {
            try repository.save(library)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    private func uniqueName(for proposedName: String) -> String {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "Untitled Profile" : trimmedName
        let existingNames = Set(library.profiles.map(\.name))

        guard existingNames.contains(baseName) else { return baseName }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)") {
            suffix += 1
        }

        return "\(baseName) \(suffix)"
    }

    private func matchingAssignmentIndex(
        for source: DisplayAssignment,
        in assignments: [DisplayAssignment]
    ) -> Int? {
        if let hardwareKey = source.fingerprint.hardwareKey,
           let exactIndex = assignments.firstIndex(where: { $0.fingerprint.hardwareKey == hardwareKey }) {
            return exactIndex
        }

        return assignments.indices
            .filter { index in
                fingerprintsShareStableTraits(source.fingerprint, assignments[index].fingerprint)
            }
            .min { lhs, rhs in
                layoutDistance(from: source, to: assignments[lhs])
                    < layoutDistance(from: source, to: assignments[rhs])
            }
    }

    private func fingerprintsShareStableTraits(
        _ lhs: DisplayFingerprint,
        _ rhs: DisplayFingerprint
    ) -> Bool {
        let exactPixelSize = lhs.pixelWidth == rhs.pixelWidth && lhs.pixelHeight == rhs.pixelHeight
        let rotatedPixelSize = lhs.pixelWidth == rhs.pixelHeight && lhs.pixelHeight == rhs.pixelWidth

        return lhs.vendorNumber == rhs.vendorNumber
            && lhs.modelNumber == rhs.modelNumber
            && lhs.localizedName.caseInsensitiveCompare(rhs.localizedName) == .orderedSame
            && (exactPixelSize || rotatedPixelSize)
            && lhs.isBuiltIn == rhs.isBuiltIn
    }

    private func layoutDistance(from lhs: DisplayAssignment, to rhs: DisplayAssignment) -> Double {
        hypot(
            lhs.normalizedFrame.x - rhs.normalizedFrame.x,
            lhs.normalizedFrame.y - rhs.normalizedFrame.y
        ) + abs(lhs.normalizedFrame.width - rhs.normalizedFrame.width)
            + abs(lhs.normalizedFrame.height - rhs.normalizedFrame.height)
    }
}
