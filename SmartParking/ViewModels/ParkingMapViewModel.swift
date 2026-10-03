import Foundation

@MainActor
final class ParkingMapViewModel: ObservableObject {
    static let refreshInterval: Duration = .seconds(5)

    @Published private(set) var zones: [ParkingZone] = []
    @Published private(set) var fetchedAt: Date?
    @Published private(set) var fromCache = false
    @Published private(set) var errorMessage: String?
    @Published var selectedSpotID: String?

    var destination: String?
    var filters = SpotFilters()

    private let service: ParkingServicing
    private let telemetry: TelemetryService

    init(service: ParkingServicing, destination: String? = nil, telemetry: TelemetryService? = nil) {
        self.service = service
        self.destination = destination
        self.telemetry = telemetry ?? .shared
    }

    var selectedSpot: ParkingSpot? {
        guard let selectedSpotID else { return nil }
        return zones.lazy.flatMap(\.rows).flatMap(\.spots).first { $0.id == selectedSpotID }
    }

    func run(levelCode: String) async {
        zones = []
        selectedSpotID = nil

        let start = ContinuousClock.now
        let errorType = await refresh(levelCode: levelCode)
        guard !Task.isCancelled else { return }
        telemetry.trackMapLoaded(levelCode: levelCode, durationMs: Self.milliseconds(since: start), errorType: errorType)

        while !Task.isCancelled {
            try? await Task.sleep(for: Self.refreshInterval)
            guard !Task.isCancelled else { return }
            await refresh(levelCode: levelCode)
        }
    }

    @discardableResult
    func refresh(levelCode: String) async -> String? {
        do {
            let result = try await service.spots(level: levelCode, destination: destination, filters: filters)
            guard !Task.isCancelled else { return nil }
            zones = ParkingZone.zones(from: result.value)
            fetchedAt = result.fetchedAt
            fromCache = result.fromCache
            errorMessage = nil
            return result.fromCache ? "network" : nil
        } catch {
            errorMessage = error.localizedDescription
            return Self.errorType(for: error)
        }
    }

    private static func errorType(for error: Error) -> String {
        switch error {
        case APIError.network: return "network"
        case APIError.server(let status, _): return "http_\(status)"
        case APIError.decoding: return "decoding"
        default: return "unknown"
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let elapsed = start.duration(to: .now).components
        return Int(elapsed.seconds) * 1000 + Int(elapsed.attoseconds / 1_000_000_000_000_000)
    }
}
