@preconcurrency import AVFoundation
import Auth
import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import Vision
import Combine

private let supportedBarcodeObjectTypes: [AVMetadataObject.ObjectType] = [
    .ean8,
    .ean13,
    .upce,
    .code128,
    .code39,
    .qr,
    .dataMatrix
]

private let supportedBarcodeSymbologies: [VNBarcodeSymbology] = [
    .ean8,
    .ean13,
    .upce,
    .code128,
    .code39,
    .qr,
    .dataMatrix
]

struct ScanView: View {
    @Binding var showCamera: Bool
    let onClose: () -> Void

    @Environment(AuthService.self) private var auth

    @State private var isRecognizing = false
    @State private var recognitionStage: RecognitionStage = .idle
    @State private var selectedMode: ScannerMode = .label
    @State private var recognitionResult: RecognizedMedicine?
    @State private var showAddMedicine = false
    @State private var ocrErrorMessage: String?
    @State private var scannedBarcode: String?
    @State private var didCaptureBarcode = false
    @State private var barcodeUnlockTask: Task<Void, Never>?
    @State private var recognitionTask: Task<Void, Never>?
    @State private var capturedPhotoData: Data?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    var body: some View {
        Group {
            if showCamera {
                ScannerFullScreenView(
                    isBusy: isRecognizing,
                    busyMessage: recognitionStage == .idle
                        ? nil
                        : recognitionStage.message,
                    selectedMode: $selectedMode,
                    onClose: closeScanner,
                    onCapture: { image in
                        if selectedMode == .barcode {
                            handleBarcodeImage(image)
                        } else {
                            handleCapture(image)
                        }
                    },
                    onBarcodeCapture: handleBarcodeCapture,
                    onGalleryTap: { showPhotoPicker = true }
                )
            } else {
                Color.black
                    .ignoresSafeArea()
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoPickerItem,
            matching: .images
        )
        .task(id: photoPickerItem?.itemIdentifier) {
            guard let item = photoPickerItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if selectedMode == .barcode {
                    handleBarcodeImage(image)
                } else {
                    handleCapture(image)
                }
            }
            await MainActor.run {
                photoPickerItem = nil
            }
        }
        .sheet(isPresented: $showAddMedicine, onDismiss: {
            resetScanState()
        }) {
            AddMedicineView(
                prefilled: recognitionResult,
                initialPhotoData: capturedPhotoData,
                scannedBarcode: scannedBarcode,
                scanErrorMessage: ocrErrorMessage
            )
        }
        .onDisappear {
            cancelPendingWork()
        }
    }

    private func handleCapture(_ image: UIImage) {
        guard !isRecognizing else { return }
        recognitionTask?.cancel()
        recognitionTask = Task {
            await MainActor.run {
                didCaptureBarcode = false
                isRecognizing = true
                recognitionStage = .readingLabel
                capturedPhotoData = image.jpegData(compressionQuality: 0.8)
                ocrErrorMessage = nil
                scannedBarcode = nil
            }

            do {
                let token = await MainActor.run { auth.session?.accessToken }
                let result = try await RecognitionService.shared.recognize(
                    image,
                    accessToken: token
                ) { stage in
                    Task { @MainActor in
                        recognitionStage = stage
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    recognitionResult = result
                    ocrErrorMessage = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isRecognizing = false
                    recognitionStage = .idle
                }
                return
            } catch {
                await MainActor.run {
                    recognitionResult = nil
                    ocrErrorMessage = (error as? RecognitionError)?.errorDescription
                        ?? NSLocalizedString("Couldn't read the packet. Fill in the details below.", comment: "")
                }
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                isRecognizing = false
                recognitionStage = .idle
                showAddMedicine = true
            }
        }
    }

    private func handleBarcodeCapture(_ barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            ocrErrorMessage = "Couldn't read the barcode. Try again or switch to manual entry."
            return
        }
        guard !didCaptureBarcode else { return }

        barcodeUnlockTask?.cancel()
        didCaptureBarcode = true
        recognitionResult = nil
        capturedPhotoData = nil
        scannedBarcode = trimmed
        ocrErrorMessage = nil
        showAddMedicine = true
    }

