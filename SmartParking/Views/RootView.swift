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
    @State private var tab: AppTab = .home
    @State private var levelCode = ParkingData.levels[0].code
    @State private var homeRoute: HomeRoute = .dashboard
    @State private var mapRoute: MapRoute = .floor

    var body: some View {
        VStack(spacing: 0) {
            content
            AppTabBar(selection: tabSelection)
        }
        .background(Palette.screen)
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
            switch homeRoute {
            case .dashboard:
                HomeView(
                    levels: ParkingData.levels,
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
                    onReserve: { spot in
                        levelCode = spot.levelCode
                        mapRoute = .floor
                        tab = .map
                    }
                )
            }
        case .map:
            switch mapRoute {
            case .floor:
                ParkingMapView(levelCode: $levelCode)
            case .findCar:
                FindCarView()
            }
        case .reserve:
            PlaceholderView(
                title: "Reservations",
                message: "Your upcoming and past parking reservations appear here.",
                icon: "calendar"
            )
        case .profile:
            PlaceholderView(
                title: "Profile",
                message: "Vehicles, payment methods and notification settings.",
                icon: "person"
            )
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