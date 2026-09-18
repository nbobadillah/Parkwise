import SwiftUI

struct ForecastCard: View {
    let slots: [ForecastSlot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Occupancy forecast · today")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.greenInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Palette.greenSoft)
                    )
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(slots) { slot in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(slot.isCurrent ? slot.band.tint.strong : slot.band.tint.soft)
                            .frame(height: 76 * slot.load)
                        Text(slot.hour)
                            .font(.system(size: 12, weight: slot.isCurrent ? .bold : .regular))
                            .foregroundStyle(slot.isCurrent ? Palette.ink : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)

            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            HStack(spacing: 14) {
                legendItem(color: Palette.greenInk, title: "Low < 55%")
                legendItem(color: Color(hex: 0xE8890C), title: "Med 55–80%")
                legendItem(color: Color(hex: 0xE04E2E), title: "High > 80%")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
    }
}
