import Foundation
import Testing

@testable import PaperMon

@MainActor
struct WallpaperStoreCompatibilityServiceTests {
    @Test func updatesEachDisplayAndItsOwnedSpaceDefault() throws {
        let oldA = URL(fileURLWithPath: "/tmp/old-a.jpg")
        let oldB = URL(fileURLWithPath: "/tmp/old-b.jpg")
        let newA = URL(fileURLWithPath: "/tmp/new-a.jpg")
        let newB = URL(fileURLWithPath: "/tmp/new-b.jpg")
        let root: [String: Any] = [
            "Displays": [
                "A": owner(for: oldA),
                "B": owner(for: oldB),
            ],
            "Spaces": [
                "space-a": [
                    "Default": owner(for: oldA),
                    "Displays": [
                        "A": owner(for: oldA),
                        "B": owner(for: oldB),
                    ],
                ],
                "space-b": [
                    "Default": owner(for: oldB),
                    "Displays": ["B": owner(for: oldB)],
                ],
            ],
        ]
        let input = try PropertyListSerialization.data(
            fromPropertyList: root,
            format: .binary,
            options: 0
        )

        let output = try WallpaperStoreCompatibilityService.updatedStoreData(
            input,
            changes: ["A": newA, "B": newB]
        )
        let updated = try #require(
            PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any]
        )
        let displays = try #require(updated["Displays"] as? [String: Any])
        let spaces = try #require(updated["Spaces"] as? [String: Any])
        let spaceA = try #require(spaces["space-a"] as? [String: Any])
        let spaceB = try #require(spaces["space-b"] as? [String: Any])

        #expect(imageURL(in: displays["A"]) == newA)
        #expect(imageURL(in: displays["B"]) == newB)
        #expect(imageURL(in: spaceA["Default"]) == newA)
        #expect(imageURL(in: spaceDisplay("A", in: spaceA)) == newA)
        #expect(imageURL(in: spaceDisplay("B", in: spaceA)) == newB)
        #expect(imageURL(in: spaceB["Default"]) == newB)
        #expect(imageURL(in: spaceDisplay("B", in: spaceB)) == newB)
    }

    private func owner(for imageURL: URL) -> [String: Any] {
        [
            "Desktop": [
                "Content": [
                    "Choices": [
                        [
                            "Configuration": configuration(for: imageURL),
                        ],
                    ],
                ],
                "LastSet": Date(timeIntervalSince1970: 0),
                "LastUse": Date(timeIntervalSince1970: 0),
            ],
        ]
    }

    private func configuration(for imageURL: URL) -> Data {
        try! PropertyListSerialization.data(
            fromPropertyList: [
                "type": "imageFile",
                "url": ["relative": imageURL.absoluteString],
            ],
            format: .binary,
            options: 0
        )
    }

    private func spaceDisplay(_ displayUUID: String, in space: [String: Any]) -> Any? {
        (space["Displays"] as? [String: Any])?[displayUUID]
    }

    private func imageURL(in value: Any?) -> URL? {
        guard let owner = value as? [String: Any],
              let desktop = owner["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]],
              let configuration = choices.first?["Configuration"] as? Data,
              let decoded = try? PropertyListSerialization.propertyList(
                from: configuration,
                format: nil
              ) as? [String: Any],
              let url = decoded["url"] as? [String: Any],
              let relative = url["relative"] as? String else {
            return nil
        }
        return URL(string: relative)
    }
}
