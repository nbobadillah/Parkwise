import CoreLocation
import Foundation

enum LocationPermissionPrompt: String, Identifiable {
    case explanation
    case settings

    var id: String { rawValue }
}

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
    @Published private(set) var nearbyLots: [NearbyLot] = []
    @Published private(set) var isLoadingNearbyLots = false
    @Published private(set) var nearbyLotsErrorMessage: String?
    @Published var locationPermissionPrompt: LocationPermissionPrompt?
    @Published private(set) var errorMessage: String?
    @Published var arrivalAt = Date().addingTimeInterval(HomeViewModel.defaultArrivalOffset)
    @Published private(set) var selectedBuildingID: String?

    private let service: ParkingServicing
    private let locationService: LocationServicing
    private let defaults: UserDefaults
    private let selectedBuildingKey = "selectedBuildingID"
    private var lastLoadedZone: String?

    init(
        service: ParkingServicing,
        locationService: LocationServicing = LocationService.shared,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.locationService = locationService
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

    func prepareLocationPermission() {
        if locationService.isDenied {
            locationPermissionPrompt = .settings
        } else if !locationService.isAuthorized {
            locationPermissionPrompt = .explanation
        } else {
            locationService.start()
        }
    }

    func requestLocationPermission() {
        locationPermissionPrompt = nil
        locationService.start()
    }

    func dismissLocationPermissionPrompt() {
        locationPermissionPrompt = nil
    }

    func locationAuthorizationDidChange() {
        if locationService.isDenied {
            locationPermissionPrompt = .settings
        } else if locationService.isAuthorized {
            locationPermissionPrompt = nil
            locationService.start()
        }
    }

    func loadLevels(isAuthenticated: Bool) async {
        await loadLevels(zone: currentZone(isAuthenticated: isAuthenticated))
    }

    func refreshLevelsForLocationChange(isAuthenticated: Bool) async {
        let zone = currentZone(isAuthenticated: isAuthenticated)
        guard zone != lastLoadedZone else { return }
        await loadLevels(zone: zone)
    }

    static func roundedZone(for location: CLLocation?) -> String? {
        guard let coordinate = location?.coordinate else { return nil }
        return String(
            format: "%.2f,%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
    }

    private func currentZone(isAuthenticated: Bool) -> String? {
        guard isAuthenticated, locationService.isAuthorized else { return nil }
        return Self.roundedZone(for: locationService.currentLocation)
    }

    private func loadLevels(zone: String?) async {
        do {
            let result = try await service.levels(zone: zone)
            levels = result.value.levels
            campusFull = result.value.campusFull
            lastLoadedZone = zone
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

    func loadNearbyLots() async {
        isLoadingNearbyLots = true
        nearbyLotsErrorMessage = nil
        defer { isLoadingNearbyLots = false }

        do {
            nearbyLots = try await service.nearbyLots()
        } catch {
            nearbyLotsErrorMessage = error.localizedDescription
        }
    }
}
