import Combine
import Foundation
import os

private let weekPlanLog = Logger(subsystem: "com.andresmorales.SmartParking", category: "WeekPlan")

struct LevelWeek: Equatable, Sendable {
    let code: String
    let hours: [Int]
    let days: [WeekDayForecast]
    let stamp: Date
    let isSaved: Bool
}

struct WeekLevelLoad: Sendable {
    let code: String
    let result: Result<WeekForecastResponse, Error>
}

struct WeekPlanBanner: Equatable {
    let title: String
    let message: String
    let isOffline: Bool
}

@MainActor
enum WeekPlanFormat {
    private static let timeFormatter = formatter("h:mm a")
    private static let savedFormatter = formatter("d MMM, h:mm a")
    private static let savedOnFormatter = formatter("d MMM 'at' h:mm a")

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func saved(_ date: Date) -> String {
        savedFormatter.string(from: date)
    }

    static func savedOn(_ date: Date) -> String {
        savedOnFormatter.string(from: date)
    }

    static func hour(_ hour: Int) -> String {
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):00 \(hour < 12 ? "AM" : "PM")"
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = WeekClock.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

@MainActor
final class WeekPlanViewModel: ObservableObject {
    static let levels = WeekPlanLevelStore.levels
    static let basis = "Based on the last 4 weeks of occupancy"

    @Published private(set) var level: String
    @Published private(set) var arrivalAt: Date
    @Published private(set) var weeks: [String: LevelWeek] = [:]
    @Published private(set) var failedLevels: Set<String> = []
    @Published private(set) var heatMap: WeekHeatMap = .empty
    @Published private(set) var heatMapLevel: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var isConnected: Bool

    private let service: WeekForecastServicing
    private let fileStore: WeekForecastFileStore
    private let levelStore: WeekPlanLevelStore
    private let cache: WeekDayCache
    private let telemetry: TelemetryService
    private let now: () -> Date
    private var viewedLevels: Set<String> = []
    private var buildTask: Task<Void, Never>?
    private var connectivity: AnyCancellable?

