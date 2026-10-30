import SQLiteData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(SettingsKey.playbackDuration) private var playbackDuration: Double = 30
    @AppStorage(SettingsKey.randomStart) private var randomStart = false
    @AppStorage(SettingsKey.devMode) private var devMode = false

    @FetchOne(Dataset.where(\.isActive)) private var activeDataset: Dataset?
    @FetchAll(Dataset.order(by: \.displayName)) private var installed: [Dataset]
    @State private var showingReleaseNotes = false

    var body: some View {
        NavigationStack {
            Form {
                gameSection
                developerSection
                datasetSection
                onDeviceSection(public: true)
                onDeviceSection(public: false)
                helpSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingReleaseNotes) { ReleaseNotesSheet() }
        }
    }

    // MARK: - Sections

    private var gameSection: some View {
        Section {
            Picker(selection: $playbackDuration) {
                ForEach([10.0, 15, 20, 30, 45, 60], id: \.self) { seconds in
                    Text("\(Int(seconds)) s").tag(seconds)
                }
            } label: {
                Label("Snippet Length", systemImage: "timer")
            }

            Toggle(isOn: $randomStart) {
                Label("Random Start", systemImage: "dice")
            }
        } header: {
            Text("Game")
        } footer: {
            Text("How long a song plays before it pauses, and whether it starts somewhere in the middle instead of the beginning.")
        }
    }

    private var developerSection: some View {
        Section {
            Toggle(isOn: $devMode) {
                Label("Developer Mode", systemImage: "hammer")
            }
        } footer: {
            Text("Songs don't play, and the question mark card shows the song it hides.")
        }
    }

    private var datasetSection: some View {
        Section {
            NavigationLink(destination: DatasetLibraryView()) {
                LabeledContent {
                    Text(activeDataset?.displayName ?? "None")
                } label: {
                    Label("Datasets", systemImage: "square.stack")
                }
            }
        } footer: {
            Text("German Hitster cards play with the Hitster dataset.")
        }
    }

    /// The downloaded repo datasets, or the user's own (imported or made in the app). Hidden when empty.
    @ViewBuilder
    private func onDeviceSection(public isRemote: Bool) -> some View {
        let datasets = installed.filter { $0.isRemote == isRemote }
        if !datasets.isEmpty {
            Section {
                ForEach(datasets) { dataset in
                    NavigationLink {
                        DatasetDetailView(id: dataset.id, remote: nil)
                    } label: {
                        InstalledRow(dataset: dataset)
                    }
                }
            } header: {
                Text(isRemote ? "On This Device · Public" : "On This Device · My Datasets")
            } footer: {
                if !isRemote {
                    Text("Imported from a file or made from Apple Music. They only exist on this device.")
                }
            }
        }
    }

    private var helpSection: some View {
        Section {
            Button {
                hasSeenOnboarding = false
                dismiss()
            } label: {
                Label("Show Onboarding", systemImage: "hand.wave")
            }

            Link(destination: Library.repositoryURL) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Link(destination: Library.repositoryURL.appending(path: "issues")) {
                Label("Report a Problem", systemImage: "ladybug")
            }

            Link(destination: URL(string: "https://discord.gg/JNu7qXGpzV")!) {
                Label("Discord", systemImage: "bubble.left.and.bubble.right")
            }
        } header: {
            Text("Help & Feedback")
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingReleaseNotes = true
            } label: {
                Label("What's New", systemImage: "sparkles")
            }

            NavigationLink(destination: SettingsViewAttributions()) {
                Label("Attributions", systemImage: "heart")
            }

            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("\(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } header: {
            Text("About")
        }
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
}
