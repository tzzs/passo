import ActivityKit
import Foundation

// MARK: - Live Activity Service

/// Thin `@MainActor` wrapper around ActivityKit for the ticket countdown Live
/// Activity. Starting an activity needs values pulled from a `@Model` `Ticket`,
/// so we snapshot the relevant fields into plain `Sendable` values up front
/// (`TicketActivityAttributes` is a value type) and never hand the `Ticket`
/// itself across a concurrency boundary.
@MainActor
enum LiveActivityService {

    /// Whether the running OS + user settings permit Live Activities at all.
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts (or restarts) the lock-screen / Dynamic Island countdown for a
    /// ticket. No-op when the ticket has no future `eventDate`, is a card, or the
    /// user has Live Activities disabled. If an activity for this ticket is
    /// already running it is ended first so we don't stack duplicates.
    @discardableResult
    static func start(for ticket: Ticket) -> Bool {
        guard isAvailable else { return false }
        guard !ticket.isCard, let eventDate = ticket.eventDate, eventDate > Date() else {
            return false
        }

        let attributes = TicketActivityAttributes(
            title: ticket.title.isEmpty ? "票据" : ticket.title,
            venue: ticket.venue,
            typeRaw: ticket.ticketTypeRaw,
            eventDate: eventDate
        )
        let initialState = TicketActivityAttributes.ContentState(status: "即将开始")

        // Avoid duplicate activities for the same ticket.
        endAll()

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: eventDate),
                pushType: nil
            )
            return true
        } catch {
            return false
        }
    }

    /// Ends every running ticket Live Activity immediately.
    static func endAll() {
        let activities = Activity<TicketActivityAttributes>.activities
        Task.detached {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Whether any ticket Live Activity is currently running — drives the
    /// start/stop toggle in the detail view.
    static var hasActiveActivity: Bool {
        !Activity<TicketActivityAttributes>.activities.isEmpty
    }
}
