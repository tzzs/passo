import SwiftUI
import SwiftData

// MARK: - Recognition Confirm View

/// Step 2: User confirms/edits OCR-extracted fields before generating a Wallet pass.
/// Design reference: HiFiConfirm in hifi-screens.jsx
struct RecognitionConfirmView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @Bindable var ticket: Ticket

    @State private var showAddedToast = false

    private var isDark: Bool { colorScheme == .dark }
    private var theme: TicketTheme { ticket.ticketType.theme }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationBar
                ticketPreview
                editableFieldsCard
                addToWalletButton
            }

            if showAddedToast { successToast }
        }
        .navigationBarHidden(true)
    }

    // MARK: Background

    private var background: some View {
        Group {
            if isDark {
                ZStack {
                    LinearGradient(
                        colors: [theme.backgroundStart, theme.backgroundEnd, Color.black],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.5, y: 0.5)
                    )
                    Color.black.opacity(0.5)
                        .offset(y: UIScreen.main.bounds.height * 0.3)
                }
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .animation(AppAnimation.themeChange, value: ticket.ticketType.rawValue)
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
            Text("确认信息")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 62)
        .padding(.bottom, 8)
    }

    // MARK: Ticket Preview (compact)

    private var ticketPreview: some View {
        TicketCardView(ticket: ticket, size: .compact, isDark: true)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .animation(AppAnimation.themeChange, value: ticket.ticketType.rawValue)
    }

    // MARK: Editable Fields Card

    private var editableFieldsCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Type selector
                typeSelector

                Divider().padding(.horizontal, AppSpacing.md)

                // Field rows
                fieldRow(icon: "🎬", label: "活动名称",  value: $ticket.title)
                Divider().padding(.horizontal, AppSpacing.md)
                fieldRow(icon: "📍", label: "场馆",      value: $ticket.venue)
                Divider().padding(.horizontal, AppSpacing.md)
                fieldRow(icon: "📅", label: "日期",      value: .constant(ticket.eventDate?.formatted(date: .abbreviated, time: .omitted) ?? ""))
                Divider().padding(.horizontal, AppSpacing.md)
                fieldRow(icon: "🕐", label: "时间",      value: $ticket.eventTime)
                Divider().padding(.horizontal, AppSpacing.md)
                fieldRow(icon: "💺", label: "座位",      value: $ticket.seatInfo)

                Divider().padding(.horizontal, AppSpacing.md)

                // Add custom field
                addFieldRow
            }
            .background(Color(uiColor: isDark ? .secondarySystemBackground : .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("票据类型")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TicketType.allCases, id: \.rawValue) { type in
                        typeChip(type)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 14)
    }

    private func typeChip(_ type: TicketType) -> some View {
        let isActive = type == ticket.ticketType
        let th = type.theme

        return Button {
            withAnimation(AppAnimation.themeChange) {
                ticket.ticketType = type
            }
        } label: {
            HStack(spacing: 4) {
                Text(type.emoji).font(.system(size: 13))
                Text(type.displayName).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? th.accent.opacity(0.1) : Color(uiColor: isDark ? .tertiarySystemBackground : .secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isActive ? th.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .foregroundStyle(isActive ? th.accent : (isDark ? Color.white : Color.black))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func fieldRow(icon: String, label: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField(label, text: value)
                    .font(.system(size: 16, weight: .medium))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private var addFieldRow: some View {
        Button { /* TODO: Add custom field */ } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: isDark ? .tertiarySystemBackground : .secondarySystemBackground))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                Text("添加自定义字段")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.accent)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: Add to Wallet Button

    private var addToWalletButton: some View {
        Button {
            addToWallet()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("添加到 Wallet")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(isDark ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isDark ? Color.white : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .padding(.bottom, 40)
    }

    // MARK: Success Toast

    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("已添加")
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(radius: 8, y: 4)
            .padding(.bottom, 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Actions

    private func addToWallet() {
        // TODO: call PassKit signing service
        ticket.passSerialNumber = UUID().uuidString
        ticket.isAddedToWallet = true
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation { showAddedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showAddedToast = false }
            dismiss()
        }
    }
}
