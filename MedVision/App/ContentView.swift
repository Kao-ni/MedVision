import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showSplash = true
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var selectedTab = 0
    @State private var showScanCamera = false
    @State private var previousTab = 0

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showSplash = false }
                    }
            } else {
                TabView(selection: $selectedTab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.horizon") }
                        .tag(0)
                    MedicinesView()
                        .tabItem { Label("Medicines", systemImage: "pills") }
                        .tag(1)
                    Color.clear
                        .tabItem { Label("Scan", systemImage: "document.viewfinder") }
                        .tag(2)
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock") }
                        .tag(3)
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                        .tag(4)
                }
                .onChange(of: selectedTab) { _, tab in
                    if tab != 2 { previousTab = tab }
                    showScanCamera = tab == 2
                }
                .fullScreenCover(isPresented: $showScanCamera, onDismiss: {
                    selectedTab = previousTab
                }) {
                    ScanView(showCamera: $showScanCamera)
                        .ignoresSafeArea()
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
