import Foundation

// MARK: - Ticket Snapshot

/// Sendable value snapshot of a Ticket for crossing actor/concurrency boundaries.
struct TicketSnapshot: Sendable {
    let title: String
    let venue: String
    let ticketTypeRaw: String
    let eventDate: Date?
    let eventTime: String
    let expiresAt: Date?
    let seatInfo: String
    let extraField1Label: String
    let extraField1Value: String
    let extraField2Label: String
    let extraField2Value: String
    let routeOrigin: String
    let routeDestination: String
    let routeDuration: String
    let arrivalTime: String
    let memberLevel: String
    let memberPoints: String
    let admissionWindow: String
    let barcodeValue: String
    let barcodeFormat: String
    let latitude: Double?
    let longitude: Double?
    let venueAddress: String
    let passSerialNumber: String?
    let notes: String
    let sourceApp: String
    let tagsJSON: String

    init(ticket: Ticket) {
        title              = ticket.title
        venue              = ticket.venue
        ticketTypeRaw      = ticket.ticketTypeRaw
        eventDate          = ticket.eventDate
        eventTime          = ticket.eventTime
        expiresAt          = ticket.expiresAt
        seatInfo           = ticket.seatInfo
        extraField1Label   = ticket.extraField1Label
        extraField1Value   = ticket.extraField1Value
        extraField2Label   = ticket.extraField2Label
        extraField2Value   = ticket.extraField2Value
        routeOrigin        = ticket.routeOrigin
        routeDestination   = ticket.routeDestination
        routeDuration      = ticket.routeDuration
        arrivalTime        = ticket.arrivalTime
        memberLevel        = ticket.memberLevel
        memberPoints       = ticket.memberPoints
        admissionWindow    = ticket.admissionWindow
        barcodeValue       = ticket.barcodeValue
        barcodeFormat      = ticket.barcodeFormat
        latitude           = ticket.latitude
        longitude          = ticket.longitude
        venueAddress       = ticket.venueAddress
        passSerialNumber   = ticket.passSerialNumber
        notes              = ticket.notes
        sourceApp          = ticket.sourceApp
        tagsJSON           = ticket.tagsJSON
    }

    var ticketType: TicketType { TicketType(rawValue: ticketTypeRaw) ?? .generic }
}

// MARK: - Signing Error

enum SigningError: LocalizedError {
    case networkTimeout
    case serverError(Int)
    case invalidResponse
    case noSigningNodeConfigured
    case passJSONBuildFailed(Error)

    var errorDescription: String? {
        switch self {
        case .networkTimeout:            return "签名服务超时，请检查网络连接"
        case .serverError(let code):     return "签名服务器错误（\(code)）"
        case .invalidResponse:           return "签名响应格式无效"
        case .noSigningNodeConfigured:   return "未配置签名节点"
        case .passJSONBuildFailed(let e): return "Pass 构建失败：\(e.localizedDescription)"
        }
    }
}

// MARK: - Signing Service

/// Sends pass.json to a remote signing node and receives a signed .pkpass bundle.
/// Automatically retries on the alternate node if the primary times out.
actor SigningService {

    // Injected by SettingsView → @AppStorage("signingNodePreference")
    static let domesticEndpoint  = "https://sign.passo.cn/api/sign"
    static let overseasEndpoint  = "https://passo-sign.workers.dev/api/sign"

    // These should be filled via App provisioning / remote config in production.
    // For the MVP they can be left empty; the signing node uses its own certificate.
    static let teamIdentifier     = ""
    static let passTypeIdentifier = "pass.com.passo.ticket"

    // MARK: - Public API

    /// Build pass JSON, send to the preferred node, retry on the alternate if timeout.
    static func sign(snapshot: TicketSnapshot, nodePreference: NodePreference) async throws -> Data {
        let passJSON: Data
        do {
            passJSON = try PassBuilder.buildPassJSON(
                snapshot: snapshot,
                teamIdentifier: teamIdentifier,
                passTypeIdentifier: passTypeIdentifier
            )
        } catch {
            throw SigningError.passJSONBuildFailed(error)
        }

        let primary   = endpoint(for: nodePreference, primary: true)
        let secondary = endpoint(for: nodePreference, primary: false)

        do {
            return try await sendRequest(passJSON: passJSON, to: primary, timeout: 5)
        } catch SigningError.networkTimeout {
            return try await sendRequest(passJSON: passJSON, to: secondary, timeout: 8)
        }
    }

    // MARK: - Private

    private static func endpoint(for preference: NodePreference, primary: Bool) -> String {
        switch preference {
        case .domestic:  return primary ? domesticEndpoint  : overseasEndpoint
        case .overseas:  return primary ? overseasEndpoint  : domesticEndpoint
        case .auto:      return primary ? domesticEndpoint  : overseasEndpoint
        }
    }

    private static func sendRequest(passJSON: Data, to urlString: String, timeout: TimeInterval) async throws -> Data {
        guard let url = URL(string: urlString) else { throw SigningError.noSigningNodeConfigured }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")
        request.httpBody = passJSON

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw SigningError.networkTimeout
        } catch {
            throw SigningError.networkTimeout  // Treat all network errors as timeout for retry logic
        }

        guard let http = response as? HTTPURLResponse else { throw SigningError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SigningError.serverError(http.statusCode) }
        guard !data.isEmpty else { throw SigningError.invalidResponse }

        return data
    }
}

// MARK: - NodePreference (mirrors SettingsView definition)

// Defined here so SigningService doesn't import SwiftUI.
// The value is read from @AppStorage in the call site.
enum NodePreference: String, CaseIterable {
    case auto     = "auto"
    case domestic = "domestic"
    case overseas = "overseas"

    var displayName: String {
        switch self {
        case .auto:     return "自动"
        case .domestic: return "国内节点"
        case .overseas: return "海外节点 (Cloudflare)"
        }
    }
}
