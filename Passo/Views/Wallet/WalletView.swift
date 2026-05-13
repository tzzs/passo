import SwiftUI
import SwiftData

// MARK: - Wallet Filter

enum WalletFilter: Int, CaseIterable {
    case today    = 0
    case upcoming = 1
    case all      = 2

    var label: String {
        switch self {
        case .today:    return "今天"
        case .upcoming: return "即将"
        case .all:      return "全部"
        }
    }
}

// MARK: - Wallet View

/// Main home screen — Apple Wallet-style ticket pile with glassmorphism cards.
/// Design reference: HiFiPile in hifi.jsx
struct WalletView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @Query(sort: \Ticket.eventDate) private var tickets: [Ticket]

    let onScanTapped: () -> Void

    @State private var filterIndex = 0
    @State private var selectedTicket: Ticket?
    @State private var topCardOffset: CGSize = .zero

    private var isDark: Bool { colorScheme == .dark }

    private var activeTheme: TicketTheme {
        filteredTickets.first?.ticketType.theme ?? TicketType.generic.theme
    }

    private var filteredTickets: [Ticket] {
        switch WalletFilter(rawValue: filterIndex) ?? .all {
        case .today:    return tickets.filter { $0.isToday && !$0.isUsed }
        case .upcoming: return tickets.filter { $0.isUpcoming }
        case .all:      return tickets
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background: dynamic gradient in dark mode, system gray in light mode
                // (matches design spec — see hifi.jsx HiFiPile)
                background
                    .ignoresSafeArea()
                    .animation(AppAnimation.themeChange, value: filteredTickets.first?.ticketType.rawValue)

                // Ambient glow blobs (dark mode only)
                if isDark { ambientGlows }

                ScrollView {
                    VStack(spacing: 0) {
                        headerBar
                        filterControl
                        nextUpLabel
                        cardStack
                        bottomSpacer
                    }
                }
            }
        }
        .navigationDestination(item: $selectedTicket) { ticket in
            PassDetailView(ticket: ticket)
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var background: some View {
        if isDark {
            activeTheme.backgroundGradient
        } else {
            Color(uiColor: .systemGroupedBackground)
        }
    }

    private var ambientGlows: some View {
        ZStack {
            Circle()
                .fill(activeTheme.accent)
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .opacity(0.12)
                .offset(x: 30, y: -80)
            Circle()
                .fill(activeTheme.accent)
                .frame(width: 160, height: 160)
                .blur(radius: 60)
                .opacity(0.08)
                .offset(x: 60, y: 200)
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Passo")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(isDark ? .white : .black)
                .kerning(-0.4)

            Spacer()

            GlassPillButton(isDark: isDark, action: onScanTapped) {
                AnyView(
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isDark ? .white : .black)
                )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
    }

    private var filterControl: some View {
        GlassSegmentedControl(
            items: WalletFilter.allCases.map(\.label),
            selectedIndex: $filterIndex,
            isDark: isDark
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 12)
    }

    private var nextUpLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(activeTheme.accent)
                .frame(width: 6, height: 6)
            Text(nextUpText)
                .font(.system(size: 13))
                .foregroundStyle(isDark ? .white.opacity(0.5) : .black.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 14)
    }

    private var nextUpText: String {
        guard let first = filteredTickets.first, !first.isUsed else { return "暂无即将到来的票据" }
        if first.isToday && !first.eventTime.isEmpty {
            return "下一场 · 今天 \(first.eventTime)"
        }
        return "下一场 · \(first.title)"
    }

    private var cardStack: some View {
        ZStack(alignment: .top) {
            if filteredTickets.isEmpty {
                emptyState
            } else {
                // Back ghost cards (depth effect)
                if filteredTickets.count > 2 {
                    ghostCard(inset: 26, topOffset: 30, opacity: 0.04, bgOpacity: 0.04)
                }
                if filteredTickets.count > 1 {
                    ghostCard(inset: 22, topOffset: 18, opacity: 0.06, bgOpacity: 0.06)
                }

                // Top card
                if let top = filteredTickets.first {
                    TicketCardView(ticket: top, size: .full, isDark: isDark)
                        .offset(topCardOffset)
                        .gesture(swipeGesture)
                        .onTapGesture { selectedTicket = top }
                        .zIndex(10)
                }

                // Peek of second card
                if filteredTickets.count > 1 {
                    TicketCardView(ticket: filteredTickets[1], size: .compact, isDark: isDark)
                        .padding(.top, 16)
                        .zIndex(5)
                        .offset(y: 340) // Below the top card
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 10)
    }

    private func ghostCard(inset: CGFloat, topOffset: CGFloat, opacity: Double, bgOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isDark ? Color.white.opacity(bgOpacity) : Color.white.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(opacity * 2), lineWidth: 1)
            )
            .frame(height: 24)
            .padding(.horizontal, inset)
            .offset(y: topOffset)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(isDark ? .white.opacity(0.3) : .black.opacity(0.2))
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text("票夹空空如也")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.8) : .black.opacity(0.7))
                Text("拍一张票据，即刻存入 Wallet")
                    .font(.system(size: 15))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .black.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            Button(action: onScanTapped) {
                Label("扫描导入", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(height: 50)
                    .frame(maxWidth: 200)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(filteredTickets.count, 4), id: \.self) { i in
                Capsule()
                    .fill(i == 0 ? activeTheme.accent : (isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)))
                    .frame(width: i == 0 ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: i)
            }
        }
        .padding(.top, 14)
    }

    private var ticketCountLabel: some View {
        let todayCount = filteredTickets.filter { $0.isToday && !$0.isUsed }.count
        let totalCount = tickets.count
        return Text("\(todayCount) 张票今天可用 · 共 \(totalCount) 张")
            .font(.system(size: 12))
            .foregroundStyle(isDark ? .white.opacity(0.35) : .black.opacity(0.3))
            .padding(.top, 8)
    }

    private var bottomSpacer: some View {
        VStack(spacing: 8) {
            if !filteredTickets.isEmpty {
                pageIndicator
                ticketCountLabel
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: Swipe Gesture (dismiss top card)

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                topCardOffset = value.translation
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    topCardOffset = .zero
                }
            }
    }
}

#Preview {
    WalletView(onScanTapped: {})
        .modelContainer(for: Ticket.self, inMemory: true)
}
