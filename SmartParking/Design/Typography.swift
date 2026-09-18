import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Palette.muted)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
