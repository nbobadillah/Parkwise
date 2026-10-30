import Combine
import Foundation

struct ReservedSpot: Equatable {
    let id: String
    let code: String
    let levelCode: String
    let zone: String

    init(reservation: Reservation) {
        id = reservation.spotId
        code = reservation.spotCode
        levelCode = reservation.levelCode
        zone = String(reservation.spotCode.prefix { $0 != "-" })
    }
}

enum ReservationViewModelError: Equatable {
    case spotUnavailable
    case activeReservationExists
    case reservingNeedsConnection
    case requestFailed(String)

    var message: String {
        switch self {
        case .spotUnavailable:
            return "Parking spot is not available."
        case .activeReservationExists:
            return "An active reservation already exists."
        case .reservingNeedsConnection:
            return "Reserving a spot needs a connection. Try again when you're back online."
        case .requestFailed(let message):
            return message
        }
    }
}

@MainActor
final class ReservationViewModel: ObservableObject {
    @Published private(set) var activeReservation: Reservation?
    @Published private(set) var activeSpot: ReservedSpot?
    @Published private(set) var remainingTime: TimeInterval?
    @Published private(set) var history: [Reservation] = []
    @Published private(set) var vehicle: ParkedVehicle?
    @Published private(set) var parkedCar: ParkedCar?
    @Published private(set) var isLoadingVehicle = false
    @Published private(set) var vehicleErrorMessage: String?
    @Published private(set) var vehicleSavedAt: Date?
    @Published private(set) var isPerformingAction = false
    @Published private(set) var error: ReservationViewModelError?
    @Published private(set) var pendingAction: PendingActionKind?
    @Published private var activeSavedAt: Date?
    @Published private var historySavedAt: Date?

    private let service: ReservationServicing
    private let reader: CachedReservationReading
    private let actionQueue: ActionQueueing
    private let locationService: LocationServicing
    private let parkedCarStore: ParkedCarStoring
    private let networkMonitor: NetworkMonitor
    private var countdownTask: Task<Void, Never>?
    private var userId: String?
    private var syncFailureMessage: String?
    private var subscriptions = Set<AnyCancellable>()

