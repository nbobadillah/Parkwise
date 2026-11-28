import Foundation

enum VoiceQueryParser {
    static func interpret(_ phrase: String) -> VoiceQuery {
        let text = normalized(phrase)
        let code = firstMatch(spotCode, in: text)
        let levelMatch = firstMatch(level, in: text)
        let levelNumber = code?[0] ?? levelMatch?[0] ?? levelMatch?[1]
        let zoneLetter = code?[1]?.uppercased() ?? firstMatch(zone, in: text)?[0].flatMap { zoneLetters[$0] }
        let number = code?[2] ?? firstMatch(spotNumber, in: text)?[0]
        let words = text.split(separator: " ").map(String.init)

        var filters: Set<VoiceFilter> = [.available]
        for (filter, stems) in filterStems where words.contains(where: { word in stems.contains { word.hasPrefix($0) } }) {
            filters.insert(filter)
        }

        return VoiceQuery(
            levelCode: levelNumber.map { "P\($0)" },
            zone: zoneLetter,
            spotNumber: zoneLetter == nil ? nil : number.flatMap { Int($0) },
            filters: filters
        )
    }

    static func normalized(_ phrase: String) -> String {
        let plain = String(phrase.lowercased().map { accents[$0] ?? $0 })
        return plain
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { replacements[String($0)] ?? String($0) }
            .joined(separator: " ")
    }

    private static let spotCode = regex(#"\bp ?([1-3]) ?([abc]) ?(\d{1,2})\b"#)

    private static let level = regex(
        #"\b(?:p|pe|piso|nivel|level|floor|planta) ?([1-3])\b|\b([1-3]) ?(?:piso|nivel|level|floor|planta)\b"#
    )

    private static let zone = regex(#"\b(?:zona|zone) (a|b|c|be|ce|bee|see)\b"#)

    private static let spotNumber = regex(
        #"\b(?:puesto|plaza|spot|space|numero|number|zona [a-z]+|zone [a-z]+) (\d{1,2})\b"#
    )

    private static let zoneLetters = [
        "a": "A", "b": "B", "c": "C", "be": "B", "ce": "C", "bee": "B", "see": "C"
    ]

    private static let filterStems: [(VoiceFilter, [String])] = [
        (.electric, ["electr", "charg", "carga", "recarg"]),
        (.accessible, ["accesib", "accessib", "discapac", "disab", "movilidad", "wheelchair"]),
        (.vip, ["vip"])
    ]

    private static let replacements = [
        "ev": "electric",
        "uno": "1", "primer": "1", "primero": "1", "one": "1", "first": "1",
        "dos": "2", "segundo": "2", "two": "2", "second": "2",
        "tres": "3", "tercer": "3", "tercero": "3", "three": "3", "third": "3",
        "cuatro": "4", "four": "4",
        "cinco": "5", "five": "5",
        "seis": "6", "six": "6",
        "siete": "7", "seven": "7",
        "ocho": "8", "eight": "8",
        "nueve": "9", "nine": "9",
        "diez": "10", "ten": "10"
    ]

    private static let accents: [Character: Character] = [
        "á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> [String?]? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}
