import SwiftUI

struct SpotResultRow: View {
    let spot: SpotListing
    var isRecommended = false
    let onReserve: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(spot.code)
                .font(AppFont.monoId)
                .foregroundStyle(Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(Palette.accent.opacity(0.4), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                if isRecommended {
                    SectionLabel(text: "Recommended")
                    Text("Level \(spot.levelCode) · \(spot.walkMinutes) min walk")
                        .font(AppFont.heading2)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("Free, closest to your destination and matching your filters.")
                        .font(AppFont.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                } else {
                    Text("Level \(spot.levelCode) · Zone \(spot.zone)")
                        .font(AppFont.heading2)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    meta
                }
            }

            Spacer(minLength: 8)

            Button(action: onReserve) {
                Text("Reserve")
                    .font(AppFont.button)
                    .foregroundStyle(spot.isAvailable ? .white : Palette.ink.opacity(0.38))
                    .padding(.horizontal, 16)
                    .frame(minWidth: 80, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(spot.isAvailable ? Palette.accent : Palette.ink.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!spot.isAvailable)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(isRecommended ? Palette.accentSoft : Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(isRecommended ? Palette.accent.opacity(0.4) : Palette.line, lineWidth: 1)
        )
    }

    private var meta: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text("\(spot.walkMinutes) min  ·  \(kindLabel)\(spot.isAvailable ? "" : "  ·  taken")")
                .lineLimit(1)
            if let icon = kindIcon {
                Image(systemName: icon.name)
                    .font(.system(size: 10))
                    .foregroundStyle(icon.color)
            }
        }
        .font(AppFont.caption)
        .foregroundStyle(Palette.muted)
    }

    private var kindLabel: String {
        switch spot.kind {
        case .standard: return "Standard"
        case .vip: return "VIP"
        case .electric: return "Electric"
        case .accessible: return "Accessible"
        }
    }

    private var kindIcon: (name: String, color: Color)? {
        switch spot.kind {
        case .electric: return ("bolt.fill", Palette.amberInk)
        case .accessible: return ("figure.roll", Palette.accent)
        default: return nil
        }
    }
}
