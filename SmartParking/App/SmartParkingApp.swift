import SwiftUI

@main
struct SmartParkingApp: App {
    @StateObject private var authViewModel: AuthViewModel
    private let parkingService: ParkingServicing
    private let reservationService: ReservationServicing
    private let locationService: LocationService
    private let parkedCarStore: ParkedCarStore

    init() {
        let authService = BackendAuthService()
        let locationService = LocationService.shared
        let parkedCarStore = ParkedCarStore.shared
        TelemetryService.shared.token = { authService.token }
        parkingService = BackendParkingService(token: { authService.token })
        reservationService = BackendReservationService(token: { authService.token })
        self.locationService = locationService
        self.parkedCarStore = parkedCarStore
        _authViewModel = StateObject(wrappedValue: AuthViewModel(service: authService))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.screen)
                } else if authViewModel.isAuthenticated {
                    RootView(
                        parkingService: parkingService,
                        reservationService: reservationService,
                        locationService: locationService,
                        parkedCarStore: parkedCarStore
                    )
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .task { await authViewModel.restoreSession() }
            .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    TelemetryService.shared.trackAppOpened()
                }
            }
            .animation(.easeInOut, value: authViewModel.isAuthenticated)
        }
    }
}
