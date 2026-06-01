import SwiftUI
import SwiftData

// MARK: - Card Wallet View (卡包)

/// Apple Wallet–style stack of long-lived membership / loyalty cards.
/// Cards stack vertically, each peeking its header; tap one to expand it in
/// place and reveal the barcode for POS scanning. Tap an already-expanded card
/// again to push into its detail page.
/// Expired cards leave here for the unified archive; soon-to-expire cards are flagged.
struct CardWalletView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Ticket.importedAt, order: .reverse) private var tickets: [Ticket]

    let onScanTapped:  () -> Void
    let onPhotoTapped: () -> Void

    @State private var selectedTicket: Ticket?
    /// The card currently expanded to show its barcode (nil = all collapsed).
    @State private var expandedID: UUID?

    private var isDark: Bool { colorScheme == .dark }

    // Stack geometry
    private let collapsedHeight: CGFloat = 72
    private let expandedHeight:  CGFloat = 224
    private let peekOverlap:     CGFloat = 18   // how much each collapsed card slides up over the previous

    /// Count across all items (tickets + cards) currently in the archive.
    private var archivedCount: Int {
        tickets.filter(\.isInArchive).count
    }

    /// Valid cards only — expired ones live in the archive.
    private var cards: [Ticket] {
        tickets
            .filter { $0.isCard && !$0.isInArchive }
            .sorted { a, b in
                // 1) Soon-to-expire first so renewals surface to the top.
                if a.isExpiringSoon != b.isExpiringSoon { return a.isExpiringSoon }
                // 2) Then by earliest validity end (no-expiry cards sink last).
                let ae = a.expiresAt ?? .distantFuture
                let be = b.expiresAt ?? .distantFuture
                if ae != be { return ae < be }
                // 3) Stable tiebreak: most recently imported first.
                return a.importedAt > b.importedAt
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: isDark ? "#0E0E10" : "#F4F1EA").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerBar

                        if cards.isEmpty {
                            emptyState
                        } else {
                            cardStack
                        }

                        archiveEntry
                    }
                }
            }
            .navigationDestination(item: $selectedTicket) { ticket in
                PassDetailView(ticket: ticket)
            }
            .onAppear {
                // Default state: expand the top card (soon-to-expire / most relevant).
                if expandedID == nil { expandedID = cards.first?.id }
            }
        }
    }

    // MARK: Stack

    private var cardStack: some View {
        let list = cards
        return VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, card in
                let isExpanded   = expandedID == card.id
                let prevExpanded = index > 0 && expandedID == list[index - 1].id

                Button {
                    if expandedID == card.id {
                        selectedTicket = card                       // 2nd tap → detail
                    } else {
                        withAnimation(AppAnimation.cardAppear) {     // 1st tap → expand
                            expandedID = card.id
                        }
                    }
                } label: {
                    cardView(card, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                // First card flush; a card under an expanded one gets a gap so it
                // isn't covered; otherwise slide up to overlap the previous card.
                .padding(.top, index == 0 ? 0 : (prevExpanded ? AppSpacing.sm : -peekOverlap))
                // Expanded card floats above everything; lower cards cover upper ones.
                .zIndex(isExpanded ? 1000 : Double(index))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 16)
    }

    // MARK: Card (collapsed peek / expanded with barcode)

    private func cardView(_ ticket: Ticket, isExpanded: Bool) -> some View {
        let palette = CardPalette.palette(for: colorKey(ticket))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(ticket.ticketType.emoji)
                    .font(.system(size: isExpanded ? 24 : 20))

                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.title.isEmpty ? "未命名卡片" : ticket.title)
                        .font(.system(size: isExpanded ? 18 : 15, weight: isExpanded ? .bold : .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isExpanded {
                        Text(validityText(ticket))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer(minLength: 8)

                if ticket.isExpiringSoon {
                    expiringBadge
                } else if isExpanded {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if isExpanded {
                Spacer(minLength: 12)
                barcodePanel(ticket)
            }
        }
        .padding(isExpanded ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isExpanded ? expandedHeight : collapsedHeight, alignment: .top)
        .background(palette.backgroundGradient)
        .overlay(
            // Accent glow blob, top-right
            Circle()
                .fill(palette.accent)
                .frame(width: 90, height: 90)
                .blur(radius: 40)
                .opacity(0.35)
                .offset(x: 40, y: -30),
            alignment: .topTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusCard, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isDark ? 0.45 : 0.18), radius: 8, y: 4)
    }

    private func barcodePanel(_ ticket: Ticket) -> some View {
        VStack(spacing: 6) {
            BarcodeImageView(
                value: ticket.barcodeValue,
                format: ticket.barcodeFormat,
                size: 78
            )
            if !ticket.barcodeValue.isEmpty {
                Text(formatBarcode(ticket.barcodeValue))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.gray)
                    .kerning(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var expiringBadge: some View {
        Text("即将到期")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: "#FF9F0A"))
            .clipShape(Capsule())
    }

    // 已归档入口 — 与票据 tab 共用统一归档页，卡包用户归档卡片后也能在此找到。
    @ViewBuilder
    private var archiveEntry: some View {
        if archivedCount > 0 {
            NavigationLink {
                ArchiveView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 15, weight: .medium))
                    Text("已归档")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(archivedCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(isDark ? .white.opacity(0.7) : .black.opacity(0.65))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("archiveEntry")
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, 18)
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Text("卡包")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(isDark ? .white : .black)
                .kerning(-0.4)
            Spacer()
            Menu {
                Button { onPhotoTapped() } label: { Label("从相册导入", systemImage: "photo.on.rectangle") }
                Button { onScanTapped() }  label: { Label("扫描条码",   systemImage: "viewfinder") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .black)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.05))
                            .overlay(Circle().strokeBorder(Color.white.opacity(isDark ? 0.15 : 0.4), lineWidth: 1))
                    )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
    }

    // MARK: Helpers

    /// Stable color key — same card always maps to the same palette.
    /// Falls back to barcode/uuid so unnamed cards still get distinct colors.
    private func colorKey(_ ticket: Ticket) -> String {
        let title = ticket.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return ticket.barcodeValue.isEmpty ? ticket.id.uuidString : ticket.barcodeValue
    }

    private func validityText(_ ticket: Ticket) -> String {
        guard let exp = ticket.expiresAt else { return "长期有效" }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return "有效期至 " + f.string(from: exp)
    }

    private func formatBarcode(_ value: String) -> String {
        let digits = value.prefix(16)
        return stride(from: 0, to: digits.count, by: 4)
            .map { i -> String in
                let start = digits.index(digits.startIndex, offsetBy: i)
                let end   = digits.index(start, offsetBy: min(4, digits.count - i))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("💳")
                .font(.system(size: 64))
                .padding(.top, 60)
            Text("还没有会员卡")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
            Text("会员卡、积分卡、月卡都可以放在这里\n随时调出条码核销")
                .font(.system(size: 14))
                .foregroundStyle(isDark ? .white.opacity(0.4) : .black.opacity(0.4))
                .multilineTextAlignment(.center)

            Button(action: onPhotoTapped) {
                Text("＋ 添加卡片")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .black : Color(hex: "#FDFCF8"))
                    .frame(height: 48)
                    .frame(maxWidth: 200)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Ticket.self, configurations: config)
    // Several differently-named member cards to show the stacked, multi-color look.
    let names = ["星巴克 金星会员", "山姆会员店", "健身房年卡", "图书馆借阅证", "Apple Store"]
    for name in names {
        let card = Ticket.preview(.member)
        card.title = name
        container.mainContext.insert(card)
    }
    return CardWalletView(onScanTapped: {}, onPhotoTapped: {})
        .modelContainer(container)
}
