import SwiftUI

struct MusicDatabaseSelector: View {
    @State var selectedFile: URL? = nil
    @State private var showFilePicker: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var onFileSelected: (URL) -> Void
    
    var body: some View {
        VStack {
            Text("Select a Music Database File")
                .font(.headline)
                .padding()
            
            Button("Import JSON File") {
                showFilePicker = true
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
            isPresented: $showFilePicker,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                print("Selected file: \(url.absoluteString)")
                selectedFile = url
                onFileSelected(url)
                dismiss()
            case .failure(let error):
                print("File selection error: \(error.localizedDescription)")
            }
        }
        .padding()
    }
}

#Preview {
    MusicDatabaseSelector(onFileSelected: { url in print(url) })
}
