import SwiftUI

enum WeekHeatStyle {
    static let tones: [Color] = [
        Palette.accentSoft,
        Color(hex: 0xB3D4FF),
        Color(hex: 0x4C9AFF),
        Color(hex: 0x2684FF),
        Palette.accent,
        Color(hex: 0x0747A6)
    ]
    static let empty = Palette.neutral
    static let best = Palette.amberText
    static let labelWidth: CGFloat = 36
    static let cellHeight: CGFloat = 22
    static let cellRadius: CGFloat = 4
    static let spacing: CGFloat = 4

    static func color(for tone: Int?) -> Color {
        guard let tone, tones.indices.contains(tone) else { return empty }
        return tones[tone]
    }
}

struct WeekHeatCellView: View {
    let cell: HeatCell

    var body: some View {
        RoundedRectangle(cornerRadius: WeekHeatStyle.cellRadius, style: .continuous)
            .fill(WeekHeatStyle.color(for: cell.tone))
            .overlay {
                if cell.isBest {
                    RoundedRectangle(cornerRadius: WeekHeatStyle.cellRadius, style: .continuous)
                        .strokeBorder(WeekHeatStyle.best, lineWidth: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: WeekHeatStyle.cellHeight)
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let hour = "\(cell.hour):00"
        guard let occupancy = cell.occupancy else { return "\(hour), no data" }
        let percent = Int((occupancy * 100).rounded())
        return cell.isBest ? "\(hour), \(percent)% full, best time" : "\(hour), \(percent)% full"
    }
}

struct DiagonalStripes: Shape {
    var spacing: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

struct NotSavedStrip: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WeekHeatStyle.cellRadius, style: .continuous)
                .fill(Palette.neutral)
            DiagonalStripes()
                .stroke(Palette.muted.opacity(0.18), lineWidth: 1.5)
                .clipShape(RoundedRectangle(cornerRadius: WeekHeatStyle.cellRadius, style: .continuous))
            Text("Not saved")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: WeekHeatStyle.cellHeight)
    }
}

struct WeekHeatLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Empty")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            ForEach(WeekHeatStyle.tones.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(WeekHeatStyle.tones[index])
                    .frame(width: 18, height: 10)
            }
            Text("Full")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(WeekHeatStyle.best, lineWidth: 2)
                .frame(width: 14, height: 14)
                .padding(.leading, 8)
                .accessibilityLabel("Best times")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct ArrivalCapsule: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(text)
                    .font(AppFont.button)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(Palette.neutral))
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Changes the arrival time")
    }
}

struct BestTimeRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Text("Use this time")
                    .font(AppFont.button)
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .stroke(Palette.accent, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}
