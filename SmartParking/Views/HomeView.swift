import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onOpenLevel: (LevelSummary) -> Void
    let onFindSpot: () -> Void
    let onFindCar: () -> Void

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
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 26)
        }
        .background(Palette.screen)
        .task { await viewModel.loadBuildings() }
        .task(id: viewModel.arrivalAt) {
            await viewModel.loadRecommendation()
            await viewModel.loadForecast()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good morning")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)
                Text(ParkingData.userName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            Text(ParkingData.userInitials)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Palette.accent))
        }
    }

    private var destinationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Destination")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.buildings) { building in
                        ChoiceChip(title: building.name, isSelected: viewModel.selectedBuildingID == building.id) {
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
            RecommendationCard(recommendation: viewModel.recommendation, arrivalAt: $viewModel.arrivalAt)
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
                tint: Tint(soft: Palette.accentSoft, strong: Palette.accent),
                action: onFindSpot
            )
            QuickAction(
                title: "Find my car",
                icon: "car.fill",
                tint: Tint(soft: Palette.violetSoft, strong: Palette.violetInk),
                action: onFindCar
            )
        }
    }
}
