import SwiftUI

// MARK: - Card Size

enum TicketCardSize {
    case full       // Full card with barcode
    case compact    // Compact preview without barcode
}

// MARK: - Ticket Card View

/// Primary glassmorphism ticket card. Maps to PassoTicketCard in the design prototype.
/// Card aspect ratio ~1.6:1, full width of container.
struct TicketCardView: View {
    let ticket: Ticket
    let size: TicketCardSize
    let isDark: Bool

    private var theme: TicketTheme { ticket.ticketType.theme }

    var body: some View {
        GlassCardView(isDark: isDark, glowColor: ticket.isUsed ? nil : theme.accent) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                if size == .full {
                    cardInfoGrid
                    perforationDivider
                    barcodeSection
                } else {
                    compactInfo
                }
            }
        }
        .opacity(ticket.isUsed ? 0.5 : 1)
    }

    // MARK: Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                TicketTypeBadge(type: ticket.ticketType)
                    .opacity(ticket.isUsed ? 0.7 : 1)
                if ticket.isUsed {
                    Text("· 已使用")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if !ticket.isUsed, let countdown = countdownText {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("倒计时")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(countdown)
                            .font(.system(size: size == .compact ? 13 : 20, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ticket.title.isEmpty ? "未命名票据" : ticket.title)
                    .font(.system(size: size == .compact ? 18 : 24, weight: .bold))
                    .foregroundStyle(isDark ? .white : .black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !ticket.venue.isEmpty {
                    Text(ticket.venue)
                        .font(.system(size: 13))
                        .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
                        .lineLimit(1)
                }
            }
        }
        .padding(size == .compact ? 12 : 16)
    }

    // MARK: Info Grid (full only)

    private var cardInfoGrid: some View {
        HStack(spacing: 20) {
            if !ticket.eventTime.isEmpty {
                infoColumn(label: "时间", value: ticket.eventTime)
            }
            if !ticket.extraField1Value.isEmpty {
                infoColumn(label: ticket.extraField1Label, value: ticket.extraField1Value)
            }
            if !ticket.extraField2Value.isEmpty {
                infoColumn(label: ticket.extraField2Label, value: ticket.extraField2Value)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func infoColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isDark ? .white : .black)
        }
    }

    // MARK: Compact Info

    private var compactInfo: some View {
        HStack(spacing: 12) {
            if !ticket.eventTime.isEmpty {
                Text(ticket.eventTime)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .black)
            }
            if !ticket.extraField1Value.isEmpty {
                Text("\(ticket.extraField1Label) \(ticket.extraField1Value) · \(ticket.extraField2Label) \(ticket.extraField2Value)")
                    .font(.system(size: 13))
                    .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: Perforation

    private var perforationDivider: some View {
        HStack(spacing: 0) {
            // Left notch
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 12, height: 12)
                .offset(x: -6)

            // Dashed line
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 6))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 6))
                }
                .stroke(
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])
                )
                .foregroundStyle(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
            }
            .frame(height: 12)

            // Right notch
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 12, height: 12)
                .offset(x: 6)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Barcode

    private var barcodeSection: some View {
        VStack(spacing: 6) {
            QRCodePlaceholderView(
                value: ticket.barcodeValue,
                size: ticket.isUsed ? 72 : 90,
                color: ticket.isUsed ? Color.gray.opacity(0.5) : .black
            )
            if !ticket.isUsed {
                Text(ticket.barcodeValue.isEmpty ? "0000 0000 0000 0000" : formatBarcode(ticket.barcodeValue))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
                    .kerning(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(ticket.isUsed ? Color.white.opacity(0.7) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: Helpers

    private var countdownText: String? {
        guard let date = ticket.eventDate else { return nil }
        let diff = date.timeIntervalSinceNow
        if diff <= 0 { return nil }
        if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)m"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            let mins  = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        } else {
            let days = Int(diff / 86400)
            return "\(days)天"
        }
    }

    private func formatBarcode(_ value: String) -> String {
        // Group digits in sets of 4 for display
        let digits = value.prefix(16)
        return stride(from: 0, to: digits.count, by: 4)
            .map { i -> String in
                let start = digits.index(digits.startIndex, offsetBy: i)
                let end   = digits.index(start, offsetBy: min(4, digits.count - i))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }
}

// MARK: - QR Code Placeholder

/// Deterministic QR-code-like grid placeholder.
/// Production implementation will use Vision framework output.
struct QRCodePlaceholderView: View {
    let value: String
    let size: CGFloat
    let color: Color

    private let gridSize = 21

    var body: some View {
        Canvas { context, canvasSize in
            let cell = canvasSize.width / CGFloat(gridSize)
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    if shouldFill(row: row, col: col) {
                        let rect = CGRect(
                            x: CGFloat(col) * cell,
                            y: CGFloat(row) * cell,
                            width: cell + 0.5,
                            height: cell + 0.5
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func shouldFill(row: Int, col: Int) -> Bool {
        // Finder patterns (top-left, top-right, bottom-left)
        if isFinderPattern(row: row, col: col) { return true }
        // Timing pattern
        if row == 6 && col >= 8 && col <= gridSize - 9 { return col % 2 == 0 }
        if col == 6 && row >= 8 && row <= gridSize - 9 { return row % 2 == 0 }
        // Data modules: deterministic hash of value + position
        let seed = value.unicodeScalars.reduce(42) { $0 &+ Int($1.value) }
        return ((row &* gridSize &+ col &* 1103515245 &+ seed) >> 16) & 1 == 1
    }

    private func isFinderPattern(row: Int, col: Int) -> Bool {
        let corners = [(0, 0), (0, gridSize - 7), (gridSize - 7, 0)]
        for (tr, tc) in corners {
            let lr = row - tr, lc = col - tc
            guard lr >= 0 && lr < 7 && lc >= 0 && lc < 7 else { continue }
            if lr == 0 || lr == 6 || lc == 0 || lc == 6 { return true }
            if lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4 { return true }
            return false
        }
        return false
    }
}