    init(
        service: WeekForecastServicing,
        arrivalAt: Date? = nil,
        networkMonitor: NetworkMonitor? = nil,
        fileStore: WeekForecastFileStore = WeekForecastFileStore(),
        levelStore: WeekPlanLevelStore = WeekPlanLevelStore(),
        cache: WeekDayCache? = nil,
        telemetry: TelemetryService? = nil,
        now: @escaping () -> Date = { Date() }
    ) {
        let monitor = networkMonitor ?? .shared
        self.service = service
        self.fileStore = fileStore
        self.levelStore = levelStore
        self.cache = cache ?? .shared
        self.telemetry = telemetry ?? .shared
        self.now = now
        self.arrivalAt = arrivalAt ?? now().addingTimeInterval(HomeViewModel.defaultArrivalOffset)
        level = levelStore.level
        isConnected = monitor.isConnected

        connectivity = monitor.$isConnected
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] connected in
                Task { @MainActor in
                    self?.isConnected = connected
                    guard connected else { return }
                    await self?.load()
                }
            }
    }

    var selectedWeek: LevelWeek? {
        weeks[level]
    }

    var isShowingSaved: Bool {
        selectedWeek?.isSaved ?? false
    }

    var arrivalHour: Int {
        WeekClock.hour(of: arrivalAt)
    }

    var arrivalText: String {
        WeekPlanFormat.time(arrivalAt)
    }

    var overline: String {
        "Predicted occupancy · \(level)"
    }

    var bestOverline: String {
        isShowingSaved ? "Best times in the saved days" : "Best times this week"
    }

    var bestNearText: String {
        "Best near \(arrivalText)"
    }

    var noBestMessage: String {
        "No history from Monday to Friday near \(arrivalText) yet."
    }

    var isBuilding: Bool {
        selectedWeek != nil && heatMapLevel != level
    }

    var footer: String? {
        guard let week = selectedWeek else { return nil }
        if week.isSaved {
            return "\(Self.basis) · Saved \(WeekPlanFormat.saved(week.stamp))"
        }
        return "\(Self.basis) · Updated \(WeekPlanFormat.time(week.stamp)) · Kept on this phone"
    }

    var missingDaysText: String? {
        guard heatMapLevel == level else { return nil }
        let missing = heatMap.missingRows
        guard let first = missing.first, let last = missing.last else { return nil }
        if missing.count == 1 {
            return "\(first.label) was not saved yet."
        }
        return "\(first.label) to \(last.label) were not saved yet."
    }

    var banner: WeekPlanBanner? {
        let title = isConnected ? "Server unreachable" : "No signal"
        if let week = selectedWeek {
            guard week.isSaved else { return nil }
            let saved = "Showing the week saved on \(WeekPlanFormat.savedOn(week.stamp))."
            let message = missingDaysText.map { "\(saved) \($0)" } ?? saved
            return WeekPlanBanner(title: title, message: message, isOffline: !isConnected)
        }
        guard hasLoaded, !isLoading, !isConnected || failedLevels.contains(level) else { return nil }
        let message = isConnected
            ? "There is no week saved on this phone yet. Pull down to try again."
            : "There is no week saved on this phone yet. It loads by itself when the signal returns."
        return WeekPlanBanner(title: title, message: message, isOffline: !isConnected)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        let current = now()
        if !isConnected {
            await showSaved()
        } else if let cached = cachedWeeks(now: current) {
            weeks = cached
            failedLevels = []
        } else {
            await fetchAll(now: current)
        }
        rebuild()
    }

    func selectLevel(_ code: String) {
        guard Self.levels.contains(code), code != level else { return }
        level = code
        levelStore.save(code)
        rebuild()
    }

    func setArrival(_ date: Date) {
        arrivalAt = date
        rebuild()
    }

    func use(_ slot: BestSlot) -> Date? {
        guard let date = WeekClock.date(day: slot.date, hour: slot.hour) else { return nil }
        telemetry.track("week_slot_used", [
            "platform": .string("ios"),
            "day": .string(slot.date),
            "hour": .int(slot.hour),
            "level": .string(level),
            "predicted": .int(slot.percent)
        ])
        return date
    }

    private func fetchAll(now current: Date) async {
        let service = service
        let loads = await withTaskGroup(of: WeekLevelLoad.self, returning: [WeekLevelLoad].self) { group in
            for code in Self.levels {
                group.addTask {
                    do {
                        let response = try await service.week(level: code)
                        return WeekLevelLoad(code: code, result: .success(response))
                    } catch {
                        return WeekLevelLoad(code: code, result: .failure(error))
                    }
                }
            }
            var results: [WeekLevelLoad] = []
            for await load in group {
                results.append(load)
            }
            return results
        }

        var loaded: [String: LevelWeek] = [:]
        var fresh: [WeekLevelForecast] = []
        var failed: Set<String> = []
        var hours = WeekForecastResponse.defaultHours

        for load in loads {
            guard case .success(let response) = load.result, let forecast = response.level(load.code) else {
                failed.insert(load.code)
                continue
            }
            hours = response.hours
            loaded[load.code] = LevelWeek(
                code: load.code,
                hours: response.hours,
                days: forecast.days,
                stamp: current,
                isSaved: false
            )
            fresh.append(forecast.stamped(current))
        }

        if !failed.isEmpty, let saved = await fileStore.load() {
            for code in failed {
                guard let level = saved.level(code) else { continue }
                loaded[code] = LevelWeek(
                    code: code,
                    hours: saved.hours,
                    days: level.days,
                    stamp: level.fetchedAt ?? saved.savedAt,
                    isSaved: true
                )
            }
        }

        weeks = loaded
        failedLevels = failed

        if failed.isEmpty {
            cache.store(Self.dayEntries(from: fresh, hours: hours, fetchedAt: current))
        }
        if !fresh.isEmpty {
            saveInBackground(fresh, hours: hours, savedAt: current)
        }
    }

    private func showSaved() async {
        guard let saved = await fileStore.load() else {
            weeks = [:]
            failedLevels = Set(Self.levels)
            return
        }
        var loaded: [String: LevelWeek] = [:]
        for level in saved.levels {
            loaded[level.code] = LevelWeek(
                code: level.code,
                hours: saved.hours,
                days: level.days,
                stamp: level.fetchedAt ?? saved.savedAt,
                isSaved: true
            )
        }
        weeks = loaded
        failedLevels = Set(Self.levels.filter { loaded[$0] == nil })
    }

    private func saveInBackground(_ levels: [WeekLevelForecast], hours: [Int], savedAt: Date) {
        let store = fileStore
        Task.detached(priority: .utility) {
            do {
                try store.save(levels: levels, hours: hours, savedAt: savedAt)
            } catch {
                weekPlanLog.error("Could not save the week: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func rebuild() {
        buildTask?.cancel()
        guard let week = selectedWeek else {
            heatMap = .empty
            heatMapLevel = nil
            return
        }

        let current = now()
        let rows = week.isSaved
            ? WeekClock.days(from: current)
            : week.days.map { WeekDate(date: $0.date, weekday: $0.weekday) }
        let input = WeekHeatMapInput(
            hours: week.hours,
            rows: rows,
            days: week.days,
            arrivalHour: arrivalHour,
            today: WeekClock.dayString(current),
            currentHour: WeekClock.hour(of: current)
        )

        buildTask = Task { [weak self] in
            let map = await Task.detached(priority: .userInitiated) {
                WeekHeatMapBuilder.build(input)
            }.value
            guard !Task.isCancelled, let self, self.level == week.code else { return }
            self.heatMap = map
            self.heatMapLevel = week.code
            self.trackViewed(week)
        }
    }

    private func trackViewed(_ week: LevelWeek) {
        guard !viewedLevels.contains(week.code) else { return }
        viewedLevels.insert(week.code)
        telemetry.track("week_viewed", [
            "platform": .string("ios"),
            "level": .string(week.code),
            "arrivalHour": .int(arrivalHour),
            "offline": .bool(week.isSaved)
        ])
    }

    private func cachedWeeks(now current: Date) -> [String: LevelWeek]? {
        let keys = WeekClock.days(from: current).compactMap { WeekDayForecast.dayKey($0.date) }
        guard keys.count == 7,
              let entries = cache.entries(for: keys, now: current),
              let first = entries.first
        else {
            return nil
        }

        let fetchedAt = entries.map(\.fetchedAt).min() ?? first.fetchedAt
        var result: [String: LevelWeek] = [:]
        for code in Self.levels {
            var days: [WeekDayForecast] = []
            for entry in entries {
                guard let occupancy = entry.levels[code] else { return nil }
                days.append(WeekDayForecast(date: entry.date, weekday: entry.weekday, occupancy: occupancy))
            }
            result[code] = LevelWeek(code: code, hours: first.hours, days: days, stamp: fetchedAt, isSaved: false)
        }
        return result
    }

    private static func dayEntries(from levels: [WeekLevelForecast], hours: [Int], fetchedAt: Date) -> [DayEntry] {
        guard let first = levels.first else { return [] }
        return first.days.map { day in
            var values: [String: [Double?]] = [:]
            for level in levels {
                if let match = level.days.first(where: { $0.date == day.date }) {
                    values[level.code] = match.occupancy
                }
            }
            return DayEntry(date: day.date, weekday: day.weekday, hours: hours, levels: values, fetchedAt: fetchedAt)
        }
    }
}
