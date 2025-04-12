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
    var displayName: String?
    var name: String

    init(name: String, displayName: String?) {
        self.name = name
        self.displayName = name
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
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

    var isActive: Bool = false

    init(link: DatabaseItemReference, readmeLink: DatabaseItemReference? = nil, songsLink: DatabaseItemReference, cardsLink: DatabaseItemReference? = nil, infoLink: DatabaseItemReference? = nil, songs: [DBSong] = [], isActive: Bool = true) {
        self.link = link
        self.readmeLink = readmeLink
        self.songsLink = songsLink
        self.cardsLink = cardsLink
        self.infoLink = infoLink
        self.songs = songs
        self.isActive = isActive
    }

    init?(fromGlobal sourceURL: URL) async {
        let githubFiles = GithubAPIFiles(fromURL: sourceURL)

        guard let infoGithubFile = githubFiles.find(with: "info.json"),
              let musicInfo = MusicDatabaseInfo.fromURL(infoGithubFile.download_url)
        else {
            print("Missing info.json or failed to parse it")
            return nil
        }

        info = musicInfo
        infoLink = DatabaseItemReference(sourceURL: infoGithubFile.download_url)
        link = DatabaseItemReference(sourceURL: sourceURL, localURL: getDatasetDirectory(for: musicInfo.name))

        if let readmeGithubFile = githubFiles.find(with: "README.md") {
            readmeLink = DatabaseItemReference(sourceURL: readmeGithubFile.download_url)
        }

        if let cardsGithubFile = githubFiles.find(with: "cards.pdf") {
            cardsLink = DatabaseItemReference(sourceURL: cardsGithubFile.download_url)
        }

        guard let songsGithubFile = githubFiles.find(with: "songs.json") else {
            print("Missing songs.json")
            return nil
        }

        songsLink = DatabaseItemReference(sourceURL: songsGithubFile.download_url)
    }

    init?(fromLocal localURL: URL, name: String?) {
        let datasetName = name ?? localURL.extractFileNameWithoutExtension()
        info = MusicDatabaseInfo(name: datasetName, displayName: nil)
        link = DatabaseItemReference(localURL: getDatasetDirectory(for: datasetName))

        guard let localSongsLink = DatabaseItemReference(fromUser: localURL, datasetName: datasetName) else {
            print("Failed to load from your local file.")
            return nil
        }

        songsLink = localSongsLink
        if !refreshSongs() {
            return nil
        }
    }

    func refreshSongs() -> Bool {
        guard let localURL = songsLink.localURL else { return false }
        guard let data = try? Data(contentsOf: localURL) else { return false }

        do {
            songs = try JSONDecoder().decode([DBSong].self, from: data)
            return true
        } catch {
            print("Failed to decode songs")
            return false
        }
    }

    func refreshInfo() {
        guard let infoURL = infoLink?.sourceURL else {
            print("Missing infoLink")
            return
        }
        if let newInfo = MusicDatabaseInfo.fromURL(infoURL) {
            info = newInfo
        } else {
            print("Failed to parse info from URL")
        }
    }

    func deleteFileReferences() {
        link.delete()
        songsLink.delete()

        if let readmeLink = readmeLink {
            readmeLink.delete()
        }
        if let cardsLink = cardsLink {
            cardsLink.delete()
        }
        if let infoLink = infoLink {
            infoLink.delete()
        }
    }

    func update() {
        refreshInfo()
        _ = refreshSongs()
    }

    public func getSongById(_ id: Int) -> DBSong? {
        guard !songs.isEmpty else { return nil }
        let modId = id % songs.count
        return songs.first(where: { $0.id == modId })
    }

    /// Manually trigger download of all remote files
    func downloadAll() async -> Bool {
        guard let datasetName = info?.name else { return false }

        async let downloadedInfo = infoLink?.download(datasetName: datasetName)
        async let downloadedSongs = songsLink.download(datasetName: datasetName)
        async let downloadedReadme = readmeLink?.download(datasetName: datasetName)
        async let downloadedCards = cardsLink?.download(datasetName: datasetName)

        let results = await [downloadedInfo, downloadedSongs, downloadedReadme, downloadedCards]

        // Only proceed if all required downloads succeed
        guard results[1] != nil else {
            print("Failed to download songs")
            return false
        }

        _ = refreshSongs()
        return true
    }
}

@Model
class DatabaseItemReference: Equatable {
    var localURL: URL?
    var sourceURL: URL?

    init(sourceURL: URL? = nil, localURL: URL? = nil) {
        self.sourceURL = sourceURL
        self.localURL = localURL
    }

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    init?(fromUser userFile: URL, datasetName: String) {
        do {
            let directory = getDatasetDirectory(for: datasetName)
            let sandboxedLocalURL = directory.appendingPathComponent(userFile.lastPathComponent)
            localURL = sandboxedLocalURL

            guard userFile.startAccessingSecurityScopedResource() else {
                return nil
            }

            let data = try Data(contentsOf: userFile)
            try data.write(to: sandboxedLocalURL)
            userFile.stopAccessingSecurityScopedResource()

        } catch {
            print("Error copying file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Manually download from source URL
    func download(datasetName: String) async -> URL? {
        guard let source = sourceURL else {
            print("Missing source URL")
            return nil
        }
        guard let downloadedURL = await source.download(datasetName: datasetName) else {
            print("Download failed for \(source)")
            return nil
        }
        localURL = downloadedURL
        return localURL
    }

    func delete() {
        guard let localURL = localURL else { return }
        do {
            if FileManager.default.fileExists(atPath: localURL.path()) {
                try FileManager.default.removeItem(at: localURL)
                print("File deleted successfully.")
            } else {
                print("File not found at path: \(localURL.path)")
            }
        } catch {
            print("Error deleting file: \(error)")
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
