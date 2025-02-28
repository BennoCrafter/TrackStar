import SwiftData
import SwiftUI

@MainActor
final class SwiftDataManager {
    static let shared = SwiftDataManager()

    private lazy var modelContainer: ModelContainer = {
        fatalError("ModelContainer must be set using configure(context:)")
    }()

    func configure(with modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func loadDatabase() -> [DBSong] {
        do {
            let results = try self.modelContainer.mainContext.fetch(FetchDescriptor<DBSong>())
            return results
        } catch {
            print("Failed to fetch DBSong entities: \(error.localizedDescription)")
            return []
        }
    }
}
