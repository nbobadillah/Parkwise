import SwiftUI

struct ForecastCard: View {
    let points: [PredictionPoint]
    let levelCode: String?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(levelCode.map { "Occupancy forecast · \($0)" } ?? "Occupancy forecast · today")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("PREDICTED")
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

            if points.isEmpty {
                Text(isLoading ? "Loading forecast" : "No prediction available")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(points, id: \.slot) { point in
                            VStack(spacing: 8) {
                                if let occupancy = point.occupancy {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(tint(for: occupancy))
                                        .frame(height: 76 * min(max(occupancy, 0), 1))
                                        .accessibilityLabel("\(Int((occupancy * 100).rounded()))% occupancy at \(point.slot)")
                                } else {
                                    Text("No data")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(Palette.muted)
                                        .frame(height: 76)
                                        .accessibilityLabel("No prediction at \(point.slot)")
                                }
                                Text(point.slot)
                                    .font(.system(size: 10, weight: isCurrent(point.slot) ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(isCurrent(point.slot) ? Palette.ink : Palette.muted)
                            }
                            .frame(width: 52)
                        }
                    }
                    .frame(height: 100, alignment: .bottom)
                }
            }

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

    private func tint(for occupancy: Double) -> Color {
        if occupancy < 0.55 { return Palette.greenInk }
        if occupancy <= 0.8 { return Color(hex: 0xE8890C) }
        return Color(hex: 0xE04E2E)
    }

    private func isCurrent(_ slot: String) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let hour = components.hour ?? 0
        let minute = (components.minute ?? 0) / 15 * 15
        return slot == String(format: "%02d:%02d", hour, minute)
    }
}
