import Foundation

enum SpotStatus: String, Codable {
    case free
    case reserved
    case occupied
    case disabled
}

struct Spot: Codable, Identifiable, Equatable {
    let id: String
    let code: String
    let zone: String
    let levelCode: String
    let status: SpotStatus
    let isAccessible: Bool
    let isEv: Bool
    let isVip: Bool
    let walkMinutes: Int
    let mine: Bool

    var state: SpotState {
        if mine { return .you }
        switch status {
        case .free: return .free
        case .reserved: return .reserved
        case .occupied, .disabled: return .taken
        }
    }
}

struct SpotFilters: Equatable {
    var available = false
    var accessible = false
    var ev = false
    var vip = false

    var queryItems: [URLQueryItem] {
        [("available", available), ("accessible", accessible), ("ev", ev), ("vip", vip)]
            .filter(\.1)
            .map { URLQueryItem(name: $0.0, value: "true") }
    }
}

struct Building: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

struct NearbyLot: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let ratePerHour: Int
    let currency: String
    let walkMinutes: Int
}
