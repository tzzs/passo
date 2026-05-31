import Foundation

// MARK: - Pass Builder

/// Builds a PassKit-compliant pass.json dictionary from a Ticket.
/// The resulting JSON is sent to the signing node; the server appends
/// icon/logo assets and returns a signed .pkpass bundle.
enum PassBuilder {

    // MARK: - Public API

    static func buildPassJSON(snapshot: TicketSnapshot, teamIdentifier: String, passTypeIdentifier: String) throws -> Data {
        let dict = buildDictionary(snapshot: snapshot, teamIdentifier: teamIdentifier, passTypeIdentifier: passTypeIdentifier)
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Dictionary Assembly

    private static func buildDictionary(snapshot: TicketSnapshot, teamIdentifier: String, passTypeIdentifier: String) -> [String: Any] {
        var pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": passTypeIdentifier,
            "serialNumber": snapshot.passSerialNumber ?? UUID().uuidString,
            "teamIdentifier": teamIdentifier,
            "organizationName": "Passo",
            "description": snapshot.title.isEmpty ? "票据" : snapshot.title,
        ]

        // Barcode: emit only when we actually have a value (an empty `message`
        // is rejected by PassKit). `barcodes` (iOS 9+) is an array; `barcode`
        // (legacy, iOS 8) must be a *single* dictionary — not the array.
        if !snapshot.barcodeValue.isEmpty {
            let barcode: [String: Any] = [
                "message": snapshot.barcodeValue,
                "format": pkBarcodeFormat(snapshot.barcodeFormat),
                "messageEncoding": "iso-8859-1"
            ]
            pass["barcodes"] = [barcode]
            pass["barcode"]  = barcode
        }

        if let date = snapshot.eventDate {
            pass["relevantDate"] = ISO8601DateFormatter().string(from: date)
            pass["expirationDate"] = ISO8601DateFormatter().string(
                from: snapshot.expiresAt ?? Ticket.defaultExpiry(for: snapshot.ticketType, eventDate: date) ?? date
            )
        }

        if let lat = snapshot.latitude, let lon = snapshot.longitude {
            pass["locations"] = [[
                "latitude": lat,
                "longitude": lon,
                "relevantText": snapshot.venue
            ]]
            pass["maxDistance"] = 500
        }

        // Per-type colors so the signed pass matches the in-app card theme.
        let colors = passColors(for: snapshot.ticketType)
        pass["backgroundColor"] = colors.background
        pass["foregroundColor"] = colors.foreground
        pass["labelColor"]      = colors.label

        let style = passStyle(for: snapshot.ticketType)
        var fields = buildFields(for: snapshot)
        // `transitType` is required by — and only valid inside — a boardingPass.
        if style == "boardingPass" {
            fields["transitType"] = transitType(for: snapshot.ticketType)
        }
        pass[style] = fields

        return pass
    }

    // MARK: - Fields per Ticket Type

    private static func buildFields(for s: TicketSnapshot) -> [String: Any] {
        var fields: [String: Any] = [:]

        fields["primaryFields"] = [[
            "key": "title",
            "label": "",
            "value": s.title.isEmpty ? "票据" : s.title
        ]]

        var secondary: [[String: Any]] = []
        if !s.venue.isEmpty     { secondary.append(["key": "venue", "label": "场馆", "value": s.venue]) }
        if !s.eventTime.isEmpty { secondary.append(["key": "time",  "label": "时间", "value": s.eventTime]) }
        fields["secondaryFields"] = secondary

        fields["auxiliaryFields"] = buildAuxiliary(for: s)

        var back: [[String: Any]] = []
        if !s.notes.isEmpty        { back.append(["key": "notes",   "label": "备注",   "value": s.notes]) }
        if !s.barcodeValue.isEmpty { back.append(["key": "barcode", "label": "条码原文", "value": s.barcodeValue]) }
        if !s.sourceApp.isEmpty    { back.append(["key": "source",  "label": "来源",   "value": s.sourceApp]) }
        fields["backFields"] = back

        return fields
    }

    private static func buildAuxiliary(for s: TicketSnapshot) -> [[String: Any]] {
        var aux: [[String: Any]] = []

        switch s.ticketType {
        case .train:
            if !s.routeOrigin.isEmpty      { aux.append(["key": "origin",      "label": "出发", "value": s.routeOrigin]) }
            if !s.routeDestination.isEmpty { aux.append(["key": "destination", "label": "到达", "value": s.routeDestination]) }
            if !s.routeDuration.isEmpty    { aux.append(["key": "duration",    "label": "历时", "value": s.routeDuration]) }

        case .member:
            if !s.memberLevel.isEmpty  { aux.append(["key": "level",  "label": "等级", "value": s.memberLevel]) }
            if !s.memberPoints.isEmpty { aux.append(["key": "points", "label": "积分", "value": s.memberPoints]) }

        case .scenic:
            if !s.admissionWindow.isEmpty { aux.append(["key": "window", "label": "入场时段", "value": s.admissionWindow]) }
            fallthrough

        default:
            if !s.extraField1Value.isEmpty { aux.append(["key": "field1", "label": s.extraField1Label, "value": s.extraField1Value]) }
            if !s.extraField2Value.isEmpty { aux.append(["key": "field2", "label": s.extraField2Label, "value": s.extraField2Value]) }
        }

        return aux
    }

    // MARK: - PassKit Format Mapping

    private static func passStyle(for type: TicketType) -> String {
        switch type {
        case .train:             return "boardingPass"
        case .member:            return "storeCard"
        case .movie, .concert, .scenic, .generic: return "eventTicket"
        }
    }

    private static func transitType(for type: TicketType) -> String {
        switch type {
        case .train: return "PKTransitTypeTrain"
        default:     return "PKTransitTypeGeneric"
        }
    }

    /// PassKit color triplet per ticket type, mirroring `TicketTheme`
    /// (`backgroundStart` → background, `accent` → label) so the signed pass
    /// looks consistent with the in-app card. Foreground stays white because
    /// every theme background is dark. Values are `rgb(r, g, b)` strings as
    /// required by the pass.json spec.
    private static func passColors(for type: TicketType) -> (background: String, foreground: String, label: String) {
        let foreground = "rgb(255, 255, 255)"
        switch type {
        case .movie:   return ("rgb(26, 26, 46)",  foreground, "rgb(233, 69, 96)")
        case .concert: return ("rgb(13, 2, 33)",   foreground, "rgb(255, 107, 107)")
        case .train:   return ("rgb(0, 51, 102)",  foreground, "rgb(0, 201, 255)")
        case .member:  return ("rgb(27, 67, 50)",  foreground, "rgb(82, 183, 136)")
        case .scenic:  return ("rgb(45, 74, 30)",  foreground, "rgb(168, 213, 162)")
        case .generic: return ("rgb(44, 44, 46)",  foreground, "rgb(142, 142, 147)")
        }
    }

    private static func pkBarcodeFormat(_ format: String) -> String {
        switch format.uppercased() {
        case "QR":         return "PKBarcodeFormatQR"
        case "CODE128":    return "PKBarcodeFormatCode128"
        case "EAN13":      return "PKBarcodeFormatEAN13"
        case "EAN8":       return "PKBarcodeFormatEAN8"
        case "DATAMATRIX": return "PKBarcodeFormatQR"  // fallback
        default:           return "PKBarcodeFormatQR"
        }
    }
}
