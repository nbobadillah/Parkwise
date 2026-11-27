import SwiftUI

struct WeekPlanView: View {
    let onBack: () -> Void
    let onUseTime: (Date) -> Void

    @StateObject private var viewModel: WeekPlanViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isPickingArrival = false
    @State private var draftArrival = Date()

    init(
        service: WeekForecastServicing,
        arrivalAt: Date?,
        networkMonitor: NetworkMonitor,
        onBack: @escaping () -> Void,
        onUseTime: @escaping (Date) -> Void
    ) {
        self.onBack = onBack
        self.onUseTime = onUseTime

        _viewModel = StateObject(
            wrappedValue: WeekPlanViewModel(
                service: service,
                arrivalAt: arrivalAt,
                networkMonitor: networkMonitor
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls

                    if let banner = viewModel.banner {
                        NoticeBox(
                            message: banner.message,
                            title: banner.title,
                            icon: banner.isOffline ? "wifi.slash" : "icloud.slash"
                        )
                    }

                    if verticalSizeClass == .compact {
                        HStack(alignment: .top, spacing: 16) {
                            cards
                        }
                    } else {
                        cards
                    }

                    if let footer = viewModel.footer {
                        Text(footer)
                            .font(AppFont.caption)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .background(Palette.screen)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isPickingArrival) {
            arrivalSheet
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Plan your week")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            ArrivalCapsule(text: "Arrive around \(viewModel.arrivalText)") {
                draftArrival = viewModel.arrivalAt
                isPickingArrival = true
            }

            Spacer(minLength: 0)

            ForEach(WeekPlanViewModel.levels, id: \.self) { code in
                LevelChip(code: code, isSelected: viewModel.level == code) {
                    viewModel.selectLevel(code)
                }
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        if viewModel.selectedWeek != nil || viewModel.isLoading || !viewModel.hasLoaded {
            mapCard
        }

        if viewModel.selectedWeek != nil && !viewModel.isBuilding {
            bestCard
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: viewModel.overline)

            if viewModel.selectedWeek == nil || viewModel.isBuilding {
                ProgressView()
                    .tint(Palette.accent)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                grid

                WeekHeatLegend()
                    .padding(.top, 4)

                Text(viewModel.bestNearText)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var grid: some View {
        VStack(spacing: WeekHeatStyle.spacing) {
            HStack(spacing: WeekHeatStyle.spacing) {
                Color.clear
                    .frame(width: WeekHeatStyle.labelWidth, height: 1)

                ForEach(viewModel.heatMap.hours, id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(AppFont.monoData)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(viewModel.heatMap.rows) { row in
                HStack(spacing: WeekHeatStyle.spacing) {
                    Text(row.label)
                        .font(AppFont.body)
                        .foregroundStyle(Palette.ink)
                        .frame(width: WeekHeatStyle.labelWidth, alignment: .leading)

                    if row.isSaved {
                        ForEach(row.cells) { cell in
                            WeekHeatCellView(cell: cell)
                        }
                    } else {
                        NotSavedStrip()
                    }
                }
            }
        }
    }

    private var bestCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: viewModel.bestOverline)
                .padding(16)

            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            if viewModel.heatMap.best.isEmpty {
                Text(viewModel.noBestMessage)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
            } else {
                ForEach(Array(viewModel.heatMap.best.enumerated()), id: \.element.id) { index, slot in
                    if index > 0 {
                        Rectangle()
                            .fill(Palette.line)
                            .frame(height: 1)
                    }

                    BestTimeRow(
                        title: "\(WeekClock.weekdayName(slot.weekday)) · \(WeekPlanFormat.hour(slot.hour))",
                        subtitle: "Level \(viewModel.level) · \(slot.percent)% full expected"
                    ) {
                        use(slot)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var arrivalSheet: some View {
        VStack(spacing: 16) {
            Text("Arrive around")
                .font(AppFont.heading1)
                .foregroundStyle(Palette.ink)

            DatePicker("Arrival", selection: $draftArrival, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_US"))
                .environment(\.timeZone, WeekClock.timeZone)

            PrimaryButton(title: "Done", isLoading: false, isEnabled: true) {
                viewModel.setArrival(draftArrival)
                isPickingArrival = false
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func hourLabel(_ hour: Int) -> String {
        guard let first = viewModel.heatMap.hours.first else { return "" }
        return (hour - first) % 2 == 0 ? "\(hour)" : ""
    }

    private func use(_ slot: BestSlot) {
        guard let date = viewModel.use(slot) else { return }
        onUseTime(date)
    }
}
