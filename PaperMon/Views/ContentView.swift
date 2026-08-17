import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Profiles", systemImage: "rectangle.3.group")
            }
            .listStyle(.sidebar)
            .navigationTitle("PaperMon")
        } detail: {
            ContentUnavailableView {
                Label("Create a Wallpaper Profile", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("Assign an image to each connected display, then switch the whole set at once.")
            }
        }
    }
}

