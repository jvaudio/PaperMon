import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedAssignmentID: DisplayAssignment.ID?

    var body: some View {
        @Bindable var profileStore = appModel.profiles
        @Bindable var bindableAppModel = appModel

        NavigationSplitView {
            ProfileSidebarView(selection: $profileStore.selectedProfileID)
                .navigationSplitViewColumnWidth(min: 190, ideal: 225, max: 300)
        } detail: {
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
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appModel.applySelectedProfile()
                } label: {
                    Label("Apply Profile", systemImage: "paintbrush.pointed")
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileStore.selectedProfile == nil || appModel.applicationStatus == .applying)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let label = appModel.applicationStatus.label {
                HStack(spacing: 8) {
                    Image(systemName: statusSymbol)
                    Text(label)
                        .lineLimit(1)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.bar)
            }
        }
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

    private var statusSymbol: String {
        if case .needsAttention = appModel.applicationStatus {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if case .needsAttention = appModel.applicationStatus {
            return .orange
        }
        return .secondary
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
