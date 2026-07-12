import SwiftUI

struct ContentView: View {
    
    @State private var showSplash = true
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline:.now() + 2) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                TabView {
                    TodayView()
                        .tabItem {
                            Image(systemName: "sun.horizon")
                        }
                    MedicinesView()
                        .tabItem {
                            Image(systemName: "pills")
                        }
                    ScanView()
                        .tabItem {
                            Image(systemName: "document.viewfinder")
                        }
                    HistoryView()
                        .tabItem {
                            Image(systemName: "clock")
                        }
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.crop.circle")
                        }
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
