import SwiftUI

struct MedicinesView: View {
    var body: some View {
        NavigationStack {
            Text("Your medicines will appear here.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Medicines")
        }
    }
}

#Preview {
    MedicinesView()
}
