import SwiftUI

struct CampusFullView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var alerts: CampusAlertService

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    alertCard
                    Text("Nearby parking")
                        .font(AppFont.heading1)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 24)
                    nearbyParkingSection
                        .padding(.top, 8)
                    notifyCard
                        .padding(.top, 16)
                }
                .padding(16)
            }
            .refreshable {
                await viewModel.loadNearbyLots()
                await viewModel.loadLevels(isAuthenticated: authViewModel.isAuthenticated)
            }
        }
        .background(Palette.screen)
        .task { await viewModel.loadNearbyLots() }
        .task(id: alerts.state) {
            guard alerts.state == .watching else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: CampusAlertService.pollInterval)
                guard !Task.isCancelled else { return }
                await viewModel.loadLevels(isAuthenticated: authViewModel.isAuthenticated)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No campus spots")
                .font(AppFont.display)
                .foregroundStyle(Palette.ink)
            Text("All levels at capacity")
                .font(AppFont.body)
                .foregroundStyle(Palette.muted)
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

    private var alertCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Palette.redInk)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Campus is full")
                    .font(AppFont.heading2)
                    .foregroundStyle(Palette.redInk)
                Text("All 3 levels at capacity. Nearby options below.")
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.redSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.redInk.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var nearbyParkingSection: some View {
        if viewModel.isLoadingNearbyLots && viewModel.nearbyLots.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if let errorMessage = viewModel.nearbyLotsErrorMessage, viewModel.nearbyLots.isEmpty {
            NoticeBox(message: errorMessage, tone: .danger, icon: "exclamationmark.circle")
        } else if viewModel.nearbyLots.isEmpty {
            Text("No nearby parking options available")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        } else {
            VStack(spacing: 8) {
                ForEach(viewModel.nearbyLots) { lot in
                    NearbyParkingCard(
                        lot: lot,
                        isPrimary: lot.id == viewModel.nearbyLots.first?.id
                    )
                }
            }
        }
    }

    private var notifyCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notify when campus opens up")
                    .font(AppFont.heading2)
                    .foregroundStyle(Palette.ink)
                Text(notifyMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: notifyAction) {
                Text(notifyButtonTitle)
                    .font(AppFont.button)
                    .foregroundStyle(alerts.state == .watching ? Palette.ink : .white)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 88, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(alerts.state == .watching ? Palette.screen : Palette.purple)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .stroke(alerts.state == .watching ? Palette.line : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cardStyle()
    }

    private var notifyMessage: String {
        switch alerts.state {
        case .off: return "Get an alert as soon as a spot frees up while Parkwise is open."
        case .watching: return "Checking every 30 seconds. We'll notify you when a spot opens up."
        case .denied: return "Notifications are off for Parkwise. Turn them on in Settings."
        }
    }

    private var notifyButtonTitle: String {
        switch alerts.state {
        case .off: return "Notify me"
        case .watching: return "Cancel"
        case .denied: return "Settings"
        }
    }

    private func notifyAction() {
        switch alerts.state {
        case .off:
            Task { await alerts.enable() }
        case .watching:
            alerts.cancel()
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

private struct NearbyParkingCard: View {
    @Environment(\.openURL) private var openURL
    let lot: NearbyLot
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    if isPrimary {
                        Text("CLOSEST")
                            .font(AppFont.overline)
                            .tracking(0.6)
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                                    .fill(Palette.accentSoft)
                            )
                    }
                    Text(lot.name)
                        .font(AppFont.heading2)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(lot.ratePerHour.formatted(.currency(code: lot.currency).precision(.fractionLength(0))))/hr")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.ink)
            }

            Text(lot.address)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 11))
                Text("\(lot.walkMinutes) min")
                Spacer(minLength: 8)
                Button(action: navigate) {
                    Text("Navigate")
                        .font(AppFont.button)
                        .foregroundStyle(isPrimary ? .white : Palette.ink)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 88, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .fill(isPrimary ? Palette.accent : Palette.screen)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .stroke(isPrimary ? Color.clear : Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .font(AppFont.caption)
            .foregroundStyle(Palette.muted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(isPrimary ? Palette.accent : Palette.line, lineWidth: isPrimary ? 1.5 : 1)
        )
    }

    private func navigate() {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(lot.name), \(lot.address), Bogotá"),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        if let url = components?.url {
            openURL(url)
        }
    }
}
