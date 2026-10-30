import Foundation
import SwiftData

struct QueuedAction: Equatable, Sendable {
    let id: UUID
    let kind: PendingActionKind
    let reservationId: String
    let createdAt: Date
    let attempts: Int
}

actor ActionQueueStore {
    private static let storeName = "PendingActions"

    private let container: ModelContainer
    private lazy var context = ModelContext(container)

    init(container: ModelContainer = ActionQueueStore.makeContainer()) {
        self.container = container
    }

    static func makeContainer() -> ModelContainer {
        if let container = try? ModelContainer(
            for: PendingAction.self,
            configurations: ModelConfiguration(storeName)
        ) {
            return container
        }
        return try! ModelContainer(
            for: PendingAction.self,
            configurations: ModelConfiguration(storeName, isStoredInMemoryOnly: true)
        )
    }

    func enqueue(_ kind: PendingActionKind, reservationId: String) throws {
        let kindRawValue = kind.rawValue
        let duplicate = FetchDescriptor<PendingAction>(
            predicate: #Predicate { $0.kindRawValue == kindRawValue && $0.reservationId == reservationId }
        )
        guard try context.fetchCount(duplicate) == 0 else { return }
        context.insert(PendingAction(kind: kind, reservationId: reservationId))
        try context.save()
    }

    func pending() throws -> [QueuedAction] {
        let descriptor = FetchDescriptor<PendingAction>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).compactMap { action in
            guard let kind = action.kind else { return nil }
            return QueuedAction(
                id: action.id,
                kind: kind,
                reservationId: action.reservationId,
                createdAt: action.createdAt,
                attempts: action.attempts
            )
        }
    }

    func remove(id: UUID) throws {
        guard let action = try find(id: id) else { return }
        context.delete(action)
        try context.save()
    }

    func incrementAttempts(id: UUID) throws -> Int? {
        guard let action = try find(id: id) else { return nil }
        action.attempts += 1
        try context.save()
        return action.attempts
    }

    private func find(id: UUID) throws -> PendingAction? {
        var descriptor = FetchDescriptor<PendingAction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
