import Foundation
import SwiftData

enum PendingActionKind: String, Codable, Sendable {
    case checkIn
    case release
}

@Model
final class PendingAction {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var reservationId: String
    var createdAt: Date
    var attempts: Int

    // Usuario propietario de la acción.
    var userId: String?

    // Información persistente de fallos.
    var failureMessage: String?
    var failedAt: Date?

    var kind: PendingActionKind? {
        PendingActionKind(rawValue: kindRawValue)
    }

    var isFailed: Bool {
        failureMessage != nil
    }

    init(
        kind: PendingActionKind,
        reservationId: String,
        createdAt: Date = Date(),
        userId: String? = nil
    ) {
        id = UUID()
        kindRawValue = kind.rawValue
        self.reservationId = reservationId
        self.createdAt = createdAt
        self.userId = userId
        attempts = 0
        failureMessage = nil
        failedAt = nil
    }
}