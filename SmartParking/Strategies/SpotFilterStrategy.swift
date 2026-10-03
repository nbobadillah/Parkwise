import Foundation

protocol SpotFilterStrategy {
    var filter: FindSpotFilter { get }
    var requestFilters: SpotFilters { get }
}

struct AvailableSpotFilterStrategy: SpotFilterStrategy {
    let filter: FindSpotFilter = .available
    let requestFilters = SpotFilters(available: true)
}

struct VIPSpotFilterStrategy: SpotFilterStrategy {
    let filter: FindSpotFilter = .vip
    let requestFilters = SpotFilters(available: true, vip: true)
}

struct ElectricSpotFilterStrategy: SpotFilterStrategy {
    let filter: FindSpotFilter = .electric
    let requestFilters = SpotFilters(available: true, ev: true)
}

struct AccessibleSpotFilterStrategy: SpotFilterStrategy {
    let filter: FindSpotFilter = .accessible
    let requestFilters = SpotFilters(available: true, accessible: true)
}

enum SpotFilterStrategyFactory {
    static func strategy(for filter: FindSpotFilter) -> any SpotFilterStrategy {
        switch filter {
        case .available:
            return AvailableSpotFilterStrategy()
        case .vip:
            return VIPSpotFilterStrategy()
        case .electric:
            return ElectricSpotFilterStrategy()
        case .accessible:
            return AccessibleSpotFilterStrategy()
        }
    }
}