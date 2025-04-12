import MarkdownUI
import SwiftUI

// MARK: - Global Source Tab with enhanced UI

struct GlobalSource: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var datasetsDatabases: [MusicDatabase] = []
    @State private var isLoading: Bool = false
    @State private var searchText: String = ""
    var onDatabaseSelected: (MusicDatabase) -> Void

    var filteredDatabases: [MusicDatabase] {
        if searchText.isEmpty {
            return datasetsDatabases
        } else {
            return datasetsDatabases.filter {
                $0.info?.displayName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                    $0.info?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search databases", text: $searchText)
                    .padding(.vertical, 8)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()

            // Content
            ScrollView {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading TrackStar datasets...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 100)
                } else if filteredDatabases.isEmpty {
                    EmptyDatabasesView(
                        searchActive: !searchText.isEmpty,
                        onRefresh: { Task { await fetchDatasets() } }
                    )
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredDatabases) { dataset in
                            NavigationLink(destination: ReadmeView(dataset: dataset)) {
                                DatasetCardView(dataset: dataset)
                                    .padding()
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarTitle("TrackStar Datasets", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { Task { await fetchDatasets() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            if SessionState.shared.isFirstTimeDatasetsLoadingGlobalSource {
                SessionState.shared.isFirstTimeDatasetsLoadingGlobalSource = false
                isLoading = true
                Task {
                    await fetchDatasets()
                }
            }
        }
        .refreshable {
            Task {
                await fetchDatasets()
            }
        }
    }

    struct DatasetCardView: View {
        let dataset: MusicDatabase

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "music.quarternote.3")
                        .foregroundColor(.blue)
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataset.info?.displayName ?? dataset.info?.name ?? "Unknown")
                            .font(.headline)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .buttonStyle(PlainButtonStyle())
        }
    }

    // Empty state view
    struct EmptyDatabasesView: View {
        let searchActive: Bool
        let onRefresh: () -> Void

        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: searchActive ? "magnifyingglass" : "music.note.list")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                Text(searchActive ? "No matching databases found" : "No datasets available")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(searchActive
                    ? "Try changing your search terms or browse all available datasets"
                    : "Connect to the internet to browse available music datasets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 60)
        }
    }

    private func fetchDatasets() async {
        print("Fetching datasets...")
        isLoading = true
        datasetsDatabases.removeAll()

        guard let url = trackStarManager.datasetProvider?.url else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let jsonObjects = try? JSONDecoder().decode([GithubAPIDataset].self, from: data) {
                for a in jsonObjects {
                    if let db = await MusicDatabase(fromGlobal: a.url) {
                        if let downloadedDB = trackStarManager.musicDatabases.first(where: { $0.link.sourceURL == db.link.sourceURL }) {
                            datasetsDatabases.append(downloadedDB)
                        } else {
                            datasetsDatabases.append(db)
                        }
                    }
                }
            }
        } catch {
            // Handle error
        }

        isLoading = false
    }
}

struct LocalSource: View {
    @Environment(\.dismiss) private var dismiss
    @State var selectedFile: URL? = nil
    @State private var showFilePicker: Bool = false
    @State private var isImporting: Bool = false
    @State private var previewData: DatabasePreview? = nil
    @State private var musicDatabase: MusicDatabase? = nil
    @State private var importError: String? = nil
    @State private var showFullSongList: Bool = false
    @State private var dbDisplayName: String = ""
    var onDatabaseSelected: (MusicDatabase) -> Void
    @EnvironmentObject private var trackStarManager: TrackStarManager

    struct DatabasePreview: Identifiable {
        var id = UUID()
        var songCount: Int
        var firstSongs: [String]
        var allSongs: [String]
        var fileSize: String
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header graphics
                    VStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .padding(.bottom, 8)

