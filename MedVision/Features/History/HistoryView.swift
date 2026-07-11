import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            Text("Your medication history will appear here.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
}
