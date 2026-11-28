import Combine
import Foundation
import os

@MainActor
final class VoiceSearchViewModel: ObservableObject {
    enum Status: Equatable {
        case ready
        case listening
        case notUnderstood
        case failed
    }

    enum Outcome: Equatable {
        case phrase(String, VoiceQuery, spoken: Bool)
        case typeInstead(String)
    }

    static let languageKey = "voiceSearch.language"

    private static let signposter = OSSignposter(subsystem: "com.parkwise", category: .pointsOfInterest)
    private static let logger = Logger(subsystem: "com.parkwise", category: "VoiceSearch")

    @Published private(set) var status: Status = .ready
    @Published private(set) var words = ""
    @Published private(set) var heard = VoiceQuery.empty
    @Published private(set) var failure: SpeechFailure?
    @Published private(set) var recent: [RecentSearch] = []
    @Published private(set) var destination: Building?
    @Published private(set) var language: VoiceLanguage
    @Published private(set) var isConnected: Bool
    @Published private(set) var outcome: Outcome?

    private let recognizer: SpeechRecognizing
    private let interpreter: PhraseInterpreter
    private let store: RecentSearchStoring
    private let service: ParkingServicing
    private let networkMonitor: NetworkMonitor
    private let defaults: UserDefaults
    private let destinationID: String?
    private let openReservationLevel: String?
    private let clock: () -> Date

    private var session: Task<Void, Never>?
    private var startedAt: Date?
    private var tracked = false
    private var generation = 0
    private var interpreted = 0
    private var thrownAway = 0
    private var networkSubscription: AnyCancellable?

    init(
        destinationID: String?,
        openReservationLevel: String?,
        service: ParkingServicing,
        networkMonitor: NetworkMonitor,
        recognizer: SpeechRecognizing? = nil,
        interpreter: PhraseInterpreter = .shared,
        store: RecentSearchStoring = RecentVoiceSearchStore.shared,
        defaults: UserDefaults = .standard,
        clock: @escaping () -> Date = Date.init
    ) {
        self.destinationID = destinationID
        self.openReservationLevel = openReservationLevel
        self.service = service
        self.networkMonitor = networkMonitor
        self.recognizer = recognizer ?? SpeechRecognizer()
        self.interpreter = interpreter
        self.store = store
        self.defaults = defaults
        self.clock = clock
        language = defaults.string(forKey: Self.languageKey).flatMap(VoiceLanguage.init(rawValue:)) ?? .spanish
        isConnected = networkMonitor.isConnected

        networkSubscription = networkMonitor.$isConnected
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] connected in
                self?.connectivityChanged(connected)
            }
    }

    var isListening: Bool {
        status == .listening
    }

    var recognizesWithoutInternet: Bool {
        recognizer.recognizesWithoutInternet(language)
    }

    var tryPhrases: [String] {
        language.examples
    }

    func open() async {
        outcome = nil
        listen()
        async let recentSearches: Void = loadRecent()
        async let building: Void = loadDestination()
        _ = await (recentSearches, building)
    }

    func close() {
        endSession()
    }

    func listen() {
        endSession()
        status = .listening
        words = ""
        heard = .empty
        failure = nil
        startedAt = clock()
        tracked = false
        interpreted = 0
        thrownAway = 0

        let stream = recognizer.listen(language: language, offline: !networkMonitor.isConnected)
        session = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled else { return }
                await self?.receive(update)
            }
        }
    }

    func stopListening() {
        recognizer.stop()
    }

    func choose(_ value: VoiceLanguage) {
        guard value != language else { return }
        language = value
        defaults.set(value.rawValue, forKey: Self.languageKey)
        listen()
    }

    func repeatSearch(_ search: RecentSearch) async {
        endSession()
        let query = await interpreter.interpret(search.phrase, language: language)
        remember(search.phrase)
        complete(.phrase(search.phrase, query, spoken: false))
    }

    func typeInstead() {
        let typed = words
        endSession()
        complete(.typeInstead(typed))
    }

    private func receive(_ update: SpeechUpdate) async {
        switch update {
        case .heard(let phrase, isFinal: true):
            await finish(phrase)
        case .heard(let phrase, isFinal: false):
            words = phrase
            Task { [weak self] in
                await self?.interpretPreview(phrase)
            }
        case .failed(let reason):
            fail(reason)
        }
    }

    private func interpretPreview(_ phrase: String) async {
        generation += 1
        let current = generation
        interpreted += 1
        let query = await measuredInterpretation(of: phrase)
        guard current == generation, isListening else {
            thrownAway += 1
            return
        }
        heard = query
    }

    private func finish(_ phrase: String) async {
        generation += 1
        let current = generation
        words = phrase
        track("ok")
        let query = await measuredInterpretation(of: phrase)
        Self.logger.info("voice previews: \(self.interpreted) interpreted, \(self.thrownAway) thrown away")
        guard current == generation else { return }
        heard = query
        guard query.understood else {
            status = .notUnderstood
            return
        }
        remember(phrase)
        complete(.phrase(phrase, query, spoken: true))
    }

    private func measuredInterpretation(of phrase: String) async -> VoiceQuery {
        let state = Self.signposter.beginInterval("interpret")
        let query = await interpreter.interpret(phrase, language: language)
        Self.signposter.endInterval("interpret", state)
        return query
    }

    private func fail(_ reason: SpeechFailure) {
        generation += 1
        track(reason.outcome)
        failure = reason
        status = .failed
    }

    private func complete(_ result: Outcome) {
        status = .ready
        outcome = result
    }

    private func track(_ result: String) {
        guard !tracked, let startedAt else { return }
        tracked = true
        let latency = Int(clock().timeIntervalSince(startedAt) * 1000)
        TelemetryService.shared.trackVoiceRecognition(outcome: result, latencyMs: latency, level: openReservationLevel)
    }

    private func remember(_ phrase: String) {
        let store = store
        let date = clock()
        Task { [weak self] in
            try? await store.save(phrase, at: date)
            await self?.loadRecent()
        }
    }

    private func loadRecent() async {
        if let saved = try? await store.recent() {
            recent = saved
        }
    }

    private func loadDestination() async {
        guard let destinationID else { return }
        guard let buildings = try? await service.buildings().value else { return }
        destination = buildings.first { $0.id == destinationID } ?? destination
    }

    private func connectivityChanged(_ connected: Bool) {
        isConnected = connected
        guard connected, destination == nil else { return }
        Task { [weak self] in
            await self?.loadDestination()
        }
    }

    private func endSession() {
        generation += 1
        session?.cancel()
        session = nil
        recognizer.cancel()
        if status == .listening {
            status = .ready
        }
    }
}
