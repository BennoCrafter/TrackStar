import SwiftUI

// MARK: - Model

struct LicenseInfo: Identifiable, Hashable {
    /// Stable identity so ForEach / navigation don't reset on every render.
    var id: String {
        name
    }

    let name: String
    let author: String
    let licenseType: String
    let copyrightHolder: String
    let repositoryURL: URL
    let bundledLicenseFile: String

    /// Loads the full license text from the bundle, falling back to the
    /// standard MIT text so the screen is never empty.
    var fullText: String {
        let parts = bundledLicenseFile.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2,
           let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1]),
           let text = try? String(contentsOf: url, encoding: .utf8)
        {
            return text
        }
        return LicenseInfo.mitTemplate(holder: copyrightHolder)
    }

    static func mitTemplate(holder: String) -> String {
        """
        MIT License

        Copyright (c) \(holder)

        Permission is hereby granted, free of charge, to any person obtaining a copy \
        of this software and associated documentation files (the "Software"), to deal \
        in the Software without restriction, including without limitation the rights \
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is \
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE \
        SOFTWARE.
        """
    }
}

extension LicenseInfo {
    static let all: [LicenseInfo] = [
        LicenseInfo(
            name: "sqlite-data",
            author: "pointfreeco",
            licenseType: "MIT",
            copyrightHolder: "Point-Free, Inc.",
            repositoryURL: URL(string: "https://github.com/pointfreeco/sqlite-data")!,
            bundledLicenseFile: "LICENSE-sqlite-data.txt"),
        LicenseInfo(
            name: "CodeScanner",
            author: "twostraws",
            licenseType: "MIT",
            copyrightHolder: "2019 Paul Hudson",
            repositoryURL: URL(string: "https://github.com/twostraws/CodeScanner")!,
            bundledLicenseFile: "LICENSE-CodeScanner.txt"),
        LicenseInfo(
            name: "swift-markdown-ui",
            author: "gonzalezreal",
            licenseType: "MIT",
            copyrightHolder: "2020 Guillermo Gonzalez",
            repositoryURL: URL(string: "https://github.com/gonzalezreal/swift-markdown-ui")!,
            bundledLicenseFile: "LICENSE-swift-markdown-ui.txt"),
        LicenseInfo(
            name: "Liberation Fonts",
            author: "liberationfonts",
            licenseType: "OFL-1.1",
            copyrightHolder: "2012 Red Hat, Inc.",
            repositoryURL: URL(string: "https://github.com/liberationfonts/liberation-fonts")!,
            bundledLicenseFile: "LICENSE-liberation-fonts.txt"),
    ].sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// MARK: - Attributions List

struct SettingsViewAttributions: View {
    var body: some View {
        List {
            Section {
                ForEach(LicenseInfo.all) { license in
                    NavigationLink {
                        LicenseDetailView(license: license)
                    } label: {
                        LicenseRow(license: license)
                    }
                    .contextMenu { LicenseContextMenu(license: license) }
                }
            } header: {
                Text("Open-source libraries")
            } footer: {
                Text("This app is built with the help of these open-source projects. Thank you to their authors and contributors.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Row

struct LicenseRow: View {
    let license: LicenseInfo
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 12) {
            Text(String(license.name.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(license.name)
                    .font(.body.weight(.medium))
                Text("by \(license.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            LicenseBadge(text: license.licenseType)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(license.name), by \(license.author), \(license.licenseType) license")
        .accessibilityHint("Shows the full license")
    }
}

struct LicenseBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

// MARK: - Context Menu

struct LicenseContextMenu: View {
    let license: LicenseInfo

    var body: some View {
        Link(destination: license.repositoryURL) {
            Label("Open in Safari", systemImage: "safari")
        }
        Button {
            UIPasteboard.general.url = license.repositoryURL
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }
        ShareLink(item: license.repositoryURL) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

// MARK: - Detail

struct LicenseDetailView: View {
    let license: LicenseInfo

    var body: some View {
        List {
            Section {
                LabeledContent("Author", value: license.author)
                LabeledContent("License", value: "\(license.licenseType) License")
                Link(destination: license.repositoryURL) {
                    HStack {
                        Text("View on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint("Opens in Safari")
            }

            Section("License text") {
                Text(license.fullText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: license.repositoryURL)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsViewAttributions()
    }
}
