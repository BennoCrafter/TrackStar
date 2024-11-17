import MusicKit
import SwiftUI

struct ContentView: View {
    @State private var player = MusicPlayer() // The music player instance
    @State private var song: Song? // Reference to the song
    @State private var scannedCode: String? = nil
    @State private var isScanning = true
    
    private var musicDBManager: MusicDBManager = .shared
    
    var body: some View {
        VStack {
            // QR Code Scanner - placed inside a small rectangle in the center of the screen
            VStack {
                QRCodeScannerView(didFindCode: { code in
                    // Avoid scanning multiple times if a song has already been played
                    if player.status == .playing {
                        print("skipping")
                        return
                    }
                    
                    self.isScanning = false
                    self.scannedCode = code
                    
                    let codeMetadata = CodeMetadata(from: scannedCode!)
                    Task {
                        if let fetchedSong = await fetchSong(from: musicDBManager.getSongById(codeMetadata.id)) {
                            await player.play(fetchedSong)
                        }
                    }
                }, isScanningEnabled: $isScanning)
                .frame(width: 300, height: 300)
                .background(Color.white.opacity(0.5)) // Optional background for clarity
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2) // Optional border around the scanner
                )
                .padding(.top, 50)
                .onTapGesture {
                    // Reset everything if user taps on the screen
                    self.scannedCode = nil
                    self.isScanning = true
                    player.stop()
                }
                
                // Text display for scanned code
                if let scannedCode = scannedCode {
                    Text("Scanned code: \(scannedCode)")
                        .padding()
                } else {
                    Text("Scan a QR code")
                        .padding()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top) // Aligns the scanner at the top of the screen
            
            Spacer()
            
            VStack {
                Button(action: {
                    
                }) {
                    Text("Reveal")
                        .font(.title)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .onAppear {
            // Request permission to access Apple Music
            requestPermission()
            print("Requested music permission.")
        }
    }
    
    private func playSong() async {
        guard let songToPlay = song else { return }
        // Make sure to play the song asynchronously
        await player.play(songToPlay)
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
