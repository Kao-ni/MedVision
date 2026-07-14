import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ScanView: View {
    @State private var showSourcePicker = false
    @State private var showCamera      = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFilePicker  = false

    @State private var isRecognizing    = false
    @State private var recognitionResult: RecognizedMedicine?
    @State private var showAddMedicine  = false
    @State private var ocrErrorMessage: String?
    @State private var capturedPhotoData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "document.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 24)

                Text("Scan a Medicine Packet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)

                Text("Take a photo and we'll read the details for you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let error = ocrErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        ocrErrorMessage = nil
                        showSourcePicker = true
                    } label: {
                        Group {
                            if isRecognizing {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Reading packet...")
                                }
                            } else {
                                Label("Scan Medicine", systemImage: "document.viewfinder.fill")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRecognizing ? Color.blue.opacity(0.6) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isRecognizing)
                    .accessibilityLabel("Scan a medicine packet")
                    .confirmationDialog("Add a Photo of the Packet", isPresented: $showSourcePicker) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Take Photo") { showCamera = true }
                        }
                        Button("Photo Library") { showPhotoPicker = true }
                        Button("Choose from Files") { showFilePicker = true }
                    }

                    Button {
                        recognitionResult = nil
                        ocrErrorMessage   = nil
                        capturedPhotoData = nil
                        showAddMedicine   = true
                    } label: {
                        Label("Add Manually Instead", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("Add medicine details manually")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    onCapture: handleCapture,
                    onCancel: { showCamera = false }
                )
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data  = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handleCapture(image)
                    }
                    photoPickerItem = nil
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView(
                    onPick: { image in
                        showFilePicker = false
                        handleCapture(image)
                    },
                    onCancel: { showFilePicker = false }
                )
            }
            .sheet(isPresented: $showAddMedicine) {
                AddMedicineView(prefilled: recognitionResult, initialPhotoData: capturedPhotoData)
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        showCamera = false
        isRecognizing = true
        capturedPhotoData = image.jpegData(compressionQuality: 0.8)

        Task {
            do {
                let result = try await RecognitionService.shared.recognize(image)
                recognitionResult = result
                ocrErrorMessage   = nil
            } catch {
                recognitionResult = nil
                ocrErrorMessage   = (error as? RecognitionError)?.errorDescription
                    ?? "Couldn't read the packet. Fill in the details below."
            }
            isRecognizing   = false
            showAddMedicine = true
        }
    }
}

private struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel  = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            else { onCancel() }
        }
    }
}

private struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (UIImage) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick   = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { onCancel(); return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data  = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                onPick(image)
            } else {
                onCancel()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

#Preview {
    ScanView()
}
