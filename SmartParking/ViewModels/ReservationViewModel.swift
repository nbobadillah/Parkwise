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
    case requestFailed(String)

    var message: String {
        switch self {
        case .spotUnavailable:
            return "Parking spot is not available."
        case .activeReservationExists:
            return "An active reservation already exists."
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
    @Published private var activeSavedAt: Date?
    @Published private var historySavedAt: Date?

    private let service: ReservationServicing
    private let reader: CachedReservationReading
    private let locationService: LocationServicing
    private let parkedCarStore: ParkedCarStoring
    private let telemetry: TelemetryService
    private let flowTracker: ReservationFlowTracking
    private var countdownTask: Task<Void, Never>?
    private var userId: String?

    init(
        service: ReservationServicing,
        reader: CachedReservationReading? = nil,
        locationService: LocationServicing = LocationService.shared,
        parkedCarStore: ParkedCarStoring = ParkedCarStore.shared,
        telemetry: TelemetryService? = nil,
        flowTracker: ReservationFlowTracking? = nil
    ) {
        self.service = service
        self.reader = reader ?? CachedReservationReader(service: service)
        self.locationService = locationService
        self.parkedCarStore = parkedCarStore
        self.telemetry = telemetry ?? .shared
        self.flowTracker = flowTracker ?? CrashMonitor.shared
        parkedCar = parkedCarStore.parkedCar
    }

    var savedAt: Date? {
        [activeSavedAt, historySavedAt].compactMap { $0 }.min()
    }

    func setUser(id: String?) {
        userId = id
    }

    func reserveScreenOpened() {
        telemetry.trackReserveOpened()
        flowTracker.setInReservationFlow(true)
    }

    func reserveScreenClosed() {
        flowTracker.setInReservationFlow(false)
    }

    func reset() {
        setActiveReservation(nil)
        history = []
        vehicle = nil
        vehicleErrorMessage = nil
        vehicleSavedAt = nil
        error = nil
        userId = nil
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
    }

    func create(spotId: String) async {
        error = nil
        let start = ContinuousClock.now
        do {
            let reservation = try await service.create(spotId: spotId)
            trackReservationRequest(since: start, error: nil)
            setActiveReservation(reservation)
            history.removeAll { $0.id == reservation.id }
            history.insert(reservation, at: 0)
            saveSnapshot()
        } catch let serviceError as ReservationServiceError {
            trackReservationRequest(since: start, error: serviceError)
            switch serviceError {
            case .spotUnavailable:
                error = .spotUnavailable
            case .activeReservationExists:
                error = .activeReservationExists
            case .conflict(let message):
                error = .requestFailed(message)
            }
        } catch {
            trackReservationRequest(since: start, error: error)
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    private func trackReservationRequest(since start: ContinuousClock.Instant, error: Error?) {
        telemetry.trackReservationRequest(
            durationMs: Int(start.duration(to: .now) / .milliseconds(1)),
            errorType: error.map(Self.requestErrorType(for:))
        )
    }

    private static func requestErrorType(for error: Error) -> String {
        switch error {
        case ReservationServiceError.spotUnavailable:
            return "spot_taken"
        case ReservationServiceError.activeReservationExists:
            return "already_active"
        case APIError.network:
            return "offline"
        case APIError.server(let status, _) where status >= 500:
            return "server_error"
        default:
            return "other"
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

    private func saveSnapshot() {
        guard let userId else { return }
        reader.save(active: activeReservation, history: history, userId: userId)
        activeSavedAt = nil
        historySavedAt = nil
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