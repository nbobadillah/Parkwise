import Foundation

struct WeekPlanLevelStore {
    static let key = "weekPlan.level"
    static let levels = ["P1", "P2", "P3"]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var level: String {
        guard let saved = defaults.string(forKey: Self.key), Self.levels.contains(saved) else {
            return Self.levels[0]
        }
        return saved
    }

    func save(_ level: String) {
        guard Self.levels.contains(level) else { return }
        defaults.set(level, forKey: Self.key)
    }
}
