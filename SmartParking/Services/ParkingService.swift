import Foundation

protocol ParkingServicing: AnyObject {
    func levels(zone: String?) async throws -> Fetched<LevelsResponse>
    func spots(level: String, destination: String?, filters: SpotFilters) async throws -> Fetched<[Spot]>
    func buildings() async throws -> [Building]
    func predictions(level: String?, date: Date) async throws -> PredictionsResponse
    func recommendedLevel(arrivalAt: Date) async throws -> LevelRecommendation
    func nearbyLots() async throws -> [NearbyLot]
}

final class BackendParkingService: ParkingServicing {
    private let client: APIClient
    private let cache: ResponseCache
    private let token: () -> String?

    init(client: APIClient = .shared, cache: ResponseCache = ResponseCache(), token: @escaping () -> String?) {
        self.client = client
        self.cache = cache
        self.token = token
    }

    func levels(zone: String?) async throws -> Fetched<LevelsResponse> {
        let query = zone.map { [URLQueryItem(name: "zone", value: $0)] } ?? []
        return try await cached(key: "levels") {
            try await self.client.send("GET", "/api/v1/levels", query: query, token: self.token())
        }
    }

    func spots(level: String, destination: String?, filters: SpotFilters) async throws -> Fetched<[Spot]> {
        var query = filters.queryItems
        if let destination {
            query.append(URLQueryItem(name: "destination", value: destination))
        }
        let key = (["spots", level, destination ?? "default"] + query.map(\.name)).joined(separator: "-")
        return try await cached(key: key) {
            try await self.client.send("GET", "/api/v1/levels/\(level)/spots", query: query, token: self.token())
        }
    }

    func buildings() async throws -> [Building] {
        try await client.send("GET", "/api/v1/buildings")
    }

    func predictions(level: String?, date: Date) async throws -> PredictionsResponse {
        var query = [URLQueryItem(name: "date", value: Self.bogotaDay(date))]
        if let level {
            query.append(URLQueryItem(name: "level", value: level))
        }
        return try await client.send("GET", "/api/v1/predictions", query: query)
    }

    func recommendedLevel(arrivalAt: Date) async throws -> LevelRecommendation {
        try await client.send(
            "GET",
            "/api/v1/recommendations/level",
            query: [URLQueryItem(name: "arrivalAt", value: APIClient.iso8601String(from: arrivalAt))]
        )
    }

    func nearbyLots() async throws -> [NearbyLot] {
        try await client.send("GET", "/api/v1/nearby-lots")
    }

    private func cached<Value: Codable>(key: String, request: () async throws -> Value) async throws -> Fetched<Value> {
        do {
            let value = try await request()
            let now = Date()
            cache.save(value, key: key, at: now)
            return Fetched(value: value, fetchedAt: now, fromCache: false)
        } catch APIError.network {
            guard let copy = cache.load(Value.self, key: key) else { throw APIError.network }
            return copy
        }
    }

    private static func bogotaDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
