import SwiftUI

enum HomeRoute {
    case dashboard
    case findSpot
}

enum MapRoute {
    case floor
    case findCar
}

struct RootView: View {
    let parkingService: ParkingServicing
    let reservationService: ReservationServicing

    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var reservationViewModel: ReservationViewModel
    @State private var tab: AppTab = .home
    @State private var levelCode = "P1"
    @State private var homeRoute: HomeRoute = .dashboard
    @State private var mapRoute: MapRoute = .floor
    @State private var selectedSpot: SpotListing?

    init(parkingService: ParkingServicing, reservationService: ReservationServicing) {
        self.parkingService = parkingService
        self.reservationService = reservationService
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(service: parkingService))
        _reservationViewModel = StateObject(wrappedValue: ReservationViewModel(service: reservationService))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            AppTabBar(selection: tabSelection)
        }
        .background(Palette.screen)
        .task(id: tab) { await homeViewModel.loadLevels() }
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

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            if homeViewModel.campusFull {
                CampusFullView()
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
                    FindSpotView(levels: homeViewModel.levels, service: parkingService) { spot in
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
                    service: parkingService,
                    onReserve: { spot in
                        selectedSpot = SpotListing(spot: spot)
                        tab = .reserve
                    }
                )
            case .findCar:
                FindCarView()
            }
        case .reserve:
            ReserveSpotView(selectedSpot: selectedSpot, viewModel: reservationViewModel)
        case .profile:
            ProfileView()
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