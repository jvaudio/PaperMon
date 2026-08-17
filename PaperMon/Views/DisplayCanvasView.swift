import AppKit
import SwiftUI

struct DisplayCanvasView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile
    @Binding var selection: DisplayAssignment.ID?

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = geometry.size

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.quaternary.opacity(0.35))

                ForEach(profile.assignments) { assignment in
                    DisplayTile(
                        assignment: assignment,
                        isSelected: selection == assignment.id,
                        preview: appModel.preview(for: assignment.image)
                    )
                    .frame(
                        width: tileWidth(for: assignment, canvasWidth: canvasSize.width),
                        height: tileHeight(for: assignment, canvasHeight: canvasSize.height)
                    )
                    .position(
                        x: tileX(for: assignment, canvasWidth: canvasSize.width),
                        y: tileY(for: assignment, canvasHeight: canvasSize.height)
                    )
                    .onTapGesture {
                        selection = assignment.id
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let url = urls.first, url.isFileURL else { return false }
                        selection = assignment.id
                        appModel.assignImage(url, to: assignment.id)
                        return true
                    }
                }
            }
            .padding(22)
        }
        .padding(20)
    }

    private func tileWidth(for assignment: DisplayAssignment, canvasWidth: Double) -> Double {
        max(104, assignment.normalizedFrame.width * max(canvasWidth - 70, 200))
    }

    private func tileHeight(for assignment: DisplayAssignment, canvasHeight: Double) -> Double {
        max(90, assignment.normalizedFrame.height * max(canvasHeight - 70, 180))
    }

    private func tileX(for assignment: DisplayAssignment, canvasWidth: Double) -> Double {
        35 + (assignment.normalizedFrame.x + assignment.normalizedFrame.width / 2) * max(canvasWidth - 70, 200)
    }

    private func tileY(for assignment: DisplayAssignment, canvasHeight: Double) -> Double {
        35 + (assignment.normalizedFrame.y + assignment.normalizedFrame.height / 2) * max(canvasHeight - 70, 180)
    }
}

private struct DisplayTile: View {
    let assignment: DisplayAssignment
    let isSelected: Bool
    let preview: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.background)

            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: assignment.presentation.scaling == .fit ? .fit : .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                    Text("Drop an image")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            VStack {
                Spacer()
                HStack {
                    Text(assignment.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: assignment.fingerprint.orientation == .portrait ? "rectangle.portrait" : "rectangle")
                }
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.62))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .secondary.opacity(0.4), lineWidth: isSelected ? 3 : 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.displayName), \(assignment.fingerprint.orientation.rawValue)")
    }
}

