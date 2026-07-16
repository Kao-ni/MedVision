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
    private enum Field: Hashable {
        case name, dosage, barcode, notes, frequencyNote
    }

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
    @FocusState private var focusedField: Field?

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
            let suggestion = MealScheduleMapper.suggest(
                hint: p.scheduleHint,
                meals: .loadFromDefaults()
            )
            let resolvedName: String = {
                if let resolution = p.resolution {
                    switch resolution.status {
                    case .consensus:
                        return resolution.finalName?.isEmpty == false ? resolution.finalName! : p.name
                    case .disagreement, .unverified:
                        return p.name
                    }
                }
                return p.name
            }()
            let resolvedDosage: String = {
                if let resolution = p.resolution, resolution.status == .consensus,
                   let dosage = resolution.finalDosage, !dosage.isEmpty {
                    return dosage
                }
                return p.dosage
            }()
            _name          = State(initialValue: resolvedName)
            _dosage        = State(initialValue: resolvedDosage)
            _form          = State(initialValue: p.form)
            _notes         = State(initialValue: p.notes)
            _scheduledTimes = State(initialValue: suggestion.times)
            _frequencyNote = State(initialValue: suggestion.frequencyNote)
            _barcode       = State(initialValue: scannedBarcode ?? "")
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
                if isOCRResult || isBarcodeResult || scanErrorMessage != nil {
                    Section {
                        confirmationHero
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let scanErrorMessage {
                    Section {
                        Label(scanErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.mvWarning)
                    }
                    .listRowBackground(Color.mvWarning.opacity(0.1))
                }

                if isOCRResult {
                    Section {
                        Label("Check the details below and correct anything before saving.", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.mvSubtle)
                    }
                    .listRowBackground(Color.mvAccent.opacity(0.1))

                    if let resolution = prefilled?.resolution {
                        resolutionSection(resolution)
                    }

                    if prefilled?.fieldConfidence.hasUncertainFields == true {
                        Section {
                            Label(
                                "Some fields may be inaccurate. Please double-check items marked below.",
                                systemImage: "exclamationmark.circle.fill"
                            )
                            .font(.subheadline)
                            .foregroundStyle(Color.mvWarning)
                        }
                        .listRowBackground(Color.mvWarning.opacity(0.1))
                    }

                    if let warnings = prefilled?.warnings, !warnings.isEmpty {
                        Section("Scan Warnings") {
                            ForEach(warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mvWarning)
                            }
                        }
                        .listRowBackground(Color.mvWarning.opacity(0.1))
                    }
                }

                if isBarcodeResult {
                    Section {
                        Label("Barcode captured from the scanner. Fill in the medicine name and dosage before saving.", systemImage: "barcode.viewfinder")
                            .font(.subheadline)
                            .foregroundStyle(Color.mvSubtle)
                    }
                    .listRowBackground(Color.mvAccent.opacity(0.1))
                }

                Section("Medicine Details") {
                    LabeledContent {
                        TextField("e.g. Paracetamol", text: $name)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .dosage }
                    } label: {
                        ocrFieldLabel("Name", confidence: prefilled?.fieldConfidence.name)
                    }

                    LabeledContent {
                        TextField("e.g. 500 mg", text: $dosage)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .dosage)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .barcode }
                    } label: {
                        ocrFieldLabel("Dosage", confidence: prefilled?.fieldConfidence.dosage)
                    }

                    LabeledContent {
                        TextField("e.g. 0123456789012", text: $barcode)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .barcode)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                    } label: {
                        Text("Barcode")
                    }

                    Picker(selection: $form) {
                        ForEach(MedicineForm.allCases, id: \.self) { f in
                            Text(LocalizedStringKey(f.localizationKey)).tag(f)
                        }
                    } label: {
                        ocrFieldLabel("Form", confidence: prefilled?.fieldConfidence.form)
                    }
                }
                .listRowBackground(Color.mvSurface.opacity(0.72))

                Section("Notes") {
                    TextField("e.g. Take with food", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .focused($focusedField, equals: .notes)
                }
                .listRowBackground(Color.mvSurface.opacity(0.72))

                scheduleSection

                photoSection
            }
            .scrollContentBackground(.hidden)
            .mvScreenBackground()
            .navigationTitle(
                isEditing
                    ? LocalizedStringKey("Edit Medicine")
                    : isOCRResult
                        ? LocalizedStringKey("Confirm Medicine")
                        : LocalizedStringKey("Add Medicine")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { close() }
                        .foregroundStyle(Color.mvAccent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    save()
                } label: {
                    Label(saveButtonTitle, systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(MVPrimaryButtonStyle(enabled: !isSaveDisabled))
                .disabled(isSaveDisabled)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var confirmationHero: some View {
        VStack(spacing: 14) {
            Group {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    MVIconTile(
                        systemImage: isBarcodeResult ? "barcode.viewfinder" : "doc.text.viewfinder",
                        tint: .mvAccent,
                        size: 76
                    )
                }
            }

            VStack(spacing: 5) {
                Text(confirmationTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.mvInk)
                Text("Review every field before adding this medicine to your schedule.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mvSubtle)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassCard()
        .padding(.vertical, 8)
    }

    private var saveButtonTitle: LocalizedStringKey {
        if isEditing { return "Save Changes" }
        if isOCRResult || isBarcodeResult { return "Confirm and Save" }
        return "Add Medicine"
    }

    private var confirmationTitle: LocalizedStringKey {
        if isOCRResult { return "Scan complete" }
        if isBarcodeResult { return "Barcode captured" }
        return "Review medicine details"
    }

    private var scheduleSection: some View {
        Section {
            if scheduledTimes.isEmpty {
                Text("No times set - add at least one to receive reminders.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mvSubtle)
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
                    .focused($focusedField, equals: .frequencyNote)
            }
        } header: {
            Text("Reminder Schedule")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if isOCRResult && !scheduledTimes.isEmpty {
                    Text("Times suggested from your meal schedule.")
                }
                Text("Swipe left on a time to remove it.")
                    .opacity(scheduledTimes.isEmpty ? 0 : 1)
            }
        }
        .listRowBackground(Color.mvSurface.opacity(0.72))
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
                        .foregroundStyle(Color.mvAccent)
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
        .listRowBackground(Color.mvSurface.opacity(0.72))
    }

    @ViewBuilder
    private func resolutionSection(_ resolution: MedicineResolution) -> some View {
        switch resolution.status {
        case .consensus:
            Section {
                Label(
                    resolution.label == "ai_corrected"
                        ? "AI-corrected name (not found in local lists). Please confirm before saving."
                        : "Verified match",
                    systemImage: resolution.label == "ai_corrected"
                        ? "sparkles"
                        : "checkmark.seal.fill"
                )
                .font(.subheadline)
                .foregroundStyle(resolution.label == "ai_corrected" ? Color.mvAccent : Color.mvSuccess)
            }
            .listRowBackground(
                (resolution.label == "ai_corrected" ? Color.mvAccent : Color.mvSuccess).opacity(0.1)
            )

        case .disagreement:
            Section("Sources Disagree") {
                Label(
                    "Sources disagree on the medicine name. Pick one or type your own.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(Color.mvDanger)

                ForEach(uniqueNameCandidates(resolution.candidates)) { candidate in
                    Button {
                        name = candidate.name
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name)
                                    .foregroundStyle(Color.mvInk)
                                Text(candidate.source.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(Color.mvSubtle)
                            }
                            Spacer()
                            if name == candidate.name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.mvAccent)
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color.mvDanger.opacity(0.1))

        case .unverified:
            Section {
                Label(
                    "Could not verify this medicine. Please check the name carefully.",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(Color.mvWarning)
            }
            .listRowBackground(Color.mvWarning.opacity(0.1))
        }
    }

    private func uniqueNameCandidates(_ candidates: [ResolutionCandidate]) -> [ResolutionCandidate] {
        var seen = Set<String>()
        var result: [ResolutionCandidate] = []
        for candidate in candidates {
            let key = candidate.name.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    @ViewBuilder
    private func ocrFieldLabel(_ title: LocalizedStringKey, confidence: RecognitionConfidence?) -> some View {
        if isOCRResult, let confidence, confidence != .high {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: confidence == .low ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(confidence == .low ? Color.mvWarning : Color.mvAccent)
            }
        } else {
            Text(title)
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
        close()
    }

    private func close() {
        focusedField = nil
        // Let UIKit finish ending the text-input session before removing the sheet.
        DispatchQueue.main.async {
            dismiss()
        }
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
