import SwiftUI
import SwiftData

struct MedicinesView: View {
    @Query(sort: \Medicine.name) private var medicines: [Medicine]
    @State private var showAddMedicine = false
    @State private var searchText = ""

    private var filteredMedicines: [Medicine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return medicines }
        return medicines.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.dosage.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if medicines.isEmpty {
                        emptyState
                    } else {
                        searchField

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                MVSectionHeader(title: "Your Medicines", systemImage: "pills.fill")
                                Spacer()
                                Text("\(filteredMedicines.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.mvAccent)
                            }

                            if filteredMedicines.isEmpty {
                                MVEmptyState(
                                    systemImage: "magnifyingglass",
                                    title: "No matching medicines",
                                    message: "Try a different medicine name or dosage."
                                )
                                .frame(maxWidth: .infinity)
                                .glassCard()
                            } else {
                                ForEach(filteredMedicines) { medicine in
                                    NavigationLink {
                                        MedicineDetailView(medicine: medicine)
                                    } label: {
                                        MedicineRow(medicine: medicine)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .mvScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddMedicine) {
                AddMedicineView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Medicines")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.mvInk)
                Text("Manage doses and reminders in one place")
                    .font(.subheadline)
                    .foregroundStyle(Color.mvSubtle)
            }
            Spacer()
            Button {
                showAddMedicine = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.mvOnAccent)
                    .frame(width: 46, height: 46)
                    .background(Color.mvAccent, in: Circle())
                    .shadow(color: Color.mvAccent.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .accessibilityLabel("Add medicine manually")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.mvSubtle)
            TextField("Search medicines", text: $searchText)
                .foregroundStyle(Color.mvInk)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.mvSubtle)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .glassCard(cornerRadius: 15)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            MVEmptyState(
                systemImage: "pills.fill",
                title: "No Medicines Yet",
                message: "Scan a medicine packet or add one manually."
            )
            Button {
                showAddMedicine = true
            } label: {
                Label("Add Manually", systemImage: "plus")
            }
            .buttonStyle(MVPrimaryButtonStyle())
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

private struct MedicineRow: View {
    let medicine: Medicine
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 14) {
            MVMedicineThumbnail(photoData: medicine.photoData, form: medicine.form, size: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(medicine.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.mvInk)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if !medicine.dosage.isEmpty {
                        Text(medicine.dosage)
                        Text("·")
                    }
                    Text(LocalizedStringKey(medicine.form.localizationKey))
                }
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)

                if medicine.scheduledTimes.isEmpty {
                    Label("No reminders set", systemImage: "bell.slash.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mvWarning)
                } else {
                    Label(
                        AppLanguage.localized(
                            "doses_per_day_format",
                            locale: locale,
                            arguments: [medicine.scheduledTimes.count]
                        ),
                        systemImage: "bell.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mvAccent)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.mvSubtle)
                .accessibilityHidden(true)
        }
        .padding(15)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MedicinesView()
        .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