    private func handleBarcodeImage(_ image: UIImage) {
        Task {
            await MainActor.run {
                barcodeUnlockTask?.cancel()
                didCaptureBarcode = true
                isRecognizing = true
                capturedPhotoData = nil
                ocrErrorMessage = nil
                scannedBarcode = nil
                recognitionResult = nil
            }

            do {
                if let barcode = try await decodeBarcode(from: image) {
                    await MainActor.run {
                        barcodeUnlockTask?.cancel()
                        didCaptureBarcode = true
                        scannedBarcode = barcode
                        showAddMedicine = true
                    }
                } else {
                    await MainActor.run {
                        ocrErrorMessage = "Couldn't read the barcode from this photo."
                        showAddMedicine = true
                    }
                }
            } catch {
                await MainActor.run {
                    ocrErrorMessage = "Couldn't read the barcode from this photo."
                    showAddMedicine = true
                }
            }

            await MainActor.run {
                isRecognizing = false
            }
        }
    }

    private func decodeBarcode(from image: UIImage) async throws -> String? {
        guard let cgImage = image.cgImage ?? image.ciImage.flatMap({ CIContext().createCGImage($0, from: $0.extent) }) else {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let payload = (request.results as? [VNBarcodeObservation])?.first?.payloadStringValue
                continuation.resume(returning: payload)
            }
            request.symbologies = supportedBarcodeSymbologies
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: image.imageOrientation.cgImagePropertyOrientation,
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func resetScanState() {
        recognitionResult = nil
        scannedBarcode = nil
        ocrErrorMessage = nil
        capturedPhotoData = nil
        isRecognizing = false

        barcodeUnlockTask?.cancel()
        barcodeUnlockTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            didCaptureBarcode = false
        }
    }

    private func closeScanner() {
        cancelPendingWork()
        onClose()
    }

    private func cancelPendingWork() {
        recognitionTask?.cancel()
        recognitionTask = nil
        barcodeUnlockTask?.cancel()
        barcodeUnlockTask = nil
        isRecognizing = false
        recognitionStage = .idle
    }
}

private struct ScannerFullScreenView: View {
    let isBusy: Bool
    var busyMessage: String? = nil
    @Binding var selectedMode: ScannerMode
    let onClose: () -> Void
    let onCapture: (UIImage) -> Void
    let onBarcodeCapture: (String) -> Void
    let onGalleryTap: () -> Void

    @StateObject private var camera = ScannerCameraController()

