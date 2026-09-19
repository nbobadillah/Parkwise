import SwiftUI

struct StatusPill: View {
    let status: LevelStatus

    var body: some View {
        Text(status.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(status.tint.strong)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(status.tint.soft)
            )
    }
}

struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Palette.accent : Palette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Palette.accentSoft : Palette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Palette.accent : Palette.line, lineWidth: isSelected ? 1.6 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct LevelChip: View {
    let code: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(code)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Palette.accent : Palette.muted)
                .frame(width: 54, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Palette.accentSoft : Palette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Palette.accent : Palette.line, lineWidth: isSelected ? 1.6 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct LegendDot: View {
    let title: String
    let fill: Color
    let stroke: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .frame(width: 13, height: 13)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
        }
    }
}

struct ProgressTrack: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.line)
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
    }
}
