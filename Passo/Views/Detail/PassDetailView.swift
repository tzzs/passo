import SwiftUI
import PassKit

// MARK: - Pass Detail View

/// Immersive pass detail: full-width gradient header + 3D flip card + info rows.
/// Design reference: HiFiDetail in hifi-screens.jsx
struct PassDetailView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let ticket: Ticket

    @State private var isFlipped = false

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
            GlassPillButton(isDark: true, action: { }) {
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
            infoRow(icon: "🔔", label: "提醒",     value: reminderText)
            Divider().padding(.horizontal, AppSpacing.md)
            infoRow(icon: "📱", label: "来源",     value: ticket.sourceApp.isEmpty ? "手动录入" : ticket.sourceApp)
        }
        .background(Color(uiColor: isDark ? .secondarySystemBackground : .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, AppSpacing.md)
    }

    private var mapPreview: some View {
        ZStack {
            // Placeholder map gradient
            LinearGradient(
                colors: isDark
                    ? [theme.backgroundStart.opacity(0.27), theme.backgroundEnd.opacity(0.27)]
                    : [Color(hex: "#e8e6e0"), Color(hex: "#d4d1c9")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Sketchy road lines
            Canvas { context, size in
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: size.height * 0.5))
                    p.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.4),
                        control1: CGPoint(x: size.width * 0.3, y: size.height * 0.3),
                        control2: CGPoint(x: size.width * 0.7, y: size.height * 0.5)
                    )
                }
                context.stroke(path, with: .color(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)), lineWidth: 1)
            }

            // Location pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accent.opacity(0.4), radius: 8)

            // Walking distance badge
            if !ticket.venueAddress.isEmpty {
                Text("步行 ~8 分钟")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(AppSpacing.md)
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
            // TODO: open system Wallet app via pass URL scheme
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

    private var reminderText: String {
        guard ticket.reminderEnabled, let date = ticket.reminderDate else { return "未设置" }
        return date.formatted(date: .omitted, time: .shortened) + " 前提醒"
    }
}
