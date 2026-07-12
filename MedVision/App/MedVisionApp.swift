import SwiftUI
import SwiftData

@main
struct MedVisionApp: App {
    init() {
        NotificationService.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Medicine.self, DoseEvent.self])
    }
}
