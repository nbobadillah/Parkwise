import SwiftUI

@MainActor
struct ReportSpotPickerView: View {

    @Environment(\.dismiss) private var dismiss

    private let levels: [LevelSummary]
    private let service: ParkingServicing
    private let onSelect: (ReportSpot) -> Void

    @State private var availableLevels: [LevelSummary] = []
    @State private var spotsByLevel: [String: [ReportSpot]] = [:]

    @State private var searchText = ""
    @State private var isLoading = false
    @State private var fromCache = false
    @State private var failedLevels: [String] = []
    @State private var errorMessage: String?

    // MARK: - Initialization

    init(
        levels: [LevelSummary],
        service: ParkingServicing,
        onSelect: @escaping (ReportSpot) -> Void
    ) {

        self.levels = levels
        self.service = service
        self.onSelect = onSelect
    }

    // MARK: - Main view

    var body: some View {

        NavigationStack {

            ScrollView {

                LazyVStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    if fromCache {
                        cacheBanner
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    if !failedLevels.isEmpty {

                        errorBanner(
                            "Could not load spots for \(failedLevels.joined(separator: ", "))."
                        )
                    }

                    if isLoading && spotsByLevel.isEmpty {

                        ProgressView("Loading parking spots…")
                            .tint(Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(32)

                    } else if !hasVisibleSpots {

                        emptyState

                    } else {

                        ForEach(availableLevels) { level in

                            let spots = filteredSpots(
                                levelCode: level.code
                            )

                            if !spots.isEmpty {

                                levelSection(
                                    level: level,
                                    spots: spots
                                )
                            }
                        }
                    }

                    if isLoading && !spotsByLevel.isEmpty {

                        ProgressView()
                            .tint(Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                    }
                }
                .padding(16)
            }
            .background(Palette.screen)
            .navigationTitle("Choose the spot")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                prompt: "Search parking spots"
            )
            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSpots()
            }
            .refreshable {
                await loadSpots()
            }
        }
    }

    // MARK: - Level section

    private func levelSection(
        level: LevelSummary,
        spots: [ReportSpot]
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            SectionLabel(
                text: "Level \(level.code) · \(level.area)"
            )

            VStack(spacing: 0) {

                ForEach(spots) { spot in

                    Button {

                        onSelect(spot)

                    } label: {

                        spotRow(spot)
                    }
                    .buttonStyle(.plain)

                    if spot.id != spots.last?.id {

                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Spot row

    private func spotRow(
        _ spot: ReportSpot
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: "parkingsign.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(
                    statusColor(spot.status)
                )

            VStack(alignment: .leading, spacing: 4) {

                Text(spot.displayCode)
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)

                Text(
                    "Shown as \(spot.statusDescription)"
                )
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    // MARK: - Loading

    private func loadSpots() async {

        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        failedLevels.removeAll()
        fromCache = false

        defer {
            isLoading = false
        }

        // Reuse levels already loaded by ParkWise.
        if !levels.isEmpty {

            availableLevels = levels

        } else {

            do {

                let response = try await service.levels(
                    zone: nil
                )

                try Task.checkCancellation()

                availableLevels = response.value.levels

                fromCache = response.fromCache

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                errorMessage =
                    error.localizedDescription

                return
            }
        }

        // Load all statuses without applying
        // reservation or accessibility filters.
        for level in availableLevels {

            guard !Task.isCancelled else {
                return
            }

            do {

                let response = try await service.spots(
                    level: level.code,
                    destination: nil,
                    filters: SpotFilters()
                )

                try Task.checkCancellation()

                let spots = response.value.map {
                    ReportSpot(spot: $0)
                }

                spotsByLevel[level.code] = spots.sorted {

                    $0.code.localizedStandardCompare(
                        $1.code
                    ) == .orderedAscending
                }

                if response.fromCache {
                    fromCache = true
                }

            } catch {

                guard !Task.isCancelled else {
                    return
                }

                failedLevels.append(level.code)
            }
        }
    }

    // MARK: - Search

    private func filteredSpots(
        levelCode: String
    ) -> [ReportSpot] {

        let spots = spotsByLevel[levelCode] ?? []

        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return spots
        }

        return spots.filter {

            $0.displayCode.localizedCaseInsensitiveContains(
                query
            ) ||

            $0.code.localizedCaseInsensitiveContains(
                query
            ) ||

            $0.levelCode.localizedCaseInsensitiveContains(
                query
            ) ||

            $0.statusDescription.localizedCaseInsensitiveContains(
                query
            )
        }
    }

    private var hasVisibleSpots: Bool {

        availableLevels.contains {

            !filteredSpots(
                levelCode: $0.code
            ).isEmpty
        }
    }

    // MARK: - Status colors

    private func statusColor(
        _ status: SpotStatus
    ) -> Color {

        switch status {

        case .free:
            return Palette.greenInk

        case .reserved:
            return Palette.amberInk

        case .occupied:
            return Palette.redInk

        case .disabled:
            return Palette.muted
        }
    }

    // MARK: - Cached data banner

    private var cacheBanner: some View {

        HStack(alignment: .top, spacing: 10) {

            Image(systemName: "wifi.slash")

            VStack(alignment: .leading, spacing: 4) {

                Text("Saved on this phone")
                    .font(AppFont.heading2)

                Text(
                    "Some parking information may be outdated."
                )
                .font(AppFont.caption)
            }

            Spacer()
        }
        .foregroundStyle(Palette.accent)
        .padding(12)
        .background(Palette.accentSoft)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Radius.card
            )
        )
    }

    // MARK: - Error banner

    private func errorBanner(
        _ message: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Label(
                message,
                systemImage: "exclamationmark.circle"
            )
            .font(AppFont.body)
            .foregroundStyle(Palette.redInk)

            Button("Try again") {

                Task {
                    await loadSpots()
                }
            }
            .font(AppFont.button)
            .foregroundStyle(Palette.accent)
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.redSoft)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Radius.card
            )
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {

        VStack(spacing: 12) {

            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Palette.muted)

            Text(
                searchText.isEmpty
                    ? "No parking spots available"
                    : "No matching spots"
            )
            .font(AppFont.heading1)
            .foregroundStyle(Palette.ink)

            Text(
                searchText.isEmpty
                    ? "Try again when you have a connection."
                    : "Try searching with another spot code."
            )
            .font(AppFont.body)
            .foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}