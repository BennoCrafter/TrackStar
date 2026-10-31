import PDFKit
import SwiftUI

/// A dataset's `cards.pdf`, downloaded from the repo or printed by the app, shown and shareable to print or save.
struct CardsView: View {
    let datasetID: String
    let title: String
    let isRemote: Bool

    @State private var file: URL?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let file {
                PDFKitView(url: file)
                    .ignoresSafeArea(edges: .bottom)
            } else if let error {
                ContentUnavailableView {
                    Label("Couldn't Load the Cards", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            } else {
                ProgressView("Downloading cards…")
            }
        }
        .navigationTitle("\(title) Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            if let file {
                ToolbarItem(placement: .primaryAction) {
                    // Print and Save to Files are in the share sheet.
                    ShareLink(item: file)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        error = nil
        do {
            file = isRemote
                ? try await Library.downloadCards(datasetID)
                : try CardPrinter.write(datasetID: datasetID, title: title)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context _: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context _: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
