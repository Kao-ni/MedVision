import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

private struct DisplayLanguage: Identifiable {
    let id: String
    let flag: String
    let nativeName: String
}

private struct MealTime {
    var hour: Int
    var minute: Int
    var second: Int

    var secondsFromMidnight: Int {
        (hour * 60 * 60) + (minute * 60) + second
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @AppStorage("profile_age") private var storedAge = ""
    @AppStorage("profile_displayLanguage") private var storedDisplayLanguage = ""
    @AppStorage("profile_bloodType") private var storedBloodType = ""
    @AppStorage("meal_breakfastSeconds") private var storedBreakfastSeconds = 8 * 60 * 60
    @AppStorage("meal_lunchSeconds") private var storedLunchSeconds = 12 * 60 * 60
    @AppStorage("meal_dinnerSeconds") private var storedDinnerSeconds = 18 * 60 * 60
    @State private var currentPage = 0
    @State private var ageInput = ""
    @State private var bloodTypeInput = ""
    @State private var allergyInputs = [""]
    @State private var conditionInputs = [""]
    @State private var breakfastTime = MealTime(hour: 8, minute: 0, second: 0)
    @State private var lunchTime = MealTime(hour: 12, minute: 0, second: 0)
    @State private var dinnerTime = MealTime(hour: 18, minute: 0, second: 0)
    @FocusState private var isAgeFieldFocused: Bool

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

    private let displayLanguages: [DisplayLanguage] = [
        DisplayLanguage(id: "en", flag: "🇺🇸", nativeName: "English"),
        DisplayLanguage(id: "th", flag: "🇹🇭", nativeName: "ไทย")
    ]

    private let bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"]

    private var agePageIndex: Int { pages.count }
    private var displayLanguagePageIndex: Int { pages.count + 1 }
    private var bloodTypePageIndex: Int { pages.count + 2 }
    private var allergiesPageIndex: Int { pages.count + 3 }
    private var conditionsPageIndex: Int { pages.count + 4 }
    private var mealTimesPageIndex: Int { pages.count + 5 }
    private var totalPageCount: Int { pages.count + 6 }
    private var isAgePage: Bool { currentPage == agePageIndex }
    private var isDisplayLanguagePage: Bool { currentPage == displayLanguagePageIndex }
    private var isBloodTypePage: Bool { currentPage == bloodTypePageIndex }
    private var isMealTimesPage: Bool { currentPage == mealTimesPageIndex }
    private var isAgeValid: Bool {
        guard let age = Int(ageInput) else { return false }
        return (1...120).contains(age)
    }
    private var isDisplayLanguageValid: Bool {
        !storedDisplayLanguage.isEmpty
    }
    private var isBloodTypeValid: Bool {
        !bloodTypeInput.isEmpty
    }
    private var isCurrentPageValid: Bool {
        if isAgePage { return isAgeValid }
        if isDisplayLanguagePage { return isAgeValid && isDisplayLanguageValid }
        if isBloodTypePage { return isAgeValid && isDisplayLanguageValid && isBloodTypeValid }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }

                ageEntryView
                    .tag(agePageIndex)

                displayLanguageEntryView
                    .tag(displayLanguagePageIndex)

                bloodTypeEntryView
                    .tag(bloodTypePageIndex)

                allergiesEntryView
                    .tag(allergiesPageIndex)

                conditionsEntryView
                    .tag(conditionsPageIndex)

                mealTimesEntryView
                    .tag(mealTimesPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, newPage in
                isAgeFieldFocused = newPage == agePageIndex
            }

            HStack(spacing: 12) {
                ForEach(0..<totalPageCount, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: currentPage == index ? 24 : 10, height: 10)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.top, 16)

            Button {
                if currentPage < mealTimesPageIndex {
                    if currentPage == agePageIndex {
                        storedAge = ageInput
                    }
                    if currentPage == bloodTypePageIndex {
                        storedBloodType = bloodTypeInput
                    }
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    storedAge = ageInput
                    storedBloodType = bloodTypeInput
                    storedBreakfastSeconds = breakfastTime.secondsFromMidnight
                    storedLunchSeconds = lunchTime.secondsFromMidnight
                    storedDinnerSeconds = dinnerTime.secondsFromMidnight
                    shouldShowOnboarding = false
                    dismiss()
                }
            } label: {
                Text(
                    isMealTimesPage
                        ? LocalizedStringKey("Get Started")
                        : LocalizedStringKey("Next")
                )
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
            .disabled(!isCurrentPageValid)
            .opacity(isCurrentPageValid ? 1 : 0.5)
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

    private var ageEntryView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How old are you?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            TextField("Age", text: $ageInput)
                .font(.system(size: 44, weight: .semibold))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($isAgeFieldFocused)
                .frame(maxWidth: 180)
                .padding(.vertical, 16)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: ageInput) { _, newValue in
                    ageInput = String(newValue.filter(\.isNumber).prefix(3))
                }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var displayLanguageEntryView: some View {
        VStack(spacing: 20) {
            Text("What language do you prefer?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(displayLanguages) { language in
                        Button {
                            storedDisplayLanguage = language.id
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.title2)

                                Text(verbatim: language.nativeName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if storedDisplayLanguage == language.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(
                                storedDisplayLanguage == language.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.secondary.opacity(0.08)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        storedDisplayLanguage == language.id
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.2),
                                        lineWidth: storedDisplayLanguage == language.id ? 2 : 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.visible)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    private var bloodTypeEntryView: some View {
        VStack(spacing: 20) {
            Text("What is your blood type?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(bloodTypes, id: \.self) { bloodType in
                        Button {
                            bloodTypeInput = bloodType
                        } label: {
                            HStack {
                                Group {
                                    if bloodType == "Unknown" {
                                        Text("Unknown")
                                    } else {
                                        Text(verbatim: bloodType)
                                    }
                                }
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                                Spacer()

                                if bloodTypeInput == bloodType {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(
                                bloodTypeInput == bloodType
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.secondary.opacity(0.08)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        bloodTypeInput == bloodType
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.2),
                                        lineWidth: bloodTypeInput == bloodType ? 2 : 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.visible)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }

    private var allergiesEntryView: some View {
        repeatableTextEntryView(
            title: "Do you have any allergies?",
            placeholder: "Type an allergy",
            addTitle: "Add Another Allergy",
            removeLabel: "Remove allergy",
            inputs: $allergyInputs
        )
    }

    private var conditionsEntryView: some View {
        repeatableTextEntryView(
            title: "Do you have any medical conditions?",
            placeholder: "Type a condition",
            addTitle: "Add Another Condition",
            removeLabel: "Remove condition",
            inputs: $conditionInputs
        )
    }

    private var mealTimesEntryView: some View {
        VStack(spacing: 14) {
            Text("When do you usually eat?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            mealTimePicker(title: "Breakfast", time: $breakfastTime)
            mealTimePicker(title: "Lunch", time: $lunchTime)
            mealTimePicker(title: "Dinner", time: $dinnerTime)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func mealTimePicker(
        title: LocalizedStringKey,
        time: Binding<MealTime>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }

            HStack(spacing: 0) {
                timeWheel(
                    label: "Hour",
                    values: 0..<24,
                    selection: time.hour
                )

                Text(":")
                    .font(.title2.bold())

                timeWheel(
                    label: "Minute",
                    values: 0..<60,
                    selection: time.minute
                )

                Text(":")
                    .font(.title2.bold())

                timeWheel(
                    label: "Second",
                    values: 0..<60,
                    selection: time.second
                )
            }
            .frame(height: 82)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timeWheel(
        label: LocalizedStringKey,
        values: Range<Int>,
        selection: Binding<Int>
    ) -> some View {
        Picker(label, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(String(format: "%02d", value))
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityLabel(label)
    }

    private func repeatableTextEntryView(
        title: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        addTitle: LocalizedStringKey,
        removeLabel: LocalizedStringKey,
        inputs: Binding<[String]>
    ) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(inputs.wrappedValue.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            TextField(placeholder, text: inputs[index])
                                .font(.body)
                                .textInputAutocapitalization(.sentences)

                            if index > 0 {
                                Button {
                                    inputs.wrappedValue.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(removeLabel)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.secondary.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        inputs.wrappedValue.append("")
                    } label: {
                        Label(addTitle, systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.visible)
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
    }
}

#Preview {
    OnboardingView()
}
