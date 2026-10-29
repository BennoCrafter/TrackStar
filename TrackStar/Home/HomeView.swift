import SwiftUI

enum GameMode {
    case classic, newParty, resumeParty
}

/// Home or one of the modes. Also shows what comes once per launch: release notes, new datasets.
struct RootView: View {
    @State private var mode: GameMode?
    @State private var openedURL: URL?
    @State private var showingReleaseNotes = false
    @State private var newDatasets: [RemoteDataset] = []
    @State private var showingNewDatasets = false
    @AppStorage(seenReleaseNotesVersionKey) private var seenReleaseNotesVersion = ""

    var body: some View {
        ZStack {
            switch mode {
            case .classic: ContentView(openedURL: $openedURL) { mode = nil }
            case .newParty: PartyView(resume: false) { mode = nil }
            case .resumeParty: PartyView(resume: true) { mode = nil }
            case nil: HomeView(mode: $mode)
            }
        }
        .animation(.default, value: mode)
        .onOpenURL { url in
            // A card has no place in a game without cards.
            guard mode == nil || mode == .classic else { return }
            openedURL = url
            mode = .classic
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingReleaseNotes, onDismiss: showNewDatasetsIfNeeded) { ReleaseNotesSheet() }
        .sheet(isPresented: $showingNewDatasets) { NewDatasetsSheet(datasets: newDatasets) }
        .task {
            showReleaseNotesIfNeeded()
            newDatasets = await NewDatasetsSheet.check()
            showNewDatasetsIfNeeded()
            await Library.updateAll()
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

struct HomeView: View {
    @Binding var mode: GameMode?
    @AppStorage(PartyModel.saveKey) private var savedGame: Data?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                TintedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Text("New Game")
                            .font(.largeTitle.bold())
                            .padding(.bottom, 8)
                        modeButton("With Cards", detail: "Scan the QR codes of printed cards.", systemImage: "qrcode.viewfinder", mode: .classic)
                        modeButton("No Cards", detail: "The phone picks the songs and keeps everyone's timeline and points.", systemImage: "person.3.fill", mode: .newParty)
                        if savedGame != nil {
                            Button { mode = .resumeParty } label: {
                                Label("Continue Game", systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .tint(.white)
                            .foregroundStyle(.black)
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private func modeButton(_ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, mode: GameMode) -> some View {
        Button { self.mode = mode } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold())
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The no-cards mode is played in landscape; the rest of the app turns freely.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var landscapeOnly = false

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        if Self.landscapeOnly { return .landscape }
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    @MainActor static func lockLandscape(_ locked: Bool) {
        landscapeOnly = locked
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        // An iPad stays as it's held after the game.
        guard locked || UIDevice.current.userInterfaceIdiom == .phone else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: locked ? .landscape : .portrait)) { _ in }
    }
}
