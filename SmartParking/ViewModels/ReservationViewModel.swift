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
    @Published private(set) var isPerformingAction = false
    @Published private(set) var error: ReservationViewModelError?

    private let service: ReservationServicing
    private let locationService: LocationServicing
    private let parkedCarStore: ParkedCarStoring
    private var countdownTask: Task<Void, Never>?

    init(
        service: ReservationServicing,
        locationService: LocationServicing = LocationService.shared,
        parkedCarStore: ParkedCarStoring = ParkedCarStore.shared
    ) {
        self.service = service
        self.locationService = locationService
        self.parkedCarStore = parkedCarStore
        parkedCar = parkedCarStore.parkedCar
    }

    func reset() {
        setActiveReservation(nil)
        history = []
        vehicle = nil
        vehicleErrorMessage = nil
        error = nil
    }

    func loadActive() async {
        error = nil
        do {
            setActiveReservation(try await service.active())
        } catch {
            self.error = .requestFailed(error.localizedDescription)
        }
    }

    func create(spotId: String) async {
        error = nil
        do {
            let reservation = try await service.create(spotId: spotId)
            setActiveReservation(reservation)
            history.removeAll { $0.id == reservation.id }
            history.insert(reservation, at: 0)
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
        do {
            history = try await service.history()
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
            await loadVehicle()
        }
    }

    func loadVehicle() async {
        isLoadingVehicle = true
        vehicleErrorMessage = nil
        defer { isLoadingVehicle = false }
        do {
            vehicle = try await service.vehicle()
        } catch {
            vehicleErrorMessage = error.localizedDescription
        }
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