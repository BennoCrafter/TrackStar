import CodeScanner
import SQLiteData
import SwiftUI

struct ContentView: View {
    @State private var game = GameModel()
    @State private var showingLibrary = false
    @State private var showingSettings = false
    @State private var showingReleaseNotes = false
    @State private var newDatasets: [RemoteDataset] = []
    @State private var showingNewDatasets = false
    @AppStorage(seenReleaseNotesVersionKey) private var seenReleaseNotesVersion = ""

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
            .sheet(isPresented: $showingReleaseNotes, onDismiss: showNewDatasetsIfNeeded) { ReleaseNotesSheet() }
            .sheet(isPresented: $showingNewDatasets) { NewDatasetsSheet(datasets: newDatasets) }
            .alert(problemTitle, isPresented: problemBinding, presenting: game.problem) { problem in
                problemActions(problem)
            } message: { problem in
                Text(problemMessage(problem))
            }
        }
        .environment(game)
        .onOpenURL { game.open($0) }
        .preferredColorScheme(.dark)
        .task {
            showReleaseNotesIfNeeded()
            newDatasets = await NewDatasetsSheet.check()
            showNewDatasetsIfNeeded()
            await Library.updateAll()
        }
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
                    if case let .success(scan) = result { game.scanned(scan.string) }
                })
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
                    ? "Point the camera at a card's QR code. Its dataset is picked automatically."
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

    /// Dark, tinted with the revealed card's period color.
    private var background: some View {
        let year = game.phase == .revealed ? game.track?.year : nil
        let (start, end) = PeriodGradient.colors(for: year)
        return ZStack {
            Color.black
            RadialGradient(
                colors: [(year == nil ? Color.accentColor : start).opacity(0.45), .clear],
                center: .top, startRadius: 0, endRadius: 600)
            RadialGradient(
                colors: [(year == nil ? Color.accentColor : end).opacity(0.25), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 500)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: year)
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
            Button { showingSettings = true } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingLibrary = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.fill")
                    Text(activeDataset?.displayName ?? "Choose Dataset")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Problems

    private var problemBinding: Binding<Bool> {
        Binding(get: { game.problem != nil }, set: { if !$0 { game.problem = nil } })
    }

    private var problemTitle: LocalizedStringKey {
        switch game.problem {
        case .unknownCode: "Not a TrackStar Card"
        case .missingDataset: "Dataset Not Downloaded"
        case .missingCard: "Card Not Found"
        case .notFound: "Song Not on Apple Music"
        case .message, nil: "Something Went Wrong"
        }
    }

    private func problemMessage(_ problem: GameModel.Problem) -> String {
        switch problem {
        case .unknownCode:
            "This QR code doesn't belong to a TrackStar or German Hitster card."
        case let .missingDataset(name):
            "This card belongs to the dataset “\(name)”. Download it to play the card."
        case let .missingCard(number):
            "\(activeDataset?.displayName ?? "The dataset") has no card number \(number)."
        case let .notFound(track):
            "“\(track.title)” by \(track.artist) couldn't be found. Here's the card anyway."
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

    /// Waits for the release notes: one sheet at a time.
    private func showNewDatasetsIfNeeded() {
        guard !newDatasets.isEmpty, !showingReleaseNotes else { return }
        showingNewDatasets = true
    }

    private func showReleaseNotesIfNeeded() {
        guard seenReleaseNotesVersion != ReleaseNotes.version, ReleaseNotes.hasNotesForCurrentVersion else { return }
        seenReleaseNotesVersion = ReleaseNotes.version
        showingReleaseNotes = true
    }
}
