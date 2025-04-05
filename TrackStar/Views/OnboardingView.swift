import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Text("Welcome TrackStar!")
                .font(.largeTitle)
                .padding()

            Text("Here’s a quick overview of how things work.")
                .font(.body)
                .padding()

//            NavigationLink(destination: MusicDatabaseSelector(onFileSelected: { url in
//                _ = musicManager.initNewMusicDatabase(url: url)
//            })) {
            //            }
            Spacer()

            Button(action: {
                onComplete()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

#Preview {
    OnboardingView(onComplete: {
        print("Onboarding completed")
    })
}
