import Foundation

struct WeekForecastFileStore: Sendable {
    static let fileName = "week_forecast.json"

    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    func load() async -> WeekForecast? {
        try? read()
    }

    func read() throws -> WeekForecast? {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        return try Self.decoder().decode(WeekForecast.self, from: data)
    }

    func save(levels: [WeekLevelForecast], hours: [Int], savedAt: Date) throws {
        let previous = try? read()
        let forecast = previous?.merging(levels, hours: hours, savedAt: savedAt)
            ?? WeekForecast(savedAt: savedAt, hours: hours, levels: levels.sorted { $0.code < $1.code })
        try write(forecast)
    }

    func write(_ forecast: WeekForecast) throws {
        let url = try fileURL()
        let data = try Self.encoder().encode(forecast)
        let temporary = url
            .deletingLastPathComponent()
            .appending(path: "\(Self.fileName).\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        do {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private func fileURL() throws -> URL {
        let base = try directory ?? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: Self.fileName)
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
