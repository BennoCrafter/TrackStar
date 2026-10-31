import CodeScanner
import SQLiteData
import SwiftUI

/// The game with printed cards: scan → listen → reveal.
struct ContentView: View {
    /// A card scanned with the Camera app.
    @Binding var openedURL: URL?
    let close: () -> Void

    @State private var game = GameModel()
    @State private var showingLibrary = false
    @State private var showingSettings = false

    @FetchOne(Dataset.where(\.isActive)) private var activeDataset: Dataset?

    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
                    .padding(.horizontal, 24)
                    .transition(.blurReplace)
                    .id(game.phase)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: game.phase)
            .safeAreaInset(edge: .bottom) { bottomButton }
            .overlay(alignment: .top) { switchedBanner }
            .toolbar { toolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingLibrary) { DatasetLibrarySheet() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .alert(problemTitle, isPresented: problemBinding, presenting: game.problem) { problem in
                problemActions(problem)
            } message: { problem in
                Text(problemMessage(problem))
            }
        }
        .environment(game)
        .onChange(of: openedURL, initial: true) {
            guard let openedURL else { return }
            game.open(openedURL)
            self.openedURL = nil
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch game.phase {
        case .scanning:
            scanner
        case .loading:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Finding the song…").foregroundStyle(.secondary)
            }
        case .listening:
            ListeningView()
        case .revealed:
            if let track = game.track {
                VStack(spacing: 20) {
                    SongCard(track: track, song: game.song)
                    if let url = game.song?.url {
                        Link(destination: url) {
                            Label("Open in Apple Music", systemImage: "music.note")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
            }
        }
    }

    private var scanner: some View {
        VStack(spacing: 24) {
            CodeScannerView(
                codeTypes: [.qr],
                scanMode: .oncePerCode,
                showViewfinder: true,
                simulatedData: "trackstar://hitster/?id=2",
                completion: { result in
                    if case let .success(scan) = result {
                        game.scanned(scan.string)
                    }
                }
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 360)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }

            VStack(spacing: 6) {
                Text("Scan a card")
                    .font(.title2.bold())
                Text(activeDataset == nil
                    ? "Point the camera at a card's QR code. Its song pack is picked automatically."
                    : "Point the camera at the QR code of a card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch game.phase {
        case .listening:
            prominentButton("Reveal", systemImage: "eye.fill", action: game.reveal)
        case .revealed:
            prominentButton("Next Card", systemImage: "qrcode.viewfinder", action: game.next)
        case .scanning, .loading:
            EmptyView()
        }
    }

    private func prominentButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(.white)
        .foregroundStyle(.black)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .sensoryFeedback(.impact(weight: .medium), trigger: game.phase)
    }

    private var background: some View {
        TintedBackground(year: game.phase == .revealed ? game.track?.year : nil)
    }

    @ViewBuilder
    private var switchedBanner: some View {
        if let name = game.switchedTo {
            Label("Switched to \(name)", systemImage: "arrow.triangle.swap")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                game.next()
                close()
            } label: {
                Label("Home", systemImage: "house.fill")
            }
        }

        ToolbarItem(placement: .topBarLeading) {
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button { showingLibrary = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.fill")
                    Text(activeDataset?.displayName ?? "Choose Song Pack")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Problems

    private var problemBinding: Binding<Bool> {
        Binding(get: { game.problem != nil }, set: {
            if !$0 {
                game.problem = nil
            }
        })
    }

    private var problemTitle: LocalizedStringKey {
        switch game.problem {
        case .unknownCode: "Not a TrackStar Card"
        case .missingDataset: "Song Pack Not Downloaded"
        case .missingCard: "Card Not Found"
        case .notFound: "Song Not on Apple Music"
        case .message, nil: "Something Went Wrong"
        }
    }

    private func problemMessage(_ problem: GameModel.Problem) -> String {
        switch problem {
        case .unknownCode:
            String(localized: "This QR code doesn't belong to a TrackStar or German Hitster card.")
        case let .missingDataset(name):
            String(localized: "This card belongs to the song pack “\(name)”. Download it to play the card.")
        case let .missingCard(number):
            String(localized: "\(activeDataset?.displayName ?? String(localized: "The song pack")) has no card number \(number).")
        case let .notFound(track):
            String(localized: "“\(track.title)” by \(track.artist) couldn't be found. Here's the card anyway.")
        case let .message(text):
            text
        }
    }

    @ViewBuilder
    private func problemActions(_ problem: GameModel.Problem) -> some View {
        if case let .missingDataset(name) = problem {
            Button("Download") { Task { await game.download(name) } }
            Button("Cancel", role: .cancel) {}
        } else {
            Button("OK", role: .cancel) {}
        }
    }
}
