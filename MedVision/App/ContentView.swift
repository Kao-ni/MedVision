import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showSplash = true
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true

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
}

#Preview {
    ContentView()
}
