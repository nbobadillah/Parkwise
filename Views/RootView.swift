import SwiftUI

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var levelCode = ParkingData.levels[0].code

    var body: some View {
        VStack(spacing: 0) {
            content
            AppTabBar(selection: $tab)
        }
        .background(Palette.screen)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            HomeView(
                levels: ParkingData.levels,
                onOpenLevel: { level in
                    levelCode = level.code
                    tab = .map
                },
                onFindSpot: { tab = .map },
                onFindCar: { tab = .map }
            )
        case .map:
            ParkingMapView(levelCode: $levelCode)
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
