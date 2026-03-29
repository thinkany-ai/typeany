import Speech
import AVFoundation
import Combine

final class SpeechRecognizer {
    @Published var partialResult: String = ""
    @Published var isAvailable: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var cancellables = Set<AnyCancellable>()
    private var finalCompletion: ((String) -> Void)?

    init() {
        updateLanguage(PreferencesManager.shared.selectedLanguage)
    }

    func updateLanguage(_ language: Language) {
        recognizer = SFSpeechRecognizer(locale: language.locale)
        isAvailable = recognizer?.isAvailable ?? false
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startStreaming(audioBufferSubject: PassthroughSubject<AVAudioPCMBuffer, Never>) {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("[TypeAny] Speech recognizer not available")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.partialResult = result.bestTranscription.formattedString
                }
                if result.isFinal {
                    let finalText = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.finalCompletion?(finalText)
                        self.finalCompletion = nil
                    }
                }
            }
            if let error = error {
                print("[TypeAny] Recognition error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Return whatever partial result we have
                    let text = self.partialResult
                    self.finalCompletion?(text)
                    self.finalCompletion = nil
                }
            }
        }

        // Forward audio buffers to the recognition request
        audioBufferSubject
            .sink { [weak self] buffer in
                self?.recognitionRequest?.append(buffer)
            }
            .store(in: &cancellables)
    }

    func stopStreaming(completion: @escaping (String) -> Void) {
        self.finalCompletion = completion
        cancellables.removeAll()
        recognitionRequest?.endAudio()

        // Timeout: if no final result within 3 seconds, return partial
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.finalCompletion != nil else { return }
            let text = self.partialResult
            self.finalCompletion?(text)
            self.finalCompletion = nil
            self.recognitionTask?.cancel()
        }
    }

    func cancel() {
        cancellables.removeAll()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        finalCompletion = nil
        partialResult = ""
    }
}
