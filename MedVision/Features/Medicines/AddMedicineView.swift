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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var dosage: String
    @State private var form: MedicineForm
    @State private var notes: String
    @State private var scheduledTimes: [Date]
    @State private var frequencyNote: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var isEditing: Bool  { existing != nil }
    private var isOCRResult: Bool { prefilled != nil && existing == nil }
    private var isSaveDisabled: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(prefilled: RecognizedMedicine? = nil, existing: Medicine? = nil, initialPhotoData: Data? = nil) {
        self.prefilled = prefilled
        self.existing = existing
        self.initialPhotoData = initialPhotoData

        if let m = existing {
            _name          = State(initialValue: m.name)
            _dosage        = State(initialValue: m.dosage)
            _form          = State(initialValue: m.form)
            _notes         = State(initialValue: m.notes)
            _scheduledTimes = State(initialValue: m.scheduledTimes)
            _frequencyNote = State(initialValue: m.frequencyNote)
            _photoData     = State(initialValue: m.photoData)
        } else if let p = prefilled {
            _name          = State(initialValue: p.name)
            _dosage        = State(initialValue: p.dosage)
            _form          = State(initialValue: p.form)
            _notes         = State(initialValue: p.notes)
            _scheduledTimes = State(initialValue: [])
            _frequencyNote = State(initialValue: "")
            _photoData     = State(initialValue: p.photoData ?? initialPhotoData)
        } else {
            _name          = State(initialValue: "")
            _dosage        = State(initialValue: "")
            _form          = State(initialValue: .pill)
            _notes         = State(initialValue: "")
            _scheduledTimes = State(initialValue: [])
            _frequencyNote = State(initialValue: "")
            _photoData     = State(initialValue: initialPhotoData)
        }
        _photoItem = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isOCRResult {
                    Section {
                        Label("Check the details below and correct anything before saving.", systemImage: "info.circle")
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

                    Picker("Form", selection: $form) {
                        ForEach(MedicineForm.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
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
            .navigationTitle(isEditing ? "Edit Medicine" : isOCRResult ? "Confirm Medicine" : "Add Medicine")
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
                        "Dose \(i + 1)",
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
        let trimmedNotes    = notes.trimmingCharacters(in: .whitespaces)
        let trimmedFreqNote = frequencyNote.trimmingCharacters(in: .whitespaces)
        let sorted          = scheduledTimes.sorted()

        if let medicine = existing {
            medicine.name          = trimmedName
            medicine.dosage        = trimmedDosage
            medicine.form          = form
            medicine.notes         = trimmedNotes
            medicine.scheduledTimes = sorted
            medicine.frequencyNote = trimmedFreqNote
            medicine.photoData     = photoData
            Task { await NotificationService.shared.schedule(for: medicine) }
        } else {
            let medicine = Medicine(
                name: trimmedName,
                dosage: trimmedDosage,
                form: form,
                notes: trimmedNotes,
                photoData: photoData,
                scheduledTimes: sorted,
                frequencyNote: trimmedFreqNote
            )
            context.insert(medicine)
            Task { await NotificationService.shared.schedule(for: medicine) }
        }
        dismiss()
    }
}

#Preview {
    AddMedicineView()
}
