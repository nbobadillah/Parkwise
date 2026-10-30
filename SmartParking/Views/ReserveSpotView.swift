import SwiftUI

struct ReserveSpotView: View {
    static let holdMinutes = 15
    static let warnBefore: TimeInterval = 3 * 60

    let selectedSpot: SpotListing?
    @ObservedObject var viewModel: ReservationViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    var onOpenMap: () -> Void = {}
    var onFindSpot: () -> Void = {}
    var onFindCar: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !networkMonitor.isConnected && matchingReservation != nil {
                        NoticeBox(
                            message: "The countdown keeps running with the time the server gave. Checking in and leaving need the signal back.",
                            title: "No signal",
                            icon: "antenna.radiowaves.left.and.right.slash"
                        )
                    }
                    if let error = viewModel.error {
                        NoticeBox(message: error.message, tone: .danger, icon: "exclamationmark.circle")
                    }

                    spotCard

                    NoticeBox(
                        message: "Reserve when you are about \(Self.holdMinutes) minutes away so you arrive before the hold expires.",
                        title: "Best time to reserve"
                    )

                    Text("Compliance history")
                        .font(AppFont.heading1)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 8)
                    ReservationHistoryCard(reservations: viewModel.history)
                }
                .padding(16)
                .padding(.top, 8)
            }
            .refreshable {
                await viewModel.loadActive()
                await viewModel.loadHistory()
            }
        }
        .background(Palette.screen)
    }

    private var matchingReservation: Reservation? {
        guard let reservation = viewModel.activeReservation else { return nil }
        guard let selectedSpot else { return reservation }
        return reservation.spotId == selectedSpot.id ? reservation : nil
    }

    private var subtitle: String {
        if let reservation = matchingReservation {
            return "Level \(reservation.levelCode) · Spot \(reservation.spotCode)"
        }
        if let selectedSpot {
            return "Level \(selectedSpot.levelCode) · Zone \(selectedSpot.zone)"
        }
        return "Pick a spot on the map"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reserve spot")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(AppFont.body)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
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

    @ViewBuilder
    private var spotCard: some View {
        if let reservation = matchingReservation {
            reservationCard(reservation)
        } else if let selectedSpot {
            card(
                code: selectedSpot.code,
                detail: "Level \(selectedSpot.levelCode) · Zone \(selectedSpot.zone) · \(selectedSpot.walkMinutes) min walk",
                ring: HoldTimeRing(label: Self.countdown(TimeInterval(Self.holdMinutes * 60)), caption: "hold time", color: Palette.accent)
            ) {
                PrimaryButton(
                    title: networkMonitor.isConnected ? "Confirm reservation" : "Waiting for connection",
                    isLoading: viewModel.isPerformingAction,
                    isEnabled: networkMonitor.isConnected
                ) {
                    Task { await viewModel.create(spotId: selectedSpot.id) }
                }
            }
        } else {
            emptyCard
        }
    }

    @ViewBuilder
    private func reservationCard(_ reservation: Reservation) -> some View {
        switch reservation.status {
        case .active:
            let remaining = viewModel.remainingTime ?? 0
            card(
                code: reservation.spotCode,
                detail: "Level \(reservation.levelCode) · expires \(reservation.expiresAt.formatted(date: .omitted, time: .shortened))",
                ring: HoldTimeRing(
                    label: Self.countdown(remaining),
                    caption: "hold time left",
                    color: remaining <= Self.warnBefore ? Palette.amberInk : Palette.accent
                )
            ) {
                PrimaryButton(title: "I parked", isLoading: viewModel.isPerformingAction, isEnabled: true) {
                    Task { await viewModel.checkIn() }
                }
                SecondaryButton(title: "Cancel reservation", isEnabled: !viewModel.isPerformingAction) {
                    Task { await viewModel.release() }
                }
            }
        case .fulfilled:
            card(
                code: reservation.spotCode,
                detail: reservation.checkedInAt.map { "Parked since \($0.formatted(date: .omitted, time: .shortened))" } ?? "Parked",
                ring: HoldTimeRing(label: "P", caption: "parked", color: Palette.greenInk)
            ) {
                SecondaryButton(title: "Find my car", action: onFindCar)
                PrimaryButton(title: "I left", isLoading: viewModel.isPerformingAction, isEnabled: true) {
                    Task { await viewModel.release() }
                }
            }
        case .released, .cancelled, .expired:
            card(
                code: reservation.spotCode,
                detail: "Level \(reservation.levelCode) · reservation \(reservation.status.rawValue)",
                ring: HoldTimeRing(label: "—", caption: "closed", color: Palette.muted)
            ) {
                PrimaryButton(title: "Open map", isLoading: false, isEnabled: true, action: onOpenMap)
            }
        }
    }

    private func card<Ring: View, Actions: View>(
        code: String,
        detail: String,
        ring: Ring,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Spot")
                        .padding(.top, 8)
                    Text(code)
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                ring
            }
            VStack(spacing: 8) {
                actions()
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No spot selected")
                .font(AppFont.heading1)
                .foregroundStyle(Palette.ink)
            Text("Choose a free spot on the map or search one to reserve it.")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            VStack(spacing: 8) {
                PrimaryButton(title: "Open map", isLoading: false, isEnabled: true, action: onOpenMap)
                SecondaryButton(title: "Find a spot", action: onFindSpot)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .cardStyle()
    }

    private static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct HoldTimeRing: View {
    let label: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 5)
                        .padding(2.5)
                )
            Text(caption)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        }
    }
}
