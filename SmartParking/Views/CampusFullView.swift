import SwiftUI

struct CampusFullView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                alertCard
                nearbyParkingSection
                notifyCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(Palette.screen)
        .task { await viewModel.loadNearbyLots() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No campus spots")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("All levels at capacity")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
    }

    private var alertCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.alertRed)
                    .frame(width: 30, height: 30)
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Campus is full")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.alertRed)
                Text("No campus spots are available. Nearby alternatives are listed below.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.alertText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.alertSoft)
        )
    }

    private var nearbyParkingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby parking")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.ink)

            if viewModel.isLoadingNearbyLots {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.nearbyLotsErrorMessage {
                AuthBanner(message: errorMessage, isError: true)
            } else if viewModel.nearbyLots.isEmpty {
                Text("No nearby parking options available")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
            } else {
                VStack(spacing: 14) {
                    ForEach(viewModel.nearbyLots) { lot in
                        NearbyParkingCard(
                            lot: lot,
                            isPrimary: lot.id == viewModel.nearbyLots.first?.id
                        )
                    }
                }
            }
        }
    }

    private var notifyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notify when campus opens up")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
            HStack(alignment: .center, spacing: 12) {
                Text("Notifications are not available yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { } label: {
                    Text("Notify me")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minWidth: 104)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.purple)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
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
}

private struct NearbyParkingCard: View {
    let lot: NearbyLot
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(lot.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(lot.ratePerHour.formatted(.currency(code: lot.currency)))/hr")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ink)
            }

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Text(lot.address)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("\(lot.walkMinutes) min")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.ink)
            }

            HStack(alignment: .center) {
                Spacer()
                Button { } label: {
                    Text("Navigate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isPrimary ? Palette.accent : Palette.buttonGray)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isPrimary ? Palette.accent : Palette.line, lineWidth: isPrimary ? 1.8 : 1)
                )
        )
    }
}
