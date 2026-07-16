import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @State private var showSplash = true
    @State private var authViewModel: AuthViewModel?
    @AppStorage("hasCompletedTermsPlaceholder") private var hasCompletedTermsPlaceholder = false
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var selectedTab = 0
    @State private var showScanCamera = false
    @State private var previousTab = 0

    var body: some View {
        ZStack {
            if showSplash || auth.isRestoringSession {
                SplashScreenView()
            } else if auth.isSignedIn {
                if !hasCompletedTermsPlaceholder {
                    TermsPlaceholderView {
                        hasCompletedTermsPlaceholder = true
                    }
                    .transition(.opacity)
                } else if shouldShowOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    mainTabs
                }
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
        .onAppear {
            #if DEBUG
            // Keep the pre-app flow easy to test from Xcode. This runs only
            // once at launch, so both Continue and Get Started still work.
            hasCompletedTermsPlaceholder = false
            shouldShowOnboarding = true
            #endif
        }
    }

    private var mainTabs: some View {
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
            ScanView(
                showCamera: $showScanCamera,
                onClose: {
                    selectedTab = previousTab
                    showScanCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .task {
            await NotificationService.shared.requestPermission()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
}
