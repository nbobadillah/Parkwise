import SwiftUI

struct RecommendationCard: View {
    let recommendation: LevelRecommendation?
    let savedAt: Date?
    @Binding var arrivalAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                arrivalText
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                changeButton
            }

            if let savedAt {
                SavedPill(savedAt: savedAt)
            }

            HStack(spacing: 8) {
                ForEach(levels, id: \.code) { level in
                    levelTile(level)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
    }

    private var arrivalText: Text {
        let time = Text(arrivalAt.formatted(date: .omitted, time: .shortened)).fontWeight(.semibold).foregroundColor(Palette.ink)
        guard let best = recommendation?.recommended else {
            return Text("Arriving ") + time + Text(" · no history yet")
        }
        return Text("Arriving ") + time + Text(" · best ") + Text(best).fontWeight(.semibold).foregroundColor(Palette.ink)
    }

    private var changeButton: some View {
        DatePicker("Arrival", selection: $arrivalAt, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .colorMultiply(.clear)
            .frame(width: 60, height: 32)
            .clipped()
            .overlay(
                Text("Change")
                    .font(AppFont.button)
                    .foregroundStyle(Palette.accent)
                    .allowsHitTesting(false)
            )
            .accessibilityLabel("Change arrival time")
    }

    private var levels: [LevelOccupancy] {
        recommendation?.levels ?? ["P1", "P2", "P3"].map { LevelOccupancy(code: $0, predictedOccupancy: nil) }
    }

    private func levelTile(_ level: LevelOccupancy) -> some View {
        let isRecommended = level.code == recommendation?.recommended
        return VStack(spacing: 2) {
            Text(level.code)
                .font(AppFont.monoId)
                .foregroundStyle(isRecommended ? Palette.accent : Palette.ink)
            Text(level.predictedOccupancy.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(level.predictedOccupancy.map(tint(for:)) ?? Palette.muted)
            Text(isRecommended ? "Best" : "full at \(Self.displayTime(slot: recommendation?.slot))")
                .font(AppFont.caption)
                .foregroundStyle(isRecommended ? Palette.accent : Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(isRecommended ? Palette.accentSoft : Palette.neutral)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(isRecommended ? Palette.accent : Palette.line, lineWidth: isRecommended ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
    }

    private static func displayTime(slot: String?) -> String {
        guard let slot else { return "arrival" }
        let parts = slot.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let date = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
        else { return slot }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func tint(for occupancy: Double) -> Color {
        if occupancy < 0.55 { return Palette.greenInk }
        if occupancy <= 0.8 { return Palette.amberInk }
        return Palette.redInk
    }
}
