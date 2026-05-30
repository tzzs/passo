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

/// Home screen — Apple Wallet-style ticket pile (upcoming) or timeline (all).
/// `filter` is fixed at init time; switching between views is handled by TabView in ContentView.
struct WalletView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @Query(sort: \Ticket.eventDate) private var tickets: [Ticket]

    let onScanTapped:  () -> Void
    let onPhotoTapped: () -> Void

    @State private var filterIndex = 0
    @State private var selectedTicket: Ticket?
    @State private var topCardOffset:  CGSize = .zero
    @State private var swipeAction:    SwipeAction?

    private enum SwipeAction { case delete, markUsed }

    private var isDark: Bool { colorScheme == .dark }

    /// 即将 / 全部 — switched in-tab via the segmented control.
    private var filter: WalletFilter { WalletFilter(rawValue: filterIndex) ?? .upcoming }

    private var activeTheme: TicketTheme {
        filteredTickets.first?.ticketType.theme ?? TicketType.generic.theme
    }

    private var isTimelineMode: Bool {
        filter == .all && !filteredTickets.isEmpty
    }

    private var filteredTickets: [Ticket] {
        // Active event tickets only — cards live in 卡包, archived items in 归档.
        let active = tickets.filter { !$0.isCard && !$0.isInArchive }
        switch filter {
        case .upcoming:
            return active.filter { $0.isToday || $0.isUpcoming }
        case .all:
            return active.sorted {
                let d0 = $0.eventDate ?? .distantFuture
                let d1 = $1.eventDate ?? .distantFuture
                return d0 < d1
            }
        }
    }

    /// Count across all items (tickets + cards) that have moved to the archive.
    private var archivedCount: Int {
        tickets.filter(\.isInArchive).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()
                    .animation(AppAnimation.themeChange, value: filteredTickets.first?.ticketType.rawValue)

                if isDark { ambientGlows }

                ScrollView {
                    VStack(spacing: 0) {
                        headerBar
                        filterControl
                        nextUpLabel
                        cardStack
                        archiveEntry
                        bottomSpacer
                    }
                }
            }
            .navigationDestination(item: $selectedTicket) { ticket in
                PassDetailView(ticket: ticket)
            }
        }
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

    // "已归档 (N)" entry — pushes the unified archive (expired/used tickets + cards).
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
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, 18)
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

            // "+" import menu — anchored to the button, expands in place (no bottom-sheet jump).
            // Album first, scan second (usage skews 7:3 toward album imports).
            Menu {
                Button {
                    onPhotoTapped()
                } label: {
                    Label("从相册导入", systemImage: "photo.on.rectangle")
                }
                Button {
                    onScanTapped()
                } label: {
                    Label("扫描条码", systemImage: "viewfinder")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .black)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.05))
                            .overlay(
                                Circle().strokeBorder(
                                    Color.white.opacity(isDark ? 0.15 : 0.4),
                                    lineWidth: 1
                                )
                            )
                            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.06), radius: 4, y: 1)
                    )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var nextUpLabel: some View {
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
                switch filter {
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
            ZStack {
                if let top = filteredTickets.first {
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
                        if top.isUsed { usedStamp }
                    }
                    .offset(topCardOffset)
                    .rotationEffect(.degrees(Double(topCardOffset.width) / 22))
                    .gesture(swipeGesture(for: top))
                    .onTapGesture { selectedTicket = top }
                    .zIndex(10)
                }
            }

            if filteredTickets.count > 1 {
                TicketCardView(ticket: filteredTickets[1], size: .compact, isDark: isDark)
                    .padding(.top, 12)
                    .zIndex(5)
                    .onTapGesture { selectedTicket = filteredTickets[1] }
            }
        }
    }

    private func ghostCard(inset: CGFloat, topOffset: CGFloat, opacity: Double, bgOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
            .fill(isDark ? Color.white.opacity(bgOpacity) : Color.white.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
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
            // Lightweight: a single text line with a small dot — no filled banner.
            HStack(spacing: 8) {
                Circle()
                    .fill(redAccent)
                    .frame(width: 7, height: 7)
                Text("下一张")
                    .font(.system(size: 13))
                    .foregroundStyle(isDark ? .white.opacity(0.5) : Color(hex: "#A8A39A"))
                Text(countdownString(to: date))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(redAccent)
                Spacer()
            }
            .padding(.horizontal, 2)
        }
    }

    private func timelineDateSection(_ group: TimelineDateGroup) -> some View {
        let dividerColor = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
        return VStack(alignment: .leading, spacing: 0) {
            // Date separator — label + horizontal rule (横杠)
            HStack(spacing: 10) {
                Text(group.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.5) : Color(hex: "#8A857C"))
                    .fixedSize()
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 14)

            ForEach(Array(group.tickets.enumerated()), id: \.element.persistentModelID) { idx, ticket in
                HStack(alignment: .top, spacing: 12) {
                    // Left rail — event time
                    Text(ticket.eventTime.isEmpty ? "全天" : ticket.eventTime)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isDark ? .white.opacity(0.85) : Color(hex: "#111111"))
                        .frame(width: 46, alignment: .leading)
                        .padding(.top, 13)

                    Button { selectedTicket = ticket } label: {
                        timelineTicketCard(ticket)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, idx < group.tickets.count - 1 ? 12 : 0)
            }
        }
        .padding(.bottom, 22)
    }

    private func timelineTicketCard(_ ticket: Ticket) -> some View {
        let accent = ticket.ticketType.theme.accent
        let ink    = isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
        let sub    = isDark ? Color.white.opacity(0.45) : Color(hex: "#A8A39A")
        // Venue + structured seat/hall/quantity (电影=影厅/座位, 火车=车厢/座位…) on one line.
        let detail = [
            ticket.venue,
            [ticket.extraField1Value, ticket.extraField2Value].filter { !$0.isEmpty }.joined(separator: " · ")
        ].filter { !$0.isEmpty }.joined(separator: " · ")

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Type badge + title on one line — badge keeps its intrinsic size,
                // title fills the rest and truncates if long.
                HStack(spacing: 8) {
                    TicketTypeBadge(type: ticket.ticketType)
                        .fixedSize()
                    Text(ticket.title.isEmpty ? "未识别标题" : ticket.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                }

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(sub)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isDark ? Color.white.opacity(0.06) : Color(hex: "#FDFCF8"))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard, style: .continuous))
        // Border uses the ticket-type theme color (replaces the old accent spine + icon)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusCard, style: .continuous)
                .strokeBorder(accent.opacity(isDark ? 0.75 : 0.55), lineWidth: 1.5)
        )
        .shadow(color: accent.opacity(isDark ? 0 : 0.10), radius: 8, y: 3)
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

        var order:   [String]          = []
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

    // MARK: - Empty State

    private var currentEmptyState: some View { emptyShowcase }

    private var emptyShowcase: some View {
        VStack(spacing: 0) {
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

            // Each tile maps directly to its import path.
            HStack(spacing: 10) {
                entryTile("camera.fill",          "拍照扫码",  action: onScanTapped)
                entryTile("photo.on.rectangle",   "截图导入",  action: onPhotoTapped)
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
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
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
            // Page dots + count only make sense for the pile (即将); a vertical
            // timeline (全部) reads them as a stray horizontal-paging affordance.
            if filter == .upcoming, !filteredTickets.isEmpty {
                pageIndicator
                ticketCountLabel
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: Swipe Labels

    @ViewBuilder
    private func swipeLabels(for ticket: Ticket) -> some View {
        let dragX    = topCardOffset.width
        let progress = min(abs(dragX) / swipeThreshold, 1.0)

        HStack {
            if dragX > 20 {
                Label(ticket.isUsed ? "已归档" : "标记使用",
                      systemImage: ticket.isUsed ? "archivebox" : "checkmark.circle.fill")
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
                topCardOffset = CGSize(
                    width:  value.translation.width,
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

// MARK: - Preview

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
        WalletView(onScanTapped: {}, onPhotoTapped: {})
            .modelContainer(container)
    }
}

#Preview {
    WalletViewPreviewContainer()
}
