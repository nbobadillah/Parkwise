import AVFoundation
import Foundation
import Speech

enum SpeechFailure: Equatable, Sendable {
    case noMatch
    case noPermission
    case network
    case unavailable
    case other

    var outcome: String {
        switch self {
        case .noMatch:
            return "no_match"
        case .noPermission:
            return "no_permission"
        case .network:
            return "offline"
        case .unavailable, .other:
            return "error"
        }
    }
}

enum SpeechUpdate: Equatable, Sendable {
    case heard(String, isFinal: Bool)
    case failed(SpeechFailure)
}

@MainActor
protocol SpeechRecognizing: AnyObject {
    func listen(language: VoiceLanguage, offline: Bool) -> AsyncStream<SpeechUpdate>
    func stop()
    func cancel()
    func recognizesWithoutInternet(_ language: VoiceLanguage) -> Bool
}

@MainActor
final class SpeechRecognizer: SpeechRecognizing {
    static let listenFor: Duration = .seconds(15)
    static let pauseFor: Duration = .seconds(3)
    static let stopGrace: Duration = .seconds(2)

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<SpeechUpdate>.Continuation?
    private var session = 0
    private var heard = ""
    private var silenceTimer: Task<Void, Never>?
    private var limitTimer: Task<Void, Never>?
    private var tapInstalled = false

    func recognizesWithoutInternet(_ language: VoiceLanguage) -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: language.localeID))?.supportsOnDeviceRecognition ?? false
    }

    func listen(language: VoiceLanguage, offline: Bool) -> AsyncStream<SpeechUpdate> {
        cancel()
        session += 1
        let current = session
        heard = ""
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechUpdate.self)
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.end(session: current)
            }
        }
        Task {
            await start(language: language, offline: offline, session: current)
        }
        return stream
    }

    func stop() {
        guard continuation != nil else { return }
        silenceTimer?.cancel()
        limitTimer?.cancel()
        stopAudio()
        request?.endAudio()
        let current = session
        limitTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.stopGrace)
            guard !Task.isCancelled else { return }
            self?.finishWithWhatWasHeard(session: current)
        }
    }

    func cancel() {
        end(session: session)
    }

    private func start(language: VoiceLanguage, offline: Bool, session current: Int) async {
        guard await Self.hasPermission() else {
            finish(.failed(.noPermission), session: current)
            return
        }
        guard current == session else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.localeID)) else {
            finish(.failed(.unavailable), session: current)
            return
        }
        let onDevice = offline && recognizer.supportsOnDeviceRecognition
        if offline && !onDevice {
            finish(.failed(.network), session: current)
            return
        }
        guard recognizer.isAvailable || onDevice else {
            finish(.failed(.unavailable), session: current)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.requiresOnDeviceRecognition = onDevice

        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true, options: .notifyOthersOnDeactivation)
            Self.installTap(on: engine.inputNode, feeding: request)
            tapInstalled = true
            engine.prepare()
            try engine.start()
        } catch {
            finish(.failed(.unavailable), session: current)
            return
        }

        self.recognizer = recognizer
        self.request = request
        task = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.resultHandler { [weak self] words, isFinal, failed in
                self?.handle(words: words, isFinal: isFinal, failed: failed, session: current)
            }
        )
        restartSilenceTimer(session: current)
        limitTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.listenFor)
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private func handle(words: String?, isFinal: Bool, failed: Bool, session current: Int) {
        guard current == session, continuation != nil else { return }
        if let words, !words.isEmpty {
            heard = words
            if isFinal {
                finish(.heard(words, isFinal: true), session: current)
                return
            }
            continuation?.yield(.heard(words, isFinal: false))
            restartSilenceTimer(session: current)
        }
        if failed || isFinal {
            finishWithWhatWasHeard(session: current)
        }
    }

    private func finishWithWhatWasHeard(session current: Int) {
        guard current == session else { return }
        if heard.isEmpty {
            finish(.failed(.noMatch), session: current)
        } else {
            finish(.heard(heard, isFinal: true), session: current)
        }
    }

    private func restartSilenceTimer(session current: Int) {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.pauseFor)
            guard !Task.isCancelled, self?.session == current else { return }
            self?.stop()
        }
    }

    private func finish(_ update: SpeechUpdate, session current: Int) {
        guard current == session, let continuation else { return }
        continuation.yield(update)
        end(session: current)
    }

    private func end(session current: Int) {
        guard current == session else { return }
        let continuation = self.continuation
        self.continuation = nil
        silenceTimer?.cancel()
        limitTimer?.cancel()
        silenceTimer = nil
        limitTimer = nil
        stopAudio()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        continuation?.finish()
    }

    private func stopAudio() {
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private static func hasPermission() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    nonisolated private static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func resultHandler(
        _ deliver: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let words = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                deliver(words, isFinal, failed)
            }
        }
    }
}
