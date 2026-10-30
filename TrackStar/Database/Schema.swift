import Foundation
import OSLog
import SQLiteData

let logger = Logger(subsystem: "com.bennowo.trackstar", category: "TrackStar")

/// A song list the cards point to. Remote ones mirror a folder in the repo's `datasets/`.
@Table("datasets")
struct Dataset: Identifiable, Hashable, Sendable {
    /// The folder name in the repo (`hitster`). The card QR codes carry it too
    /// (`trackstar://hitster/?id=1`), which is how a scan picks its dataset.
    let id: String
    var displayName: String
    /// `info.json`'s version; a higher remote one means the songs changed.
    var version: Int = 0
    var songCount: Int = 0
    /// Imported from a file: no cards, README or updates.
    var isRemote: Bool = true
    var isActive: Bool = false
    /// `info.json`'s icon: an SF Symbol name or an emoji.
    var icon: String?
    /// `info.json`'s `"type": "artist"`: one artist's songs, placed by album instead of year.
    var isArtist: Bool = false
}

/// One card of a dataset. `number` is the id printed on the card and encoded in its QR code.
@Table("tracks")
struct Track: Identifiable, Hashable, Sendable, Codable {
    let id: Int
    var datasetID: String
    var number: Int
    var title: String
    var artist: String
    var year: Int?
    var album: String?
}

/// Someone who played a game without cards; remembered for the next one.
@Table("players")
struct Player: Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
}

enum Schema {
    static func appDatabase() throws -> any DatabaseWriter {
        let database = try defaultDatabase()
        logger.info("Open database: \(database.path)")
        try migrator().migrate(database)
        return database
    }

    /// Never edit a registered migration; append new ones.
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create datasets and tracks") { db in
            try #sql(
                """
                CREATE TABLE "datasets" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "displayName" TEXT NOT NULL,
                  "version" INTEGER NOT NULL DEFAULT 0,
                  "songCount" INTEGER NOT NULL DEFAULT 0,
                  "isRemote" INTEGER NOT NULL DEFAULT 1,
                  "isActive" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            ).execute(db)
            try #sql(
                """
                CREATE TABLE "tracks" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "datasetID" TEXT NOT NULL REFERENCES "datasets"("id") ON DELETE CASCADE,
                  "number" INTEGER NOT NULL,
                  "title" TEXT NOT NULL,
                  "artist" TEXT NOT NULL,
                  "year" INTEGER,
                  "album" TEXT,
                  UNIQUE("datasetID", "number")
                ) STRICT
                """
            ).execute(db)
        }
        migrator.registerMigration("Create players") { db in
            try #sql(
                """
                CREATE TABLE "players" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "name" TEXT NOT NULL UNIQUE COLLATE NOCASE
                ) STRICT
                """
            ).execute(db)
        }
        migrator.registerMigration("Add dataset icon") { db in
            try #sql(#"ALTER TABLE "datasets" ADD COLUMN "icon" TEXT"#).execute(db)
        }
        migrator.registerMigration("Add dataset isArtist") { db in
            try #sql(#"ALTER TABLE "datasets" ADD COLUMN "isArtist" INTEGER NOT NULL DEFAULT 0"#).execute(db)
        }
        return migrator
    }
}
