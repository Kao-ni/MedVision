import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationStack {
            Text("ScanView")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("Scan")
        }
    }
}

#Preview {
    ScanView()
}
