import XCTest
@testable import Passo

final class CardPaletteTests: XCTestCase {

    func testStableIndexIsDeterministicForKnownCardNames() {
        XCTAssertEqual(CardPalette.stableIndex(for: "星巴克 金星会员", upperBound: 8), 3)
        XCTAssertEqual(CardPalette.stableIndex(for: "山姆会员店", upperBound: 8), 7)
        XCTAssertEqual(CardPalette.stableIndex(for: "Apple Store", upperBound: 8), 6)
        XCTAssertEqual(CardPalette.stableIndex(for: "", upperBound: 8), 5)
    }

    func testStableIndexStaysInsideUpperBound() {
        for upperBound in 1...16 {
            let index = CardPalette.stableIndex(for: "健身房年卡", upperBound: upperBound)
            XCTAssertGreaterThanOrEqual(index, 0)
            XCTAssertLessThan(index, upperBound)
        }
    }

    func testPaletteReturnsOneOfCuratedPalettes() {
        XCTAssertTrue(CardPalette.all.contains(CardPalette.palette(for: "图书馆借阅证")))
    }
}
