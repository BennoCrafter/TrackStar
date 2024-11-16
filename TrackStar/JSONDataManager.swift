import Foundation

class JSONDataManager {

    // Path to the directory where the data will be stored
    static var documentDirectory: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // Function to save large JSON data to a file
    static func save(jsonData: Data, fileName: String) -> Bool {
        guard let directory = documentDirectory else {
            print("Unable to access document directory.")
            return false
        }
        
        let fileURL = directory.appendingPathComponent(fileName)
        
        do {
            // Write the data to disk
            try jsonData.write(to: fileURL)
            print("Data saved to \(fileURL.path)")
            return true
        } catch {
            print("Error saving data: \(error.localizedDescription)")
            return false
        }
    }

    // Function to load large JSON data from a file
    static func load(fileName: String) -> Data? {
        guard let directory = documentDirectory else {
            print("Unable to access document directory.")
            return nil
        }
        
        let fileURL = directory.appendingPathComponent(fileName)
        
        do {
            // Read the data from the file
            let data = try Data(contentsOf: fileURL)
            print("Data loaded from \(fileURL.path)")
            return data
        } catch {
            print("Error loading data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Function to decode JSON data into a custom object (example: Decodable object)
    static func decode<T: Decodable>(jsonData: Data, toType type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let object = try decoder.decode(T.self, from: jsonData)
            return object
        } catch {
            print("Error decoding data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Function to encode an object to JSON data
    static func encode<T: Encodable>(object: T) -> Data? {
        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(object)
            return jsonData
        } catch {
            print("Error encoding object: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func copyFile(from sourceURL: URL, to destinationURL: URL) -> Bool {
        if sourceURL.startAccessingSecurityScopedResource() {
            do {
                // Copy the file from source to destination
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                print("File copied from \(sourceURL.path) to \(destinationURL.path)")
                sourceURL.stopAccessingSecurityScopedResource()
                return true
            } catch {
                print("Error copying file: \(error.localizedDescription)")
                sourceURL.stopAccessingSecurityScopedResource()
                return false
            }
        }
        else {
            return false
        }
    }
    
    static func copyFile(from sourceURL: URL, withName fileName: String) -> Bool {
        // Ensure the destination directory exists
        guard let directory = documentDirectory else {
            print("Unable to access document directory.")
            return false
        }
        
        let destinationURL = directory.appendingPathComponent(fileName)
        
        return copyFile(from: sourceURL, to: destinationURL)
    }
}
