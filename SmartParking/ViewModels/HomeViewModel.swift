import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    static let defaultArrivalOffset: TimeInterval = 20 * 60

    @Published private(set) var levels: [LevelSummary] = []
    @Published private(set) var campusFull = false
    @Published private(set) var fetchedAt: Date?
    @Published private(set) var fromCache = false
    @Published private(set) var recommendation: LevelRecommendation?
    @Published private(set) var errorMessage: String?
    @Published var arrivalAt = Date().addingTimeInterval(HomeViewModel.defaultArrivalOffset)

    private let service: ParkingServicing

    init(service: ParkingServicing) {
        self.service = service
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
}
