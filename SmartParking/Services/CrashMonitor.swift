import Foundation

@MainActor
protocol ReservationFlowTracking: AnyObject {
    func setInReservationFlow(_ inFlow: Bool)
}

@MainActor
final class CrashMonitor: ReservationFlowTracking {
    static let shared = CrashMonitor()

    private let telemetry: TelemetryService
    private var inReservationFlow = false
    private var isSessionOpen = false

    init(telemetry: TelemetryService? = nil) {
        self.telemetry = telemetry ?? .shared
    }

    func start() {
        if let previous = SessionMarkerFile.read() {
            telemetry.trackAppCrash(
                inReservationFlow: previous.inReservationFlow,
                reason: previous.exceptionReason
            )
        }
        NSSetUncaughtExceptionHandler { exception in
            SessionMarkerFile.record(exception)
        }
        sessionDidBecomeActive()
    }

    func sessionDidBecomeActive() {
        isSessionOpen = true
        SessionMarkerFile.write(SessionMarker(inReservationFlow: inReservationFlow))
    }

    func sessionDidEnd() {
        isSessionOpen = false
        SessionMarkerFile.remove()
    }

    func setInReservationFlow(_ inFlow: Bool) {
        inReservationFlow = inFlow
        guard isSessionOpen else { return }
        SessionMarkerFile.write(SessionMarker(inReservationFlow: inFlow))
    }
}

private struct SessionMarker: Codable {
    var inReservationFlow: Bool
    var exceptionReason: String?
}

private enum SessionMarkerFile {
    static let url = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "session-in-progress.json")

    static func read() -> SessionMarker? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionMarker.self, from: data)
    }

    static func write(_ marker: SessionMarker) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(marker).write(to: url, options: .atomic)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    static func record(_ exception: NSException) {
        var marker = read() ?? SessionMarker(inReservationFlow: false)
        marker.exceptionReason = "\(exception.name.rawValue): \(exception.reason ?? "")"
        write(marker)
    }
}
