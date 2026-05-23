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

    // Train-specific route (structurally different layout on card)
    var routeOrigin: String      // "北京南"
    var routeDestination: String // "上海虹桥"
    var routeDuration: String    // "4h 28m"
    var arrivalTime: String      // "13:10"

    // Member-specific
    var memberLevel: String      // "★ Gold"
    var memberPoints: String     // "2,560"

    // Scenic: timed admission window
    var admissionWindow: String  // "09:00 - 12:00"

    // Tags / badges (JSON array of strings, e.g. VIP通道, 含停车, 生日免费)
    var tagsJSON: String         // encoded as "["VIP通道","含停车"]"

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
        sourceApp: String = "",
        routeOrigin: String = "",
        routeDestination: String = "",
        routeDuration: String = "",
        arrivalTime: String = "",
        memberLevel: String = "",
        memberPoints: String = "",
        admissionWindow: String = "",
        tags: [String] = []
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
        self.routeOrigin        = routeOrigin
        self.routeDestination   = routeDestination
        self.routeDuration      = routeDuration
        self.arrivalTime        = arrivalTime
        self.memberLevel        = memberLevel
        self.memberPoints       = memberPoints
        self.admissionWindow    = admissionWindow
        self.tagsJSON           = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

// MARK: - Convenience

extension Ticket {
    var tags: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))) ?? []
        }
        set {
            tagsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
    }

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

    // MARK: Preview fixtures (one per ticket type)

    static func preview(_ type: TicketType) -> Ticket {
        let cal = Calendar.current
        let soon: (Int, Int) -> Date = { h, m in
            cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
        }
        switch type {
        case .movie:
            return Ticket(
                title: "奥本海默", venue: "万达影城 · 来福士店",
                ticketType: .movie,
                eventDate: soon(19, 30), eventTime: "19:30",
                extraField1Label: "影厅", extraField1Value: "IMAX 4",
                extraField2Label: "座位", extraField2Value: "F · 7",
                barcodeValue: "89012345678901234",
                sourceApp: "猫眼电影"
            )
        case .concert:
            return Ticket(
                title: "时代巡回演唱会", venue: "梅赛德斯·奔驰中心",
                ticketType: .concert,
                eventDate: cal.date(byAdding: .day, value: 3, to: soon(20, 0)),
                eventTime: "20:00",
                extraField1Label: "区域", extraField1Value: "A区",
                extraField2Label: "座位", extraField2Value: "12排 8号",
                barcodeValue: "76543210987654321",
                sourceApp: "大麦",
                tags: ["VIP 通道", "含停车"]
            )
        case .train:
            return Ticket(
                title: "G1234", venue: "北京南 → 上海虹桥",
                ticketType: .train,
                eventDate: cal.date(byAdding: .day, value: 2, to: soon(8, 42)),
                eventTime: "08:42",
                extraField1Label: "车厢", extraField1Value: "7车",
                extraField2Label: "座位", extraField2Value: "12A",
                barcodeValue: "11223344556677889",
                sourceApp: "12306",
                routeOrigin: "北京南", routeDestination: "上海虹桥",
                routeDuration: "4h 28m", arrivalTime: "13:10"
            )
        case .member:
            return Ticket(
                title: "星巴克金卡", venue: "有效期至 2025.12.31",
                ticketType: .member,
                eventDate: nil, eventTime: "",
                extraField1Label: "积分", extraField1Value: "2,560",
                extraField2Label: "星星", extraField2Value: "256",
                barcodeValue: "99887766554433221",
                sourceApp: "星巴克",
                memberLevel: "★ Gold", memberPoints: "2,560",
                tags: ["生日免费", "买一送一 ×3", "升杯券 ×2"]
            )
        case .scenic:
            return Ticket(
                title: "故宫博物院", venue: "午门入口",
                ticketType: .scenic,
                eventDate: cal.date(byAdding: .day, value: 5, to: soon(9, 0)),
                eventTime: "09:00",
                extraField1Label: "类型", extraField1Value: "成人票",
                extraField2Label: "数量", extraField2Value: "×2",
                barcodeValue: "55443322110099887",
                sourceApp: "故宫门票",
                admissionWindow: "09:00 - 12:00"
            )
        case .generic:
            return Ticket(
                title: "TechCrunch Disrupt", venue: "上海世博展览馆",
                ticketType: .generic,
                eventDate: cal.date(byAdding: .day, value: 7, to: soon(10, 0)),
                eventTime: "10:00",
                extraField1Label: "类型", extraField1Value: "VIP",
                extraField2Label: "编号", extraField2Value: "B-42",
                barcodeValue: "12398765412398765",
                notes: "📝 凭此码 + 身份证入场",
                sourceApp: "官网"
            )
        }
    }
}
