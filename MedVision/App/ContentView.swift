import SwiftUI

struct ContentView: View {
    var body: some View {
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

#Preview {
    ContentView()
}
