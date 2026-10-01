import SwiftUI

@main
struct SmartParkingApp: App {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        _authViewModel = StateObject(wrappedValue: AuthViewModel(service: BackendAuthService()))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.screen)
                } else if authViewModel.isAuthenticated {
                    RootView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authViewModel)
            .task { await authViewModel.restoreSession() }
            .animation(.easeInOut, value: authViewModel.isAuthenticated)
        }
    }
}
