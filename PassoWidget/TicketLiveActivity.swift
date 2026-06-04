import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Ticket Live Activity

/// Lock-screen banner + Dynamic Island countdown for an upcoming ticket.
///
/// Theming reuses the shared `TicketType.theme.backgroundGradient`, so the live
/// surfaces match the in-app card palette. The countdown itself is rendered with
/// `Text(eventDate, style: .timer)`, which WidgetKit updates on-device without a
/// push — `ContentState` only carries the short status string.
struct TicketLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TicketActivityAttributes.self) { context in
            // Lock screen / banner presentation.
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let theme = context.attributes.ticketType.theme
            return DynamicIsland {
                // Expanded regions.
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.ticketType.emoji)
                        .font(.title2)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.eventDate, style: .timer)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: 78)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        if !context.attributes.venue.isEmpty {
                            Label(context.attributes.venue, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text(context.attributes.ticketType.emoji)
            } compactTrailing: {
                Text(context.attributes.eventDate, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: 52)
            } minimal: {
                Text(context.attributes.ticketType.emoji)
            }
            .keylineTint(theme.accent)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TicketActivityAttributes>

    private var theme: TicketTheme { context.attributes.ticketType.theme }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(context.attributes.ticketType.emoji)
                    Text(context.attributes.ticketType.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.18), in: Capsule())
                }

                Text(context.attributes.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !context.attributes.venue.isEmpty {
                    Label(context.attributes.venue, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(context.attributes.eventDate, style: .timer)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: 96)
                Text(context.state.status)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundGradient)
    }
}
