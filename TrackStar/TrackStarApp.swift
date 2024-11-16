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
    let isFirstLaunch = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

    init() {
        if isFirstLaunch {
            print("First time launching. Initialize Music Database")
            initMusicDB(filename: "/Users/benno/coding/swift/TrackStar/songs_table.json")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
