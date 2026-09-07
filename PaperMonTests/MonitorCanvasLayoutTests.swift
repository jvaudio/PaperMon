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

    @Test func separatesDisplaysWhoseSavedGeometryOverlaps() throws {
        let assignments = [
            assignment(name: "Top", serial: 1, frame: DisplayFrame(x: 0.25, y: 0, width: 0.5, height: 0.52), pixels: (1920, 1080)),
            assignment(name: "Bottom", serial: 2, frame: DisplayFrame(x: 0.25, y: 0.48, width: 0.5, height: 0.52), pixels: (1920, 1080)),
        ]

        let frames = MonitorCanvasLayout().frames(for: assignments, in: CGSize(width: 900, height: 700))
        let top = frames[assignments[0].id]!
        let bottom = frames[assignments[1].id]!

        #expect(!top.intersects(bottom))
        #expect(bottom.minY - top.maxY >= 8)
    }

    @Test func stackedLandscapeDisplaysUseTheSameGapAsTheirRightNeighbor() throws {
        let assignments = [
            assignment(
                name: "Top",
                serial: 1,
                frame: DisplayFrame(
                    x: 0.2647058823529412,
                    y: 0.020630242575379733,
                    width: 0.47058823529411764,
                    height: 0.48968487871231015
                ),
                pixels: (3840, 2160)
            ),
            assignment(
                name: "Left",
                serial: 2,
                frame: DisplayFrame(
                    x: 0,
                    y: 0.020630242575379733,
                    width: 0.2647058823529412,
                    height: 0.8705508954885514
                ),
                pixels: (2160, 3840)
            ),
            assignment(
                name: "Right",
                serial: 3,
                frame: DisplayFrame(
                    x: 0.7352941176470589,
                    y: 0,
                    width: 0.2647058823529412,
                    height: 0.8705508954885514
                ),
                pixels: (2160, 3840)
            ),
            assignment(
                name: "Bottom",
                serial: 4,
                frame: DisplayFrame(
                    x: 0.2647058823529412,
                    y: 0.5103151212876899,
                    width: 0.47058823529411764,
                    height: 0.48968487871231015
                ),
                pixels: (3840, 2160)
            ),
        ]

        let frames = MonitorCanvasLayout().frames(for: assignments, in: CGSize(width: 1080, height: 606))
        let top = try #require(frames[assignments[0].id])
        let right = try #require(frames[assignments[2].id])
        let bottom = try #require(frames[assignments[3].id])
        let verticalGap = bottom.minY - top.maxY
        let topRightGap = right.minX - top.maxX
        let bottomRightGap = right.minX - bottom.maxX

        #expect(verticalGap >= 24)
        #expect(abs(verticalGap - topRightGap) < 1)
        #expect(abs(verticalGap - bottomRightGap) < 1)
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
