import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            Text("Your reminder schedule will appear here.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Schedule")
        }
    }
}

#Preview {
    TodayView()
}
