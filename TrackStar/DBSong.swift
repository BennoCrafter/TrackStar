import Foundation

class DBSong: Codable {
    var artist: String
    var title: String
    var album: String
    var image: URL
    var year: Int
    
    var id: Int
}
