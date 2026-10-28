import Foundation

struct PasswordRule: Identifiable {
    let id: String
    let title: String
    let isMet: Bool
}

enum AuthValidation {
    static let maxNameLength = 30
    static let maxEmailLength = 100
    static let minPasswordLength = 8
    static let maxPasswordLength = 64
    static let invalidNameMessage = "Enter a valid name."

    static let emailProviders = [
        "gmail.com",
        "outlook.com",
        "hotmail.com",
        "live.com",
        "yahoo.com",
        "icloud.com",
        "me.com",
        "proton.me",
        "protonmail.com",
        "uniandes.edu.co"
    ]

    private static let nameCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: " '-."))

    static func nameRejection(_ name: String) -> String? {
        if name.count > maxNameLength { return "Names can have up to \(maxNameLength) characters." }
        if name.unicodeScalars.contains(where: { !nameCharacters.contains($0) }) { return invalidNameMessage }
        if hasRepeatedRun(name.lowercased(), length: 3) { return invalidNameMessage }
        if name.contains("  ") { return invalidNameMessage }
        return nil
    }

    static func cleanEmail(_ email: String) -> String {
        String(email.lowercased().filter { !$0.isWhitespace }.prefix(maxEmailLength))
    }

    static func cleanPassword(_ password: String) -> String {
        String(password.prefix(maxPasswordLength))
    }

    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let letters = trimmed.filter(\.isLetter).count
        return nameRejection(trimmed) == nil && letters >= 2 && trimmed.first?.isLetter == true
    }

    static func isValidEmailFormat(_ email: String) -> Bool {
        email.count <= maxEmailLength
            && email.range(of: #"^[a-z0-9]([a-z0-9._%+-]*[a-z0-9])?@[a-z0-9-]+(\.[a-z0-9-]+)+$"#, options: .regularExpression) != nil
            && !email.contains("..")
    }

    static func isRealProvider(_ email: String) -> Bool {
        guard let domain = email.split(separator: "@").last.map(String.init) else { return false }
        return emailProviders.contains(domain)
    }

    static func emailError(_ email: String) -> String? {
        guard let at = email.firstIndex(of: "@") else { return nil }
        let domain = email[email.index(after: at)...]
        guard domain.contains(".") else { return nil }
        if !isValidEmailFormat(email) { return "Enter a valid email." }
        if !isRealProvider(email) { return "Use a real email provider such as Gmail, Outlook, iCloud, Yahoo or Uniandes." }
        return nil
    }

    static func emailSuggestions(_ email: String) -> [String] {
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard let local = parts.first, !local.isEmpty else { return [] }
        let typedDomain = parts.count > 1 ? String(parts[1]) : ""
        guard !emailProviders.contains(typedDomain) else { return [] }
        return emailProviders
            .filter { typedDomain.isEmpty || $0.hasPrefix(typedDomain) }
            .prefix(4)
            .map { "\(local)@\($0)" }
    }

    static func passwordRules(_ password: String) -> [PasswordRule] {
        [
            PasswordRule(id: "length", title: "\(minPasswordLength) to \(maxPasswordLength) characters", isMet: (minPasswordLength...maxPasswordLength).contains(password.count)),
            PasswordRule(id: "upper", title: "One uppercase letter", isMet: password.contains(where: \.isUppercase)),
            PasswordRule(id: "lower", title: "One lowercase letter", isMet: password.contains(where: \.isLowercase)),
            PasswordRule(id: "number", title: "One number", isMet: password.contains(where: \.isNumber)),
            PasswordRule(id: "symbol", title: "One symbol (!@#$%…)", isMet: password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }),
            PasswordRule(id: "spaces", title: "No spaces", isMet: !password.isEmpty && !password.contains(where: \.isWhitespace))
        ]
    }

    static func isStrongPassword(_ password: String) -> Bool {
        passwordRules(password).allSatisfy(\.isMet)
    }

    private static func hasRepeatedRun(_ text: String, length: Int) -> Bool {
        var previous: Character?
        var run = 0
        for character in text where character != " " {
            run = character == previous ? run + 1 : 1
            previous = character
            if run >= length { return true }
        }
        return false
    }
}
