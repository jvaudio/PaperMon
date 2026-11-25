import Foundation
import Testing

@testable import PaperMon

struct DisplayMatcherTests {
    @Test func exactHardwareIdentityWinsAfterLayoutChanges() throws {
        let left = snapshot(id: 10, serial: 100, name: "Dell", x: 0, width: 1_200, height: 1_920)
        let right = snapshot(id: 11, serial: 200, name: "Dell", x: 1_200, width: 1_200, height: 1_920)
        let assignments = assignments(for: [left, right])
        let movedLeft = snapshot(id: 50, serial: 100, name: "Dell", x: 1_200, width: 1_200, height: 1_920)
        let movedRight = snapshot(id: 51, serial: 200, name: "Dell", x: 0, width: 1_200, height: 1_920)

        let result = DisplayMatcher().match(assignments: assignments, to: [movedRight, movedLeft])

        #expect(result.displayID(for: assignments[0].id) == 50)
        #expect(result.displayID(for: assignments[1].id) == 51)
    }

    @Test func layoutSeparatesIdenticalDisplaysWithoutSerialNumbers() throws {
        let left = snapshot(id: 10, serial: nil, name: "Studio Display", x: 0, width: 1_920, height: 1_080)
        let right = snapshot(id: 11, serial: nil, name: "Studio Display", x: 1_920, width: 1_920, height: 1_080)
        let assignments = assignments(for: [left, right])

        let result = DisplayMatcher().match(assignments: assignments, to: [right, left])

        #expect(result.displayID(for: assignments[0].id) == left.id)
        #expect(result.displayID(for: assignments[1].id) == right.id)
    }

    @Test func missingDisplayLeavesAssignmentUnmatched() throws {
        let display = snapshot(id: 10, serial: 100, name: "Portrait", x: 0, width: 1_200, height: 1_920)
        let second = snapshot(id: 11, serial: 200, name: "Landscape", x: 1_200, width: 1_920, height: 1_080)
        let assignments = assignments(for: [display, second])

        let result = DisplayMatcher().match(assignments: assignments, to: [display])

        #expect(result.matches.count == 1)
        #expect(result.unmatchedAssignmentIDs == [assignments[1].id])
    }

    @Test func changedTVSerialStillMatchesUsingStableTraits() throws {
        let tv = snapshot(id: 10, serial: 100, name: "LG TV (3)", x: 0, width: 3_840, height: 2_160)
        let assignment = try #require(assignments(for: [tv]).first)
        let reconnectedTV = snapshot(
            id: 42,
            serial: 999,
            name: "LG TV (3)",
            x: 0,
            width: 3_840,
            height: 2_160
        )

        let result = DisplayMatcher().match(assignments: [assignment], to: [reconnectedTV])

        #expect(result.displayID(for: assignment.id) == reconnectedTV.id)
        #expect(result.matches.first?.confidence == .probable)
    }

    @Test func fallbackCannotStealUniqueTVWhenAnotherDisplayLosesEDID() {
        let main = snapshot(id: 10, serial: 100, name: "M55Q7-J01", x: 0, width: 3_840, height: 2_160)
        let left = snapshot(id: 11, serial: 100, name: "M55Q7-H1 (1)", x: -2_160, width: 2_160, height: 3_840)
        let right = snapshot(id: 12, serial: 100, name: "M55Q7-H1 (2)", x: 3_840, width: 2_160, height: 3_840)
        var tv = snapshot(id: 13, serial: 100, name: "M55Q6-L4", x: 0, width: 3_840, height: 2_160)
        tv.fingerprint.modelNumber = 3
        tv.frame.y = 2_160
        let saved = assignments(for: [main, left, right, tv])
        var unidentified = snapshot(id: 42, serial: nil, name: "", x: 3_840, width: 1_080, height: 1_920)
        unidentified.fingerprint.vendorNumber = nil
        unidentified.fingerprint.modelNumber = nil
        var renamedLeft = left
        renamedLeft.fingerprint.localizedName = "M55Q7-H1"

        for connected in [[main, renamedLeft, tv, unidentified], [unidentified, tv, renamedLeft, main]] {
            let result = DisplayMatcher().match(assignments: saved, to: connected)
            #expect(result.matches.count == 4)
            #expect(result.displayID(for: saved[0].id) == main.id)
            #expect(result.displayID(for: saved[1].id) == left.id)
            #expect(result.displayID(for: saved[2].id) == unidentified.id)
            #expect(result.displayID(for: saved[3].id) == tv.id)
            #expect(result.unmatchedAssignmentIDs.isEmpty)
            #expect(result.ambiguousAssignmentIDs.isEmpty)
        }
    }

    private func assignments(for displays: [DisplaySnapshot]) -> [DisplayAssignment] {
        let frames = DisplayLayoutNormalizer().normalizedFrames(for: displays)
        return displays.map { display in
            DisplayAssignment(
                displayName: display.fingerprint.localizedName,
                fingerprint: display.fingerprint,
                normalizedFrame: frames[display.id] ?? .zero
            )
        }
    }

    private func snapshot(
        id: UInt32,
        serial: UInt32?,
        name: String,
        x: Double,
        width: Double,
        height: Double
    ) -> DisplaySnapshot {
        DisplaySnapshot(
            id: id,
            fingerprint: DisplayFingerprint(
                vendorNumber: 1,
                modelNumber: 2,
                serialNumber: serial,
                localizedName: name,
                pixelWidth: Int(width),
                pixelHeight: Int(height),
                orientation: DisplayOrientation(width: width, height: height),
                isBuiltIn: false
            ),
            frame: DisplayFrame(x: x, y: 0, width: width, height: height),
            isMain: x == 0
        )
    }
}
