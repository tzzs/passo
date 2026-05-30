import SwiftUI
import SwiftData

// MARK: - Card Wallet View (卡包)

/// Grid of long-lived membership / loyalty cards (no timeline, no event time).
/// Cards are surfaced for on-demand retrieval — tap to enlarge the barcode at a POS.
/// Expired cards leave here for the unified archive; soon-to-expire cards are flagged.
struct CardWalletView: View {
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Ticket.importedAt, order: .reverse) private var tickets: [Ticket]

    let onScanTapped:  () -> Void
    let onPhotoTapped: () -> Void

    @State private var selectedTicket: Ticket?

    private var isDark: Bool { colorScheme == .dark }

    /// Valid cards only — expired ones live in the archive.
    private var cards: [Ticket] {
        tickets
            .filter { $0.isCard && !$0.isInArchive }
            // Soon-to-expire first so renewals surface to the top.
            .sorted { ($0.isExpiringSoon ? 0 : 1) < ($1.isExpiringSoon ? 0 : 1) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

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
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(cards) { card in
                                    Button { selectedTicket = card } label: { cardCell(card) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, 16)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedTicket) { ticket in
                PassDetailView(ticket: ticket)
            }
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

    // MARK: Card Cell

    private func cardCell(_ ticket: Ticket) -> some View {
        let theme = ticket.ticketType.theme
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(ticket.ticketType.emoji)
                    .font(.system(size: 22))
                Spacer()
                if ticket.isExpiringSoon {
                    Text("即将到期")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#FF9F0A"))
                        .clipShape(Capsule())
                }
            }

            Spacer(minLength: 12)

            Text(ticket.title.isEmpty ? "未命名卡片" : ticket.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(validityText(ticket))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(14)
        .frame(height: 132, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundGradient)
        .overlay(
            // Subtle accent glow blob, top-right
            Circle()
                .fill(theme.accent)
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
        .shadow(color: theme.accent.opacity(isDark ? 0.25 : 0.18), radius: 10, y: 5)
    }

    private func validityText(_ ticket: Ticket) -> String {
        guard let exp = ticket.expiresAt else { return "长期有效" }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return "有效期至 " + f.string(from: exp)
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
    container.mainContext.insert(Ticket.preview(.member))
    return CardWalletView(onScanTapped: {}, onPhotoTapped: {})
        .modelContainer(container)
}
