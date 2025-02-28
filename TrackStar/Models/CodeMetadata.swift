import Foundation
import SwiftUI

class CodeMetadata {
    @AppStorage("hitsterMode") var hitsterMode: Bool = false

    var id: Int

    init(from s: String) {
        self.id = -1

        if !hitsterMode {
            fromTrackStarString(s)
        } else {
            fromHitsterString(s)
        }
    }

    func fromTrackStarString(_ s: String) {
        let components = s.split(separator: "=")

        // Check if there are exactly two components (key and value)
        if components.count == 2 {
            let key = String(components[0]) // "id"
            let value = String(components[1]) // "2"

            id = Int(value)!
        } else {
            print("Invalid format")
            id = 0
        }
    }

    func fromHitsterString(_ s: String) {
        guard let url = URL(string: s) else { return }
        let pathComponents = url.pathComponents

        if let idComp = pathComponents.last {
            id = Int(idComp) ?? -1
        }
    }
}
