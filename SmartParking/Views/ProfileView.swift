import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @ObservedObject var reservationViewModel: ReservationViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = viewModel.user {
                    VStack(spacing: 12) {
                        Text(user.initials)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 76, height: 76)
                            .background(Circle().fill(Palette.accentSoft))
                        Text(user.displayName.isEmpty ? "Parkwise user" : user.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(user.email)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .cardStyle()
                }

                historySection

                if let message = viewModel.errorMessage {
                    AuthBanner(message: message, isError: true)
                }

                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.redInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.redSoft)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .background(Palette.screen)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reservation history")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)

            VStack(spacing: 0) {
                if reservationViewModel.history.isEmpty {
                    Text("No reservation history")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(reservationViewModel.history) { reservation in
                        ProfileHistoryRow(reservation: reservation)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card)
            )
        }
    }
}

private struct ProfileHistoryRow: View {
    let reservation: Reservation

    private var isGood: Bool {
        reservation.status == .fulfilled || reservation.status == .released
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reservation.spotCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ink)

                Text("\(reservation.levelCode) · \(reservation.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            Text(reservation.status.rawValue.capitalized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isGood ? Palette.greenInk : Palette.muted)
        }
        .padding(14)
    }
}