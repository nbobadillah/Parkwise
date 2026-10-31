import SwiftUI

@main
struct SmartParkingApp: App {
    @StateObject private var authViewModel: AuthViewModel

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
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .task {
                await authViewModel.restoreSession()
                TelemetryService.shared.trackAppOpened()
            }
        }
    }
}