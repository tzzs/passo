import XCTest
@testable import Passo

/// Free-tier import quota logic, centralized in StoreService (P1-3).
final class ImportQuotaTests: XCTestCase {

    func testProHasUnlimited() {
        let tickets = (0..<100).map { _ in Ticket() }
        XCTAssertEqual(StoreService.remainingFreeImports(isPro: true, tickets: tickets), .max)
        XCTAssertFalse(StoreService.isAtFreeImportLimit(isPro: true, tickets: tickets))
    }

    func testFreeTierCountsThisMonth() {
        // Fresh tickets default importedAt = now → all count toward this month.
        let four = (0..<4).map { _ in Ticket() }
        XCTAssertEqual(StoreService.remainingFreeImports(isPro: false, tickets: four), 1)
        XCTAssertFalse(StoreService.isAtFreeImportLimit(isPro: false, tickets: four))

        let five = (0..<5).map { _ in Ticket() }
        XCTAssertEqual(StoreService.remainingFreeImports(isPro: false, tickets: five), 0)
        XCTAssertTrue(StoreService.isAtFreeImportLimit(isPro: false, tickets: five))
    }

    func testLastMonthImportsDoNotCount() {
        let old = Ticket()
        old.importedAt = Date(timeIntervalSinceNow: -60 * 86_400)   // ~2 months ago
        XCTAssertEqual(
            StoreService.remainingFreeImports(isPro: false, tickets: [old]),
            StoreService.freeMonthlyImportLimit
        )
    }
}
