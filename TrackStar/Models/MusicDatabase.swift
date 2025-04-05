import Foundation
import SwiftData

struct GithubAPIFile: Codable {
    var name: String
    var url: URL
    var download_url: URL
}

struct GithubAPIFiles: Codable {
    let files: [GithubAPIFile]

    init(fromURL url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            files = []
            return
        }

        let decoder = JSONDecoder()
        do {
            files = try decoder.decode([GithubAPIFile].self, from: data)
        } catch {
            files = []
        }
    }

    func find(with name: String) -> GithubAPIFile? {
        return files.first(where: { $0.name == name })
    }
}

@Model
class MusicDatabaseInfo: Codable {
    var displayName: String
    var name: String

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decode(String.self, forKey: .displayName)
        name = try container.decode(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(name, forKey: .name)
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case name
    }

    static func fromURL(_ url: URL) -> MusicDatabaseInfo? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let decodedInfo = try decoder.decode(MusicDatabaseInfo.self, from: data)
            return decodedInfo
        } catch {
            return nil
        }
    }
}

@Model
class MusicDatabase {
    var link: DatabaseItemReference
    var readmeLink: DatabaseItemReference?
    var songsLink: DatabaseItemReference
    var cardsLink: DatabaseItemReference?
    var infoLink: DatabaseItemReference?

    var songs: [DBSong] = []
    var info: MusicDatabaseInfo?

    // Initialize stored properties first before calling methods
    init(link: DatabaseItemReference, readmeLink: DatabaseItemReference? = nil, songsLink: DatabaseItemReference, cardsLink: DatabaseItemReference? = nil, infoLink: DatabaseItemReference? = nil, songs: [DBSong] = []) {
        self.link = link
        self.readmeLink = readmeLink
        self.songsLink = songsLink
        self.cardsLink = cardsLink
        self.infoLink = infoLink
        self.songs = songs
    }

    /// init from url like https://api.github.com/repos/BennoCrafter/TrackStar/contents/datasets/hitster_songDB
    init?(fromGlobal sourceURL: URL) async {
        let githubFiles = GithubAPIFiles(fromURL: sourceURL)

        guard let infoGithubFile = githubFiles.find(with: "info.json") else { return nil }

        guard let musicInfo = MusicDatabaseInfo.fromURL(infoGithubFile.download_url) else {
            return nil
        }

        info = musicInfo
        infoLink = await DatabaseItemReference(from: infoGithubFile.download_url, datasetName: musicInfo.name)

        link = DatabaseItemReference(sourceURL: sourceURL, localURL: getDatasetDirectory(for: musicInfo.name))

        if let readmeGithubFile = githubFiles.find(with: "README.md") {
            readmeLink = await DatabaseItemReference(from: readmeGithubFile.download_url, datasetName: musicInfo.name)
        }

        if let cardsGithubFile = githubFiles.find(with: "cards.pdf") {
            cardsLink = await DatabaseItemReference(from: cardsGithubFile.download_url, datasetName: musicInfo.name)
        }

        if let songsGithubFile = githubFiles.find(with: "songs.json") {
            if let songsRef = await DatabaseItemReference(from: songsGithubFile.download_url, datasetName: musicInfo.name) {
                songsLink = songsRef
            } else {
                print("Failed to find songs. Sorry.")
                return nil
            }
        } else {
            return nil
        }

        refreshSongs()
    }

    init?(fromLocal localURL: URL, name: String?) {
        let datasetName = name ?? localURL.extractFileNameWithoutExtension()

        link = DatabaseItemReference(localURL: getDatasetDirectory(for: datasetName))

        guard let localSongsLink = DatabaseItemReference(fromUser: localURL, datasetName: datasetName) else {
            print("Failed to load from your local file.")
            return nil
        }

        songsLink = localSongsLink

        refreshSongs()
    }

    func refreshSongs() {
        guard let data = try? Data(contentsOf: songsLink.localURL) else {
            return
        }

        let decoder = JSONDecoder()
        do {
            songs = try decoder.decode([DBSong].self, from: data)
        } catch {
            return
        }
    }

    func update() {
        refreshInfo()
        refreshSongs()
    }

    func refreshInfo() {
        guard let infoURL = infoLink?.sourceURL else {
            print("Failed to refresh info for music database \(self)")
            return
        }
        if let newInfo = MusicDatabaseInfo.fromURL(infoURL) {
            info = newInfo
        } else {
            print("Failed to refresh info for music database. (Decoding failed) \(self)")
        }
    }

    public func getSongById(_ id: Int) -> DBSong? {
        guard songs.count != 0 else { return nil }
        let modId = id % songs.count
        return songs.first(where: { $0.id == modId })
    }
}

@Model
class DatabaseItemReference {
    /// local sandboxed url
    var localURL: URL
    /// url from provider like github (raw)
    var sourceURL: URL?

    init(sourceURL: URL? = nil, localURL: URL) {
        self.sourceURL = sourceURL
        self.localURL = localURL
    }

    init?(from sourceURL: URL, datasetName: String) async {
        self.sourceURL = sourceURL
        guard let downloadedURL = await sourceURL.download(datasetName: datasetName) else {
            return nil
        }
        localURL = downloadedURL
    }

    init?(fromUser userFile: URL, datasetName: String) {
        do {
            let directory = getDatasetDirectory(for: datasetName)
            localURL = directory.appendingPathComponent(userFile.lastPathComponent)

            guard userFile.startAccessingSecurityScopedResource() else {
                return nil
            }

            let dataFromMusicDb = try Data(contentsOf: userFile)
            try dataFromMusicDb.write(to: localURL)
            userFile.stopAccessingSecurityScopedResource()

        } catch {
            print("Error copying file: \(error.localizedDescription)")
            return nil
        }
    }
}

extension URL {
    func download(datasetName: String) async -> URL? {
        do {
            let (data, _) = try await URLSession.shared.data(from: self)
            let savePath = getDatasetDirectory(for: datasetName).appendingPathComponent(extractFileNameWithoutExtension())

            try data.write(to: savePath)
            return savePath
        } catch {
            print("Download error for \(self): \(error)")
            return nil
        }
    }
}

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