                        Text("Import Local Database")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text("Select a TrackStar database JSON file from your device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()

                    // Import button
                    Button(action: {
                        self.showFilePicker = true
                        self.importError = nil
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Select JSON File")
                        }
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    // Error message
                    if let error = importError {
                        VStack {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }

                    // File preview
                    if let file = selectedFile {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading) {
                                    Text(file.lastPathComponent)
                                        .font(.headline)
                                    TextField(
                                        "Display name (optional)",
                                        text: $dbDisplayName
                                    )
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {}
                                    .lineLimit(1, reservesSpace: true)

                                    if let preview = previewData {
                                        Text("\(preview.songCount) songs · \(preview.fileSize)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else if isImporting {
                                        Text("Analyzing file...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }

                            if let preview = previewData {
                                // Songs preview
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Preview")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)

                                    ForEach(preview.firstSongs.prefix(3), id: \.self) { song in
                                        HStack {
                                            Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                            Text(song)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }

                                    if preview.songCount > 3 {
                                        Button(action: {
                                            showFullSongList = true
                                        }) {
                                            Text("+ \(preview.songCount - 3) more songs")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            } else if isImporting {
                                // Loading indicator
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                            }

                            // Action buttons
                            HStack {
                                Button(action: {
                                    self.selectedFile = nil
                                    self.previewData = nil
                                    self.importError = nil
                                }) {
                                    Text("Cancel")
                                        .frame(minWidth: 100)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .foregroundColor(.primary)
                                        .cornerRadius(8)
                                }

                                Spacer()

                                Button(action: {
                                    guard let musicDatabase = musicDatabase else { return }
                                    if !dbDisplayName.isEmpty {
                                        musicDatabase.info?.displayName = dbDisplayName
                                    }
                                    self.trackStarManager.addNewMusicDatabase(musicDatabase)
                                    self.trackStarManager.applyMusicDatabase(musicDatabase)
                                    self.onDatabaseSelected(musicDatabase)
                                    dismiss()
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                        Text("Use This Database")
                                    }
                                    .frame(minWidth: 180)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(previewData == nil)
                                .opacity(previewData == nil ? 0.5 : 1)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    print("Selected file: \(url.absoluteString)")
                    self.selectedFile = url
                    self.initLocalMusicDatabase(for: url)
                    self.generatePreview(for: url)
                case .failure(let error):
                    print("File selection error: \(error.localizedDescription)")
                    self.importError = "Error selecting file: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showFullSongList) {
                FullSongListView(preview: previewData)
            }
        }
    }

    private func initLocalMusicDatabase(for url: URL) {
        guard let database = MusicDatabase(fromLocal: url, name: nil) else {
            importError = "Invalid database format"
            isImporting = false
            return
        }
        musicDatabase = database
    }

    private func generatePreview(for url: URL) {
        isImporting = true
        previewData = nil

        guard let musicDatabase = musicDatabase else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            let fileSizeString = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)

            let songTitles = musicDatabase.songs.map { song in
                song.title
            }

            previewData = DatabasePreview(
                songCount: musicDatabase.songs.count,
                firstSongs: Array(songTitles.prefix(10)),
                allSongs: songTitles,
                fileSize: fileSizeString
            )
        } catch {
            importError = "Error reading file"
        }

        isImporting = false
    }
}

struct FullSongListView: View {
    @Environment(\.dismiss) private var dismiss
    var preview: LocalSource.DatabasePreview?

    var body: some View {
        NavigationStack {
            Group {
                if let preview = preview {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(preview.allSongs.enumerated().map { $0 }, id: \.offset) { index, song in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)

                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)

                                    Text(song)
                                        .font(.body)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    VStack {
                        Text("No songs available")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("All Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ReadmeView

struct ReadmeView: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    var dataset: MusicDatabase

    @State private var readmeContent: String = "Loading..."
    @State private var errorMessage: String? = nil
    @State private var isDownloading: Bool = false
    private var downloaded: Bool { dataset.link.localURL != nil }
    @State private var showOptions: Bool = false

    var isAlreadyDownloaded: Bool {
        return trackStarManager.musicDatabases.contains { $0.link.sourceURL == dataset.link.sourceURL }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            ScrollView {
                if let errorMessage = errorMessage {
                    ErrorView(
                        message: errorMessage,
                        onRetry: { fetchReadme() }
                    )
                } else {
                    Markdown(self.readmeContent)
                        .padding()
                }
            }

            // Download action bar
            if !downloaded && !isAlreadyDownloaded {
                downloadActionBar
            }
        }
        .navigationBarTitle(dataset.info?.displayName ?? "Unknown", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isAlreadyDownloaded {
                    Button(action: {
                        if !dataset.isActive {
                            trackStarManager.applyMusicDatabase(dataset)
                        }
                    }) {
                        Text(dataset.isActive ? "Applied" : "Apply")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(dataset.isActive ? Color.green.opacity(0.2) : Color.green)
                            .foregroundColor(dataset.isActive ? .green : .white)
                            .cornerRadius(8)
                    }
                    .disabled(dataset.isActive)
                }
                if !isAlreadyDownloaded {
                    Button(action: {
                        Task {
                            await downloadDatabase()
                        }
                    }) {
                        Text("Download")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .onAppear {
            fetchReadme()
        }
    }

    // Download action bar at the bottom of the screen
    private var downloadActionBar: some View {
        VStack(spacing: 0) {
            if isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloading database...")
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }

            // Action buttons
            HStack {
                // Database info
                VStack(alignment: .leading) {
                    Text("\(dataset.songs.count) songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Download button
                Button(action: {
                    Task {
                        await downloadDatabase()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isDownloading)
            }
            .padding()
            .background(
                Rectangle()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
            )
        }
    }

    // Error view
    struct ErrorView: View {
        let message: String
        let onRetry: () -> Void

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                    .padding()

                Text("Unable to load README")
                    .font(.headline)

                Text(message)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: onRetry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    private func fetchReadme() {
        errorMessage = nil
        readmeContent = "Loading..."

        guard let url = dataset.readmeLink?.sourceURL else {
            errorMessage = "Invalid URL for README file."
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    return
                }

                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Could not fetch README (Status code: \(httpResponse.statusCode))"
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received."
                    return
                }

                self.readmeContent = String(decoding: data, as: UTF8.self)
            }
        }.resume()
    }

    private func downloadDatabase() async {
        isDownloading = true

        if await dataset.downloadAll() {
            trackStarManager.addNewMusicDatabase(dataset)
            trackStarManager.applyMusicDatabase(dataset)
        } else {
            errorMessage = "Failed to download database"
        }

        isDownloading = false
    }
}

enum ActiveTab: String, Hashable, Identifiable {
    case global, downloads, local

    var id: String { rawValue }
}

struct DownloadsTab: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var isRefreshing: Bool = false
    @Binding var activeTab: ActiveTab

    var onDatabaseSelected: (MusicDatabase) -> Void

    var body: some View {
        Group {
            if trackStarManager.musicDatabases.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .padding(.top, 40)

                    Text("No Downloaded Databases")
                        .font(.headline)

                    Button("Browse datasets") {
                        activeTab = .global
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .background(Color.clear)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(trackStarManager.musicDatabases) { database in
                            DownloadedDatabaseRow(
                                database: database,
                                onApply: { db in withAnimation { applyDatabase(db) } }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitle("Downloaded Databases", displayMode: .inline)
        .refreshable {}
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .disabled(trackStarManager.musicDatabases.isEmpty)
            }
        }
    }

    private func applyDatabase(_ database: MusicDatabase) {
        trackStarManager.applyMusicDatabase(database)
    }

    private func deleteDatabase(at offsets: IndexSet) {
        // Delete logic here
    }
}

struct DownloadedDatabaseRow: View {
    let database: MusicDatabase
    let onApply: (MusicDatabase) -> Void
    var isApplied: Bool { database.isActive }

    @State private var showDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                // Database icon
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundColor(isApplied ? .blue : .gray)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())

                // Database info
                VStack(alignment: .leading, spacing: 4) {
                    Text(database.info?.displayName ?? database.info?.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(isApplied ? .primary : .primary.opacity(0.9))

                    HStack(spacing: 6) {
                        Label("\(database.songs.count) songs", systemImage: "music.note")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Buttons
                HStack(spacing: 10) {
                    Button(action: { onApply(database) }) {
                        Text(isApplied ? "Applied" : "Apply")
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isApplied ? Color.blue.opacity(0.2) : Color.blue)
                            .foregroundColor(isApplied ? .blue : .white)
                            .cornerRadius(8)
                    }
                    .disabled(isApplied)
                    .opacity(isApplied ? 0.8 : 1)

                    Button(action: { withAnimation { showDetails.toggle() } }) {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.systemBackground).opacity(0.6))
                            .clipShape(Circle())
                    }
                }
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.vertical, 4)

                    HStack {
                        Spacer()
                        Label(database.link.sourceURL != nil ? "Global" : "Local", systemImage: database.link.sourceURL != nil ? "globe.americas.fill" : "archivebox")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Group {
                if isApplied {
                    LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.05), Color(UIColor.secondarySystemBackground)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color(UIColor.secondarySystemBackground)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isApplied ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct MusicDatabaseSelector: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var activeTab: ActiveTab = .downloads
    var onDatabaseSelected: (MusicDatabase) -> Void

    var body: some View {
        NavigationStack {
            TabView(selection: $activeTab) {
                Tab("Downloads", systemImage: "arrow.down.circle.fill", value: .downloads) {
                    DownloadsTab(activeTab: $activeTab, onDatabaseSelected: { database in
                        self.dismiss()
                        self.onDatabaseSelected(database)
                    })
                }

                Tab("Global", systemImage: "globe.americas.fill", value: .global) {
                    GlobalSource(onDatabaseSelected: { database in
                        self.dismiss()
                        self.onDatabaseSelected(database)
                    })
                }

                Tab("Local", systemImage: "archivebox.fill", value: .local) {
                    LocalSource(onDatabaseSelected: { database in
                        self.dismiss()
                        self.onDatabaseSelected(database)
                    })
                }
            }
            .navigationBarTitle("Music Database", displayMode: .inline)
        }
    }
}

class GithubAPIDataset: Identifiable, Decodable {
    let id: String // is comparable to the sha
    let name: String
    let url: URL

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
    }

    enum CodingKeys: String, CodingKey {
        case id = "sha"
        case name
        case url
    }
}
