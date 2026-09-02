import Foundation

struct DisplayMatch: Equatable, Sendable {
    enum Confidence: String, Sendable {
        case exact
        case probable
    }

    let assignmentID: DisplayAssignment.ID
    let displayID: UInt32
    let score: Double
    let confidence: Confidence
}

struct DisplayMatchResult: Equatable, Sendable {
    var matches: [DisplayMatch]
    var unmatchedAssignmentIDs: Set<DisplayAssignment.ID>
    var ambiguousAssignmentIDs: Set<DisplayAssignment.ID>
    var unmatchedDisplayIDs: Set<UInt32>

    func displayID(for assignmentID: DisplayAssignment.ID) -> UInt32? {
        matches.first { $0.assignmentID == assignmentID }?.displayID
    }
}

struct DisplayMatcher: Sendable {
    private let normalizer = DisplayLayoutNormalizer()
    private let minimumScore = 38.0
    private let ambiguityMargin = 4.0

    func match(assignments: [DisplayAssignment], to displays: [DisplaySnapshot]) -> DisplayMatchResult {
        let normalizedFrames = normalizer.normalizedFrames(for: displays)
        var availableDisplays = displays
        var matches: [DisplayMatch] = []
        var unmatchedAssignments = Set<DisplayAssignment.ID>()
        var ambiguousAssignments = Set<DisplayAssignment.ID>()

        let orderedAssignments = assignments.sorted { lhs, rhs in
            let lhsHasHardwareKey = lhs.fingerprint.hardwareKey != nil
            let rhsHasHardwareKey = rhs.fingerprint.hardwareKey != nil
            return lhsHasHardwareKey && !rhsHasHardwareKey
        }

        for assignment in orderedAssignments {
            let candidates = availableDisplays
                .map { display in
                    (
                        display: display,
                        score: score(
                            assignment: assignment,
                            display: display,
                            normalizedFrame: normalizedFrames[display.id] ?? .zero
                        )
                    )
                }
                .sorted { $0.score > $1.score }

            guard let best = candidates.first, best.score >= minimumScore else {
                unmatchedAssignments.insert(assignment.id)
                continue
            }

            let exactHardwareMatch = assignment.fingerprint.hardwareKey != nil
                && assignment.fingerprint.hardwareKey == best.display.fingerprint.hardwareKey
            if let second = candidates.dropFirst().first,
               best.score - second.score < ambiguityMargin,
               !exactHardwareMatch {
                ambiguousAssignments.insert(assignment.id)
                continue
            }

            matches.append(
                DisplayMatch(
                    assignmentID: assignment.id,
                    displayID: best.display.id,
                    score: best.score,
                    confidence: exactHardwareMatch ? .exact : .probable
                )
            )
            availableDisplays.removeAll { $0.id == best.display.id }
        }

        return DisplayMatchResult(
            matches: matches,
            unmatchedAssignmentIDs: unmatchedAssignments,
            ambiguousAssignmentIDs: ambiguousAssignments,
            unmatchedDisplayIDs: Set(availableDisplays.map(\.id))
        )
    }

    private func score(
        assignment: DisplayAssignment,
        display: DisplaySnapshot,
        normalizedFrame: DisplayFrame
    ) -> Double {
        let saved = assignment.fingerprint
        let current = display.fingerprint
        var score = 0.0

        if saved.vendorNumber != nil, saved.vendorNumber == current.vendorNumber { score += 20 }
        if saved.modelNumber != nil, saved.modelNumber == current.modelNumber { score += 25 }

        if let savedSerial = saved.serialNumber, let currentSerial = current.serialNumber {
            // Some TVs and adapters expose a synthesized serial that can change after a
            // restart. Treat an exact serial as strong evidence, but let the remaining
            // physical and layout traits recover from a changed value.
            score += savedSerial == currentSerial ? 55 : -25
        }

        if saved.localizedName.caseInsensitiveCompare(current.localizedName) == .orderedSame {
            score += 12
        }

        let exactPixelSize = saved.pixelWidth == current.pixelWidth && saved.pixelHeight == current.pixelHeight
        let rotatedPixelSize = saved.pixelWidth == current.pixelHeight && saved.pixelHeight == current.pixelWidth
        if exactPixelSize || rotatedPixelSize { score += 22 }

        if saved.orientation == current.orientation { score += 14 }
        if saved.isBuiltIn == current.isBuiltIn { score += 8 }
        if display.isMain && assignment.normalizedFrame.x == 0 && assignment.normalizedFrame.y == 0 { score += 3 }

        let positionDistance = hypot(
            assignment.normalizedFrame.x - normalizedFrame.x,
            assignment.normalizedFrame.y - normalizedFrame.y
        )
        score += max(0, 24 - (positionDistance * 40))

        let sizeDistance = abs(assignment.normalizedFrame.width - normalizedFrame.width)
            + abs(assignment.normalizedFrame.height - normalizedFrame.height)
        score += max(0, 10 - (sizeDistance * 20))

        return score
    }
}
