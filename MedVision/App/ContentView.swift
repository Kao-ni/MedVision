import SwiftUI

struct ContentView: View {
    
    @State private var showSplash = true
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    
    var body: some View {
        VStack {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline:.now() + 2) {
                            withAnimation {
                                    showSplash = false
                            }
                        }
                    }
            }
            else if shouldShowOnboarding {
                OnboardingView()
            }
            else {
                TabView {
                    TodayView()
                        .tabItem {
                            Label("Today", systemImage: "bell.fill")
                        }
                    MedicinesView()
                        .tabItem {
                            Label("Medicines", systemImage: "pills.fill")
                        }
                    ScanView()
                        .tabItem {
                            Label("Scan", systemImage: "camera.fill")
                        }
                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "calendar")
                        }
                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "gear")
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
