import SwiftUI
import SwiftData

private enum MainTab: Int, CaseIterable, Identifiable {
    case today
    case medicines
    case scan
    case history
    case profile

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .medicines: "Medicines"
        case .scan: "Scan"
        case .history: "History"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.horizon.fill"
        case .medicines: "pills.fill"
        case .scan: "document.viewfinder"
        case .history: "clock.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @State private var showSplash = true
    @State private var authViewModel: AuthViewModel?
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasChosenLanguage") private var hasChosenLanguage = false
    @AppStorage("hasCompletedTermsPlaceholder") private var hasCompletedTermsPlaceholder = false
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var selectedTab: MainTab = .today
    @State private var lastNonScanTab: MainTab = .today
    @State private var showScanCamera = false

    var body: some View {
        ZStack {
            if showSplash || auth.isRestoringSession {
                SplashScreenView()
            } else if !hasSeenWelcome {
                WelcomeView {
                    withAnimation { hasSeenWelcome = true }
                }
                .transition(.opacity)
            } else if !hasChosenLanguage {
                LanguageChooserView {
                    withAnimation { hasChosenLanguage = true }
                }
                .transition(.opacity)
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .scan {
                selectedTab = lastNonScanTab
                showScanCamera = true
            } else {
                lastNonScanTab = newValue
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
            // once at launch, so the full welcome -> onboarding flow re-shows.
            hasSeenWelcome = false
            hasChosenLanguage = false
            hasCompletedTermsPlaceholder = false
            shouldShowOnboarding = true
            #endif
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(MainTab.today)
                .tabItem {
                    Label(MainTab.today.title, systemImage: MainTab.today.systemImage)
                }
            MedicinesView()
                .tag(MainTab.medicines)
                .tabItem {
                    Label(MainTab.medicines.title, systemImage: MainTab.medicines.systemImage)
                }
            Color.clear
                .tag(MainTab.scan)
                .tabItem {
                    Label(MainTab.scan.title, systemImage: MainTab.scan.systemImage)
                }
            HistoryView()
                .tag(MainTab.history)
                .tabItem {
                    Label(MainTab.history.title, systemImage: MainTab.history.systemImage)
                }
            ProfileView()
                .tag(MainTab.profile)
                .tabItem {
                    Label(MainTab.profile.title, systemImage: MainTab.profile.systemImage)
                }
        }
        .fullScreenCover(isPresented: $showScanCamera) {
            ScanView(
                showCamera: $showScanCamera,
                onClose: { showScanCamera = false }
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
