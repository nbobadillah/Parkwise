import SwiftUI

@main
struct SmartParkingApp: App {
    @StateObject private var authViewModel: AuthViewModel
    private let parkingService: ParkingServicing

    init() {
        let authService = BackendAuthService()
        TelemetryService.shared.token = { authService.token }
        parkingService = BackendParkingService(token: { authService.token })
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
                    RootView(parkingService: parkingService)
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
