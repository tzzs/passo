import XCTest
@testable import Passo

/// Pure-logic tests for Ticket classification, archive, and expiry rules.
final class TicketModelTests: XCTestCase {

    // MARK: isCard — only .member is a card (P1-6)

    func testOnlyMemberIsCard() {
        XCTAssertTrue(Ticket(ticketType: .member).isCard)
        for type in [TicketType.movie, .concert, .train, .scenic, .generic] {
            XCTAssertFalse(Ticket(ticketType: type).isCard, "\(type) should not be a card")
        }
        // A dateless generic ticket must NOT auto-classify as a card.
        XCTAssertFalse(Ticket(ticketType: .generic, eventDate: nil).isCard)
    }

    // MARK: Archive bucketing + restore semantics (P0-6 / P0-7)

    func testIsInArchiveTriggers() {
        let used = Ticket(); used.isUsed = true
        XCTAssertTrue(used.isInArchive)

        let archived = Ticket(); archived.isArchived = true
        XCTAssertTrue(archived.isInArchive)

        let expired = Ticket(); expired.expiresAt = Date(timeIntervalSinceNow: -3600)
        XCTAssertTrue(expired.isExpired)
        XCTAssertTrue(expired.isInArchive)

        let active = Ticket(); active.expiresAt = Date(timeIntervalSinceNow: 3600)
        XCTAssertFalse(active.isInArchive)
    }

    func testCanRestoreOnlyWhenNotExpired() {
        // Used but not expired → restorable.
        let used = Ticket(); used.isUsed = true
        XCTAssertTrue(used.canRestore)

        // Expired → not restorable (can't un-expire).
        let expired = Ticket(); expired.isUsed = true
        expired.expiresAt = Date(timeIntervalSinceNow: -3600)
        XCTAssertFalse(expired.canRestore)

        // Active (not in archive) → nothing to restore.
        XCTAssertFalse(Ticket().canRestore)
    }

    // MARK: defaultExpiry per type (spec §4.4)

    func testDefaultExpiryRules() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar.current

        XCTAssertEqual(Ticket.defaultExpiry(for: .movie, eventDate: base),
                       cal.date(byAdding: .hour, value: 1, to: base))
        XCTAssertEqual(Ticket.defaultExpiry(for: .concert, eventDate: base),
                       cal.date(byAdding: .minute, value: 30, to: base))
        XCTAssertEqual(Ticket.defaultExpiry(for: .train, eventDate: base), base)
        XCTAssertEqual(Ticket.defaultExpiry(for: .scenic, eventDate: base),
                       cal.date(byAdding: .hour, value: 8, to: base))
        XCTAssertNil(Ticket.defaultExpiry(for: .member, eventDate: base))
        // No event date → 7-day fallback (non-nil).
        XCTAssertNotNil(Ticket.defaultExpiry(for: .movie, eventDate: nil))
    }
}
