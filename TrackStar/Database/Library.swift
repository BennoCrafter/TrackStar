import Foundation
import SQLiteData

/// A dataset folder in the repo, as its `info.json` describes it.
struct RemoteDataset: Identifiable, Hashable, Decodable, Sendable {
    let name: String
    let displayName: String?
    let version: Int
    /// An SF Symbol name or an emoji.
    let icon: String?

    var id: String { name }
    var title: String { displayName ?? name }

    enum CodingKeys: String, CodingKey {
        case name, version, icon
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
    }
}

/// An entry of a `songs.json` (see backend/README.md).
struct SongEntry: Decodable, Sendable {
    let id: Int
    let title: String
    let artist: String
    let year: Int?
    let album: String?
}

/// Downloads, imports and removes datasets. The database is the only state; views observe it.
enum Library {
    static let repositoryURL = URL(string: "https://github.com/BennoCrafter/TrackStar")!
    private static let listURL = URL(string: "https://api.github.com/repos/BennoCrafter/TrackStar/contents/datasets")!
    private static let rawURL = URL(string: "https://raw.githubusercontent.com/BennoCrafter/TrackStar/main/datasets")!

    /// No local cache: a dataset pushed a minute ago should show up on pull to refresh.
    private static let session = URLSession(configuration: {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }())

    static func fileURL(_ dataset: String, _ file: String) -> URL {
        rawURL.appending(path: dataset).appending(path: file)
    }

    // MARK: - Remote

    /// One GitHub API call for the folder list (60/hour without a token), then raw files.
    static func catalog() async throws -> [RemoteDataset] {
        struct Entry: Decodable { let name: String; let type: String }
        let entries: [Entry] = try JSONDecoder().decode([Entry].self, from: await data(listURL))
        return await withTaskGroup(of: RemoteDataset?.self) { group in
            for entry in entries where entry.type == "dir" {
                group.addTask { try? await info(entry.name) }
            }
            var result: [RemoteDataset] = []
            for await dataset in group {
                if let dataset { result.append(dataset) }
            }
            return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    static func info(_ name: String) async throws -> RemoteDataset {
        try await JSONDecoder().decode(RemoteDataset.self, from: data(fileURL(name, "info.json")))
    }

    static func readme(_ name: String) async throws -> String {
        try await String(decoding: data(fileURL(name, "README.md")), as: UTF8.self)
    }

    static func install(_ remote: RemoteDataset) async throws {
        let songs = try await JSONDecoder().decode([SongEntry].self, from: data(fileURL(remote.name, "songs.json")))
        try save(id: remote.name, displayName: remote.title, version: remote.version, isRemote: true, icon: remote.icon, songs: songs)
    }

    /// Re-downloads every remote dataset whose `info.json` has a higher version.
    static func updateAll() async {
        @Dependency(\.defaultDatabase) var database
        let installed = (try? await database.read { try Dataset.where(\.isRemote).fetchAll($0) }) ?? []
        for dataset in installed {
            guard let remote = try? await info(dataset.id) else { continue }
            if remote.icon != dataset.icon {
                try? await database.write { try Dataset.find(dataset.id).update { $0.icon = remote.icon }.execute($0) }
            }
            guard remote.version > dataset.version else { continue }
            do {
                try await install(remote)
                logger.info("Updated \(dataset.id) to version \(remote.version)")
            } catch {
                logger.error("Updating \(dataset.id) failed: \(error)")
            }
        }
    }

    private static func data(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: url])
        }
        return data
    }

    // MARK: - Cards

    /// `cards.pdf` of a dataset, kept so the cards open offline too.
    static func cardsFile(_ name: String) -> URL {
        URL.documentsDirectory.appending(path: "Cards/\(name).pdf")
    }

    /// Always tries a fresh copy: a new card design changes the PDF without raising the version.
    static func downloadCards(_ name: String) async throws -> URL {
        let file = cardsFile(name)
        do {
            let pdf = try await data(fileURL(name, "cards.pdf"))
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try pdf.write(to: file, options: .atomic)
        } catch where FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            logger.info("Cards download failed, showing the saved copy: \(error)")
        }
        return file
    }

    // MARK: - Local

    /// Imports a `songs.json` picked in Files.
    static func importFile(_ url: URL, displayName: String) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let songs = try JSONDecoder().decode([SongEntry].self, from: Data(contentsOf: url))
        try createLocal(displayName: displayName, songs: songs)
    }

    /// A dataset only on this device. Its cards are printed by the app (see `CardPrinter`).
    static func createLocal(displayName: String, songs: [SongEntry]) throws {
        // Lowercase: the id is the host of the card URLs.
        try save(id: "local-\(UUID().uuidString.lowercased())", displayName: displayName, version: 0, isRemote: false, songs: songs)
    }

    // MARK: - Database

    /// Replaces the dataset and its tracks. The first dataset becomes the active one.
    static func save(id: String, displayName: String, version: Int, isRemote: Bool, icon: String? = nil, songs: [SongEntry]) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            let wasActive = try Dataset.find(id).fetchOne(db)?.isActive
            let hasActive = try Dataset.where(\.isActive).fetchCount(db) > 0
            // Cascades to the old tracks.
            try Dataset.find(id).delete().execute(db)
            try Dataset.insert {
                Dataset(id: id, displayName: displayName, version: version, songCount: songs.count, isRemote: isRemote, isActive: wasActive ?? !hasActive, icon: icon)
            }.execute(db)
            try Track.insert {
                for song in songs {
                    Track.Draft(datasetID: id, number: song.id, title: song.title, artist: song.artist, year: song.year, album: song.album)
                }
            }.execute(db)
        }
    }

    static func activate(_ id: String) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Dataset.update { $0.isActive = $0.id.eq(id) }.execute(db)
        }
    }

    static func delete(_ id: String) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Dataset.find(id).delete().execute(db)
        }
        try? FileManager.default.removeItem(at: cardsFile(id))
    }

    static func track(dataset: String, number: Int) throws -> Track? {
        @Dependency(\.defaultDatabase) var database
        return try database.read { db in
            try Track.where { $0.datasetID.eq(dataset) && $0.number.eq(number) }.fetchOne(db)
        }
    }
}
