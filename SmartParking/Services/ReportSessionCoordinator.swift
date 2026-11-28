import Foundation
import Combine

// MARK: - Submission result

struct ReportSubmission {
    let report: QueuedReport
    let state: ReportDeliveryState
}

// MARK: - History result

struct ReportHistoryResult {
    let reports: [SpotReport]
    let pending: [QueuedReport]
    let fetchedAt: Date?
    let isCached: Bool
    let warning: String?
}

// MARK: - Session coordinator

@MainActor
final class ReportSessionCoordinator: ObservableObject {

    @Published private(set) var activeUserId: String?
    @Published private(set) var isConnected: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = 0

    private struct Session: Equatable {
        let id = UUID()
        let userId: String
        let token: String
    }

    let draftStore = ReportDraftStore()

    private let networkMonitor: NetworkMonitor
    private let historyCache = ReportHistoryCache()
    private let photoCache = ReportPhotoCache()
    private let service: ReportServicing = BackendReportService()

    private var store: PendingReportStore?
    private var outbox: ReportOutbox?

    private var desiredSession: Session?
    private var installedSession: Session?

    private var reconciliationTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(networkMonitor: NetworkMonitor) {

        self.networkMonitor = networkMonitor
        isConnected = networkMonitor.isConnected

        observeConnectivity()
        observeOutbox()
    }

    // MARK: - Network monitoring

    private func observeConnectivity() {

        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] _ in

