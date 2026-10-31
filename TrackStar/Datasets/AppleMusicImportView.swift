import MusicKit
import SwiftUI

/// Makes a dataset from a playlist in the user's Apple Music library. The app prints its cards.
struct AppleMusicImportView: View {
    @State private var playlists: MusicItemCollection<Playlist> = []
    @State private var creating: Playlist.ID?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SongPickerView(onCreated: { dismiss() })
                } label: {
                    Label("Choose Songs", systemImage: "checklist")
                }
            } footer: {
                Text("Pick songs one by one from your library or all of Apple Music.")
            }

            Section("Playlists") {
                ForEach(playlists) { playlist in
                    Button {
                        Task { await create(from: playlist) }
                    } label: {
                        HStack(spacing: 12) {
                            if let artwork = playlist.artwork {
                                ArtworkImage(artwork, width: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else {
                                Image(systemName: "music.note.list")
                                    .frame(width: 44, height: 44)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            Text(playlist.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if creating == playlist.id {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(creating != nil)
                }
            }

            Section {} footer: {
                Text(yearNote)
            }
        }
        .navigationTitle("From Apple Music")
        .alert("Something Went Wrong", isPresented: Binding(get: { error != nil }, set: {
            if !$0 {
                error = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task { await load() }
    }

    private func load() async {
        guard await MusicAuthorization.request() == .authorized else {
            error = String(localized: "Allow TrackStar to access Apple Music in the Settings app.")
            return
        }
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.sort(by: \.name, ascending: true)
            playlists = try await request.response().items
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create(from playlist: Playlist) async {
        creating = playlist.id
        defer { creating = nil }
        do {
            let tracks = try await playlist.with([.tracks]).tracks ?? []
            let songs = tracks.enumerated().map { index, track in
                SongEntry(number: index + 1, title: track.title, artist: track.artistName, releaseDate: track.releaseDate, album: track.albumTitle)
            }
            guard !songs.isEmpty else {
                error = String(localized: "“\(playlist.name)” has no songs.")
                return
            }
            try Library.createLocal(displayName: playlist.name, songs: songs)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private let yearNote = String(localized: "Each song becomes a card. The year comes from Apple Music, which sometimes has the date of a remaster or compilation, so check the songs before printing.")

private extension SongEntry {
    init(number: Int, title: String, artist: String, releaseDate: Date?, album: String?) {
        self.init(id: number, title: title, artist: artist, year: releaseDate.map { Calendar.current.component(.year, from: $0) }, album: album)
    }
}

/// Pick single songs from the library or the Apple Music catalog for a new dataset.
private struct SongPickerView: View {
    enum Scope: Hashable {
        case library, catalog
    }

    let onCreated: () -> Void

    @State private var search = ""
    @State private var scope = Scope.library
    @State private var results: MusicItemCollection<Song> = []
    @State private var selected: [Song] = []
    @State private var isNaming = false
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        List {
            if !selected.isEmpty {
                Section("Selected (\(selected.count))") {
                    ForEach(selected) { row($0) }
                        .onDelete { selected.remove(atOffsets: $0) }
                }
            }
            Section(search.isEmpty && scope == .library ? "Recently Added" : "Results") {
                ForEach(results.filter { song in !selected.contains { $0.id == song.id } }) { row($0) }
            }
        }
        .navigationTitle("Choose Songs")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs or artists")
        .searchScopes($scope) {
            Text("Library").tag(Scope.library)
            Text("Apple Music").tag(Scope.catalog)
        }
        .overlay {
            if results.isEmpty, selected.isEmpty, !search.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { isNaming = true }
                    .disabled(selected.isEmpty)
            }
        }
        .alert("Name the Song Pack", isPresented: $isNaming) {
            TextField("Name", text: $name)
            Button("Create", action: create)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(yearNote)
        }
        .alert("Something Went Wrong", isPresented: Binding(get: { error != nil }, set: {
            if !$0 {
                error = nil
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        // Restarts on every keystroke; the sleep debounces typing.
        .task(id: "\(scope)|\(search)") {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func row(_ song: Song) -> some View {
        let isSelected = selected.contains { $0.id == song.id }
        return Button {
            if isSelected {
                selected.removeAll { $0.id == song.id }
            } else {
                selected.append(song)
            }
        } label: {
            HStack(spacing: 12) {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text([song.artistName, song.releaseDate.map { String(Calendar.current.component(.year, from: $0)) }].compactMap(\.self).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
    }

    private func load() async {
        guard await MusicAuthorization.request() == .authorized else {
            error = String(localized: "Allow TrackStar to access Apple Music in the Settings app.")
            return
        }
        do {
            switch scope {
            case .library:
                var request = MusicLibraryRequest<Song>()
                if search.isEmpty {
                    request.sort(by: \.libraryAddedDate, ascending: false)
                } else {
                    request.filter(text: search)
                }
                request.limit = 100
                results = try await request.response().items
            case .catalog:
                guard !search.isEmpty else {
                    results = []
                    return
                }
                var request = MusicCatalogSearchRequest(term: search, types: [Song.self])
                request.limit = 25
                results = try await request.response().songs
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create() {
        let songs = selected.enumerated().map { index, song in
            SongEntry(number: index + 1, title: song.title, artist: song.artistName, releaseDate: song.releaseDate, album: song.albumTitle)
        }
        do {
            try Library.createLocal(displayName: name.isEmpty ? "My Songs" : name, songs: songs)
            onCreated()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
