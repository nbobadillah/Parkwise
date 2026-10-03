import Foundation

enum SpotKind: Equatable {
    case standard
    case vip
    case electric
    case accessible

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .vip:
            return "VIP"
        case .electric:
            return "Electric \u{26A1}\u{FE0F}"
        case .accessible:
            return "Accessible \u{267F}\u{FE0F}"
        }
    }
}

enum FindSpotFilter: String, CaseIterable, Identifiable {
    case available = "Available"
    case vip = "VIP"
    case electric = "Electric"
    case accessible = "Accessible"

    var id: String {
        rawValue
    }
}

struct SpotListing: Identifiable, Equatable {
    let id: String
    let code: String
    let levelCode: String
    let zone: String
    let walkMinutes: Int
    let kind: SpotKind
    let isAvailable: Bool

    init(spot: Spot) {
        id = spot.id
        code = spot.code
        levelCode = spot.levelCode
        zone = spot.zone
        walkMinutes = spot.walkMinutes
        isAvailable = spot.status == .free

        if spot.isVip {
            kind = .vip
        } else if spot.isEv {
            kind = .electric
        } else if spot.isAccessible {
            kind = .accessible
        } else {
            kind = .standard
        }
    }

    init(spot: ParkingSpot) {
        id = spot.id
        code = spot.code
        levelCode = spot.levelCode
        zone = spot.zone
        walkMinutes = spot.walkMinutes
        isAvailable = spot.state == .free
        kind = .standard
    }

    var levelTitle: String {
        "\(levelCode) · Zone \(zone)"
    }
}