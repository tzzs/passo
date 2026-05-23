import SwiftUI
import UIKit
import PassKit
import MapKit

// MARK: - Pass Detail View

/// Immersive pass detail: full-width gradient header + 3D flip card + info rows.
/// Design reference: HiFiDetail in hifi-screens.jsx
struct PassDetailView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext

    let ticket: Ticket

    @State private var isFlipped = false
    @State private var mapSnapshot: UIImage?
    @State private var mapCoordinate: CLLocationCoordinate2D?
    @State private var reminderEnabled: Bool = false
    @State private var scheduledReminderDate: Date?
    @State private var showMenu = false
    @State private var showEditNotes = false
    @State private var showDeleteConfirm = false
    @State private var editingNotes = ""

    private var isDark: Bool { colorScheme == .dark }
    private var theme: TicketTheme { ticket.ticketType.theme }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
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
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .task {
            reminderEnabled = ticket.reminderEnabled
            editingNotes = ticket.notes
            scheduledReminderDate = ReminderService.reminderDate(for: TicketSnapshot(ticket: ticket))
            await loadMapSnapshot()
        }
        .confirmationDialog("操作", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("分享票据") { shareTicket() }
            Button("编辑备注") { editingNotes = ticket.notes; showEditNotes = true }
            Button("删除票据", role: .destructive) { showDeleteConfirm = true }
            Button("取消", role: .cancel) {}
        }
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

    // MARK: Background

    private var backgroundColor: Color {
        isDark ? Color.black : Color(uiColor: .systemGroupedBackground)
    }

    private var gradientHeader: some View {
        VStack {
            LinearGradient(
                colors: [theme.backgroundStart, theme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: UIScreen.main.bounds.height * 0.52)
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
            GlassPillButton(isDark: true, action: { showMenu = true }) {
                AnyView(
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 62)
        .padding(.bottom, 8)
    }

    // MARK: Flippable Card

    private var flippableCard: some View {
        ZStack {
            // Front face
            TicketCardView(ticket: ticket, size: .full, isDark: true)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 0 : 1)

            // Back face
            cardBackFace
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .opacity(isFlipped ? 1 : 0)
        }
        .animation(AppAnimation.cardFlip, value: isFlipped)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .onTapGesture {
            isFlipped.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var cardBackFace: some View {
        GlassCardView(isDark: true, glowColor: theme.accent) {
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
            }
            .padding(AppSpacing.md)
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
            infoRow(icon: "🕐", label: "过期时间", value: expiryText)
            Divider().padding(.horizontal, AppSpacing.md)
            reminderRow
            Divider().padding(.horizontal, AppSpacing.md)
            infoRow(icon: "📱", label: "来源",     value: ticket.sourceApp.isEmpty ? "手动录入" : ticket.sourceApp)
        }
        .background(Color(uiColor: isDark ? .secondarySystemBackground : .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: M5 — Map Preview

    private var mapPreview: some View {
        Button {
            openInMaps()
        } label: {
            ZStack {
                if let img = mapSnapshot {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Loading / no-location placeholder
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

                // Pin overlay
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.accent)
                    .shadow(color: theme.accent.opacity(0.5), radius: 6)
                    .opacity(mapSnapshot != nil ? 1 : 0)

                // "在地图中打开" hint
                if mapSnapshot != nil {
                    Text("点击在地图中打开")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(AppSpacing.md)
        .disabled(mapCoordinate == nil && ticket.venueAddress.isEmpty)
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
        options.size = CGSize(width: UIScreen.main.bounds.width - 32, height: 110)
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
            Text("🔔")
                .font(.system(size: 18))
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text("提醒")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if reminderEnabled, let date = scheduledReminderDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white : .black)
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

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isDark ? .white : .black)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: Open Wallet Button

    private var openWalletButton: some View {
        Button {
            UIApplication.shared.openWallet()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wallet.pass")
                Text("在 Wallet 中查看")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(isDark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isDark ? Color(hex: "#2c2c2e") : Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .padding(.bottom, 40)
        .disabled(!ticket.isAddedToWallet)
        .opacity(ticket.isAddedToWallet ? 1 : 0.4)
    }

    // MARK: Computed strings

    private var expiryText: String {
        guard let exp = ticket.expiresAt else { return "无过期时间" }
        return exp.formatted(date: .abbreviated, time: .shortened)
    }

}
