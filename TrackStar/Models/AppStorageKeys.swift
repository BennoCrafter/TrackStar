import SwiftUI

enum AppStorageKeys: String, Identifiable {
    case hasLaunchedBefore

    var id: String { self.rawValue }

    func keyName() -> String {
        return self.rawValue
    }

    func defaultValue() -> Any {
        switch self {
        case .hasLaunchedBefore:
            return false
        }
    }
}
