import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.mvSky.ignoresSafeArea()

            Text("MedVision")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .kerning(0.2)
                .foregroundStyle(.white)
        }
    }
}

