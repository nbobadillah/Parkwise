import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Palette.accent : Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Palette.accentSoft : Palette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Palette.accent : Palette.border, lineWidth: isSelected ? 1.6 : 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SpotResultRow: View {
    let spot: SpotListing
    let onReserve: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(spot.id)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.accent)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Palette.accent.opacity(0.55), lineWidth: 1.2)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(spot.levelTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "smallcircle.filled.circle")
                            .font(.system(size: 10))
                        Text("\(spot.walkMinutes) min")
                    }
                    Text("·")
                        .foregroundStyle(Palette.slate)
                    Text(spot.kind.title)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.subtle)
            }

            Spacer(minLength: 8)

            Button(action: onReserve) {
                Text("Reserve")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Palette.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .shadow(color: Palette.ink.opacity(0.05), radius: 3, y: 1)
    }
}