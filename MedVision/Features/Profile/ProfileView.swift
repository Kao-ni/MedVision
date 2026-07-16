import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @AppStorage("profile_firstName") private var firstName = "First Name"
    @AppStorage("profile_lastName") private var lastName = "Last Name"
    @AppStorage("profile_gender") private var gender = "Male"
    @AppStorage("profile_birthdayTimestamp") private var birthdayTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("profile_bloodType") private var bloodType = "O+"
    @AppStorage("profile_allergies") private var allergies = "None"
    @AppStorage("profile_conditions") private var conditions = "None"
    @AppStorage("profile_medications") private var medications = "None"
    @AppStorage("profile_phone") private var phone = ""
    @AppStorage(AppLanguage.storageKey) private var displayLanguage = "en"
    @AppStorage(UserMealTimes.breakfastKey) private var breakfastSeconds = UserMealTimes.defaultBreakfast
    @AppStorage(UserMealTimes.lunchKey) private var lunchSeconds = UserMealTimes.defaultLunch
    @AppStorage(UserMealTimes.dinnerKey) private var dinnerSeconds = UserMealTimes.defaultDinner
    @Environment(\.locale) private var locale

    @State private var showEditSheet = false
    @State private var isSigningOut = false
    @State private var signOutError: String?

    private var accountEmail: String { auth.userEmail ?? "—" }

    private var birthdayDisplay: String {
        Date(timeIntervalSince1970: birthdayTimestamp).formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
    }

    private var ageDisplay: String {
        let birthday = Date(timeIntervalSince1970: birthdayTimestamp)
        let age = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return age > 0 ? "\(age)" : "0"
    }

    private var initials: String {
        let values = [displayFirstName, displayLastName]
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        return values.isEmpty ? "MV" : values.uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    identityCard

                    infoCard(title: "Health Information", items: [
                        ProfileInfoItem(icon: "drop.fill", tint: .mvDanger, label: "Blood Type", value: bloodType),
                        ProfileInfoItem(icon: "allergens", tint: .mvWarning, label: "Allergies", value: allergies, localizeValue: allergies == "None"),
                        ProfileInfoItem(icon: "cross.case.fill", tint: .mvAccent, label: "Conditions", value: conditions, localizeValue: conditions == "None"),
                        ProfileInfoItem(icon: "pills.fill", tint: .mvSuccess, label: "Medications", value: medications, localizeValue: medications == "None")
                    ])

                    languageCard
                    mealTimesCard

                    CaregiverAlertsCard()

                    infoCard(title: "Account", items: [
                        ProfileInfoItem(icon: "envelope.fill", tint: .mvAccent, label: "Email", value: accountEmail),
                        ProfileInfoItem(icon: "phone.fill", tint: .mvSuccess, label: "Phone", value: phone.isEmpty ? "—" : phone)
                    ])

                    if let signOutError {
                        Label(signOutError, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.mvDanger)
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                    }

                    Button {
                        Task { await signOut() }
                    } label: {
                        ZStack {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .opacity(isSigningOut ? 0 : 1)
                            if isSigningOut {
                                ProgressView().tint(Color.mvDanger)
                            }
                        }
                    }
                    .buttonStyle(MVSecondaryButtonStyle(tint: .mvDanger))
                    .disabled(isSigningOut)
                    .accessibilityLabel("Sign Out")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .mvScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditSheet) {
                EditProfileSheet(
                    firstName: $firstName,
                    lastName: $lastName,
                    gender: $gender,
                    birthdayTimestamp: $birthdayTimestamp,
                    bloodType: $bloodType,
                    allergies: $allergies,
                    conditions: $conditions,
                    medications: $medications,
                    phone: $phone,
                    accountEmail: accountEmail
                )
            }
            .onAppear {
                applyAuthNameIfNeeded()
                if displayLanguage.isEmpty {
                    displayLanguage = "en"
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Profile")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.mvInk)
                Text("Your health and account preferences")
                    .font(.subheadline)
                    .foregroundStyle(Color.mvSubtle)
            }
            Spacer()
            Button("Edit") { showEditSheet = true }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.mvAccent)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.mvAccent.opacity(0.13), in: Capsule())
        }
    }

    private var identityCard: some View {
        VStack(spacing: 15) {
            Text(initials)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mvOnAccent)
                .frame(width: 82, height: 82)
                .background(
                    LinearGradient(
                        colors: [Color.mvAccentGradientStart, Color.mvAccentGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 2))
                .shadow(color: Color.mvAccent.opacity(0.3), radius: 14, x: 0, y: 7)
                .accessibilityHidden(true)

            Text("\(displayFirstName) \(displayLastName)")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    statPill(value: gender, label: "Gender", localizeValue: true)
                    statPill(value: ageDisplay, label: "Age")
                    statPill(value: birthdayDisplay, label: "Birthday")
                }
                VStack(spacing: 8) {
                    statPill(value: gender, label: "Gender", localizeValue: true)
                    HStack(spacing: 8) {
                        statPill(value: ageDisplay, label: "Age")
                        statPill(value: birthdayDisplay, label: "Birthday")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard()
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MVSectionHeader(title: "Language", systemImage: "globe")
            VStack(alignment: .leading, spacing: 13) {
                Text("App language")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mvInk)
                Picker("Language", selection: $displayLanguage) {
                    Text("English").tag("en")
                    Text(verbatim: "ไทย").tag("th")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("App language")
            }
            .padding(16)
            .glassCard()
            .onChange(of: displayLanguage) { _, newValue in
                displayLanguage = AppLanguage.code(for: newValue)
            }
        }
    }

    private var mealTimesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MVSectionHeader(title: "Meal times", systemImage: "fork.knife")
            VStack(spacing: 0) {
                mealTimeRow(title: "Breakfast", systemImage: "sunrise.fill", seconds: $breakfastSeconds)
                Divider().overlay(Color.mvBorder.opacity(0.45))
                mealTimeRow(title: "Lunch", systemImage: "sun.max.fill", seconds: $lunchSeconds)
                Divider().overlay(Color.mvBorder.opacity(0.45))
                mealTimeRow(title: "Dinner", systemImage: "sunset.fill", seconds: $dinnerSeconds)
            }
            .padding(.horizontal, 15)
            .glassCard()
        }
    }

    private func mealTimeRow(
        title: LocalizedStringKey,
        systemImage: String,
        seconds: Binding<Int>
    ) -> some View {
        HStack(spacing: 12) {
            MVIconTile(systemImage: systemImage, tint: .mvAccent, size: 38)
            DatePicker(
                title,
                selection: Binding(
                    get: { date(fromSeconds: seconds.wrappedValue) },
                    set: { seconds.wrappedValue = secondsFromMidnight(of: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .font(.body)
            .tint(Color.mvAccent)
        }
        .padding(.vertical, 11)
        .accessibilityLabel(Text(title))
    }

    private func date(fromSeconds seconds: Int) -> Date {
        var comps = DateComponents()
        comps.hour = seconds / 3600
        comps.minute = (seconds % 3600) / 60
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func secondsFromMidnight(of date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((comps.hour ?? 0) * 3600) + ((comps.minute ?? 0) * 60)
    }

    private var displayFirstName: String {
        if firstName != "First Name" { return firstName }
        if let full = auth.userDisplayName {
            return full.split(separator: " ").first.map(String.init) ?? AppLanguage.localized("First Name")
        }
        return AppLanguage.localized("First Name")
    }

    private var displayLastName: String {
        if lastName != "Last Name" { return lastName }
        if let full = auth.userDisplayName {
            let parts = full.split(separator: " ")
            if parts.count > 1 {
                return parts.dropFirst().joined(separator: " ")
            }
        }
        return AppLanguage.localized("Last Name")
    }

    private func applyAuthNameIfNeeded() {
        guard let full = auth.userDisplayName, !full.isEmpty else { return }
        let parts = full.split(separator: " ").map(String.init)
        if firstName == "First Name", let given = parts.first {
            firstName = given
        }
        if lastName == "Last Name", parts.count > 1 {
            lastName = parts.dropFirst().joined(separator: " ")
        }
    }

    private func signOut() async {
        signOutError = nil
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await auth.signOut()
        } catch {
            signOutError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func statPill(
        value: String,
        label: LocalizedStringKey,
        localizeValue: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Group {
                if localizeValue {
                    Text(LocalizedStringKey(value))
                } else {
                    Text(verbatim: value)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.mvInk)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.mvSubtle)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.mvAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func infoCard(title: LocalizedStringKey, items: [ProfileInfoItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MVSectionHeader(title: title)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .overlay(Color.mvBorder.opacity(0.45))
                            .padding(.leading, 52)
                    }
                    HStack(spacing: 12) {
                        MVIconTile(systemImage: item.icon, tint: item.tint, size: 38)
                        Text(item.label)
                            .foregroundStyle(Color.mvInk)
                        Spacer()
                        Group {
                            if item.localizeValue {
                                Text(LocalizedStringKey(item.value))
                            } else {
                                Text(verbatim: item.value)
                            }
                        }
                        .foregroundStyle(Color.mvSubtle)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    }
                    .font(.body)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 15)
            .glassCard()
        }
    }
}

private struct ProfileInfoItem: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let label: LocalizedStringKey
    let value: String
    var localizeValue = false
}

struct EditProfileSheet: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var gender: String
    @Binding var birthdayTimestamp: Double
    @Binding var bloodType: String
    @Binding var allergies: String
    @Binding var conditions: String
    @Binding var medications: String
    @Binding var phone: String
    let accountEmail: String

    @Environment(\.dismiss) private var dismiss

    let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    let bloodTypeOptions = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "Unknown"]

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: birthdayTimestamp) },
            set: { birthdayTimestamp = $0.timeIntervalSince1970 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }

                Section("Personal") {
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) {
                            Text(LocalizedStringKey($0))
                        }
                    }
                    DatePicker("Birthday", selection: birthdayBinding, displayedComponents: .date)
                        .tint(Color.mvAccent)
                }

                Section("Health") {
                    Picker("Blood Type", selection: $bloodType) {
                        ForEach(bloodTypeOptions, id: \.self) {
                            Text(LocalizedStringKey($0))
                        }
                    }
                    LabeledContent {
                        TextField("None", text: $allergies)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Allergies", systemImage: "allergens")
                            .foregroundStyle(Color.mvWarning)
                    }
                    LabeledContent {
                        TextField("None", text: $conditions)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Conditions", systemImage: "cross.case.fill")
                            .foregroundStyle(Color.mvAccent)
                    }
                    LabeledContent {
                        TextField("None", text: $medications)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Medications", systemImage: "pills.fill")
                            .foregroundStyle(Color.mvSuccess)
                    }
                }

                Section("Contact") {
                    LabeledContent("Email", value: accountEmail)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .scrollContentBackground(.hidden)
            .mvScreenBackground()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mvAccent)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())
}
