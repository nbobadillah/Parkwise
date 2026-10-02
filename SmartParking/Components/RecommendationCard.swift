import SwiftUI

struct RecommendationCard: View {
    let recommendation: LevelRecommendation?
    @Binding var arrivalAt: Date

    var body: some View {
        HStack(spacing: 14) {
            Text(recommendation?.recommended ?? "—")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Palette.accent.opacity(0.35), lineWidth: 1)
                )

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
        .padding(14)
        .cardStyle()
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
}
