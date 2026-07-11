import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationStack {
            Text("Scan a medicine packet to add it.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Scan")
        }
    }
}

#Preview {
    ScanView()
}
