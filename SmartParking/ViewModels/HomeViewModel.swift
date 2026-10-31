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
    @Published private(set) var recommendationFetchedAt: Date?
    @Published private(set) var recommendationFromCache = false
    @Published private(set) var forecast: PredictionsResponse?
    @Published private(set) var isLoadingForecast = false
    @Published private(set) var nearbyLots: [NearbyLot] = []
    @Published private(set) var isLoadingNearbyLots = false
    @Published private(set) var nearbyLotsErrorMessage: String?

    // Accessible and EV spots
    @Published private(set) var specialSpotsAvailability: SpecialSpotsAvailabilityResponse?
    @Published private(set) var specialSpotsFetchedAt: Date?
    @Published private(set) var specialSpotsFromCache = false
    @Published private(set) var isLoadingSpecialSpots = false
    @Published private(set) var specialSpotsErrorMessage: String?

    @Published var locationPermissionPrompt: LocationPermissionPrompt?
    @Published private(set) var errorMessage: String?
    @Published var arrivalAt = Date().addingTimeInterval(HomeViewModel.defaultArrivalOffset)
    @Published private(set) var selectedBuildingID: String?

    private let service: ParkingServicing
    private let locationService: LocationServicing
    private let telemetry: TelemetryService
    private let defaults: UserDefaults
    private let selectedBuildingKey = "selectedBuildingID"
    private var lastLoadedZone: String?
    private var lastViewedSlot: String?

    init(
        service: ParkingServicing,
        locationService: LocationServicing = LocationService.shared,
        telemetry: TelemetryService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.locationService = locationService
        self.telemetry = telemetry ?? .shared
        self.defaults = defaults
        selectedBuildingID = defaults.string(forKey: selectedBuildingKey)
    }

    var forecastLevelCode: String? {
        recommendation?.recommended ?? forecast?.levels.first?.code
    }

    var forecastPoints: [PredictionPoint] {
        forecast?.levels.first { $0.code == forecastLevelCode }?.points ?? []
    }

    var destinationID: String? {
        guard let selectedBuildingID,
              buildings.contains(where: { $0.id == selectedBuildingID })
        else {
            return nil
        }
        return selectedBuildingID
    }

    func loadBuildings() async {
        do {
            let loadedBuildings = try await service.buildings().value
            buildings = loadedBuildings

            if let selectedBuildingID,
               loadedBuildings.contains(where: { $0.id == selectedBuildingID }) {
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

    func loadArrivalData() async {
        async let recommendationLoad: Void = loadRecommendation()
        async let forecastLoad: Void = loadForecast()
        _ = await (recommendationLoad, forecastLoad)
    }

    func prefetchLevels() async {
        let service = service
        let destination = destinationID

        await withTaskGroup(of: Void.self) { group in
            for levelCode in ["P1", "P2", "P3"] {
                group.addTask {
                    _ = try? await service.spots(
                        level: levelCode,
                        destination: destination,
                        filters: SpotFilters()
                    )
                }
            }
        }
    }

    func loadRecommendation() async {
        let loaded: Fetched<LevelRecommendation>

        do {
            loaded = try await service.recommendedLevel(arrivalAt: arrivalAt)
        } catch {
            guard let local = await localRecommendation() else {
                recommendation = nil
                recommendationFetchedAt = nil
                recommendationFromCache = false
                return
            }
            loaded = local
        }

        recommendation = loaded.value
        recommendationFetchedAt = loaded.fetchedAt
        recommendationFromCache = loaded.fromCache
        trackForecastViewed(slot: loaded.value.slot)
    }

    private func localRecommendation() async -> Fetched<LevelRecommendation>? {
        guard let forecast = try? await service.predictions(level: nil, date: arrivalAt) else {
            return nil
        }

        let slot = BogotaClock.slot(arrivalAt)
        let levels = forecast.value.levels.map { level in
            LevelOccupancy(
                code: level.code,
                predictedOccupancy: level.points.first { $0.slot == slot }?.occupancy
            )
        }

        let recommended = levels
            .compactMap { level in
                level.predictedOccupancy.map { (level.code, $0) }
            }
            .min { $0.1 < $1.1 }?
            .0

        guard recommended != nil else { return nil }

        let recommendation = LevelRecommendation(
            arrivalAt: arrivalAt,
            slot: slot,
            recommended: recommended,
            levels: levels
        )

        return Fetched(
            value: recommendation,
            fetchedAt: forecast.fetchedAt,
            fromCache: true
        )
    }

    private func trackForecastViewed(slot: String) {
        guard slot != lastViewedSlot else { return }

        let source = lastViewedSlot == nil ? "home_open" : "arrival_change"
        lastViewedSlot = slot
        telemetry.trackForecastViewed(
            screen: "home",
            arrivalSlot: slot,
            source: source
        )
    }

    func loadForecast() async {
        isLoadingForecast = true
        defer { isLoadingForecast = false }

        forecast = try? await service.predictions(
            level: nil,
            date: arrivalAt
        ).value
    }

    func loadNearbyLots() async {
        isLoadingNearbyLots = true
        nearbyLotsErrorMessage = nil
        defer { isLoadingNearbyLots = false }

        do {
            nearbyLots = try await service.nearbyLots().value
        } catch {
            nearbyLotsErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Accessible and EV spots

    func loadSpecialSpotsAvailability() async {
        isLoadingSpecialSpots = true
        specialSpotsErrorMessage = nil
        defer { isLoadingSpecialSpots = false }

        do {
            let result = try await service.specialSpotsAvailability()
            specialSpotsAvailability = result.value
            specialSpotsFetchedAt = result.fetchedAt
            specialSpotsFromCache = result.fromCache
        } catch {
            specialSpotsErrorMessage = error.localizedDescription
        }
    }
}
