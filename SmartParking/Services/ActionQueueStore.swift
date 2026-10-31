import Foundation
import SwiftData

struct QueuedAction: Equatable, Sendable {
    let id: UUID
    let kind: PendingActionKind
    let reservationId: String
    let createdAt: Date
    let attempts: Int
    let userId: String?
    let failureMessage: String?
    let failedAt: Date?

    var isFailed: Bool {
        failureMessage != nil
    }
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
            configurations: ModelConfiguration(
                storeName,
                isStoredInMemoryOnly: true
            )
        )
    }

    // MARK: - Enqueue

    func enqueue(
        _ kind: PendingActionKind,
        reservationId: String,
        userId: String
    ) throws {
        let kindRawValue = kind.rawValue

        let duplicate = FetchDescriptor<PendingAction>(
            predicate: #Predicate {
                $0.kindRawValue == kindRawValue &&
                $0.reservationId == reservationId &&
                $0.userId == userId
            }
        )

        guard try context.fetchCount(duplicate) == 0 else {
            return
        }

        context.insert(
            PendingAction(
                kind: kind,
                reservationId: reservationId,
                userId: userId
            )
        )

        try context.save()
    }

    // MARK: - Fetch

    // Legacy: devuelve todas las acciones.
    // No utilizar para mostrar información de una sesión concreta.
    func pending() throws -> [QueuedAction] {
        let descriptor = FetchDescriptor<PendingAction>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        return try context.fetch(descriptor).compactMap {
            makeQueuedAction(from: $0)
        }
    }

    // Acciones pertenecientes a un usuario.
    func pending(userId: String) throws -> [QueuedAction] {
        let descriptor = FetchDescriptor<PendingAction>(
            predicate: #Predicate {
                $0.userId == userId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        return try context.fetch(descriptor).compactMap {
            makeQueuedAction(from: $0)
        }
    }

    // Legacy: filtra solo por reserva, no por usuario.
    func pending(reservationId: String) throws -> [QueuedAction] {
        let descriptor = FetchDescriptor<PendingAction>(
            predicate: #Predicate {
                $0.reservationId == reservationId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        return try context.fetch(descriptor).compactMap {
            makeQueuedAction(from: $0)
        }
    }

    // Acciones de una reserva pertenecientes a un usuario.
    func pending(
        reservationId: String,
        userId: String
    ) throws -> [QueuedAction] {
        let descriptor = FetchDescriptor<PendingAction>(
            predicate: #Predicate {
                $0.reservationId == reservationId &&
                $0.userId == userId
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        return try context.fetch(descriptor).compactMap {
            makeQueuedAction(from: $0)
        }
    }

    // MARK: - Remove

    func remove(id: UUID, userId: String) throws {
        guard let action = try find(id: id),
              action.userId == userId else {
            return
        }

        context.delete(action)
        try context.save()
    }

    // MARK: - Attempts

    func incrementAttempts(
        id: UUID,
        userId: String
    ) throws -> Int? {
        guard let action = try find(id: id),
              action.userId == userId else {
            return nil
        }

        action.attempts += 1
        try context.save()

        return action.attempts
    }

    // MARK: - Failure

    func markFailed(
        id: UUID,
        userId: String,
        message: String
    ) throws {
        guard let action = try find(id: id),
              action.userId == userId else {
            return
        }

        action.failureMessage = message
        action.failedAt = Date()

        try context.save()
    }

    // MARK: - Retry

    func retry(id: UUID, userId: String) throws {
        guard let action = try find(id: id),
              action.userId == userId else {
            return
        }

        action.attempts = 0
        action.failureMessage = nil
        action.failedAt = nil

        try context.save()
    }

    // MARK: - Mapping

    private func makeQueuedAction(
        from action: PendingAction
    ) -> QueuedAction? {
        guard let kind = action.kind else {
            return nil
        }

        return QueuedAction(
            id: action.id,
            kind: kind,
            reservationId: action.reservationId,
            createdAt: action.createdAt,
            attempts: action.attempts,
            userId: action.userId,
            failureMessage: action.failureMessage,
            failedAt: action.failedAt
        )
    }

    // MARK: - Internal lookup

    private func find(id: UUID) throws -> PendingAction? {
        var descriptor = FetchDescriptor<PendingAction>(
            predicate: #Predicate {
                $0.id == id
            }
        )

        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }
}