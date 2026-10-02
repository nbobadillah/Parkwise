import Foundation

struct Fetched<Value> {
    let value: Value
    let fetchedAt: Date
    let fromCache: Bool
}

final class ResponseCache {
    private struct Entry<Value: Codable>: Codable {
        let savedAt: Date
        let value: Value
    }

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "ParkwiseCache")) {
        self.directory = directory
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save<Value: Codable>(_ value: Value, key: String, at date: Date = Date()) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(Entry(savedAt: date, value: value)) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func load<Value: Codable>(_ type: Value.Type, key: String) -> Fetched<Value>? {
        guard
            let data = try? Data(contentsOf: fileURL(for: key)),
            let entry = try? decoder.decode(Entry<Value>.self, from: data)
        else { return nil }
        return Fetched(value: entry.value, fetchedAt: entry.savedAt, fromCache: true)
    }

    private func fileURL(for key: String) -> URL {
        let name = key.map { $0.isLetter || $0.isNumber ? $0 : "_" }
        return directory.appending(path: String(name) + ".json")
    }
}
