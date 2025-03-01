import SwiftUI

class CodeMetadata {
    var id: Int

    init(from s: String) {
        self.id = -1
        parseMetadata(from: s)
    }

    func parseMetadata(from s: String) {
        fatalError("Subclasses must override this method")
    }
}

class TrackStarMetadata: CodeMetadata {
    override func parseMetadata(from s: String) {
        let components = s.split(separator: "=")

        guard components.count == 2, let value = Int(components[1]) else {
            print("Invalid format for TrackStarString: \(s)")
            id = -1
            return
        }
        id = value
    }
}

class HitsterMetadata: CodeMetadata {
    override func parseMetadata(from s: String) {
        guard let url = URL(string: s), let lastComponent = url.pathComponents.last, let parsedId = Int(lastComponent) else {
            print("Invalid format for HitsterString: \(s)")
            id = -1
            return
        }
        id = parsedId
    }
}

class MetadataFactory {
    @AppStorage("hitsterMode") private var hitsterMode: Bool = false
    static let shared: MetadataFactory = .init()

    func createMetadata(from s: String) -> CodeMetadata {
        return hitsterMode ? HitsterMetadata(from: s) : TrackStarMetadata(from: s)
    }
}
