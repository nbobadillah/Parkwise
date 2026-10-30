import Combine
import Foundation

struct ActionQueueFailure: Equatable {
    let kind: PendingActionKind
    let reservationId: String
    let message: String
}

@MainActor
protocol ActionQueueing: AnyObject {
    var failures: AnyPublisher<ActionQueueFailure, Never> { get }
    func enqueue(_ kind: PendingActionKind, reservationId: String) async throws
    func drain() async
    func pending() async -> [QueuedAction]
}

@MainActor
final class ActionQueue: ActionQueueing {
    static let maxAttempts = 5

    private enum Outcome {
        case completed
        case rejected(String)
        case unauthorized
        case failed(String)
    }

    private let store: ActionQueueStore
    private let service: ReservationServicing
    private let failureSubject = PassthroughSubject<ActionQueueFailure, Never>()
    private var connectivity: AnyCancellable?
    private var drainTask: Task<Void, Never>?

    var failures: AnyPublisher<ActionQueueFailure, Never> {
        failureSubject.eraseToAnyPublisher()
    }

    init(store: ActionQueueStore, service: ReservationServicing, networkMonitor: NetworkMonitor = .shared) {
        self.store = store
        self.service = service
        connectivity = networkMonitor.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { await self?.drain() }
            }
    }

    func enqueue(_ kind: PendingActionKind, reservationId: String) async throws {
        try await store.enqueue(kind, reservationId: reservationId)
    }

    func drain() async {
        if let drainTask {
            await drainTask.value
            return
        }
        let task = Task { _ = try? await drainPending() }
        drainTask = task
        await task.value
        drainTask = nil
    }

    func pending() async -> [QueuedAction] {
        (try? await store.pending()) ?? []
    }

    private func drainPending() async throws {
        while let action = try await store.pending().first {
            switch await attempt(action) {
            case .completed:
                try await store.remove(id: action.id)
            case .rejected(let message):
                try await store.remove(id: action.id)
                report(action, message: message)
            case .unauthorized:
                return
            case .failed(let message):
                let attempts = try await store.incrementAttempts(id: action.id) ?? 0
                if attempts >= Self.maxAttempts {
                    try await store.remove(id: action.id)
                    report(action, message: message)
                }
                return
            }
        }
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
        } catch APIError.server(let status, let message) where (400..<500).contains(status) && status != 429 {
            return .rejected(message)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func report(_ action: QueuedAction, message: String) {
        failureSubject.send(
            ActionQueueFailure(kind: action.kind, reservationId: action.reservationId, message: message)
        )
    }
}
