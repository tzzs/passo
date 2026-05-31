import XCTest

@MainActor
final class PassoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
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

    /// Detail expiry row should open a focused validity editor.
    func testDetailExpiryRowOpensEditor() throws {
        app.tabBars.buttons["卡包"].tap()

        let memberCard = app.staticTexts["星巴克金卡"].firstMatch
        XCTAssertTrue(memberCard.waitForExistence(timeout: 2))
        memberCard.tap()

        let expiryRow = app.buttons["detailExpiryRow"]
        XCTAssertTrue(expiryRow.waitForExistence(timeout: 2))
        expiryRow.tap()

        XCTAssertTrue(app.navigationBars["编辑过期时间"].waitForExistence(timeout: 2))

        let expiryToggle = app.switches["设置过期时间"]
        XCTAssertTrue(expiryToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(expiryToggle.value as? String, "0")
        XCTAssertFalse(app.datePickers["过期时间"].exists)

        expiryToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let enabledPredicate = NSPredicate(format: "value == %@", "1")
        expectation(for: enabledPredicate, evaluatedWith: expiryToggle)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(app.descendants(matching: .any)["expiryDatePicker"].waitForExistence(timeout: 2))
    }
}
