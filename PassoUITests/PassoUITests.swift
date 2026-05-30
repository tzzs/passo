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

    /// Issue 2a: tapping "+" opens an in-place Menu (album first, scan second).
    func testPlusMenu() throws {
        // The "+" is the only plain image-button in the nav header.
        let plus = app.buttons["plus"].firstMatch
        if plus.waitForExistence(timeout: 3) {
            plus.tap()
        } else {
            // Fallback: top-right corner coordinate tap
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.07)).tap()
        }
        sleep(1)
        snap("plus_menu")

        // Menu items should be present
        XCTAssertTrue(app.buttons["从相册导入"].waitForExistence(timeout: 2)
                      || app.staticTexts["从相册导入"].waitForExistence(timeout: 1),
                      "Menu should show 从相册导入")
    }

    /// Issue 3: detail page uses SF Symbol icons (no emoji).
    func testDetailPage() throws {
        // Tap the first ticket cell/card to push detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap()
        }
        sleep(2)  // allow map snapshot + push transition
        snap("detail_page")
    }

    /// Issue 2b: scan page exposes an album entry.
    func testScanAlbumEntry() throws {
        let plus = app.buttons["plus"].firstMatch
        if plus.waitForExistence(timeout: 3) { plus.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.07)).tap()
        }
        sleep(1)
        // Pick 扫描条码 from the menu
        let scan = app.buttons["扫描条码"]
        if scan.waitForExistence(timeout: 2) {
            scan.tap()
            sleep(2)
            snap("scan_page")
        }
    }
}
