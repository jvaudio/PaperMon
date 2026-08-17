import SwiftUI

struct ProfileSidebarView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selection: WallpaperProfile.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Wallpaper Profiles") {
                ForEach(appModel.profiles.profiles) { profile in
                    ProfileSidebarRow(
                        profile: profile,
                        isActive: appModel.profiles.library.activeProfileID == profile.id
                    )
                    .tag(profile.id)
                    .contextMenu {
                        Button("Apply") {
                            appModel.applyProfile(profile.id)
                        }
                        Button("Duplicate") {
                            appModel.profiles.duplicateProfile(profile.id)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            appModel.profiles.deleteProfile(profile.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PaperMon")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appModel.createProfile()
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }
        }
    }
}

private struct ProfileSidebarRow: View {
    let profile: WallpaperProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "rectangle.3.group")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 17)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .lineLimit(1)
                Text("\(profile.assignments.count) display\(profile.assignments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