    var body: some View {
        GeometryReader { proxy in
            let safe = proxy.safeAreaInsets
            let size = proxy.size

            ZStack {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.20),
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar(safe: safe)
                    Spacer()
                }

                scannerStack(in: size)

                VStack(spacing: 0) {
                    Spacer()
                    footerStack(safe: safe)
                }

                if isBusy {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text(busyMessage ?? AppLanguage.localized("Reading label..."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .onAppear {
                camera.onCapture = onCapture
                camera.onBarcodeCapture = onBarcodeCapture
                camera.start()
            }
            .onDisappear {
                camera.stop()
            }
            .onChange(of: selectedMode) { _, mode in
                camera.setMode(mode)
            }
        }
        .ignoresSafeArea()
    }

    private func topBar(safe: EdgeInsets) -> some View {
            HStack {
                MaterialIconButton(
                    systemImage: "chevron.left",
                    size: 52,
                    isActive: false,
                    isDisabled: false,
                    action: onClose
                )

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, safe.top + 58)
    }

    private func scannerStack(in size: CGSize) -> some View {
        let dimensions = reticleSize(for: size)

        return VStack(spacing: 14) {
            Spacer(minLength: 0)

            VStack(spacing: 16) {
                ReticleView(
                    width: dimensions.width,
                    height: dimensions.height
                )

                if let tipText = camera.tipText(for: selectedMode) {
                    TipBanner(
                        text: tipText,
                        color: camera.tipColor
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footerStack(safe: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                if let feedback = camera.captureFeedback {
                    CaptureBadge(text: feedback.text)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                ModeToggle(mode: $selectedMode, isDisabled: isBusy)

                BottomControls(
                    onGalleryTap: onGalleryTap,
                    onShutterTap: {
                        camera.capturePhoto()
                    },
                    onFlashTap: { camera.toggleFlash() },
                    flashEnabled: camera.isFlashOn,
                    isDisabled: isBusy
                )
            }
            .padding(.bottom, max(safe.bottom, 0) + 20)
        }
    }

    private func reticleSize(for size: CGSize) -> CGSize {
        switch selectedMode {
        case .label:
            return CGSize(width: size.width * 0.75, height: size.height * 0.35)
        case .barcode:
            return CGSize(width: size.width * 0.75, height: size.height * 0.18)
        }
    }
}

private enum ScannerMode: String, CaseIterable {
    case label
    case barcode

    var title: String {
        switch self {
        case .label: return AppLanguage.localized("Label")
        case .barcode: return AppLanguage.localized("Barcode")
        }
    }

    var icon: String {
        switch self {
        case .label: return "doc.text"
        case .barcode: return "barcode"
        }
    }

    var defaultTip: String? {
        switch self {
        case .label: return nil
        case .barcode: return AppLanguage.localized("Centre the barcode inside the frame")
        }
    }

    var scanText: String {
        switch self {
        case .label: return AppLanguage.localized("Scanning label...")
        case .barcode: return AppLanguage.localized("Reading barcode...")
        }
    }

    var successText: String {
        switch self {
        case .label: return AppLanguage.localized("Label captured!")
        case .barcode: return AppLanguage.localized("Barcode found!")
        }
    }
}

private enum TipState: Equatable {
    case `default`
    case angle
    case lighting
    case distance
    case blur
    case permissionDenied
    case cameraUnavailable
    case ready
}

private struct CaptureFeedback: Equatable {
    let text: String
}

private final class ScannerCameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isFlashOn = false
    @Published var tipState: TipState = .default
    @Published var captureFeedback: CaptureFeedback?

    var onCapture: ((UIImage) -> Void)?
    var onBarcodeCapture: ((String) -> Void)?

    private let sessionQueue = DispatchQueue(label: "medvision.scanner.session")
    private let analysisQueue = DispatchQueue(label: "medvision.scanner.analysis", qos: .userInitiated)

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoDelegate = ScannerPhotoDelegate()

    private var isConfigured = false
    private var currentDevice: AVCaptureDevice?
    private var currentMode: ScannerMode = .label
    private var distanceArea: CGFloat = 0
    private var hasDistanceReading = false
    private var frameCount = 0
    private var isCapturing = false
    private var feedbackTask: Task<Void, Never>?
    private var lastTipState: TipState = .default
    private var pendingTipState: TipState = .default
    private var pendingTipCount = 0

    override init() {
        super.init()
        photoDelegate.onPhoto = { [weak self] image in
            self?.onCapture?(image)
        }
        photoDelegate.onFinish = { [weak self] in
            self?.isCapturing = false
        }
        session.beginConfiguration()
        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                guard self.configureIfNeeded() else { return }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    guard granted else { return }
                    self.sessionQueue.async { [weak self] in
                        guard let self else { return }
                        guard self.configureIfNeeded() else { return }
                        if !self.session.isRunning {
                            self.session.startRunning()
                        }
                    }
                }
            default:
                DispatchQueue.main.async {
                    self.tipState = .permissionDenied
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        feedbackTask?.cancel()
        feedbackTask = nil
        DispatchQueue.main.async {
            self.captureFeedback = nil
            self.isCapturing = false
        }
    }

    func setMode(_ mode: ScannerMode) {
        guard currentMode != mode else { return }
        currentMode = mode
        distanceArea = 0
        hasDistanceReading = false
        frameCount = 0
        pendingTipState = .default
        pendingTipCount = 0
        updateTip(.default, force: true)
        feedbackTask?.cancel()
        feedbackTask = nil

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.metadataOutput.metadataObjectTypes = mode == .barcode
                ? supportedBarcodeObjectTypes
                : []
            self.session.commitConfiguration()
        }
    }

    func toggleFlash() {
        guard let device = currentDevice, device.hasTorch else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()
                let next = !self.isFlashOn
                device.torchMode = next ? .on : .off
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isFlashOn = next
                }
            } catch {
                DispatchQueue.main.async {
                    self.isFlashOn = false
                }
            }
        }
    }

    func capturePhoto() {
        guard !isCapturing else { return }
        guard isConfigured, session.isRunning else {
            DispatchQueue.main.async {
                self.tipState = .cameraUnavailable
            }
            return
        }
        isCapturing = true
        showCaptureFeedback()

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.currentDevice?.hasFlash == true {
                settings.flashMode = self.isFlashOn ? .on : .off
            }
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.photoOutput.capturePhoto(with: settings, delegate: self.photoDelegate)
            }
        }
    }

    func tipText(for mode: ScannerMode) -> String? {
        switch tipState {
        case .default:
            return mode.defaultTip
        case .angle:
            return AppLanguage.localized("Tilt the camera - hold it flat above the label")
        case .lighting:
            return AppLanguage.localized("Move to better light or turn on flash")
        case .distance:
            return AppLanguage.localized("Move closer - about 20 cm works best")
        case .blur:
            return AppLanguage.localized("Hold still - camera is focusing...")
        case .permissionDenied:
            return AppLanguage.localized("Camera access is blocked. Enable it in Settings to scan.")
        case .cameraUnavailable:
            return AppLanguage.localized("No camera is available on this device.")
        case .ready:
            return AppLanguage.localized("Looking good - tap the shutter to scan")
        }
    }

    var tipColor: Color {
        switch tipState {
        case .default: return .green
        case .angle: return .orange
        case .lighting: return .yellow
        case .distance: return .cyan
        case .blur: return .red
        case .permissionDenied: return .orange
        case .cameraUnavailable: return .orange
        case .ready: return .green
        }
    }

    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.tipState = .cameraUnavailable
            }
            return false
        }

        currentDevice = device
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        metadataOutput.setMetadataObjectsDelegate(self, queue: analysisQueue)
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
        }
        metadataOutput.metadataObjectTypes = currentMode == .barcode
            ? supportedBarcodeObjectTypes
            : []

        session.commitConfiguration()
        isConfigured = true
        return true
    }

    private func showCaptureFeedback() {
        feedbackTask?.cancel()
        guard currentMode == .barcode else {
            DispatchQueue.main.async {
                self.captureFeedback = nil
            }
            return
        }

        let captureMode = currentMode
        let scanningText = captureMode.scanText
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                self.captureFeedback = CaptureFeedback(text: scanningText)
            }
        }

        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.captureFeedback = CaptureFeedback(text: captureMode.successText)
                }
            }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.captureFeedback = nil
                }
                self.isCapturing = false
            }
        }
    }

    private func evaluateTip() {
        let next: TipState

        if currentBrightness < 0.18 {
            next = .lighting
        } else if currentSharpness < 115 {
            next = .blur
        } else if currentMode == .label {
            if !hasDistanceReading {
                next = .default
            } else if distanceArea < 0.16 {
                next = .distance
            } else {
                next = .ready
            }
        } else {
            next = .ready
        }

        updateTip(next)
    }

    private var currentBrightness: Double = 0.5
    private var currentSharpness: Double = 300

    private func updateTip(_ state: TipState) {
        updateTip(state, force: false)
    }

    private func updateTip(_ state: TipState, force: Bool) {
        let requiredStableCount: Int
        switch state {
        case .default:
            requiredStableCount = 24
        case .ready:
            requiredStableCount = 10
        case .angle, .lighting, .distance, .blur, .permissionDenied, .cameraUnavailable:
            requiredStableCount = 14
        }

        if state == pendingTipState {
            pendingTipCount += 1
        } else {
            pendingTipState = state
            pendingTipCount = 1
        }

        guard force || (pendingTipCount >= requiredStableCount && state != lastTipState) else { return }
        lastTipState = state
        DispatchQueue.main.async {
            self.tipState = state
        }
    }
}

