import SQLiteData
import SwiftUI

/// `UserDefaults` key of the repo datasets this device has seen, newline separated.
/// Empty until the first check, which records the catalog without announcing anything.
let seenDatasetsKey = "seenDatasets"

/// Shown on launch when the repo has datasets that weren't there last time.
struct NewDatasetsSheet: View {
    let datasets: [RemoteDataset]

    @FetchAll private var installed: [Dataset]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow.gradient)
                            .symbolEffect(.bounce, options: .nonRepeating)
                        Text(datasets.count == 1 ? "New Dataset" : "\(datasets.count) New Datasets")
                            .font(.title.bold())
                        Text("Fresh songs just landed in TrackStar. Get them to play or print their cards.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    ForEach(datasets) { remote in
                        NavigationLink {
                            DatasetDetailView(id: remote.id, remote: remote)
                        } label: {
                            NewDatasetRow(remote: remote, isInstalled: installed.contains { $0.id == remote.id })
                        }
                    }
                }
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The datasets added to the repo since the last check, minus downloaded ones. Records the
    /// catalog as seen, so each dataset is announced once.
    static func check() async -> [RemoteDataset] {
        guard let catalog = try? await Library.catalog() else { return [] }
        let stored = UserDefaults.standard.string(forKey: seenDatasetsKey) ?? ""
        let seen = Set(stored.split(separator: "\n").map(String.init))
        UserDefaults.standard.set(seen.union(catalog.map(\.id)).sorted().joined(separator: "\n"), forKey: seenDatasetsKey)
        guard !stored.isEmpty else { return [] }

        @Dependency(\.defaultDatabase) var database
        let installed = Set((try? await database.read { try Dataset.select(\.id).fetchAll($0) }) ?? [])
        return catalog.filter { !seen.contains($0.id) && !installed.contains($0.id) }
    }
}

/// A new dataset with the first paragraph of its README as a teaser.
private struct NewDatasetRow: View {
    let remote: RemoteDataset
    let isInstalled: Bool

    @State private var summary: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DatasetIcon(name: remote.title, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(remote.title)
                    .font(.headline)
                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                } else {
                    Text("Loading…")
                        .font(.subheadline)
                        .redacted(reason: .placeholder)
                }
                if isInstalled {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                } else {
                    DownloadButton(remote: remote)
                }
            }
        }
        .padding(.vertical, 6)
        .task {
            let readme = (try? await Library.readme(remote.id)) ?? ""
            // First paragraph that isn't a heading; Markdown emphasis stripped for plain text.
            let paragraph = readme.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty && !$0.hasPrefix("#") }
            summary = paragraph?.replacingOccurrences(of: "**", with: "") ?? ""
        }
    }
}
