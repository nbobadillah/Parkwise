import SwiftUI
import UIKit

enum HomeRoute {
    case dashboard
    case findSpot
}

enum MapRoute {
    case floor
    case findCar
}

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var locationService: LocationService
    @ObservedObject private var networkMonitor: NetworkMonitor
    let parkingService: ParkingServicing
    let reservationService: ReservationServicing

    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var reservationViewModel: ReservationViewModel
    @State private var tab: AppTab = .home
    @State private var levelCode = "P1"
    @State private var homeRoute: HomeRoute = .dashboard
    @State private var mapRoute: MapRoute = .floor
    @State private var selectedSpot: SpotListing?
    @State private var showSignIn = false

    init(
        parkingService: ParkingServicing,
        reservationService: ReservationServicing,
        locationService: LocationService,
        parkedCarStore: ParkedCarStore,
        networkMonitor: NetworkMonitor
    ) {
        self.parkingService = parkingService
        self.reservationService = reservationService
        _locationService = ObservedObject(wrappedValue: locationService)
        _networkMonitor = ObservedObject(wrappedValue: networkMonitor)
        _homeViewModel = StateObject(
            wrappedValue: HomeViewModel(service: parkingService, locationService: locationService)
        )
        _reservationViewModel = StateObject(
            wrappedValue: ReservationViewModel(
                service: reservationService,
                locationService: locationService,
                parkedCarStore: parkedCarStore
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                AuthBanner(
                    message: "No internet connection. Cached data will be used when available.",
                    isError: true
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            content
            AppTabBar(selection: tabSelection)
        }
        .background(Palette.screen)
        .task(id: tab) {
            if tab == .home {
                homeViewModel.prepareLocationPermission()
            }
            await homeViewModel.loadLevels(isAuthenticated: authViewModel.isAuthenticated)
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard isConnected else { return }

            Task {
                await homeViewModel.loadLevels(
                    isAuthenticated: authViewModel.isAuthenticated
                )
            }
        }
        .onChange(of: locationService.authorization) { _, _ in
            if tab == .home {
                homeViewModel.locationAuthorizationDidChange()
                Task {
                    await homeViewModel.loadLevels(
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                }
            }
        }
        .onChange(of: locationService.currentLocation?.timestamp) { _, _ in
            if tab == .home {
                Task {
                    await homeViewModel.refreshLevelsForLocationChange(
                        isAuthenticated: authViewModel.isAuthenticated
                    )
                }
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            Task {
                await homeViewModel.loadLevels(isAuthenticated: isAuthenticated)
            }
        }
        .task(id: authViewModel.isAuthenticated) {
            guard authViewModel.isAuthenticated else {
                reservationViewModel.reset()
                return
            }
            showSignIn = false
            await reservationViewModel.loadActive()
            await reservationViewModel.loadHistory()
        }
        .sheet(isPresented: $showSignIn) {
            LoginView()
                .environmentObject(authViewModel)
        }
        .alert(item: $homeViewModel.locationPermissionPrompt) { prompt in
            switch prompt {
            case .explanation:
                Alert(
                    title: Text("Use your location?"),
                    message: Text("Location is optional. Parkwise uses it to record approximate demand when campus is full and to save your car's position aftercheck-in."),
                    primaryButton: .default(
                        Text("Continue"),
                        action: homeViewModel.requestLocationPermission
                    ),
                    secondaryButton: .cancel(
                        Text("Not now"),
                        action: homeViewModel.dismissLocationPermissionPrompt
                    )
                )
            case .settings:
                Alert(
                    title: Text("Location access is off"),
                    message: Text("You can enable location in Settings. Parking and reservations remain available without it."),
                    primaryButton: .default(
                        Text("Open Settings"),
                        action: openSettings
                    ),
                    secondaryButton: .cancel(
                        Text("Not now"),
                        action: homeViewModel.dismissLocationPermissionPrompt
                    )
                )
            }
        }
    }

    // Al tocar cualquier pestaña se vuelve a la pantalla principal de cada sección
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { newTab in
                homeRoute = .dashboard
                mapRoute = .floor
                tab = newTab
            }
        )
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            if homeViewModel.campusFull {
                CampusFullView(viewModel: homeViewModel)
            } else {
                switch homeRoute {
                case .dashboard:
                    HomeView(
                        viewModel: homeViewModel,
                        onOpenLevel: { level in
                            levelCode = level.code
                            mapRoute = .floor
                            tab = .map
                        },
                        onFindSpot: { homeRoute = .findSpot },
                        onFindCar: {
                            mapRoute = .findCar
                            tab = .map
                        }
                    )
                case .findSpot:
                    FindSpotView(
                        levels: homeViewModel.levels,
                        destinationID: homeViewModel.destinationID,
                        service: parkingService,
                        networkMonitor: networkMonitor
                    ) { spot in
                        selectedSpot = spot
                        tab = .reserve
                    }
                }
            }
        case .map:
            switch mapRoute {
            case .floor:
                ParkingMapView(
                    levelCode: $levelCode,
                    levels: homeViewModel.levels,
                    destinationID: homeViewModel.destinationID,
                    service: parkingService,
                    onReserve: { spot in
                        selectedSpot = SpotListing(spot: spot)
                        tab = .reserve
                    }
                )
            case .findCar:
                if authViewModel.isAuthenticated {
                    FindCarView(
                        viewModel: reservationViewModel,
                        parkingService: parkingService,
                        locationService: locationService,
                        destinationID: homeViewModel.destinationID,
                        networkMonitor: networkMonitor
                    )
                } else {
                    SignInPromptView(
                        title: "Find your car",
                        message: "Sign in to see where you parked after checking in.",
                        icon: "car.fill"
                    ) { showSignIn = true }
                }
            }
        case .reserve:
            if authViewModel.isAuthenticated {
                ReserveSpotView(
                    selectedSpot: selectedSpot,
                    viewModel: reservationViewModel
                )
            } else {
                SignInPromptView(
                    title: selectedSpot.map { "Reserve \($0.code)" } ?? "Reserve a spot",
                    message: "Create an account or sign in to hold a spot for 15 minutes.",
                    icon: "calendar.badge.plus"
                ) { showSignIn = true }
            }
        case .profile:
            if authViewModel.isAuthenticated {
                ProfileView(
                    reservationViewModel: reservationViewModel
                )
            } else {
                SignInPromptView(
                    title: "Your profile",
                    message: "Create an account or sign in to see your reservations.",
                    icon: "person.crop.circle"
                ) { showSignIn = true }
            }
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.accent)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Palette.accentSoft))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.screen)
    }
}

struct SignInPromptView: View {
    let title: String
    let message: String
    let icon: String
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.accent)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Palette.accentSoft))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            PrimaryButton(title: "Sign in or create account", isLoading: false, isEnabled: true, action: onSignIn)
                .frame(maxWidth: 320)
                .padding(.top, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.screen)
    }
}
