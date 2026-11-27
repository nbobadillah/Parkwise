import Foundation

struct WeekDayForecast: Codable, Equatable, Sendable {
    let date: String
    let weekday: Int
    let occupancy: [Double?]

    init(date: String, weekday: Int, occupancy: [Double?]) {
        self.date = date
        self.weekday = weekday
        self.occupancy = occupancy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        weekday = (try? container.decodeIfPresent(Int.self, forKey: .weekday)) ?? 0
        let values = (try? container.decodeIfPresent([LossyFraction].self, forKey: .occupancy)) ?? nil
        occupancy = values?.map(\.value) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case weekday
        case occupancy
    }

    var dayKey: Int? {
        WeekDayForecast.dayKey(date)
    }

    static func dayKey(_ date: String) -> Int? {
        let parts = date.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day)
        else {
            return nil
        }
        return year * 10_000 + month * 100 + day
    }

    func occupancy(at index: Int) -> Double? {
        guard occupancy.indices.contains(index) else { return nil }
        return occupancy[index]
    }
}

struct WeekLevelForecast: Codable, Equatable, Sendable {
    let code: String
    let days: [WeekDayForecast]
    let fetchedAt: Date?

    init(code: String, days: [WeekDayForecast], fetchedAt: Date? = nil) {
        self.code = code
        self.days = days
        self.fetchedAt = fetchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        days = (try? container.decodeIfPresent([LossyDay].self, forKey: .days))?.compactMap(\.day) ?? []
        fetchedAt = try? container.decodeIfPresent(Date.self, forKey: .fetchedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case days
        case fetchedAt
    }

    func stamped(_ date: Date) -> WeekLevelForecast {
        WeekLevelForecast(code: code, days: days, fetchedAt: date)
    }
}

struct WeekForecastResponse: Decodable, Equatable, Sendable {
    static let defaultHours = Array(6...19)

    let from: String?
    let hours: [Int]
    let levels: [WeekLevelForecast]

    init(from: String?, hours: [Int], levels: [WeekLevelForecast]) {
        self.from = from
        self.hours = hours
        self.levels = levels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = try? container.decodeIfPresent(String.self, forKey: .from)
        let decodedHours = (try? container.decodeIfPresent([Int].self, forKey: .hours)) ?? nil
        hours = decodedHours.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultHours
        levels = (try? container.decodeIfPresent([LossyLevel].self, forKey: .levels))?.compactMap(\.level) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case from
        case hours
        case levels
    }

    func level(_ code: String) -> WeekLevelForecast? {
        levels.first { $0.code == code }
    }
}

struct WeekForecast: Codable, Equatable, Sendable {
    let savedAt: Date
    let hours: [Int]
    let levels: [WeekLevelForecast]

    func level(_ code: String) -> WeekLevelForecast? {
        levels.first { $0.code == code }
    }

    func merging(_ fresh: [WeekLevelForecast], hours freshHours: [Int], savedAt date: Date) -> WeekForecast {
        let freshCodes = Set(fresh.map(\.code))
        let kept = levels.filter { !freshCodes.contains($0.code) }
        let merged = (kept + fresh).sorted { $0.code < $1.code }
        return WeekForecast(savedAt: date, hours: freshHours, levels: merged)
    }
}

private struct LossyFraction: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try? container.decode(Double.self)
        value = decoded.flatMap { $0.isFinite ? $0 : nil }
    }
}

private struct LossyDay: Decodable {
    let day: WeekDayForecast?

    init(from decoder: Decoder) throws {
        day = try? WeekDayForecast(from: decoder)
    }
}

private struct LossyLevel: Decodable {
    let level: WeekLevelForecast?

    init(from decoder: Decoder) throws {
        level = try? WeekLevelForecast(from: decoder)
    }
}
