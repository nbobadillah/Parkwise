import SwiftUI

struct FindSpotView: View {
    let levels: [LevelSummary]
    let destinationID: String?
    let onReserve: (SpotListing) -> Void

    @ObservedObject private var networkMonitor: NetworkMonitor
    @StateObject private var viewModel: FindSpotViewModel
    @State private var query = ""

    init(
        levels: [LevelSummary],
        destinationID: String?,
        service: ParkingServicing,
        networkMonitor: NetworkMonitor,
        onReserve: @escaping (SpotListing) -> Void
    ) {
        self.levels = levels
        self.destinationID = destinationID
        self.onReserve = onReserve
        _networkMonitor = ObservedObject(wrappedValue: networkMonitor)
        _viewModel = StateObject(wrappedValue: FindSpotViewModel(service: service))
    }

    private var filteredSpots: [SpotListing] {
        let spots = viewModel.spots(matching: query)

        guard query.isEmpty, let recommendedSpot = viewModel.recommendedSpot else {
            return spots
        }

        return spots.filter { $0.id != recommendedSpot.id }
    }

    private var recommendedSpot: SpotListing? {
        query.isEmpty ? viewModel.recommendedSpot : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(viewModel.spots(matching: query).count) spots found")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.subtle)

                    if let recommendedSpot {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended spot")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.ink)

                            SpotResultRow(spot: recommendedSpot) {
                                onReserve(recommendedSpot)
                            }
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.spots(matching: query).isEmpty {
                        emptyState
                    } else if !filteredSpots.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(filteredSpots) { spot in
                                SpotResultRow(spot: spot) {
                                    onReserve(spot)
                                }
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        AuthBanner(message: errorMessage, isError: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.screen)
        .task(
            id: levels.map(\.code).joined(separator: ",")
                + (destinationID ?? "")
                + viewModel.filter.rawValue
                + String(networkMonitor.isConnected)
        ) {
            await viewModel.load(
                levels: levels,
                destinationID: destinationID
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find a spot")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    searchField
                    micButton
                }

                HStack(spacing: 8) {
                    ForEach(FindSpotFilter.allCases) { item in
                        FilterChip(
                            title: item.rawValue,
                            isSelected: viewModel.filter == item
                        ) {
                            viewModel.filter = item
                            TelemetryService.shared.trackFilterApplied(filter: item)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)

            TextField(
                "Search",
                text: $query,
                prompt: Text("Spot code, zone, level…")
                    .foregroundColor(Palette.muted)
            )
            .font(.system(size: 14))
            .foregroundStyle(Palette.ink)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.neutral)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.border, lineWidth: 1.5)
        )
    }

    private var micButton: some View {
        Button {} label: {
            Image(systemName: "mic")
                .font(.system(size: 17))
                .foregroundStyle(Palette.accent)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.accent.opacity(0.55), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "parkingsign.circle")
                .font(.system(size: 30))
                .foregroundStyle(Palette.muted)

            Text("No spots found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)

            Text(
                query.isEmpty
                    ? "There are no spots matching this filter"
                    : "Try another search"
            )
            .font(.system(size: 13))
            .foregroundStyle(Palette.subtle)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}