import MarkdownUI
import SwiftUI

enum ActiveTab: String, Hashable, Identifiable {
    case global, downloads, local

    var id: String { rawValue }
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

                    Button(action: { showDetails.toggle() }) {
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

//                        if let date = database.info?.downloadDate {
//                            Label(formattedDate(date), systemImage: "calendar")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                        }
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

struct LocalSource: View {
    @State var selectedFile: URL? = nil
    @State private var showFilePicker: Bool = false
    @State private var isImporting: Bool = false
    var onDatabaseSelected: (MusicDatabase) -> Void
    @EnvironmentObject private var trackStarManager: TrackStarManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Select a Music Database File")
                .font(.headline)
                .padding()

            Button(action: {
                self.showFilePicker = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Import JSON File")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if let file = selectedFile {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected File: \(file.lastPathComponent)")
                        .font(.subheadline)

                    Button(action: {
                        guard let db = MusicDatabase(fromLocal: file, name: nil) else {
                            print("uff. failed..")
                            return
                        }
                        self.trackStarManager.addNewMusicDatabase(db)
                        self.trackStarManager.applyMusicDatabase(db)
                        self.onDatabaseSelected(db)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Use This Database")
                        }
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                print("Selected file: \(url.absoluteString)")
                self.selectedFile = url
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
        .padding()
        .navigationBarTitle("Local Database", displayMode: .inline)
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

struct GlobalSource: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var datasetsDatabases: [MusicDatabase] = []
    @State private var isLoading: Bool = false
    var onDatabaseSelected: (MusicDatabase) -> Void

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading folders...")
                    Spacer()
                }
            } else if datasetsDatabases.isEmpty {
                Text("No datasets found")
                    .foregroundStyle(.gray)
                    .padding()
            } else {
                ForEach(datasetsDatabases) { dataset in
                    NavigationLink(destination:
                        ReadmeView(dataset: dataset)
                    ) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard.fill")
                                .foregroundColor(.blue)
                            Text(dataset.info?.displayName ?? "Unknown")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationBarTitle("TrackStar Datasets", displayMode: .inline)
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

    private func fetchDatasets() async {
        print("Fetching datasets...")
        datasetsDatabases.removeAll()
        guard let url = URL(string: "https://api.github.com/repos/BennoCrafter/TrackStar/contents/datasets") else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            isLoading = false

            if let jsonObjects = try? JSONDecoder().decode([GithubAPIDataset].self, from: data) {
                for a in jsonObjects {
                    if let db = await MusicDatabase(fromGlobal: a.url) {
                        datasetsDatabases.append(db)
                    }
                }
            }
        } catch {
            isLoading = false
        }
    }
}

struct ReadmeView: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager

    var dataset: MusicDatabase

    @State private var readmeContent: String = "Loading..."
    @State private var errorMessage: String? = nil
    @State private var isDownloading: Bool = false
    @State private var downloaded: Bool = false
    @State private var showOptions: Bool = false

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                        .padding()

                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()

                    Button("Try Again") {
                        fetchReadme()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else {
                ScrollView {
                    Markdown(self.readmeContent)
                        .padding()
                }

                if isDownloading {
                    VStack {
                        Text("Downloading database...")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .navigationBarTitle(dataset.info?.displayName ?? "Unknown", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !downloaded {
                    Button(action: {
                        Task {
                            await downloadDatabase()
                        }
                    }) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                } else {
                    Button(action: {}) {
                        Label("Success", systemImage: "checkmark.circle")
                    }
                }
            }
        }
        .onAppear {
            fetchReadme()
        }
    }

    private func fetchReadme() {
        errorMessage = nil
        readmeContent = "Loading..."

        guard let url = dataset.readmeLink?.sourceURL
        else {
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
            downloaded = true
        } else {
            errorMessage = "Failed to download"
        }
        isDownloading = false
    }

    private func extractDescription(from readme: String) -> String {
        // Extract first paragraph or a reasonable summary from readme
        let lines = readme.split(separator: "\n")

        // Skip headers and find first paragraph
        var description = ""
        var inParagraph = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip headers and empty lines when looking for content
            if trimmed.isEmpty {
                if inParagraph {
                    break // End of paragraph
                }
                continue
            }

            // Skip markdown headers
            if trimmed.hasPrefix("#") {
                continue
            }

            // Found content
            if description.isEmpty {
                description = trimmed
                inParagraph = true
            } else {
                description += " " + trimmed
            }

            // Limit description length
            if description.count > 150 {
                description = String(description.prefix(150)) + "..."
                break
            }
        }

        return description.isEmpty ? "No description available" : description
    }
}

#Preview {
    MusicDatabaseSelector(onDatabaseSelected: { db in
        print(db.link.sourceURL)
    })
}
