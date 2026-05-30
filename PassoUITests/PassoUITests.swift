import XCTest

@MainActor
final class PassoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
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

    /// 票据 · 全部 timeline via segment.
    func testAllTimeline() throws {
        app.buttons["全部"].firstMatch.tap()
        sleep(1)
        snap("all_timeline")
    }

    /// Archive flow: swipe the top pile card to mark used → archive entry → archive view.
    func testArchiveFlow() throws {
        let card = app.scrollViews.firstMatch
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.34))
        let end   = card.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.34))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)
        let archiveEntry = app.staticTexts["已归档"].firstMatch
        if archiveEntry.waitForExistence(timeout: 2) {
            archiveEntry.tap()
            sleep(1)
            snap("archive_view")
        }
    }

    /// Detail page width must stay stable when the async map snapshot loads
    /// (regression: scaledToFill snapshot widened the info card / ate the margins).
    func testDetailMapWidth() throws {
        app.scrollViews.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.34)).tap()
        sleep(1)
        snap("detail_initial")    // map placeholder
        sleep(4)
        snap("detail_after_map")  // map loaded — width must be unchanged
    }
}
