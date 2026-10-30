import SwiftUI

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

enum Palette {
    static let screen = Color(hex: 0xF4F5F7)
    static let card = Color.white
    static let ink = Color(hex: 0x172B4D)
    static let muted = Color(hex: 0x6B778C)
    static let line = Color(hex: 0xEBECF0)
    static let accent = Color(hex: 0x0052CC)
    static let accentHover = Color(hex: 0x0065FF)
    static let accentSoft = Color(hex: 0xDEEBFF)
    static let greenInk = Color(hex: 0x36B37E)
    static let greenSoft = Color(hex: 0xE3FCEF)
    static let amberInk = Color(hex: 0xFFAB00)
    static let amberSoft = Color(hex: 0xFFF7D6)
    static let amberBorder = Color(hex: 0xFFE380)
    static let amberText = Color(hex: 0xFF8B00)
    static let redInk = Color(hex: 0xDE350B)
    static let redSoft = Color(hex: 0xFFEBE6)
    static let alertRed = Color(hex: 0xDE350B)
    static let alertSoft = Color(hex: 0xFFEBE6)
    static let alertText = Color(hex: 0xDE350B)
    static let neutral = Color(hex: 0xF4F5F7)
    static let slate = Color(hex: 0x6B778C)
    static let violetSoft = Color(hex: 0xEAE6FF)
    static let violetInk = Color(hex: 0x6554C0)
    static let purple = Color(hex: 0x6554C0)
    static let buttonGray = Color(hex: 0xEBECF0)
    static let subtle = Color(hex: 0x6B778C)
    static let border = Color(hex: 0xEBECF0)
}

enum Radius {
    static let badge: CGFloat = 3
    static let small: CGFloat = 6
    static let card: CGFloat = 8
}

struct Tint {
    let soft: Color
    let strong: Color
}
