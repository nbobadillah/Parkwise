import Foundation

struct LevelSummary: Codable, Identifiable, Equatable {
    let code: String
    let name: String
    let underground: Bool
    let total: Int
    let free: Int
    let reserved: Int
    let occupied: Int

    var id: String { code }

    var area: String { underground ? "Basement" : "Ground" }

    var listTitle: String { "\(name) · \(area)" }

    var shortTitle: String { "\(code) · \(area)" }

    var freeTitle: String { free == 0 ? "No spots" : "\(free) free" }

    var occupancy: Double { total == 0 ? 1 : Double(total - free) / Double(total) }

    var status: LevelStatus {
        if free == 0 { return .full }
        return Double(free) / Double(total) < 0.1 ? .limited : .available
    }
}

struct LevelsResponse: Codable, Equatable {
    let generatedAt: Date
    let campusFull: Bool
    let levels: [LevelSummary]
}

struct PredictionPoint: Codable, Equatable {
    let slot: String
    let occupancy: Double?
}

struct LevelPrediction: Codable, Equatable {
    let code: String
    let points: [PredictionPoint]
}

struct PredictionsResponse: Codable, Equatable {
    let date: String
    let intervalMinutes: Int
    let levels: [LevelPrediction]
}

struct LevelOccupancy: Codable, Equatable {
    let code: String
    let predictedOccupancy: Double?
}

struct LevelRecommendation: Codable, Equatable {
    let arrivalAt: Date
    let slot: String
    let recommended: String?
    let levels: [LevelOccupancy]

    var recommendedOccupancy: Double? {
        levels.first { $0.code == recommended }?.predictedOccupancy
    }
}
