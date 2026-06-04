import Foundation

/// Lightweight, Codable snapshot of a ticket transferred from the iPhone to the
/// Watch over WatchConnectivity.
///
/// The Watch is a separate physical device and cannot read the iPhone's
/// SwiftData / App Group store directly (App Group containers do not span
/// devices). So instead of pulling in the `@Model` `Ticket`, the Watch defines
/// its own SwiftData-free value type and the phone serialises into it.
///
/// This same shape is duplicated on the iOS side in
/// `Passo/Services/WatchSyncService.swift`. Keep the two in sync — they form the
/// wire contract between the devices. `typeRaw` carries `TicketType.rawValue`
/// so the Watch can rehydrate the shared `TicketType` (and its theme) without
/// depending on the SwiftData model.
struct TicketDTO: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var venue: String
    var eventTime: String
    var eventDate: Date?
    var barcodeValue: String
    var barcodeFormat: String
    var typeRaw: String
    /// Barcode pre-rendered to PNG on the iPhone. watchOS has no CoreImage to
    /// generate codes on-device, so the phone renders and ships the image.
    var barcodeImageData: Data? = nil

    var ticketType: TicketType { TicketType(rawValue: typeRaw) ?? .generic }
}
