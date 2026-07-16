import SwiftUI
import SwiftData

@main
struct MedVisionApp: App {
    private static let container: ModelContainer = makeContainer()
    @State private var authService = AuthService()
    @AppStorage(AppLanguage.storageKey) private var displayLanguage = "en"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(
                    \.locale,
                    Locale(identifier: AppLanguage.code(for: displayLanguage))
                )
                .onOpenURL { url in
                    authService.handleOpenURL(url)
                }
        }
        .modelContainer(Self.container)
    }

    // Builds the persistent ModelContainer. If the schema has changed and
    // automatic migration fails, the old store is deleted and a fresh one
    // is created so the app never gets stuck in a broken state.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Medicine.self, DoseEvent.self])
        let storeURL = persistentStoreURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to create SwiftData container: \(error)")
            }
        }
    }

    private static func persistentStoreURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        do {
            try fileManager.createDirectory(
                at: applicationSupportDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            fatalError("Failed to create Application Support directory: \(error)")
        }

        return applicationSupportDirectory.appendingPathComponent("default.store")
    }
}
