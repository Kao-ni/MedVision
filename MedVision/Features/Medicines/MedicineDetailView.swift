import SwiftUI
import SwiftData

struct MedicineDetailView: View {
    let medicine: Medicine

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var recentEvents: [DoseEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        return medicine.doseEvents
            .filter { $0.scheduledTime > cutoff && $0.status != .pending }
            .sorted { $0.scheduledTime > $1.scheduledTime }
    }

    var body: some View {
        List {
            photoSection
            detailsSection
            scheduleSection
            historySection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(medicine.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddMedicineView(existing: medicine)
        }
        .confirmationDialog(
            "Delete \(medicine.name)?",
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

    // MARK: - Sections

    @ViewBuilder
    private var photoSection: some View {
        if let data = medicine.photoData, let image = UIImage(data: data) {
            Section {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            if !medicine.dosage.isEmpty {
                LabeledContent("Dosage", value: medicine.dosage)
            }
            LabeledContent("Form", value: medicine.form.rawValue)
            if !medicine.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(medicine.notes)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if !medicine.scheduledTimes.isEmpty {
            Section("Reminder Schedule") {
                if !medicine.frequencyNote.isEmpty {
                    Label(medicine.frequencyNote, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(medicine.scheduledTimes.sorted(), id: \.self) { time in
                    Label(
                        time.formatted(date: .omitted, time: .shortened),
                        systemImage: "bell"
                    )
                }
            }
        } else {
            Section("Reminder Schedule") {
                Label("No reminders set", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
                Button("Add Schedule") { showEdit = true }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !recentEvents.isEmpty {
            Section("Last 14 Days") {
                ForEach(recentEvents) { event in
                    DoseEventRow(event: event)
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Medicine", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MedicineDetailView(medicine: PlaceholderData.paracetamol)
    }
    .modelContainer(PlaceholderData.previewContainer)
}
