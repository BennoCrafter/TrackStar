import MusicKit
import SwiftUI

struct ContentView: View {
    @State private var isPlaying = false
    @State private var player = MusicPlayer()  // The music player instance
    @State private var song: Song?  // Reference to the song
    
    @State private var scannedCode: String? = nil
    @State private var isScanning = true
    
    var body: some View {
        VStack {
            // QR Code Scanner - placed inside a small rectangle in the center of the screen
            VStack {
                QRCodeScannerView(didFindCode: { code in
                    self.scannedCode = code
                    self.isScanning = false
                }, isScanningEnabled: isScanning)
                .frame(width: 300, height: 300)
                .background(Color.white.opacity(0.5)) // Optional background for clarity
                .cornerRadius(20) 
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue, lineWidth: 2) // Optional border around the scanner
                )
                .padding(.top, 50)
                .onTapGesture {
                    self.scannedCode = nil
                    self.isScanning = true
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
            
            // Music player controls
            VStack {
                Text("Apple Music Player")
                    .font(.largeTitle)
                    .padding()
                
                Button(action: {
                    Task {
                        if isPlaying {
                            // Pause the music if it's playing
                            player.pause()
                        } else {
                            await searchForSong()
                            // Play "Shape of You" by Ed Sheeran
                            playSong()
                        }
                        isPlaying.toggle()
                    }
                }) {
                    Text(isPlaying ? "Pause" : "Play Shape of You")
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
                print("Requested permission.")
            }
        }
    }
    
    private func playSong() {
        guard let songToPlay = song else { return }
        Task {
            await player.play(songToPlay)
        }
    }
    
    private func searchForSong() async {
        // Search for "Shape of You" by Ed Sheeran
        var request = MusicCatalogSearchRequest(term: "Shape of You Ed Sheeran", types: [Song.self])
        request.limit = 1
        
        do {
            let response = try await request.response()
            if let foundSong = response.songs.first {
                song = foundSong
                print("Found song: \(foundSong.title) by \(foundSong.artistName)")
            } else {
                print("Song not found.")
            }
        } catch {
            print("Error searching for song: \(error)")
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
