import UIKit
import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = true
    @AppStorage("profile_birthdayTimestamp") private var storedBirthdayTimestamp = Date().timeIntervalSince1970
    @AppStorage("profile_bloodType") private var storedBloodType = ""
    @AppStorage("profile_allergies") private var storedAllergies = "None"
    @AppStorage("profile_conditions") private var storedConditions = "None"
    @AppStorage("meal_breakfastSeconds") private var storedBreakfastSeconds = 8 * 60 * 60
    @AppStorage("meal_lunchSeconds") private var storedLunchSeconds = 12 * 60 * 60
    @AppStorage("meal_dinnerSeconds") private var storedDinnerSeconds = 18 * 60 * 60

    @State private var currentPage = 0
    @State private var birthDay = 15
    @State private var birthMonth = 6
    @State private var birthYear = 2000
    @State private var bloodTypeInput = ""
    @State private var selectedAllergies: Set<String> = []
    @State private var allergyOtherText = ""
    @State private var showAllergyOther = false
    @State private var noAllergies = false
    @State private var selectedConditions: Set<String> = []
    @State private var conditionSearch = ""
    @State private var noConditions = false
    @State private var breakfastTime = MealTime(hour: 8, minute: 0)
    @State private var lunchTime = MealTime(hour: 12, minute: 0)
    @State private var dinnerTime = MealTime(hour: 18, minute: 0)
    @State private var showLoader = false

    private struct MealTime {
        var hour: Int
        var minute: Int
        var secondsFromMidnight: Int { (hour * 3600) + (minute * 60) }
    }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemImage: "pills.fill",
            color: .mvAccent,
            title: "Your Medicine\nAssistant",
            description: "Keep all your medicines in one place and never miss a dose."
        ),
        OnboardingPage(
            systemImage: "camera.fill",
            color: .mvAccent,
            title: "Scan & Save",
            description: "Just point your camera at any medicine packet. We'll read it for you."
        ),
        OnboardingPage(
            systemImage: "bell.fill",
            color: .mvAccent,
            title: "Get Reminded",
            description: "We'll remind you exactly when to take each medicine, every day."
        )
    ]

    private let bloodTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"]
    private let allergyLabels = [
        "Penicillin", "Peanuts", "Tree Nuts", "Shellfish", "Dairy", "Gluten",
        "Soy", "Latex", "Pollen", "Dust", "Pet Dander", "Bee Stings",
        "Sulfa Drugs", "Ibuprofen"
    ]
    private let conditionLabels = [
        "Diabetes", "Hypertension", "Asthma", "Thyroid disorder", "High cholesterol",
        "Heart disease", "Kidney disease", "Depression or anxiety", "Arthritis"
    ]
    private let months = Calendar.current.monthSymbols

    private var birthdayPageIndex: Int { pages.count }
    private var bloodTypePageIndex: Int { pages.count + 1 }
    private var allergiesPageIndex: Int { pages.count + 2 }
    private var conditionsPageIndex: Int { pages.count + 3 }
    private var mealTimesPageIndex: Int { pages.count + 4 }
    private var totalPageCount: Int { pages.count + 5 }

    private var isCurrentPageValid: Bool {
        switch currentPage {
        case birthdayPageIndex: return isBirthdayValid
        case bloodTypePageIndex: return !bloodTypeInput.isEmpty
        case allergiesPageIndex:
            return noAllergies || !selectedAllergies.isEmpty || !allergyOtherText.trimmingCharacters(in: .whitespaces).isEmpty
        case conditionsPageIndex:
            return noConditions || !selectedConditions.isEmpty
        default: return true
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index]).tag(index)
                    }
                    birthdayEntryView.tag(birthdayPageIndex)
                    bloodTypeEntryView.tag(bloodTypePageIndex)
                    allergiesEntryView.tag(allergiesPageIndex)
                    conditionsEntryView.tag(conditionsPageIndex)
                    mealTimesEntryView.tag(mealTimesPageIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.top, 16)

                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 44)
            }

            if showLoader {
                SettingUpView()
                    .transition(.opacity)
            }
        }
        .mvScreenBackground()
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalPageCount, id: \.self) { index in
                Capsule()
                    .fill(currentPage == index ? Color.mvAccent : Color.mvSubtle.opacity(0.3))
                    .frame(width: currentPage == index ? 24 : 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.mvInk)
                        .frame(width: 54, height: 54)
                        .glassCard(cornerRadius: 14)
                }
            }

            Button {
                advance()
            } label: {
                Text(currentPage == mealTimesPageIndex ? LocalizedStringKey("Get Started") : LocalizedStringKey("Next"))
            }
            .buttonStyle(MVPrimaryButtonStyle(enabled: isCurrentPageValid))
            .disabled(!isCurrentPageValid)
        }
    }

    private func advance() {
        if currentPage == birthdayPageIndex { persistBirthday() }
        if currentPage == bloodTypePageIndex { storedBloodType = bloodTypeInput }
        if currentPage == allergiesPageIndex { persistAllergies() }
        if currentPage == conditionsPageIndex { persistConditions() }

        if currentPage < mealTimesPageIndex {
            withAnimation { currentPage += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        persistBirthday()
        storedBloodType = bloodTypeInput
        persistAllergies()
        persistConditions()
        storedBreakfastSeconds = breakfastTime.secondsFromMidnight
        storedLunchSeconds = lunchTime.secondsFromMidnight
        storedDinnerSeconds = dinnerTime.secondsFromMidnight

        withAnimation { showLoader = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            shouldShowOnboarding = false
            dismiss()
        }
    }

    private func persistBirthday() {
        var comps = DateComponents()
        comps.year = birthYear
        comps.month = birthMonth
        comps.day = birthDay
        if let date = Calendar.current.date(from: comps) {
            storedBirthdayTimestamp = date.timeIntervalSince1970
        }
    }

    private var isBirthdayValid: Bool {
        guard let birthday = birthdayDate else { return false }
        return birthday <= Date()
    }

    private var birthdayDate: Date? {
        var comps = DateComponents()
        comps.year = birthYear
        comps.month = birthMonth
        comps.day = birthDay
        return Calendar.current.date(from: comps)
    }

    private func persistAllergies() {
        if noAllergies {
            storedAllergies = "None"
            return
        }
        var items = allergyLabels.filter { selectedAllergies.contains($0) }
        let other = allergyOtherText.trimmingCharacters(in: .whitespaces)
        if !other.isEmpty { items.append(other) }
        storedAllergies = items.isEmpty ? "None" : items.joined(separator: ", ")
    }

    private func persistConditions() {
        if noConditions {
            storedConditions = "None"
            return
        }
        let items = conditionLabels.filter { selectedConditions.contains($0) }
        storedConditions = items.isEmpty ? "None" : items.joined(separator: ", ")
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 36) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 200, height: 200)
                Image(systemName: page.systemImage)
                    .font(.system(size: 84))
                    .foregroundStyle(page.color)
            }
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.mvInk)
                    .multilineTextAlignment(.center)
                Text(page.description)
                    .font(.title3)
                    .foregroundStyle(Color.mvSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Spacer()
        }
    }

    private var birthdayEntryView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("When's your birthday?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.mvAccent)
                .multilineTextAlignment(.center)

            BirthdayWheelPicker(
                day: $birthDay,
                month: $birthMonth,
                year: $birthYear,
                monthSymbols: months
            )
            .frame(height: 200)
            .padding(.horizontal, 8)
            .glassCard()
            .padding(.horizontal, 24)

            Text("We use this to personalize your medication reminders.")
                .font(.footnote)
                .foregroundStyle(Color.mvSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var bloodTypeEntryView: some View {
        VStack(spacing: 20) {
            Text("What is your blood type?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(bloodTypes, id: \.self) { type in
                        Button {
                            bloodTypeInput = type
                        } label: {
                            HStack {
                                Group {
                                    if type == "Unknown" { Text("Unknown") } else { Text(verbatim: type) }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(bloodTypeInput == type ? .white : Color.mvInk)
                                Spacer()
                                if bloodTypeInput == type {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .glassCard(selected: bloodTypeInput == type)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var allergiesEntryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Do you have any allergies?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.mvInk)
            Text("Select all that apply — you can update this anytime.")
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(allergyLabels, id: \.self) { label in
                        chip(label: label, selected: selectedAllergies.contains(label)) {
                            noAllergies = false
                            if selectedAllergies.contains(label) { selectedAllergies.remove(label) }
                            else { selectedAllergies.insert(label) }
                        }
                    }
                    Button {
                        withAnimation { showAllergyOther.toggle() }
                    } label: {
                        Text("＋ Add other")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.mvAccent)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .strokeBorder(Color.mvAccent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            )
                    }
                    .buttonStyle(.plain)
                }

                if showAllergyOther {
                    TextField("Type an allergy", text: $allergyOtherText)
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                        .padding(.top, 12)
                        .onChange(of: allergyOtherText) { _, value in
                            if !value.isEmpty { noAllergies = false }
                        }
                }
            }

            Button {
                noAllergies.toggle()
                if noAllergies { selectedAllergies.removeAll(); allergyOtherText = "" }
            } label: {
                Text("No known allergies")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(noAllergies ? .white : Color.mvInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(noAllergies ? Color.mvAccent : nil)
                    .glassCard(selected: noAllergies)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private var conditionsEntryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Any existing health conditions?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.mvInk)
            Text("This helps us flag potential interactions.")
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.mvSubtle)
                TextField("Search conditions", text: $conditionSearch)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassCard(cornerRadius: 14)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredConditions, id: \.self) { label in
                        Button {
                            noConditions = false
                            if selectedConditions.contains(label) { selectedConditions.remove(label) }
                            else { selectedConditions.insert(label) }
                        } label: {
                            HStack {
                                Text(verbatim: label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.mvInk)
                                Spacer()
                                checkbox(selected: selectedConditions.contains(label))
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                noConditions.toggle()
                if noConditions { selectedConditions.removeAll() }
            } label: {
                Text("No known conditions")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(noConditions ? .white : Color.mvInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(noConditions ? Color.mvAccent : nil)
                    .glassCard(selected: noConditions)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private var filteredConditions: [String] {
        let query = conditionSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return conditionLabels }
        return conditionLabels.filter { $0.lowercased().contains(query) }
    }

    private var mealTimesEntryView: some View {
        VStack(spacing: 16) {
            Text("When do you usually eat?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

            mealTimeRow(title: "Breakfast", time: $breakfastTime)
            mealTimeRow(title: "Lunch", time: $lunchTime)
            mealTimeRow(title: "Dinner", time: $dinnerTime)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func mealTimeRow(title: LocalizedStringKey, time: Binding<MealTime>) -> some View {
        HStack {
            Image(systemName: "alarm.fill").foregroundStyle(Color.mvAccent)
            Text(title).font(.headline).foregroundStyle(Color.mvInk)
            Spacer()
            DatePicker(
                title,
                selection: Binding(
                    get: {
                        var c = DateComponents(); c.hour = time.wrappedValue.hour; c.minute = time.wrappedValue.minute
                        return Calendar.current.date(from: c) ?? Date()
                    },
                    set: {
                        let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                        time.wrappedValue.hour = c.hour ?? 0
                        time.wrappedValue.minute = c.minute ?? 0
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .padding(16)
        .glassCard(cornerRadius: 14)
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? .white : Color.mvInk)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.mvAccent : Color.white.opacity(0.5), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func checkbox(selected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(selected ? Color.mvAccent : Color.white)
                .frame(width: 24, height: 24)
            RoundedRectangle(cornerRadius: 7)
                .stroke(selected ? Color.mvAccent : Color(hex: "D8DEE4"), lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct BirthdayWheelPicker: UIViewRepresentable {
    @Binding var day: Int
    @Binding var month: Int
    @Binding var year: Int
    let monthSymbols: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(day: $day, month: $month, year: $year, monthSymbols: monthSymbols)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.backgroundColor = .clear
        picker.selectRow(max(0, day - 1), inComponent: 0, animated: false)
        picker.selectRow(max(0, month - 1), inComponent: 1, animated: false)
        picker.selectRow(max(0, year - 1950), inComponent: 2, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        context.coordinator.day = $day
        context.coordinator.month = $month
        context.coordinator.year = $year
        context.coordinator.monthSymbols = monthSymbols

        let currentDayRow = max(0, min(day - 1, context.coordinator.dayCount(for: month, year: year) - 1))
        let currentMonthRow = max(0, month - 1)
        let currentYearRow = max(0, year - 1950)

        if uiView.selectedRow(inComponent: 0) != currentDayRow {
            uiView.selectRow(currentDayRow, inComponent: 0, animated: false)
        }
        if uiView.selectedRow(inComponent: 1) != currentMonthRow {
            uiView.selectRow(currentMonthRow, inComponent: 1, animated: false)
        }
        if uiView.selectedRow(inComponent: 2) != currentYearRow {
            uiView.selectRow(currentYearRow, inComponent: 2, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var day: Binding<Int>
        var month: Binding<Int>
        var year: Binding<Int>
        var monthSymbols: [String]

        init(day: Binding<Int>, month: Binding<Int>, year: Binding<Int>, monthSymbols: [String]) {
            self.day = day
            self.month = month
            self.year = year
            self.monthSymbols = monthSymbols
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch component {
            case 0:
                return dayCount(for: month.wrappedValue, year: year.wrappedValue)
            case 1:
                return 12
            case 2:
                return (1950...Calendar.current.component(.year, from: Date())).count
            default:
                return 0
            }
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            switch component {
            case 0: return "\(row + 1)"
            case 1: return monthSymbols[safe: row] ?? ""
            case 2: return "\(1950 + row)"
            default: return nil
            }
        }

        func pickerView(
            _ pickerView: UIPickerView,
            attributedTitleForRow row: Int,
            forComponent component: Int
        ) -> NSAttributedString? {
            let title = rowTitle(for: row, component: component)
            return NSAttributedString(
                string: title,
                attributes: [
                    .foregroundColor: UIColor.black,
                    .font: UIFont.systemFont(ofSize: 20, weight: .regular)
                ]
            )
        }

        private func rowTitle(for row: Int, component: Int) -> String {
            switch component {
            case 0: return "\(row + 1)"
            case 1: return monthSymbols[safe: row] ?? ""
            case 2: return "\(1950 + row)"
            default: return ""
            }
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case 0:
                day.wrappedValue = row + 1
            case 1:
                month.wrappedValue = row + 1
                let validDays = dayCount(for: month.wrappedValue, year: year.wrappedValue)
                if day.wrappedValue > validDays {
                    day.wrappedValue = validDays
                    pickerView.reloadComponent(0)
                    pickerView.selectRow(validDays - 1, inComponent: 0, animated: false)
                }
            case 2:
                year.wrappedValue = 1950 + row
                let validDays = dayCount(for: month.wrappedValue, year: year.wrappedValue)
                if day.wrappedValue > validDays {
                    day.wrappedValue = validDays
                    pickerView.reloadComponent(0)
                    pickerView.selectRow(validDays - 1, inComponent: 0, animated: false)
                }
            default:
                break
            }
            pickerView.reloadAllComponents()
        }

        func dayCount(for month: Int, year: Int) -> Int {
            let dayRange: ClosedRange<Int>
            switch month {
            case 1, 3, 5, 7, 8, 10, 12:
                dayRange = 1...31
            case 4, 6, 9, 11:
                dayRange = 1...30
            case 2:
                let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
                dayRange = 1...(isLeapYear ? 29 : 28)
            default:
                dayRange = 1...31
            }
            return dayRange.count
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct SettingUpView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.mvSky.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Setting things up…")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(animate ? 1 : 0.5)
                Text("This will only take a moment.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

#Preview {
    OnboardingView()
}
