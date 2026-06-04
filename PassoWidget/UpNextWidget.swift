import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

/// A value snapshot for the widget timeline. WidgetKit serializes entries across
/// the process boundary, so this must be a plain value type — never a live
/// SwiftData `@Model`, which is reference-typed and bound to a ModelContext.
struct UpNextEntry: TimelineEntry {
    let date: Date
    let ticket: TicketSummary?
}

/// The minimal, Sendable projection of a Ticket the widget needs to render.
struct TicketSummary: Sendable {
    let title: String
    let venue: String
    let eventTime: String
    let eventDate: Date?
    let typeRaw: String

    var type: TicketType { TicketType(rawValue: typeRaw) ?? .generic }
}

// MARK: - Provider

struct UpNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry {
        UpNextEntry(date: Date(), ticket: TicketSummary(
            title: "时代巡回演唱会", venue: "梅赛德斯·奔驰中心", eventTime: "20:00",
            eventDate: Date().addingTimeInterval(3600), typeRaw: TicketType.concert.rawValue
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        completion(UpNextEntry(date: Date(), ticket: Self.loadUpNext()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let entry = UpNextEntry(date: Date(), ticket: Self.loadUpNext())
        // Refresh hourly so the card keeps pace as the event approaches / passes.
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    /// Opens the shared App Group store read-only and snapshots the up-next ticket.
    /// Uses `cloudKitDatabase: .none` — the widget only reads what the app has
    /// already mirrored into the local SQLite file, avoiding CloudKit in-process.
    static func loadUpNext() -> TicketSummary? {
        let config = ModelConfiguration(
            groupContainer: .identifier("group.com.passo.app"),
            cloudKitDatabase: .none
        )
        guard let container = try? ModelContainer(for: Ticket.self, configurations: config) else {
            return nil
        }
        let context = ModelContext(container)
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>())) ?? []
        guard let next = Ticket.upNext(from: tickets) else { return nil }
        return TicketSummary(
            title: next.title,
            venue: next.venue,
            eventTime: next.eventTime,
            eventDate: next.eventDate,
            typeRaw: next.ticketTypeRaw
        )
    }
}

// MARK: - View

struct UpNextWidgetView: View {
    let entry: UpNextEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let ticket = entry.ticket {
                content(ticket)
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            entry.ticket?.type.theme.backgroundGradient ?? TicketType.generic.theme.backgroundGradient
        }
    }

    private func content(_ ticket: TicketSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ticket.type.emoji)
                    .font(.system(size: family == .systemSmall ? 18 : 22))
                Spacer()
                Text(ticket.type.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.white.opacity(0.15), in: Capsule())
            }

            Spacer(minLength: 0)

            Text(ticket.title)
                .font(.system(size: family == .systemSmall ? 16 : 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            if !ticket.venue.isEmpty {
                Text(ticket.venue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            if let date = ticket.eventDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(date, style: .relative)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(ticket.type.theme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "ticket")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
            Text("暂无即将使用的票")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct UpNextWidget: Widget {
    let kind = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpNextProvider()) { entry in
            UpNextWidgetView(entry: entry)
        }
        .configurationDisplayName("即将使用")
        .description("显示你下一张要使用的票")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
