import AppKit
import SwiftUI

struct DisplayCanvasView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile
    @Binding var selection: DisplayAssignment.ID?
    private let layout = MonitorCanvasLayout()

    var body: some View {
        GeometryReader { geometry in
            let frames = layout.frames(for: profile.assignments, in: geometry.size)

            ZStack {
                DotGridBackground()

                ForEach(profile.assignments) { assignment in
                    if let frame = frames[assignment.id] {
                        DisplayTile(
                            assignment: assignment,
                            isSelected: selection == assignment.id,
                            preview: appModel.preview(for: assignment.image)
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
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
            }
            .clipShape(Rectangle())
        }
    }
}

private struct DisplayTile: View {
    let assignment: DisplayAssignment
    let isSelected: Bool
    let preview: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.92))

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.paperMonPanel)

                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: assignment.presentation.scaling == .fit ? .fit : .fill)
                        .clipped()
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title3)
                        Text("Drop an image")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(Color.paperMonMuted)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Text(assignment.displayName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: assignment.fingerprint.orientation == .portrait ? "rectangle.portrait" : "rectangle")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.66))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isSelected ? Color.paperMonAccent : Color.paperMonBorder,
                    lineWidth: isSelected ? 3 : 1
                )
        }
        .shadow(color: .black.opacity(0.40), radius: 12, y: 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.displayName), \(assignment.fingerprint.orientation.rawValue)")
    }
}
