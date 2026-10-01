import Foundation

enum SpotKind {
    case standard
    case vip
    case electric
    case accessible

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .vip: return "VIP"
        case .electric: return "Electric \u{26A1}\u{FE0F}"
        case .accessible: return "Accessible \u{267F}\u{FE0F}"
        }
    }
}

struct SpotListing: Identifiable {
    let id: String
    let levelCode: String
    let area: String
    let walkMinutes: Int
    let kind: SpotKind

    var levelTitle: String { "\(levelCode) · \(area)" }
}

enum FindSpotData {
    static let filters = ["Available", "VIP", "Electric", "Accessible"]

    static let spots: [SpotListing] = [
        SpotListing(id: "A103", levelCode: "P1", area: "North", walkMinutes: 1, kind: .standard),
        SpotListing(id: "A205", levelCode: "P1", area: "North", walkMinutes: 2, kind: .standard),
        SpotListing(id: "B201", levelCode: "P1", area: "North", walkMinutes: 2, kind: .standard),
        SpotListing(id: "B108", levelCode: "P1", area: "North", walkMinutes: 3, kind: .electric),
        SpotListing(id: "C012", levelCode: "P2", area: "Central", walkMinutes: 5, kind: .vip),
        SpotListing(id: "D304", levelCode: "P2", area: "Central", walkMinutes: 6, kind: .accessible)
    ]
}