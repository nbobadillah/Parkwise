import SwiftUI

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

struct ParkingSpot: Identifiable, Equatable {
    let id: String
    let code: String
    let zone: String
    let levelCode: String
    var state: SpotState
    let walkMinutes: Int

    init(spot: Spot) {
        id = spot.id
        code = spot.code
        zone = spot.zone
        levelCode = spot.levelCode
        state = spot.state
        walkMinutes = spot.walkMinutes
    }
}

struct ParkingRow: Identifiable, Equatable {
    let index: Int
    var spots: [ParkingSpot]

    var id: Int { index }
}

struct ParkingZone: Identifiable, Equatable {
    static let spotsPerRow = 6

    let id: String
    let name: String
    var rows: [ParkingRow]

    static func zones(from spots: [Spot]) -> [ParkingZone] {
        let grouped = Dictionary(grouping: spots, by: \.zone)
        return grouped.keys.sorted().map { zone in
            let cells = grouped[zone, default: []].map(ParkingSpot.init(spot:))
            let rows = stride(from: 0, to: cells.count, by: spotsPerRow).enumerated().map { offset, start in
                ParkingRow(index: offset + 1, spots: Array(cells[start..<min(start + spotsPerRow, cells.count)]))
            }
            return ParkingZone(id: zone, name: "Zone \(zone)", rows: rows)
        }
    }
}
