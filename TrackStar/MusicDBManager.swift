import Foundation

class MusicDBManager {
    static var shared = MusicDBManager()
    
    let musicDB = JSONDataManager.load(fileName: <#T##String#>)
    init() {}
    
    public func getSongById(_ id: Int) -> DBSong {
        
    }
}
