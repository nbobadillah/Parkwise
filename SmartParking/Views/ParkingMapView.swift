import SwiftUI

struct ParkingMapView: View {
    @Binding var levelCode: String
    let levels: [LevelSummary]
    let destinationID: String?
    let onReserve: (ParkingSpot) -> Void
    let onReport: ((ReportSpot) -> Void)?

    @ObservedObject private var networkMonitor: NetworkMonitor
    @StateObject private var viewModel: ParkingMapViewModel
    @State private var highlightFilters: [FindSpotFilter] = []

    init(
        levelCode: Binding<String>,
        levels: [LevelSummary],
        destinationID: String?,
        service: ParkingServicing,
        networkMonitor: NetworkMonitor,
        onReport: ((ReportSpot) -> Void)? = nil,
        onReserve: @escaping (ParkingSpot) -> Void
    ) {
        _levelCode = levelCode
        self.levels = levels
        self.destinationID = destinationID
        self.onReserve = onReserve
        self.onReport = onReport

        _networkMonitor = ObservedObject(wrappedValue: networkMonitor)
        _viewModel = StateObject(
            wrappedValue: ParkingMapViewModel(
                service: service,
                destination: destinationID
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .bottom) {
                grid

                if let spot = viewModel.selectedSpot {
                    SelectedSpotSheet(
                        spot: spot,
                        isReserved: spot.state == .you,
                        onReserve: { onReserve(spot) },
                        onReport: onReport.map { callback in
                            {
                                callback(
                                    ReportSpot(spot: spot.sourceSpot)
                                )
                            }
                        },
                        onClose: {
                            viewModel.selectedSpotID = nil
                        }
                    )
                    .transition(.move(edge: .bottom))
                    .task(id: spot.id) {
                        TelemetryService.shared.trackWalkingTimeViewed(
                            spotCode: spot.code,
                            levelCode: levelCode,
                            minutes: spot.walkMinutes,
                            source: "map"
                        )
                    }
                }
            }
        }
        .background(Palette.screen)
        .animation(
            .easeOut(duration: 0.22),
            value: viewModel.selectedSpotID
        )
        .task(id: "\(levelCode)|\(destinationID ?? "")|\(networkMonitor.isConnected)") {
            viewModel.destination = destinationID

            await viewModel.run(
                levelCode: levelCode,
                isConnected: networkMonitor.isConnected
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Level")

                    Text("Level \(levelCode)")
                        .font(AppFont.display)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    if viewModel.fromCache,
                       let fetchedAt = viewModel.fetchedAt {
                        SavedPill(savedAt: fetchedAt)
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    ForEach(levels) { level in
                        LevelChip(
                            code: level.code,
                            isSelected: level.code == levelCode
                        ) {
                            levelCode = level.code
                        }
                    }
                }
            }

            SpotLegend()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FindSpotFilter.allCases) { filter in
                        ChoiceChip(
                            title: filter.rawValue,
                            isSelected: highlightFilters.contains(filter),
                            selectedColor: Self.highlightColor(for: filter)
                        ) {
                            if let index = highlightFilters.firstIndex(of: filter) {
                                highlightFilters.remove(at: index)
                            } else {
                                highlightFilters.append(filter)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !networkMonitor.isConnected {
                    OfflineNotice(savedAt: viewModel.fetchedAt)
                }

                if let message = viewModel.errorMessage,
                   viewModel.zones.isEmpty {
                    NoticeBox(
                        message: message,
                        tone: .danger,
                        icon: "exclamationmark.circle"
                    )
                }

                EntranceBar()

                ForEach(viewModel.zones) { zone in
                    VStack(alignment: .leading, spacing: 8) {
                        ZoneHeader(name: zone.name)
                        LaneDivider()

                        ForEach(zone.rows) { row in
                            SpotRow(
                                row: row,
                                selectedSpotID: viewModel.selectedSpotID,
                                highlight: highlight(for:),
                                allowAllStates: onReport != nil
                            ) { spot in
                                viewModel.selectedSpotID = spot.id
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(
                .bottom,
                viewModel.selectedSpot == nil
                    ? 8
                    : (onReport == nil ? 180 : 244)
            )
        }
    }

    private func highlight(for spot: ParkingSpot) -> Color? {
        highlightFilters.first {
            spot.matches($0)
        }
        .map(Self.highlightColor(for:))
    }

    static func highlightColor(for filter: FindSpotFilter) -> Color {
        switch filter {
        case .available: return Palette.greenInk
        case .vip: return Palette.violetInk
        case .electric: return Palette.accentHover
        case .accessible: return Palette.amberText
        }
    }
}

struct SelectedSpotSheet: View {
    let spot: ParkingSpot
    let isReserved: Bool
    let onReserve: () -> Void
    let onClose: () -> Void
    let onReport: (() -> Void)?

    init(
        spot: ParkingSpot,
        isReserved: Bool,
        onReserve: @escaping () -> Void,
        onReport: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.spot = spot
        self.isReserved = isReserved
        self.onReserve = onReserve
        self.onReport = onReport
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Palette.line)
                .frame(width: 36, height: 4)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Selected spot")

                    Text(spot.code)
                        .font(.system(
                            size: 28,
                            weight: .medium,
                            design: .monospaced
                        ))
                        .foregroundStyle(Palette.accent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Walk to destination")
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)

                    Text("~\(spot.walkMinutes) min")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }

            HStack(spacing: 8) {
                PrimaryButton(
                    title: isReserved
                        ? "Spot reserved"
                        : (spot.state == .free
                            ? "Reserve this spot"
                            : "Spot unavailable"),
                    isLoading: false,
                    isEnabled: !isReserved && spot.state == .free,
                    action: onReserve
                )

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: Radius.small,
                                style: .continuous
                            )
                            .stroke(Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Report any selected spot, regardless of its status.
            if let onReport {
                Button(action: onReport) {
                    Label(
                        "Report a problem with this spot",
                        systemImage: "exclamationmark.bubble"
                    )
                    .font(AppFont.button)
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(
                            cornerRadius: Radius.small
                        )
                        .fill(Palette.accentSoft)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                topTrailingRadius: 16,
                style: .continuous
            )
            .fill(Palette.card)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
    }
}