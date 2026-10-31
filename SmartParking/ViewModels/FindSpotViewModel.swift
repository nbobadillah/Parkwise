import Combine
import Foundation

private final class SpotMemoryCacheEntry: NSObject {
    let spots: [SpotListing]
    let savedAt: Date
    let fromResponseCache: Bool

    init(
        spots: [SpotListing],
        savedAt: Date,
        fromResponseCache: Bool
    ) {
        self.spots = spots
        self.savedAt = savedAt
        self.fromResponseCache = fromResponseCache
    }
}

@MainActor
final class FindSpotViewModel: ObservableObject {
    private static let filterPreferenceKey = "findSpot.lastFilter"
    private static let cacheTTL: TimeInterval = 30

    @Published private(set) var spots: [SpotListing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isShowingCachedData = false

    @Published var filter: FindSpotFilter {
        didSet {
            UserDefaults.standard.set(
                filter.rawValue,
                forKey: Self.filterPreferenceKey
            )
        }
    }

    @Published var searchQuery = ""
    @Published private(set) var debouncedQuery = ""

    private let service: ParkingServicing
    private let memoryCache = NSCache<NSString, SpotMemoryCacheEntry>()
    private var searchSubscription: AnyCancellable?

    var recommendedSpot: SpotListing? {
        spots.first
    }

    init(
        service: ParkingServicing,
        initialFilter: FindSpotFilter? = nil
    ) {
        self.service = service

        let savedFilter = UserDefaults.standard.string(
            forKey: Self.filterPreferenceKey
        )

        let resolvedFilter = initialFilter
            ?? savedFilter.flatMap(FindSpotFilter.init(rawValue:))
            ?? .available

        filter = resolvedFilter

        // Persistir también el filtro recibido inicialmente.
        UserDefaults.standard.set(
            resolvedFilter.rawValue,
            forKey: Self.filterPreferenceKey
        )

        memoryCache.countLimit = 16

        searchSubscription = $searchQuery
            .debounce(
                for: .milliseconds(150),
                scheduler: RunLoop.main
            )
            .removeDuplicates()
            .sink { [weak self] query in
                self?.debouncedQuery = query
            }
    }

    func load(
        levels: [LevelSummary],
        destinationID: String?
    ) async {
        guard !levels.isEmpty else {
            spots = []
            errorMessage = nil
            isShowingCachedData = false
            return
        }

        let selectedFilter = filter

        let cacheKey = memoryCacheKey(
            levels: levels,
            destinationID: destinationID,
            filter: selectedFilter
        )

        if let cached = memoryCache.object(
            forKey: cacheKey as NSString
        ),
           Date().timeIntervalSince(cached.savedAt) < Self.cacheTTL {
            spots = cached.spots
            isShowingCachedData = cached.fromResponseCache
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            // Descargar todas las plazas sin filtrar desde el backend.
            let fetchedResults = try await withThrowingTaskGroup(
                of: Fetched<[Spot]>.self,
                returning: [Fetched<[Spot]>].self
            ) { group in
                for level in levels {
                    group.addTask { @MainActor in
                        try await service.spots(
                            level: level.code,
                            destination: destinationID,
                            filters: SpotFilters()
                        )
                    }
                }

                var results: [Fetched<[Spot]>] = []

                for try await result in group {
                    results.append(result)
                }

                return results
            }

            guard !Task.isCancelled else {
                return
            }

            let allListings = fetchedResults
                .flatMap(\.value)
                .map(SpotListing.init(spot:))

            // Filtrar y ordenar fuera del hilo principal.
            let processedSpots = await Task.detached(
                priority: .userInitiated
            ) {
                allListings
                    .filter {
                        $0.matches(selectedFilter)
                    }
                    .sorted {
                        if $0.walkMinutes != $1.walkMinutes {
                            return $0.walkMinutes < $1.walkMinutes
                        }

                        return $0.code.localizedStandardCompare($1.code)
                            == .orderedAscending
                    }
            }.value

            guard !Task.isCancelled else {
                return
            }

            let cameFromResponseCache = fetchedResults.contains {
                $0.fromCache
            }

            spots = processedSpots
            isShowingCachedData = cameFromResponseCache

            memoryCache.setObject(
                SpotMemoryCacheEntry(
                    spots: processedSpots,
                    savedAt: Date(),
                    fromResponseCache: cameFromResponseCache
                ),
                forKey: cacheKey as NSString
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }

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

    private func memoryCacheKey(
        levels: [LevelSummary],
        destinationID: String?,
        filter: FindSpotFilter
    ) -> String {
        let levelSignature = levels
            .map(\.code)
            .sorted()
            .joined(separator: ",")

        return [
            destinationID ?? "default",
            filter.rawValue,
            levelSignature
        ].joined(separator: "|")
    }
}