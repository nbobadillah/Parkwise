import Foundation

struct DayEntry: Equatable, Sendable {
    let date: String
    let weekday: Int
    let hours: [Int]
    let levels: [String: [Double?]]
    let fetchedAt: Date
}

struct DaySparseArray: Sendable {
    static let defaultMaxEntries = 7
    static let defaultTTL: TimeInterval = 10 * 60

    let maxEntries: Int
    let ttl: TimeInterval
    private(set) var keys: [Int] = []
    private(set) var values: [DayEntry] = []

    init(maxEntries: Int = DaySparseArray.defaultMaxEntries, ttl: TimeInterval = DaySparseArray.defaultTTL) {
        self.maxEntries = max(1, maxEntries)
        self.ttl = ttl
    }

    var count: Int {
        keys.count
    }

    func index(of key: Int) -> Int? {
        let position = insertionPoint(for: key)
        guard position < keys.count, keys[position] == key else { return nil }
        return position
    }

    func get(_ key: Int, now: Date = Date()) -> DayEntry? {
        guard let index = index(of: key) else { return nil }
        let entry = values[index]
        guard now.timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return entry
    }

    mutating func put(_ key: Int, _ entry: DayEntry) {
        let position = insertionPoint(for: key)
        if position < keys.count, keys[position] == key {
            values[position] = entry
            return
        }
        keys.insert(key, at: position)
        values.insert(entry, at: position)
        if keys.count > maxEntries {
            keys.removeFirst()
            values.removeFirst()
        }
    }

    mutating func remove(_ key: Int) {
        guard let index = index(of: key) else { return }
        keys.remove(at: index)
        values.remove(at: index)
    }

    mutating func removeAll() {
        keys.removeAll()
        values.removeAll()
    }

    private func insertionPoint(for key: Int) -> Int {
        var low = 0
        var high = keys.count
        while low < high {
            let middle = (low + high) / 2
            if keys[middle] < key {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}

@MainActor
final class WeekDayCache {
    static let shared = WeekDayCache()

    private(set) var days: DaySparseArray

    init(days: DaySparseArray = DaySparseArray()) {
        self.days = days
    }

    func entries(for keys: [Int], now: Date = Date()) -> [DayEntry]? {
        var found: [DayEntry] = []
        for key in keys {
            guard let entry = days.get(key, now: now) else { return nil }
            found.append(entry)
        }
        return found
    }

    func store(_ entries: [DayEntry]) {
        for entry in entries {
            guard let key = WeekDayForecast.dayKey(entry.date) else { continue }
            days.put(key, entry)
        }
    }
}
