import Combine
import Foundation

struct ActionQueueFailure: Equatable {
    let kind: PendingActionKind
    let reservationId: String
    let message: String
}

struct ActionQueueCompletion: Equatable {
    let kind: PendingActionKind
    let reservationId: String
    let completedAt: Date
}

@MainActor
protocol ActionQueueing: AnyObject {
    var failures: AnyPublisher<[ActionQueueFailure], Never> { get }
    var completions: AnyPublisher<[ActionQueueCompletion], Never> { get }
    var pendingChanges: AnyPublisher<[QueuedAction], Never> { get }

    func setActiveUser(_ userId: String?)
    func enqueue(_ kind: PendingActionKind, reservationId: String) async throws
    func pendingActions() async throws -> [QueuedAction]
    func pendingActions(reservationId: String) async throws -> [QueuedAction]
    func retry(id: UUID) async
    func drain() async
}

@MainActor
final class ActionQueue: ActionQueueing {
    static let maxAttempts = 5
    private static let maxRecentResults = 20

    private enum Outcome {
        case completed
        case rejected(String)
        case unauthorized
        case failed(String)
    }

    private let store: ActionQueueStore
    private let service: ReservationServicing

    private var activeUserId: String?

    private let failureSubject = CurrentValueSubject<[ActionQueueFailure], Never>([])
    private let completionSubject = CurrentValueSubject<[ActionQueueCompletion], Never>([])
    private let pendingSubject = CurrentValueSubject<[QueuedAction], Never>([])

    private var connectivity: AnyCancellable?

    // Identifica la ejecución de cola asociada a una sesión.
    private var drainTask: Task<Void, Never>?
    private var drainTaskId: UUID?
    private var drainTaskUserId: String?

    var failures: AnyPublisher<[ActionQueueFailure], Never> {
        failureSubject.eraseToAnyPublisher()
    }

    var completions: AnyPublisher<[ActionQueueCompletion], Never> {
        completionSubject.eraseToAnyPublisher()
    }

    var pendingChanges: AnyPublisher<[QueuedAction], Never> {
        pendingSubject.eraseToAnyPublisher()
    }

