import Foundation

extension Notification.Name {
    static let reportOutboxChanged =
        Notification.Name("reportOutboxChanged")
}

enum ReportOutboxError: LocalizedError {
    case noSession
    case sessionChanging

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "Sign in to report a parking spot."
        case .sessionChanging:
            return "The report session is changing. Try again."
        }
    }
}

actor ReportOutbox {

    private struct Session {
        let id = UUID()
        let userId: String
        let token: String
    }

    private let store: PendingReportStore
    private let service: ReportServicing
    private let historyCache: ReportHistoryCache

    private var session: Session?
    private var isConnected = false
    private var isChangingSession = false
    private var authenticationPaused = false

    private var drainTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var needsDrain = false

    private var recentSent: [SpotReport] = []

    init(
        store: PendingReportStore,
        service: ReportServicing = BackendReportService(),
        historyCache: ReportHistoryCache
    ) {
        self.store = store
        self.service = service
        self.historyCache = historyCache
    }

    // MARK: - Session lifecycle

    func activate(
        userId: String,
        token: String,
        connected: Bool
    ) async throws {

        guard !isChangingSession else {
            throw ReportOutboxError.sessionChanging
        }

        if let session {
            guard session.userId == userId,
                  session.token == token else {
                throw ReportOutboxError.sessionChanging
            }

            setConnected(connected)
            return
        }

        isChangingSession = true

        defer {
            isChangingSession = false
        }

        try await store.restoreInterruptedReports(
            userId: userId
        )

        session = Session(
            userId: userId,
            token: token
        )

        isConnected = connected
        authenticationPaused = false
        recentSent.removeAll()

        notifyChanged()
        kick()
    }

    func deactivate() async throws {

        guard !isChangingSession else {
            throw ReportOutboxError.sessionChanging
        }

        guard let previous = session else {
            return
        }

        isChangingSession = true

        defer {
            isChangingSession = false
        }

        session = nil
        isConnected = false
        authenticationPaused = false
        needsDrain = false

        recentSent.removeAll()

        cancelRetry()

        let running = drainTask

        running?.cancel()

        if let running {
            await running.value
        }

        notifyChanged()

        try await store.clear(
            userId: previous.userId
        )
    }

    // MARK: - Connectivity

    func setConnected(_ connected: Bool) {

        isConnected = connected

        if connected {
            kick()
        } else {
            cancelRetry()
        }

        notifyChanged()
    }

    // MARK: - Submit report

    func enqueue(
        userId: String,
        spot: ReportSpot,
        kind: ReportKind,
        note: String?,
        photo: Data?
    ) async throws -> QueuedReport {

        let current = try requireSession(
            userId: userId
        )

        let report = try await store.enqueue(
            userId: userId,
            spot: spot,
            kind: kind,
            note: note,
            photo: photo
        )

        guard session?.id == current.id else {
            throw ReportOutboxError.noSession
        }

        notifyChanged()
        kick()

        return report
    }

    // MARK: - Local reports

    func pending(
        userId: String
    ) async throws -> [QueuedReport] {

        let current = try requireSession(
            userId: userId
        )

        let reports = try await store.pending(
            userId: userId
        )

        guard session?.id == current.id else {
            throw ReportOutboxError.noSession
        }

        return reports
    }

    func sentReports(
        userId: String
    ) throws -> [SpotReport] {

        _ = try requireSession(userId: userId)

        return recentSent
    }

    func photoData(
        clientId: UUID,
        userId: String
    ) async throws -> Data? {

        let current = try requireSession(
            userId: userId
        )

        let data = try await store.photoData(
            clientId: clientId,
            userId: userId
        )

        guard session?.id == current.id else {
            throw ReportOutboxError.noSession
        }

        return data
    }

    // MARK: - Immediate synchronization

    func flush() async {

        cancelRetry()
        kick()

        while let running = drainTask {
            await running.value
        }
    }

    // MARK: - Sequential worker

    private func kick() {

        guard let current = session,
              isConnected,
              !authenticationPaused,
              retryTask == nil else {
            return
        }

        guard drainTask == nil else {
            needsDrain = true
            return
        }

        needsDrain = false

        drainTask = Task { [weak self] in
            guard let self else { return }

            await self.drain(
                sessionId: current.id
            )
        }
    }

    private func drain(
        sessionId: UUID
    ) async {

        var shouldRetry = false

        defer {
            drainTask = nil

            if session?.id == sessionId {

                if shouldRetry {
                    scheduleRetry(
                        sessionId: sessionId
                    )
                } else if needsDrain {
                    kick()
                }
            }
        }

        guard let current = session,
              current.id == sessionId else {
            return
        }

        do {

            // Recover a send interrupted by an app restart
            // or a previous persistence failure.
            try await store.restoreInterruptedReports(
                userId: current.userId
            )

            while canDrain(sessionId: sessionId) {

                let reports = try await store.pending(
                    userId: current.userId
                )

                guard canDrain(sessionId: sessionId) else {
                    return
                }

                guard let next = reports.first(
                    where: { $0.state == .waiting }
                ) else {
                    return
                }

                guard let sending = try await store.markSending(
                    clientId: next.clientId,
                    userId: current.userId
                ) else {
                    continue
                }

                notifyChanged()

                guard canDrain(sessionId: sessionId) else {

                    try await store.markWaiting(
                        clientId: sending.clientId,
                        userId: current.userId
                    )

                    notifyChanged()
                    return
                }

                let photo: Data?

                do {

                    photo = try await store.photoData(
                        clientId: sending.clientId,
                        userId: current.userId
                    )

                } catch {

                    guard session?.id == sessionId else {
                        return
                    }

                    try await store.markRejected(
                        clientId: sending.clientId,
                        userId: current.userId,
                        message: "Could not read the saved photo."
                    )

                    notifyChanged()
                    continue
                }

                guard canDrain(sessionId: sessionId) else {

                    try await store.markWaiting(
                        clientId: sending.clientId,
                        userId: current.userId
                    )

                    notifyChanged()
                    return
                }

                let request = ReportRequest(
                    clientId: sending.clientId.uuidString.lowercased(),
                    spotId: sending.spotId,
                    kind: sending.kind,
                    shownStatus: sending.shownStatus,
                    note: sending.note,
                    reportedAt: APIClient.iso8601String(
                        from: sending.reportedAt
                    ),
                    photo: photo?.base64EncodedString()
                )

                let sent: SpotReport

                do {

                    sent = try await service.create(
                        request,
                        token: current.token
                    )

                } catch {

                    guard session?.id == sessionId else {
                        return
                    }

                    if case APIError.server(let status, _) = error,
                       status == 401 {

                        authenticationPaused = true

                        try await store.markWaiting(
                            clientId: sending.clientId,
                            userId: current.userId
                        )

                        notifyChanged()
                        return
                    }

                    if case APIError.server(let status, let message) = error,
                       (400..<500).contains(status),
                       status != 408,
                       status != 429 {

                        try await store.markRejected(
                            clientId: sending.clientId,
                            userId: current.userId,
                            message: message
                        )

                        notifyChanged()
                        continue
                    }

                    // Network failures, timeouts and server errors
                    // keep the report available for another attempt.
                    try await store.markWaiting(
                        clientId: sending.clientId,
                        userId: current.userId
                    )

                    notifyChanged()

                    shouldRetry = true
                    return
                }

                guard session?.id == sessionId else {
                    return
                }

                // Keep the accepted report available immediately.
                rememberSent(sent)

                _ = await historyCache.mergeSent(
                    [sent],
                    userId: current.userId
                )

                guard session?.id == sessionId else {
                    return
                }

                // Only remove the local copy after the server
                // has accepted the report.
                try await store.remove(
                    clientId: sending.clientId,
                    userId: current.userId
                )

                notifyChanged()
            }

        } catch {

            guard session?.id == sessionId else {
                return
            }

            shouldRetry = true
            notifyChanged()
        }
    }

    // MARK: - Retry scheduling

    private func scheduleRetry(
        sessionId: UUID
    ) {

        guard canDrain(sessionId: sessionId),
              retryTask == nil else {
            return
        }

        retryTask = Task { [weak self] in

            do {
                try await Task.sleep(
                    for: .seconds(15)
                )
            } catch {
                return
            }

            await self?.retryNow(
                sessionId: sessionId
            )
        }
    }

    private func retryNow(
        sessionId: UUID
    ) {

        guard session?.id == sessionId else {
            return
        }

        retryTask = nil
        kick()
    }

    private func cancelRetry() {

        retryTask?.cancel()
        retryTask = nil
    }

    // MARK: - Helpers

    private func canDrain(
        sessionId: UUID
    ) -> Bool {

        session?.id == sessionId &&
        isConnected &&
        !authenticationPaused &&
        !Task.isCancelled
    }

    private func requireSession(
        userId: String
    ) throws -> Session {

        guard let session,
              session.userId == userId,
              !isChangingSession else {
            throw ReportOutboxError.noSession
        }

        return session
    }

    private func rememberSent(
        _ report: SpotReport
    ) {

        recentSent.removeAll {
            $0.clientId.lowercased() ==
            report.clientId.lowercased()
        }

        recentSent.insert(report, at: 0)

        if recentSent.count > 50 {
            recentSent.removeLast(
                recentSent.count - 50
            )
        }
    }

    private func notifyChanged() {

        NotificationCenter.default.post(
            name: .reportOutboxChanged,
            object: nil
        )
    }
}