import XCTest
@testable import SmartParking

final class PhraseLRUTests: XCTestCase {
    func testReadingMovesTheEntryToTheFront() {
        let cache = PhraseLRU<String, Int>(maxEntries: 3)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.set(3, for: "c")

        XCTAssertEqual(cache.value(for: "a"), 1)
        XCTAssertEqual(cache.keysByUse, ["a", "c", "b"])
    }

    func testTheLeastRecentlyUsedEntryLeavesWhenFull() {
        let cache = PhraseLRU<String, Int>(maxEntries: 2)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        _ = cache.value(for: "a")
        cache.set(3, for: "c")

        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "a"), 1)
        XCTAssertEqual(cache.value(for: "c"), 3)
        XCTAssertEqual(cache.count, 2)
    }

    func testWritingAnExistingKeyReplacesTheValueWithoutGrowing() {
        let cache = PhraseLRU<String, Int>(maxEntries: 2)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.set(10, for: "a")

        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.keysByUse, ["a", "b"])
        XCTAssertEqual(cache.value(for: "a"), 10)
    }

    func testOneEntryCacheKeepsOnlyTheLastOne() {
        let cache = PhraseLRU<String, Int>(maxEntries: 1)
        cache.set(1, for: "a")
        cache.set(2, for: "b")

        XCTAssertNil(cache.value(for: "a"))
        XCTAssertEqual(cache.keysByUse, ["b"])
    }

    func testTheInterpreterKeepsThirtyTwoPhrases() {
        XCTAssertEqual(PhraseInterpreter.maxEntries, 32)
    }
}
