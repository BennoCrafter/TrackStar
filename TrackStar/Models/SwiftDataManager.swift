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

    func loadDatabase() -> MusicDatabase? {
        if let result = try! modelContainer.mainContext.fetch(FetchDescriptor<MusicDatabase>())
            .first
        {
            return result
        } else {
            return nil
        }
    }

    func saveDatabase(_ db: MusicDatabase) {
        modelContainer.mainContext.insert(db)
    }

    func loadAppConfig() -> AppConfig {
        if let result = try! modelContainer.mainContext.fetch(FetchDescriptor<AppConfig>())
            .first
        {
            return result
        } else {
            let instance = AppConfig()
            modelContainer.mainContext.insert(instance)
            return instance
        }
    }

    func save() {
        try? modelContainer.mainContext.save()
    }
}
