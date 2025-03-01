import MusicKit
import SwiftData
import SwiftUI

@main
struct TrackStarApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @StateObject var musicManager: TrackStarManager = .shared

    init() {
        if !hasLaunchedBefore {
            print("First time launching. Initialize Music Database")
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasLaunchedBefore {
                ContentView()
                    .environmentObject(musicManager)
            }
            else {
                OnboardingView {
                    hasLaunchedBefore = true
                }
                .environmentObject(musicManager)
            }
        }.modelContainer(for: [DBSong.self, AppConfig.self], onSetup: handleSetup)
    }

    func handleSetup(result: Result<ModelContainer, Error>) {
        switch result {
        case .success(let modelContainer):
            musicManager.configure(with: modelContainer)
        case .failure(let error):
            print("Model Container setup: \(error.localizedDescription)")
        }
    }
}
