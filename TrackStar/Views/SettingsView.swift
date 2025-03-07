import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    var playbackTimeInterval: String = "0.0"
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var trackStarManager: TrackStarManager
    @StateObject private var settingsViewModel: SettingsViewModel = .init()

    var body: some View {
        NavigationStack {
            Form {
                Section("Music Database") {
                    NavigationLink(destination: MusicDatabaseSelector(onFileSelected: { url in
                        _ = trackStarManager.initNewMusicDatabase(url: url)
                    })) {
                        HStack {
                            Text("Current: ")
                            Text(trackStarManager.appConfig.musicDBName ?? "None")
                                .foregroundStyle(.blue)
                        }
                    }

                    Toggle(isOn: $trackStarManager.appConfig.useHitsterQRCodes) {
                        Text("Hitster Mode")
                    }

                    Toggle(isOn: $trackStarManager.appConfig.useRandomPlaybackInterval) {
                        Text("Use random playback interval")
                    }
                    TextField("Enter length (in seconds) of playback interval", text: $settingsViewModel.playbackTimeInterval)
                        .keyboardType(.numberPad)
                        .onChange(of: settingsViewModel.playbackTimeInterval) { _, newValue in
                            if let newTimeInterval = TimeInterval(newValue) {
                                trackStarManager.appConfig.playbackTimeInterval = newTimeInterval
                            }
                        }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                settingsViewModel.playbackTimeInterval = String(trackStarManager.appConfig.playbackTimeInterval)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TrackStarManager.shared)
}
