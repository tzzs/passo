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

    // MARK: Detail map target selection

    func testMapPreviewUsesVenueAddressBeforeVenueForRegularTickets() {
        let ticket = Ticket(
            title: "奥本海默",
            venue: "万达影城 · 来福士店",
            ticketType: .movie,
            venueAddress: "上海市黄浦区西藏中路 268 号"
        )

        XCTAssertEqual(PassDetailMapTarget.previewQuery(for: ticket), "上海市黄浦区西藏中路 268 号")
    }

    func testMapPreviewFallsBackToVenueForRegularTickets() {
        let ticket = Ticket(
            title: "时代巡回演唱会",
            venue: "梅赛德斯·奔驰中心",
            ticketType: .concert
        )

        XCTAssertEqual(PassDetailMapTarget.previewQuery(for: ticket), "梅赛德斯·奔驰中心")
    }

    func testTrainMapPreviewUsesDestinationInsteadOfRouteVenue() {
        let ticket = Ticket(
            title: "G1234",
            venue: "北京南 → 上海虹桥",
            ticketType: .train,
            routeOrigin: "北京南",
            routeDestination: "上海虹桥"
        )

        XCTAssertEqual(PassDetailMapTarget.previewQuery(for: ticket), "上海虹桥")
        XCTAssertNotEqual(PassDetailMapTarget.previewQuery(for: ticket), "北京南 → 上海虹桥")
    }

    func testTrainMapPreviewFallsBackToOriginWhenDestinationMissing() {
        let ticket = Ticket(
            title: "G1234",
            venue: "北京南 → 上海虹桥",
            ticketType: .train,
            routeOrigin: "北京南"
        )

        XCTAssertEqual(PassDetailMapTarget.previewQuery(for: ticket), "北京南")
    }

    func testTrainMapsOpenModeUsesRouteWhenOriginAndDestinationExist() {
        let ticket = Ticket(
            title: "G1234",
            venue: "北京南 → 上海虹桥",
            ticketType: .train,
            routeOrigin: "北京南",
            routeDestination: "上海虹桥"
        )

        XCTAssertEqual(PassDetailMapTarget.openMode(for: ticket), .route(origin: "北京南", destination: "上海虹桥"))
    }

    // MARK: Renewal (P2-1)

    func testCanRenewOnlyWhenExpired() {
        let expired = Ticket(); expired.expiresAt = Date(timeIntervalSinceNow: -3600)
        XCTAssertTrue(expired.canRenew)

        let active = Ticket(); active.expiresAt = Date(timeIntervalSinceNow: 3600)
        XCTAssertFalse(active.canRenew)

        // No expiry date → nothing to renew.
        XCTAssertFalse(Ticket().canRenew)
    }

    func testRenewClearsArchiveFlagsAndSetsExpiry() {
        let ticket = Ticket(ticketType: .movie)
        ticket.isUsed = true
        ticket.isArchived = true
        ticket.archivedAt = Date()
        ticket.expiresAt = Date(timeIntervalSinceNow: -3600)
        XCTAssertTrue(ticket.isInArchive)

        let newExpiry = Date(timeIntervalSinceNow: 7 * 86_400)
        ticket.renew(until: newExpiry)

        XCTAssertEqual(ticket.expiresAt, newExpiry)
        XCTAssertFalse(ticket.isUsed)
        XCTAssertFalse(ticket.isArchived)
        XCTAssertNil(ticket.archivedAt)
        XCTAssertFalse(ticket.isInArchive)
        XCTAssertFalse(ticket.isExpired)
    }

    func testSuggestedRenewalDateSnapsToEndOfDay() {
        let cal = Calendar.current
        // A deliberately "odd" base time so we can prove the time gets rewritten.
        let base = cal.date(bySettingHour: 14, minute: 37, second: 52, of: Date())!
        for type in TicketType.allCases {
            let suggested = Ticket.suggestedRenewalDate(for: type, from: base)
            let comps = cal.dateComponents([.hour, .minute], from: suggested)
            XCTAssertEqual(comps.hour, 23, "\(type) should snap to end-of-day hour")
            XCTAssertEqual(comps.minute, 59, "\(type) should snap to end-of-day minute")
            XCTAssertGreaterThan(suggested, base, "\(type) renewal must be in the future")
        }
    }

    func testSuggestedRenewalDateUsesMonthHorizonForMembers() {
        let cal = Calendar.current
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let member = Ticket.suggestedRenewalDate(for: .member, from: base)
        let expectedDay = cal.date(byAdding: .month, value: 1, to: base)!
        XCTAssertTrue(cal.isDate(member, inSameDayAs: expectedDay),
                      "member renewal should land one month out")
    }

    func testSuggestedRenewalDateUsesShortHorizonForEvents() {
        let cal = Calendar.current
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let movie = Ticket.suggestedRenewalDate(for: .movie, from: base)
        let expectedDay = cal.date(byAdding: .day, value: 7, to: base)!
        XCTAssertTrue(cal.isDate(movie, inSameDayAs: expectedDay),
                      "movie renewal should land seven days out")
    }
}
