import MusicKit
import SwiftData
import SwiftUI

@main
struct TrackStarApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @StateObject var musicManager: ViewModel = .shared

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
                OnboardingView(hasLaunchedBefore: hasLaunchedBefore, onFileSelected: { url in
                    if JSONDataManager.copyFile(from: url, withName: "musicDB.json") {
                        print("Copied!")
                    }
                    hasLaunchedBefore = true
                })
            }
        }
    }
}
