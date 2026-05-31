import XCTest
@testable import Passo

/// TicketParser classification + field extraction (P1-1).
final class TicketParserTests: XCTestCase {

    func testClassifyByKeyword() {
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "IMAX 影厅 场次").ticketType, .movie)
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "G123 高铁 检票口").ticketType, .train)
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "会员 金卡 积分").ticketType, .member)
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "演唱会 大麦").ticketType, .concert)
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "故宫 博物院 游览").ticketType, .scenic)
        XCTAssertEqual(TicketParser.parse(barcodeValue: "", ocrText: "随便一些文字").ticketType, .generic)
    }

    /// Title extraction relies on per-line splitting — newline-joined OCR must work.
    func testTitleFromFirstMeaningfulLine() {
        let ocr = "订单号 20231101123456\n复仇者联盟\nIMAX 4 厅"
        let ticket = TicketParser.parse(barcodeValue: "", ocrText: ocr)
        XCTAssertEqual(ticket.title, "复仇者联盟")   // skips the order-number line
    }

    func testParseFillsDefaultExpiry() {
        // movie with an event date → expiresAt defaults to +1h, never nil.
        let ocr = "电影 影厅\n2030-06-01 19:30"
        let ticket = TicketParser.parse(barcodeValue: "X", ocrText: ocr)
        XCTAssertNotNil(ticket.expiresAt)
    }
}
