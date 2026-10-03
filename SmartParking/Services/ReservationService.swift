import Foundation

protocol ReservationServicing: AnyObject {
    func create(spotId: String) async throws -> Reservation
    func checkIn(id: String) async throws -> Reservation
    func release(id: String) async throws -> Reservation
    func active() async throws -> Reservation?
    func history() async throws -> [Reservation]
    func vehicle() async throws -> ParkedVehicle?
}

enum ReservationServiceError: LocalizedError {
    case spotUnavailable
    case activeReservationExists
    case conflict(message: String)

    var errorDescription: String? {
        switch self {
        case .spotUnavailable:
            return "Parking spot is not available."
        case .activeReservationExists:
            return "An active reservation already exists."
        case .conflict(let message):
            return message
        }
    }
}

final class BackendReservationService: ReservationServicing {
    private struct CreateRequest: Encodable {
        let spotId: String
    }

    private let client: APIClient
    private let token: () -> String?

    init(client: APIClient = .shared, token: @escaping () -> String?) {
        self.client = client
        self.token = token
    }

    func create(spotId: String) async throws -> Reservation {
        do {
            return try await client.send(
                "POST",
                "/api/v1/reservations",
                body: CreateRequest(spotId: spotId),
                token: token()
            )
        } catch let APIError.server(status, message) where status == 409 {
            switch message {
            case "Parking spot is not available":
                throw ReservationServiceError.spotUnavailable
            case "An active reservation already exists":
                throw ReservationServiceError.activeReservationExists
            default:
                throw ReservationServiceError.conflict(message: message)
            }
        }
    }

    func checkIn(id: String) async throws -> Reservation {
        try await client.send("POST", "/api/v1/reservations/\(id)/check-in", token: token())
    }

    func release(id: String) async throws -> Reservation {
        try await client.send("POST", "/api/v1/reservations/\(id)/release", token: token())
    }

    func active() async throws -> Reservation? {
        try await client.send("GET", "/api/v1/reservations/active", token: token())
    }

    func history() async throws -> [Reservation] {
        try await client.send("GET", "/api/v1/reservations/me", token: token())
    }

    func vehicle() async throws -> ParkedVehicle? {
        try await client.send("GET", "/api/v1/vehicle", token: token())
    }
}