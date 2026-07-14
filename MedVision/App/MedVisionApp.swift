import SwiftUI
import SwiftData
import PythonKit

@main
struct MedVisionApp: App {
    let container: ModelContainer

    init() {
        MedVisionApp.configurePython()
        container = MedVisionApp.makeContainer()
    }

    private static func configurePython() {
        guard let bundlePath = Bundle.main.resourcePath else { return }

        // PYTHONHOME tells the interpreter where to find the standard library.
        // With an embedded python-apple-support framework the stdlib lives
        // directly inside the bundle resource directory.
        setenv("PYTHONHOME", bundlePath, 1)
        setenv("PYTHONPATH", bundlePath, 1)

        // PythonKit locates the Python dylib via PYTHON_LIBRARY.
        // The embedded Python.xcframework is installed as a framework under
        // the app's Frameworks directory; point PythonKit at it explicitly so
        // it doesn't have to search.
        if let frameworksPath = Bundle.main.privateFrameworksURL {
            let pythonLibPath = frameworksPath
                .appendingPathComponent("Python.framework")
                .appendingPathComponent("Python")
            setenv("PYTHON_LIBRARY", pythonLibPath.path, 1)
        }
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
