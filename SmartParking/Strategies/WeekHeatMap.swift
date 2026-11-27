import Foundation

struct WeekDate: Equatable, Sendable {
    let date: String
    let weekday: Int
}

enum WeekClock {
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    static var timeZone: TimeZone {
        TimeZone(identifier: "America/Bogota") ?? .current
    }

    static func days(from now: Date, count: Int = 7) -> [WeekDate] {
        let calendar = Self.calendar
        let start = calendar.startOfDay(for: now)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return WeekDate(date: dayString(day), weekday: calendar.component(.weekday, from: day) - 1)
        }
    }

    static func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func hour(of date: Date) -> Int {
        calendar.component(.hour, from: date)
    }

    static func date(day: String, hour: Int) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    static func weekdayName(_ weekday: Int) -> String {
        weekdayNames.indices.contains(weekday) ? weekdayNames[weekday] : ""
    }
}

struct HeatCell: Equatable, Identifiable, Sendable {
    let hour: Int
    let occupancy: Double?
    let tone: Int?
    let isBest: Bool

    var id: Int { hour }
}

struct HeatRow: Equatable, Identifiable, Sendable {
    let date: String
    let weekday: Int
    let isSaved: Bool
    let cells: [HeatCell]

    var id: String { date }

    var label: String {
        WeekClock.weekdayName(weekday)
    }
}

struct BestSlot: Equatable, Identifiable, Sendable {
    let date: String
    let weekday: Int
    let hour: Int
    let occupancy: Double

    var id: String {
        BestSlot.id(date: date, hour: hour)
    }

    var percent: Int {
        Int((occupancy * 100).rounded())
    }

    static func id(date: String, hour: Int) -> String {
        "\(date)-\(hour)"
    }
}

struct WeekHeatMap: Equatable, Sendable {
    static let empty = WeekHeatMap(hours: [], rows: [], best: [])

    let hours: [Int]
    let rows: [HeatRow]
    let best: [BestSlot]

    var missingRows: [HeatRow] {
        rows.filter { !$0.isSaved }
    }
}

struct WeekHeatMapInput: Equatable, Sendable {
    let hours: [Int]
    let rows: [WeekDate]
    let days: [WeekDayForecast]
    let arrivalHour: Int
    let today: String
    let currentHour: Int
}

enum WeekHeatMapBuilder {
    static let cutoffs: [Double] = [0.20, 0.40, 0.60, 0.75, 0.90]
    static let toneCount = cutoffs.count + 1
    static let nearHours = 1
    static let bestLimit = 3
    static let workdays = 1...5

    static func tone(for occupancy: Double) -> Int {
        cutoffs.firstIndex { occupancy < $0 } ?? cutoffs.count
    }

    static func build(_ input: WeekHeatMapInput) -> WeekHeatMap {
        let byDate = Dictionary(input.days.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        let shownDays = input.rows.compactMap { byDate[$0.date] }
        let best = bestSlots(
            days: shownDays,
            hours: input.hours,
            arrivalHour: input.arrivalHour,
            today: input.today,
            currentHour: input.currentHour
        )
        let bestIDs = Set(best.map(\.id))
        let rows = input.rows.map { row -> HeatRow in
            guard let day = byDate[row.date] else {
                return HeatRow(date: row.date, weekday: row.weekday, isSaved: false, cells: [])
            }
            let cells = input.hours.enumerated().map { (index, hour) -> HeatCell in
                let occupancy = day.occupancy(at: index)
                return HeatCell(
                    hour: hour,
                    occupancy: occupancy,
                    tone: occupancy.map(tone(for:)),
                    isBest: bestIDs.contains(BestSlot.id(date: row.date, hour: hour))
                )
            }
            return HeatRow(date: row.date, weekday: row.weekday, isSaved: true, cells: cells)
        }
        return WeekHeatMap(hours: input.hours, rows: rows, best: best)
    }

    static func bestSlots(
        days: [WeekDayForecast],
        hours: [Int],
        arrivalHour: Int,
        today: String,
        currentHour: Int,
        limit: Int = bestLimit
    ) -> [BestSlot] {
        var slots: [BestSlot] = []
        for day in days where workdays.contains(day.weekday) {
            for (index, hour) in hours.enumerated() {
                guard abs(hour - arrivalHour) <= nearHours,
                      day.date != today || hour > currentHour,
                      let occupancy = day.occupancy(at: index)
                else {
                    continue
                }
                slots.append(BestSlot(date: day.date, weekday: day.weekday, hour: hour, occupancy: occupancy))
            }
        }
        return Array(slots.sorted(by: isBetter(_:than:)).prefix(limit))
    }

    static func isBetter(_ lhs: BestSlot, than rhs: BestSlot) -> Bool {
        if lhs.occupancy != rhs.occupancy {
            return lhs.occupancy < rhs.occupancy
        }
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        return lhs.hour < rhs.hour
    }
}
