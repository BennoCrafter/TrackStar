import CodeScanner
import MediaPlayer
import MusicKit
import SwiftUI
import VisionKit

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
                if musicManager.activeView != .qrCodeScanning {
                    controlButton
                }
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
                CodeScannerView(codeTypes: [.qr], scanMode: .continuous, showViewfinder: true, completion: handleScan)
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
            let codeMetadata = MetadataFactory.shared.createMetadata(from: result.string)
            musicManager.scannedCodeMetadata = codeMetadata
            Task {
                if let fetchedSong = await musicManager.fetchSong(from: musicManager.musicDBManager.getSongById(codeMetadata.id)) {
                    musicManager.song = fetchedSong
                    await musicManager.playSong(fetchedSong)
                }
            }
            toggleActiveView()
        case .failure(let error):
            print(error.localizedDescription)
        }
    }
}
