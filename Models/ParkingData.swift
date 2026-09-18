import Foundation

enum ParkingData {
    static let userName = "Nicolas Bobadilla"
    static let userInitials = "AM"
    static let destinations = ["Main Campus ", "Library", "Admin Building", "Sports Center"]

    static let forecast: [ForecastSlot] = [
        ForecastSlot(hour: "7", load: 0.32, band: .low, isCurrent: false),
        ForecastSlot(hour: "8", load: 0.62, band: .medium, isCurrent: true),
        ForecastSlot(hour: "9", load: 0.86, band: .high, isCurrent: false),
        ForecastSlot(hour: "10", load: 0.82, band: .high, isCurrent: false),
        ForecastSlot(hour: "11", load: 0.58, band: .medium, isCurrent: false),
        ForecastSlot(hour: "12", load: 0.44, band: .low, isCurrent: false),
        ForecastSlot(hour: "1", load: 0.55, band: .medium, isCurrent: false),
        ForecastSlot(hour: "2", load: 0.72, band: .medium, isCurrent: false)
    ]

    static let levels: [ParkingLevel] = [
        ParkingLevel(
            code: "P1",
            area: "North",
            free: 14,
            reserved: 3,
            total: 80,
            recommendedSpot: "B201",
            zones: [
                zone("A", name: "Zone A", walkBase: 1, rows: [
                    [.taken, .taken, .free, .free, .taken, .free],
                    [.taken, .free, .free, .taken, .taken, .taken],
                    [.reserved, .free, .taken, .free, .free, .taken]
                ]),
                zone("B", name: "Zone B", walkBase: 2, rows: [
                    [.free, .you, .free, .taken, .taken, .free],
                    [.free, .taken, .reserved, .free, .free, .free],
                    [.free, .free, .taken, .taken, .free, .taken]
                ]),
                zone("C", name: "Zone C", walkBase: 3, rows: [
                    [.taken, .free, .taken, .free, .taken, .taken],
                    [.free, .taken, .taken, .reserved, .free, .taken],
                    [.taken, .taken, .free, .taken, .free, .free]
                ])
            ]
        ),
        ParkingLevel(
            code: "P2",
            area: "Central",
            free: 3,
            reserved: 8,
            total: 60,
            recommendedSpot: "A103",
            zones: [
                zone("A", name: "Zone A", walkBase: 1, rows: [
                    [.taken, .reserved, .free, .taken, .taken, .taken],
                    [.taken, .taken, .reserved, .taken, .free, .taken],
                    [.reserved, .taken, .taken, .reserved, .taken, .taken]
                ]),
                zone("B", name: "Zone B", walkBase: 2, rows: [
                    [.taken, .taken, .reserved, .taken, .taken, .free],
                    [.reserved, .taken, .taken, .taken, .reserved, .taken],
                    [.taken, .reserved, .taken, .taken, .taken, .taken]
                ])
            ]
        ),
        ParkingLevel(
            code: "P3",
            area: "South",
            free: 0,
            reserved: 12,
            total: 50,
            recommendedSpot: nil,
            zones: [
                zone("A", name: "Zone A", walkBase: 2, rows: [
                    [.taken, .reserved, .taken, .taken, .reserved, .taken],
                    [.taken, .taken, .reserved, .taken, .taken, .taken],
                    [.reserved, .taken, .taken, .reserved, .taken, .taken]
                ]),
                zone("B", name: "Zone B", walkBase: 3, rows: [
                    [.taken, .taken, .taken, .reserved, .taken, .taken],
                    [.reserved, .taken, .taken, .taken, .taken, .reserved],
                    [.taken, .reserved, .taken, .taken, .reserved, .taken]
                ])
            ]
        )
    ]

    static func level(code: String) -> ParkingLevel {
        levels.first { $0.code == code } ?? levels[0]
    }

    private static func zone(_ letter: String, name: String, walkBase: Int, rows: [[SpotState]]) -> ParkingZone {
        let builtRows = rows.enumerated().map { offset, states -> ParkingRow in
            let number = offset + 1
            let spots = states.enumerated().map { column, state in
                ParkingSpot(
                    id: String(format: "%@%d%02d", letter, number, column + 1),
                    state: state,
                    walkMinutes: walkBase + (number - 1) / 2
                )
            }
            return ParkingRow(index: number, spots: spots)
        }
        return ParkingZone(id: letter, name: name, rows: builtRows)
    }
}
