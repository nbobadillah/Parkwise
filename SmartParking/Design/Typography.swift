import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Palette.muted)
    }
}

enum AppFont {
    static let display = Font.system(size: 20, weight: .bold)
    static let heading1 = Font.system(size: 15, weight: .semibold)
    static let heading2 = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 12, weight: .medium)
    static let overline = Font.system(size: 11, weight: .semibold)
    static let button = Font.system(size: 13, weight: .semibold)
    static let monoId = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let monoData = Font.system(size: 12, design: .monospaced)
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = Radius.card

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
    func cardStyle(radius: CGFloat = Radius.card) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
