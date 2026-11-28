import XCTest
@testable import SmartParking

final class VoiceQueryParserTests: XCTestCase {
    func testSpanishPhraseFindsTheLevelAndTheTypeOfSpot() {
        let query = VoiceQueryParser.interpret("Puesto eléctrico en el P2")

        XCTAssertEqual(query.levelCode, "P2")
        XCTAssertEqual(query.filters, [.available, .electric])
        XCTAssertEqual(query.searchText, "P2")
        XCTAssertTrue(query.understood)
        XCTAssertEqual(query.findSpotFilter, .electric)
    }

    func testEnglishPhraseFindsTheZoneAndTheTypeOfSpot() {
        let query = VoiceQueryParser.interpret("Accessible spot in zone B")

        XCTAssertNil(query.levelCode)
        XCTAssertEqual(query.zone, "B")
        XCTAssertEqual(query.filters, [.available, .accessible])
        XCTAssertEqual(query.searchText, "B")
    }

    func testNumbersAndLettersSaidAsWordsAreUnderstood() {
        XCTAssertEqual(VoiceQueryParser.interpret("pe dos zona be").searchText, "P2 B")
        XCTAssertEqual(VoiceQueryParser.interpret("segundo piso").levelCode, "P2")
        XCTAssertEqual(VoiceQueryParser.interpret("spot on the third floor").levelCode, "P3")
        XCTAssertTrue(VoiceQueryParser.interpret("EV P3").filters.contains(.electric))
        XCTAssertTrue(VoiceQueryParser.interpret("VIP en P1").filters.contains(.vip))
    }

    func testFullSpotCodeBecomesTheCodeOfTheSpot() {
        XCTAssertEqual(VoiceQueryParser.interpret("P2-B-14").searchText, "P2 B B-14")

        let spoken = VoiceQueryParser.interpret("puesto 7 de la zona C en el nivel 3")
        XCTAssertEqual(spoken.levelCode, "P3")
        XCTAssertEqual(spoken.spotCode, "C-07")
        XCTAssertEqual(spoken.searchText, "P3 C C-07")
    }

    func testNumberWithoutZoneIsNotTakenAsASpot() {
        let query = VoiceQueryParser.interpret("spot 14 in P2")

        XCTAssertNil(query.spotCode)
        XCTAssertEqual(query.searchText, "P2")
    }

    func testPhraseWithoutLevelZoneOrTypeIsNotUnderstood() {
        let query = VoiceQueryParser.interpret("hola, cómo estás")

        XCTAssertFalse(query.understood)
        XCTAssertEqual(query.filters, [.available])
        XCTAssertEqual(query.searchText, "")
        XCTAssertEqual(query.findSpotFilter, .available)
    }

    func testChipsFollowTheOrderOfAndroid() {
        let query = VoiceQueryParser.interpret("puesto eléctrico accesible en el nivel P2 zona B")

        XCTAssertEqual(query.chips, ["Level P2", "Zone B", "Electric", "Accessible"])
        XCTAssertEqual(query.findSpotFilter, .electric)
    }

    func testNormalizedPhraseHasNoAccentsAndNumbersAsDigits() {
        XCTAssertEqual(VoiceQueryParser.normalized("Eléctrico en el Piso DOS"), "electrico en el piso 2")
    }

    func testTheActorGivesTheSameAnswerAsTheParser() async {
        let interpreter = PhraseInterpreter()
        let first = await interpreter.interpret("electric P2 zone A", language: .english)
        let again = await interpreter.interpret("Electric P2, zone A", language: .english)

        XCTAssertEqual(first, VoiceQueryParser.interpret("electric P2 zone A"))
        XCTAssertEqual(first, again)
    }
}
