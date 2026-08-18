import CoreGraphics
import Foundation

struct MonitorCanvasLayout: Sendable {
    var canvasPadding: CGFloat = 52
    var monitorGap: CGFloat = 12

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

        return Dictionary(uniqueKeysWithValues: virtualFrames.map { id, virtualFrame in
            let rawFrame = CGRect(
                x: fittedOrigin.x + (virtualFrame.minX - virtualBounds.minX) * scale,
                y: fittedOrigin.y + (virtualFrame.minY - virtualBounds.minY) * scale,
                width: virtualFrame.width * scale,
                height: virtualFrame.height * scale
            )
            let inset = min(
                monitorGap / 2,
                max(0, min(rawFrame.width, rawFrame.height) * 0.08)
            )
            return (id, rawFrame.insetBy(dx: inset, dy: inset))
        })
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

