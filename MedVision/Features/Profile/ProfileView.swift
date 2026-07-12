import SwiftUI

struct ProfileView: View {
    @AppStorage("profile_firstName") private var firstName = "First Name"
    @AppStorage("profile_lastName") private var lastName = "Last Name"
    @AppStorage("profile_gender") private var gender = "Male"
    @AppStorage("profile_age") private var age = "28"
    @AppStorage("profile_birthdayTimestamp") private var birthdayTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("profile_bloodType") private var bloodType = "O+"
    @AppStorage("profile_allergies") private var allergies = "None"
    @AppStorage("profile_conditions") private var conditions = "None"
    @AppStorage("profile_medications") private var medications = "None"
    @AppStorage("profile_email") private var email = ""
    @AppStorage("profile_phone") private var phone = ""

    @State private var showEditSheet = false

    private var birthdayDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date(timeIntervalSince1970: birthdayTimestamp))
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
                                Text(firstName)
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text(lastName)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            HStack(spacing: 8) {
                                statPill(value: gender, label: "Gender")
                                statPill(value: age, label: "Age")
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

                    infoCard(title: "Account", items: [
                        ("envelope.fill", Color.orange, "Email", email.isEmpty ? "—" : email),
                        ("phone.fill", Color.green, "Phone", phone.isEmpty ? "—" : phone),
                    ])
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
                    age: $age,
                    birthdayTimestamp: $birthdayTimestamp,
                    bloodType: $bloodType,
                    allergies: $allergies,
                    conditions: $conditions,
                    medications: $medications,
                    email: $email,
                    phone: $phone
                )
            }
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
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
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let (icon, color, label, value) = item

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

                        Text(label)
                        Spacer()
                        Text(value)
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
    @Binding var age: String
    @Binding var birthdayTimestamp: Double
    @Binding var bloodType: String
    @Binding var allergies: String
    @Binding var conditions: String
    @Binding var medications: String
    @Binding var email: String
    @Binding var phone: String

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
                        ForEach(genderOptions, id: \.self) { Text($0) }
                    }
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    DatePicker("Birthday", selection: birthdayBinding, displayedComponents: .date)
                }

                Section("Health") {
                    Picker("Blood Type", selection: $bloodType) {
                        ForEach(bloodTypeOptions, id: \.self) { Text($0) }
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
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
}
