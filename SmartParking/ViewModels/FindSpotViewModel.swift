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

struct SpotSearchSession: Equatable {
    enum Mode: String {
        case voice
        case text
    }

    let id: String
    let mode: Mode
    let voiceFallback: Bool

    static func newID() -> String {
        (0..<16).map { _ in String(Int.random(in: 0..<16), radix: 16) }.joined()
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
    @Published private(set) var spokenPhrase: String?
    @Published private(set) var lastLoadFromMemory = false

    private(set) var search: SpotSearchSession?
    private var searchReported = false
    private var typingAfterVoice = false
    private var applyingVoice = false
    private var searchSettle: Task<Void, Never>?
    private var typingSubscription: AnyCancellable?

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

        typingSubscription = $searchQuery
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] query in
                self?.queryTyped(query)
            }
    }

    func searchPhrase(
        _ phrase: String,
        query: VoiceQuery,
        spoken: Bool,
        levels: [LevelSummary],
        destinationID: String?
    ) async {
        startSearch(spoken ? .voice : .text)
        spokenPhrase = spoken ? phrase : nil
        applyingVoice = true
        filter = query.findSpotFilter
        searchQuery = query.searchText
        debouncedQuery = query.searchText
        applyingVoice = false
        await load(levels: levels, destinationID: destinationID)
        reportSearch()
    }

    func typeAfterVoice(_ words: String) {
        endSearch()
        typingAfterVoice = true
        searchQuery = words
    }

    func filterChosen(_ value: FindSpotFilter) {
        endSearch()
        filter = value
    }

    func spotSelected(_ spot: SpotListing) {
        reportSearch()
        TelemetryService.shared.trackSpotSelected(
            levelCode: spot.levelCode,
            spotCode: spot.code,
            searchId: search?.id,
            mode: search?.mode.rawValue
        )
    }

    func reportSearch() {
        guard let search, !searchReported else { return }
        searchReported = true
        TelemetryService.shared.trackSpotSearch(
            searchId: search.id,
            mode: search.mode.rawValue,
            resultCount: spots(matching: searchQuery).count,
            fromCache: lastLoadFromMemory,
            offline: isShowingCachedData,
            voiceFallback: search.voiceFallback
        )
    }

    private func queryTyped(_ query: String) {
        guard !applyingVoice else { return }
        spokenPhrase = nil
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            endSearch()
            return
        }
        if search?.mode != .text {
            startSearch(.text, voiceFallback: typingAfterVoice)
        }
        searchSettle?.cancel()
        searchSettle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reportSearch()
        }
    }

    private func startSearch(_ mode: SpotSearchSession.Mode, voiceFallback: Bool = false) {
        searchSettle?.cancel()
        search = SpotSearchSession(id: SpotSearchSession.newID(), mode: mode, voiceFallback: voiceFallback)
        spokenPhrase = nil
        searchReported = false
        typingAfterVoice = false
    }

    private func endSearch() {
        searchSettle?.cancel()
        search = nil
        spokenPhrase = nil
        searchReported = false
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
            lastLoadFromMemory = true
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

        let service = service

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

            lastLoadFromMemory = false
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
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else {
            return spots
        }

        return spots.filter { spot in
            terms.allSatisfy { term in
                spot.code.localizedCaseInsensitiveContains(term)
                    || spot.levelCode.localizedCaseInsensitiveContains(term)
                    || spot.zone.localizedCaseInsensitiveContains(term)
            }
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