extension ScannerCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameCount += 1

        let metrics = analyze(pixelBuffer: pixelBuffer)
        currentBrightness = metrics.brightness
        currentSharpness = metrics.sharpness

        if currentMode == .label, frameCount % 6 == 0 {
            analyzeLabelDistance(pixelBuffer: pixelBuffer)
        }

        evaluateTip()
    }

    private func analyze(pixelBuffer: CVPixelBuffer) -> (brightness: Double, sharpness: Double) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return (0.5, 300)
        }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
        let step = max(4, min(width, height) / 64)

        var count = 0.0
        var sum = 0.0
        var lapSum = 0.0
        var lapSquares = 0.0

        for y in stride(from: 1, to: height - 1, by: step) {
            let row = pixels.advanced(by: y * bytesPerRow)
            for x in stride(from: 1, to: width - 1, by: step) {
                let center = Double(row[x])
                let left = Double(row[x - 1])
                let right = Double(row[x + 1])
                let up = Double(pixels.advanced(by: (y - 1) * bytesPerRow)[x])
                let down = Double(pixels.advanced(by: (y + 1) * bytesPerRow)[x])
                let laplacian = center * 4.0 - left - right - up - down

                count += 1
                sum += center
                lapSum += laplacian
                lapSquares += laplacian * laplacian
            }
        }

        guard count > 0 else { return (0.5, 300) }

        let brightness = (sum / count) / 255.0
        let meanLap = lapSum / count
        let sharpness = max(0, (lapSquares / count) - (meanLap * meanLap))
        return (brightness, sharpness)
    }

    private func analyzeLabelDistance(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            guard let self else { return }
            let observations = request.results as? [VNRectangleObservation]
            let area = observations?.first.map {
                $0.boundingBox.width * $0.boundingBox.height
            } ?? 0
            DispatchQueue.main.async {
                self.distanceArea = CGFloat(area)
                self.hasDistanceReading = observations?.isEmpty == false
            }
        }

        request.maximumObservations = 1
        request.minimumConfidence = 0.5
        request.minimumSize = 0.12
        request.minimumAspectRatio = 0.25
        request.quadratureTolerance = 20.0

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
}

