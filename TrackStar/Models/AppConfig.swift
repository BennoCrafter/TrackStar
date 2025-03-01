import SwiftData
import SwiftUI

@Model
class AppConfig: ObservableObject {
    var useRandomPlaybackInterval: Bool = false
    var playbackTimeInterval: TimeInterval = 20
    var musicDBName: String? = nil

    init(useRandomPlaybackInterval: Bool = false, musicDBName: String? = nil, playbackTimeInterval: TimeInterval = 20) {
        self.useRandomPlaybackInterval = useRandomPlaybackInterval
        self.playbackTimeInterval = playbackTimeInterval
        self.musicDBName = musicDBName
    }
}
