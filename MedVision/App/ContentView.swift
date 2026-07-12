import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showSplash = true
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @AppStorage("hasSeededPlaceholderData") private var hasSeededPlaceholderData = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showSplash = false }
                    }
            } else {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.horizon") }
                    MedicinesView()
                        .tabItem { Label("Medicines", systemImage: "pills") }
                    ScanView()
                        .tabItem { Label("Scan", systemImage: "document.viewfinder") }
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock") }
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                }
                .task {
                    seedPlaceholderDataIfNeeded()
                    await NotificationService.shared.requestPermission()
                }
                .sheet(isPresented: Binding(
                    get: { !showSplash && shouldShowOnboarding },
                    set: { shouldShowOnboarding = $0 }
                )) {
                    OnboardingView()
                        .interactiveDismissDisabled(true)
                }
            }
        }
    }

    // Seeds demo data on first launch in debug builds only.
    private func seedPlaceholderDataIfNeeded() {
        #if DEBUG
        guard !hasSeededPlaceholderData else { return }

        let paracetamol = Medicine(name: "Paracetamol", dosage: "500 mg", form: .pill, notes: "Take with water", frequencyNote: "Every 6 hours if needed")
        let amoxicillin  = Medicine(name: "Amoxicillin",  dosage: "250 mg", form: .pill, notes: "Complete the full course", frequencyNote: "3 times daily with food")
        let vitaminD     = Medicine(name: "Vitamin D",    dosage: "1000 IU", form: .liquid, notes: "", frequencyNote: "Once daily in the morning")

        for m in [paracetamol, amoxicillin, vitaminD] { modelContext.insert(m) }

        let cal = Calendar.current
        let now = Date()
        func d(_ daysAgo: Int, _ hour: Int) -> Date {
            let base = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
        }

        let events: [DoseEvent] = [
            // Today — past doses
            DoseEvent(scheduledTime: d(0, 8),  status: .complete, medicine: paracetamol),
            DoseEvent(scheduledTime: d(0, 14), status: .omitted,  medicine: paracetamol),
            // Today — upcoming doses
            DoseEvent(scheduledTime: d(0, 18), status: .pending,  medicine: vitaminD),
            DoseEvent(scheduledTime: d(0, 20), status: .pending,  medicine: amoxicillin),
            DoseEvent(scheduledTime: d(0, 20), status: .pending,  medicine: paracetamol),
            // Previous days
            DoseEvent(scheduledTime: d(1, 8),  status: .complete, medicine: amoxicillin),
            DoseEvent(scheduledTime: d(1, 14), status: .omitted,  medicine: amoxicillin),
            DoseEvent(scheduledTime: d(1, 20), status: .missed,   medicine: amoxicillin),
            DoseEvent(scheduledTime: d(2, 9),  status: .complete, medicine: vitaminD),
            DoseEvent(scheduledTime: d(2, 9),  status: .complete, medicine: paracetamol),
            DoseEvent(scheduledTime: d(3, 8),  status: .missed,   medicine: paracetamol),
        ]
        for e in events { modelContext.insert(e) }

        hasSeededPlaceholderData = true
        #endif
    }
}

#Preview {
    ContentView()
}
