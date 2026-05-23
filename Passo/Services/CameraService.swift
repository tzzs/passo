import AVFoundation
import CoreImage
import SwiftUI
import UIKit

// MARK: - Barcode Result

struct BarcodeResult: Equatable {
    let value: String
    let format: String  // "QR", "Code128", "EAN13", etc.
}

// MARK: - Camera Service

/// Manages AVCaptureSession for live camera preview + real-time barcode detection.
/// Runs the capture session on a background serial queue to keep the main thread free.
@MainActor
final class CameraService: NSObject, ObservableObject {

    @Published var detectedBarcode: BarcodeResult?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "passo.camera.session", qos: .userInitiated)
    private let metadataOutput = AVCaptureMetadataOutput()

    // Debounce: only fire once per unique barcode value
    private var lastDetectedValue: String?

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

        // Input
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Metadata output for barcode detection
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = supportedBarcodeTypes
        }

        session.commitConfiguration()

        // Wire preview layer on main thread before starting
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
            let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
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

// MARK: - Camera Preview UIViewRepresentable

/// Wraps AVCaptureVideoPreviewLayer in a SwiftUI-compatible view.
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

    // Custom UIView that keeps the previewLayer in sync with its bounds
    final class PreviewUIView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }
}
