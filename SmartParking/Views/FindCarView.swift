import SwiftUI

struct FindCarView: View {
    @State private var mode: RouteMode = .direct

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    floorCard
                    modePicker
                    steps
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .background(Palette.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find my car")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)
            Text(FindCarData.parkedAt)
                .font(.system(size: 13))
                .foregroundStyle(Palette.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 17)
        // En esta pantalla el blanco NO invade el área de la barra de estado
        .background(Palette.card, ignoresSafeAreaEdges: [])
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            SummaryTile(
                label: "Spot",
                value: FindCarData.spotCode,
                caption: FindCarData.levelTitle,
                valueColor: Palette.accent,
                monospaced: true
            )
            SummaryTile(
                label: "Walk",
                value: FindCarData.walkTime,
                caption: FindCarData.entrance,
                valueColor: Palette.ink
            )
        }
    }

    private var floorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            CaptionLabel(text: "\(FindCarData.levelTitle) — Floor view")
            FloorMap(
                rows: FindCarData.floor,
                spotCode: FindCarData.spotCode,
                distance: FindCarData.distance
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 8)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(RouteMode.allCases) { item in
                RouteModeButton(title: item.title, isSelected: mode == item) {
                    mode = item
                }
            }
        }
    }

    private var steps: some View {
        VStack(spacing: 8) {
            ForEach(FindCarData.steps) { step in
                RouteStepRow(step: step)
            }
        }
    }
}