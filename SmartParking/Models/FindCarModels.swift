import Foundation

enum FloorCellKind {
    case taken
    case open
    case route
    case target
}

enum RouteMode: String, CaseIterable, Identifiable {
    case direct
    case lit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .direct: return "Direct route"
        case .lit: return "Lit route"
        }
    }
}

struct RouteStep: Identifiable {
    let icon: String
    let text: String
    var isFinal = false

    var id: String { text }
}

enum FindCarData {
    static let parkedAt = "Parked today at 8:14 AM"
    static let spotCode = "B201"
    static let levelTitle = "P1 · North"
    static let walkTime = "~2 min"
    static let entrance = "via Entrance A"
    static let distance = "~120m"

    static let steps: [RouteStep] = [
        RouteStep(icon: "arrow.up.right", text: "Head north toward Zone B"),
        RouteStep(icon: "arrow.up", text: "Pass Zone A (30m)"),
        RouteStep(icon: "mappin.and.ellipse", text: "Arrive at B201 · on your right", isFinal: true)
    ]

    // 8 filas x 6 columnas, igual que la imagen
    static let floor: [[FloorCellKind]] = [
        [.taken, .taken, .taken, .taken, .taken, .taken],
        [.taken, .taken, .taken, .taken, .taken, .taken],
        [.taken, .open,  .taken, .taken, .taken, .taken],
        [.taken, .target, .taken, .taken, .taken, .taken],
        [.taken, .route, .open,  .open,  .open,  .open],
        [.taken, .route, .open,  .open,  .open,  .open],
        [.route, .route, .open,  .open,  .open,  .open],
        [.taken, .taken, .open,  .open,  .open,  .open]
    ]
}