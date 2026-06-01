import SwiftUI
import UIKit
import PassKit
@preconcurrency import MapKit

// MARK: - Pass Detail View

/// Immersive pass detail: full-width gradient header + 3D flip card + info rows.
/// Design reference: HiFiDetail in hifi-screens.jsx
struct PassDetailView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext

    @Bindable var ticket: Ticket

    @State private var isFlipped = false
    @State private var cardHeight: CGFloat = 0
    @State private var mapSnapshot: UIImage?
    @State private var mapCoordinate: CLLocationCoordinate2D?
    @State private var reminderEnabled: Bool = false
    @State private var scheduledReminderDate: Date?
    @State private var showEditNotes = false
    @State private var showDeleteConfirm = false
    @State private var showEditTicket = false
    @State private var editingNotes = ""
    @State private var expiryEditDraft: ExpiryEditDraft?

    // Wallet pass (re)generation — lets a save-only ticket get signed later.
    @AppStorage("signingNodePreference") private var nodeRaw = NodePreference.auto.rawValue
    @State private var isSigningWallet = false
    @State private var walletSigningError: String?
    @State private var pkpassData: Data?
    @State private var showWalletSheet = false

    private let hPad: CGFloat = AppSpacing.md   // 16pt — unified app-wide content margin
    private var isDark: Bool { true }
    private var theme: TicketTheme { ticket.ticketType.theme }

    var body: some View {
        ZStack {
            // Background: dark behind the header, fades to system background behind info cards.
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.56),
                    .init(color: Color(uiColor: .systemBackground), location: 0.70),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            gradientHeader.ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    navigationBar
                    flippableCard
                    flipHint
                    infoCard
                    openWalletButton
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .task {
            reminderEnabled = ticket.reminderEnabled
            editingNotes = ticket.notes
            scheduledReminderDate = ReminderService.reminderDate(for: TicketSnapshot(ticket: ticket))
            await loadMapSnapshot()
            // F2: sync isAddedToWallet with actual PKPassLibrary state
            syncWalletStatus()
        }
        .fullScreenCover(isPresented: $showEditTicket) {
            RecognitionConfirmView(ticket: ticket, mode: .edit)
        }
        .sheet(item: $expiryEditDraft) { draft in
            ExpiryEditorSheet(
                draft: draft,
                accent: theme.accent,
                onCancel: { expiryEditDraft = nil },
                onSave: saveEditedExpiry
            )
        }
        .sheet(isPresented: $showWalletSheet) {
            if let data = pkpassData {
                WalletPresenter(passData: data) {
                    ticket.isAddedToWallet = true
                    try? modelContext.save()
                    showWalletSheet = false
                } onCancelled: {
                    showWalletSheet = false
                }
                .ignoresSafeArea()
            }
        }
        .alert("签名失败", isPresented: .constant(walletSigningError != nil), actions: {
            Button("确定") { walletSigningError = nil }
        }, message: {
            Text(walletSigningError ?? "")
        })
        .alert("编辑备注", isPresented: $showEditNotes) {
            TextField("备注内容", text: $editingNotes, axis: .vertical)
                .lineLimit(3...6)
            Button("保存") {
                ticket.notes = editingNotes
                try? modelContext.save()
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除票据", role: .destructive) {
                ReminderService.cancelReminder(ticketID: ticket.id)
                modelContext.delete(ticket)
                try? modelContext.save()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，票据将从 Passo 中永久删除")
        }
    }

    private func shareTicket() {
        let lines: [String] = [
            ticket.title,
            ticket.venue.isEmpty ? nil : "📍 \(ticket.venue)",
            ticket.eventDate.map { "📅 \($0.formatted(date: .abbreviated, time: .omitted))" },
            ticket.eventTime.isEmpty ? nil : "🕐 \(ticket.eventTime)",
            ticket.seatInfo.isEmpty ? nil : "💺 \(ticket.seatInfo)",
            ticket.barcodeValue.isEmpty ? nil : ticket.barcodeValue,
        ].compactMap { $0 }
        let text = lines.joined(separator: "\n")
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .rootViewController?.present(av, animated: true)
    }

    private func archiveTicket() {
        ticket.isArchived = true
        ticket.archivedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func restoreTicket() {
        ticket.isArchived = false
        ticket.isUsed     = false
        ticket.archivedAt = nil
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func syncWalletStatus() {
        guard let serial = ticket.passSerialNumber else { return }
        let typeID = "pass.com.passo.ticket"
        let library = PKPassLibrary()
        guard let pass = library.passes().first(where: {
            $0.serialNumber == serial && $0.passTypeIdentifier == typeID
        }) else { return }
        let inLibrary = library.containsPass(pass)
        if ticket.isAddedToWallet != inLibrary {
            ticket.isAddedToWallet = inLibrary
            try? modelContext.save()
        }
    }

    private func beginEditingExpiry() {
        let hasExpiry = ticket.expiresAt != nil
        let expiryDate = ticket.expiresAt
            ?? Ticket.defaultExpiry(for: ticket.ticketType, eventDate: ticket.eventDate)
            ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())
            ?? Date()
        expiryEditDraft = ExpiryEditDraft(
            hasExpiry: hasExpiry,
            expiryDate: expiryDate,
            isCurrentlyExpired: ticket.isExpired
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveEditedExpiry(hasExpiry: Bool, expiryDate: Date) {
        ticket.expiresAt = hasExpiry ? expiryDate : nil
        let shouldRescheduleReminder = hasExpiry && reminderEnabled
        if !hasExpiry {
            ticket.reminderEnabled = false
            ticket.reminderDate = nil
            reminderEnabled = false
            scheduledReminderDate = nil
            ReminderService.cancelReminder(ticketID: ticket.id)
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        expiryEditDraft = nil
        if shouldRescheduleReminder {
            Task { await toggleReminder(true) }
        }
    }

    // MARK: Gradient Header

    private var gradientHeader: some View {
        VStack {
            LinearGradient(
                colors: [theme.backgroundStart, theme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: UIScreen.main.bounds.height * 0.62)
            .overlay(
                // Ambient glow
                Circle()
                    .fill(theme.accent)
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                    .opacity(0.1)
                    .offset(x: 30, y: 60)
            )
            .animation(AppAnimation.themeChange, value: ticket.ticketType.rawValue)
            Spacer()
        }
    }

    // MARK: Navigation Bar

    private var navigationBar: some View {
        HStack {
            GlassPillButton(isDark: true, action: { dismiss() }) {
                AnyView(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
            }
            Spacer()
            Text("Pass 详情")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Menu {
                Button { shareTicket() } label: {
                    Label("分享票据", systemImage: "square.and.arrow.up")
                }
                Button { showEditTicket = true } label: {
                    Label("编辑票据", systemImage: "pencil")
                }
                Button { editingNotes = ticket.notes; showEditNotes = true } label: {
                    Label("编辑备注", systemImage: "square.and.pencil")
                }
                if ticket.isInArchive {
                    // Only offer restore when it can actually re-activate the item
                    // (auto-expired tickets stay archived — no misleading no-op).
                    if ticket.canRestore {
                        Button { restoreTicket() } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
                        }
                    }
                } else {
                    Button { archiveTicket() } label: {
                        Label("归档", systemImage: "archivebox")
                    }
                }
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    .frame(width: 44, height: 44)          // HIG 44pt hit target
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, hPad)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: Flippable Card

    private var flippableCard: some View {
        ZStack {
            // Front face — GeometryReader in background captures the rendered height
            // so we can pin the back face to exactly the same dimension.
            TicketCardView(ticket: ticket, size: .full, isDark: true, useStaticBackground: true)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { cardHeight = geo.size.height }
                    }
                )
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 0 : 1)

            // Back face — explicit height pins it to the front face measurement.
            cardBackFace
                .frame(
                    maxWidth: .infinity,
                    minHeight: cardHeight > 0 ? cardHeight : nil,
                    maxHeight: cardHeight > 0 ? cardHeight : nil
                )
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 1 : 0)
        }
        .animation(AppAnimation.cardFlip, value: isFlipped)
        .padding(.horizontal, hPad)
        .padding(.bottom, 4)
        .onTapGesture {
            isFlipped.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var cardBackFace: some View {
        GlassCardView(isDark: true, glowColor: theme.accent, useStaticBackground: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("备注 & 详情")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("点击翻回")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                backInfoBlock(title: "备注", content: ticket.notes.isEmpty ? "暂无备注" : ticket.notes)
                backInfoBlock(title: "原始条码", content: ticket.barcodeValue.isEmpty ? "—" : ticket.barcodeValue, isMonospaced: true)
                backInfoBlock(title: "来源", content: ticket.sourceApp.isEmpty ? "手动录入" : ticket.sourceApp)

                Spacer(minLength: 0)
            }
            // Padding before frame so the VStack fills (cardHeight - 2×padding),
            // matching the GlassCardView's proposed height exactly.
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func backInfoBlock(title: String, content: String, isMonospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Text(content)
                .font(isMonospaced
                    ? .system(size: 13, design: .monospaced)
                    : .system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .kerning(isMonospaced ? 1 : 0)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Flip Hint

    private var flipHint: some View {
        Text(isFlipped ? "← 点击翻回正面" : "点击卡片查看背面 →")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.bottom, 12)
    }

    // MARK: Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            mapPreview
            expiryRow
            Divider().padding(.horizontal, AppSpacing.md)
            reminderRow
            Divider().padding(.horizontal, AppSpacing.md)
            infoRow(systemIcon: "square.and.arrow.down", label: "来源", value: ticket.sourceApp.isEmpty ? "手动录入" : ticket.sourceApp)
        }
        // Stable full width — independent of whether the map is a placeholder or image.
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, hPad)
    }

    // MARK: M5 — Map Preview

    private var mapPreview: some View {
        Button {
            openInMaps()
        } label: {
            // Color.clear (flexible width, 0 ideal) defines the box size; the map
            // image and chrome are OVERLAYS, which never drive the host's layout —
            // so a wide scaledToFill snapshot can't widen the info card.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .overlay {
                    if let img = mapSnapshot {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: isDark
                                    ? [theme.backgroundStart.opacity(0.27), theme.backgroundEnd.opacity(0.27)]
                                    : [Color(hex: "#e8e6e0"), Color(hex: "#d4d1c9")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            if ticket.venueAddress.isEmpty && ticket.latitude == nil {
                                Label("暂无位置信息", systemImage: "map")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
                .overlay {
                    // Pin
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.accent)
                        .shadow(color: theme.accent.opacity(0.5), radius: 6)
                        .opacity(mapSnapshot != nil ? 1 : 0)
                }
                .overlay(alignment: .bottomTrailing) {
                    // "在地图中打开" hint
                    if mapSnapshot != nil {
                        Text("点击在地图中打开")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(AppSpacing.md)
        .disabled(mapCoordinate == nil && ticket.venueAddress.isEmpty)
    }

    private var expiryRow: some View {
        Button {
            beginEditingExpiry()
        } label: {
            HStack(spacing: 12) {
                iconTile("clock")
                VStack(alignment: .leading, spacing: 1) {
                    Text("过期时间")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(expiryText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detailExpiryRow")
        .accessibilityLabel("编辑过期时间")
    }

    private func loadMapSnapshot() async {
        // Resolve coordinate: use stored lat/lon, or geocode the address
        let coordinate: CLLocationCoordinate2D
        if let lat = ticket.latitude, let lon = ticket.longitude {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else if !ticket.venueAddress.isEmpty {
            guard let geocoded = await geocodeAddress(ticket.venueAddress) else { return }
            coordinate = geocoded
        } else if !ticket.venue.isEmpty {
            guard let geocoded = await geocodeAddress(ticket.venue) else { return }
            coordinate = geocoded
        } else {
            return
        }

        mapCoordinate = coordinate

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 600,
            longitudinalMeters: 600
        )
        options.size = CGSize(width: UIScreen.main.bounds.width - 40, height: 110)
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.showsBuildings = true

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return }

        // Draw pin on snapshot
        let image = UIGraphicsImageRenderer(size: options.size).image { _ in
            snapshot.image.draw(at: .zero)
            let point = snapshot.point(for: coordinate)
            let pin = UIImage(systemName: "mappin.circle.fill",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .regular))!
                .withTintColor(UIColor(theme.accent), renderingMode: .alwaysOriginal)
            pin.draw(at: CGPoint(x: point.x - pin.size.width / 2,
                                 y: point.y - pin.size.height))
        }

        mapSnapshot = image
    }

    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        try? await withCheckedThrowingContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, error in
                if let coord = placemarks?.first?.location?.coordinate {
                    continuation.resume(returning: coord)
                } else {
                    continuation.resume(throwing: error ?? URLError(.unknown))
                }
            }
        }
    }

    private func openInMaps() {
        guard let coord = mapCoordinate else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = ticket.venue.isEmpty ? ticket.title : ticket.venue
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: M4 — Reminder Row

    private var reminderRow: some View {
        HStack(spacing: 12) {
            iconTile(reminderEnabled ? "bell.badge" : "bell")

            VStack(alignment: .leading, spacing: 1) {
                Text("提醒")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if reminderEnabled, let date = scheduledReminderDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("未设置")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $reminderEnabled)
                .labelsHidden()
                .tint(theme.accent)
                .onChange(of: reminderEnabled) { _, enabled in
                    Task { await toggleReminder(enabled) }
                }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private func toggleReminder(_ enable: Bool) async {
        let snapshot = TicketSnapshot(ticket: ticket)
        if enable {
            let date = await ReminderService.scheduleReminder(snapshot: snapshot, ticketID: ticket.id)
            scheduledReminderDate = date
            ticket.reminderEnabled = date != nil
            ticket.reminderDate    = date
            if date == nil { reminderEnabled = false }
            if snapshot.latitude != nil || !snapshot.venueAddress.isEmpty {
                await ReminderService.scheduleLocationReminder(snapshot: snapshot, ticketID: ticket.id)
            }
        } else {
            ReminderService.cancelReminder(ticketID: ticket.id)
            ticket.reminderEnabled = false
            ticket.reminderDate    = nil
        }
        try? modelContext.save()
    }

    /// Themed SF Symbol tile — rounded square with the ticket's accent tint.
    /// Replaces ad-hoc emoji icons for a consistent, crisp look across info rows.
    private func iconTile(_ systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.accent.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.accent)
        }
    }

    private func infoRow(systemIcon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconTile(systemIcon)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: Open Wallet Button

    @ViewBuilder
    private var openWalletButton: some View {
        Group {
            if ticket.isAddedToWallet {
                Button {
                    UIApplication.shared.openWallet()
                } label: {
                    walletButtonLabel(icon: "wallet.pass", title: "在 Wallet 中查看")
                }
            } else {
                // Save-only ticket — offer to (re)generate the signed pass now.
                Button {
                    Task { await generateWalletPass() }
                } label: {
                    HStack(spacing: 8) {
                        if isSigningWallet {
                            ProgressView().tint(isDark ? .white : .black)
                        } else {
                            walletButtonLabel(icon: "wallet.pass.fill", title: "添加到 Wallet")
                        }
                    }
                }
                .disabled(isSigningWallet)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, 12)
        .padding(.bottom, 40)
    }

    private func walletButtonLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title).font(.system(size: 16, weight: .medium))
        }
        .foregroundStyle(isDark ? .white : .black)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(isDark ? Color(hex: "#2c2c2e") : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func generateWalletPass() async {
        isSigningWallet = true
        defer { isSigningWallet = false }
        if ticket.passSerialNumber == nil {
            ticket.passSerialNumber = UUID().uuidString
        }
        let snapshot = TicketSnapshot(ticket: ticket)
        let pref = NodePreference(rawValue: nodeRaw) ?? .auto
        do {
            pkpassData = try await SigningService.sign(snapshot: snapshot, nodePreference: pref)
            showWalletSheet = true
        } catch {
            walletSigningError = (error as? SigningError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Computed strings

    private var expiryText: String {
        guard let exp = ticket.expiresAt else { return "无过期时间" }
        return exp.formatted(date: .abbreviated, time: .shortened)
    }

}

private struct ExpiryEditDraft: Identifiable {
    let id = UUID()
    let hasExpiry: Bool
    let expiryDate: Date
    let isCurrentlyExpired: Bool
}

private struct ExpiryEditorSheet: View {
    let draft: ExpiryEditDraft
    let accent: Color
    let onCancel: () -> Void
    let onSave: (_ hasExpiry: Bool, _ expiryDate: Date) -> Void

    @State private var hasExpiry: Bool
    @State private var expiryDate: Date

    init(
        draft: ExpiryEditDraft,
        accent: Color,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ hasExpiry: Bool, _ expiryDate: Date) -> Void
    ) {
        self.draft = draft
        self.accent = accent
        self.onCancel = onCancel
        self.onSave = onSave
        _hasExpiry = State(initialValue: draft.hasExpiry)
        _expiryDate = State(initialValue: draft.expiryDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("设置过期时间", isOn: $hasExpiry)
                        .tint(accent)
                    if hasExpiry {
                        VStack {
                            DatePicker(
                                "过期时间",
                                selection: $expiryDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .accessibilityIdentifier("expiryDatePicker")
                        }
                    }
                } footer: {
                    if draft.isCurrentlyExpired && hasExpiry {
                        Text("保存未来时间后，非手动归档且未使用的票卡会回到有效列表。")
                    }
                }
            }
            .navigationTitle("编辑过期时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(hasExpiry, expiryDate) }
                }
            }
        }
    }
}
