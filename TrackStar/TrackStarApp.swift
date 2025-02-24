//
//  TrackStarApp.swift
//  TrackStar
//
//  Created by Ben Baumeister on 16.11.24.
//

import SwiftData
import SwiftUI
import MusicKit

@main
struct TrackStarApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    init() {
        if !hasLaunchedBefore {
            print("First time launching. Initialize Music Database")
        }
        
    }
    var body: some Scene {
        WindowGroup {
            if hasLaunchedBefore {
                ContentView()
            }
            else {
                OnboardingView(hasLaunchedBefore: hasLaunchedBefore, onFileSelected: {url in
                    if JSONDataManager.copyFile(from: url, withName: "musicDB.json") {
                        print("Copied!")
                    }
                    hasLaunchedBefore = true
                })
            }
        }
    }
}
