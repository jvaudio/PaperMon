import Observation

@Observable
@MainActor
final class DisplayStore {
    private(set) var displays: [DisplaySnapshot]

    @ObservationIgnored
    private let inventory: any DisplayInventoryProviding

    init(inventory: (any DisplayInventoryProviding)? = nil) {
        let inventory = inventory ?? DisplayInventoryService()
        self.inventory = inventory
        displays = inventory.currentDisplays()
    }

    func refresh() {
        displays = inventory.currentDisplays()
    }
}

