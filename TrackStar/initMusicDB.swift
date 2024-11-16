//
//  initMusicDB.swift
//  TrackStar
//
//  Created by Ben Baumeister on 16.11.24.
//

import Foundation

public func initMusicDB(filename: String) {
    let fileURL = URL(fileURLWithPath: filename)

    do {
        // Load the data from the local file
        let fileData = try Data(contentsOf: fileURL)
        print("File loaded successfully.")
        
        // Now you can use this data with the JSONDataManager
        
        let fileName = "musicDB.json"
        let success = JSONDataManager.save(jsonData: fileData, fileName: fileName)
        if success {
            print("File saved successfully to app directory.")
        }
    } catch {
        print("Error loading file: \(error.localizedDescription)")
    }
}
