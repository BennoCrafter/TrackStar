import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("hitsterMode") var hitsterMode: Bool = false
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var musicManager: TrackStarManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var settingsViewModel: SettingsViewModel = .init()

    var body: some View {
        NavigationStack {
            Form {
                Section("Music Database") {
                    NavigationLink(destination: MusicDatabaseSelector(onFileSelected: { url in
                        _ = musicManager.initNewMusicDatabase(url: url)
                    })) {
                        HStack {
                            Text("Current: ")
                            Text(musicManager.appConfig.musicDBName ?? "None")
                                .foregroundStyle(.blue)
                        }
                    }

                    Toggle(isOn: $settingsViewModel.hitsterMode) {
                        Text("Hitster Mode")
                    }

                    Toggle(isOn: $musicManager.appConfig.useRandomPlaybackInterval) {
                        Text("Use random playback interval")
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
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TrackStarManager.shared)
}
