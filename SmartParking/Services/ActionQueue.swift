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

    func enqueue(_ kind: PendingActionKind, reservationId: String) async throws
    func pendingActions() async throws -> [QueuedAction]
    func pendingActions(reservationId: String) async throws -> [QueuedAction]
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

    private let failureSubject = CurrentValueSubject<[ActionQueueFailure], Never>([])
    private let completionSubject = CurrentValueSubject<[ActionQueueCompletion], Never>([])
    private let pendingSubject = CurrentValueSubject<[QueuedAction], Never>([])

    private var connectivity: AnyCancellable?
    private var drainTask: Task<Void, Never>?

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
                Task {
                    await self?.drain()
                }
            }

        Task {
            await refreshPending()
        }
    }

    func enqueue(
        _ kind: PendingActionKind,
        reservationId: String
    ) async throws {
        try await store.enqueue(kind, reservationId: reservationId)
        await refreshPending()
    }

    func pendingActions() async throws -> [QueuedAction] {
        try await store.pending()
    }

    func pendingActions(
        reservationId: String
    ) async throws -> [QueuedAction] {
        try await store.pending(reservationId: reservationId)
    }

    func drain() async {
        if let existingTask = drainTask {
            await existingTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.drainPending()
            } catch {
                await self.refreshPending()
            }
        }

        drainTask = task
        await task.value
        drainTask = nil
    }

    private func drainPending() async throws {
        while let action = try await store.pending().first {
            switch await attempt(action) {
            case .completed:
                try await store.remove(id: action.id)

                reportCompletion(action)
                await refreshPending()

            case .rejected(let message):
                try await store.remove(id: action.id)

                reportFailure(action, message: message)
                await refreshPending()

            case .unauthorized:
                await refreshPending()
                return

            case .failed(let message):
                let attempts = try await store.incrementAttempts(id: action.id) ?? 0

                if attempts >= Self.maxAttempts {
                    try await store.remove(id: action.id)
                    reportFailure(action, message: message)
                }

                await refreshPending()
                return
            }
        }

        await refreshPending()
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

    private func refreshPending() async {
        do {
            pendingSubject.send(try await store.pending())
        } catch {
            // No reemplazamos el último estado conocido por una lista vacía.
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