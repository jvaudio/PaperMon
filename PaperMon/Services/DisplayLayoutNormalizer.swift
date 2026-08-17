import Foundation

struct DisplayLayoutNormalizer: Sendable {
    func normalizedFrames(for displays: [DisplaySnapshot]) -> [UInt32: DisplayFrame] {
        guard let first = displays.first else { return [:] }

        let minX = displays.map(\.frame.x).min() ?? first.frame.x
        let minY = displays.map(\.frame.y).min() ?? first.frame.y
        let maxX = displays.map { $0.frame.x + $0.frame.width }.max() ?? (first.frame.x + first.frame.width)
        let maxY = displays.map { $0.frame.y + $0.frame.height }.max() ?? (first.frame.y + first.frame.height)
        let totalWidth = max(maxX - minX, 1)
        let totalHeight = max(maxY - minY, 1)

        return Dictionary(uniqueKeysWithValues: displays.map { display in
            (
                display.id,
                DisplayFrame(
                    x: (display.frame.x - minX) / totalWidth,
                    y: (display.frame.y - minY) / totalHeight,
                    width: display.frame.width / totalWidth,
                    height: display.frame.height / totalHeight
                )
            )
        })
    }
}

