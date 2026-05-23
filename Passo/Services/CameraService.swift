import AVFoundation
import CoreImage
import SwiftUI
import UIKit
import Vision

// MARK: - Barcode Result

struct BarcodeResult: Equatable {
    let value: String
    let format: String  // "QR", "Code128", "EAN13", etc.
}

// MARK: - Camera Service

/// Manages AVCaptureSession for live camera preview + real-time barcode detection.
/// Also runs throttled frame OCR (1 fps) so TicketParser gets enriched text context.
@MainActor
final class CameraService: NSObject, ObservableObject {

    @Published var detectedBarcode: BarcodeResult?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    /// Accumulated OCR text from the most recent camera frame — fed into TicketParser
    /// alongside the barcode value for richer field extraction.
    @Published private(set) var latestOCRText: String = ""

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session      = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "passo.camera.session", qos: .userInitiated)
    private let ocrQueue     = DispatchQueue(label: "passo.camera.ocr",     qos: .utility)
    private let metadataOutput   = AVCaptureMetadataOutput()
    private let videoDataOutput  = AVCaptureVideoDataOutput()

    private var lastDetectedValue: String?
    // Accessed only from ocrQueue — nonisolated(unsafe) avoids actor-isolation error
    nonisolated(unsafe) private var lastOCRFrameTime: CFTimeInterval = 0
    private let ocrInterval: CFTimeInterval = 1.5

    // MARK: Lifecycle

    func requestPermissionAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        switch status {
        case .authorized:
            sessionQueue.async { self.configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted { self?.sessionQueue.async { self?.configureAndStart() } }
                }
            }
        default:
            break
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: Torch

    func setTorch(_ on: Bool) {
        guard
            let device = AVCaptureDevice.default(for: .video),
            device.hasTorch,
            (try? device.lockForConfiguration()) != nil
        else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: Private Setup

    private func configureAndStart() {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Barcode metadata output
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = supportedBarcodeTypes
        }

        // Video data output for parallel OCR
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: ocrQueue)
        }

        session.commitConfiguration()

        Task { @MainActor in
            self.previewLayer.session = self.session
            self.previewLayer.videoGravity = .resizeAspectFill
        }

        session.startRunning()
    }

    private var supportedBarcodeTypes: [AVMetadataObject.ObjectType] {
        [.qr, .dataMatrix, .aztec, .code128, .ean13, .ean8, .itf14, .code39]
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension CameraService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let obj   = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = obj.stringValue
        else { return }

        let format = barcodeFormatString(from: obj.type)
        Task { @MainActor in
            guard value != self.lastDetectedValue else { return }
            self.lastDetectedValue = value
            self.detectedBarcode = BarcodeResult(value: value, format: format)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private nonisolated func barcodeFormatString(from type: AVMetadataObject.ObjectType) -> String {
        switch type {
        case .qr:         return "QR"
        case .code128:    return "Code128"
        case .ean13:      return "EAN13"
        case .ean8:       return "EAN8"
        case .dataMatrix: return "DataMatrix"
        case .aztec:      return "Aztec"
        case .itf14:      return "ITF14"
        case .code39:     return "Code39"
        default:          return "QR"
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (OCR)

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastOCRFrameTime >= ocrInterval else { return }
        // Note: lastOCRFrameTime is accessed on ocrQueue — no actor isolation needed
        // since this property is only written here and read here (single queue).
        // We use a local nonisolated approach; the published result goes back to MainActor.

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Commit throttle timestamp before async work so subsequent frames are dropped
        lastOCRFrameTime = now

        let request = VNRecognizeTextRequest()
        request.recognitionLevel     = .fast  // ~200 ms vs ~800 ms for accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        guard (try? handler.perform([request])) != nil else { return }

        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: " ")

        guard !text.isEmpty else { return }
        Task { @MainActor in
            self.latestOCRText = text
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }

    final class PreviewUIView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }
}
