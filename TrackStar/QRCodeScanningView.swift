import MusicKit
import SwiftUI

struct QRCodeScanningView: View {
    @EnvironmentObject private var musicManager: MusicManager

    var body: some View {
        VStack {
            QRCodeScannerView(didFindCode: { code in
                // Avoid scanning multiple times if song is already playing
                if musicManager.player.status == .playing {
                    print("skipping")
                    return
                }

                musicManager.isScanning = false
                musicManager.scannedCode = code

                let codeMetadata = CodeMetadata(from: musicManager.scannedCode!)
                Task {
                    if let fetchedSong = await fetchSong(from: musicManager.musicDBManager.getSongById(codeMetadata.id)) {
                        musicManager.song = fetchedSong
                        await musicManager.player.play(fetchedSong)
                    }
                }
            }, isScanningEnabled: $musicManager.isScanning)
                .frame(width: 300, height: 300)
                .background(Color.white.opacity(0.5))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .padding(.top, 50)
                .onTapGesture {
                    musicManager.resetQRCode()
                }

            // Text display
            if let scannedCode = musicManager.scannedCode {
                Text("Scanned code: \(scannedCode)")
                    .padding()
            } else {
                Text("Scan a QR code")
                    .padding()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func fetchSong(from dbSong: DBSong?) async -> Song? {
        guard let dbSong = dbSong else {
            print("Invalid song data.")
            return nil
        }
        var request = MusicCatalogSearchRequest(term: "\(dbSong.title) by \(dbSong.artist)", types: [Song.self])
        request.limit = 1

        do {
            let response = try await request.response()
            if let foundSong = response.songs.first {
                print("Found song: \(foundSong.title) by \(foundSong.artistName)")
                return foundSong
            } else {
                print("Song not found.")
                return nil
            }
        } catch {
            print("Error searching for song: \(error)")
            return nil
        }
    }
}
