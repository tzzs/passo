import Foundation
import ImageIO
import Vision
import UIKit

// MARK: - Ticket Parser

/// Classifies a barcode + OCR text into a Ticket with best-effort field extraction.
/// All parsing is local, deterministic, and never throws — worst case returns a .generic ticket.
enum TicketParser {

    struct ImageAnalysisResult {
        let barcodeValue: String
        let barcodeFormat: String
        let ocrText: String

        var hasRecognizedContent: Bool {
            !barcodeValue.isEmpty || !ocrText.isEmpty
        }
    }

    // MARK: - Main Entry Point

    static func parse(barcodeValue: String, ocrText: String) -> Ticket {
        let combined = "\(barcodeValue) \(ocrText)"
        let type = classifyType(from: combined)

        var ticket = Ticket(
            ticketType: type,
            barcodeValue: barcodeValue,
            barcodeFormat: "QR"
        )

        extractFields(from: ocrText, into: &ticket, type: type)
        // F5: fill expiresAt using default rules so views display it correctly from the start
        if ticket.expiresAt == nil {
            ticket.expiresAt = Ticket.defaultExpiry(for: type, eventDate: ticket.eventDate)
        }
        return ticket
    }

    // MARK: - OCR Request

    /// Run Vision OCR on a UIImage and return concatenated text lines.
    static func runOCR(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                // Keep line breaks: extractTitle() relies on per-line splitting.
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: cgImagePropertyOrientation(from: image.imageOrientation),
                options: [:]
            )
            try? handler.perform([request])
        }
    }

    /// Run barcode detection and OCR on a still image.
    /// Uses the UIImage orientation so rotated screenshots/photos are analyzed correctly.
    static func analyzeImage(
        _ image: UIImage,
        textRecognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) throws -> ImageAnalysisResult {
        guard let cgImage = image.cgImage else {
            return ImageAnalysisResult(barcodeValue: "", barcodeFormat: "QR", ocrText: "")
        }

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImagePropertyOrientation(from: image.imageOrientation),
            options: [:]
        )

        let barcodeReq = VNDetectBarcodesRequest()
        barcodeReq.symbologies = supportedBarcodeSymbologies

        let ocrReq = VNRecognizeTextRequest()
        ocrReq.recognitionLevel = textRecognitionLevel
        ocrReq.recognitionLanguages = ["zh-Hans", "en-US"]
        ocrReq.usesLanguageCorrection = usesLanguageCorrection

        try handler.perform([barcodeReq, ocrReq])

        let barcode = barcodeReq.results?.first
        let barcodeValue = barcode?.payloadStringValue ?? ""
        // Keep line breaks: extractTitle() relies on per-line splitting.
        let ocrText = (ocrReq.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        return ImageAnalysisResult(
            barcodeValue: barcodeValue,
            barcodeFormat: barcodeFormatString(for: barcode?.symbology),
            ocrText: ocrText
        )
    }

    static func barcodeFormatString(for symbology: VNBarcodeSymbology?) -> String {
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

    private static var supportedBarcodeSymbologies: [VNBarcodeSymbology] {
        [.qr, .dataMatrix, .aztec, .code128, .ean13, .itf14, .code39]
    }

    private static func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
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

    // MARK: - Type Classification

    private static func classifyType(from text: String) -> TicketType {
        let lower = text.lowercased()

        // URL-based signals (highest confidence)
        if lower.contains("maoyan.com") || lower.contains("taopiaopiao.com")
            || lower.contains("movies") { return .movie }
        if lower.contains("damai.cn") || lower.contains("showstart.com") { return .concert }
        if lower.contains("12306") || lower.contains("rail") { return .train }

        // Keyword-based signals
        if containsAny(lower, ["影厅", "imax", "场次", "放映", "影院", "电影"]) { return .movie }
        if containsAny(lower, ["演唱会", "音乐节", "演出", "大麦", "场馆", "入场券", "concert"]) { return .concert }
        if containsAny(lower, ["车次", "高铁", "动车", "座位号", "检票口", "g1", "g2", "g3", "d1", "d2"]) { return .train }
        if containsAny(lower, ["会员", "积分", "储值", "金卡", "gold", "silver", "钻石", "membership"]) { return .member }
        if containsAny(lower, ["景区", "游览", "博物院", "博物馆", "故宫", "公园", "风景区"]) { return .scenic }

        return .generic
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    // MARK: - Field Extraction

    private static func extractFields(from text: String, into ticket: inout Ticket, type: TicketType) {
        ticket.title    = extractTitle(from: text, type: type)
        ticket.venue    = extractVenue(from: text, type: type)
        ticket.eventTime = extractTime(from: text)
        ticket.eventDate = parseEventDate(from: text)
        ticket.seatInfo  = extractSeatInfo(from: text, type: type)

        switch type {
        case .train:
            let route = extractTrainRoute(from: text)
            ticket.routeOrigin      = route.origin
            ticket.routeDestination = route.destination
            ticket.routeDuration    = route.duration
            ticket.arrivalTime      = route.arrival
            ticket.extraField1Label = "车厢"
            ticket.extraField1Value = extractPattern(#"(\d+)车"#, in: text) ?? ""
            ticket.extraField2Label = "座位"
            ticket.extraField2Value = extractPattern(#"(\d+[A-F])"#, in: text) ?? ""

        case .movie:
            ticket.extraField1Label = "影厅"
            ticket.extraField1Value = extractPattern(#"(IMAX\s*\d+|[\d]+厅|[A-Z]厅)"#, in: text) ?? ""
            ticket.extraField2Label = "座位"
            ticket.extraField2Value = extractPattern(#"([A-Z]\s*排?\s*[\d]+\s*座?)"#, in: text) ?? ""

        case .concert:
            ticket.extraField1Label = "区域"
            ticket.extraField1Value = extractPattern(#"([A-Z]区|内场|看台\s*\d*)"#, in: text) ?? ""
            ticket.extraField2Label = "座位"
            ticket.extraField2Value = extractPattern(#"(\d+排\s*\d+号)"#, in: text) ?? ""

        case .member:
            ticket.memberLevel  = extractPattern(#"(★?\s*(?:Gold|Silver|Diamond|金|银|钻石)[卡级]?)"#, in: text) ?? ""
            ticket.memberPoints = extractPattern(#"积分[：:]\s*([\d,，]+)"#, in: text) ?? ""
            ticket.extraField1Label = "积分"
            ticket.extraField1Value = ticket.memberPoints
            ticket.extraField2Label = "等级"
            ticket.extraField2Value = ticket.memberLevel

        case .scenic:
            ticket.admissionWindow = extractAdmissionWindow(from: text)
            ticket.extraField1Label = "类型"
            ticket.extraField1Value = containsAny(text, ["儿童", "小孩"]) ? "儿童票" :
                                      containsAny(text, ["老人", "老年"]) ? "老年票" : "成人票"
            ticket.extraField2Label = "数量"
            ticket.extraField2Value = extractPattern(#"×?\s*(\d+)\s*张"#, in: text).map { "×\($0)" } ?? "×1"

        case .generic:
            ticket.extraField1Label = "类型"
            ticket.extraField1Value = extractPattern(#"(VIP|普通|标准|特邀)"#, in: text) ?? ""
            ticket.extraField2Label = "编号"
            ticket.extraField2Value = extractPattern(#"(?:编号|NO\.?)[：:\s]*([\w-]+)"#, in: text) ?? ""
        }
    }

    // MARK: - Field Helpers

    private static func extractTitle(from text: String, type: TicketType) -> String {
        let lines = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 1 }

        // Skip lines that look like order numbers, dates, or purely numeric/short strings
        let orderPattern = try? NSRegularExpression(pattern: #"^[\d\s\-/.:TZ]{4,}$|^[A-Z]{0,3}\d{8,}$|订单号|Order"#)
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if orderPattern?.firstMatch(in: line, range: range) != nil { continue }
            if line.count < 2 { continue }
            return line
        }
        return type.displayName
    }

    private static func extractVenue(from text: String, type: TicketType) -> String {
        if let match = extractPattern(#"([一-龥]{2,}(?:影城|剧院|体育场|中心|场馆|博物馆|景区|站|影院))"#, in: text) {
            return match
        }
        return ""
    }

    private static func extractTime(from text: String) -> String {
        // Match HH:mm or H:mm
        return extractPattern(#"(\d{1,2}:\d{2})(?::\d{2})?"#, in: text) ?? ""
    }

    private static func parseEventDate(from text: String) -> Date? {
        // Match yyyy-MM-dd, yyyy.MM.dd, yyyy年MM月dd日, MM-dd, MM月dd日
        let patterns: [(String, String)] = [
            (#"(\d{4})[-./年](\d{1,2})[-./月](\d{1,2})"#, "yyyy-MM-dd"),
            (#"(\d{1,2})[-./月](\d{1,2})[日号]?"#,         "MM-dd"),
        ]
        let cal = Calendar.current
        for (pattern, _) in patterns {
            guard
                let regex = try? NSRegularExpression(pattern: pattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
            else { continue }

            if match.numberOfRanges >= 4,
               let y = rangeString(match, 1, in: text),
               let m = rangeString(match, 2, in: text),
               let d = rangeString(match, 3, in: text),
               let year = Int(y), let month = Int(m), let day = Int(d) {
                var comps = DateComponents()
                comps.year = year; comps.month = month; comps.day = day
                return cal.date(from: comps)
            } else if match.numberOfRanges >= 3,
                      let m = rangeString(match, 1, in: text),
                      let d = rangeString(match, 2, in: text),
                      let month = Int(m), let day = Int(d) {
                var comps = cal.dateComponents([.year], from: Date())
                comps.month = month; comps.day = day
                guard let candidate = cal.date(from: comps) else { continue }
                // If the date is more than 30 days in the past, assume the event is next year
                // (handles Dec purchase of Jan tickets, etc.)
                let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                if candidate < thirtyDaysAgo {
                    comps.year = (comps.year ?? cal.component(.year, from: Date())) + 1
                    return cal.date(from: comps)
                }
                return candidate
            }
        }
        return nil
    }

    private static func extractSeatInfo(from text: String, type: TicketType) -> String {
        switch type {
        case .train:
            let car  = extractPattern(#"(\d+车)"#, in: text) ?? ""
            let seat = extractPattern(#"(\d+[A-F]座?)"#, in: text) ?? ""
            return [car, seat].filter { !$0.isEmpty }.joined(separator: " · ")
        case .movie, .concert:
            return extractPattern(#"([A-Z]\s*排?\s*\d+\s*[号座]?)"#, in: text) ?? ""
        default:
            return ""
        }
    }

    private static func extractTrainRoute(from text: String) -> (origin: String, destination: String, duration: String, arrival: String) {
        let origin      = extractPattern(#"([一-龥]{2,}(?:站|南|北|东|西)?)(?=.*?→|.*?至)"#, in: text) ?? ""
        let destination = extractPattern(#"(?:→|至)\s*([一-龥]{2,}(?:站|南|北|东|西)?)"#, in: text) ?? ""
        let duration    = extractPattern(#"(\d+h\s*\d+m|\d+小时\d+分)"#, in: text) ?? ""
        let times       = extractAllTimes(from: text)
        let arrival     = times.count >= 2 ? times[1] : ""
        return (origin, destination, duration, arrival)
    }

    private static func extractAdmissionWindow(from text: String) -> String {
        return extractPattern(#"(\d{1,2}:\d{2}\s*[-–~至]\s*\d{1,2}:\d{2})"#, in: text) ?? ""
    }

    // MARK: - Regex Utilities

    private static func extractPattern(_ pattern: String, in text: String) -> String? {
        guard
            // dotMatchesLineSeparators so `.*?` lookaheads still span the now
            // newline-joined OCR text (e.g. train route origin → destination).
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges >= 2
        else { return nil }
        return rangeString(match, 1, in: text)
    }

    private static func extractAllTimes(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\d{1,2}:\d{2}"#) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func rangeString(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard
            index < match.numberOfRanges,
            let range = Range(match.range(at: index), in: text)
        else { return nil }
        return String(text[range])
    }
}
