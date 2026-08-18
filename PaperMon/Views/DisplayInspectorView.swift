import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DisplayInspectorView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile?
    @Binding var selectedAssignmentID: DisplayAssignment.ID?
    @State private var isChoosingImage = false

    private var assignment: DisplayAssignment? {
        guard let profile, let selectedAssignmentID else { return nil }
        return profile.assignments.first { $0.id == selectedAssignmentID }
    }

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader

            Rectangle()
                .fill(Color.paperMonBorder.opacity(0.55))
                .frame(height: 1)

            if let assignment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        selectedDisplaySection(assignment)
                        nicknameSection(assignment)
                        scalingSection(assignment)
                        wallpaperSection(assignment)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "Select a Display",
                    systemImage: "rectangle.dashed",
                    description: Text("Choose a monitor in the arrangement to edit its details.")
                )
                .foregroundStyle(Color.paperMonMuted)
            }
        }
        .background(Color.paperMonInspector)
        .fileImporter(
            isPresented: $isChoosingImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first, let assignment {
                    appModel.assignImage(url, to: assignment.id)
                }
            case let .failure(error):
                appModel.notice = AppNotice(title: "Couldn’t Open Image", message: error.localizedDescription)
            }
        }
    }

    private var inspectorHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(Color.paperMonAccent)
            Text("Inspector")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 62)
        .background(Color.paperMonPanel)
    }

    private func selectedDisplaySection(_ assignment: DisplayAssignment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SELECTED DISPLAY")

            VStack(alignment: .leading, spacing: 9) {
                Text(assignment.fingerprint.localizedName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.paperMonAccent)
                        .frame(width: 7, height: 7)
                    Text("\(String(assignment.fingerprint.pixelWidth)) × \(String(assignment.fingerprint.pixelHeight))")
                    Text("•")
                        .foregroundStyle(Color.paperMonBorder)
                    Text(assignment.fingerprint.orientation.rawValue.capitalized)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.paperMonMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.paperMonPanel, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.paperMonBorder, lineWidth: 1)
            }
        }
    }

    private func nicknameSection(_ assignment: DisplayAssignment) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("NICKNAME")

            TextField(
                "Display nickname",
                text: Binding(
                    get: { assignment.displayName },
                    set: { appModel.updateDisplayName($0, for: assignment.id) }
                )
            )
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.paperMonBorder, lineWidth: 1)
            }
        }
    }

    private func scalingSection(_ assignment: DisplayAssignment) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("SCALING")

            Picker(
                "Scaling",
                selection: Binding(
                    get: { assignment.presentation.scaling },
                    set: { appModel.updateScaling($0, for: assignment.id) }
                )
            ) {
                ForEach(WallpaperScaling.allCases) { scaling in
                    Text(scaling.title).tag(scaling)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func wallpaperSection(_ assignment: DisplayAssignment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("CURRENT WALLPAPER")
                Spacer()
                Button("Change") {
                    isChoosingImage = true
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.paperMonAccent)
            }

            wallpaperPreview(assignment)

            if let image = assignment.image {
                Text(image.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.paperMonMuted)
                    .lineLimit(1)

                Button("Remove Wallpaper", role: .destructive) {
                    appModel.removeImage(from: assignment.id)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    @ViewBuilder
    private func wallpaperPreview(_ assignment: DisplayAssignment) -> some View {
        if let preview = appModel.preview(for: assignment.image) {
            Image(nsImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 118)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.paperMonBorder, lineWidth: 1)
                }
        } else {
            Button {
                isChoosingImage = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                    Text("Choose a wallpaper")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.paperMonMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 118)
                .background(Color.paperMonPanel, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.paperMonBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(Color.paperMonMuted)
    }
}
