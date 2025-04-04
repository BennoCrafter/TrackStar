import Foundation
import SwiftData

@Model
class CachedFiles {
    var readme: URL?
    var musicDB: URL?

    init(readme: URL? = nil, musicDB: URL? = nil) {
        self.readme = readme
        self.musicDB = musicDB
    }
}

@Model
class MusicDatabase {
    var source: URL?
    var localSource: URL?

    var cachedFiles: CachedFiles = CachedFiles()
    var dbSongs: [DBSong] = []
    var musicDBName: String?
//
//    init(source: URL, localSource: URL) {
//        self.source = source
//        self.localSource = localSource
//    }

    init() {}

    func loadLocalDB(musicDB: URL) {
        resetDB()
        musicDBName = musicDB.extractFileNameWithoutExtension()
        let loc = getDatasetDirectory(for: musicDB.extractFileNameWithoutExtension())
        localSource = loc

        do {
            guard musicDB.startAccessingSecurityScopedResource() else {
                return
            }
            try print(String(contentsOf: musicDB, encoding: .utf8))

            let db = loc.appendingPathComponent(musicDB.lastPathComponent)
            let dataFromMusicDb = try Data(contentsOf: musicDB)
            try dataFromMusicDb.write(to: db)
            musicDB.stopAccessingSecurityScopedResource()
            cachedFiles = CachedFiles(musicDB: db)
            loadSongs()
        } catch {
            print("Error copying file: \(error.localizedDescription)")
        }
    }

    /// Init a new Database from a URL like https://github.com/BennoCrafter/TrackStar/tree/main/datasets/taylor_swift_songDB

    func loadGlobalDB(source: URL) async {
        resetDB()
        self.source = source
        musicDBName = source.lastPathComponent
        localSource = await downloadFiles(from: source)
    }

    /// Download all needed files of a GitHub dataset URL and return local URL where it gets stored
    func downloadFiles(from source: URL) async -> URL? {
        guard let rawURL = source.toRawGithubUserContent() else { return nil }

        let datasetDirectory = getDatasetDirectory(for: source.lastPathComponent)
        try? FileManager.default.createDirectory(at: datasetDirectory, withIntermediateDirectories: true)

        await fetchREADME(source: source, rawURL: rawURL)
        await fetchDB(source: source, rawURL: rawURL, dbName: "\(source.lastPathComponent).json")

        return datasetDirectory
    }

    func fetchREADME(source: URL, rawURL: URL) async {
        cachedFiles.readme = await fetchFile(source: source, rawURL: rawURL, name: "README.md")
    }

    func fetchDB(source: URL, rawURL: URL, dbName: String) async {
        cachedFiles.musicDB = await fetchFile(source: source, rawURL: rawURL, name: dbName)
    }

    func fetchFile(source: URL, rawURL: URL, name: String) async -> URL? {
        guard let fileURL = rawURL.appendingPathComponent(name) as URL? else { return nil }
        return await downloadFile(from: fileURL, fileName: name, datasetName: source.lastPathComponent)
    }

    func downloadFile(from url: URL, fileName: String, datasetName: String) async -> URL? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let savePath = getDatasetDirectory(for: datasetName).appendingPathComponent(fileName)

            try data.write(to: savePath)
            return savePath
        } catch {
            print("Download error for \(fileName): \(error)")
            return nil
        }
    }

    /// Function to get the `datasets` directory
    func getDatasetDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("datasets")
    }

    func getDatasetDirectory(for datasetName: String) -> URL {
        let d = getDatasetDirectory().appendingPathComponent(datasetName)
        if !FileManager.default.fileExists(atPath: d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    func loadSongs() {
        do {
            guard let musicDBURL = cachedFiles.musicDB else { return }
            print(musicDBURL)
            do {
                let contents = try String(contentsOf: musicDBURL, encoding: .utf8)
                print(contents)
            } catch {
                print("Error reading file: \(error.localizedDescription)")
            }
            let dbData = try Data(contentsOf: musicDBURL)
            let decoder = JSONDecoder()
            dbSongs = try decoder.decode([DBSong].self, from: dbData)
            try modelContext?.save()
        } catch {
            print("Failed to load db songs")
        }
    }

    public func getSongById(_ id: Int) -> DBSong? {
        print(dbSongs)
        guard dbSongs.count != 0 else { return nil }
        let modId = id % dbSongs.count
        return dbSongs.first(where: { $0.id == modId })
    }

    func resetDB() {
        cachedFiles = CachedFiles()
        dbSongs = []
        source = nil
        localSource = nil
        musicDBName = nil
    }
}

extension URL {
    /// Converts a GitHub repo `tree` URL to a `raw.githubusercontent.com` URL
    func toRawGithubUserContent() -> URL? {
        let urlString = absoluteString

        guard urlString.contains("github.com"),
              let components = URLComponents(string: urlString)
        else {
            return nil
        }

        var pathComponents = components.path.split(separator: "/")

        guard pathComponents.count > 3,
              let treeIndex = pathComponents.firstIndex(of: "tree"),
              treeIndex + 1 < pathComponents.count
        else {
            return nil
        }

        let username = pathComponents[0]
        let repo = pathComponents[1]
        let branch = pathComponents[treeIndex + 1]

        pathComponents.removeSubrange(treeIndex ... (treeIndex + 1))

        let rawURLString = "https://raw.githubusercontent.com/\(username)/\(repo)/\(branch)/" + pathComponents.dropFirst(2).joined(separator: "/")

        return URL(string: rawURLString)
    }

    /// Get last path component without extension. Comparable to python Path.name
    func extractFileNameWithoutExtension() -> String {
        guard let lastPathComponent = lastPathComponent.split(separator: ".").first else {
            return lastPathComponent
        }
        return String(lastPathComponent)
    }
}
