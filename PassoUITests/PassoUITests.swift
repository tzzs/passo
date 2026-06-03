import XCTest

@MainActor
final class PassoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -uitest skips first-launch onboarding for a deterministic start.
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 卡包 tab — membership card grid.
    func testCardsTab() throws {
        app.tabBars.buttons["卡包"].tap()
        sleep(1)
        snap("cards_tab")
        XCTAssertTrue(app.staticTexts["卡包"].exists)
    }

    /// 票据 · 全部 timeline via segment (stable accessibility id).
    func testAllTimeline() throws {
        let allSegment = app.buttons["segment.全部"]
        XCTAssertTrue(allSegment.waitForExistence(timeout: 2))
        allSegment.tap()
        sleep(1)
        snap("all_timeline")
    }

    /// 全部 mode exposes the search field.
    func testSearchFieldVisible() throws {
        app.buttons["segment.全部"].tap()
        XCTAssertTrue(app.textFields["ticketSearchField"].waitForExistence(timeout: 2))
    }

    /// Archive flow: swipe the top pile card to mark used → archive entry → archive view.
    func testArchiveFlow() throws {
        let card = app.descendants(matching: .any).matching(identifier: "topTicketCard").firstMatch
        if card.waitForExistence(timeout: 2) {
            let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            let end   = card.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
            sleep(1)
        }
        let archiveEntry = app.buttons["archiveEntry"].firstMatch
        if archiveEntry.waitForExistence(timeout: 2) {
            archiveEntry.tap()
            sleep(1)
            snap("archive_view")
        }
    }

    /// Renewal flow: an expired ticket in the archive exposes "编辑有效期",
    /// which opens the renewal sheet. Relies on the -uitest-seed-expired hook
    /// in PassoApp to guarantee a deterministic expired ticket.
    func testRenewalFlowFromArchive() throws {
        // setUp already launched without the seed; relaunch with it.
        app.terminate()
        app.launchArguments = ["-uitest", "-uitest-seed-expired"]
        app.launch()

        // Enter the archive from the 票据 tab.
        let archiveEntry = app.buttons["archiveEntry"].firstMatch
        XCTAssertTrue(archiveEntry.waitForExistence(timeout: 3), "archive entry should be reachable")
        archiveEntry.tap()

        // The seeded expired ticket should be listed.
        let row = app.staticTexts["已过期电影票"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3), "expired ticket should appear in the archive")

        // Leading swipe reveals the renewal action (expired ⇒ canRenew, not canRestore).
        row.swipeRight()
        let renewAction = app.buttons["编辑有效期"].firstMatch
        XCTAssertTrue(renewAction.waitForExistence(timeout: 2), "renewal swipe action should be offered")
        renewAction.tap()

        // The renewal sheet appears with its date picker and confirm button.
        XCTAssertTrue(app.staticTexts["选择新的有效期"].waitForExistence(timeout: 2), "renewal sheet should open")
        snap("renewal_sheet")
        XCTAssertTrue(app.buttons["续期"].waitForExistence(timeout: 2), "renew confirm button should be present")
    }

    /// Detail page width must stay stable when the async map snapshot loads
    /// (regression: scaledToFill snapshot widened the info card / ate the margins).
    func testDetailMapWidth() throws {
        let card = app.descendants(matching: .any).matching(identifier: "topTicketCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 2))
        card.tap()
        sleep(1)
        snap("detail_initial")    // map placeholder
        sleep(4)
        snap("detail_after_map")  // map loaded — width must be unchanged
    }
}
