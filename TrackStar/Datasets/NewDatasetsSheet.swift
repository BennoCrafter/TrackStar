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
                            NewDatasetRow(remote: remote, isInstalled: installed.contains { $0.id == remote.id })
                        }
                    }
                } header: {
                    header
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.yellow.gradient)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text(datasets.count == 1 ? "New Song Pack" : "\(datasets.count) New Song Packs")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Download a pack to play it or print its cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .textCase(nil)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 16)
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

    /// `nil` while loading, empty when the README has nothing usable.
    @State private var summary: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            DatasetIcon(name: remote.title, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(remote.title)
                    .font(.headline)

                summaryView
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if isInstalled {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    } else {
                        DownloadButton(remote: remote)
                            // Keeps the tap on the button instead of triggering the row's navigation.
                            .buttonStyle(.borderless)
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .task(id: remote.id) {
            let readme = (try? await Library.readme(remote.id)) ?? ""
            summary = Self.teaser(from: readme)
        }
    }

    @ViewBuilder private var summaryView: some View {
        switch summary {
        case nil:
            Text("Placeholder summary text for this song pack that spans two lines")
                .redacted(reason: .placeholder)
        case let text? where !text.isEmpty:
            Text(text)
        default:
            EmptyView()
        }
    }

    /// The first prose paragraph of a README as plain text: skips headings, images, badges,
    /// HTML and code, and renders inline Markdown so no `**`, `_` or `[link](url)` shows through.
    static func teaser(from readme: String) -> String {
        let paragraph = readme
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { block in
                guard let first = block.first else { return false }
                return !"#!<[`>|-".contains(first) || block.hasPrefix("[") && !block.hasPrefix("[![")
            }
        guard let paragraph else { return "" }

        let joined = paragraph
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: joined, options: options) {
            return String(attributed.characters)
        }
        return joined
    }
}
