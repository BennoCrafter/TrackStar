class MusicDBManager {
    static var shared = MusicDBManager()
    
    private var dbSongs: [DBSong] = [] // Store the decoded songs
    private var dbSongsCount: Int = 0
    
    private init() {
        loadData()
    }
    
    // Method to load and decode the musicDB.json file
    private func loadData() {
        if let jsonData = JSONDataManager.load(fileName: "musicDB.json") {
            if let decodedSongs: [DBSong] = JSONDataManager.decode(jsonData: jsonData, toType: [DBSong].self) {
                dbSongs = decodedSongs // Store the decoded songs
                dbSongsCount = dbSongs.count
            } else {
                dbSongs = []
                print("Failed to decode songs")
            }
        } else {
            dbSongs = []
            print("Failed to load musicDB.json")
        }
    }
    
    public func getSongById(_ id: Int) -> DBSong? {
        let modId = id % dbSongsCount
        return dbSongs.first(where: {$0.id == modId})
    }
}
