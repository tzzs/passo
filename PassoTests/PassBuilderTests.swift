import XCTest
@testable import Passo

/// Verifies the pass.json shape required by PassKit (P0-3).
final class PassBuilderTests: XCTestCase {

    private func buildJSON(_ ticket: Ticket) throws -> [String: Any] {
        let data = try PassBuilder.buildPassJSON(
            snapshot: TicketSnapshot(ticket: ticket),
            teamIdentifier: "TEAMID",
            passTypeIdentifier: "pass.com.passo.ticket"
        )
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testLegacyBarcodeIsSingleDictAndBarcodesIsArray() throws {
        let t = Ticket(ticketType: .movie, barcodeValue: "ABC123", barcodeFormat: "QR")
        let json = try buildJSON(t)

        // legacy `barcode` must be a single dict, not an array
        XCTAssertTrue(json["barcode"] is [String: Any])
        // modern `barcodes` must be an array
        XCTAssertTrue(json["barcodes"] is [[String: Any]])
    }

    func testEmptyBarcodeOmitsBarcodeKeys() throws {
        let t = Ticket(ticketType: .movie, barcodeValue: "")
        let json = try buildJSON(t)
        XCTAssertNil(json["barcode"])
        XCTAssertNil(json["barcodes"])
    }

    func testBoardingPassHasTransitType() throws {
        let t = Ticket(ticketType: .train, barcodeValue: "X")
        let json = try buildJSON(t)
        let boarding = try XCTUnwrap(json["boardingPass"] as? [String: Any])
        XCTAssertEqual(boarding["transitType"] as? String, "PKTransitTypeTrain")
    }

    func testNonBoardingPassHasNoTransitType() throws {
        let t = Ticket(ticketType: .movie, barcodeValue: "X")
        let json = try buildJSON(t)
        let event = try XCTUnwrap(json["eventTicket"] as? [String: Any])
        XCTAssertNil(event["transitType"])
    }

    func testColorsPresent() throws {
        let t = Ticket(ticketType: .member, barcodeValue: "X")
        let json = try buildJSON(t)
        XCTAssertEqual(json["foregroundColor"] as? String, "rgb(255, 255, 255)")
        XCTAssertNotNil(json["backgroundColor"] as? String)
        XCTAssertNotNil(json["labelColor"] as? String)
        // member → storeCard style
        XCTAssertNotNil(json["storeCard"])
    }
}