extension ScannerCameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard currentMode == .barcode else { return }
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = readable.stringValue, !value.isEmpty else { return }
        DispatchQueue.main.async {
            self.tipState = .ready
            self.onBarcodeCapture?(value)
        }
    }
}

private final class ScannerPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    nonisolated(unsafe) var onPhoto: ((UIImage) -> Void)?
    nonisolated(unsafe) var onFinish: (() -> Void)?

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async { [onFinish] in
                onFinish?()
            }
        }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async { [onPhoto] in
            onPhoto?(image)
        }
    }
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            previewLayer.session = newValue
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct ReticleView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            ReticleCorners()
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
        }
        .frame(width: width, height: height)
        .animation(.easeInOut(duration: 0.28), value: width)
        .animation(.easeInOut(duration: 0.28), value: height)
    }
}

private struct ReticleCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 1.5
        let len: CGFloat = 40
        let radius: CGFloat = 15

        let minX = rect.minX + inset
        let minY = rect.minY + inset
        let maxX = rect.maxX - inset
        let maxY = rect.maxY - inset

        path.move(to: CGPoint(x: minX, y: minY + len))
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addArc(
            center: CGPoint(x: minX + radius, y: minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: minX + len, y: minY))

        path.move(to: CGPoint(x: maxX - len, y: minY))
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addArc(
            center: CGPoint(x: maxX - radius, y: minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: maxX, y: minY + len))

        path.move(to: CGPoint(x: minX, y: maxY - len))
        path.addLine(to: CGPoint(x: minX, y: maxY - radius))
        path.addArc(
            center: CGPoint(x: minX + radius, y: maxY - radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: minX + len, y: maxY))

        path.move(to: CGPoint(x: maxX - len, y: maxY))
        path.addLine(to: CGPoint(x: maxX - radius, y: maxY))
        path.addArc(
            center: CGPoint(x: maxX - radius, y: maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - len))

        return path
    }
}

