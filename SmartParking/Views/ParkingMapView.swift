import SwiftUI

struct ParkingMapView: View {
    @Binding var levelCode: String

    @State private var zones: [ParkingZone] = []
    @State private var selectedSpotID: String?
    @State private var reservedSpotID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottom) {
                grid
                if let spot = selectedSpot {
                    SelectedSpotSheet(
                        spot: spot,
                        isReserved: reservedSpotID == spot.id,
                        onReserve: { reserve(spot.id) },
                        onClose: { selectedSpotID = nil }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .background(Palette.screen)
        .animation(.easeOut(duration: 0.22), value: selectedSpotID)
        .onAppear(perform: loadLevel)
        .onChange(of: levelCode) { loadLevel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Level")
                    Text(ParkingData.level(code: levelCode).shortTitle)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(ParkingData.levels) { level in
                        LevelChip(code: level.code, isSelected: level.code == levelCode) {
                            levelCode = level.code
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                LegendDot(title: "Free", fill: Palette.greenSoft, stroke: Palette.greenInk.opacity(0.35))
                LegendDot(title: "Taken", fill: Palette.neutral, stroke: Palette.line)
                LegendDot(title: "Reserved", fill: Palette.amberSoft, stroke: Palette.amberInk.opacity(0.4))
                LegendDot(title: "You", fill: Palette.accentSoft, stroke: Palette.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Palette.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EntranceBar()
                ForEach(zones) { zone in
                    VStack(alignment: .leading, spacing: 12) {
                        ZoneHeader(name: zone.name)
                        LaneDivider()
                        ForEach(zone.rows) { row in
                            HStack(spacing: 9) {
                                Text("\(row.index)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Palette.muted)
                                    .frame(width: 12, alignment: .leading)
                                ForEach(row.spots) { spot in
                                    SpotCell(spot: spot, isSelected: spot.id == selectedSpotID) {
                                        selectedSpotID = spot.id
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, selectedSpot == nil ? 24 : 190)
        }
    }

    private var selectedSpot: ParkingSpot? {
        guard let selectedSpotID else { return nil }
        for zone in zones {
            for row in zone.rows {
                if let match = row.spots.first(where: { $0.id == selectedSpotID }) {
                    return match
                }
            }
        }
        return nil
    }

    private func loadLevel() {
        let level = ParkingData.level(code: levelCode)
        zones = level.zones
        reservedSpotID = nil
        selectedSpotID = level.recommendedSpot
    }

    private func reserve(_ id: String) {
        for zoneIndex in zones.indices {
            for rowIndex in zones[zoneIndex].rows.indices {
                for spotIndex in zones[zoneIndex].rows[rowIndex].spots.indices where zones[zoneIndex].rows[rowIndex].spots[spotIndex].id == id {
                    zones[zoneIndex].rows[rowIndex].spots[spotIndex].state = .you
                }
            }
        }
        reservedSpotID = id
    }
}

struct SelectedSpotSheet: View {
    let spot: ParkingSpot
    let isReserved: Bool
    let onReserve: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Palette.line)
                .frame(width: 44, height: 4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Selected spot")
                    Text(spot.id)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Walk from entrance")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                    Text("~\(spot.walkMinutes) min")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
            }

            HStack(spacing: 12) {
                Button(action: onReserve) {
                    Text(isReserved ? "Spot reserved" : "Reserve this spot")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isReserved ? Palette.greenInk : Palette.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isReserved)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.neutral)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.card)
                .shadow(color: Palette.ink.opacity(0.12), radius: 18, y: -4)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
