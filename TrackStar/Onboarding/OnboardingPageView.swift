import SwiftUI

struct OnboardingPage {
    enum Style {
        /// Calm, looping ambience: the hero breathes and music symbols drift around it.
        case welcome
        /// One-shot payoff: the badge pops in, confetti bursts, success haptic.
        case celebration
    }

    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    var style: Style = .welcome
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    /// Drives the staggered entrance (hero → title → description).
    @State private var appeared = false
    /// Bumped to fire one-shot effects: symbol bounce, confetti, haptic.
    @State private var effectTrigger = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var preferredCircleSize: CGFloat = 160
    @State private var availableHeight: CGFloat = .infinity

    private var circleSize: CGFloat {
        min(preferredCircleSize, availableHeight * 0.25)
    }

    private var isCelebration: Bool {
        page.style == .celebration
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            hero
                .zIndex(1) // let confetti fall in front of the text

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(StaggeredEntrance(isVisible: appeared, delay: 0.12))

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(StaggeredEntrance(isVisible: appeared, delay: 0.22))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
        .sensoryFeedback(.success, trigger: effectTrigger) { _, _ in isCelebration }
        .task { await playEntrance() }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack {
            if page.style == .welcome {
                OrbitingSymbols(radius: circleSize * 0.92, paused: reduceMotion)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: appeared)
            }

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: circleSize, height: circleSize)

            Image(systemName: page.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: circleSize * 0.44)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: effectTrigger)
                .rotationEffect(.degrees(isCelebration && !appeared && !reduceMotion ? -30 : 0))

            if isCelebration, !reduceMotion {
                ConfettiBurst(trigger: effectTrigger)
            }
        }
        .frame(width: circleSize * 1.9, height: circleSize * (isCelebration ? 1.4 : 1.9))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.6), value: appeared)
        .accessibilityHidden(true)
    }

    // MARK: Choreography

    private func playEntrance() async {
        // Let the page's slide-in transition get underway before the content moves.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        appeared = true

        // Celebration only: fire the bounce, confetti, and haptic as the badge lands.
        guard isCelebration else { return }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled else { return }
        effectTrigger += 1
    }
}

// MARK: - Entrance

struct StaggeredEntrance: ViewModifier {
    let isVisible: Bool
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .blur(radius: isVisible || reduceMotion ? 0 : 6)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: isVisible)
    }
}

// MARK: - Preview

#Preview("Welcome page") {
    OnboardingPageView(
        page: OnboardingPage(imageName: "music.quarternote.3", title: "Welcome to TrackStar!", description: "Guess the year of the song."))
}

#Preview("Done page") {
    OnboardingPageView(
        page: OnboardingPage(imageName: "checkmark.seal", title: "You're all set!", description: "Let the music play.", style: .celebration))
}
