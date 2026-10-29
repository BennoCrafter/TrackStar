import SQLiteData
import SwiftUI

/// A new game without cards: who plays, then which dataset.
struct PartySetupView: View {
    let start: (PartyModel) -> Void
    let close: () -> Void

    @FetchAll(Player.order(by: \.name)) private var saved: [Player]
    @FetchAll(Dataset.order(by: \.displayName)) private var datasets: [Dataset]
    /// In the order they were picked: the order of the score bar.
    @State private var selected: [String] = []
    @State private var newName = ""
    @FocusState private var isAdding: Bool
    @State private var showingLibrary = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add a player", text: $newName)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(add)
                    ForEach(saved) { player in
                        Button { toggle(player.name) } label: {
                            HStack {
                                Text(player.name)
                                Spacer()
                                if selected.contains(player.name) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: forget)
                } header: {
                    Text("Players")
                } footer: {
                    Text("Players are remembered for the next game. Swipe left to forget one.")
                }
            }
            .navigationTitle("Who Plays?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: close)
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("Next") { datasetList }
                        .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var datasetList: some View {
        List {
            Section {
                ForEach(datasets) { dataset in
                    Button { begin(dataset.id) } label: {
                        LabeledContent(dataset.displayName, value: "\(dataset.songCount) songs")
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                if datasets.isEmpty { Text("Download a dataset to play.") }
            }
            Section {
                Button("Get Datasets") { showingLibrary = true }
            }
        }
        .navigationTitle("Which Songs?")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLibrary) { DatasetLibrarySheet() }
        .alert("Can't Start", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return }
        // The names are unique ignoring case, like in the database.
        if let existing = saved.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            if !selected.contains(existing.name) { selected.append(existing.name) }
        } else {
            @Dependency(\.defaultDatabase) var database
            do {
                try database.write { db in try Player.insert { Player.Draft(name: name) }.execute(db) }
                selected.append(name)
            } catch {
                logger.error("Saving player \(name) failed: \(error)")
            }
        }
        isAdding = true // the next name
    }

    private func toggle(_ name: String) {
        if let index = selected.firstIndex(of: name) {
            selected.remove(at: index)
        } else {
            selected.append(name)
        }
    }

    private func forget(_ offsets: IndexSet) {
        @Dependency(\.defaultDatabase) var database
        for index in offsets {
            let player = saved[index]
            selected.removeAll { $0 == player.name }
            try? database.write { db in try Player.find(player.id).delete().execute(db) }
        }
    }

    private func begin(_ datasetID: String) {
        do {
            try start(PartyModel.start(players: selected, datasetID: datasetID))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
