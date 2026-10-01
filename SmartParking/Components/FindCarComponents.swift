import SwiftUI

struct CaptionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(Palette.subtle)
    }
}

struct SummaryTile: View {
    let label: String
    let value: String
    let caption: String
    let valueColor: Color
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CaptionLabel(text: label)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: monospaced ? .monospaced : .default))
                .foregroundStyle(valueColor)
            Text(caption)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.subtle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 8)
    }
}

struct FloorCell: View {
    let kind: FloorCellKind

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(stroke, lineWidth: kind == .route ? 1.6 : 1)
            )
    }

    private var fill: Color {
        switch kind {
        case .taken: return Color(hex: 0xE2E5EA)
        case .open: return Color(hex: 0xEEF0F4)
        case .route: return Palette.accentSoft
        case .target: return Palette.accent
        }
    }

    private var stroke: Color {
        switch kind {
        case .taken: return Color(hex: 0xD2D6DD)
        case .open: return Color(hex: 0xDFE3E9)
        case .route, .target: return Palette.accent
        }
    }
}

struct FloorMap: View {
    let rows: [[FloorCellKind]]
    let spotCode: String
    let distance: String

    private let cellWidth: CGFloat = 38
    private let cellHeight: CGFloat = 22
    private let columnSpacing: CGFloat = 7.5
    private let rowSpacing: CGFloat = 6
    private let inset: CGFloat = 20

    private var columnCenter: CGFloat { inset + cellWidth / 2 }

    private func rowTop(_ index: Int) -> CGFloat {
        inset + CGFloat(index) * (cellHeight + rowSpacing)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.neutral)

            grid
                .padding(.leading, inset)
                .padding(.top, inset)

            Path { path in
                path.move(to: CGPoint(x: columnCenter, y: rowTop(3)))
                path.addLine(to: CGPoint(x: columnCenter, y: rowTop(7)))
            }
            .stroke(Palette.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            Text(spotCode)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 1)
                )
                .position(x: 18.5, y: 94)

            Text("🚗")
                .font(.system(size: 14))
                .position(x: columnCenter, y: rowTop(2) + cellHeight / 2 - 3)

            Text(distance)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Palette.subtle)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Palette.line.opacity(0.9))
                )
                .position(x: 69.5, y: 162)

            Text("ENTRANCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(Palette.violetInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Palette.violetSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Palette.violetInk.opacity(0.4), lineWidth: 1)
                )
                .position(x: columnCenter, y: 228)
        }
        .frame(height: 260)
    }

    private var grid: some View {
        VStack(spacing: rowSpacing) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: columnSpacing) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        FloorCell(kind: rows[r][c])
                            .frame(width: cellWidth, height: cellHeight)
                    }
                }
            }
        }
    }
}

struct RouteModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? Palette.accent : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 43)
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

struct RouteStepRow: View {
    let step: RouteStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(step.isFinal ? Palette.accent : Palette.subtle)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(step.isFinal ? Palette.card : Palette.neutral)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(step.isFinal ? Palette.accent.opacity(0.5) : Palette.line, lineWidth: 1)
                )

            Text(step.text)
                .font(.system(size: 14, weight: step.isFinal ? .semibold : .regular))
                .foregroundStyle(step.isFinal ? Palette.accent : Palette.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(step.isFinal ? Palette.accentSoft : Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(step.isFinal ? Palette.accent.opacity(0.6) : Palette.line,
                        lineWidth: step.isFinal ? 1.5 : 1)
        )
    }
}