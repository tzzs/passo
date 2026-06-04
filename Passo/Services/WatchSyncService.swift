import Foundation
import WatchConnectivity
import UIKit
import CoreImage.CIFilterBuiltins

/// Pushes the user's active tickets from the iPhone to the paired Apple Watch
/// over WatchConnectivity.
///
/// Why not App Group / CloudKit: the Watch is a separate physical device, and an
/// App Group container does not span devices, so the Watch cannot read the
/// iPhone's SwiftData store directly. WatchConnectivity is the supported channel
/// for moving a lightweight payload between the paired devices.
///
/// Transfer strategy: the active set is encoded as `[TicketDTO]` and sent via
/// `updateApplicationContext` — the system coalesces to the latest state, which
/// is exactly the semantics we want ("here is the current list of tickets"). We
/// additionally `transferUserInfo` so a Watch that is currently asleep still gets
/// a queued, guaranteed delivery.
///
/// The DTO shape here is duplicated from `PassoWatch/TicketDTO.swift`; the two
/// form the wire contract between the devices and must stay in sync.
final class WatchSyncService: NSObject, @unchecked Sendable {

    static let shared = WatchSyncService()

    /// Wire key the payload is stored under — must match the Watch receiver.
    private static let payloadKey = "tickets"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Call once at launch so the session is alive before the first push.
    func start() { _ = WCSession.isSupported() }

    /// Encodes and pushes the given active tickets to the Watch. Safe to call
    /// repeatedly; no-ops when WatchConnectivity is unsupported.
    func sync(tickets: [WatchTicketSnapshot]) {
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(tickets.map(\.dto)) else { return }
        let payload = [Self.payloadKey: data]

        let session = WCSession.default
        // Latest-state-wins channel.
        if session.activationState == .activated {
            try? session.updateApplicationContext(payload)
        }
        // Queued guaranteed delivery for an asleep Watch.
        session.transferUserInfo(payload)
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to keep serving the (possibly switched) paired Watch.
        WCSession.default.activate()
    }
}

// MARK: - Snapshot

/// Sendable snapshot built on the MainActor from a `Ticket` before crossing into
/// the sync service. Mirrors the Watch's `TicketDTO` fields.
struct WatchTicketSnapshot: Sendable {
    let id: String
    let title: String
    let venue: String
    let eventTime: String
    let eventDate: Date?
    let barcodeValue: String
    let barcodeFormat: String
    let typeRaw: String
    let barcodeImageData: Data?

    init(ticket: Ticket) {
        self.id = ticket.id.uuidString
        self.title = ticket.title
        self.venue = ticket.venue
        self.eventTime = ticket.eventTime
        self.eventDate = ticket.eventDate
        self.barcodeValue = ticket.barcodeValue
        self.barcodeFormat = ticket.barcodeFormat
        self.typeRaw = ticket.ticketTypeRaw
        // Pre-render the barcode here on the phone; the Watch can't.
        self.barcodeImageData = WatchBarcodeRenderer.pngData(
            value: ticket.barcodeValue, format: ticket.barcodeFormat
        )
    }

    /// The Codable wire representation. Field-for-field identical to
    /// `PassoWatch/TicketDTO.swift`.
    fileprivate struct DTO: Codable {
        var id: String
        var title: String
        var venue: String
        var eventTime: String
        var eventDate: Date?
        var barcodeValue: String
        var barcodeFormat: String
        var typeRaw: String
        var barcodeImageData: Data?
    }

    fileprivate var dto: DTO {
        DTO(id: id, title: title, venue: venue, eventTime: eventTime,
            eventDate: eventDate, barcodeValue: barcodeValue,
            barcodeFormat: barcodeFormat, typeRaw: typeRaw,
            barcodeImageData: barcodeImageData)
    }
}

// MARK: - Barcode Renderer (iPhone side)

/// Renders a ticket barcode to PNG on the iPhone so the Watch — which has no
/// CoreImage — can display it directly. Mirrors the QR / Code128 handling in the
/// app's `BarcodeImageView`.
private enum WatchBarcodeRenderer {
    // CIContext is documented as thread-safe; the type just isn't marked Sendable.
    nonisolated(unsafe) private static let ciContext = CIContext()

    static func pngData(value: String, format: String) -> Data? {
        guard !value.isEmpty else { return nil }
        let message = Data(value.utf8)

        let output: CIImage?
        let scale: CGFloat
        if format == "QR" || format == "DataMatrix" || format == "Aztec" {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = message
            filter.correctionLevel = "M"
            output = filter.outputImage
            scale = 10
        } else {
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = message
            filter.quietSpace = 4
            output = filter.outputImage
            scale = 3
        }

        guard let ciImage = output else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage).pngData()
    }
}
