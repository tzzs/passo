import AppIntents
import Foundation
import SwiftData

// MARK: - Next Ticket Intent

/// Surfaces the user's next upcoming event ticket to Siri, Spotlight, and the
/// Shortcuts app. Runs fully on-device with no network access.
///
/// "Next upcoming" is defined inline here (deliberately not via a `Ticket`
/// helper) as: an item that is **not** a card, **not** in the archive, and has
/// the nearest *future* `eventDate`.
struct NextTicketIntent: AppIntent {

    static let title: LocalizedStringResource = "查看下一张票"

    static let description = IntentDescription(
        "告诉你下一张即将使用的票据，并可在 Passo 中打开它。",
        categoryName: "票据"
    )

    /// Bring Passo to the foreground after answering, so the user lands in the app.
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = try Self.fetchNextTicketSnapshot()

        guard let snapshot else {
            return .result(dialog: "你还没有即将使用的票")
        }

        return .result(dialog: IntentDialog(stringLiteral: snapshot.dialogText))
    }

    // MARK: - Data access

    /// Opens a fresh `ModelContainer` that mirrors the app's `main` configuration
    /// (`groupContainer: .none`, `cloudKitDatabase: .none`) so the intent reads the
    /// exact same local SQLite store, then returns a `Sendable` snapshot of the next
    /// upcoming ticket — or `nil` if there is none.
    ///
    /// A snapshot (rather than the `@Model` itself) crosses out of this scope so no
    /// non-`Sendable` SwiftData object escapes, keeping Swift 6 strict concurrency happy.
    @MainActor
    static func fetchNextTicketSnapshot() throws -> NextTicketSnapshot? {
        let config = ModelConfiguration(groupContainer: .none, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Ticket.self, configurations: config)
        let context = ModelContext(container)

        // Fetch all tickets and filter in memory: `isCard` / `isInArchive` are
        // computed properties (not stored), so they can't be expressed in a
        // #Predicate. The active ticket set is small, so this is cheap.
        let descriptor = FetchDescriptor<Ticket>()
        let tickets = try context.fetch(descriptor)

        let now = Date()
        let next = tickets
            .filter { !$0.isCard && !$0.isInArchive }
            .compactMap { ticket -> (Ticket, Date)? in
                guard let date = ticket.eventDate, date > now else { return nil }
                return (ticket, date)
            }
            .min { $0.1 < $1.1 }?
            .0

        guard let next else { return nil }
        return NextTicketSnapshot(ticket: next)
    }
}

// MARK: - Sendable snapshot

/// Immutable, `Sendable` projection of the fields the intent needs from a
/// `Ticket`, so nothing non-`Sendable` crosses an actor boundary.
struct NextTicketSnapshot: Sendable {
    let title: String
    let venue: String
    let eventDate: Date?

    init(ticket: Ticket) {
        self.title = ticket.title
        self.venue = ticket.venue
        self.eventDate = ticket.eventDate
    }

    /// Friendly Chinese dialog, e.g. "你的下一张票：奥本海默，万达影城，3 小时后".
    var dialogText: String {
        var parts: [String] = []

        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        parts.append(name.isEmpty ? "未命名票据" : name)

        let place = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !place.isEmpty {
            parts.append(place)
        }

        if let date = eventDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.unitsStyle = .full
            parts.append(formatter.localizedString(for: date, relativeTo: Date()))
        }

        return "你的下一张票：" + parts.joined(separator: "，")
    }
}
