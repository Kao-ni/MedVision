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

    private var accountEmail: String {
        auth.userEmail ?? "—"
    }

    private var birthdayDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = locale
        return formatter.string(from: Date(timeIntervalSince1970: birthdayTimestamp))
    }

    private var ageDisplay: String {
        let calendar = Calendar.current
        let birthday = Date(timeIntervalSince1970: birthdayTimestamp)
        let age = calendar.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return age > 0 ? "\(age)" : "0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 125)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.9))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            VStack(alignment: .leading, spacing: -6) {
                                Text(displayFirstName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text(displayLastName)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            HStack(spacing: 8) {
                                statPill(value: gender, label: "Gender", localizeValue: true)
                                statPill(value: ageDisplay, label: "Age")
                                statPill(value: birthdayDisplay, label: "Birthday")
                            }
                            .padding(.top, 8)
                        }
                        .alignmentGuide(.top) { d in d[.top] + 6 }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    infoCard(title: "Health Information", items: [
                        ("drop.fill", Color.red, "Blood Type", bloodType),
                        ("allergens", Color.orange, "Allergies", allergies),
                        ("cross.case.fill", Color.blue, "Conditions", conditions),
                        ("pills.fill", Color.purple, "Medications", medications),
                    ])

                    languageCard

                    mealTimesCard

                    CaregiverAlertsCard()

                    infoCard(title: "Account", items: [
                        ("envelope.fill", Color.orange, "Email", accountEmail),
                        ("phone.fill", Color.green, "Phone", phone.isEmpty ? "—" : phone),
                    ])

                    if let signOutError {
                        Text(signOutError)
                            .font(.body)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    Button {
                        Task { await signOut() }
                    } label: {
                        ZStack {
                            Text("Sign Out")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .opacity(isSigningOut ? 0 : 1)
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isSigningOut)
                    .padding(.horizontal, 20)
                    .accessibilityLabel(Text("Sign Out"))
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditSheet = true }
                }
            }
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

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Language")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 14) {
                Text("App language")
                    .font(.body)
                    .fontWeight(.medium)

                Picker("Language", selection: $displayLanguage) {
                    Text("English").tag("en")
                    Text(verbatim: "ไทย").tag("th")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text("App language"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .onChange(of: displayLanguage) { _, newValue in
                displayLanguage = AppLanguage.code(for: newValue)
            }
        }
    }

    private var mealTimesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Meal times")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(spacing: 16) {
                mealTimeRow(title: "Breakfast", seconds: $breakfastSeconds)
                mealTimeRow(title: "Lunch", seconds: $lunchSeconds)
                mealTimeRow(title: "Dinner", seconds: $dinnerSeconds)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
    }

    private func mealTimeRow(title: LocalizedStringKey, seconds: Binding<Int>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { date(fromSeconds: seconds.wrappedValue) },
                set: { seconds.wrappedValue = secondsFromMidnight(of: $0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .font(.title3)
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
        VStack(spacing: 1) {
            Group {
                if localizeValue {
                    Text(LocalizedStringKey(value))
                } else {
                    Text(verbatim: value)
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func infoCard(title: String, items: [(String, Color, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(title))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let (icon, color, label, value) = item
                    let showsLocalizedValue = value == "None"
                        || ["Male", "Female", "Non-binary", "Prefer not to say", "Unknown"].contains(value)

                    if index > 0 {
                        Divider().padding(.leading, 56)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(color)
                            .frame(width: 30, height: 30)
                            .background(color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(LocalizedStringKey(label))
                        Spacer()
                        Group {
                            if showsLocalizedValue {
                                Text(LocalizedStringKey(value))
                            } else {
                                Text(verbatim: value)
                            }
                        }
                        .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
    }
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
                        .tint(.black)
                        .foregroundStyle(.black)
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
                            .foregroundStyle(.orange)
                    }
                    LabeledContent {
                        TextField("None", text: $conditions)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Conditions", systemImage: "cross.case.fill")
                            .foregroundStyle(.blue)
                    }
                    LabeledContent {
                        TextField("None", text: $medications)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Medications", systemImage: "pills.fill")
                            .foregroundStyle(.purple)
                    }
                }

                Section("Contact") {
                    LabeledContent("Email", value: accountEmail)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthService())
}
