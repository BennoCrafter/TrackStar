import Foundation

class DBSong: Decodable {
    var artist: String
    var title: String
    var album: String?
    var image: String?
    var year: Int
    
    var id: Int
}
