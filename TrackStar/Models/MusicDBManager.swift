import Foundation

class MusicDBManager {
    static var shared = MusicDBManager()

    private var dbSongs: [DBSong] = []

    func configure(with songs: [DBSong]) {
        dbSongs = songs
    }

    public func getSongById(_ id: Int) -> DBSong? {
        guard dbSongs.count != 0 else { return nil }
        let modId = id % dbSongs.count
        return dbSongs.first(where: { $0.id == modId })
    }
}
