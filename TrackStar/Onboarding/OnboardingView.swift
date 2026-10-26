import MusicKit
import SQLiteData
import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool

    @State private var step: Step = .welcome
    @State private var isMovingForward = true

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Welcome → how to play → Apple Music access → pick a dataset → done.
    private enum Step: Int, CaseIterable {
        case welcome, howToPlay, music, datasets, done

        var title: LocalizedStringKey {
            self == .datasets ? "Get a Dataset" : ""
        }

        var continueTitle: LocalizedStringKey {
            switch self {
            case .music: "Allow Apple Music"
            case .done: "Start Playing"
            default: "Continue"
            }
        }
    }

    /// Full-size iPad gets a centered card instead of a full-screen layout stretched across a huge canvas.
    private var usesCardLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    // MARK: - Body

    var body: some View {
        if usesCardLayout {
            ZStack {
                ZStack {
                    Color(.systemGroupedBackground)
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.3), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 700)
                }
                .ignoresSafeArea()

                flow
                    .frame(maxWidth: 600, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 12)
                    .padding(40)
            }
        } else {
            flow
        }
    }

    /// One navigation stack for the whole flow, so the bottom bar stays put while pages slide.
    private var flow: some View {
        NavigationStack {
            currentPage
                .background(Color(.systemGroupedBackground))
                .id(step)
                .transition(pageTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .simultaneousGesture(
                    DragGesture(minimumDistance: 40).onEnded { value in
                        // The dataset list scrolls and swipes its rows itself.
                        guard step != .datasets else { return }
                        handleSwipe(value)
                    })
                .navigationTitle(step.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if step != .done {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip", action: finish)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                        .padding(.bottom, 8)
                }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: - Pages

    @ViewBuilder
    private var currentPage: some View {
        switch step {
        case .welcome:
            OnboardingPageView(
                page: OnboardingPage(
                    imageName: "music.quarternote.3",
                    title: "Welcome to TrackStar!",
                    description: "The music game where you guess when a song came out."))

        case .howToPlay:
            OnboardingPageView(
                page: OnboardingPage(
                    imageName: "qrcode.viewfinder",
                    title: "Scan, Listen, Guess",
                    description: "Scan a card and the song plays. Guess its year, place it on your timeline, then reveal the card to check."))

        case .music:
            OnboardingPageView(
                page: OnboardingPage(
                    imageName: "applelogo",
                    title: "Apple Music",
                    description: "The songs play through Apple Music, so TrackStar needs access. Playing full songs needs a subscription."))

        case .datasets:
            DatasetLibraryView()
                .navigationTitle("")
                .onboardingHint("A dataset is a set of cards. Download one, then print its cards or use the original German Hitster cards.")

        case .done:
            OnboardingPageView(
                page: OnboardingPage(
                    imageName: "checkmark.seal",
                    title: "You're all set!",
                    description: "Grab your cards and let the music play.",
                    style: .celebration))
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            OnboardingPageIndicator(count: Step.allCases.count, current: step.rawValue)

            HStack(spacing: 12) {
                if step != .welcome, step != .done {
                    backButton
                        .transition(.scale.combined(with: .opacity))
                }
                continueButton
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background {
            if #available(iOS 26.0, *) {
                // Liquid Glass buttons float over the content; no docked bar behind them.
                Color.clear
            } else {
                Rectangle()
                    .fill(.bar)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) { Divider() }
            }
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        let button = Button(action: handleContinueTap) {
            Text(step.continueTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .controlSize(.large)

        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder
    private var backButton: some View {
        let button = Button(action: goBack) {
            Image(systemName: "chevron.left")
                .font(.headline)
                .frame(width: 22, height: 22)
                .padding(6)
        }
        .controlSize(.large)
        .accessibilityLabel("Back")

        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            button
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
    }

    // MARK: - Navigation

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading),
            removal: .move(edge: isMovingForward ? .leading : .trailing))
            .combined(with: .opacity)
    }

    /// On `.music` the button asks for access first; the answer doesn't block moving on.
    private func handleContinueTap() {
        if step == .music {
            Task {
                _ = await MusicAuthorization.request()
                advance()
            }
        } else {
            advance()
        }
    }

    private func advance() {
        if step == .done {
            finish()
        } else if let next = Step(rawValue: step.rawValue + 1) {
            move(to: next)
        }
    }

    private func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            move(to: previous)
        }
    }

    /// Mirrors the Continue/Back buttons. Swiping past `.music` doesn't ask for access;
    /// the game asks again before the first song.
    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        guard abs(horizontal) > abs(value.translation.height) * 1.5 else { return }
        horizontal < 0 ? advance() : goBack()
    }

    private func move(to newStep: Step) {
        guard newStep != step else { return }
        // Update the direction first so the outgoing page re-renders with the correct removal
        // edge, then change the page on the next run-loop tick.
        isMovingForward = newStep.rawValue > step.rawValue
        Task {
            withAnimation(.snappy(duration: 0.35)) {
                step = newStep
            }
        }
    }

    private func finish() {
        withAnimation {
            hasSeenOnboarding = true
        }
        // A new user hasn't missed anything, so no "What's New" right after onboarding.
        UserDefaults.standard.set(ReleaseNotes.version, forKey: seenReleaseNotesVersionKey)
    }
}

// MARK: - Page indicator

private struct OnboardingPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 20 : 6, height: 6)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

// MARK: - Hint banner

private extension View {
    func onboardingHint(_ text: LocalizedStringKey) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }
}

#Preview {
    @Previewable @State var hasSeenOnboarding = false
    let _ = prepareDependencies { $0.defaultDatabase = try! Schema.appDatabase() }
    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
}
