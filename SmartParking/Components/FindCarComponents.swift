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