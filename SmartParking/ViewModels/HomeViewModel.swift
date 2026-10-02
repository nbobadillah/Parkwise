import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    static let defaultArrivalOffset: TimeInterval = 20 * 60

    @Published private(set) var levels: [LevelSummary] = []
    @Published private(set) var buildings: [Building] = []
    @Published private(set) var campusFull = false
    @Published private(set) var fetchedAt: Date?
    @Published private(set) var fromCache = false
    @Published private(set) var recommendation: LevelRecommendation?
    @Published private(set) var forecastPoints: [PredictionPoint] = []
    @Published private(set) var forecastLevelCode: String?
    @Published private(set) var isLoadingForecast = false
    @Published private(set) var errorMessage: String?
    @Published var arrivalAt = Date().addingTimeInterval(HomeViewModel.defaultArrivalOffset)
    @Published private(set) var selectedBuildingID: String?

    private let service: ParkingServicing
    private let defaults: UserDefaults
    private let selectedBuildingKey = "selectedBuildingID"

    init(service: ParkingServicing, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        selectedBuildingID = defaults.string(forKey: selectedBuildingKey)
    }

    var destinationID: String? {
        guard let selectedBuildingID, buildings.contains(where: { $0.id == selectedBuildingID }) else { return nil }
        return selectedBuildingID
    }

    func loadBuildings() async {
        do {
            let loadedBuildings = try await service.buildings()
            buildings = loadedBuildings
            if let selectedBuildingID, loadedBuildings.contains(where: { $0.id == selectedBuildingID }) {
                return
            }
            guard let firstBuilding = loadedBuildings.first else {
                selectedBuildingID = nil
                defaults.removeObject(forKey: selectedBuildingKey)
                return
            }
            selectBuilding(id: firstBuilding.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectBuilding(id: String) {
        guard buildings.contains(where: { $0.id == id }) else { return }
        selectedBuildingID = id
        defaults.set(id, forKey: selectedBuildingKey)
    }

    func loadLevels() async {
        do {
            let result = try await service.levels(zone: nil)
            levels = result.value.levels
            campusFull = result.value.campusFull
            fetchedAt = result.fetchedAt
            fromCache = result.fromCache
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRecommendation() async {
        do {
            recommendation = try await service.recommendedLevel(arrivalAt: arrivalAt)
        } catch {
            recommendation = nil
        }
    }

    func loadForecast() async {
        guard let levelCode = recommendation?.recommended else {
            forecastPoints = []
            forecastLevelCode = nil
            return
        }

        isLoadingForecast = true
        defer { isLoadingForecast = false }
        do {
            let response = try await service.predictions(level: levelCode, date: Date())
            forecastPoints = response.levels.first(where: { $0.code == levelCode })?.points ?? []
            forecastLevelCode = levelCode
        } catch {
            forecastPoints = []
            forecastLevelCode = levelCode
        }
    }
}
