import UIKit
import Social
import ImageIO
import Vision
import UniformTypeIdentifiers

// MARK: - Share Extension Entry Point

/// Receives images shared from other apps, runs barcode + OCR detection,
/// then hands the result off to the main Passo app via a shared App Group URL.
final class ShareViewController: UIViewController {

    private let appGroupID = "group.com.passo.app"
    private let passoURL   = URL(string: "passo://import")!

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        extractAndProcess()
    }

    // MARK: - Extraction

    private func extractAndProcess() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments else {
            cancel(message: "未收到任何内容")
            return
        }

        // Prefer image; fall back to URL
        if let imageProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
                guard error == nil else {
                    Task { @MainActor in
                        self?.cancel(message: "无法读取图片")
                    }
                    return
                }
                var image: UIImage?
                if let url  = data as? URL     { image = UIImage(contentsOfFile: url.path) }
                if let uiImg = data as? UIImage { image = uiImg }
                if let imgData = data as? Data  { image = UIImage(data: imgData) }

                guard let image else {
                    Task { @MainActor in
                        self?.cancel(message: "图片格式不支持")
                    }
                    return
                }
                Task { @MainActor in
                    await self?.analyze(image: image)
                }
            }
        } else if let urlProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                let urlString = (data as? URL)?.absoluteString ?? (data as? String ?? "")
                Task { @MainActor in
                    self?.handOff(barcodeValue: urlString, barcodeFormat: "QR", ocrText: "")
                }
            }
        } else {
            cancel(message: "Passo 暂不支持此类型内容")
        }
    }

    // MARK: - Analysis

    private func analyze(image: UIImage) async {
        guard let cgImage = image.cgImage else {
            cancel(message: "图片处理失败")
            return
        }

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImagePropertyOrientation(from: image.imageOrientation),
            options: [:]
        )

        let barcodeReq = VNDetectBarcodesRequest()
        barcodeReq.symbologies = [.qr, .dataMatrix, .aztec, .code128, .ean13, .itf14, .code39]

        let ocrReq = VNRecognizeTextRequest()
        ocrReq.recognitionLevel = .accurate
        ocrReq.recognitionLanguages = ["zh-Hans", "en-US"]
        ocrReq.usesLanguageCorrection = true

        try? handler.perform([barcodeReq, ocrReq])

        let barcode = barcodeReq.results?.first
        let barcodeValue = barcode?.payloadStringValue ?? ""
        let barcodeFormat = barcodeFormatString(for: barcode?.symbology)
        // Keep line breaks: TicketParser.extractTitle() relies on per-line splitting.
        let ocrText = (ocrReq.results as? [VNRecognizedTextObservation] ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        // Save thumbnail to App Group container so main app can read it
        let thumbData = image.preparingThumbnail(of: CGSize(width: 400, height: 400))?.jpegData(compressionQuality: 0.75)
        if let thumbData,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let thumbURL = container.appendingPathComponent("pending_thumb.jpg")
            try? thumbData.write(to: thumbURL)
        }

        handOff(barcodeValue: barcodeValue, barcodeFormat: barcodeFormat, ocrText: ocrText)
    }

    // MARK: - Hand-Off

    private func handOff(barcodeValue: String, barcodeFormat: String, ocrText: String) {
        guard !barcodeValue.isEmpty || ocrText.count > 10 else {
            cancel(message: "未识别到票据信息")
            return
        }

        // Persist payload in App Group so Passo app can read on launch.
        // Surface failures instead of silently opening the app with no data —
        // a nil container almost always means the App Group is misconfigured.
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            cancel(message: "无法访问共享存储，请确认已开启 App Group（\(appGroupID)）")
            return
        }

        let payload: [String: String] = ["barcode": barcodeValue, "format": barcodeFormat, "ocr": ocrText]
        let payloadURL = container.appendingPathComponent("pending_import.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: payloadURL)
        } catch {
            cancel(message: "保存导入数据失败：\(error.localizedDescription)")
            return
        }

        // Open main app via custom URL scheme
        _ = extensionContext?.open(passoURL, completionHandler: nil)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel(message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "无法导入", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                self?.extensionContext?.cancelRequest(withError: NSError(
                    domain: "com.passo.share",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            })
            self?.present(alert, animated: true)
        }
    }

    private func barcodeFormatString(for symbology: VNBarcodeSymbology?) -> String {
        guard let symbology else { return "QR" }
        switch symbology {
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

    private func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:            return .up
        case .upMirrored:    return .upMirrored
        case .down:          return .down
        case .downMirrored:  return .downMirrored
        case .left:          return .left
        case .leftMirrored:  return .leftMirrored
        case .right:         return .right
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
