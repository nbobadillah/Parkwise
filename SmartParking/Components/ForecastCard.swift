import SwiftUI

struct ForecastCard: View {
    let hours: [HourlyOccupancy]
    let currentHour: Int
    let isLive: Bool
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Occupancy forecast")
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isLive {
                    Text("LIVE")
                        .font(AppFont.overline)
                        .tracking(0.6)
                        .foregroundStyle(Palette.greenInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                                .fill(Palette.greenSoft)
                        )
                }
            }

            Group {
                if hours.isEmpty {
                    Text(isLoading ? "Loading forecast" : "No forecast yet")
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(hours) { hour in
                            bar(hour)
                        }
                    }
                }
            }
            .frame(height: 72)

            HStack(spacing: 16) {
                legendItem(color: Palette.greenInk, title: "Low < 55%")
                legendItem(color: Palette.amberInk, title: "Med 55-80%")
                legendItem(color: Palette.redInk, title: "High > 80%")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func bar(_ hour: HourlyOccupancy) -> some View {
        let isNow = hour.hour == currentHour
        let base = tint(for: hour.occupancy)
        return VStack(spacing: 4) {
            GeometryReader { geometry in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .fill(isNow ? base : base.opacity(0.25))
                        .frame(height: geometry.size.height * min(max(hour.occupancy ?? 0, 0.05), 1))
                }
            }
            Text(hour.label)
                .font(AppFont.monoData.weight(isNow ? .medium : .regular))
                .foregroundStyle(isNow ? Palette.ink : Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hour.occupancy.map { "\(Int(($0 * 100).rounded()))% occupancy at \(hour.label)" } ?? "No prediction at \(hour.label)")
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        }
    }

    private func tint(for occupancy: Double?) -> Color {
        guard let occupancy else { return Palette.muted }
        if occupancy < 0.55 { return Palette.greenInk }
        if occupancy <= 0.8 { return Palette.amberInk }
        return Palette.redInk
    }
}
