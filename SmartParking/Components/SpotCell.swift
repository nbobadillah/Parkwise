import SwiftUI

struct SpotCell: View {
    let spot: ParkingSpot
    let isSelected: Bool
    var highlight: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(spot.code)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(spot.state == .unavailable ? Palette.muted : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .stroke(border, lineWidth: borderWidth)
                )
        }
        .buttonStyle(.plain)
        .disabled(spot.state != .free && spot.state != .you && !isSelected)
        .accessibilityLabel("\(spot.code), \(stateTitle)")
    }

    private var baseFill: Color {
        switch spot.state {
        case .free: return Palette.greenSoft
        case .taken: return Palette.card
        case .unavailable: return Palette.neutral
        case .reserved: return Palette.amberSoft
        case .you: return Palette.accentSoft
        }
    }

    private var fill: Color {
        guard let highlight else { return baseFill }
        return highlight.opacity(0.12)
    }

    private var border: Color {
        if isSelected || spot.state == .you { return Palette.accent }
        if let highlight { return highlight }
        switch spot.state {
        case .free: return Palette.greenInk.opacity(0.4)
        case .taken: return Palette.line
        case .unavailable: return Palette.muted
        case .reserved: return Palette.amberInk.opacity(0.6)
        case .you: return Palette.accent
        }
    }

    private var borderWidth: CGFloat {
        if highlight != nil && !isSelected && spot.state != .you { return 2.5 }
        return isSelected || spot.state == .you ? 1.5 : 1
    }

    private var stateTitle: String {
        switch spot.state {
        case .free: return "free"
        case .taken: return "taken"
        case .unavailable: return "unavailable"
        case .reserved: return "reserved"
        case .you: return "your spot"
        }
    }
}

struct SpotRow: View {
    static let slots = 6

    let row: ParkingRow
    let selectedSpotID: String?
    var highlight: (ParkingSpot) -> Color? = { _ in nil }
    let onSelect: (ParkingSpot) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("\(row.index)")
                .font(AppFont.monoData)
                .foregroundStyle(Palette.muted)
                .frame(width: 14, alignment: .leading)
            ForEach(0..<Self.slots, id: \.self) { slot in
                if slot < row.spots.count {
                    let spot = row.spots[slot]
                    SpotCell(spot: spot, isSelected: spot.id == selectedSpotID, highlight: highlight(spot)) {
                        onSelect(spot)
                    }
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
            }
        }
    }
}

struct SpotLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { items }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    LegendDot(title: "Free", fill: Palette.greenSoft, stroke: Palette.greenInk)
                    LegendDot(title: "Taken", fill: Palette.card, stroke: Palette.line)
                    LegendDot(title: "Reserved", fill: Palette.amberSoft, stroke: Palette.amberInk)
                }
                HStack(spacing: 16) {
                    LegendDot(title: "Unavailable", fill: Palette.neutral, stroke: Palette.muted)
                    LegendDot(title: "You", fill: Palette.accentSoft, stroke: Palette.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var items: some View {
        LegendDot(title: "Free", fill: Palette.greenSoft, stroke: Palette.greenInk)
        LegendDot(title: "Taken", fill: Palette.card, stroke: Palette.line)
        LegendDot(title: "Reserved", fill: Palette.amberSoft, stroke: Palette.amberInk)
        LegendDot(title: "Unavailable", fill: Palette.neutral, stroke: Palette.muted)
        LegendDot(title: "You", fill: Palette.accentSoft, stroke: Palette.accent)
    }
}

struct LaneDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
            .fill(Palette.line.opacity(0.5))
            .frame(height: 18)
            .overlay(
                HStack {
                    ForEach(0..<6, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Palette.muted.opacity(0.4))
                            .frame(width: 14, height: 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            )
    }
}

struct ZoneHeader: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Palette.accent)
                .frame(width: 3, height: 14)
            Text(name)
                .font(AppFont.heading2)
                .foregroundStyle(Palette.accent)
            Spacer(minLength: 0)
        }
    }
}

struct EntranceBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Text("ENTRANCE / EXIT")
                .font(AppFont.overline)
                .tracking(0.6)
                .foregroundStyle(Palette.ink)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Text("N")
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
    }
}
