import SwiftUI

struct ReserveSpotView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                mainReservationCard
                infoCard
                historySection
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(Palette.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reserve spot")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("P1 · North · Zone B")
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
                    Text("B201")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Palette.accent)
                    Text("Level P1 · North · Row 2")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    ZStack {
                        Circle()
                            .stroke(Palette.accent, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        Text("15:00")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                    }
                    Text("hold time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }

            Button { } label: {
                Text("Confirm reservation")
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

    private var infoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Palette.amberSoft)
                    .frame(width: 24, height: 24)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.amberText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Best time to reserve")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.amberText)
                Text("Based on your commute, reserve at 7:45 AM to arrive during the low-traffic window. Today's lot fills by 8:30 AM.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.amberText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.amberSoft)
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Compliance history")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)

            VStack(spacing: 0) {
                HistoryRow(title: "Spot B201", date: "Sep 3, 2026", isGood: true)
                HistoryRow(title: "Spot A103", date: "Sep 2, 2026", isGood: true)
                HistoryRow(title: "Spot C012", date: "Aug 30", isGood: false)
                HistoryRow(title: "Spot A205", date: "Aug 28", isGood: true)
                HistoryRow(title: "Spot B108", date: "Aug 27", isGood: true)
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
    let title: String
    let date: String
    let isGood: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isGood ? Palette.greenSoft : Palette.redSoft)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(isGood ? Palette.greenInk.opacity(0.25) : Palette.redInk.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: isGood ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isGood ? Palette.greenInk : Palette.redInk)
            }

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.ink)

            Spacer()

            Text(date)
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
