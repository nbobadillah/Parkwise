import SwiftUI

struct RecommendationCard: View {
    let recommendation: LevelRecommendation?
    @Binding var arrivalAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                }

                Spacer(minLength: 4)

                DatePicker("Arrival", selection: $arrivalAt, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Palette.accent)
            }

            HStack(spacing: 10) {
                ForEach(levels, id: \.code) { level in
                    levelTile(level)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var levels: [LevelOccupancy] {
        recommendation?.levels ?? ["P1", "P2", "P3"].map { LevelOccupancy(code: $0, predictedOccupancy: nil) }
    }

    private func levelTile(_ level: LevelOccupancy) -> some View {
        let isRecommended = level.code == recommendation?.recommended
        return VStack(spacing: 6) {
            Text(level.code)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isRecommended ? Palette.accent : Palette.ink)
            Text(level.predictedOccupancy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(level.predictedOccupancy.map(tint(for:)) ?? Palette.muted)
            Text(isRecommended ? "Best" : "full")
                .font(.system(size: 11, weight: isRecommended ? .bold : .regular))
                .foregroundStyle(isRecommended ? Palette.accent : Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isRecommended ? Palette.accentSoft : Palette.neutral)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isRecommended ? Palette.accent.opacity(0.55) : Palette.line, lineWidth: isRecommended ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let code = recommendation?.recommended else { return "No forecast yet" }
        return "Level \(code)"
    }

    private var subtitle: String {
        guard let recommendation, let occupancy = recommendation.recommendedOccupancy else {
            return "Pick your arrival time"
        }
        return "~\(Int((occupancy * 100).rounded()))% full at \(recommendation.slot)"
    }

    private func tint(for occupancy: Double) -> Color {
        if occupancy < 0.55 { return Palette.greenInk }
        if occupancy <= 0.8 { return Color(hex: 0xE8890C) }
        return Color(hex: 0xE04E2E)
    }
}
