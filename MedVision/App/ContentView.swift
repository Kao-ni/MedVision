import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @State private var showSplash = true
    @State private var authViewModel: AuthViewModel?
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true

    var body: some View {
        ZStack {
            if showSplash || auth.isRestoringSession {
                SplashScreenView()
            } else if auth.isSignedIn {
                mainTabs
            } else if let authViewModel {
                AuthView(viewModel: authViewModel)
            } else {
                SplashScreenView()
                    .task {
                        self.authViewModel = AuthViewModel(auth: auth)
                    }
            }
        }
        .task {
            if authViewModel == nil {
                authViewModel = AuthViewModel(auth: auth)
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showSplash = false }
        }
    }

    private var mainTabs: some View {
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
            get: { shouldShowOnboarding },
            set: { shouldShowOnboarding = $0 }
        )) {
            OnboardingView()
                .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
}