    init(
        service: ReservationServicing,
        actionQueue: ActionQueueing,
        reader: CachedReservationReading? = nil,
        locationService: LocationServicing = LocationService.shared,
        parkedCarStore: ParkedCarStoring = ParkedCarStore.shared,
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.service = service
        self.reader = reader ?? CachedReservationReader(service: service)
        self.actionQueue = actionQueue
        self.locationService = locationService
        self.parkedCarStore = parkedCarStore
        self.networkMonitor = networkMonitor
        parkedCar = parkedCarStore.parkedCar

        actionQueue.failures
            .sink { [weak self] failure in
                MainActor.assumeIsolated {
                    self?.syncFailureMessage = failure.message
                }
            }
            .store(in: &subscriptions)

        networkMonitor.$isConnected
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { await self?.synchronize() }
            }
            .store(in: &subscriptions)
    }

    var savedAt: Date? {
        [activeSavedAt, historySavedAt].compactMap { $0 }.min()
    }

    var pendingMessage: String? {
        switch pendingAction {
        case .checkIn:
            return "Check-in pending. It will be sent when you're back online."
        case .release:
            return "Release pending. It will be sent when you're back online."
        case nil:
            return nil
        }
    }

    func setUser(id: String?) {
        userId = id
    }

    func reset() {
        setActiveReservation(nil)
        history = []
        vehicle = nil
        vehicleErrorMessage = nil
        vehicleSavedAt = nil
        error = nil
        userId = nil
        syncFailureMessage = nil
        pendingAction = nil
        activeSavedAt = nil
        historySavedAt = nil
    }

    func loadActive() async {
        error = nil
        guard let userId else { return }
        do {
            let fetched = try await reader.active(userId: userId)
            setActiveReservation(fetched.value)
            activeSavedAt = fetched.fromCache ? fetched.fetchedAt : nil
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
        await refreshPendingAction()
    }

    func create(spotId: String) async {
        error = nil
        guard networkMonitor.isConnected else {
            error = .reservingNeedsConnection
            return
        }
        do {
            let reservation = try await service.create(spotId: spotId)
            setActiveReservation(reservation)
            history.removeAll { $0.id == reservation.id }
            history.insert(reservation, at: 0)
            saveSnapshot()
        } catch let serviceError as ReservationServiceError {
            switch serviceError {
            case .spotUnavailable:
                error = .spotUnavailable
            case .activeReservationExists:
                error = .activeReservationExists
            case .conflict(let message):
                error = .requestFailed(message)
            }
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    func loadHistory() async {
        guard let userId else { return }
        do {
            let fetched = try await reader.history(userId: userId)
            history = fetched.value
            historySavedAt = fetched.fromCache ? fetched.fetchedAt : nil
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    func checkIn() async {
        guard let reservation = activeReservation, reservation.status == .active else { return }
        guard networkMonitor.isConnected else {
            await enqueue(.checkIn, for: reservation)
            return
        }
        await performReservationAction {
            try await self.service.checkIn(id: reservation.id)
        }
        guard let checkedInReservation = activeReservation, checkedInReservation.status == .fulfilled else { return }
        if let location = locationService.currentLocation {
            parkedCar = parkedCarStore.save(
                location: location,
                levelCode: checkedInReservation.levelCode,
                spotCode: checkedInReservation.spotCode
            )
        }
        await loadVehicle()
    }

    func release() async {
        guard let reservation = activeReservation,
              reservation.status == .active || reservation.status == .fulfilled else { return }
        guard networkMonitor.isConnected else {
            await enqueue(.release, for: reservation)
            return
        }
        await performReservationAction {
            try await self.service.release(id: reservation.id)
        }
        if activeReservation?.status == .cancelled || activeReservation?.status == .released {
            parkedCarStore.clear()
            parkedCar = nil
            forgetVehicle()
            await loadVehicle()
        }
    }

    func loadVehicle() async {
        isLoadingVehicle = true
        vehicleErrorMessage = nil
        defer { isLoadingVehicle = false }
        do {
            guard let userId else {
                vehicle = try await service.vehicle()
                vehicleSavedAt = nil
                return
            }
            let fetched = try await reader.vehicle(userId: userId)
            vehicle = fetched.value
            vehicleSavedAt = fetched.fromCache && fetched.value != nil ? fetched.fetchedAt : nil
        } catch {
            vehicleErrorMessage = error.localizedDescription
        }
    }

    private func forgetVehicle() {
        vehicle = nil
        vehicleSavedAt = nil
        guard let userId else { return }
        reader.clearVehicle(userId: userId)
    }

    private func performReservationAction(_ action: () async throws -> Reservation) async {
        error = nil
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            let reservation = try await action()
            setActiveReservation(reservation)
            if let index = history.firstIndex(where: { $0.id == reservation.id }) {
                history[index] = reservation
            } else {
                history.insert(reservation, at: 0)
            }
            saveSnapshot()
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    private func enqueue(_ kind: PendingActionKind, for reservation: Reservation) async {
        error = nil
        do {
            try await actionQueue.enqueue(kind, reservationId: reservation.id)
            pendingAction = kind
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    private func synchronize() async {
        guard userId != nil else { return }
        let synchronizedAction = pendingAction
        await actionQueue.drain()
        await loadActive()
        await loadHistory()
        if let message = syncFailureMessage {
            error = .requestFailed(message)
            syncFailureMessage = nil
        }
        guard synchronizedAction != nil, pendingAction == nil else { return }
        if synchronizedAction == .release, activeReservation == nil {
            parkedCarStore.clear()
            parkedCar = nil
            forgetVehicle()
        }
        await loadVehicle()
    }

    private func refreshPendingAction() async {
        guard let reservationId = activeReservation?.id else {
            pendingAction = nil
            return
        }
        pendingAction = await actionQueue.pending().last { $0.reservationId == reservationId }?.kind
    }

    private func saveSnapshot() {
        guard let userId else { return }
        reader.save(active: activeReservation, history: history, userId: userId)
        activeSavedAt = nil
    }

    private func setActiveReservation(_ reservation: Reservation?) {
        activeReservation = reservation
        activeSpot = reservation.map(ReservedSpot.init(reservation:))
        countdownTask?.cancel()

        guard let reservation, reservation.status == .active else {
            remainingTime = nil
            return
        }

        let expiresAt = reservation.expiresAt
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let timeRemaining = max(0, expiresAt.timeIntervalSinceNow)
                self.remainingTime = timeRemaining
                guard timeRemaining > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}