import Foundation

class CodeMetadata {
    var id: Int

    init(id: Int) {
        self.id = id
    }
}

enum CodeMetadataPattern: String, CaseIterable {
    case trackStar = #"^id=(\d+)$"#
    case hitster = #"www.hitstergame.com/de/(\d+)"#
}

func parseMetadata(from s: String, with pattern: CodeMetadataPattern) -> CodeMetadata? {
    if let metadata = parseWithRegex(from: s, regex: pattern.rawValue) {
        return metadata
    }

    print("No matching metadata format found for: \(s)")
    return nil
}

private func parseWithRegex(from s: String, regex: String) -> CodeMetadata? {
    let regex = try! NSRegularExpression(pattern: regex)
    let range = NSRange(location: 0, length: s.utf16.count)

    if let match = regex.firstMatch(in: s, options: [], range: range) {
        if let idRange = Range(match.range(at: 1), in: s) {
            if let id = Int(s[idRange]) {
                return CodeMetadata(id: id)
            }
        }
    }

    return nil
}
