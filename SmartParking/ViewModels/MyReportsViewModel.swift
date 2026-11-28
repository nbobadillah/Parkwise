import Foundation
import Combine

// MARK: - Unified history item

enum ReportHistoryItem: Identifiable {

    case sent(SpotReport)
    case pending(QueuedReport)

    var id: String {
        switch self {
        case .sent(let report):
            return report.clientId.lowercased()

        case .pending(let report):
            return report.clientId.uuidString.lowercased()
        }
    }

    var displayCode: String {
        switch self {
        case .sent(let report):
            return report.displayCode

        case .pending(let report):
            return report.displayCode
        }
    }

    var kind: ReportKind {
        switch self {
        case .sent(let report):
            return report.kind

        case .pending(let report):
            return report.kind
        }
    }

    var note: String? {
        switch self {
        case .sent(let report):
            return report.note

        case .pending(let report):
            return report.note
        }
    }

    var reportedAt: Date {
        switch self {
        case .sent(let report):
            return report.reportedAt

        case .pending(let report):
            return report.reportedAt
        }
    }

    var state: ReportDeliveryState {
        switch self {
        case .sent:
            return .sent

        case .pending(let report):
            return report.state
        }
    }

    var hasPhoto: Bool {
        switch self {
        case .sent(let report):
            return report.hasPhoto

        case .pending(let report):
            return report.hasPhoto
        }
    }

    var failureMessage: String? {
        switch self {
        case .sent:
            return nil

        case .pending(let report):
            return report.failureMessage
        }
    }

    var photoTaskId: String {
        "\(id)-\(state.rawValue)"
    }
}

// MARK: - My reports view model

@MainActor
final class MyReportsViewModel: ObservableObject {

    @Published private(set) var items: [ReportHistoryItem] = []

    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    @Published private(set) var isCached = false
    @Published private(set) var fetchedAt: Date?

    @Published private(set) var warning: String?
    @Published var errorMessage: String?

    let userId: String

    private let coordinator: ReportSessionCoordinator

    private var refreshTask: Task<Void, Never>?

    private var needsRefresh = false
    private var needsForcedRefresh = false

    // MARK: - Initialization

    init(
        userId: String,
        coordinator: ReportSessionCoordinator
    ) {
        self.userId = userId
        self.coordinator = coordinator
    }

    // MARK: - Computed state

    var pendingCount: Int {

        items.filter {
            $0.state == .waiting ||
            $0.state == .sending
        }.count
    }

    var rejectedCount: Int {

        items.filter {
            $0.state == .rejected
        }.count
    }

    var sentCount: Int {

        items.filter {
            $0.state == .sent
        }.count
    }

    var isConnected: Bool {
        coordinator.isConnected
    }

    var isEmpty: Bool {
        hasLoaded && items.isEmpty
    }

    // MARK: - Refresh

    func refresh(
        force: Bool = false
    ) async {

        if let running = refreshTask {

            needsRefresh = true

            needsForcedRefresh =
                needsForcedRefresh || force

            await running.value

            return
        }

        refreshTask = Task { [weak self] in

            guard let self else {
                return
            }

            await self.performRefresh(
                force: force
            )
        }

        await refreshTask?.value
    }

    private func performRefresh(
        force: Bool
    ) async {

        isLoading = true

        defer {
            isLoading = false
            refreshTask = nil
        }

        var forceRefresh = force

        repeat {

            needsRefresh = false
            needsForcedRefresh = false

            await loadOnce(
                force: forceRefresh
            )

            forceRefresh = needsForcedRefresh

        } while needsRefresh &&
                !Task.isCancelled &&
                coordinator.activeUserId == userId
    }

    private func loadOnce(
        force: Bool
    ) async {

        guard coordinator.activeUserId == userId else {

            items.removeAll()
            fetchedAt = nil
            hasLoaded = false

            return
        }

        errorMessage = nil

        do {

            let result = try await coordinator.loadHistory(
                userId: userId,
                force: force
            )

            try Task.checkCancellation()

            guard coordinator.activeUserId == userId else {
                return
            }

            items = merge(
                sent: result.reports,
                pending: result.pending
            )

            fetchedAt = result.fetchedAt
            isCached = result.isCached
            warning = result.warning

            hasLoaded = true

        } catch is CancellationError {

            return

        } catch {

            guard coordinator.activeUserId == userId else {

                items.removeAll()
                hasLoaded = false
                fetchedAt = nil

                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Merge local and remote reports

    private func merge(
        sent: [SpotReport],
        pending: [QueuedReport]
    ) -> [ReportHistoryItem] {

        var result: [ReportHistoryItem] = []

        var seen = Set<String>()

        // Prefer the server-confirmed version.
        for report in sent {

            let item = ReportHistoryItem.sent(report)

            if seen.insert(item.id).inserted {
                result.append(item)
            }
        }

        // Add pending reports that have not already
        // been accepted by the server.
        for report in pending {

            let item = ReportHistoryItem.pending(report)

            if seen.insert(item.id).inserted {
                result.append(item)
            }
        }

        return result.sorted {

            if $0.reportedAt == $1.reportedAt {
                return $0.id < $1.id
            }

            return $0.reportedAt > $1.reportedAt
        }
    }

    // MARK: - Photo loading

    func photoData(
        for item: ReportHistoryItem
    ) async throws -> Data? {

        guard coordinator.activeUserId == userId,
              item.hasPhoto else {
            return nil
        }

        switch item {

        case .sent(let report):

            return try await coordinator.reportPhoto(
                for: report,
                userId: userId
            )

        case .pending(let report):

            return try await coordinator.pendingPhoto(
                clientId: report.clientId,
                userId: userId
            )
        }
    }

    // MARK: - Date formatting

    func dateTitle(
        for date: Date
    ) -> String {

        let calendar = Calendar.current

        let time = date.formatted(
            date: .omitted,
            time: .shortened
        )

        if calendar.isDateInToday(date) {
            return "Today at \(time)"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday at \(time)"
        }

        return date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }
}