private struct TipBanner: View {
    let text: String
    let color: Color

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .scaleEffect(pulse ? 1.25 : 1.0)
                .opacity(pulse ? 1.0 : 0.6)

            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct CaptureBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.40))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
    }
}

private struct ModeToggle: View {
    @Binding var mode: ScannerMode
    let isDisabled: Bool

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 2
            let height = proxy.size.height
            let indicatorHeight = height * 0.8
            let segmentWidth = max(0, (proxy.size.width - inset * 2) / 2)
            let indicatorWidth = max(0, segmentWidth - 4)
            let indicatorCenterX = inset + (segmentWidth / 2) + (mode == .label ? 0 : segmentWidth)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .position(x: indicatorCenterX, y: height / 2)
                    .animation(.spring(response: 0.28, dampingFraction: 0.84), value: mode)

                HStack(spacing: 0) {
                    modeSegment(
                        mode: .label,
                        icon: "doc.text",
                        title: ScannerMode.label.title,
                        width: segmentWidth
                    )

                    modeSegment(
                        mode: .barcode,
                        icon: "barcode",
                        title: ScannerMode.barcode.title,
                        width: segmentWidth
                    )
                }
            }
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
        .frame(height: 44)
        .frame(maxWidth: 288)
    }

    private func modeSegment(mode option: ScannerMode, icon: String, title: String, width: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                mode = option
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(mode == option ? Color.black : Color.white.opacity(0.88))
            .frame(width: width)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1.0)
    }
}

private struct BottomControls: View {
    let onGalleryTap: () -> Void
    let onShutterTap: () -> Void
    let onFlashTap: () -> Void
    let flashEnabled: Bool
    let isDisabled: Bool

    var body: some View {
        HStack {
            MaterialIconButton(
                systemImage: "photo",
                size: 58,
                isActive: false,
                isDisabled: isDisabled,
                action: onGalleryTap
            )

            Spacer()

            ShutterButton(action: onShutterTap, isDisabled: isDisabled)

            Spacer()

            MaterialIconButton(
                systemImage: flashEnabled ? "flashlight.on.fill" : "flashlight.off.fill",
                size: 58,
                isActive: flashEnabled,
                isDisabled: isDisabled,
                action: onFlashTap
            )
        }
        .padding(.horizontal, 24)
    }
}

private struct MaterialIconButton: View {
    let systemImage: String
    let size: CGFloat
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isActive ? 0.0 : 0.20), lineWidth: 0.5)
                    )
                if isActive {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                }

                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.80))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1.0)
    }
}

private struct ShutterButton: View {
    let action: () -> Void
    let isDisabled: Bool
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.72), lineWidth: 3)
                    .shadow(color: .white.opacity(0.18), radius: 8)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 2)

                Circle()
                    .fill(Color.white)
                    .padding(8)
            }
            .frame(width: 82, height: 82)
            .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .opacity(isDisabled ? 0.62 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
    }
}
