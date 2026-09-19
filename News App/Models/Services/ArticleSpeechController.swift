import AVFoundation
import Combine

/// Reads an article aloud with `AVSpeechSynthesizer`.
///
/// One instance is owned by each detail screen (`@StateObject` in
/// `ArticleDetailView`), so navigating to a new story always starts from a
/// clean, stopped synthesizer instead of layering speech from an old screen.
@MainActor
final class ArticleSpeechController: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Starts reading `title` and `body` aloud, or stops if already speaking.
    func toggle(title: String, body: String) {
        if isSpeaking {
            stop()
            return
        }

        let text = [title, body].filter { !$0.isEmpty }.joined(separator: ". ")
        guard !text.isEmpty else { return }

        // `.spokenAudio` lets this duck music instead of fighting with it — the
        // same behaviour Podcasts and News use for read-aloud content.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Stops playback immediately. Safe to call even when nothing is speaking,
    /// which is why the article screen can call it unconditionally on disappear.
    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func markStopped() {
        isSpeaking = false
    }
}

extension ArticleSpeechController: AVSpeechSynthesizerDelegate {
    /// `AVSpeechSynthesizerDelegate` callbacks are not guaranteed to land on the
    /// main thread, so each one hops onto the main actor before touching the
    /// `@Published` property views observe.
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.markStopped() }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.markStopped() }
    }
}
