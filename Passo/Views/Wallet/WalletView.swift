import SwiftUI
import SwiftData

// MARK: - Wallet Filter

enum WalletFilter: Int, CaseIterable {
    case upcoming = 0  // 今天 + 即将到来
    case all      = 1

    var label: String {
        switch self {
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
    @State private var swipeAction: SwipeAction?
    @State private var showPhotoImport = false

    private enum SwipeAction { case delete, markUsed }

    private var isDark: Bool { colorScheme == .dark }

    private var activeTheme: TicketTheme {
        filteredTickets.first?.ticketType.theme ?? TicketType.generic.theme
    }

    private var activeFilter: WalletFilter {
        WalletFilter(rawValue: filterIndex) ?? .all
    }

    private var isTimelineMode: Bool {
        activeFilter == .all && !filteredTickets.isEmpty
    }

    private var filteredTickets: [Ticket] {
        switch activeFilter {
        case .upcoming:
            // Today's tickets (regardless of time) + strictly future events, exclude used
            return tickets.filter { ($0.isToday || $0.isUpcoming) && !$0.isUsed }
        case .all:
            // Unused tickets first (sorted by date), used tickets sink to bottom
            return tickets.sorted {
                if $0.isUsed != $1.isUsed { return !$0.isUsed }
                let d0 = $0.eventDate ?? .distantFuture
                let d1 = $1.eventDate ?? .distantFuture
                return d0 < d1
            }
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
            // Must be inside NavigationStack so the destination is registered in the nav graph
            .navigationDestination(item: $selectedTicket) { ticket in
                PassDetailView(ticket: ticket)
            }
            // Sticky bottom bar: empty state shows a single primary CTA;
            // any non-empty list (both tabs) gets the dual action bar.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if filteredTickets.isEmpty {
                    stickyImportBar
                } else {
                    actionBottomBar
                }
            }
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportView()
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

            HStack(spacing: 10) {
                GlassPillButton(isDark: isDark, action: { showPhotoImport = true }) {
                    AnyView(
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isDark ? .white : .black)
                    )
                }

                GlassPillButton(isDark: isDark, action: onScanTapped) {
                    AnyView(
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isDark ? .white : .black)
                    )
                }
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

    @ViewBuilder
    private var nextUpLabel: some View {
        // Hidden in timeline mode — the countdown chip communicates this instead
        if !isTimelineMode {
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
    }

    private var nextUpText: String {
        guard let first = filteredTickets.first, !first.isUsed else { return "暂无即将到来的票据" }
        if first.isToday && !first.eventTime.isEmpty {
            return "下一场 · 今天 \(first.eventTime)"
        }
        return "下一场 · \(first.title)"
    }

    private var cardStack: some View {
        Group {
            if filteredTickets.isEmpty {
                currentEmptyState
                    .padding(.horizontal, AppSpacing.md)
            } else {
                switch activeFilter {
                case .upcoming:
                    cardPile
                        .padding(.horizontal, AppSpacing.md)
                case .all:
                    allTimeline
                }
            }
        }
        .padding(.top, 10)
    }

    private var cardPile: some View {
        VStack(spacing: 0) {
            // Top card with swipe gesture
            ZStack {
                if let top = filteredTickets.first {
                    // Ghost depth layers behind the top card
                    if filteredTickets.count > 2 {
                        ghostCard(inset: 26, topOffset: -8, opacity: 0.04, bgOpacity: 0.04)
                    }
                    if filteredTickets.count > 1 {
                        ghostCard(inset: 22, topOffset: -4, opacity: 0.06, bgOpacity: 0.06)
                    }

                    ZStack {
                        TicketCardView(ticket: top, size: .full, isDark: isDark)
                            .saturation(top.isUsed ? 0.25 : 1)
                            .opacity(top.isUsed ? 0.7 : 1)
                        swipeLabels(for: top)
                        // "已使用" stamp overlay
                        if top.isUsed {
                            usedStamp
                        }
                    }
                    .offset(topCardOffset)
                    .rotationEffect(.degrees(Double(topCardOffset.width) / 22))
                    .gesture(swipeGesture(for: top))
                    .onTapGesture { selectedTicket = top }
                    .zIndex(10)
                }
            }

            // Peek of second card — tappable to navigate to its detail
            if filteredTickets.count > 1 {
                TicketCardView(ticket: filteredTickets[1], size: .compact, isDark: isDark)
                    .padding(.top, 12)
                    .zIndex(5)
                    .onTapGesture { selectedTicket = filteredTickets[1] }
            }
        }
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

    private var usedStamp: some View {
        Text("已使用")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .rotationEffect(.degrees(-22))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                    .rotationEffect(.degrees(-22))
            )
    }

    // MARK: - Timeline (全部 tab)

    private var allTimeline: some View {
        VStack(spacing: 0) {
            countdownSection
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, 16)

            let groups = dateGrouped(filteredTickets)
            ForEach(groups, id: \.label) { group in
                timelineDateSection(group)
                    .padding(.horizontal, AppSpacing.md)
            }

            Color.clear.frame(height: 8)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var countdownSection: some View {
        let redAccent = Color(hex: "#E94560")
        if let next = filteredTickets.first(where: { ($0.eventDate ?? .distantPast) > Date() }),
           let date = next.eventDate {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("倒计时")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(redAccent.opacity(0.65))
                    Text("下一张 " + countdownString(to: date))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(redAccent)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(redAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: timelineIcon(next.ticketType))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(redAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(redAccent.opacity(isDark ? 0.1 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(redAccent.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private func timelineDateSection(_ group: TimelineDateGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header
            HStack(spacing: 12) {
                Color.clear.frame(width: 20)
                Text(group.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.4) : Color(hex: "#A8A39A"))
            }
            .padding(.bottom, 10)

            // Ticket rows with vertical timeline line
            ForEach(Array(group.tickets.enumerated()), id: \.element.persistentModelID) { idx, ticket in
                HStack(alignment: .top, spacing: 12) {
                    // Left: dot + vertical connector line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.3) : Color(hex: "#C5C0B8"))
                            .frame(width: 8, height: 8)
                            .padding(.top, 20)
                        if idx < group.tickets.count - 1 {
                            Rectangle()
                                .fill(isDark ? Color.white.opacity(0.1) : Color(hex: "#DDD9D2"))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                                .padding(.top, 4)
                        }
                    }
                    .frame(width: 20)

                    // Ticket card
                    Button { selectedTicket = ticket } label: {
                        timelineTicketCard(ticket)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, idx < group.tickets.count - 1 ? 10 : 0)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func timelineTicketCard(_ ticket: Ticket) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ticket.ticketType.theme.accent.opacity(isDark ? 0.2 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: timelineIcon(ticket.ticketType))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ticket.ticketType.theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ticket.title.isEmpty ? "未识别标题" : ticket.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.9) : Color(hex: "#111111"))
                    .lineLimit(1)

                let detail = [ticket.eventTime, ticket.venue]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(isDark ? .white.opacity(0.45) : Color(hex: "#A8A39A"))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.25) : Color(hex: "#C5C0B8"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isDark ? Color.white.opacity(0.07) : Color(hex: "#FDFCF8"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isDark ? 0 : 0.04), radius: 6, y: 2)
    }

    // MARK: Timeline Helpers

    private struct TimelineDateGroup: Identifiable {
        let id = UUID()
        let label: String
        let tickets: [Ticket]
    }

    private func dateGrouped(_ tickets: [Ticket]) -> [TimelineDateGroup] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "M月 d日 EEEE"
        fmt.locale = Locale(identifier: "zh_CN")

        var order: [String] = []
        var grouped: [String: [Ticket]] = [:]

        for ticket in tickets {
            let key: String
            if let date = ticket.eventDate {
                key = cal.isDateInToday(date) ? "今天" : fmt.string(from: date)
            } else {
                key = "日期待定"
            }
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]!.append(ticket)
        }

        return order.compactMap { key in
            guard let t = grouped[key] else { return nil }
            return TimelineDateGroup(label: key, tickets: t)
        }
    }

    private func countdownString(to date: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSinceNow))
        let d = secs / 86_400
        let h = (secs % 86_400) / 3600
        let m = (secs % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "即将开始"
    }

    private func timelineIcon(_ type: TicketType) -> String {
        switch type {
        case .movie:   return "film"
        case .concert: return "music.note"
        case .train:   return "train.side.front.car"
        case .scenic:  return "mountain.2"
        case .member:  return "creditcard"
        case .generic: return "ticket"
        }
    }

    // Dual-action bar shown on both tabs when the list is non-empty.
    // Primary CTA opens scanner; secondary opens photo-library import.
    private var actionBottomBar: some View {
        HStack(spacing: 10) {
            Button(action: onScanTapped) {
                Text("＋ 扫一张")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? Color.black : Color(hex: "#FDFCF8"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button { showPhotoImport = true } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.7) : .black.opacity(0.6))
                    .frame(width: 48, height: 48)
                    .background(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // Both tabs use the same rich first-run showcase
    private var currentEmptyState: some View {
        emptyShowcase
    }

    // MARK: Empty State — unified across all filter tabs

    private var emptyShowcase: some View {
        VStack(spacing: 0) {
            // Decorative illustration
            ZStack {
                Text("✦")
                    .font(.system(size: 18))
                    .foregroundStyle(isDark ? .white.opacity(0.3) : .black.opacity(0.2))
                    .offset(x: -52, y: 6)
                Text("✦")
                    .font(.system(size: 11))
                    .foregroundStyle(isDark ? .white.opacity(0.2) : .black.opacity(0.15))
                    .offset(x: 54, y: -10)
                Text("🎟")
                    .font(.system(size: 72))
            }
            .padding(.top, 40)

            Text("还没有票")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
                .padding(.top, 20)

            VStack(spacing: 3) {
                Text("拍一张票、截图或二维码")
                Text("秒速导入，随时亮码")
            }
            .font(.system(size: 15))
            .foregroundStyle(isDark ? .white.opacity(0.38) : .black.opacity(0.38))
            .multilineTextAlignment(.center)
            .padding(.top, 10)

            // Entry-point shortcuts — only the two import paths the app actually supports.
            HStack(spacing: 10) {
                entryTile("camera.fill", "拍照扫码", action: onScanTapped)
                entryTile("photo.on.rectangle", "截图导入") { showPhotoImport = true }
            }
            .padding(.horizontal, 40)
            .padding(.top, 28)

            Text("支持电影票 · 高铁票 · 演出票 · 会员卡 · 门票...")
                .font(.system(size: 12))
                .foregroundStyle(isDark ? .white.opacity(0.22) : .black.opacity(0.28))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // iOS-standard sticky bottom bar — placed via safeAreaInset in body
    private var stickyImportBar: some View {
        Button(action: onScanTapped) {
            Text("＋ 扫描导入第一张票")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.black : Color(hex: "#FDFCF8"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDark ? Color.white : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func entryTile(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.65) : .black.opacity(0.55))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .black.opacity(0.42))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
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

    // MARK: Swipe Labels

    @ViewBuilder
    private func swipeLabels(for ticket: Ticket) -> some View {
        let dragX = topCardOffset.width
        let progress = min(abs(dragX) / swipeThreshold, 1.0)

        HStack {
            // Right swipe → mark used
            if dragX > 20 {
                Label(ticket.isUsed ? "已归档" : "标记使用", systemImage: ticket.isUsed ? "archivebox" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.85))
                    .clipShape(Capsule())
                    .opacity(progress)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
            }

            // Left swipe → delete
            if dragX < -20 {
                Label("删除", systemImage: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
                    .opacity(progress)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 20)
            }
        }
    }

    // MARK: Swipe Gesture

    private let swipeThreshold: CGFloat = 120

    private func swipeGesture(for ticket: Ticket) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow horizontal swipe; dampen vertical drift
                topCardOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height * 0.15
                )
            }
            .onEnded { value in
                let dx = value.translation.width

                if dx > swipeThreshold {
                    commitSwipe(direction: .right, ticket: ticket)
                } else if dx < -swipeThreshold {
                    commitSwipe(direction: .left, ticket: ticket)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        topCardOffset = .zero
                    }
                }
            }
    }

    private func commitSwipe(direction: HorizontalDirection, ticket: Ticket) {
        let screenWidth = UIScreen.main.bounds.width
        let flyX: CGFloat = direction == .right ? screenWidth + 100 : -(screenWidth + 100)

        withAnimation(.spring(response: 0.38, dampingFraction: 0.8), completionCriteria: .removed) {
            topCardOffset = CGSize(width: flyX, height: topCardOffset.height)
        } completion: {
            topCardOffset = .zero
            if direction == .right {
                ticket.isUsed = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                modelContext.delete(ticket)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            try? modelContext.save()
        }
    }

    private enum HorizontalDirection { case left, right }
}

// MARK: - Photo Import Entry (WalletView header button)

extension WalletView {
    var photoImportButton: some View {
        Button { showPhotoImport = true } label: {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isDark ? .white : .black)
        }
    }
}

private struct WalletViewPreviewContainer: View {
    private let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Ticket.self, configurations: config)
        for type in TicketType.allCases {
            container.mainContext.insert(Ticket.preview(type))
        }
        self.container = container
    }

    var body: some View {
        WalletView(onScanTapped: {})
            .modelContainer(container)
    }
}

#Preview {
    WalletViewPreviewContainer()
}
