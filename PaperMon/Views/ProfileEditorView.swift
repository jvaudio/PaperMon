import SwiftUI

struct ProfileEditorView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile
    @Binding var selectedAssignmentID: DisplayAssignment.ID?
    @State private var inspectorPresented = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            DisplayCanvasView(profile: profile, selection: $selectedAssignmentID)
        }
        .inspector(isPresented: $inspectorPresented) {
            DisplayInspectorView(profile: profile, selectedAssignmentID: $selectedAssignmentID)
                .inspectorColumnWidth(min: 270, ideal: 300, max: 360)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    appModel.syncSelectedProfileWithCurrentDisplays()
                } label: {
                    Label("Sync Displays", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            ToolbarItem {
                Button {
                    inspectorPresented.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .onAppear {
            if selectedAssignmentID == nil {
                selectedAssignmentID = profile.assignments.first?.id
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            TextField(
                "Profile Name",
                text: Binding(
                    get: { profile.name },
                    set: { appModel.renameProfile(profile.id, to: $0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.title2.weight(.semibold))
            .accessibilityLabel("Profile name")

            Spacer()

            Text("Drop images onto displays")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

