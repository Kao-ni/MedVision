import SwiftUI
import SwiftData

struct MedicinesView: View {
    @Query(sort: \Medicine.name) private var medicines: [Medicine]
    @State private var showAddMedicine = false

    var body: some View {
        NavigationStack {
            Group {
                if medicines.isEmpty {
                    ContentUnavailableView {
                        Label("No Medicines Yet", systemImage: "pills")
                    } description: {
                        Text("Scan a medicine packet or add one manually.")
                    } actions: {
                        Button("Add Manually") { showAddMedicine = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(medicines) { medicine in
                        NavigationLink {
                            MedicineDetailView(medicine: medicine)
                        } label: {
                            MedicineRow(medicine: medicine)
                        }
                    }
                }
            }
            .navigationTitle("Medicines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMedicine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medicine manually")
                }
            }
            .sheet(isPresented: $showAddMedicine) {
                AddMedicineView()
            }
        }
    }
}

private struct MedicineRow: View {
    let medicine: Medicine
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medicine.name)
                .font(.headline)
            HStack(spacing: 6) {
                if !medicine.dosage.isEmpty {
                    Text(medicine.dosage)
                }
                if !medicine.dosage.isEmpty {
                    Text("·")
                }
                Text(LocalizedStringKey(medicine.form.localizationKey))
                if !medicine.scheduledTimes.isEmpty {
                    Text("·")
                    Label(
                        AppLanguage.localized(
                            "doses_per_day_format",
                            locale: locale,
                            arguments: [medicine.scheduledTimes.count]
                        ),
                        systemImage: "bell"
                    )
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MedicinesView()
        .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
