import Foundation

protocol CachedReservationReading: AnyObject {
    func active(userId: String) async throws -> Fetched<Reservation?>
    func history(userId: String) async throws -> Fetched<[Reservation]>
    func save(active: Reservation?, history: [Reservation], userId: String)
    func vehicle(userId: String) async throws -> Fetched<ParkedVehicle?>
    func clearVehicle(userId: String)
}

final class CachedReservationReader: CachedReservationReading {
    private let service: ReservationServicing
    private let cache: ResponseCache

    init(service: ReservationServicing, cache: ResponseCache = ResponseCache()) {
        self.service = service
        self.cache = cache
    }

    func active(userId: String) async throws -> Fetched<Reservation?> {
        try await cached(key: Self.activeKey(userId)) {
            try await self.service.active()
        }
    }

    func history(userId: String) async throws -> Fetched<[Reservation]> {
        try await cached(key: Self.historyKey(userId)) {
            try await self.service.history()
        }
    }

    func save(active: Reservation?, history: [Reservation], userId: String) {
        let open = active.flatMap { $0.status == .active || $0.status == .fulfilled ? $0 : nil }
        cache.save(open, key: Self.activeKey(userId))
        cache.save(history, key: Self.historyKey(userId))
    }

    func vehicle(userId: String) async throws -> Fetched<ParkedVehicle?> {
        try await cached(key: Self.vehicleKey(userId)) {
            try await self.service.vehicle()
        }
    }

    func clearVehicle(userId: String) {
        cache.save(ParkedVehicle?.none, key: Self.vehicleKey(userId))
    }

    private static func vehicleKey(_ userId: String) -> String {
        "vehicle-\(userId)"
    }

    private static func activeKey(_ userId: String) -> String {
        "reservation-active-\(userId)"
    }

    private static func historyKey(_ userId: String) -> String {
        "reservation-history-\(userId)"
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
}
