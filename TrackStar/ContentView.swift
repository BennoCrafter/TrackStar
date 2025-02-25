import MediaPlayer
import MusicKit
import SwiftUI

enum ActiveView {
    case qrCodeScanning, songCard
}

struct ContentView: View {
    @EnvironmentObject private var musicManager: MusicManager
    @State private var songs: [MPMediaItem] = []
    @State private var isPickerPresented = false

    var body: some View {
        VStack {
            VStack {
                Button("Select Playlist") {
                    isPickerPresented = true
                }
                .padding()

                List(songs, id: \.persistentID) { song in
                    Text(song.title ?? "Unknown Title")
                }
            }
            .sheet(isPresented: $isPickerPresented) {
                MediaPickerView(selectedSongs: $songs)
            }
            Spacer()

            if musicManager.activeView == .qrCodeScanning {
                QRCodeScanningView()
                    .transition(.slide)
            } else if musicManager.activeView == .songCard {
                SongCard()
                    .transition(.opacity)
            }
            Spacer()

            Button(action: {
                switch musicManager.activeView {
                case .qrCodeScanning:
                    musicManager.activeView = .songCard
                case .songCard:
                    musicManager.resetQRCode()
                    musicManager.activeView = .qrCodeScanning
                }

            }) {
                Text(musicManager.activeView == .qrCodeScanning ? "Reveal" : "Back")
                    .font(.title)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .onAppear {
            // Request permission to access Apple Music
            requestPermission()
            print("Requested music permission.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading, content: {
                Button(action: onConfigPress) {
                    Image(systemName: "music.note.list").font(.subheadline)
                }
            })
        }
    }

    private func onConfigPress() {}

    private func requestPermission() {
        Task {
            do {
                let authorizationStatus = await MusicAuthorization.request()

                guard authorizationStatus == .authorized else {
                    print("Authorization failed. Please allow access to Apple Music in Settings.")
                    return
                }
            }
        }
    }
}
