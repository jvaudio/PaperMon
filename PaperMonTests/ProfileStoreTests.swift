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

    @Test func displayNicknameCarriesAcrossProfiles() {
        let store = makeStore()
        let firstAssignment = assignment(serial: 42, x: 0)
        let secondAssignment = assignment(serial: 42, x: 0)
        _ = store.createProfile(name: "Work", assignments: [firstAssignment])
        _ = store.createProfile(name: "Play", assignments: [secondAssignment])

        store.updateDisplayName("Portrait Screen", matching: secondAssignment)

        #expect(store.profiles.count == 2)
        #expect(store.profiles.allSatisfy { $0.assignments.first?.displayName == "Portrait Screen" })
    }

    @Test func nicknameLookupLetsNewProfilesInheritAnExistingName() {
        let store = makeStore()
        let savedAssignment = assignment(serial: 42, x: 0, displayName: "Portrait Screen")
        _ = store.createProfile(name: "Work", assignments: [savedAssignment])

        let name = store.displayName(
            for: savedAssignment.fingerprint,
            normalizedFrame: savedAssignment.normalizedFrame
        )

        #expect(name == "Portrait Screen")
    }

    @Test func layoutKeepsIdenticalSeriallessDisplaysDistinct() {
        let store = makeStore()
        let left = assignment(serial: nil, x: 0)
        let right = assignment(serial: nil, x: 0.6)
        let otherLeft = assignment(serial: nil, x: 0)
        let otherRight = assignment(serial: nil, x: 0.6)
        _ = store.createProfile(name: "Work", assignments: [left, right])
        _ = store.createProfile(name: "Play", assignments: [otherLeft, otherRight])

        store.updateDisplayName("Left Screen", matching: otherLeft)

        for profile in store.profiles {
            #expect(profile.assignments[0].displayName == "Left Screen")
            #expect(profile.assignments[1].displayName == "Display")
        }
    }

    private func makeStore() -> ProfileStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("profiles.json", isDirectory: false)
        return ProfileStore(repository: ProfileRepository(libraryURL: url))
    }

    private func assignment(
        serial: UInt32?,
        x: Double,
        displayName: String = "Display"
    ) -> DisplayAssignment {
        DisplayAssignment(
            displayName: displayName,
            fingerprint: DisplayFingerprint(
                vendorNumber: 1,
                modelNumber: 2,
                serialNumber: serial,
                localizedName: "Display",
                pixelWidth: 1_200,
                pixelHeight: 1_920,
                orientation: .portrait,
                isBuiltIn: false
            ),
            normalizedFrame: DisplayFrame(x: x, y: 0, width: 0.4, height: 1)
        )
    }
}
