import Foundation

enum SpotKind: Equatable, Sendable {
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
            return "Electric ⚡️"
        case .accessible:
            return "Accessible ♿️"
        }
    }
}

enum FindSpotFilter: String, CaseIterable, Identifiable, Sendable {
    case available = "Available"
    case vip = "VIP"
    case electric = "Electric"
    case accessible = "Accessible"

    var id: String {
        rawValue
    }
}

struct SpotListing: Identifiable, Equatable, Sendable {
    let id: String
    let code: String
    let levelCode: String
    let zone: String
    let walkMinutes: Int
    let kind: SpotKind

    let isAvailable: Bool
    let isVIP: Bool
    let isElectric: Bool
    let isAccessible: Bool

    init(spot: Spot) {
        id = spot.id
        code = spot.code
        levelCode = spot.levelCode
        zone = spot.zone
        walkMinutes = spot.walkMinutes

        // Las plazas propias no se ofrecen como disponibles.
        isAvailable = spot.status == .free && !spot.mine

        isVIP = spot.isVip
        isElectric = spot.isEv
        isAccessible = spot.isAccessible

        // Se conserva una categoría principal para la presentación.
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

        isVIP = false
        isElectric = false
        isAccessible = false
        kind = .standard
    }

    var levelTitle: String {
        "\(levelCode) · Zone \(zone)"
    }

    func matches(_ filter: FindSpotFilter) -> Bool {
        switch filter {
        case .available:
            return isAvailable
        case .vip:
            return isAvailable && isVIP
        case .electric:
            return isAvailable && isElectric
        case .accessible:
            return isAvailable && isAccessible
        }
    }
}