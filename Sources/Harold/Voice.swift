import AVFoundation
import Speech
import SwiftUI

@MainActor
final class Voice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var listening = false
    @Published private(set) var preparing = false
    @Published private(set) var speaking = false
    @Published var error: String?

    private let speaker = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var utterance: AVSpeechUtterance?
    private var sessionID = UUID()

    override init() {
        super.init()
        speaker.delegate = self
    }

    func toggleSpeech(_ text: String) {
        if speaking {
            stopSpeech()
            return
        }
        guard !text.isEmpty else { return }
        stopListening()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        self.utterance = utterance
        speaker.speak(utterance)
        speaking = true
    }

    func stopSpeech() {
        utterance = nil
        speaker.stopSpeaking(at: .immediate)
        speaking = false
    }

    func toggleListening(update: @escaping (String) -> Void) {
        if listening {
            stopListening()
            return
        }
        guard !preparing else { return }
        error = nil
        stopSpeech()
        preparing = true
        let id = UUID()
        sessionID = id

        Task {
            let microphone = await AVCaptureDevice.requestAccess(for: .audio)
            guard sessionID == id else { return }
            guard microphone else {
                preparing = false
                error = "Allow microphone access in System Settings to use dictation."
                return
            }
            let permission = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard sessionID == id else { return }
            preparing = false
            guard permission == .authorized else {
                error = "Allow speech recognition in System Settings to use dictation."
                return
            }
            startListening(id: id, update: update)
        }
    }

    func stopListening() {
        sessionID = UUID()
        preparing = false
        if request != nil {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            request?.endAudio()
        }
        task?.cancel()
        task = nil
        request = nil
        listening = false
    }

    private func startListening(id: UUID, update: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognition is unavailable. You can still type your question."
            return
        }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            error = "Harold couldn’t find an active microphone."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stopListening()
            self.error = "Harold couldn’t start your microphone."
            return
        }
        listening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, failure in
            let transcript = result?.bestTranscription.formattedString
            let finished = result?.isFinal == true
            Task { @MainActor in
                guard let self, self.sessionID == id else { return }
                if let transcript { update(transcript) }
                if finished || failure != nil {
                    self.stopListening()
                    if failure != nil {
                        self.error = "Dictation ended. You can edit or submit your question."
                    }
                }
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            if let current = self.utterance, ObjectIdentifier(current) == id {
                self.utterance = nil
                self.speaking = false
            }
        }
    }
}
