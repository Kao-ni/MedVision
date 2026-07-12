import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    let color: Color
    let title: String
    let description: String
}

struct OnboardingView: View {
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "pills.fill",
            color: .blue,
            title: "Your Medicine\nAssistant",
            description: "Keep all your medicines in one place and never miss a dose."
        ),
        OnboardingPage(
            systemImage: "camera.fill",
            color: .green,
            title: "Scan & Save",
            description: "Just point your camera at any medicine packet. We'll read it for you."
        ),
        OnboardingPage(
            systemImage: "bell.fill",
            color: .orange,
            title: "Get Reminded",
            description: "We'll remind you exactly when to take each medicine, every day."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: currentPage == index ? 24 : 10, height: 10)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.top, 16)

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    shouldShowOnboarding = false
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 52)
        }
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 200, height: 200)
                Image(systemName: page.systemImage)
                    .font(.system(size: 88))
                    .foregroundStyle(page.color)
            }

            VStack(spacing: 18) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