    init(
        store: ActionQueueStore,
        service: ReservationServicing,
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.store = store
        self.service = service

        connectivity = networkMonitor.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.drain()
                }
            }
    }

    func setActiveUser(_ userId: String?) {
        guard activeUserId != userId else {
            return
        }

        activeUserId = userId

        // No mostramos resultados de la cuenta anterior.
        failureSubject.send([])
        completionSubject.send([])
        pendingSubject.send([])

        // Invalidamos la ejecución anterior. Aunque la petición de red
        // termine después, no podrá modificar acciones de otra sesión.
        drainTask?.cancel()
        drainTask = nil
        drainTaskId = nil
        drainTaskUserId = nil

        guard let userId else {
            return
        }

        Task { @MainActor in
            await refreshPending(for: userId)

            guard activeUserId == userId else {
                return
            }

            await drain()
        }
    }

    func enqueue(
        _ kind: PendingActionKind,
        reservationId: String
    ) async throws {
        guard let userId = activeUserId else {
            return
        }

        try await store.enqueue(
            kind,
            reservationId: reservationId,
            userId: userId
        )

        await refreshPending(for: userId)

        guard activeUserId == userId else {
            return
        }

        await drain()
    }

    func pendingActions() async throws -> [QueuedAction] {
        guard let userId = activeUserId else {
            return []
        }

        return try await store.pending(userId: userId)
    }

    func pendingActions(
        reservationId: String
    ) async throws -> [QueuedAction] {
        guard let userId = activeUserId else {
            return []
        }

        return try await store.pending(
            reservationId: reservationId,
            userId: userId
        )
    }

    func retry(id: UUID) async {
        guard let userId = activeUserId else {
            return
        }

        do {
            try await store.retry(id: id, userId: userId)
            await refreshPending(for: userId)

            guard activeUserId == userId else {
                return
            }

            await drain()
        } catch {
            await refreshPending(for: userId)
        }
    }

    func drain() async {
        guard let userId = activeUserId else {
            return
        }

        if let existingTask = drainTask,
           drainTaskUserId == userId {
            await existingTask.value
            return
        }

        // Si pertenece a otra sesión, no esperamos a que termine.
        drainTask?.cancel()

        let taskId = UUID()

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.drainPending(
                    userId: userId,
                    taskId: taskId
                )
            } catch {
                await self.refreshPending(for: userId)
            }
        }

        drainTask = task
        drainTaskId = taskId
        drainTaskUserId = userId

        await task.value

        // Una tarea antigua no debe limpiar el identificador
        // de una ejecución nueva.
        if drainTaskId == taskId {
            drainTask = nil
            drainTaskId = nil
            drainTaskUserId = nil
        }
    }

    private func drainPending(
        userId: String,
        taskId: UUID
    ) async throws {
        while isCurrentSession(userId, taskId: taskId) {
            let actions = try await store.pending(userId: userId)

            guard isCurrentSession(userId, taskId: taskId) else {
                break
            }

            // Las acciones fallidas requieren reintento manual.
            guard let action = actions.first(where: { !$0.isFailed }) else {
                break
            }

            let outcome = await attempt(action)

            guard isCurrentSession(userId, taskId: taskId) else {
                break
            }

            switch outcome {
            case .completed:
                try await store.remove(
                    id: action.id,
                    userId: userId
                )

                guard isCurrentSession(userId, taskId: taskId) else {
                    break
                }

                reportCompletion(action)
                await refreshPending(for: userId)

            case .rejected(let message):
                try await store.markFailed(
                    id: action.id,
                    userId: userId,
                    message: message
                )

                guard isCurrentSession(userId, taskId: taskId) else {
                    break
                }

                reportFailure(action, message: message)
                await refreshPending(for: userId)

            case .unauthorized:
                await refreshPending(for: userId)
                return

            case .failed(let message):
                let attempts = try await store.incrementAttempts(
                    id: action.id,
                    userId: userId
                ) ?? 0

                guard isCurrentSession(userId, taskId: taskId) else {
                    break
                }

                if attempts >= Self.maxAttempts {
                    try await store.markFailed(
                        id: action.id,
                        userId: userId,
                        message: message
                    )

                    guard isCurrentSession(userId, taskId: taskId) else {
                        break
                    }

                    reportFailure(action, message: message)
                }

                await refreshPending(for: userId)

                // Esperamos a una próxima reconexión o reintento manual.
                return
            }
        }

        await refreshPending(for: userId)
    }

    private func isCurrentSession(
        _ userId: String,
        taskId: UUID
    ) -> Bool {
        activeUserId == userId &&
        drainTaskId == taskId &&
        !Task.isCancelled
    }

    private func attempt(_ action: QueuedAction) async -> Outcome {
        do {
            switch action.kind {
            case .checkIn:
                _ = try await service.checkIn(id: action.reservationId)

            case .release:
                _ = try await service.release(id: action.reservationId)
            }

            return .completed

        } catch APIError.server(let status, _) where status == 401 {
            return .unauthorized

        } catch APIError.server(let status, let message)
            where (400..<500).contains(status) && status != 429 {
            return .rejected(message)

        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func refreshPending(for userId: String) async {
        guard activeUserId == userId else {
            return
        }

        do {
            let actions = try await store.pending(userId: userId)

            guard activeUserId == userId else {
                return
            }

            pendingSubject.send(actions)
        } catch {
            // Conservamos el último estado conocido.
        }
    }

    private func reportCompletion(_ action: QueuedAction) {
        var results = completionSubject.value

        results.insert(
            ActionQueueCompletion(
                kind: action.kind,
                reservationId: action.reservationId,
                completedAt: Date()
            ),
            at: 0
        )

        if results.count > Self.maxRecentResults {
            results = Array(results.prefix(Self.maxRecentResults))
        }

        completionSubject.send(results)
    }

    private func reportFailure(
        _ action: QueuedAction,
        message: String
    ) {
        var results = failureSubject.value

        results.insert(
            ActionQueueFailure(
                kind: action.kind,
                reservationId: action.reservationId,
                message: message
            ),
            at: 0
        )

        if results.count > Self.maxRecentResults {
            results = Array(results.prefix(Self.maxRecentResults))
        }

        failureSubject.send(results)
    }
}