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

    // MARK: Type-specific Info Section (full only)

    @ViewBuilder
    private var cardInfoGrid: some View {
        switch ticket.ticketType {
        case .train:   trainRouteInfo
        case .member:  memberInfo
        case .scenic:  scenicInfo
        case .concert: concertInfo
        default:       defaultInfoGrid
        }
    }

    // ── Movie / Generic: standard 3-column grid ──────────────────────────

    private var defaultInfoGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            // Generic note banner
            if ticket.ticketType == .generic, !ticket.notes.isEmpty {
                noteBanner(ticket.notes)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // ── Concert: fields + tag chips ──────────────────────────────────────

    private var concertInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                if !ticket.extraField1Value.isEmpty {
                    infoColumn(label: ticket.extraField1Label, value: ticket.extraField1Value)
                }
                if !ticket.extraField2Value.isEmpty {
                    infoColumn(label: ticket.extraField2Label, value: ticket.extraField2Value)
                }
                if !ticket.eventTime.isEmpty {
                    infoColumn(label: "时间", value: ticket.eventTime)
                }
            }
            if !ticket.tags.isEmpty {
                tagChips(ticket.tags)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // ── Train: horizontal route layout (origin → destination + duration) ─

    private var trainRouteInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                // Departure
                VStack(alignment: .center, spacing: 2) {
                    Text(ticket.routeOrigin.isEmpty ? "出发地" : ticket.routeOrigin)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .black)
                    Text(ticket.eventTime)
                        .font(.system(size: 11))
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .black.opacity(0.4))
                }
                // Duration line
                VStack(spacing: 4) {
                    Text(ticket.routeDuration)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(theme.accent.opacity(0.5))
                            .frame(height: 1.5)
                            .frame(maxWidth: .infinity)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                // Arrival
                VStack(alignment: .center, spacing: 2) {
                    Text(ticket.routeDestination.isEmpty ? "目的地" : ticket.routeDestination)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .black)
                    Text(ticket.arrivalTime)
                        .font(.system(size: 11))
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .black.opacity(0.4))
                }
            }
            // Car / seat / class
            HStack(spacing: 20) {
                if !ticket.extraField1Value.isEmpty {
                    infoColumn(label: ticket.extraField1Label, value: ticket.extraField1Value)
                }
                if !ticket.extraField2Value.isEmpty {
                    infoColumn(label: ticket.extraField2Label, value: ticket.extraField2Value)
                }
                if !ticket.seatInfo.isEmpty {
                    infoColumn(label: "类型", value: ticket.seatInfo)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // ── Member: level/points + perks ─────────────────────────────────────

    private var memberInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                if !ticket.memberLevel.isEmpty {
                    infoColumn(label: "等级", value: ticket.memberLevel, valueColor: theme.accent)
                }
                if !ticket.memberPoints.isEmpty {
                    infoColumn(label: "积分", value: ticket.memberPoints)
                }
                if !ticket.extraField2Value.isEmpty {
                    infoColumn(label: ticket.extraField2Label, value: ticket.extraField2Value)
                }
            }
            if !ticket.tags.isEmpty {
                tagChips(ticket.tags)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // ── Scenic: date/type/qty + admission window banner ──────────────────

    private var scenicInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                if !ticket.eventTime.isEmpty {
                    infoColumn(label: "入场时间", value: ticket.eventTime)
                }
                if !ticket.extraField1Value.isEmpty {
                    infoColumn(label: ticket.extraField1Label, value: ticket.extraField1Value)
                }
                if !ticket.extraField2Value.isEmpty {
                    infoColumn(label: ticket.extraField2Label, value: ticket.extraField2Value)
                }
            }
            if !ticket.admissionWindow.isEmpty {
                admissionWindowBanner
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var admissionWindowBanner: some View {
        HStack(spacing: 6) {
            Text("⏰")
                .font(.system(size: 12))
            Text("入园时段  \(ticket.admissionWindow)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.accent.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Shared column + helpers

    private func infoColumn(label: String, value: String, valueColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(valueColor ?? (isDark ? .white : .black))
        }
    }

    private func tagChips(_ chips: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(chips, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(theme.accent.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func noteBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.accent.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Compact Info

    private var compactInfo: some View {
        HStack(spacing: 12) {
            if ticket.ticketType == .train, !ticket.routeOrigin.isEmpty {
                Text("\(ticket.routeOrigin) → \(ticket.routeDestination)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .black)
                    .lineLimit(1)
            } else if ticket.ticketType == .member {
                Text(ticket.memberLevel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accent)
                if !ticket.memberPoints.isEmpty {
                    Text("积分 \(ticket.memberPoints)")
                        .font(.system(size: 13))
                        .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
                }
            } else {
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

// MARK: - Flow Layout (auto-wrapping HStack)

/// Simple flow layout — wraps children when they exceed available width.
/// Uses the iOS 16 Layout protocol.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        var rowStart = 0

        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
                rowStart = i
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        _ = rowStart
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

// MARK: - Previews (all 6 ticket types)

#Preview("所有票据类型") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(TicketType.allCases, id: \.rawValue) { type in
                TicketCardView(
                    ticket: Ticket.preview(type),
                    size: .full,
                    isDark: true
                )
            }
        }
        .padding()
    }
    .background(Color(hex: "#1A1A2E"))
}

#Preview("浅色模式") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(TicketType.allCases, id: \.rawValue) { type in
                TicketCardView(
                    ticket: Ticket.preview(type),
                    size: .full,
                    isDark: false
                )
            }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
