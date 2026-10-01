import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    static let walkingSpeed: CLLocationSpeed = 1.3

    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.activityType = .otherNavigation
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func start() {
        errorMessage = nil
        if isAuthorized {
            manager.startUpdatingLocation()
        } else if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            errorMessage = "Location access is off. Enable it in Settings to locate your car."
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation else { return nil }
        return currentLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func walkingMinutes(to coordinate: CLLocationCoordinate2D) -> Int? {
        distance(to: coordinate).map(Self.walkingMinutes(for:))
    }

    static func walkingMinutes(for distance: CLLocationDistance) -> Int {
        max(1, Int((distance / walkingSpeed / 60).rounded(.up)))
    }

    static func formatted(_ distance: CLLocationDistance) -> String {
        distance < 1000 ? "~\(Int(distance.rounded()))m" : String(format: "~%.1fkm", distance / 1000)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized {
                self.start()
            } else if self.isDenied {
                self.errorMessage = "Location access is off. Enable it in Settings to locate your car."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            self.currentLocation = latest
            self.errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        Task { @MainActor in
            self.errorMessage = "Could not get your location. Try again outside or near the entrance."
        }
    }
}
