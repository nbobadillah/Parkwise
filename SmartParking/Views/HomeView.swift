import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject var viewModel: HomeViewModel

    let onOpenLevel: (LevelSummary) -> Void
    let onFindSpot: () -> Void
    let onFindCar: () -> Void

    @State private var showSpecialSpots = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                destinationPicker

                ForecastCard(
                    points: viewModel.forecastPoints,
                    levelCode: viewModel.forecastLevelCode,
                    isLoading: viewModel.isLoadingForecast
                )

                recommendation
                levelList
                actions
                specialSpotsAction
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 26)
        }
        .background(Palette.screen)
        .sheet(isPresented: $showSpecialSpots) {
            AccessibleEVSpotsView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadBuildings()

            if NetworkMonitor.shared.isConnected {
                await viewModel.prefetchLevels()
            }
        }
        .task(id: viewModel.arrivalAt) {
            await viewModel.loadArrivalData()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)

                Text(authViewModel.user?.displayName ?? "Guest")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }

            Spacer()

            Text(authViewModel.user?.initials ?? "G")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Palette.accent))
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Destination")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.buildings) { building in
                        ChoiceChip(
                            title: building.name,
                            isSelected: viewModel.selectedBuildingID == building.id
                        ) {
                            viewModel.selectBuilding(id: building.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var recommendation: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Recommended level")

            RecommendationCard(
                recommendation: viewModel.recommendation,
                savedAt: viewModel.recommendationFromCache
                    ? viewModel.recommendationFetchedAt
                    : nil,
                arrivalAt: $viewModel.arrivalAt
            )
        }
    }

    private var levelList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Parking levels")

            ForEach(viewModel.levels) { level in
                LevelCard(level: level) {
                    onOpenLevel(level)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            QuickAction(
                title: "Find a spot",
                icon: "magnifyingglass",
                tint: Tint(
                    soft: Palette.accentSoft,
                    strong: Palette.accent
                ),
                action: onFindSpot
            )

            QuickAction(
                title: "Find my car",
                icon: "car.fill",
                tint: Tint(
                    soft: Palette.violetSoft,
                    strong: Palette.violetInk
                ),
                action: onFindCar
            )
        }
    }

    private var specialSpotsAction: some View {
        Button {
            showSpecialSpots = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.roll")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 44, height: 44)
                    .background(Palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessible and EV spots")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)

                    Text("Check availability by parking level")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
