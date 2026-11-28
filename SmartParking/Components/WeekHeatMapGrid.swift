import SwiftUI

struct WeekHeatMapGrid: View, Equatable {
    let hours: [Int]
    let rows: [HeatRow]

    nonisolated static func == (lhs: WeekHeatMapGrid, rhs: WeekHeatMapGrid) -> Bool {
        lhs.hours == rhs.hours && lhs.rows == rhs.rows
    }

    var body: some View {
        VStack(spacing: WeekHeatStyle.spacing) {
            HStack(spacing: WeekHeatStyle.spacing) {
                Color.clear
                    .frame(width: WeekHeatStyle.labelWidth, height: 1)

                ForEach(hours, id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(AppFont.monoData)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(rows) { row in
                HStack(spacing: WeekHeatStyle.spacing) {
                    Text(row.label)
                        .font(AppFont.body)
                        .foregroundStyle(Palette.ink)
                        .frame(width: WeekHeatStyle.labelWidth, alignment: .leading)

                    if row.isSaved {
                        ForEach(row.cells) { cell in
                            WeekHeatCellView(cell: cell)
                        }
                    } else {
                        NotSavedStrip()
                    }
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        guard let first = hours.first else { return "" }
        return (hour - first) % 2 == 0 ? "\(hour)" : ""
    }
}
