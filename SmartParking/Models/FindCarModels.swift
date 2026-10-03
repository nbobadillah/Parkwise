import Foundation

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