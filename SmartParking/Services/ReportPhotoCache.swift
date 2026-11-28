import Foundation
import CryptoKit

actor ReportPhotoCache {

    static let maxEntries = 50
    static let ttl: TimeInterval = 14 * 24 * 60 * 60

    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    private let service: ReportServicing

    private var memory: [String: Entry] = [:]
    private var generations: [String: UUID] = [:]

    init(
        service: ReportServicing = BackendReportService()
    ) {
        self.service = service
    }

    // MARK: - Load photo

    func photo(
        for report: SpotReport,
        userId: String,
        token: String,
        connected: Bool
    ) async throws -> Data {

        guard report.hasPhoto,
              let reportId = UUID(uuidString: report.id) else {
            throw APIError.server(
                status: 404,
                message: "Report photo not found."
            )
        }

        let key = cacheKey(
            reportId: reportId,
            userId: userId
        )

        let now = Date()

        // 1. Memory cache
        if let entry = memory[key] {

            if isFresh(entry.storedAt, now: now) {
                return entry.data
            }

            memory.removeValue(forKey: key)
        }

        // 2. Disk cache
        if let url = try? fileURL(
            reportId: reportId,
            userId: userId
        ) {

            if let entry = readDisk(
                url: url,
                now: now
            ) {

                remember(entry, key: key)

                return entry.data
            }
        }

        // 3. Network fallback
        guard connected else {
            throw APIError.network
        }

        let generation = generationForUser(userId)

        let data = try await service.photo(
            for: report,
            token: token
        )

        try Task.checkCancellation()

        // Do not recreate cached data after logout.
        guard generations[userId] == generation else {
            throw CancellationError()
        }

        guard isValidPhoto(data) else {
            throw APIError.decoding
        }

        let entry = Entry(
            data: data,
            storedAt: Date()
        )

        remember(entry, key: key)

        if let url = try? fileURL(
            reportId: reportId,
            userId: userId
        ) {

            try? data.write(
                to: url,
                options: .atomic
            )

            pruneDisk(userId: userId)
        }

        return data
    }

    // MARK: - Memory cache

    private func remember(
        _ entry: Entry,
        key: String
    ) {

        let now = Date()

        memory = memory.filter {
            isFresh($0.value.storedAt, now: now)
        }

        memory[key] = entry

        while memory.count > Self.maxEntries {

            guard let oldest = memory.min(
                by: {
                    $0.value.storedAt <
                    $1.value.storedAt
                }
            )?.key else {
                break
            }

            memory.removeValue(
                forKey: oldest
            )
        }
    }

    // MARK: - Disk cache

    private func readDisk(
        url: URL,
        now: Date
    ) -> Entry? {

        guard let values = try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ),
        let storedAt = values.contentModificationDate else {
            return nil
        }

        guard isFresh(storedAt, now: now),
              let data = try? Data(contentsOf: url),
              isValidPhoto(data) else {

            try? FileManager.default.removeItem(
                at: url
            )

            return nil
        }

        return Entry(
            data: data,
            storedAt: storedAt
        )
    }

    private func pruneDisk(userId: String) {

        guard let directory = try? cacheDirectory(
            userId: userId
        ),
        let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()

        var valid: [(url: URL, date: Date)] = []

        for file in files {

            guard file.pathExtension == "jpg",
                  let values = try? file.resourceValues(
                      forKeys: [
                          .contentModificationDateKey,
                          .isRegularFileKey
                      ]
                  ),
                  values.isRegularFile == true else {
                continue
            }

            guard let date = values.contentModificationDate,
                  isFresh(date, now: now) else {

                try? FileManager.default.removeItem(
                    at: file
                )

                continue
            }

            valid.append(
                (url: file, date: date)
            )
        }

        valid.sort {
            $0.date > $1.date
        }

        for entry in valid.dropFirst(Self.maxEntries) {

            try? FileManager.default.removeItem(
                at: entry.url
            )
        }
    }

    // MARK: - Logout cleanup

    func clear(userId: String) {

        // Invalidate any download still in progress.
        generations[userId] = UUID()

        let prefix = userHash(userId) + "/"

        memory = memory.filter {
            !$0.key.hasPrefix(prefix)
        }

        if let directory = try? cacheDirectory(
            userId: userId
        ) {

            try? FileManager.default.removeItem(
                at: directory
            )
        }
    }

    // MARK: - Helpers

    private func isFresh(
        _ date: Date,
        now: Date
    ) -> Bool {

        let age = now.timeIntervalSince(date)

        return age >= 0 && age < Self.ttl
    }

    private func isValidPhoto(
        _ data: Data
    ) -> Bool {

        data.count <= ReportPhotoCompressor.maxBytes &&
        data.starts(with: [0xFF, 0xD8, 0xFF])
    }

    private func generationForUser(
        _ userId: String
    ) -> UUID {

        if let generation = generations[userId] {
            return generation
        }

        let generation = UUID()

        generations[userId] = generation

        return generation
    }

    private func userHash(
        _ userId: String
    ) -> String {

        SHA256.hash(
            data: Data(userId.utf8)
        )
        .map {
            String(format: "%02x", $0)
        }
        .joined()
    }

    private func cacheKey(
        reportId: UUID,
        userId: String
    ) -> String {

        "\(userHash(userId))/\(reportId.uuidString)"
    }

    private func cacheDirectory(
        userId: String
    ) throws -> URL {

        let manager = FileManager.default

        let caches = try manager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = caches
            .appendingPathComponent(
                "ReportPhotos",
                isDirectory: true
            )
            .appendingPathComponent(
                userHash(userId),
                isDirectory: true
            )

        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directory
    }

    private func fileURL(
        reportId: UUID,
        userId: String
    ) throws -> URL {

        try cacheDirectory(
            userId: userId
        )
        .appendingPathComponent(
            "\(reportId.uuidString).jpg"
        )
    }
}