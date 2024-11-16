//
//  Item.swift
//  TrackStar
//
//  Created by Ben Baumeister on 16.11.24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
