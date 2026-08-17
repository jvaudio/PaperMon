import SwiftUI
import UniformTypeIdentifiers

struct DisplayInspectorView: View {
    @Environment(AppModel.self) private var appModel
    let profile: WallpaperProfile
    @Binding var selectedAssignmentID: DisplayAssignment.ID?
    @State private var isChoosingImage = false

    private var assignment: DisplayAssignment? {
        guard let selectedAssignmentID else { return nil }
        return profile.assignments.first { $0.id == selectedAssignmentID }
    }

    var body: some View {
        if let assignment {
            Form {
                Section("Display") {
                    LabeledContent("Name", value: assignment.displayName)
                    LabeledContent("Orientation", value: assignment.fingerprint.orientation.rawValue.capitalized)
                    LabeledContent(
                        "Resolution",
                        value: "\(assignment.fingerprint.pixelWidth) × \(assignment.fingerprint.pixelHeight)"
                    )
                }

                Section("Wallpaper") {
                    if let image = assignment.image {
                        LabeledContent("Image", value: image.displayName)
                    } else {
                        Text("No image assigned")
                            .foregroundStyle(.secondary)
                    }

                    Button("Choose Image…") {
                        isChoosingImage = true
                    }

                    if assignment.image != nil {
                        Button("Remove Image", role: .destructive) {
                            appModel.removeImage(from: assignment.id)
                        }
                    }
                }

                Section("Presentation") {
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
                }
            }
            .formStyle(.grouped)
            .fileImporter(
                isPresented: $isChoosingImage,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        appModel.assignImage(url, to: assignment.id)
                    }
                case let .failure(error):
                    appModel.notice = AppNotice(title: "Couldn’t Open Image", message: error.localizedDescription)
                }
            }
        } else {
            ContentUnavailableView(
                "Select a Display",
                systemImage: "rectangle.dashed",
                description: Text("Choose a display in the canvas to assign its wallpaper.")
            )
        }
    }
}

