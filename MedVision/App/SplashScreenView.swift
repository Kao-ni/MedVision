import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(red: 174/255, green: 227/255, blue: 251/255).ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Text("MedVision")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            .foregroundStyle(.white)
        }
    }
}

