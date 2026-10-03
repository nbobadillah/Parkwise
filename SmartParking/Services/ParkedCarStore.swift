import CoreLocation
import Foundation

struct ParkedCar: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let levelCode: String?
    let spotCode: String?
    let parkedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
protocol ParkedCarStoring: AnyObject {
    var parkedCar: ParkedCar? { get }
    func save(location: CLLocation, levelCode: String?, spotCode: String?) -> ParkedCar
    func clear()
}

@MainActor
final class ParkedCarStore: ObservableObject, ParkedCarStoring {
    static let shared = ParkedCarStore()

    @Published private(set) var parkedCar: ParkedCar?

    private let defaults: UserDefaults
    private let key = "parkedCar"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        parkedCar = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ParkedCar.self, from: $0) }
    }

    @discardableResult
    func save(location: CLLocation, levelCode: String? = nil, spotCode: String? = nil) -> ParkedCar {
        let car = ParkedCar(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            levelCode: levelCode,
            spotCode: spotCode,
            parkedAt: Date()
        )
        defaults.set(try? JSONEncoder().encode(car), forKey: key)
        parkedCar = car
        return car
    }

    func clear() {
        defaults.removeObject(forKey: key)
        parkedCar = nil
    }
}
