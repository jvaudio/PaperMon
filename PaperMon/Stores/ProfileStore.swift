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
}

