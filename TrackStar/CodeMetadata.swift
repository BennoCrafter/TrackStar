import Foundation

class CodeMetadata {
    var id: Int
    
    init(from s: String) {
        let components = s.split(separator: "=")
        
        // Check if there are exactly two components (key and value)
        if components.count == 2 {
            let key = String(components[0]) // "id"
            let value = String(components[1]) // "2"
            
            self.id = Int(value)!
        } else {
            print("Invalid format")
            self.id = 0
        }
    }
}

