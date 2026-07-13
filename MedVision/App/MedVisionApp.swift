import SwiftUI
import SwiftData

@main
struct MedVisionApp: App {
    let container: ModelContainer

    init() {
        NotificationService.shared.setup()
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    // Builds the persistent ModelContainer. If the schema has changed and
    // automatic migration fails, the old store is deleted and a fresh one
    // is created so the app never gets stuck in a broken state.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Medicine.self, DoseEvent.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            let storeURL = config.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}
