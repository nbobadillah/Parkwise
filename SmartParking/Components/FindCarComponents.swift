import SwiftUI

struct CaptionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.overline)
            .tracking(0.6)
            .foregroundStyle(Palette.muted)
    }
}

struct SummaryTile: View {
    let label: String
    let value: String
    let caption: String
    let valueColor: Color
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CaptionLabel(text: label)
            Text(value)
                .font(.system(size: 24, weight: monospaced ? .medium : .bold, design: monospaced ? .monospaced : .default))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(AppFont.caption)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct FindCarFloorMap: View {
    let zones: [ParkingZone]
    let selectedSpotID: String?
    let errorMessage: String?
    let isLoading: Bool

    var body: some View {
        Group {
            if let errorMessage {
                AuthBanner(message: errorMessage, isError: true)
            } else if zones.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if zones.isEmpty {
                Text("Parking layout unavailable")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        EntranceBar()
                        ForEach(zones) { zone in
                            VStack(alignment: .leading, spacing: 12) {
                                ZoneHeader(name: zone.name)
                                LaneDivider()
                                ForEach(zone.rows) { row in
                                    SpotRow(row: row, selectedSpotID: selectedSpotID) { _ in }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 260)
            }
        }
    }
}

struct RouteStepRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Palette.accentSoft)
                )

            Text(text)
                .font(AppFont.body)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
    }
}