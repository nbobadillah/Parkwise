import SwiftUI

struct LevelCard: View {
    let level: LevelSummary
    var isRecommended = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(level.code)
                    .font(AppFont.monoId)
                    .foregroundStyle(level.status.tint.strong)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(level.status.tint.soft)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(isRecommended ? "\(level.name) · best" : level.name)
                            .font(AppFont.heading2)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        StatusPill(status: level.status)
                    }

                    ProgressTrack(value: level.occupancy, color: level.status.tint.strong)

                    (Text(level.freeTitle).fontWeight(.semibold).foregroundColor(level.status.tint.strong)
                        + Text("  \(level.reserved) reserved  \(level.occupied) occupied  \(level.total) total"))
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.line)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(isRecommended ? Palette.accent : Palette.line, lineWidth: isRecommended ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuickAction: View {
    let title: String
    let icon: String
    let tint: Tint
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint.strong)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(tint.soft)
                    )
                Text(title)
                    .font(AppFont.heading2)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
