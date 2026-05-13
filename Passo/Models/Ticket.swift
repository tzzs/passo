import Foundation
import SwiftData

// MARK: - Ticket Model

@Model
final class Ticket {

    // Core identity
    var id: UUID
    var title: String
    var venue: String
    var ticketTypeRaw: String   // Persists TicketType.rawValue

    // Event timing
    var eventDate: Date?
    var eventTime: String       // "19:30" — display string from OCR
    var expiresAt: Date?

    // Seat / entry info
    var seatInfo: String        // e.g. "IMAX 4厅 · F排 7座"
    var extraField1Label: String
    var extraField1Value: String
    var extraField2Label: String
    var extraField2Value: String

    // Barcode
    var barcodeValue: String
    var barcodeFormat: String   // "QR", "Code128", "EAN13", etc.

    // Location for Wallet pass
    var latitude: Double?
    var longitude: Double?
    var venueAddress: String

    // Wallet integration
    var passSerialNumber: String?   // UUID assigned on Pass creation
    var isAddedToWallet: Bool

    // Metadata
    var notes: String
    var sourceApp: String           // "猫眼电影", "12306", "截图导入", etc.
    var importedAt: Date
    var isUsed: Bool
    var thumbnailData: Data?        // Cropped source image for card thumbnail

    // Reminder
    var reminderDate: Date?
    var reminderEnabled: Bool

    init(
        title: String = "",
        venue: String = "",
        ticketType: TicketType = .generic,
        eventDate: Date? = nil,
        eventTime: String = "",
        expiresAt: Date? = nil,
        seatInfo: String = "",
        extraField1Label: String = "",
        extraField1Value: String = "",
        extraField2Label: String = "",
        extraField2Value: String = "",
        barcodeValue: String = "",
        barcodeFormat: String = "QR",
        latitude: Double? = nil,
        longitude: Double? = nil,
        venueAddress: String = "",
        notes: String = "",
        sourceApp: String = ""
    ) {
        self.id                 = UUID()
        self.title              = title
        self.venue              = venue
        self.ticketTypeRaw      = ticketType.rawValue
        self.eventDate          = eventDate
        self.eventTime          = eventTime
        self.expiresAt          = expiresAt
        self.seatInfo           = seatInfo
        self.extraField1Label   = extraField1Label
        self.extraField1Value   = extraField1Value
        self.extraField2Label   = extraField2Label
        self.extraField2Value   = extraField2Value
        self.barcodeValue       = barcodeValue
        self.barcodeFormat      = barcodeFormat
        self.latitude           = latitude
        self.longitude          = longitude
        self.venueAddress       = venueAddress
        self.passSerialNumber   = nil
        self.isAddedToWallet    = false
        self.notes              = notes
        self.sourceApp          = sourceApp
        self.importedAt         = Date()
        self.isUsed             = false
        self.thumbnailData      = nil
        self.reminderDate       = nil
        self.reminderEnabled    = false
    }
}

// MARK: - Convenience

extension Ticket {
    var ticketType: TicketType {
        get { TicketType(rawValue: ticketTypeRaw) ?? .generic }
        set { ticketTypeRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }

    var isUpcoming: Bool {
        guard let date = eventDate else { return false }
        return date > Date() && !isUsed
    }

    var isToday: Bool {
        guard let date = eventDate else { return false }
        return Calendar.current.isDateInToday(date)
    }

    // Default expiry rules per ticket type (spec §4.4)
    static func defaultExpiry(for type: TicketType, eventDate: Date?) -> Date? {
        guard let base = eventDate else {
            return Calendar.current.date(byAdding: .day, value: 7, to: Date())
        }
        switch type {
        case .movie:   return Calendar.current.date(byAdding: .hour, value: 1, to: base)
        case .concert: return Calendar.current.date(byAdding: .minute, value: 30, to: base)
        case .train:   return base
        case .scenic:  return Calendar.current.date(byAdding: .hour, value: 8, to: base)
        case .member:  return nil
        case .generic: return Calendar.current.date(byAdding: .day, value: 7, to: base)
        }
    }
}
