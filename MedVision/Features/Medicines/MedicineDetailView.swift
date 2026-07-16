import SwiftUI
import SwiftData

struct MedicineDetailView: View {
    let medicine: Medicine

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var recentEvents: [DoseEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        return medicine.doseEvents
            .filter { $0.scheduledTime > cutoff && $0.status != .pending }
            .sorted { $0.scheduledTime > $1.scheduledTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                detailsCard
                scheduleCard
                historyCard

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Medicine", systemImage: "trash")
                }
                .buttonStyle(MVSecondaryButtonStyle(tint: .mvDanger))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .mvScreenBackground()
        .navigationTitle(medicine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mvAccent)
            }
        }
        .sheet(isPresented: $showEdit) {
            AddMedicineView(existing: medicine)
        }
        .confirmationDialog(
            AppLanguage.localized(
                "delete_medicine_format",
                locale: locale,
                arguments: [medicine.name]
            ),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await NotificationService.shared.cancel(for: medicine) }
                context.delete(medicine)
                dismiss()
            }
        } message: {
            Text("This will also delete all dose history for this medicine.")
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            if let data = medicine.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.mvBorder.opacity(0.5), lineWidth: 1)
                    }
            } else {
                MVMedicineThumbnail(photoData: nil, form: medicine.form, size: 92)
                    .padding(.top, 10)
            }

            VStack(spacing: 5) {
                Text(medicine.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.mvInk)
                    .multilineTextAlignment(.center)
                HStack(spacing: 5) {
                    if !medicine.dosage.isEmpty {
                        Text(medicine.dosage)
                        Text("·")
                    }
                    Text(LocalizedStringKey(medicine.form.localizationKey))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mvSubtle)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            MVSectionHeader(title: "Details", systemImage: "list.bullet.rectangle")
            if !medicine.dosage.isEmpty {
                detailRow(label: "Dosage", value: medicine.dosage, systemImage: "scalemass.fill")
            }
            detailRow(
                label: "Form",
                value: AppLanguage.localized(medicine.form.localizationKey, locale: locale),
                systemImage: medicine.form.systemImage
            )
            if !medicine.notes.isEmpty {
                Divider().overlay(Color.mvBorder.opacity(0.45))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Notes")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.mvSubtle)
                    Text(medicine.notes)
                        .font(.body)
                        .foregroundStyle(Color.mvInk)
                }
            }
        }
        .padding(17)
        .glassCard()
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            MVSectionHeader(title: "Reminder Schedule", systemImage: "bell.fill")

            if medicine.scheduledTimes.isEmpty {
                Label("No reminders set", systemImage: "bell.slash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.mvSubtle)
                Button("Add Schedule") { showEdit = true }
                    .buttonStyle(MVSecondaryButtonStyle())
            } else {
                if !medicine.frequencyNote.isEmpty {
                    Label(medicine.frequencyNote, systemImage: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.mvSubtle)
                }
                ForEach(medicine.scheduledTimes.sorted(), id: \.self) { time in
                    HStack {
                        MVIconTile(systemImage: "bell.fill", tint: .mvAccent, size: 38)
                        Text(
                            time,
                            format: Date.FormatStyle(date: .omitted, time: .shortened)
                                .locale(locale)
                        )
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Color.mvInk)
                        Spacer()
                    }
                }
            }
        }
        .padding(17)
        .glassCard()
    }

    @ViewBuilder
    private var historyCard: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                MVSectionHeader(title: "Last 14 Days", systemImage: "clock.arrow.circlepath")
                    .padding(.bottom, 6)
                ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                    DoseEventRow(event: event, showMedicineName: false)
                    if index < recentEvents.count - 1 {
                        Divider().overlay(Color.mvBorder.opacity(0.45))
                    }
                }
            }
            .padding(17)
            .glassCard()
        }
    }

    private func detailRow(label: LocalizedStringKey, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            MVIconTile(systemImage: systemImage, tint: .mvAccent, size: 38)
            Text(label)
                .foregroundStyle(Color.mvInk)
            Spacer()
            Text(value)
                .foregroundStyle(Color.mvSubtle)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        MedicineDetailView(medicine: Medicine(name: "Paracetamol", dosage: "500 mg", form: .tablet))
    }
    .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
