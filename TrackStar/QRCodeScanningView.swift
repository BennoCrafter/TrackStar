import MusicKit
import SwiftUI

struct QRCodeScanningView: View {
    @EnvironmentObject private var viewModel: ViewModel

    var body: some View {
        VStack {
            QRCodeScannerView(didFindCode: { code in
                // Avoid scanning multiple times if song is already playing
                if viewModel.player.status == .playing {
                    print("skipping")
                    return
                }
                
                viewModel.isScanning = false
                viewModel.scannedCode = code
                
                let codeMetadata = CodeMetadata(from: viewModel.scannedCode!)
                Task {
                    if let fetchedSong = await fetchSong(from: viewModel.musicDBManager.getSongById(codeMetadata.id)) {
                        viewModel.song = fetchedSong
                        await viewModel.player.play(fetchedSong)
                    }
                }
            }, isScanningEnabled: $viewModel.isScanning)
                .frame(width: 300, height: 300)
                .background(Color.white.opacity(0.5))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .padding(.top, 50)
                .onTapGesture {
                    viewModel.resetQRCode()
                }
            
            // Text display
            if let scannedCode = viewModel.scannedCode {
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
