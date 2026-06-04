import ActivityKit
import Foundation

// MARK: - Ticket Live Activity Attributes

/// Shared ActivityKit contract between the main app (which starts/updates/ends
/// the Live Activity) and the widget extension (which renders the lock-screen
/// banner + Dynamic Island).
///
/// This file is compiled into BOTH targets — the app picks it up via its
/// `Passo/` source glob, and the `PassoWidget` target lists it explicitly in
/// `project.yml`. Keep it dependency-free (Foundation + ActivityKit only) so it
/// stays portable across both processes.
struct TicketActivityAttributes: ActivityAttributes {

    /// Static attributes — fixed for the lifetime of the activity. These describe
    /// *which* ticket the countdown is for and never change once started.
    let title: String
    let venue: String
    let typeRaw: String
    let eventDate: Date

    /// Resolves the persisted `TicketType.rawValue` back to a theme-carrying enum,
    /// falling back to `.generic` for forward compatibility.
    var ticketType: TicketType { TicketType(rawValue: typeRaw) ?? .generic }

    /// Dynamic content — the only part ActivityKit re-renders on update. The live
    /// countdown itself is driven declaratively by `Text(eventDate, style: .timer)`
    /// in the views (no per-second push needed), so `ContentState` only carries a
    /// short human-readable status string the app can refresh as the event nears.
    struct ContentState: Codable, Hashable {
        var status: String
    }
}
