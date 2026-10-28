import Foundation
import UserNotifications

enum CampusAlertState: Equatable {
    case off
    case watching
    case denied
}

@MainActor
final class CampusAlertService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = CampusAlertService()
    static let pollInterval: Duration = .seconds(30)

    @Published private(set) var state: CampusAlertState

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let watchingKey = "notifyWhenCampusOpens"

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        state = defaults.bool(forKey: watchingKey) ? .watching : .off
        super.init()
        center.delegate = self
    }

    func enable() async {
        let settings = await center.notificationSettings()
        let granted: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .denied:
            granted = false
        default:
            granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        setWatching(granted)
        if !granted {
            state = .denied
        }
    }

    func cancel() {
        setWatching(false)
    }

    func campusDidChange(full: Bool) {
        guard state == .watching, !full else { return }
        let content = UNMutableNotificationContent()
        content.title = "A campus spot opened up"
        content.body = "Open Parkwise to see the free spots and reserve one."
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "campus-open", content: content, trigger: nil))
        setWatching(false)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func setWatching(_ watching: Bool) {
        defaults.set(watching, forKey: watchingKey)
        state = watching ? .watching : .off
    }
}
