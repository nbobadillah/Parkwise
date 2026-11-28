import SwiftUI

@main
@MainActor
struct SmartParkingApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var reportCoordinator: ReportSessionCoordinator

    private let authService: AuthServicing
    private let parkingService: ParkingServicing
    private let reservationService: ReservationServicing
    private let locationService: LocationService
    private let parkedCarStore: ParkedCarStore
    private let networkMonitor: NetworkMonitor
    private let actionQueue: ActionQueueing

    init() {
        let authService = BackendAuthService()
        let locationService = LocationService.shared
        let parkedCarStore = ParkedCarStore.shared
        let networkMonitor = NetworkMonitor.shared

        let parkingService = BackendParkingService(
            token: { authService.token }
        )

        let reservationService = BackendReservationService(
            token: { authService.token }
        )

        let actionQueue = ActionQueue(
            store: ActionQueueStore(),
            service: reservationService,
            networkMonitor: networkMonitor
        )

        TelemetryService.shared.token = { authService.token }
        CrashMonitor.shared.start()

        self.authService = authService
        self.parkingService = parkingService
        self.reservationService = reservationService
        self.locationService = locationService
        self.parkedCarStore = parkedCarStore
        self.networkMonitor = networkMonitor
        self.actionQueue = actionQueue

        _authViewModel = StateObject(
            wrappedValue: AuthViewModel(
                service: authService,
                networkMonitor: networkMonitor
            )
        )

        _reportCoordinator = StateObject(
            wrappedValue: ReportSessionCoordinator(
                networkMonitor: networkMonitor
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isRestoring {
                    ProgressView()
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                        .background(Palette.screen)
                } else {
                    RootView(
                        parkingService: parkingService,
                        reservationService: reservationService,
                        locationService: locationService,
                        parkedCarStore: parkedCarStore,
                        networkMonitor: networkMonitor,
                        actionQueue: actionQueue
                    )
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(reportCoordinator)
            .task {
                await authViewModel.restoreSession()
                TelemetryService.shared.trackAppOpened()
            }
            .onChange(
                of: authViewModel.user?.id,
                initial: true
            ) { _, userId in

                reportCoordinator.setSession(
                    userId: userId,
                    token: authService.token
                )
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    CrashMonitor.shared.sessionDidBecomeActive()
                    reportCoordinator.retrySession()

                case .background:
                    CrashMonitor.shared.sessionDidEnd()

                default:
                    break
                }
            }
        }
    }
}