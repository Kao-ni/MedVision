import SwiftUI

struct ProfileView: View {
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
                            .frame(width: 110)
                            .frame(maxHeight: .infinity)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.9))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            VStack(alignment: .leading, spacing: -6) {
                                Text("First Name")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Last Name")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            HStack(spacing: 8) {
                                statPill(value: "Male", label: "Gender")
                                statPill(value: "28", label: "Age")
                                statPill(value: "Jan 15", label: "Birthday")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    infoCard(title: "Health Information", items: [
                        ("drop.fill", Color.red, "Blood Type", "O+"),
                        ("allergens", Color.orange, "Allergies", "Penicillin"),
                        ("cross.case.fill", Color.blue, "Conditions", "None"),
                        ("pills.fill", Color.purple, "Medications", "3 Active"),
                    ])

                    infoCard(title: "Account", items: [
                        ("envelope.fill", Color.orange, "Email", "john@example.com"),
                        ("phone.fill", Color.green, "Phone", "+1 555 0123"),
                    ])
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statPill(value: String, label: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.vertical, 5)
            
            Spacer()
                .frame(maxWidth: 30)
        }
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

#Preview {
    ProfileView()
}
