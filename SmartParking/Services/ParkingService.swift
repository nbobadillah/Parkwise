import Foundation

protocol ParkingServicing: AnyObject {
    func levels(zone: String?) async throws -> Fetched<LevelsResponse>
    func spots(level: String, destination: String?, filters: SpotFilters) async throws -> Fetched<[Spot]>
    func buildings() async throws -> Fetched<[Building]>
    func predictions(level: String?, date: Date) async throws -> Fetched<PredictionsResponse>
    func recommendedLevel(arrivalAt: Date) async throws -> Fetched<LevelRecommendation>
    func nearbyLots() async throws -> Fetched<[NearbyLot]>
    func specialSpotsAvailability() async throws -> Fetched<SpecialSpotsAvailabilityResponse>
}

final class BackendParkingService: ParkingServicing {
    private let client: APIClient
    private let cache: ResponseCache
    private let token: () -> String?

    init(
        client: APIClient = .shared,
        cache: ResponseCache = ResponseCache(),
        token: @escaping () -> String?
    ) {
        self.client = client
        self.cache = cache
        self.token = token
    }

    func levels(zone: String?) async throws -> Fetched<LevelsResponse> {
        let query = zone.map {
            [URLQueryItem(name: "zone", value: $0)]
        } ?? []

        // Cada zona debe tener su propia entrada de caché.
        let key = "levels-\(zone ?? "all")"

        return try await cached(key: key) {
            try await self.client.send(
                "GET",
                "/api/v1/levels",
                query: query,
                token: self.token()
            )
        }
    }

    func spots(
        level: String,
        destination: String?,
        filters: SpotFilters
    ) async throws -> Fetched<[Spot]> {
        var query = filters.queryItems

        if let destination {
            query.append(
                URLQueryItem(name: "destination", value: destination)
            )
        }

        // La clave incluye nombres y valores de todos los parámetros.
        // Así no se mezclan respuestas de filtros o destinos diferentes.
        let querySignature = query
            .map { "\($0.name)=\($0.value ?? "")" }
            .sorted()
            .joined(separator: "&")

        let key = [
            "spots",
            level,
            destination ?? "default",
            querySignature
        ].joined(separator: "-")

        return try await cached(key: key) {
            try await self.client.send(
                "GET",
                "/api/v1/levels/\(level)/spots",
                query: query,
                token: self.token()
            )
        }
    }

    func buildings() async throws -> Fetched<[Building]> {
        try await cached(key: "buildings") {
            try await self.client.send("GET", "/api/v1/buildings")
        }
    }

    func predictions(
        level: String?,
        date: Date
    ) async throws -> Fetched<PredictionsResponse> {
        let day = BogotaClock.day(date)
        var query = [URLQueryItem(name: "date", value: day)]

        if let level {
            query.append(URLQueryItem(name: "level", value: level))
        }

        return try await cached(
            key: "predictions-\(day)-\(level ?? "all")"
        ) {
            try await self.client.send(
                "GET",
                "/api/v1/predictions",
                query: query
            )
        }
    }

    func recommendedLevel(
        arrivalAt: Date
    ) async throws -> Fetched<LevelRecommendation> {
        try await cached(
            key: "recommendation-\(BogotaClock.slot(arrivalAt))"
        ) {
            try await self.client.send(
                "GET",
                "/api/v1/recommendations/level",
                query: [
                    URLQueryItem(
                        name: "arrivalAt",
                        value: APIClient.iso8601String(from: arrivalAt)
                    )
                ]
            )
        }
    }

    func nearbyLots() async throws -> Fetched<[NearbyLot]> {
        try await cached(key: "nearby-lots") {
            try await self.client.send("GET", "/api/v1/nearby-lots")
        }
    }

    func specialSpotsAvailability() async throws -> Fetched<SpecialSpotsAvailabilityResponse> {
        try await cached(key: "special-spots-availability") {
            try await self.client.send(
                "GET",
                "/api/v1/special-spots/availability"
            )
        }
    }

    private func cached<Value: Codable>(
        key: String,
        request: () async throws -> Value
    ) async throws -> Fetched<Value> {
        do {
            let value = try await request()
            let now = Date()

            cache.save(value, key: key, at: now)

            return Fetched(
                value: value,
                fetchedAt: now,
                fromCache: false
            )
        } catch APIError.network {
            guard let copy = cache.load(Value.self, key: key) else {
                throw APIError.network
            }

            return copy
        }
    }
}

enum BogotaClock {
    static let slotMinutes = 15

    static func day(_ date: Date) -> String {
        let parts = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )

        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    static func slot(_ date: Date) -> String {
        let parts = calendar.dateComponents(
            [.hour, .minute],
            from: date
        )

        let minute = parts.minute ?? 0

        return String(
            format: "%02d:%02d",
            parts.hour ?? 0,
            minute - minute % slotMinutes
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(
            identifier: "America/Bogota"
        ) ?? .current

        return calendar
    }
}
