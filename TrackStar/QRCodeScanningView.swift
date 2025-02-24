import SwiftUI
import MusicKit

struct QRCodeScanningView: View {
    @StateObject var viewModel: ViewModel = .shared

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
                    viewModel.scannedCode = nil
                    viewModel.isScanning = true
                    viewModel.player.stop()
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
        
        Spacer()
        
        VStack {
            Button(action: {}) {
                Text("Reveal")
                    .font(.title)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    
    private func playSong() async {
        guard let songToPlay = viewModel.song else { return }
        // Make sure to play the song asynchronously
        await viewModel.player.play(songToPlay)
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
