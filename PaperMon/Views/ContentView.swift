import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedAssignmentID: DisplayAssignment.ID?

    var body: some View {
        @Bindable var profileStore = appModel.profiles
        @Bindable var bindableAppModel = appModel

        HStack(spacing: 0) {
            ProfileSidebarView(selection: $profileStore.selectedProfileID)
                .frame(width: 250)

            Rectangle()
                .fill(Color.paperMonBorder.opacity(0.55))
                .frame(width: 1)

            Group {
                if let profile = profileStore.selectedProfile {
                    ProfileEditorView(
                        profile: profile,
                        selectedAssignmentID: $selectedAssignmentID
                    )
                    .id(profile.id)
                } else {
                    EmptyProfilesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color.paperMonBorder.opacity(0.55))
                .frame(width: 1)

            DisplayInspectorView(
                profile: profileStore.selectedProfile,
                selectedAssignmentID: $selectedAssignmentID
            )
            .frame(width: 310)
        }
        .frame(minWidth: 1_180, minHeight: 650)
        .background(Color.paperMonCanvas)
        .alert(item: $bindableAppModel.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .task {
            appModel.startIfNeeded()
            if profileStore.profiles.isEmpty {
                appModel.createProfile()
            }
        }
    }

}

private struct EmptyProfilesView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ContentUnavailableView {
            Label("Create a Wallpaper Profile", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Assign an image to each connected display, then switch the whole set at once.")
        } actions: {
            Button("Create Profile") {
                appModel.createProfile()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
