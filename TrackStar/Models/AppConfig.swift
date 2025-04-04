import SwiftData
import SwiftUI
    
@Model
class AppConfig: ObservableObject {
    var useRandomPlaybackInterval: Bool = false
    var playbackTimeInterval: TimeInterval = 20
    var useHitsterQRCodes: Bool = false

    init() {}
}
