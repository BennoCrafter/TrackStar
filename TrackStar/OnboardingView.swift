import SwiftUI

struct OnboardingView: View {
    @State var hasLaunchedBefore: Bool // Tracks if it's the first launch
    @State var selectedFile: URL? = nil
    
    var onFileSelected: (URL) -> Void // Callback function to handle the selected file
    
    var body: some View {
        VStack {
            Text("Select a Music Database File")
                .font(.headline)
                .padding()
            
            Button("Import JSON File") {
                // Trigger the file importer
                hasLaunchedBefore = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            if let file = selectedFile {
                Text("Selected File: \(file.lastPathComponent)")
                    .padding()
            }
        }
        .fileImporter(
            isPresented: $hasLaunchedBefore,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                print("Selected file: \(url.absoluteString)")
                selectedFile = url
                onFileSelected(url) 
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
        .padding()
    }
}
