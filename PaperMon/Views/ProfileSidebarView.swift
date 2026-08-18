import SwiftUI

struct ProfileSidebarView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selection: WallpaperProfile.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            Text("PROFILES")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.paperMonMuted)
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                ForEach(appModel.profiles.profiles) { profile in
                        Button {
                            selection = profile.id
                        } label: {
                            ProfileSidebarRow(
                                profile: profile,
                                isSelected: selection == profile.id,
                                isActive: appModel.profiles.library.activeProfileID == profile.id
                            )
                        }
                        .buttonStyle(.plain)
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
                .padding(.horizontal, 10)
            }

            Button {
                appModel.createProfile()
            } label: {
                Label("New Profile", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.paperMonBorder, lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Spacer(minLength: 20)

            Rectangle()
                .fill(Color.paperMonBorder.opacity(0.50))
                .frame(height: 1)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .font(.callout.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.paperMonMuted)
        }
        .background(Color.paperMonSidebar)
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2.weight(.medium))
                .foregroundStyle(Color.paperMonAccent)
                .frame(width: 40, height: 40)
                .background(Color.paperMonAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.paperMonAccent.opacity(0.48), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("PaperMon")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.paperMonAccent)
                Text("MACOS WALLPAPER\nMANAGER")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.paperMonMuted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}

private struct ProfileSidebarRow: View {
    let profile: WallpaperProfile
    let isSelected: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "display.and.arrow.down" : "display")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.paperMonAccent : Color.paperMonMuted)
                .frame(width: 22)

            Text(profile.name)
                .font(.callout.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.paperMonAccent : Color.paperMonMuted)
                .lineLimit(1)

            Spacer()

            if isActive {
                Circle()
                    .fill(Color.paperMonAccent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            isSelected ? Color.paperMonSidebarSelection : Color.clear,
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.paperMonAccent)
                    .frame(width: 3, height: 28)
            }
        }
        .contentShape(Rectangle())
    }
}
