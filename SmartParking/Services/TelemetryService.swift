import Foundation

enum TelemetryValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

struct TelemetryEvent: Codable, Equatable {
    let name: String
    let properties: [String: TelemetryValue]
}

@MainActor
final class TelemetryService {
    static let shared = TelemetryService()

    private struct Accepted: Decodable {
        let accepted: Bool
    }

    private let client: APIClient
    private let defaults: UserDefaults
    private let key = "pendingTelemetry"
    private let maxPending = 200
    private var isFlushing = false

    private(set) var pending: [TelemetryEvent]

    init(client: APIClient = .shared, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        pending = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([TelemetryEvent].self, from: $0) } ?? []
    }

    func track(_ name: String, _ properties: [String: TelemetryValue] = [:]) {
        pending.append(TelemetryEvent(name: name, properties: properties))
        if pending.count > maxPending {
            pending.removeFirst(pending.count - maxPending)
        }
        persist()
        Task { await flush() }
    }

    func trackWalkingTimeViewed(spotCode: String, levelCode: String, minutes: Int, source: String) {
        track("walking_time_viewed", [
            "spotCode": .string(spotCode),
            "levelCode": .string(levelCode),
            "minutes": .int(minutes),
            "source": .string(source)
        ])
    }

    func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let event = pending.first {
            do {
                let _: Accepted = try await client.send("POST", "/api/v1/telemetry", body: event)
                pending.removeFirst()
                persist()
            } catch APIError.server(let status, _) where (400..<500).contains(status) {
                pending.removeFirst()
                persist()
            } catch {
                return
            }
        }
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(pending), forKey: key)
    }
}
