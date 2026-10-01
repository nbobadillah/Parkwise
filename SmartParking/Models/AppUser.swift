import Foundation

struct AppUser: Identifiable, Equatable, Codable {
    let id: String
    let email: String
    let displayName: String

    var initials: String {
        let letters = displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        return letters.isEmpty ? String(email.prefix(1)).uppercased() : String(letters).uppercased()
    }
}
