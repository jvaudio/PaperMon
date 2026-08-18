import CoreGraphics
import Foundation

struct MonitorCanvasLayout: Sendable {
    var canvasPadding: CGFloat = 62
    var monitorGap: CGFloat = 40

    func frames(
        for assignments: [DisplayAssignment],
        in canvasSize: CGSize
    ) -> [DisplayAssignment.ID: CGRect] {
        guard !assignments.isEmpty,
              canvasSize.width > canvasPadding * 2,
              canvasSize.height > canvasPadding * 2 else {
            return [:]
        }

        let layoutAspect = inferredLayoutAspect(from: assignments)
        let virtualFrames = assignments.map { assignment in
            (
                assignment.id,
                CGRect(
                    x: assignment.normalizedFrame.x * layoutAspect,
                    y: assignment.normalizedFrame.y,
                    width: assignment.normalizedFrame.width * layoutAspect,
                    height: assignment.normalizedFrame.height
                )
            )
        }
        let virtualBounds = virtualFrames
            .map(\.1)
            .reduce(CGRect.null) { $0.union($1) }

        guard !virtualBounds.isNull, virtualBounds.width > 0, virtualBounds.height > 0 else {
            return [:]
        }

        let availableSize = CGSize(
            width: canvasSize.width - canvasPadding * 2,
            height: canvasSize.height - canvasPadding * 2
        )
        let scale = min(
            availableSize.width / virtualBounds.width,
            availableSize.height / virtualBounds.height
        )
        let fittedSize = CGSize(
            width: virtualBounds.width * scale,
            height: virtualBounds.height * scale
        )
        let fittedOrigin = CGPoint(
            x: (canvasSize.width - fittedSize.width) / 2,
            y: (canvasSize.height - fittedSize.height) / 2
        )

        let fittedFrames = virtualFrames.map { id, virtualFrame in
            let rawFrame = CGRect(
                x: fittedOrigin.x + (virtualFrame.minX - virtualBounds.minX) * scale,
                y: fittedOrigin.y + (virtualFrame.minY - virtualBounds.minY) * scale,
                width: virtualFrame.width * scale,
                height: virtualFrame.height * scale
            )
            let inset = min(
                monitorGap / 2,
                max(0, min(rawFrame.width, rawFrame.height) * 0.16)
            )
            return (id, rawFrame.insetBy(dx: inset, dy: inset))
        }

        return Dictionary(uniqueKeysWithValues: separateAndCenter(
            fittedFrames,
            in: canvasSize,
            minimumClearance: 24
        ))
    }

    private func separateAndCenter(
        _ input: [(DisplayAssignment.ID, CGRect)],
        in canvasSize: CGSize,
        minimumClearance: CGFloat
    ) -> [(DisplayAssignment.ID, CGRect)] {
        var output = input

        for _ in 0..<20 {
            var changed = false

            for firstIndex in output.indices {
                for secondIndex in output.indices where firstIndex < secondIndex {
                    let first = output[firstIndex].1
                    let second = output[secondIndex].1
                    let expandedFirst = first.insetBy(
                        dx: -minimumClearance / 2,
                        dy: -minimumClearance / 2
                    )
                    let expandedSecond = second.insetBy(
                        dx: -minimumClearance / 2,
                        dy: -minimumClearance / 2
                    )
                    let overlap = expandedFirst.intersection(expandedSecond)

                    guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else {
                        continue
                    }

                    let horizontalSeparation = abs(first.midX - second.midX)
                        / max((first.width + second.width) / 2, 1)
                    let verticalSeparation = abs(first.midY - second.midY)
                        / max((first.height + second.height) / 2, 1)

                    if horizontalSeparation > verticalSeparation {
                        let direction: CGFloat = first.midX <= second.midX ? -1 : 1
                        let shift = overlap.width / 2 + 0.5
                        output[firstIndex].1 = first.offsetBy(dx: direction * shift, dy: 0)
                        output[secondIndex].1 = second.offsetBy(dx: -direction * shift, dy: 0)
                    } else {
                        let direction: CGFloat = first.midY <= second.midY ? -1 : 1
                        let shift = overlap.height / 2 + 0.5
                        output[firstIndex].1 = first.offsetBy(dx: 0, dy: direction * shift)
                        output[secondIndex].1 = second.offsetBy(dx: 0, dy: -direction * shift)
                    }
                    changed = true
                }
            }

            if !changed { break }
        }

        let bounds = output.map(\.1).reduce(CGRect.null) { $0.union($1) }
        guard !bounds.isNull else { return output }

        let availableWidth = canvasSize.width - canvasPadding * 2
        let availableHeight = canvasSize.height - canvasPadding * 2
        let scale = min(1, availableWidth / bounds.width, availableHeight / bounds.height)
        let scaledSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let origin = CGPoint(
            x: (canvasSize.width - scaledSize.width) / 2,
            y: (canvasSize.height - scaledSize.height) / 2
        )

        return output.map { id, frame in
            let centeredFrame = CGRect(
                x: origin.x + (frame.minX - bounds.minX) * scale,
                y: origin.y + (frame.minY - bounds.minY) * scale,
                width: frame.width * scale,
                height: frame.height * scale
            )
            return (id, centeredFrame)
        }
    }

    private func inferredLayoutAspect(from assignments: [DisplayAssignment]) -> CGFloat {
        let candidates = assignments.compactMap { assignment -> CGFloat? in
            let normalized = assignment.normalizedFrame
            guard normalized.width > 0, normalized.height > 0,
                  assignment.fingerprint.pixelWidth > 0,
                  assignment.fingerprint.pixelHeight > 0 else {
                return nil
            }

            let monitorAspect = CGFloat(assignment.fingerprint.pixelWidth)
                / CGFloat(assignment.fingerprint.pixelHeight)
            let normalizedAspect = CGFloat(normalized.width / normalized.height)
            return monitorAspect / normalizedAspect
        }.sorted()

        guard !candidates.isEmpty else { return 16.0 / 9.0 }
        return min(max(candidates[candidates.count / 2], 0.5), 5)
    }
}
