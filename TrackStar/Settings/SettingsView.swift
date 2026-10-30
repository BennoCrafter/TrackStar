import SQLiteData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(SettingsKey.playbackDuration) private var playbackDuration: Double = 30
    @AppStorage(SettingsKey.randomStart) private var randomStart = false
    @AppStorage(SettingsKey.devMode) private var devMode = false
    @AppStorage(SettingsKey.winningScore) private var winningScore = PartyModel.defaultWinningScore
    @AppStorage(SettingsKey.wrongCostsPoint) private var wrongCostsPoint = true
    @AppStorage(SettingsKey.nameTheSong) private var nameTheSong = true

    @FetchOne(Dataset.where(\.isActive)) private var activeDataset: Dataset?
    @State private var showingReleaseNotes = false

    var body: some View {
        NavigationStack {
            Form {
                gameSection
                partyRulesSection
                developerSection
                datasetSection
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

    private var partyRulesSection: some View {
        Section {
            Stepper(value: $winningScore, in: 3 ... 30) {
                LabeledContent {
                    Text("\(winningScore)").monospacedDigit()
                } label: {
                    Label("Points to Win", systemImage: "trophy")
                }
            }

            Toggle(isOn: $wrongCostsPoint) {
                Label("Lose a Point When Wrong", systemImage: "minus.circle")
            }

            Toggle(isOn: $nameTheSong) {
                Label("Name the Song First", systemImage: "checklist")
            }
        } header: {
            Text("Party Rules")
        } footer: {
            Text("For the Party Game. With “Name the Song First”, a player picks the right title and artist out of three before placing the card.")
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
                    Label("Song Packs", systemImage: "square.stack")
                }
            }
        } footer: {
            Text("German Hitster cards play with the Hitster song pack.")
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
