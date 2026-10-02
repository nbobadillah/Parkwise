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
}
