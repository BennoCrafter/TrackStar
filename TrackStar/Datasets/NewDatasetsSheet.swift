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
                    ForEach(datasets) { remote in
                        NavigationLink {
                            DatasetDetailView(id: remote.id, remote: remote)
                        } label: {
                            HStack {
                                DatasetIcon(name: remote.title)
                                Text(remote.title)
                                Spacer()
                                if installed.contains(where: { $0.id == remote.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel("Downloaded")
                                } else {
                                    DownloadButton(remote: remote)
                                }
                            }
                        }
                    }
                } header: {
                    Text(datasets.count == 1 ? "A new dataset is available." : "\(datasets.count) new datasets are available.")
                        .font(.body)
                        .textCase(nil)
                }
            }
            .navigationTitle("New Datasets")
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
