import SwiftUI
import SwiftData

@main
struct MedVisionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Medicine.self, DoseEvent.self])
    }
}
