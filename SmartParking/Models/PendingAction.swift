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

    var kind: PendingActionKind? {
        PendingActionKind(rawValue: kindRawValue)
    }

    init(kind: PendingActionKind, reservationId: String, createdAt: Date = Date()) {
        id = UUID()
        kindRawValue = kind.rawValue
        self.reservationId = reservationId
        self.createdAt = createdAt
        attempts = 0
    }
}
