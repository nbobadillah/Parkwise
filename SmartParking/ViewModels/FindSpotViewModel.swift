import Foundation

@MainActor
final class FindSpotViewModel: ObservableObject {
    @Published private(set) var spots: [SpotListing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var filter: FindSpotFilter = .available

    var recommendedSpot: SpotListing? {
        spots.first
    }

    private let service: ParkingServicing

    init(service: ParkingServicing) {
        self.service = service
    }

    func load(levels: [LevelSummary], destinationID: String?) async {
        isLoading = true
        errorMessage = nil
        spots = []
        defer { isLoading = false }

        do {
            let strategy = SpotFilterStrategyFactory.strategy(for: filter)
            var fetchedSpots: [Spot] = []

            for level in levels {
                let result = try await service.spots(
                    level: level.code,
                    destination: destinationID,
                    filters: strategy.requestFilters
                )

                fetchedSpots.append(contentsOf: result.value)
            }

            guard !Task.isCancelled else { return }

            spots = fetchedSpots
                .map(SpotListing.init(spot:))
                .sorted {
                    if $0.walkMinutes != $1.walkMinutes {
                        return $0.walkMinutes < $1.walkMinutes
                    }

                    return $0.code.localizedStandardCompare($1.code) == .orderedAscending
                }
        } catch {
            guard !Task.isCancelled else { return }

            errorMessage = error.localizedDescription
        }
    }

    func spots(matching query: String) -> [SpotListing] {
        guard !query.isEmpty else {
            return spots
        }

        return spots.filter {
            $0.code.localizedCaseInsensitiveContains(query)
                || $0.levelCode.localizedCaseInsensitiveContains(query)
                || $0.zone.localizedCaseInsensitiveContains(query)
        }
    }
}