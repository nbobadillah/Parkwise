import Foundation

actor PhraseInterpreter {
    static let shared = PhraseInterpreter()
    static let maxEntries = 32

    private let cache = PhraseLRU<String, VoiceQuery>(maxEntries: PhraseInterpreter.maxEntries)

    func interpret(_ phrase: String, language: VoiceLanguage) -> VoiceQuery {
        let key = language.rawValue + "|" + VoiceQueryParser.normalized(phrase)
        if let remembered = cache.value(for: key) {
            return remembered
        }
        let query = VoiceQueryParser.interpret(phrase)
        cache.set(query, for: key)
        return query
    }
}
