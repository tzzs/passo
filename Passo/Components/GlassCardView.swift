import SwiftUI

// MARK: - Glass Card

/// Glassmorphism container: .ultraThinMaterial + 1pt highlight stroke + multi-layer shadow.
/// Mirrors the GlassCard component in the design prototype.
struct GlassCardView<Content: View>: View {
    let isDark: Bool
    let glowColor: Color?
    let content: () -> Content

    init(
        isDark: Bool = true,
        glowColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isDark    = isDark
        self.glowColor = glowColor
        self.content   = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .background(
                    isDark
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.55)
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.radiusCard)
                        .strokeBorder(
                            Color.white.opacity(isDark ? 0.15 : 0.45),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: glowColor?.opacity(0.27) ?? Color.black.opacity(isDark ? 0.3 : 0.08),
                    radius: 20,
                    x: 0, y: 8
                )
                .shadow(
                    color: Color.black.opacity(isDark ? 0.2 : 0.04),
                    radius: 4,
                    x: 0, y: 2
                )

            // Top 1pt highlight line (inset from edges)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(isDark ? 0.2 : 0.6))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, 0)
        }
    }
}

// MARK: - Glass Pill Button

/// 40×40 circular glass button, used for nav back/more buttons.
struct GlassPillButton: View {
    let isDark: Bool
    let action: () -> Void
    let icon: () -> AnyView

    var body: some View {
        Button(action: action) {
            icon()
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.05))
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    Color.white.opacity(isDark ? 0.15 : 0.4),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.06), radius: 4, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Segmented Control

/// Horizontal segmented control with glass background.
/// Used in WalletView (今天 / 即将 / 全部).
struct GlassSegmentedControl: View {
    let items: [String]
    @Binding var selectedIndex: Int
    let isDark: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = i
                    }
                } label: {
                    Text(items[i])
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedIndex == i
                                ? (isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.85))
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(
                            isDark ? Color.white : Color.black
                        )
                        .opacity(selectedIndex == i ? 1 : 0.6)
                        .shadow(
                            color: .black.opacity(selectedIndex == i ? 0.15 : 0),
                            radius: 4, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(isDark ? 0.08 : 0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Type Badge

/// Small pill badge showing ticket type + emoji.
struct TicketTypeBadge: View {
    let type: TicketType

    var body: some View {
        HStack(spacing: 4) {
            Text(type.emoji)
                .font(.system(size: 12))
            Text(type.displayName)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(type.theme.accent.opacity(0.13))
        .overlay(
            Capsule()
                .strokeBorder(type.theme.accent.opacity(0.34), lineWidth: 1)
        )
        .foregroundStyle(type.theme.accent)
        .clipShape(Capsule())
    }
}
