import Foundation

// MARK: - Report kind

enum ReportKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case occupied
    case blocked
    case damaged
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .occupied:
            return "Occupied without a reservation"
        case .blocked:
            return "Spot blocked"
        case .damaged:
            return "Sign or paint damaged"
        case .other:
            return "Something else"
        }
    }

    var icon: String {
        switch self {
        case .occupied:
            return "car.fill"
        case .blocked:
            return "exclamationmark.octagon"
        case .damaged:
            return "paintbrush"
        case .other:
            return "ellipsis.circle"
        }
    }
}

// MARK: - Selected parking spot

struct ReportSpot: Codable, Identifiable, Equatable {
    let id: String
    let code: String
    let levelCode: String
    let status: SpotStatus

    init(spot: Spot) {
        id = spot.id
        code = spot.code
        levelCode = spot.levelCode
        status = spot.status
    }

    var displayCode: String {
        "\(levelCode)-\(code)"
    }

    var statusDescription: String {
        switch status {
        case .free:
            return "free"
        case .reserved:
            return "reserved"
        case .occupied:
            return "occupied"
        case .disabled:
            return "out of service"
        }
    }

    var description: String {
        "Level \(levelCode) · shown as \(statusDescription) in ParkWise"
    }
}

// MARK: - Server report

struct SpotReport: Codable, Identifiable, Equatable {
    let id: String
    let clientId: String
    let spotId: String
    let spotCode: String
    let levelCode: String
    let kind: ReportKind
    let note: String?
    let shownStatus: SpotStatus
    let reportedAt: Date
    let photoUrl: String?

    var displayCode: String {
        "\(levelCode)-\(spotCode)"
    }

    var hasPhoto: Bool {
        photoUrl != nil
    }
}

// MARK: - Report request

struct ReportRequest: Encodable {
    let clientId: String
    let spotId: String
    let kind: ReportKind
    let shownStatus: SpotStatus
    let note: String?
    let reportedAt: String
    let photo: String?

    let platform = "ios"
}

// MARK: - Local delivery state

enum ReportDeliveryState: String, Codable, Sendable {
    case sent
    case waiting
    case sending
    case rejected

    var title: String {
        switch self {
        case .sent:
            return "SENT"
        case .waiting:
            return "WAITING FOR SIGNAL"
        case .sending:
            return "SENDING"
        case .rejected:
            return "NOT ACCEPTED"
        }
    }
}