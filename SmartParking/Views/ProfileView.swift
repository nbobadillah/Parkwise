import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    @ObservedObject var reservationViewModel: ReservationViewModel
    let actionQueue: ActionQueueing

    @State private var isConfirmingSignOut = false
    @State private var pendingActions: [QueuedAction] = []
    @State private var failures: [ActionQueueFailure] = []
    @State private var queueErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Profile")

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let user = viewModel.user {
                        userCard(user)
                    }

                    if !pendingActions.isEmpty {
                        SectionLabel(text: "Pending actions")
                            .padding(.top, 24)

                        pendingActionsCard
                            .padding(.top, 8)
                    }

                    if !failures.isEmpty {
                        SectionLabel(text: "Recent failures")
                            .padding(.top, 24)

                        failuresCard
                            .padding(.top, 8)
                    }

                    if let message = queueErrorMessage {
                        NoticeBox(
                            message: message,
                            tone: .danger,
                            icon: "exclamationmark.circle"
                        )
                        .padding(.top, 8)
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
                        Label(
                            "Log out",
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )
                        .font(AppFont.button)
                        .foregroundStyle(Palette.redInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: Radius.small,
                                style: .continuous
                            )
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
            .refreshable {
                await refreshData()
            }
        }
        .background(Palette.screen)
        .task {
            await loadPendingActions()
        }
        .onReceive(actionQueue.pendingChanges) { actions in
            pendingActions = actions
        }
        .onReceive(actionQueue.failures) { recentFailures in
            failures = recentFailures
        }
        .alert("Log out now?", isPresented: $isConfirmingSignOut) {
            Button("Stay", role: .cancel) {}

            Button("Log out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("You can keep browsing as a guest and log in again anytime.")
        }
    }

    private func refreshData() async {
        await reservationViewModel.loadHistory()
        await loadPendingActions()
    }

    private func loadPendingActions() async {
        do {
            pendingActions = try await actionQueue.pendingActions()
            queueErrorMessage = nil
        } catch {
            queueErrorMessage = "Could not load pending actions: \(error.localizedDescription)"
        }
    }

    private func retryAction(_ action: QueuedAction) {
        Task {
            await actionQueue.retry(id: action.id)
            await loadPendingActions()
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

    private var pendingActionsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(pendingActions.enumerated()), id: \.element.id) { index, action in
                QueueActionRow(
                    title: actionTitle(action.kind),
                    subtitle: "Reservation \(action.reservationId)",
                    date: action.failedAt ?? action.createdAt,
                    icon: action.isFailed
                        ? "exclamationmark.circle"
                        : "arrow.triangle.2.circlepath",
                    color: action.isFailed
                        ? Palette.redInk
                        : Palette.accent,
                    background: action.isFailed
                        ? Palette.redSoft
                        : Palette.accentSoft,
                    detail: action.failureMessage
                        ?? (action.attempts > 0
                            ? "\(action.attempts) synchronization attempts"
                            : "Waiting for connection"),
                    retryAction: action.isFailed
                        ? { retryAction(action) }
                        : nil
                )

                if index < pendingActions.count - 1 {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                }
            }
        }
        .cardStyle()
    }

    private var failuresCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(failures.enumerated()), id: \.offset) { index, failure in
                QueueActionRow(
                    title: actionTitle(failure.kind),
                    subtitle: "Reservation \(failure.reservationId)",
                    date: nil,
                    icon: "exclamationmark.circle",
                    color: Palette.redInk,
                    background: Palette.redSoft,
                    detail: failure.message
                )

                if index < failures.count - 1 {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                }
            }
        }
        .cardStyle()
    }

    private func actionTitle(_ kind: PendingActionKind) -> String {
        switch kind {
        case .checkIn:
            return "Check-in"
        case .release:
            return "Release reservation"
        }
    }

    private var historyCard: some View {
        ReservationHistoryCard(reservations: reservationViewModel.history)
    }
}

private struct QueueActionRow: View {
    let title: String
    let subtitle: String
    let date: Date?
    let icon: String
    let color: Color
    let background: Color
    let detail: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(
                            cornerRadius: Radius.badge,
                            style: .continuous
                        )
                        .fill(background)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFont.body)
                        .foregroundStyle(Palette.ink)

                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)

                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)

                    if let date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(AppFont.monoData)
                            .foregroundStyle(Palette.muted)
                    }
                }

                Spacer(minLength: 0)
            }

            if let retryAction {
                Button(action: retryAction) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(AppFont.button)
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: Radius.small,
                                style: .continuous
                            )
                            .stroke(Palette.accent, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
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
        .accessibilityLabel(
            "Spot \(reservation.spotCode), \(reservation.levelCode), \(reservation.status.rawValue)"
        )
    }

    private var badge: some View {
        let (icon, color, background): (String, Color, Color) = {
            switch reservation.status {
            case .fulfilled, .released:
                return ("checkmark", Palette.greenInk, Palette.greenSoft)
            case .expired:
                return ("xmark", Palette.redInk, Palette.redSoft)
            case .cancelled:
                return ("minus", Palette.muted, Palette.screen)
            case .active:
                return ("clock", Palette.accent, Palette.accentSoft)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(
                    cornerRadius: Radius.badge,
                    style: .continuous
                )
                .fill(background)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: Radius.badge,
                    style: .continuous
                )
                .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}