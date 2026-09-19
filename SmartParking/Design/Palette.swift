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
    static let ink = Color(hex: 0x111C33)
    static let muted = Color(hex: 0x8A94A6)
    static let line = Color(hex: 0xE5E8EE)
    static let accent = Color(hex: 0x1B41CC)
    static let accentSoft = Color(hex: 0xEBF0FE)
    static let greenInk = Color(hex: 0x14804A)
    static let greenSoft = Color(hex: 0xE3F6EA)
    static let amberInk = Color(hex: 0xC2780F)
    static let amberSoft = Color(hex: 0xFDF2D6)
    static let redInk = Color(hex: 0xC63A20)
    static let redSoft = Color(hex: 0xFAE4DE)
    static let neutral = Color(hex: 0xF1F3F7)
    static let slate = Color(hex: 0x98A2B3)
    static let violetSoft = Color(hex: 0xEFEBFD)
    static let violetInk = Color(hex: 0x5B3BD1)
    static let subtle = Color(hex: 0x667085)
    static let border = Color(hex: 0xD9DDE4) 
}

struct Tint {
    let soft: Color
    let strong: Color
}
