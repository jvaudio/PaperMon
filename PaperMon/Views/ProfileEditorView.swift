import SwiftUI

struct ProfileEditorView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile
    @Binding var selectedAssignmentID: DisplayAssignment.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            DisplayCanvasView(profile: profile, selection: $selectedAssignmentID)
        }
        .onAppear {
            if !profile.assignments.contains(where: { $0.id == selectedAssignmentID }) {
                selectedAssignmentID = profile.assignments.first?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Current:")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.paperMonMuted)

            TextField(
                "Profile Name",
                text: Binding(
                    get: { profile.name },
                    set: { appModel.renameProfile(profile.id, to: $0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(width: 150)
            .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityLabel("Profile name")

            Label("Arrangement", systemImage: "rectangle.3.group")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.paperMonAccent)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.paperMonAccent)
                        .frame(height: 2)
                }

            Spacer()

            applicationStatus

            Button {
                appModel.syncSelectedProfileWithCurrentDisplays()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.paperMonMuted)
            .help("Sync connected displays")

            Button("Apply") {
                appModel.applyProfile(profile.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.paperMonAccent)
            .disabled(appModel.applicationStatus == .applying)
        }
        .padding(.horizontal, 22)
        .frame(height: 62)
        .background(Color.paperMonPanel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.paperMonBorder.opacity(0.55))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var applicationStatus: some View {
        switch appModel.applicationStatus {
        case .idle:
            Text("Auto-saved")
                .foregroundStyle(Color.paperMonMuted)
        case .applying:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Applying…")
            }
            .foregroundStyle(Color.paperMonMuted)
        case let .applied(message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.paperMonAccent)
        case .needsAttention:
            Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
