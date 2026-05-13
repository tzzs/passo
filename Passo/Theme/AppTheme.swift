import SwiftUI

// MARK: - Ticket Type

enum TicketType: String, CaseIterable, Codable {
    case movie   = "movie"
    case concert = "concert"
    case train   = "train"
    case member  = "member"
    case scenic  = "scenic"
    case generic = "generic"

    var displayName: String {
        switch self {
        case .movie:   return "电影"
        case .concert: return "演出"
        case .train:   return "高铁"
        case .member:  return "会员"
        case .scenic:  return "景点"
        case .generic: return "通用"
        }
    }

    var emoji: String {
        switch self {
        case .movie:   return "🎬"
        case .concert: return "🎤"
        case .train:   return "🚄"
        case .member:  return "💳"
        case .scenic:  return "🏛"
        case .generic: return "🎫"
        }
    }

    var theme: TicketTheme { TicketTheme(type: self) }
}

// MARK: - Ticket Theme

/// Per-type color system, mirrors PASSO_THEMES in the design prototype.
struct TicketTheme {
    let backgroundStart: Color
    let backgroundEnd: Color
    let accent: Color
    let accentSecondary: Color

    init(type: TicketType) {
        switch type {
        case .movie:
            backgroundStart = Color(hex: "#1A1A2E")
            backgroundEnd   = Color(hex: "#16213E")
            accent          = Color(hex: "#E94560")
            accentSecondary = Color(hex: "#C73A52")
        case .concert:
            backgroundStart = Color(hex: "#0D0221")
            backgroundEnd   = Color(hex: "#190341")
            accent          = Color(hex: "#FF6B6B")
            accentSecondary = Color(hex: "#FFE66D")
        case .train:
            backgroundStart = Color(hex: "#003366")
            backgroundEnd   = Color(hex: "#005B99")
            accent          = Color(hex: "#00C9FF")
            accentSecondary = Color(hex: "#0090CC")
        case .member:
            backgroundStart = Color(hex: "#1B4332")
            backgroundEnd   = Color(hex: "#2D6A4F")
            accent          = Color(hex: "#52B788")
            accentSecondary = Color(hex: "#3D9E6E")
        case .scenic:
            backgroundStart = Color(hex: "#2D4A1E")
            backgroundEnd   = Color(hex: "#4A7C59")
            accent          = Color(hex: "#A8D5A2")
            accentSecondary = Color(hex: "#7ABF6E")
        case .generic:
            backgroundStart = Color(hex: "#2C2C2E")
            backgroundEnd   = Color(hex: "#3A3A3C")
            accent          = Color(hex: "#8E8E93")
            accentSecondary = Color(hex: "#636366")
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundStart, backgroundEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Design Tokens

enum AppSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32

    // Corner radii per HIG spec
    static let radiusCard:   CGFloat = 16
    static let radiusButton: CGFloat = 12
    static let radiusTag:    CGFloat = 8
}

enum AppAnimation {
    static let themeChange  = Animation.easeOut(duration: 0.4)
    static let cardFlip     = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let cardAppear   = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let scanPulse    = Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
