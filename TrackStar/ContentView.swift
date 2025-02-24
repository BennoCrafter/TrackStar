import MusicKit
import SwiftUI

enum ActiveView {
    case qrCodeScanning, songCard
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: ViewModel

    var body: some View {
        VStack {
            if viewModel.activeView == .qrCodeScanning {
                QRCodeScanningView()
                    .transition(.slide)
            } else if viewModel.activeView == .songCard {
                SongCard()
                    .transition(.slide)
            }
            Spacer()

            Button(action: {
                viewModel.activeView = viewModel.activeView == .songCard ? ActiveView.qrCodeScanning : ActiveView.songCard
            }) {
                Text(viewModel.activeView == .qrCodeScanning ? "Reveal" : "Back")
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
