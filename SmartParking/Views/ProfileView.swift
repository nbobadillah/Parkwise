import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @ObservedObject var reservationViewModel: ReservationViewModel
    @State private var isConfirmingSignOut = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Profile")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let user = viewModel.user {
                        userCard(user)
                    }

                    SectionLabel(text: "Reservation history")
                        .padding(.top, 24)
                    historyCard
                        .padding(.top, 8)

                    if let message = viewModel.errorMessage {
                        NoticeBox(message: message)
                            .padding(.top, 8)
                    }

                    Button {
                        isConfirmingSignOut = true
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(AppFont.button)
                            .foregroundStyle(Palette.redInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .stroke(Palette.redInk, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)
                }
                .padding(16)
                .padding(.top, 8)
            }
            .refreshable { await reservationViewModel.loadHistory() }
        }
        .background(Palette.screen)
        .alert("Log out now?", isPresented: $isConfirmingSignOut) {
            Button("Stay", role: .cancel) {}
            Button("Log out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("You can keep browsing as a guest and log in again anytime.")
        }
    }

    private func userCard(_ user: AppUser) -> some View {
        HStack(spacing: 16) {
            Text(user.initials)
                .font(AppFont.heading1)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Palette.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName.isEmpty ? "Parkwise user" : user.displayName)
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(user.email)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cardStyle()
    }

    private var historyCard: some View {
        ReservationHistoryCard(reservations: reservationViewModel.history)
    }
}

struct ScreenHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppFont.display)
            .foregroundStyle(Palette.ink)
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
}

struct ReservationHistoryCard: View {
    let reservations: [Reservation]

    var body: some View {
        if reservations.isEmpty {
            Text("No reservations yet")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardStyle()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(reservations.enumerated()), id: \.element.id) { index, reservation in
                    ReservationHistoryRow(reservation: reservation)
                    if index < reservations.count - 1 {
                        Rectangle()
                            .fill(Palette.line)
                            .frame(height: 1)
                    }
                }
            }
            .cardStyle()
        }
    }
}

private struct ReservationHistoryRow: View {
    let reservation: Reservation

    var body: some View {
        HStack(spacing: 16) {
            badge
            Text("Spot \(reservation.spotCode) · \(reservation.levelCode)")
                .font(AppFont.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(reservation.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(AppFont.monoData)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spot \(reservation.spotCode), \(reservation.levelCode), \(reservation.status.rawValue)")
    }

    private var badge: some View {
        let (icon, color, background): (String, Color, Color) = {
            switch reservation.status {
            case .fulfilled, .released: return ("checkmark", Palette.greenInk, Palette.greenSoft)
            case .expired: return ("xmark", Palette.redInk, Palette.redSoft)
            case .cancelled: return ("minus", Palette.muted, Palette.screen)
            case .active: return ("clock", Palette.accent, Palette.accentSoft)
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}
