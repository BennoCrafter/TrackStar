import CodeScanner
import MediaPlayer
import MusicKit
import SwiftUI
import VisionKit

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var musicManager: TrackStarManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Music Database") {
                    NavigationLink(destination: MusicDatabaseSelector(onFileSelected: { url in
                        _ = musicManager.initNewMusicDatabase(url: url)
                    })) {
                        HStack {
                            Text("Current: ")
                            Text(musicManager.musicDBName.isEmpty ? "None" : musicManager.musicDBName)
                                .foregroundStyle(.blue)
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
        }
    }
}

// MARK: - Active View Enum

enum ActiveView {
    case qrCodeScanning, songCard, playMenu
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var musicManager: TrackStarManager
    @State private var showSettingsView: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                activeViewContent
                Spacer()
                controlButton
            }
            .onAppear {
                requestPermission()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onConfigPress) {
                        Image(systemName: "music.note.list").font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showSettingsView) {
                SettingsView()
            }
        }
    }

    // MARK: - Active View Content

    @ViewBuilder
    private var activeViewContent: some View {
        switch musicManager.activeView {
        case .qrCodeScanning:
            if showSettingsView {
                EmptyView()
            } else {
                CodeScannerView(codeTypes: [.qr], scanMode: .continuous, showViewfinder: true, videoCaptureDevice: AVCaptureDevice.systemPreferredCamera, completion: handleScan)
                    .frame(width: 300, height: 300)
            }

        case .songCard:
            SongCard()

        case .playMenu:
            PlayMenu()
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button(action: toggleActiveView) {
            Text(musicManager.activeView == .playMenu ? "Reveal" : "Back")
                .font(.title)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Button Action to Toggle Views

    private func toggleActiveView() {
        switch musicManager.activeView {
        case .qrCodeScanning:
            musicManager.activeView = .playMenu
        case .playMenu:
            musicManager.activeView = .songCard
        case .songCard:
            musicManager.resetQRCode()
            musicManager.activeView = .qrCodeScanning
        }
    }

    // MARK: - Permission Request

    private func requestPermission() {
        Task {
            do {
                let authorizationStatus = await MusicAuthorization.request()
                guard authorizationStatus == .authorized else {
                    print("Authorization failed. Please allow access to Apple Music in Settings.")
                    return
                }
                print("Requested music permission.")
            }
        }
    }

    // MARK: - Config Button Action

    private func onConfigPress() {
        showSettingsView = true
    }

    func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            print("Found code: \(result.string)")
            musicManager.scannedCode = result.string
            let codeMetadata = CodeMetadata(from: musicManager.scannedCode!)
            Task {
                if let fetchedSong = await musicManager.fetchSong(from: musicManager.musicDBManager.getSongById(codeMetadata.id)) {
                    musicManager.song = fetchedSong
                    await musicManager.musicPlayer.play(fetchedSong)
                }
            }
            toggleActiveView()
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
