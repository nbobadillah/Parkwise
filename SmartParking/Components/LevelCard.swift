import SwiftUI

struct LevelCard: View {
    let level: ParkingLevel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(level.code)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(level.status.tint.strong)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(level.status.tint.soft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(level.status.tint.strong.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Text(level.listTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 4)
                        StatusPill(status: level.status)
                    }

                    ProgressTrack(value: level.occupancy, color: level.status.tint.strong)

                    HStack(spacing: 8) {
                        Text(level.freeTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(level.status.tint.strong)
                        Text("\(level.reserved) reserved · \(level.total) total")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.slate)
            }
            .padding(14)
            .cardStyle()
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint.strong)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.soft)
                    )
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .cardStyle(radius: 14)
        }
        .buttonStyle(.plain)
    }
}
