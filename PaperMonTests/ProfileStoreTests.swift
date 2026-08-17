import Foundation
import Testing

@testable import PaperMon

@MainActor
struct ProfileStoreTests {
    @Test func createsUniqueProfileNames() {
        let store = makeStore()

        let first = store.createProfile(name: "Work")
        let second = store.createProfile(name: "Work")

        #expect(first.name == "Work")
        #expect(second.name == "Work 2")
        #expect(store.selectedProfileID == second.id)
    }

    @Test func deletingActiveProfileClearsSelectionAndActiveState() {
        let store = makeStore()
        let profile = store.createProfile(name: "Work")
        store.setActiveProfile(profile.id)

        store.deleteProfile(profile.id)

        #expect(store.profiles.isEmpty)
        #expect(store.activeProfile == nil)
        #expect(store.selectedProfile == nil)
    }

    private func makeStore() -> ProfileStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
        return ProfileStore(repository: ProfileRepository(libraryURL: url))
    }
}

