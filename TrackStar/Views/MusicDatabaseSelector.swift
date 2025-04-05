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

// Model for downloaded database
struct DownloadedDatabase: Identifiable, Codable {
    let id = UUID()
    let name: String
    let dateDownloaded: Date
    let filePath: String
    var description: String
    
    static func saveDownloadedDatabases(_ databases: [DownloadedDatabase]) {
        if let encoded = try? JSONEncoder().encode(databases) {
            UserDefaults.standard.set(encoded, forKey: "downloadedDatabases")
        }
    }
    
    static func loadDownloadedDatabases() -> [DownloadedDatabase] {
        if let data = UserDefaults.standard.data(forKey: "downloadedDatabases"),
           let databases = try? JSONDecoder().decode([DownloadedDatabase].self, from: data)
        {
            return databases
        }
        return []
    }
}

struct DownloadsTab: View {
    @State private var downloadedDatabases: [DownloadedDatabase] = []
    @State private var isRefreshing: Bool = false
    @Binding var activeTab: ActiveTab
    var onDatabaseSelected: (MusicDatabase) -> Void
    @EnvironmentObject private var trackStarManager: TrackStarManager
    
    var body: some View {
        Group {
            if downloadedDatabases.isEmpty {
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
                List {
                    ForEach(downloadedDatabases) { database in
                        DownloadedDatabaseRow(database: database, onApply: { db in
                            applyDatabase(db)
                        })
                    }
                    .onDelete(perform: deleteDatabase)
                }
            }
        }

        .navigationBarTitle("Downloaded Databases", displayMode: .inline)
        .onAppear {
            loadDatabases()
        }
        .refreshable {
            loadDatabases()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .disabled(downloadedDatabases.isEmpty)
            }
        }
    }
    
    private func loadDatabases() {
        isRefreshing = true
        // Simulate some loading time to show refresh animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            downloadedDatabases = DownloadedDatabase.loadDownloadedDatabases()
            isRefreshing = false
        }
    }
    
    private func applyDatabase(_ database: DownloadedDatabase) {}
    
    private func deleteDatabase(at offsets: IndexSet) {
        for index in offsets {
            let database = downloadedDatabases[index]
            let fileURL = URL(fileURLWithPath: database.filePath)
            
            // Try to delete the file
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        downloadedDatabases.remove(atOffsets: offsets)
        DownloadedDatabase.saveDownloadedDatabases(downloadedDatabases)
    }
}

struct DownloadedDatabaseRow: View {
    let database: DownloadedDatabase
    let onApply: (DownloadedDatabase) -> Void
    @State private var showDetails: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(database.name)
                        .font(.headline)
                    
                    Text("Downloaded: \(formattedDate(database.dateDownloaded))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    onApply(database)
                }) {
                    Text("Apply")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Button(action: {
                    showDetails.toggle()
                }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .padding(8)
                }
            }
            
            if showDetails {
                Text(database.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
                // Start loading file access
                url.startAccessingSecurityScopedResource()
                self.selectedFile = url
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
        .padding()
        .navigationBarTitle("Local Database", displayMode: .inline)
    }
}

struct Folder: Identifiable, Codable {
    let id = UUID()
    let name: String
    let path: String
}

struct GlobalSource: View {
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @State private var folders: [Folder] = []
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
            } else if folders.isEmpty {
                Text("No folders found")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(folders) { folder in
                    NavigationLink(destination:
                        ReadmeView(
                            folderPath: folder.path,
                            folderName: folder.name,
                            onDatabaseSelected: onDatabaseSelected
                        )
                    ) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(folder.name)
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationBarTitle("TrackStar Datasets", displayMode: .inline)
        .onAppear {
            isLoading = true
            fetchFolders()
        }
        .refreshable {
            fetchFolders()
        }
    }
    
    private func fetchFolders() {
        guard let url = URL(string: "https://api.github.com/repos/BennoCrafter/TrackStar/contents/datasets") else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let data = data, error == nil else { return }
                
                if let jsonObjects = try? JSONDecoder().decode([GitHubItem].self, from: data) {
                    self.folders = jsonObjects.filter { $0.type == "dir" }.map {
                        Folder(name: $0.name, path: $0.path)
                    }
                }
            }
        }.resume()
    }
}

struct ReadmeView: View {
    let folderPath: String
    let folderName: String
    var onDatabaseSelected: (MusicDatabase) -> Void
    
    @State private var readmeContent: String = "Loading..."
    @State private var errorMessage: String? = nil
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Float = 0.0
    @State private var showOptions: Bool = false
    @State private var downloadedDatabases: [DownloadedDatabase] = []
    @EnvironmentObject private var trackStarManager: TrackStarManager

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
                        ProgressView(value: downloadProgress)
                            .padding()
                        Text("Downloading database... \(Int(downloadProgress * 100))%")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .navigationBarTitle(folderName, displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    downloadDatabase()
                }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
        }
        .onAppear {
            fetchReadme()
            downloadedDatabases = DownloadedDatabase.loadDownloadedDatabases()
        }
    }

    private func fetchReadme() {
        errorMessage = nil
        readmeContent = "Loading..."
        
        let readmeUrlString = "https://raw.githubusercontent.com/BennoCrafter/TrackStar/main/\(folderPath)/README.md"

        guard let encodedUrlString = readmeUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedUrlString)
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
    
    private func downloadDatabase() {
        performDatabaseDownload { destinationUrl, description in
            // Add to downloads list without applying
            let newDownload = DownloadedDatabase(
                name: folderName,
                dateDownloaded: Date(),
                filePath: destinationUrl.path,
                description: description
            )
            
            downloadedDatabases.append(newDownload)
            DownloadedDatabase.saveDownloadedDatabases(downloadedDatabases)
        }
    }

    private func downloadAndApplyDatabase() {}
    
    private func performDatabaseDownload(completion: @escaping (URL, String) -> Void) {
        let dbUrlString = "https://raw.githubusercontent.com/BennoCrafter/TrackStar/main/\(folderPath)/database.json"
        
        guard let encodedUrlString = dbUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedUrlString)
        else {
            errorMessage = "Invalid URL for database file."
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { tempLocalUrl, response, error in
            DispatchQueue.main.async {
                self.isDownloading = false
                
                if let error = error {
                    self.errorMessage = "Download failed: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Could not download database (Status code: \(httpResponse.statusCode))"
                    return
                }
                
                guard let tempLocalUrl = tempLocalUrl else {
                    self.errorMessage = "Download failed: No local file available."
                    return
                }
                
                // Create a permanent location for the file
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let timestamp = Int(Date().timeIntervalSince1970)
                let destinationUrl = documentsDirectory.appendingPathComponent("\(folderName)_\(timestamp).json")
                
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: destinationUrl)
                    
                    // Extract description from readme for metadata
                    let description = extractDescription(from: self.readmeContent)
                    
                    // Call completion handler
                    completion(destinationUrl, description)
                } catch {
                    self.errorMessage = "Failed to save database: \(error.localizedDescription)"
                }
            }
        }
        
        // Set up progress observation
        downloadTask.resume()
        
        // This would be better with a proper progress observer, but for simplicity:
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isDownloading {
                timer.invalidate()
                return
            }
            
            // Simulate progress (in a real app, use URLSession's progress tracking)
            if self.downloadProgress < 0.95 {
                self.downloadProgress += 0.05
            }
        }
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

struct GitHubItem: Codable {
    let name: String
    let path: String
    let type: String
}

struct GitHubFile: Codable {
    let content: String
}

#Preview {
    MusicDatabaseSelector(onDatabaseSelected: { db in
        print(db.link.sourceURL)
    })
}
