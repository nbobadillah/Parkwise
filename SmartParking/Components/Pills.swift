import SwiftUI

struct StatusPill: View {
    let status: LevelStatus

    var body: some View {
        Text(status.title)
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(status.tint.strong)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .fill(status.tint.soft)
            )
    }
}

struct SavedPill: View {
    let savedAt: Date

    var body: some View {
        Label("Guardado \(savedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock.arrow.circlepath")
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(Palette.amberText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                    .fill(Palette.amberSoft)
            )
    }
}

struct OfflineNotice: View {
    let savedAt: Date?
    var serverUnreachable = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: serverUnreachable ? "icloud.slash" : "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Palette.amberText)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(serverUnreachable ? "Server unreachable" : "No signal")
                    .font(AppFont.heading2)
                    .foregroundStyle(Palette.amberText)
                if let savedAt {
                    (Text("Showing cached data from ")
                        + Text(savedAt.formatted(date: .omitted, time: .shortened)).fontWeight(.semibold).foregroundColor(Palette.ink)
                        + Text(" · \(savedAt.formatted(.dateTime.month(.abbreviated).day()))"))
                        .font(AppFont.body)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text("No saved data yet")
                        .font(AppFont.body)
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.amberSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.amberBorder, lineWidth: 1)
        )
    }
}

struct NoticeBox: View {
    enum Tone {
        case warning
        case danger
    }

    let message: String
    var title: String?
    var tone: Tone = .warning
    var icon = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(AppFont.heading2)
                        .foregroundStyle(textColor)
                }
                Text(message)
                    .font(AppFont.body)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(tone == .warning ? Palette.amberSoft : Palette.redSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(tone == .warning ? Palette.amberBorder : Palette.redInk.opacity(0.3), lineWidth: 1)
        )
    }

    private var textColor: Color {
        tone == .warning ? Palette.amberText : Palette.redInk
    }
}

struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    var selectedColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.button)
                .foregroundStyle(isSelected ? tint : Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .stroke(isSelected ? tint : Palette.line, lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        selectedColor ?? Palette.accent
    }

    private var background: Color {
        guard isSelected else { return Palette.card }
        return selectedColor.map { $0.opacity(0.14) } ?? Palette.accentSoft
    }
}

struct LevelChip: View {
    let code: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ChoiceChip(title: code, isSelected: isSelected, action: action)
    }
}

struct LegendDot: View {
    let title: String
    let fill: Color
    let stroke: Color

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .frame(width: 10, height: 10)
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
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
