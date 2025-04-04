import Foundation
import SwiftData

@Model
class DBSong: Codable {
    var artist: String
    var title: String
    var album: String?
    var image: String?
    var year: Int
    var id: Int
    
    var musicDatabase: MusicDatabase?
    
    init(artist: String, title: String, album: String? = nil, image: String? = nil, year: Int, id: Int) {
        self.artist = artist
        self.title = title
        self.album = album
        self.image = image
        self.year = year
        self.id = id
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artist = try container.decode(String.self, forKey: .artist)
        title = try container.decode(String.self, forKey: .title)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        year = try container.decode(Int.self, forKey: .year)
        id = try container.decode(Int.self, forKey: .id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(artist, forKey: .artist)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encode(year, forKey: .year)
        try container.encode(id, forKey: .id)
    }
    
    enum CodingKeys: String, CodingKey {
        case artist
        case title
        case album
        case image
        case year
        case id
    }
}
