
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    let onOpenLevel: (LevelSummary) -> Void
    let onFindSpot: (FindSpotFilter) -> Void
    let onFindCar: () -> Void

    @State private var showSpecialSpots = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if !networkMonitor.isConnected {
                    OfflineNotice(savedAt: viewModel.fetchedAt)
                        .padding(.top, 16)
                }

                SectionLabel(text: "Destination")
                    .padding(.top, 24)

                destinationPicker
                    .padding(.top, 8)

                ForecastCard(
                    hours: viewModel.forecastHours,
                    currentHour: viewModel.arrivalHour,
                    isLive: viewModel.forecast != nil
                        && !viewModel.forecastFromCache,
                    isLoading: viewModel.isLoadingForecast
                )
                .padding(.top, 16)

                SectionLabel(text: "Parking levels")
                    .padding(.top, 24)

                RecommendationCard(
                    recommendation: viewModel.recommendation,
                    savedAt: viewModel.recommendationFromCache
                        ? viewModel.recommendationFetchedAt
                        : nil,
                    arrivalAt: $viewModel.arrivalAt
                )
                .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(viewModel.levels) { level in
                        LevelCard(
                            level: level,
                            isRecommended: level.code
                                == viewModel.recommendation?.recommended
                        ) {
                            onOpenLevel(level)
                        }
                    }
                }
                .padding(.top, 8)

                actions
                    .padding(.top, 16)

                specialSpotsAction
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Palette.screen)
        .sheet(isPresented: $showSpecialSpots) {
            AccessibleEVSpotsView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.loadBuildings()
            await viewModel.loadLevels(
                isAuthenticated: authViewModel.isAuthenticated
            )
            await viewModel.loadArrivalData()
            await viewModel.loadSpecialSpotsAvailability()
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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:
            return "Good morning"
        case 12..<18:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)

                Text(authViewModel.user?.displayName ?? "Guest")
                    .font(AppFont.display)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(authViewModel.user?.initials ?? "G")
                .font(AppFont.heading2)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.accent))
        }
    }

    @ViewBuilder
    private var destinationPicker: some View {
        if viewModel.buildings.isEmpty {
            Text("Destinations unavailable")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.buildings) { building in
                        ChoiceChip(
                            title: building.name,
                            isSelected: viewModel.selectedBuildingID
                                == building.id
                        ) {
                            viewModel.selectBuilding(id: building.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                QuickAction(
                    title: "Find a spot",
                    icon: "magnifyingglass",
                    tint: Tint(
                        soft: Palette.accentSoft,
                        strong: Palette.accent
                    )
                ) {
                    onFindSpot(.available)
                }

                QuickAction(
                    title: "Find my car",
                    icon: "car",
                    tint: Tint(
                        soft: Palette.violetSoft,
                        strong: Palette.violetInk
                    ),
                    action: onFindCar
                )
            }

            HStack(spacing: 8) {
                QuickAction(
                    title: "Accessible",
                    icon: "figure.roll",
                    tint: Tint(
                        soft: Palette.accentSoft,
                        strong: Palette.accent
                    )
                ) {
                    onFindSpot(.accessible)
                }

                QuickAction(
                    title: "EV spots",
                    icon: "bolt.fill",
                    tint: Tint(
                        soft: Palette.amberSoft,
                        strong: Palette.amberText
                    )
                ) {
                    onFindSpot(.electric)
                }
            }
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
                    .clipShape(
                        RoundedRectangle(cornerRadius: 13)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessible and EV availability")
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
