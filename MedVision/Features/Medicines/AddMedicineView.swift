import SwiftUI
import SwiftData
import PhotosUI

// Handles three entry paths:
//   - existing != nil          -> Edit an existing medicine
//   - prefilled != nil         -> Confirm OCR result (post-scan)
//   - both nil                 -> Manual add
//
// Golden rule: never auto-save - the user always confirms before anything is written.
struct AddMedicineView: View {
    var prefilled: RecognizedMedicine? = nil
    var existing: Medicine? = nil
    var initialPhotoData: Data? = nil
    var scannedBarcode: String? = nil
    var scanErrorMessage: String? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var name: String
    @State private var dosage: String
    @State private var form: MedicineForm
    @State private var notes: String
    @State private var barcode: String
    @State private var scheduledTimes: [Date]
    @State private var frequencyNote: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var isEditing: Bool  { existing != nil }
    private var isOCRResult: Bool { prefilled != nil && existing == nil }
    private var isBarcodeResult: Bool { scannedBarcode?.isEmpty == false && existing == nil && prefilled == nil }
    private var isSaveDisabled: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(
        prefilled: RecognizedMedicine? = nil,
        existing: Medicine? = nil,
        initialPhotoData: Data? = nil,
        scannedBarcode: String? = nil,
        scanErrorMessage: String? = nil
    ) {
        self.prefilled = prefilled
        self.existing = existing
        self.initialPhotoData = initialPhotoData
        self.scannedBarcode = scannedBarcode
        self.scanErrorMessage = scanErrorMessage

        if let m = existing {
            _name          = State(initialValue: m.name)
            _dosage        = State(initialValue: m.dosage)
            _form          = State(initialValue: m.form)
            _notes         = State(initialValue: m.notes)
            _barcode       = State(initialValue: m.barcode ?? "")
            _scheduledTimes = State(initialValue: m.scheduledTimes)
            _frequencyNote = State(initialValue: m.frequencyNote)
            _photoData     = State(initialValue: m.photoData)
        } else if let p = prefilled {
            _name          = State(initialValue: p.name)
            _dosage        = State(initialValue: p.dosage)
            _form          = State(initialValue: p.form)
            _notes         = State(initialValue: p.notes)
            _barcode       = State(initialValue: scannedBarcode ?? "")
            _scheduledTimes = State(initialValue: [])
            _frequencyNote = State(initialValue: "")
            _photoData     = State(initialValue: p.photoData ?? initialPhotoData)
        } else {
            _name          = State(initialValue: "")
            _dosage        = State(initialValue: "")
            _form          = State(initialValue: .tablet)
            _notes         = State(initialValue: "")
            _barcode       = State(initialValue: scannedBarcode ?? "")
            _scheduledTimes = State(initialValue: [])
            _frequencyNote = State(initialValue: "")
            _photoData     = State(initialValue: initialPhotoData)
        }
        _photoItem = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let scanErrorMessage {
                    Section {
                        Label(scanErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                }

                if isOCRResult {
                    Section {
                        Label("Check the details below and correct anything before saving.", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.blue.opacity(0.07))
                }

                if isBarcodeResult {
                    Section {
                        Label("Barcode captured from the scanner. Fill in the medicine name and dosage before saving.", systemImage: "barcode.viewfinder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.blue.opacity(0.07))
                }

                Section("Medicine Details") {
                    LabeledContent {
                        TextField("e.g. Paracetamol", text: $name)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Name")
                    }

                    LabeledContent {
                        TextField("e.g. 500 mg", text: $dosage)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Dosage")
                    }

                    LabeledContent {
                        TextField("e.g. 0123456789012", text: $barcode)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } label: {
                        Text("Barcode")
                    }

                    Picker("Form", selection: $form) {
                        ForEach(MedicineForm.allCases, id: \.self) { f in
                            Text(LocalizedStringKey(f.localizationKey)).tag(f)
                        }
                    }
                }

                Section("Notes") {
                    TextField("e.g. Take with food", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                scheduleSection

                photoSection
            }
            .navigationTitle(
                isEditing
                    ? LocalizedStringKey("Edit Medicine")
                    : isOCRResult
                        ? LocalizedStringKey("Confirm Medicine")
                        : LocalizedStringKey("Add Medicine")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            if scheduledTimes.isEmpty {
                Text("No times set - add at least one to receive reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(scheduledTimes.indices, id: \.self) { i in
                    DatePicker(
                        AppLanguage.localized(
                            "dose_number_format",
                            locale: locale,
                            arguments: [i + 1]
                        ),
                        selection: $scheduledTimes[i],
                        displayedComponents: .hourAndMinute
                    )
                }
                .onDelete { scheduledTimes.remove(atOffsets: $0) }
            }

            Button {
                scheduledTimes.append(defaultNewTime())
            } label: {
                Label("Add Dose Time", systemImage: "plus.circle.fill")
            }

            if !scheduledTimes.isEmpty {
                TextField("Note (e.g. with food, after meal)", text: $frequencyNote)
            }
        } header: {
            Text("Reminder Schedule")
        } footer: {
            Text("Swipe left on a time to remove it.")
                .opacity(scheduledTimes.isEmpty ? 0 : 1)
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    photoData = try? await newItem?.loadTransferable(type: Data.self)
                }
            }

            if photoData != nil {
                Button(role: .destructive) {
                    photoData = nil
                    photoItem = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
    }

    private func defaultNewTime() -> Date {
        var comps = DateComponents()
        comps.hour = 8
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func save() {
        let trimmedName     = name.trimmingCharacters(in: .whitespaces)
        let trimmedDosage   = dosage.trimmingCharacters(in: .whitespaces)
        let trimmedBarcode  = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)
        let trimmedFreqNote = frequencyNote.trimmingCharacters(in: .whitespaces)
        let sorted          = scheduledTimes.sorted()

        let medicine: Medicine
        if let existing {
            existing.name           = trimmedName
            existing.dosage         = trimmedDosage
            existing.form           = form
            existing.notes          = trimmedNotes
            existing.barcode        = trimmedBarcode.isEmpty ? nil : trimmedBarcode
            existing.scheduledTimes = sorted
            existing.frequencyNote  = trimmedFreqNote
            existing.photoData      = photoData
            medicine = existing
        } else {
            let m = Medicine(
                name: trimmedName,
                dosage: trimmedDosage,
                form: form,
                notes: trimmedNotes,
                barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode,
                photoData: photoData,
                scheduledTimes: sorted,
                frequencyNote: trimmedFreqNote
            )
            context.insert(m)
            medicine = m
        }

        generateTodayEvents(for: medicine, newTimes: sorted)
        Task { await NotificationService.shared.schedule(for: medicine) }
        dismiss()
    }

    private func generateTodayEvents(for medicine: Medicine, newTimes: [Date]) {
        let calendar = Calendar.current
        // Remove today's pending events so they're rebuilt from the current schedule.
        medicine.doseEvents
            .filter { calendar.isDateInToday($0.scheduledTime) && $0.status == .pending }
            .forEach { context.delete($0) }

        for time in newTimes {
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            guard let scheduled = calendar.date(
                bySettingHour: comps.hour ?? 0,
                minute: comps.minute ?? 0,
                second: 0,
                of: Date()
            ) else { continue }
            context.insert(DoseEvent(scheduledTime: scheduled, status: .pending, medicine: medicine))
        }
    }
}

#Preview {
    AddMedicineView()
}
