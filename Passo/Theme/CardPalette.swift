import SwiftUI

// MARK: - Card Palette

/// A curated gradient palette for membership cards in the stacked 卡包.
///
/// Each card is assigned a palette *deterministically* from its title via
/// `palette(for:)`, so a given card always keeps the same color across app
/// launches while the stack as a whole stays colorful and easy to tell apart.
///
/// Mirrors the deep-background / light-accent style of `TicketTheme` so the
/// two systems feel like one design language.
struct CardPalette: Equatable {
    let backgroundStart: Color
    let backgroundEnd: Color
    let accent: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundStart, backgroundEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Curated hues spread around the wheel. Deep backgrounds keep white text
    /// and the barcode panel readable; accents drive the glow blob.
    static let all: [CardPalette] = [
        CardPalette(backgroundStart: Color(hex: "#003366"), backgroundEnd: Color(hex: "#005B99"), accent: Color(hex: "#00C9FF")), // 海蓝
        CardPalette(backgroundStart: Color(hex: "#1B4332"), backgroundEnd: Color(hex: "#2D6A4F"), accent: Color(hex: "#52B788")), // 翠绿
        CardPalette(backgroundStart: Color(hex: "#5A1B3A"), backgroundEnd: Color(hex: "#8A2D5C"), accent: Color(hex: "#FF6B9D")), // 玫红
        CardPalette(backgroundStart: Color(hex: "#2A1A4E"), backgroundEnd: Color(hex: "#3D2A6E"), accent: Color(hex: "#9D7BFF")), // 暗紫
        CardPalette(backgroundStart: Color(hex: "#4A2A11"), backgroundEnd: Color(hex: "#7A451A"), accent: Color(hex: "#FF9F45")), // 焦糖橙
        CardPalette(backgroundStart: Color(hex: "#0A3D3D"), backgroundEnd: Color(hex: "#14605E"), accent: Color(hex: "#4FD1C5")), // 深青
        CardPalette(backgroundStart: Color(hex: "#3E1118"), backgroundEnd: Color(hex: "#6E1F2B"), accent: Color(hex: "#FF6B6B")), // 酒红
        CardPalette(backgroundStart: Color(hex: "#1A2151"), backgroundEnd: Color(hex: "#2A3478"), accent: Color(hex: "#6C8CFF")), // 靛蓝
    ]

    /// The palette for a card. Same `key` (the card title) → same palette, always.
    static func palette(for key: String) -> CardPalette {
        let palettes = all
        guard !palettes.isEmpty else {
            return CardPalette(backgroundStart: Color(hex: "#1B4332"),
                               backgroundEnd: Color(hex: "#2D6A4F"),
                               accent: Color(hex: "#52B788"))
        }
        let index = stableIndex(for: key, upperBound: palettes.count)
        return palettes[index]
    }

    /// Map an arbitrary string to a stable index in `0..<upperBound`.
    ///
    /// Requirements:
    ///  - **Deterministic across launches.** Do NOT use `String.hashValue` —
    ///    Swift seeds it randomly per process, so colors would change on every
    ///    relaunch. Derive the value yourself from the string's bytes/scalars.
    ///  - Return a value in `0..<upperBound` (assume `upperBound > 0`).
    ///  - Spread reasonably evenly so similar names don't all collide.
    //
    // TODO(you): implement the deterministic hash. A few valid approaches:
    //   • Sum/fold `key.unicodeScalars` (e.g. accumulate `hash = hash &* 31 &+ scalar.value`)
    //   • FNV-1a over `key.utf8`
    // then take `% upperBound` (guard against negative with `&` math on unsigned).
    static func stableIndex(for key: String, upperBound: Int) -> Int {
        // djb2-style accumulation over Unicode scalars. `&*` / `&+` are
        // overflow operators — hash accumulation always overflows, and unlike
        // `*`/`+` these wrap instead of trapping. Deterministic across launches.
        var hash: UInt64 = 5381
        for scalar in key.unicodeScalars {
            hash = hash &* 31 &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(upperBound))
    }
}
