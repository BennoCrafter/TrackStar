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
