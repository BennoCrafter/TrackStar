import SQLiteData
import SwiftUI

@main
struct TrackStarApp: App {
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var databaseError: String?

    init() {
        #if DEBUG
            checkCardCodes()
        #endif
        do {
            try prepareDependencies {
                $0.defaultDatabase = try Schema.appDatabase()
            }
        } catch {
            logger.error("Failed to open the database: \(error)")
            _databaseError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let databaseError {
                ContentUnavailableView(
                    "TrackStar Couldn't Start",
                    systemImage: "exclamationmark.triangle",
                    description: Text(databaseError))
            } else if hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
    }
}
