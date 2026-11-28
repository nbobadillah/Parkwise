import Foundation
import SwiftData

@Model
final class RecentVoiceSearch {
    @Attribute(.unique) var phrase: String
    var searchedAt: Date

    init(phrase: String, searchedAt: Date) {
        self.phrase = phrase
        self.searchedAt = searchedAt
    }
}

struct RecentSearch: Identifiable, Equatable, Sendable {
    let phrase: String
    let searchedAt: Date

    var id: String {
        phrase
    }
}

protocol RecentSearchStoring: Sendable {
    func recent() async throws -> [RecentSearch]
    func save(_ phrase: String, at date: Date) async throws
}

actor RecentVoiceSearchStore: RecentSearchStoring {
    static let shared = RecentVoiceSearchStore()
    static let limit = 10

    private static let storeName = "RecentVoiceSearches"

    private let container: ModelContainer
    private lazy var context = ModelContext(container)

    init(container: ModelContainer = RecentVoiceSearchStore.makeContainer()) {
        self.container = container
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if !inMemory, let container = try? ModelContainer(
            for: RecentVoiceSearch.self,
            configurations: ModelConfiguration(storeName)
        ) {
            return container
        }
        return try! ModelContainer(
            for: RecentVoiceSearch.self,
            configurations: ModelConfiguration(storeName, isStoredInMemoryOnly: true)
        )
    }

    func recent() throws -> [RecentSearch] {
        try newestFirst().map { RecentSearch(phrase: $0.phrase, searchedAt: $0.searchedAt) }
    }

    func save(_ phrase: String, at date: Date) throws {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var same = FetchDescriptor<RecentVoiceSearch>(predicate: #Predicate { $0.phrase == trimmed })
        same.fetchLimit = 1
        if let saved = try context.fetch(same).first {
            saved.searchedAt = date
        } else {
            context.insert(RecentVoiceSearch(phrase: trimmed, searchedAt: date))
        }

        for old in try newestFirst().dropFirst(Self.limit) {
            context.delete(old)
        }
        try context.save()
    }

    private func newestFirst() throws -> [RecentVoiceSearch] {
        try context.fetch(FetchDescriptor<RecentVoiceSearch>(sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]))
    }
}
