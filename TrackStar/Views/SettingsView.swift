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
                    NavigationLink(destination: MusicDatabaseSelector(onDatabaseSelected: { db in
                    })) {
                        HStack {
                            Text("Current: ")
                            Text(trackStarManager.musicDatabase.musicDBName ?? "None")
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

                    NavigationLink(destination: SettingsViewAttributions()) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                            Text("Attributions")
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

struct SettingsViewAttributions: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LicenseCardView(title: "CodeScanner", license: "Mit license", url: URL(string: "https://github.com/twostraws/CodeScanner/blob/main/LICENSE")!)
                LicenseCardView(title: "MarqueeText", license: "Mit license", url: URL(string: "https://github.com/joekndy/MarqueeText")!)
                LicenseCardView(title: "swift-markdown-ui", license: "Mit license", url: URL(string: "https://github.com/gonzalezreal/swift-markdown-ui")!)
            }
        }
    }
}

struct LicenseCardView: View {
    var title: String
    var license: String?
    var url: URL

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "book.pages.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.blue))
                    .padding(.trailing)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let license = license {
                        Text(license)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            .shadow(radius: 5)
        }
        .onTapGesture {
            print("Opening license url: \(url)")
            UIApplication.shared.open(url)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SettingsViewAttributions()
}

#Preview {
    SettingsView()
        .environmentObject(TrackStarManager.preview)
}
