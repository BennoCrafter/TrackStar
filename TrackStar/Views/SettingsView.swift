import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage(AppStorageKeys.hasLaunchedBefore.keyName()) var hasLaunchedBefore: Bool = false
    @Published var playbackTimeInterval: String = "0.0"
    
    func resetOnboarding() {
        hasLaunchedBefore = false
    }
    
    func updatePlaybackInterval(_ value: String) {
        if let newTimeInterval = TimeInterval(value) {
            playbackTimeInterval = value
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @EnvironmentObject private var trackStarManager: TrackStarManager
    @StateObject private var viewModel: SettingsViewModel = .init()
    
    var body: some View {
        NavigationStack {
            List {
                databaseSection
                playbackSection
                aboutSection
                miscSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                viewModel.playbackTimeInterval = String(trackStarManager.appConfig.playbackTimeInterval)
            }
        }
    }
    
    // MARK: - Section Views
    
    private var databaseSection: some View {
        Section {
            NavigationLink(destination: MusicDatabaseSelector(onDatabaseSelected: { db in
            })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Music Database")
                        .font(.headline)
                    
                    HStack {
                        Text("Current:")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Text(trackStarManager.activeMusicDatabase?.info?.displayName ?? "None")
                            .foregroundStyle(.blue)
                            .font(.subheadline.bold())
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    .padding(4)
            )
        } header: {
            SectionHeader(title: "Database")
        }
    }
    
    private var playbackSection: some View {
        Section {
            SettingsToggleRow(
                title: "Hitster Mode",
                subtitle: "Scan the QR codes from the Hitster game",
                icon: "qrcode",
                iconColor: .orange,
                isOn: $trackStarManager.appConfig.useHitsterQRCodes
            )
            
            SettingsToggleRow(
                title: "Random Playback Interval",
                subtitle: "Use varying playback durations",
                icon: "dice",
                iconColor: .green,
                isOn: $trackStarManager.appConfig.useRandomPlaybackInterval
            )
            
            PlaybackDurationRow(
                timeInterval: $viewModel.playbackTimeInterval,
                onValueChanged: { newValue in
                    if let interval = TimeInterval(newValue) {
                        trackStarManager.appConfig.playbackTimeInterval = interval
                    }
                }
            )
        } header: {
            SectionHeader(title: "Playback")
        }
    }
    
    private var aboutSection: some View {
        Section {
            NavigationLink(destination: SettingsViewAttributions()) {
                HStack(spacing: 12) {
                    SettingsIcon(icon: "heart.circle.fill", color: .red)
                    
                    Text("Attributions")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
        } header: {
            SectionHeader(title: "About")
        }
    }
    
    private var miscSection: some View {
        Section {
            Button(action: {
                viewModel.resetOnboarding()
            }) {
                HStack(spacing: 12) {
                    SettingsIcon(icon: "book.and.wrench", color: .blue)
                    SettingsText(title: "Reset Onboarding")
                    
                    Spacer()
                    
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.vertical, 4)
            }
        } header: {
            SectionHeader(title: "Miscellaneous")
        }
    }
}

// MARK: - UI Components

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
    }
}

struct SettingsIcon: View {
    let icon: String
    let color: Color
    var size: CGFloat = 32
    var iconSize: CGFloat = 16
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

struct SettingsText: View {
    var title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlaybackDurationRow: View {
    @Binding var timeInterval: String
    var onValueChanged: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(icon: "timer", color: .purple)
            
            SettingsText(title: "Playback Duration", subtitle: "Time in seconds")

            Spacer()
            
            HStack(spacing: 0) {
                Button(action: { decrementValue() }) {
                    Image(systemName: "minus")
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
                
                TextField("0.0", text: $timeInterval)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .onChange(of: timeInterval) { _, newValue in
                        onValueChanged(newValue)
                    }
                
                Button(action: { incrementValue() }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
    
    private func incrementValue() {
        if let current = Double(timeInterval) {
            let newValue = (current + 1).rounded(to: 1)
            timeInterval = String(format: "%.1f", newValue)
            onValueChanged(timeInterval)
        }
    }
    
    private func decrementValue() {
        if let current = Double(timeInterval), current > 1 {
            let newValue = (current - 1).rounded(to: 1)
            timeInterval = String(format: "%.1f", newValue)
            onValueChanged(timeInterval)
        }
    }
}

// MARK: - Toggle Row Component

struct SettingsToggleRow: View {
    var title: String
    var subtitle: String? = nil
    var icon: String
    var iconColor: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(icon: icon, color: iconColor)
            SettingsText(title: title, subtitle: subtitle)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Attributions View

struct SettingsViewAttributions: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(licenses) { license in
                    LicenseCardView(
                        title: license.title,
                        license: license.licenseType,
                        url: license.url
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private var licenses: [LicenseInfo] {
        [
            LicenseInfo(
                title: "CodeScanner",
                licenseType: "MIT License",
                url: URL(string: "https://github.com/twostraws/CodeScanner/blob/main/LICENSE")!
            ),
            LicenseInfo(
                title: "MarqueeText",
                licenseType: "MIT License",
                url: URL(string: "https://github.com/joekndy/MarqueeText")!
            ),
            LicenseInfo(
                title: "swift-markdown-ui",
                licenseType: "MIT License",
                url: URL(string: "https://github.com/gonzalezreal/swift-markdown-ui")!
            )
        ]
    }
}

struct LicenseInfo: Identifiable {
    let id = UUID()
    let title: String
    let licenseType: String
    let url: URL
}

struct LicenseCardView: View {
    var title: String
    var license: String?
    var url: URL
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            UIApplication.shared.open(url)
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let license = license {
                        Text(license)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(url.host ?? "")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : .white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Utility Extension

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

#Preview {
    SettingsViewAttributions()
}

#Preview {
    SettingsView()
        .environmentObject(TrackStarManager.preview)
}
