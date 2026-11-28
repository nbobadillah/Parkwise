import Foundation
import CryptoKit

// MARK: - ArrayMap

struct ReportArrayMap<Value> {

    private struct Entry {
        let key: String
        let value: Value
        let insertedAt: Date
    }

    private var hashes: [Int] = []
    private var entries: [Entry] = []

    private let maxEntries: Int
    private let ttl: TimeInterval

    init(
        maxEntries: Int = 32,
        ttl: TimeInterval = 60
    ) {
        self.maxEntries = max(1, maxEntries)
        self.ttl = ttl
    }

    var count: Int {
        entries.count
    }

    // MARK: - Lookup

    mutating func value(
        for key: String,
        now: Date = Date()
    ) -> Value? {

        guard let index = indexForKey(key) else {
            return nil
        }

        let entry = entries[index]

        guard now.timeIntervalSince(
            entry.insertedAt
        ) < ttl else {

            remove(at: index)
            return nil
        }

        return entry.value
    }

    // MARK: - Insert

    mutating func insert(
        _ value: Value,
        for key: String,
        now: Date = Date()
    ) {

        removeExpired(now: now)

        let entry = Entry(
            key: key,
            value: value,
            insertedAt: now
        )

        if let index = indexForKey(key) {
            entries[index] = entry
            return
        }

        let hash = key.hashValue
        let index = lowerBound(hash)

        hashes.insert(hash, at: index)
        entries.insert(entry, at: index)

        if entries.count > maxEntries {

            if let oldest = entries.indices.min(
                by: {
                    entries[$0].insertedAt <
                    entries[$1].insertedAt
                }
            ) {
                remove(at: oldest)
            }
        }
    }

    // MARK: - Binary search

    private func lowerBound(
        _ hash: Int
    ) -> Int {

        var low = 0
        var high = hashes.count

        while low < high {

            let middle = low + (high - low) / 2

            if hashes[middle] < hash {
                low = middle + 1
            } else {
                high = middle
            }
        }

        return low
    }

    private func indexForKey(
        _ key: String
    ) -> Int? {

        let hash = key.hashValue
        var index = lowerBound(hash)

        // Resolve hash collisions using the original key.
        while index < hashes.count,
              hashes[index] == hash {

            if entries[index].key == key {
                return index
            }

            index += 1
        }

        return nil
    }

    // MARK: - Cleanup

    private mutating func removeExpired(
        now: Date
    ) {

        for index in entries.indices.reversed() {

            if now.timeIntervalSince(
                entries[index].insertedAt
            ) >= ttl {

                remove(at: index)
            }
        }
    }

    private mutating func remove(
        at index: Int
    ) {
        hashes.remove(at: index)
        entries.remove(at: index)
    }

    mutating func removeAll() {
        hashes.removeAll()
        entries.removeAll()
    }
}

// MARK: - Cached history

struct ReportHistorySnapshot: Codable {

    let reports: [SpotReport]
    let fetchedAt: Date?

    var isFresh: Bool {

        guard let fetchedAt else {
            return false
        }

        let age = Date().timeIntervalSince(fetchedAt)

        return age >= 0 && age < 60
    }
}

// MARK: - History cache

actor ReportHistoryCache {

    private var index = ReportArrayMap<SpotReport>(
        maxEntries: 32,
        ttl: 60
    )

    private var activeUserId: String?

    private var current = ReportHistorySnapshot(
        reports: [],
        fetchedAt: nil
    )

    // MARK: - Load cached history

    func load(
        userId: String
    ) -> ReportHistorySnapshot {

        if activeUserId == userId {
            return current
        }

        activeUserId = userId
        index.removeAll()

        current = ReportHistorySnapshot(
            reports: [],
            fetchedAt: nil
        )

        if let url = try? fileURL(userId: userId),
           let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(
               ReportHistorySnapshot.self,
               from: data
           ) {

            current = saved
        }

        rebuildIndex()

        return current
    }

    // MARK: - Save server response

    func save(
        _ reports: [SpotReport],
        userId: String
    ) -> ReportHistorySnapshot {

        _ = load(userId: userId)

        current = ReportHistorySnapshot(
            reports: normalized(reports),
            fetchedAt: Date()
        )

        rebuildIndex()
        persist(userId: userId)

        return current
    }

    // MARK: - Insert newly accepted reports

    func mergeSent(
        _ reports: [SpotReport],
        userId: String
    ) -> ReportHistorySnapshot {

        _ = load(userId: userId)

        var merged = current.reports

        for report in reports {

            let key = report.clientId.lowercased()

            if let cached = index.value(for: key),
               cached == report {
                continue
            }

            merged.removeAll {
                $0.clientId.lowercased() == key
            }

            merged.append(report)
        }

        let updated = normalized(merged)

        guard updated != current.reports else {
            return current
        }

        current = ReportHistorySnapshot(
            reports: updated,
            fetchedAt: current.fetchedAt
        )

        rebuildIndex()
        persist(userId: userId)

        return current
    }

    // MARK: - Cache cleanup

    func clear(userId: String) {

        if activeUserId == userId {

            activeUserId = nil
            index.removeAll()

            current = ReportHistorySnapshot(
                reports: [],
                fetchedAt: nil
            )
        }

        if let url = try? fileURL(userId: userId) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    private func rebuildIndex() {

        index.removeAll()

        for report in current.reports.prefix(32) {

            index.insert(
                report,
                for: report.clientId.lowercased()
            )
        }
    }

    private func normalized(
        _ reports: [SpotReport]
    ) -> [SpotReport] {

        var seen = Set<String>()

        let sorted = reports.sorted {
            $0.reportedAt > $1.reportedAt
        }

        let unique = sorted.filter {
            seen.insert(
                $0.clientId.lowercased()
            ).inserted
        }

        return Array(unique.prefix(50))
    }

    private func persist(userId: String) {

        guard let url = try? fileURL(userId: userId),
              let data = try? JSONEncoder().encode(
                  current
              ) else {
            return
        }

        try? data.write(
            to: url,
            options: .atomic
        )
    }

    private func fileURL(
        userId: String
    ) throws -> URL {

        let manager = FileManager.default

        let caches = try manager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = caches.appendingPathComponent(
            "ReportHistory",
            isDirectory: true
        )

        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let filename = SHA256.hash(
            data: Data(userId.utf8)
        )
        .map {
            String(format: "%02x", $0)
        }
        .joined()

        return directory.appendingPathComponent(
            "\(filename).json"
        )
    }
}