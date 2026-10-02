import SwiftUI

struct ReserveSpotView: View {
    let selectedSpot: SpotListing?
    @ObservedObject var viewModel: ReservationViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                mainReservationCard
                if let error = viewModel.error {
                    AuthBanner(message: error.message, isError: true)
                }
                historySection
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(Palette.screen)
    }

    private var displayedSpotCode: String? {
        selectedSpot?.code ?? viewModel.activeSpot?.code
    }

    private var displayedSpotTitle: String? {
        if let selectedSpot {
            return "\(selectedSpot.levelCode) · Zone \(selectedSpot.zone)"
        }
        return viewModel.activeSpot.map { "\($0.levelCode) · Zone \($0.zone)" }
    }

    private var matchingReservation: Reservation? {
        guard let spotId = selectedSpot?.id ?? viewModel.activeSpot?.id else { return nil }
        return viewModel.activeReservation?.spotId == spotId
            ? viewModel.activeReservation
            : nil
    }

    private var remainingTimeText: String {
        guard let remainingTime = viewModel.remainingTime, matchingReservation?.status == .active else {
            return "—"
        }
        let seconds = Int(remainingTime)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var reservationButtonTitle: String {
        switch matchingReservation?.status {
        case .some(.active): return "Check in"
        case .some(.fulfilled): return "Release spot"
        case .some(.released), .some(.cancelled), .some(.expired): return "Reservation closed"
        default: return "Confirm reservation"
        }
    }

    private var isReservationClosed: Bool {
        switch matchingReservation?.status {
        case .some(.released), .some(.cancelled), .some(.expired): return true
        default: return false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reserve spot")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(displayedSpotTitle ?? "Select a parking spot")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
    }

    private var mainReservationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SPOT")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Palette.accent)
                    Text(displayedSpotCode ?? "Select spot")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Palette.accent)
                    Text(displayedSpotTitle ?? "")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    ZStack {
                        Circle()
                            .stroke(Palette.accent, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        Text(remainingTimeText)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                    }
                    Text("hold time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }

            Button {
                Task {
                    switch matchingReservation?.status {
                    case .some(.active):
                        await viewModel.checkIn()
                    case .some(.fulfilled):
                        await viewModel.release()
                    default:
                        guard let selectedSpot else { return }
                        await viewModel.create(spotId: selectedSpot.id)
                    }
                }
            } label: {
                Text(reservationButtonTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.isPerformingAction
                    || isReservationClosed
                    || (selectedSpot == nil && matchingReservation == nil)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Compliance history")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)

            VStack(spacing: 0) {
                if viewModel.history.isEmpty {
                    Text("No reservation history")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(viewModel.history) { reservation in
                        HistoryRow(reservation: reservation)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.line, lineWidth: 1)
                    )
            )
        }
    }
}

private struct HistoryRow: View {
    let reservation: Reservation

    private var isGood: Bool {
        reservation.status == .fulfilled || reservation.status == .released
    }

    private var isActive: Bool {
        reservation.status == .active
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isGood ? Palette.greenSoft : (isActive ? Palette.amberSoft : Palette.redSoft))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isGood ? Palette.greenInk.opacity(0.25) : (isActive ? Palette.amberInk.opacity(0.25) : Palette.redInk.opacity(0.25)), lineWidth: 1)
                    )
                Image(systemName: isGood ? "checkmark" : (isActive ? "clock" : "xmark"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isGood ? Palette.greenInk : (isActive ? Palette.amberInk : Palette.redInk))
            }

            Text("Spot \(reservation.spotCode) · \(reservation.status.rawValue.capitalized)")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink)

            Spacer()

            Text(reservation.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}
