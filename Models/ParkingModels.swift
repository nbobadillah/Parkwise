import SwiftUI

enum OccupancyBand {
    case low
    case medium
    case high

    var tint: Tint {
        switch self {
        case .low:
            return Tint(soft: Palette.greenSoft, strong: Palette.greenInk)
        case .medium:
            return Tint(soft: Palette.amberSoft, strong: Color(hex: 0xE8890C))
        case .high:
            return Tint(soft: Palette.redSoft, strong: Color(hex: 0xE04E2E))
        }
    }
}

struct ForecastSlot: Identifiable {
    let id = UUID()
    let hour: String
    let load: Double
    let band: OccupancyBand
    let isCurrent: Bool
}

enum LevelStatus {
    case available
    case limited
    case full

    var title: String {
        switch self {
        case .available: return "Available"
        case .limited: return "Limited"
        case .full: return "Full"
        }
    }

    var tint: Tint {
        switch self {
        case .available:
            return Tint(soft: Palette.greenSoft, strong: Palette.greenInk)
        case .limited:
            return Tint(soft: Palette.amberSoft, strong: Palette.amberInk)
        case .full:
            return Tint(soft: Palette.redSoft, strong: Palette.redInk)
        }
    }
}

enum SpotState {
    case free
    case taken
    case reserved
    case you
}

struct ParkingSpot: Identifiable {
    let id: String
    var state: SpotState
    let walkMinutes: Int
}

struct ParkingRow: Identifiable {
    let index: Int
    var spots: [ParkingSpot]

    var id: Int { index }
}

struct ParkingZone: Identifiable {
    let id: String
    let name: String
    var rows: [ParkingRow]
}

struct ParkingLevel: Identifiable {
    let code: String
    let area: String
    let free: Int
    let reserved: Int
    let total: Int
    let recommendedSpot: String?
    let zones: [ParkingZone]

    var id: String { code }

    var listTitle: String { "Level \(code) · \(area)" }

    var shortTitle: String { "\(code) · \(area)" }

    var freeTitle: String { free == 0 ? "No spots" : "\(free) free" }

    var occupancy: Double { Double(total - free) / Double(total) }

    var status: LevelStatus {
        if free == 0 { return .full }
        return Double(free) / Double(total) < 0.1 ? .limited : .available
    }
}
