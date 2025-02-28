import MediaPlayer
import SwiftUI

struct MediaPickerView: UIViewControllerRepresentable {
    @Binding var selectedSongs: [MPMediaItem]

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = true
        picker.showsCloudItems = true
        picker.prompt = "Select some things"
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        var parent: MediaPickerView

        init(_ parent: MediaPickerView) {
            self.parent = parent
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            // Get all songs from the selected collection
            let newSongs = mediaItemCollection.items

            // Add items that aren't already in the selection
            for song in newSongs {
                if !parent.selectedSongs.contains(where: { $0.persistentID == song.persistentID }) {
                    parent.selectedSongs.append(song)
                }
            }

            mediaPicker.dismiss(animated: true)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true)
        }
    }
}

enum MPMediaType {
    case playlists
    case albums
    case music
}
