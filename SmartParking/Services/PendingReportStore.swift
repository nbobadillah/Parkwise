import Foundation
import SwiftData
import CryptoKit

// MARK: - Sendable snapshot

struct QueuedReport: Identifiable, Sendable {

    let clientId: UUID
    let userId: String

    let spotId: String
    let spotCode: String
    let levelCode: String

    let kind: ReportKind
    let shownStatus: SpotStatus

    let note: String?
    let reportedAt: Date

    let photoFilename: String?

    let state: ReportDeliveryState
    let attempts: Int
    let failureMessage: String?

    var id: UUID {
        clientId
    }

    var displayCode: String {
        "\(levelCode)-\(spotCode)"
    }

    var hasPhoto: Bool {
        photoFilename != nil
    }
}

// MARK: - Storage errors

enum PendingReportStoreError: LocalizedError {

    case invalidRecord
    case invalidPhoto

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Could not read the saved report."
        case .invalidPhoto:
            return "Could not read the report photo."
        }
    }
}

// MARK: - SwiftData storage

@ModelActor
actor PendingReportStore {

    // MARK: - Container

    static func make() throws -> PendingReportStore {

        let container = try ModelContainer(
            for: PendingReport.self,
            configurations: ModelConfiguration(
                "PendingReports"
            )
        )

        return PendingReportStore(
            modelContainer: container
        )
    }

    // MARK: - Enqueue

    func enqueue(
        userId: String,
        spot: ReportSpot,
        kind: ReportKind,
        note: String?,
        photo: Data?,
        reportedAt: Date = Date()
    ) throws -> QueuedReport {

        let clientId = UUID()

        let cleanNote = note?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let finalNote: String? = cleanNote.flatMap {
            $0.isEmpty
                ? nil
                : String($0.prefix(280))
        }

        var photoFilename: String?
        var savedPhotoURL: URL?

        if let photo {

            guard photo.count <= ReportPhotoCompressor.maxBytes,
                  photo.starts(with: [0xFF, 0xD8, 0xFF]) else {
                throw PendingReportStoreError.invalidPhoto
            }

            let filename = "\(clientId.uuidString).jpg"

            let directory = try photoDirectory(
                userId: userId
            )

            let url = directory.appendingPathComponent(
                filename
            )

            try photo.write(
                to: url,
                options: .atomic
            )

            photoFilename = filename
            savedPhotoURL = url
        }

        let report = PendingReport(
            clientId: clientId,
            userId: userId,
            spot: spot,
            kind: kind,
            note: finalNote,
            reportedAt: reportedAt,
            photoFilename: photoFilename
        )

        modelContext.insert(report)

        do {
            let result = try snapshot(report)

            try modelContext.save()

            return result

        } catch {

            modelContext.rollback()

            if let savedPhotoURL {
                try? FileManager.default.removeItem(
                    at: savedPhotoURL
                )
            }

            throw error
        }
    }

    // MARK: - Fetch reports

    func pending(
        userId: String
    ) throws -> [QueuedReport] {

        try records(userId: userId).map {
            try snapshot($0)
        }
    }

    private func records(
        userId: String
    ) throws -> [PendingReport] {

        let descriptor = FetchDescriptor<PendingReport>(
            predicate: #Predicate {
                $0.userId == userId
            },
            sortBy: [
                SortDescriptor(\.reportedAt)
            ]
        )

        return try modelContext.fetch(descriptor)
    }

    private func find(
        clientId: UUID,
        userId: String
    ) throws -> PendingReport? {

        var descriptor = FetchDescriptor<PendingReport>(
            predicate: #Predicate {
                $0.clientId == clientId &&
                $0.userId == userId
            }
        )

        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Report state

    func markSending(
        clientId: UUID,
        userId: String
    ) throws -> QueuedReport? {

        guard let report = try find(
            clientId: clientId,
            userId: userId
        ),
        report.state == .waiting else {
            return nil
        }

        report.stateRawValue =
            ReportDeliveryState.sending.rawValue

        report.attempts += 1
        report.failureMessage = nil

        do {
            let result = try snapshot(report)

            try modelContext.save()

            return result

        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func markWaiting(
        clientId: UUID,
        userId: String
    ) throws {

        try updateState(
            clientId: clientId,
            userId: userId,
            state: .waiting,
            message: nil
        )
    }

    func markRejected(
        clientId: UUID,
        userId: String,
        message: String
    ) throws {

        try updateState(
            clientId: clientId,
            userId: userId,
            state: .rejected,
            message: message
        )
    }

    private func updateState(
        clientId: UUID,
        userId: String,
        state: ReportDeliveryState,
        message: String?
    ) throws {

        guard let report = try find(
            clientId: clientId,
            userId: userId
        ) else {
            return
        }

        report.stateRawValue = state.rawValue
        report.failureMessage = message

        try saveChanges()
    }

    // MARK: - Interrupted sends

    func restoreInterruptedReports(
        userId: String
    ) throws {

        let reports = try records(
            userId: userId
        )

        for report in reports
        where report.state == .sending {

            report.stateRawValue =
                ReportDeliveryState.waiting.rawValue
        }

        try saveChanges()
    }

    // MARK: - Local photo

    func photoData(
        clientId: UUID,
        userId: String
    ) throws -> Data? {

        guard let report = try find(
            clientId: clientId,
            userId: userId
        ) else {
            return nil
        }

        guard let filename = report.photoFilename else {
            return nil
        }

        guard filename == "\(clientId.uuidString).jpg" else {
            throw PendingReportStoreError.invalidPhoto
        }

        let directory = try photoDirectory(
            userId: userId
        )

        let url = directory.appendingPathComponent(
            filename
        )

        let data = try Data(contentsOf: url)

        guard data.count <= ReportPhotoCompressor.maxBytes,
              data.starts(with: [0xFF, 0xD8, 0xFF]) else {
            throw PendingReportStoreError.invalidPhoto
        }

        return data
    }

    // MARK: - Remove sent report

    func remove(
        clientId: UUID,
        userId: String
    ) throws {

        guard let report = try find(
            clientId: clientId,
            userId: userId
        ) else {
            return
        }

        let filename = report.photoFilename

        modelContext.delete(report)

        try saveChanges()

        if filename == "\(clientId.uuidString).jpg",
           let directory = try? photoDirectory(
               userId: userId
           ) {

            let url = directory.appendingPathComponent(
                "\(clientId.uuidString).jpg"
            )

            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Logout cleanup

    func clear(
        userId: String
    ) throws {

        let reports = try records(
            userId: userId
        )

        for report in reports {
            modelContext.delete(report)
        }

        try saveChanges()

        let directory = try photoDirectory(
            userId: userId
        )

        if FileManager.default.fileExists(
            atPath: directory.path
        ) {
            try FileManager.default.removeItem(
                at: directory
            )
        }
    }

    // MARK: - Photo directory

    private func photoDirectory(
        userId: String
    ) throws -> URL {

        let manager = FileManager.default

        let applicationSupport = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let userFolder = SHA256.hash(
            data: Data(userId.utf8)
        )
        .map {
            String(format: "%02x", $0)
        }
        .joined()

        let directory = applicationSupport
            .appendingPathComponent(
                "PendingReports",
                isDirectory: true
            )
            .appendingPathComponent(
                userFolder,
                isDirectory: true
            )

        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directory
    }

    // MARK: - Persistence

    private func saveChanges() throws {

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Mapping

    private func snapshot(
        _ report: PendingReport
    ) throws -> QueuedReport {

        guard let kind = report.kind,
              let status = report.shownStatus,
              let state = report.state else {
            throw PendingReportStoreError.invalidRecord
        }

        return QueuedReport(
            clientId: report.clientId,
            userId: report.userId,
            spotId: report.spotId,
            spotCode: report.spotCode,
            levelCode: report.levelCode,
            kind: kind,
            shownStatus: status,
            note: report.note,
            reportedAt: report.reportedAt,
            photoFilename: report.photoFilename,
            state: state,
            attempts: report.attempts,
            failureMessage: report.failureMessage
        )
    }
}