import SQLiteData
import SwiftUI

/// The library as a sheet, from the dataset button on the game screen.
struct DatasetLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatasetLibraryView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Downloaded datasets on top, the rest of the repo's catalog below, and file import.
struct DatasetLibraryView: View {
    @FetchAll(Dataset.order(by: \.displayName)) private var installed: [Dataset]

    @State private var catalog: [RemoteDataset] = []
    @State private var catalogError: String?
    @State private var isLoading = false
    @State private var error: String?

    @State private var showingImporter = false
    @State private var importURL: URL?
    @State private var importName = ""

    private var available: [RemoteDataset] {
        catalog.filter { remote in !installed.contains { $0.id == remote.id } }
    }

    var body: some View {
        List {
            if installed.isEmpty {
                Section("On This Device") {
                    Text("No song packs yet. Download one below.")
                        .foregroundStyle(.secondary)
                }
            }
            installedSection("On This Device · Public", installed.filter(\.isRemote),
                             footer: "Swipe right to play a song pack. Scanning a card switches to its song pack too.")
            installedSection("On This Device · My Song Packs", installed.filter { !$0.isRemote },
                             footer: "Imported from a file or made from Apple Music. They only exist on this device.")

            Section {
                if isLoading, catalog.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let catalogError {
                    Label(catalogError, systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.secondary)
                } else if available.isEmpty {
                    Text("You've got every song pack.")
                        .foregroundStyle(.secondary)
                }
                availableRows(available.filter { !$0.isArtist })
            } header: {
                Text("Available")
            } footer: {
                Text("Song Packs come from the TrackStar repository on GitHub. Each one has printable cards.")
            }

            if available.contains(where: \.isArtist) {
                Section {
                    availableRows(available.filter(\.isArtist))
                } header: {
                    Text("Artists")
                } footer: {
                    Text("One artist's songs. In the Party Game you place them by album instead of year.")
                }
            }

            Section {
                NavigationLink {
                    AppleMusicImportView()
                } label: {
                    Label("Create from Apple Music Playlist", systemImage: "music.note.list")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("Import songs.json", systemImage: "square.and.arrow.down")
                }
                Link(destination: Library.repositoryURL.appending(path: "tree/main/backend")) {
                    Label("Create Your Own Song Pack", systemImage: "hammer")
                }
            } header: {
                Text("Your Own")
            } footer: {
                Text("TrackStar makes printable cards for your own song packs. A songs.json is a list of {\"id\", \"title\", \"artist\", \"year\"} entries.")
            }
        }
        .navigationTitle("Song Packs")
        .refreshable { await loadCatalog() }
        .task { if catalog.isEmpty { await loadCatalog() } }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            if case let .success(url) = result {
                importName = url.deletingPathExtension().lastPathComponent
                importURL = url
            }
        }
        .alert("Name the Song Pack", isPresented: Binding(get: { importURL != nil }, set: { if !$0 { importURL = nil } })) {
            TextField("Name", text: $importName)
            Button("Import") {
                guard let url = importURL else { return }
                run { try Library.importFile(url, displayName: importName.isEmpty ? "My Songs" : importName) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Something Went Wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func availableRows(_ datasets: [RemoteDataset]) -> some View {
        ForEach(datasets) { remote in
            NavigationLink {
                DatasetDetailView(id: remote.id, remote: remote)
            } label: {
                HStack {
                    DatasetIcon(name: remote.title, icon: remote.icon)
                    Text(remote.title)
                    Spacer()
                    DownloadButton(remote: remote)
                }
            }
        }
    }

    /// Hidden when empty.
    @ViewBuilder
    private func installedSection(_ title: LocalizedStringKey, _ datasets: [Dataset], footer: LocalizedStringKey) -> some View {
        if !datasets.isEmpty {
            Section {
                ForEach(datasets) { dataset in
                    NavigationLink {
                        DatasetDetailView(id: dataset.id, remote: catalog.first { $0.id == dataset.id })
                    } label: {
                        InstalledRow(dataset: dataset)
                    }
                    .swipeActions(edge: .leading) {
                        if !dataset.isActive {
                            Button("Play") { run { try Library.activate(dataset.id) } }
                                .tint(.accentColor)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        run { try Library.delete(datasets[index].id) }
                    }
                }
            } header: {
                Text(title)
            } footer: {
                Text(footer)
            }
        }
    }

    private func loadCatalog() async {
        isLoading = true
        do {
            catalog = try await Library.catalog()
            catalogError = nil
        } catch {
            catalogError = String(localized: "Couldn't load the song packs. Check your connection and pull to refresh.")
        }
        // Launch isn't the only time to update: pull to refresh should pick up a version pushed since.
        await Library.updateAll()
        isLoading = false
    }

    private func run(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}

/// "Get" for a dataset from the repo, with its own progress and error.
struct DownloadButton: View {
    let remote: RemoteDataset

    @State private var isDownloading = false
    @State private var error: String?

    var body: some View {
        Button {
            Task {
                isDownloading = true
                do { try await Library.install(remote) } catch { self.error = error.localizedDescription }
                isDownloading = false
            }
        } label: {
            if isDownloading {
                ProgressView()
            } else {
                Label("Get", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.bold())
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .disabled(isDownloading)
        .alert("Couldn't Download \(remote.title)", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }
}

struct InstalledRow: View {
    let dataset: Dataset

    var body: some View {
        HStack {
            DatasetIcon(name: dataset.displayName, icon: dataset.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(dataset.displayName)
                Text(dataset.isRemote ? "\(dataset.songCount) songs" : "\(dataset.songCount) songs · imported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if dataset.isActive {
                Text("Playing")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
        }
    }
}

/// A rounded square with the dataset's initial, colored by its name so it stays the same.
struct DatasetIcon: View {
    let name: String
    /// An SF Symbol name or an emoji; the first letter of the name without one.
    var icon: String?
    var size: CGFloat = 36

    var body: some View {
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        Group {
            if let icon, UIImage(systemName: icon) != nil {
                Image(systemName: icon)
            } else {
                Text(icon ?? name.prefix(1).uppercased())
            }
        }
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                PeriodGradient.gradient(for: 1950 + hash % 16 * 5),
                in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    let _ = prepareDependencies { $0.defaultDatabase = try! Schema.appDatabase() }
    DatasetLibrarySheet()
}
