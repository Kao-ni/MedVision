import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Settings will appear here.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    ProfileView()
}
