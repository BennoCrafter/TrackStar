import SwiftUI

/// `UserDefaults` key of the release notes version this device has shown. Per device on purpose,
/// so every device shows the notes once after updating.
let seenReleaseNotesVersionKey = "seenReleaseNotesVersion"

enum ReleaseNotes {
    static var version: String {
        Bundle.main.appVersion
    }

    static var hasNotesForCurrentVersion: Bool {
        releases.contains { $0.version == version }
    }

    struct Release: Identifiable {
        var id: String {
            version
        }

        let version: String
        let items: [Item]
    }

    struct Item: Identifiable {
        var id: String {
            systemImage
        }

        let systemImage: String
        let color: Color
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }

    static let releases: [Release] = [
        Release(version: "2.0", items: [
            Item(
                systemImage: "sparkles",
                color: .purple,
                title: "A New TrackStar",
                text: "Redesigned from the ground up: scan, listen with a countdown, and reveal the card in the colors of its decade."),
            Item(
                systemImage: "qrcode.viewfinder",
                color: .blue,
                title: "Cards Pick Their Dataset",
                text: "Scanning a card switches to its dataset, or offers to download it. German Hitster cards work without a setting."),
            Item(
                systemImage: "printer.fill",
                color: .orange,
                title: "Printable Cards",
                text: "Open any dataset's cards right in the app, then print them or save them to Files."),
            Item(
                systemImage: "music.note.house.fill",
                color: .red,
                title: "Cards From Your Playlists",
                text: "Turn any Apple Music playlist into a dataset, and TrackStar makes printable cards for it."),
            Item(
                systemImage: "camera.fill",
                color: .gray,
                title: "Scan With the Camera App",
                text: "Point the iPhone camera at a card to open TrackStar and play it right away."),
            Item(
                systemImage: "music.note.list",
                color: .pink,
                title: "Browse the Songs",
                text: "Search every card of a dataset by title, artist, year or number."),
            Item(
                systemImage: "arrow.down.circle.fill",
                color: .green,
                title: "Download Again",
                text: "Datasets are stored in a new way. Download yours again from the dataset list."),
        ]),
    ]
}

struct ReleaseNotesView: View {
    @State private var selection = ReleaseNotes.hasNotesForCurrentVersion ? ReleaseNotes.version : ReleaseNotes.releases.first?.version

    var body: some View {
        TabView(selection: $selection) {
            ForEach(ReleaseNotes.releases.reversed()) { release in
                List {
                    Section {
                        ForEach(release.items) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.systemImage)
                                    .font(.title2)
                                    .foregroundStyle(item.color)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.headline)
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Version \(release.version)")
                    }
                }
                .tag(Optional(release.version))
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shown once after an update (see `ContentView`), with a Done button.
struct ReleaseNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReleaseNotesView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
