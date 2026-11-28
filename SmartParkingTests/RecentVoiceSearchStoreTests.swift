import XCTest
@testable import SmartParking

final class RecentVoiceSearchStoreTests: XCTestCase {
    func testKeepsTheLastTenNewestFirstAndARepeatOnlyUpdatesItsDate() async throws {
        let store = RecentVoiceSearchStore(container: RecentVoiceSearchStore.makeContainer(inMemory: true))
        let start = Date(timeIntervalSince1970: 1_000_000)

        for index in 0..<11 {
            try await store.save("phrase \(index)", at: start.addingTimeInterval(Double(index)))
        }
        try await store.save("phrase 5", at: start.addingTimeInterval(100))

        let recent = try await store.recent()
        XCTAssertEqual(recent.count, 10)
        XCTAssertEqual(recent.first?.phrase, "phrase 5")
        XCTAssertFalse(recent.contains { $0.phrase == "phrase 0" })
        XCTAssertEqual(recent.filter { $0.phrase == "phrase 5" }.count, 1)
    }
}
