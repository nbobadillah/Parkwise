import SwiftUI

struct FindSpotView: View {
    let levels: [LevelSummary]
    let destinationID: String?
    let initialFilter: FindSpotFilter
    let onReserve: (SpotListing) -> Void

    @ObservedObject private var networkMonitor: NetworkMonitor
    @StateObject private var viewModel: FindSpotViewModel
    @State private var query = ""

    init(
        levels: [LevelSummary],
        destinationID: String?,
        service: ParkingServicing,
        networkMonitor: NetworkMonitor,
        initialFilter: FindSpotFilter = .available,
        onReserve: @escaping (SpotListing) -> Void
    ) {
        self.levels = levels
        self.destinationID = destinationID
        self.initialFilter = initialFilter
        self.onReserve = onReserve
        _networkMonitor = ObservedObject(wrappedValue: networkMonitor)
        _viewModel = StateObject(wrappedValue: FindSpotViewModel(service: service, filter: initialFilter))
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
                VStack(alignment: .leading, spacing: 16) {
                    if !networkMonitor.isConnected {
                        NoticeBox(
                            message: "Filters and search work with the last saved copy. You can pick a spot now; the reservation is confirmed when the phone is back online.",
                            title: "No signal",
                            icon: "wifi.slash"
                        )
                    }

                    if let recommendedSpot, !viewModel.isLoading {
                        SpotResultRow(spot: recommendedSpot, isRecommended: true) {
                            onReserve(recommendedSpot)
                        }
                    }

                    Text("\(viewModel.spots(matching: query).count) spots found")
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.spots(matching: query).isEmpty {
                        emptyState
                    } else if !filteredSpots.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(filteredSpots) { spot in
                                SpotResultRow(spot: spot) {
                                    onReserve(spot)
                                }
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        NoticeBox(message: errorMessage, tone: .danger, icon: "exclamationmark.circle")
                    }
                }
                .padding(16)
                .padding(.top, 8)
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
            Text(title)
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)

            VStack(alignment: .leading, spacing: 16) {
                searchField

                HStack(spacing: 8) {
                    ForEach(FindSpotFilter.allCases) { item in
                        ChoiceChip(
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
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var title: String {
        switch initialFilter {
        case .accessible: return "Accessible spots"
        case .electric: return "EV spots"
        default: return "Find a spot"
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)

            TextField(
                "Search",
                text: $query,
                prompt: Text("Spot code, zone, level…")
                    .foregroundColor(Palette.muted)
            )
            .font(AppFont.body)
            .foregroundStyle(Palette.ink)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.neutral)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
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