import CoreGraphics
import Testing

@testable import PaperMon

struct MonitorCanvasLayoutTests {
    @Test func centersCrossLayoutWithoutOverlappingDisplays() throws {
        let assignments = [
            assignment(name: "Top", serial: 1, frame: DisplayFrame(x: 0.25, y: 0, width: 0.5, height: 0.25), pixels: (1920, 1080)),
            assignment(name: "Left", serial: 2, frame: DisplayFrame(x: 0, y: 0.25, width: 0.25, height: 0.5), pixels: (1080, 1920)),
            assignment(name: "Right", serial: 3, frame: DisplayFrame(x: 0.75, y: 0.25, width: 0.25, height: 0.5), pixels: (1080, 1920)),
            assignment(name: "Bottom", serial: 4, frame: DisplayFrame(x: 0.25, y: 0.75, width: 0.5, height: 0.25), pixels: (1920, 1080)),
        ]

        let frames = MonitorCanvasLayout().frames(for: assignments, in: CGSize(width: 900, height: 700))
        let output = assignments.compactMap { frames[$0.id] }

        #expect(output.count == assignments.count)
        for index in output.indices {
            for otherIndex in output.indices where index < otherIndex {
                #expect(!output[index].intersects(output[otherIndex]))
            }
        }

        let bounds = output.reduce(CGRect.null) { $0.union($1) }
        #expect(abs(bounds.midX - 450) < 2)
        #expect(abs(bounds.midY - 350) < 2)
    }

    @Test func preservesPortraitAndLandscapeShapes() throws {
        let assignments = [
            assignment(name: "Landscape", serial: 1, frame: DisplayFrame(x: 0, y: 0, width: 0.65, height: 1), pixels: (1920, 1080)),
            assignment(name: "Portrait", serial: 2, frame: DisplayFrame(x: 0.65, y: 0, width: 0.35, height: 1), pixels: (1080, 1920)),
        ]

        let frames = MonitorCanvasLayout().frames(for: assignments, in: CGSize(width: 800, height: 600))

        #expect(frames[assignments[0].id]!.width > frames[assignments[0].id]!.height)
        #expect(frames[assignments[1].id]!.height > frames[assignments[1].id]!.width)
    }

    private func assignment(
        name: String,
        serial: UInt32,
        frame: DisplayFrame,
        pixels: (Int, Int)
    ) -> DisplayAssignment {
        DisplayAssignment(
            displayName: name,
            fingerprint: DisplayFingerprint(
                vendorNumber: 1,
                modelNumber: 1,
                serialNumber: serial,
                localizedName: name,
                pixelWidth: pixels.0,
                pixelHeight: pixels.1,
                orientation: DisplayOrientation(width: Double(pixels.0), height: Double(pixels.1)),
                isBuiltIn: false
            ),
            normalizedFrame: frame
        )
    }
}

