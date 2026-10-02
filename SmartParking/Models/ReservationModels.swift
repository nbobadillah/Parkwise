import Foundation

enum ReservationStatus: String, Codable {
    case active
    case fulfilled
    case released
    case cancelled
    case expired
}

struct Reservation: Codable, Identifiable, Equatable {
    let id: String
    let spotId: String
    let spotCode: String
    let levelCode: String
    let status: ReservationStatus
    let createdAt: Date
    let expiresAt: Date
    let checkedInAt: Date?
    let releasedAt: Date?
}

struct ParkedVehicle: Codable, Equatable {
    let spotId: String
    let spotCode: String
    let levelCode: String
    let zone: String
    let parkedAt: Date
}
