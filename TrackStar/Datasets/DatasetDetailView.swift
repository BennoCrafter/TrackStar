import MarkdownUI
import SQLiteData
import SwiftUI

/// One dataset, downloaded or not: get or play it, its cards, songs and README.
struct DatasetDetailView: View {
    let id: String
    /// From the catalog; nil when it hasn't loaded or the dataset was imported.
    let remote: RemoteDataset?

    @FetchOne private var dataset: Dataset?
    @State private var readme: String?
    @State private var isDownloading = false
    @State private var showingCards = false
    @State private var confirmingDelete = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(id: String, remote: RemoteDataset?) {
        self.id = id
        self.remote = remote
        _dataset = FetchOne(wrappedValue: nil, Dataset.where { $0.id.eq(id) })
    }

    private var title: String {
        dataset?.displayName ?? remote?.title ?? id
    }

    private var isRemote: Bool {
        dataset?.isRemote ?? true
    }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)

            Section {
                if dataset != nil {
                    NavigationLink {
                        SongListView(datasetID: id, title: title)
                    } label: {
                        Label("Songs", systemImage: "music.note.list")
                    }
                }
                if isRemote || dataset != nil {
                    Button {
                        showingCards = true
                    } label: {
                        Label("Printable Cards", systemImage: "printer")
                    }
                }
            } footer: {
                if isRemote {
                    Text("Print the cards double-sided, flipping on the long edge, then cut along the marks.")
                } else {
                    Text("Print the cards double-sided, flipping on the long edge, then cut along the marks. They only play on this device: the song pack isn't in the repository.")
                }
            }

            if isRemote {
                Section("About") {
                    if let readme {
                        Markdown(readme)
                            .markdownTextStyle { FontSize(15) }
                    } else {
                        ProgressView()
                    }
                }
            }

            if let dataset {
                Section {
                    Button("Delete Song Pack", role: .destructive) { confirmingDelete = true }
                } footer: {
                    if dataset.isRemote, dataset.version > 0 {
                        Text("Version \(dataset.version). Updates download automatically.")
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCards) {
            NavigationStack { CardsView(datasetID: id, title: title, isRemote: isRemote) }
        }
        .confirmationDialog("Delete \(title)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                do {
                    try Library.delete(id)
                    dismiss()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task {
            guard isRemote, readme == nil else { return }
            readme = (try? await Library.readme(id)) ?? "No description."
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            DatasetIcon(name: title, icon: dataset?.icon ?? remote?.icon, size: 80)
            Text(title)
                .font(.title.bold())
            if let dataset {
                Text("\(dataset.songCount) songs")
                    .foregroundStyle(.secondary)
            }
            primaryButton
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }   

    @ViewBuilder
    private var primaryButton: some View {
        if let dataset {
            Button {
                do { try Library.activate(dataset.id) } catch { self.error = error.localizedDescription }
            } label: {
                Label(dataset.isActive ? "Playing" : "Play This Song Pack", systemImage: dataset.isActive ? "checkmark" : "play.fill")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(dataset.isActive)
        } else {
            Button {
                Task { await download() }
            } label: {
                Group {
                    if isDownloading {
                        ProgressView()
                    } else {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isDownloading)
        }
    }

    private func download() async {
        isDownloading = true
        do {
            let info = if let remote { remote } else { try await Library.info(id) }
            try await Library.install(info)
        } catch {
            self.error = error.localizedDescription
        }
        isDownloading = false
    }
}

/// Every card of a dataset, searchable.
struct SongListView: View {
    let title: String

    @FetchAll private var tracks: [Track]
    @State private var search = ""

    init(datasetID: String, title: String) {
        self.title = title
        _tracks = FetchAll(Track.where { $0.datasetID.eq(datasetID) }.order(by: \.number))
    }

    private var filtered: [Track] {
        guard !search.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.artist.localizedCaseInsensitiveContains(search)
                || $0.year.map(String.init) == search
                || String($0.number) == search
        }
    }

    var body: some View {
        List(filtered) { track in
            HStack(spacing: 12) {
                Text("\(track.number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let year = track.year {
                    Text(String(year))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PeriodGradient.gradient(for: year), in: Capsule())
                }
            }
        }
        .searchable(text: $search, prompt: "Title, artist, year or number")
        .navigationTitle("Songs")
        .overlay {
            if filtered.isEmpty, !search.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }
}
