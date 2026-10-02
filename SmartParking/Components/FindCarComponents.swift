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

struct FloorMapUnavailable: View {
    let parkedCar: ParkedCar?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.neutral)
            VStack(spacing: 8) {
                Text(parkedCar == nil ? "Floor map unavailable" : "Saved GPS position")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.muted)
                if let parkedCar {
                    Text(String(
                        format: "%.5f, %.5f",
                        locale: Locale(identifier: "en_US_POSIX"),
                        parkedCar.latitude,
                        parkedCar.longitude
                    ))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.ink)
                }
            }
        }
        .frame(height: 260)
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
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Palette.subtle)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Palette.neutral)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}