                Task { @MainActor [weak self] in
                    self?.networkChanged()
                }
            }
            .store(in: &subscriptions)
    }

    private func networkChanged() {

        let connected = networkMonitor.isConnected

        guard connected != isConnected else {
            return
        }

        isConnected = connected
        requestReconciliation()
    }

    // MARK: - Outbox observation

    private func observeOutbox() {

        NotificationCenter.default.publisher(
            for: .reportOutboxChanged
        )
        .sink { [weak self] _ in

            Task { @MainActor [weak self] in
                self?.revision &+= 1
            }
        }
        .store(in: &subscriptions)
    }

    // MARK: - Authentication

    func setSession(
        userId: String?,
        token: String?
    ) {

        if let userId,
           let token,
           !token.isEmpty {

            if desiredSession?.userId == userId,
               desiredSession?.token == token {

                requestReconciliation()
                return
            }

            desiredSession = Session(
                userId: userId,
                token: token
            )

        } else {

            desiredSession = nil
        }

        activeUserId = nil
        errorMessage = nil

        requestReconciliation()
    }

    func retrySession() {
        requestReconciliation()
    }

    // MARK: - Session reconciliation

    private func requestReconciliation() {

        guard reconciliationTask == nil else {
            return
        }

        reconciliationTask = Task { [weak self] in

            guard let self else {
                return
            }

            await self.reconcile()
        }
    }

    private func reconcile() async {

        defer {
            reconciliationTask = nil
        }

        while true {

            // Clean up the previous account before
            // activating another one.
            if let previous = installedSession,
               previous != desiredSession {

                activeUserId = nil

                do {

                    try await outbox?.deactivate()

                    // Ensure persistent cleanup also succeeds
                    // if a previous deactivation was interrupted.
                    try await store?.clear(
                        userId: previous.userId
                    )

                } catch {

                    errorMessage = error.localizedDescription
                    return
                }

                draftStore.clear(
                    userId: previous.userId
                )

                await historyCache.clear(
                    userId: previous.userId
                )

                await photoCache.clear(
                    userId: previous.userId
                )

                installedSession = nil

                continue
            }

            guard let target = desiredSession else {
                activeUserId = nil
                return
            }

            // Create the persistent store outside
            // the main actor.
            if outbox == nil {

                do {

                    let newStore = try await Task.detached(
                        priority: .utility
                    ) {
                        try PendingReportStore.make()
                    }.value

                    store = newStore

                    outbox = ReportOutbox(
                        store: newStore,
                        historyCache: historyCache
                    )

                } catch {

                    errorMessage = error.localizedDescription
                    return
                }

                continue
            }

            guard let outbox else {
                return
            }

            // Restore pending reports before enabling
            // network synchronization.
            if installedSession == nil {

                do {

                    try await outbox.activate(
                        userId: target.userId,
                        token: target.token,
                        connected: false
                    )

                    installedSession = target

                } catch {

                    errorMessage = error.localizedDescription
                    return
                }

                continue
            }

            let connected = isConnected

            await outbox.setConnected(connected)

            // The session or connection may have changed
            // while awaiting an actor operation.
            guard desiredSession == target,
                  connected == isConnected else {
                continue
            }

            activeUserId = target.userId
            errorMessage = nil

            return
        }
    }

    // MARK: - Submit report

    func submit(
        userId: String,
        spot: ReportSpot,
        kind: ReportKind,
        note: String?,
        photo: Data?
    ) async throws -> ReportSubmission {

        let (session, outbox) = try requireSession(
            userId: userId
        )

        let queued = try await outbox.enqueue(
            userId: userId,
            spot: spot,
            kind: kind,
            note: note,
            photo: photo
        )

        try verifySession(session)

        // Offline reports are already safely stored.
        // Online reports are sent immediately.
        if isConnected {
            await outbox.flush()
        }

        try verifySession(session)

        let sent = try await outbox.sentReports(
            userId: userId
        )

        try verifySession(session)

        if sent.contains(where: {
            $0.clientId.lowercased() ==
            queued.clientId.uuidString.lowercased()
        }) {

            return ReportSubmission(
                report: queued,
                state: .sent
            )
        }

        let pending = try await outbox.pending(
            userId: userId
        )

        try verifySession(session)

        let state = pending.first {
            $0.clientId == queued.clientId
        }?.state ?? .waiting

        return ReportSubmission(
            report: queued,
            state: state
        )
    }

    // MARK: - Load history

    func loadHistory(
        userId: String,
        force: Bool = false
    ) async throws -> ReportHistoryResult {

        let (session, outbox) = try requireSession(
            userId: userId
        )

        // Read pending reports and cached history
        // concurrently.
        async let localPending = outbox.pending(
            userId: userId
        )

        async let localHistory = historyCache.load(
            userId: userId
        )

        var snapshot = await localHistory

        try verifySession(session)

        var warning: String?

        // Avoid unnecessary server requests for 60 seconds.
        if isConnected && (force || !snapshot.isFresh) {

            do {

                let reports = try await service.mine(
                    token: session.token
                )

                try verifySession(session)

                snapshot = await historyCache.save(
                    reports,
                    userId: userId
                )

            } catch {

                try verifySession(session)

                warning = error.localizedDescription
            }
        }

        try verifySession(session)

        // Include recently accepted reports even when
        // the server history has not been refreshed.
        let recent = try await outbox.sentReports(
            userId: userId
        )

        try verifySession(session)

        snapshot = await historyCache.mergeSent(
            recent,
            userId: userId
        )

        let pending = try await localPending

        try verifySession(session)

        return ReportHistoryResult(
            reports: snapshot.reports,
            pending: pending,
            fetchedAt: snapshot.fetchedAt,
            isCached: !isConnected || warning != nil,
            warning: warning
        )
    }

    // MARK: - Manual synchronization

    func synchronize(userId: String) async throws {

        let (session, outbox) = try requireSession(
            userId: userId
        )

        await outbox.flush()

        try verifySession(session)
    }

    // MARK: - Pending report photo

    func pendingPhoto(
        clientId: UUID,
        userId: String
    ) async throws -> Data? {

        let (session, outbox) = try requireSession(
            userId: userId
        )

        let data = try await outbox.photoData(
            clientId: clientId,
            userId: userId
        )

        try verifySession(session)

        return data
    }

    // MARK: - Sent report photo

    func reportPhoto(
        for report: SpotReport,
        userId: String
    ) async throws -> Data {

        let (session, _) = try requireSession(
            userId: userId
        )

        let data = try await photoCache.photo(
            for: report,
            userId: userId,
            token: session.token,
            connected: isConnected
        )

        try verifySession(session)

        return data
    }

    // MARK: - Session validation

    private func requireSession(
        userId: String
    ) throws -> (Session, ReportOutbox) {

        guard let session = installedSession,
              session == desiredSession,
              activeUserId == userId,
              session.userId == userId,
              let outbox else {

            throw ReportOutboxError.noSession
        }

        return (session, outbox)
    }

    private func verifySession(
        _ session: Session
    ) throws {

        try Task.checkCancellation()

        guard installedSession == session,
              desiredSession == session,
              activeUserId == session.userId else {

            throw ReportOutboxError.noSession
        }
    }
}