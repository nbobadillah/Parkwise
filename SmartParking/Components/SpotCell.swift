import SwiftUI

struct SpotCell: View {
    let spot: ParkingSpot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(stroke, lineWidth: isSelected ? 0 : 1)
                )
                .overlay(content)
                .frame(height: 42)
        }
        .buttonStyle(.plain)
        .disabled(spot.state == .taken && !isSelected)
    }

    private var content: some View {
        Group {
            if isSelected {
                Text(spot.id)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            } else if spot.state == .free {
                Circle()
                    .fill(Palette.greenInk)
                    .frame(width: 6, height: 6)
            } else if spot.state == .you {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var fill: Color {
        if isSelected { return Palette.slate }
        switch spot.state {
        case .free: return Palette.greenSoft
        case .taken: return Palette.neutral
        case .reserved: return Palette.amberSoft
        case .you: return Palette.accentSoft
        }
    }

    private var stroke: Color {
        switch spot.state {
        case .free: return Palette.greenInk.opacity(0.35)
        case .taken: return Palette.line
        case .reserved: return Palette.amberInk.opacity(0.4)
        case .you: return Palette.accent
        }
    }
}

struct LaneDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .foregroundStyle(Palette.line)
            .frame(height: 24)
            .overlay(
                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule()
                            .fill(Palette.slate.opacity(0.5))
                            .frame(width: 14, height: 2)
                    }
                }
            )
    }
}

struct ZoneHeader: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.accent)
                .frame(width: 3, height: 15)
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.accent)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}

struct EntranceBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("ENTRANCE / EXIT")
                .font(.system(size: 14, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.accent)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
            Text("→ N")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .cardStyle(radius: 12)
    }
}
