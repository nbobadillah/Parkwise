import Foundation
import SwiftData

@Model
final class PendingReport {

    @Attribute(.unique)
    var clientId: UUID

    var userId: String

    var spotId: String
    var spotCode: String
    var levelCode: String

    var kindRawValue: String
    var shownStatusRawValue: String

    var note: String?
    var reportedAt: Date

    var photoFilename: String?

    var stateRawValue: String
    var attempts: Int
    var failureMessage: String?

    var kind: ReportKind? {
        ReportKind(rawValue: kindRawValue)
    }

    var shownStatus: SpotStatus? {
        SpotStatus(rawValue: shownStatusRawValue)
    }

    var state: ReportDeliveryState? {
        ReportDeliveryState(rawValue: stateRawValue)
    }

    var displayCode: String {
        "\(levelCode)-\(spotCode)"
    }

    init(
        clientId: UUID = UUID(),
        userId: String,
        spot: ReportSpot,
        kind: ReportKind,
        note: String?,
        reportedAt: Date = Date(),
        photoFilename: String? = nil
    ) {
        self.clientId = clientId
        self.userId = userId

        spotId = spot.id
        spotCode = spot.code
        levelCode = spot.levelCode

        kindRawValue = kind.rawValue
        shownStatusRawValue = spot.status.rawValue

        self.note = note
        self.reportedAt = reportedAt
        self.photoFilename = photoFilename

        stateRawValue = ReportDeliveryState.waiting.rawValue
        attempts = 0
        failureMessage = nil
    }
}