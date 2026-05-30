import Foundation
import UIKit

// MARK: - Share Import Service

/// Reads the pending import payload written by the Share Extension
/// into the shared App Group container, then clears it.
enum ShareImportService {

    private static let appGroupID   = "group.com.passo.app"
    private static let payloadFile  = "pending_import.json"
    private static let thumbFile    = "pending_thumb.jpg"

    struct Payload {
        let barcodeValue: String
        let barcodeFormat: String
        let ocrText: String
        let thumbnailData: Data?
    }

    static func consumePendingPayload() -> Payload? {
        guard
            let container  = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }

        let payloadURL = container.appendingPathComponent(payloadFile)
        let thumbURL   = container.appendingPathComponent(thumbFile)

        guard
            let data    = try? Data(contentsOf: payloadURL),
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }

        let barcodeValue = json["barcode"] ?? ""
        let barcodeFormat = json["format"] ?? "QR"
        let ocrText      = json["ocr"] ?? ""
        let thumbData    = try? Data(contentsOf: thumbURL)

        // Consume — remove files so the next launch doesn't re-import
        try? FileManager.default.removeItem(at: payloadURL)
        try? FileManager.default.removeItem(at: thumbURL)

        guard !barcodeValue.isEmpty || ocrText.count > 10 else { return nil }
        return Payload(
            barcodeValue: barcodeValue,
            barcodeFormat: barcodeFormat,
            ocrText: ocrText,
            thumbnailData: thumbData
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let passoShareImport = Notification.Name("com.passo.shareImport")
}
