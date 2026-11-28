import Foundation

enum VoiceLanguage: String, CaseIterable, Identifiable, Sendable {
    case spanish = "es-CO"
    case english = "en-US"

    var id: String {
        rawValue
    }

    var localeID: String {
        rawValue
    }

    var shortName: String {
        String(rawValue.prefix(2)).uppercased()
    }

    var examples: [String] {
        switch self {
        case .spanish:
            return ["Puesto libre en el P1", "Eléctrico en el P2", "Accesible en la zona B"]
        case .english:
            return ["Free spot in P1", "Electric spot in P2", "Accessible spot in zone B"]
        }
    }
}

enum VoiceFilter: String, CaseIterable, Hashable, Sendable {
    case available
    case electric
    case accessible
    case vip

    var label: String? {
        switch self {
        case .available:
            return nil
        case .electric:
            return "Electric"
        case .accessible:
            return "Accessible"
        case .vip:
            return "VIP"
        }
    }
}

struct VoiceQuery: Equatable, Sendable {
    var levelCode: String?
    var zone: String?
    var spotNumber: Int?
    var filters: Set<VoiceFilter> = [.available]

    static let empty = VoiceQuery()

    var spotCode: String? {
        guard let zone, let spotNumber else { return nil }
        return "\(zone)-\(String(format: "%02d", spotNumber))"
    }

    var understood: Bool {
        levelCode != nil || zone != nil || filters.contains { $0 != .available }
    }

    var searchText: String {
        [levelCode, zone, spotCode].compactMap { $0 }.joined(separator: " ")
    }

    var findSpotFilter: FindSpotFilter {
        if filters.contains(.electric) { return .electric }
        if filters.contains(.accessible) { return .accessible }
        if filters.contains(.vip) { return .vip }
        return .available
    }

    var chips: [String] {
        var labels: [String] = []
        if let levelCode {
            labels.append("Level \(levelCode)")
        }
        if let spotCode {
            labels.append("Spot \(spotCode)")
        } else if let zone {
            labels.append("Zone \(zone)")
        }
        labels += [VoiceFilter.electric, .accessible, .vip]
            .filter(filters.contains)
            .compactMap(\.label)
        return labels
    }
}
