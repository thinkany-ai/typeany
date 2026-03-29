import Cocoa
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let hotkeyMonitor = HotkeyMonitor()
    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let whisperLocal = WhisperLocalEngine()
    private let whisperAPI = WhisperAPIEngine()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()
    private let floatingPanel = FloatingPanelController()
    private let appState = AppState.shared
    private var cancellables = Set<AnyCancellable>()

    // VAD state
    private var vadSilenceStart: Date?
    private var vadTriggered = false
    private let vadSilenceThreshold: Float = 0.015
    private let vadSilenceDuration: TimeInterval = 1.5

    // Track whether we've seen speech (for VAD with Whisper engines)
    private var hasDetectedSpeech = false

    private var currentEngine: ASREngineType {
        PreferencesManager.shared.asrEngine
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        menuBar.setup()
        menuBar.onQuit = {
            NSApp.terminate(nil)
        }
        menuBar.onHistoryInject = { [weak self] text in
            self?.injectHistoryItem(text)
        }

        // Request permissions
        _ = Permissions.checkAccessibility()
        Permissions.requestMicrophone { granted in
            if granted {
                Permissions.requestSpeechRecognition { _ in }
            }
        }

        // Setup hotkey callbacks
        hotkeyMonitor.onKeyDown = { [weak self] in
            self?.startRecording()
        }
        hotkeyMonitor.onKeyUp = { [weak self] in
            self?.stopRecording()
        }
        configureAndStartHotkey()

        // Allow menu bar to trigger hotkey reconfiguration
        menuBar.onTriggerKeyChanged = { [weak self] in
            self?.configureAndStartHotkey()
        }

        // Observe language changes
        appState.$selectedLanguage
            .sink { [weak self] lang in
                self?.speechRecognizer.updateLanguage(lang)
            }
            .store(in: &cancellables)

        // Forward audio levels to app state + VAD check
        audioRecorder.audioLevelSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                self.appState.audioLevel = level
                self.checkVAD(level: level)
            }
            .store(in: &cancellables)

        // Forward partial transcription to app state (Apple ASR only)
        speechRecognizer.$partialResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                if self.appState.recordingState == .recording && self.currentEngine == .apple {
                    self.appState.currentTranscription = text
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Hotkey Configuration

    private func configureAndStartHotkey() {
        let prefs = PreferencesManager.shared
        hotkeyMonitor.configure(
            triggerKey: prefs.triggerKey,
            customCombo: prefs.customKeyCombo
        )
        hotkeyMonitor.start()
    }

    // MARK: - VAD (Voice Activity Detection)

    private func checkVAD(level: Float) {
        guard PreferencesManager.shared.vadEnabled,
              appState.recordingState == .recording,
              !vadTriggered else { return }

        // Track speech detection for Whisper engines
        if level > vadSilenceThreshold * 2 {
            hasDetectedSpeech = true
        }

        // For Apple ASR, check transcription; for Whisper engines, check if speech was detected
        let hasSpeechActivity: Bool
        if currentEngine == .apple {
            hasSpeechActivity = !appState.currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            hasSpeechActivity = hasDetectedSpeech
        }

        if level < vadSilenceThreshold && hasSpeechActivity {
            if vadSilenceStart == nil {
                vadSilenceStart = Date()
            } else if let start = vadSilenceStart,
                      Date().timeIntervalSince(start) >= vadSilenceDuration {
                // Silence exceeded threshold - auto stop
                vadTriggered = true
                floatingPanel.showVADHint()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.stopRecording()
                }
            } else if let start = vadSilenceStart,
                      Date().timeIntervalSince(start) >= vadSilenceDuration - 0.5 {
                // Near threshold - blink hint
                floatingPanel.showVADHint()
            }
        } else {
            vadSilenceStart = nil
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard appState.recordingState == .idle else { return }

        // Reset VAD state
        vadSilenceStart = nil
        vadTriggered = false
        hasDetectedSpeech = false

        appState.recordingState = .recording
        appState.currentTranscription = ""

        menuBar.updateIcon(recording: true)
        floatingPanel.show()

        let needsWAV = currentEngine != .apple

        // Start audio recording
        audioRecorder.startRecording(recordWAV: needsWAV)

        // Only start streaming speech recognition for Apple ASR
        if currentEngine == .apple {
            speechRecognizer.startStreaming(audioBufferSubject: audioRecorder.audioBufferSubject)
        }
    }

    private func stopRecording() {
        guard appState.recordingState == .recording else { return }

        appState.recordingState = .processing
        menuBar.updateIcon(recording: false)

        // Stop audio recording, get WAV file URL if recorded
        let wavURL = audioRecorder.stopRecording()

        switch currentEngine {
        case .apple:
            stopWithAppleASR()
        case .localWhisper:
            stopWithWhisperLocal(wavURL: wavURL)
        case .whisperAPI:
            stopWithWhisperAPI(wavURL: wavURL)
        }
    }

    // MARK: - Apple ASR

    private func stopWithAppleASR() {
        speechRecognizer.stopStreaming { [weak self] finalText in
            guard let self = self else { return }
            self.processTranscription(finalText)
        }
    }

    // MARK: - Local Whisper

    private func stopWithWhisperLocal(wavURL: URL?) {
        guard let wavURL = wavURL else {
            print("[TypeAny] No WAV file for local Whisper")
            cleanupAfterFailure()
            return
        }

        appState.recordingState = .transcribing
        floatingPanel.showTranscribing()

        let lang = appState.selectedLanguage.rawValue

        Task {
            do {
                let text = try await whisperLocal.transcribe(audioFile: wavURL, language: lang)
                await MainActor.run {
                    self.processTranscription(text)
                }
            } catch {
                print("[TypeAny] Local Whisper error: \(error)")
                await MainActor.run {
                    self.cleanupAfterFailure()
                }
            }
            try? FileManager.default.removeItem(at: wavURL)
        }
    }

    // MARK: - Whisper API

    private func stopWithWhisperAPI(wavURL: URL?) {
        guard let wavURL = wavURL else {
            print("[TypeAny] No WAV file for Whisper API")
            cleanupAfterFailure()
            return
        }

        appState.recordingState = .transcribing
        floatingPanel.showTranscribing()

        let lang = appState.selectedLanguage.rawValue

        Task {
            do {
                let text = try await whisperAPI.transcribe(audioFile: wavURL, language: lang)
                await MainActor.run {
                    self.processTranscription(text)
                }
            } catch {
                print("[TypeAny] Whisper API error: \(error)")
                await MainActor.run {
                    self.cleanupAfterFailure()
                }
            }
            try? FileManager.default.removeItem(at: wavURL)
        }
    }

    // MARK: - Common Processing

    private func processTranscription(_ finalText: String) {
        // Apply hot word replacements (works even without LLM)
        let hotWordCorrected = HotWordsManager.shared.applyReplacements(finalText)

        let prefs = PreferencesManager.shared
        if prefs.llmEnabled && prefs.isLLMConfigured && !hotWordCorrected.isEmpty {
            appState.recordingState = .refining
            appState.currentTranscription = hotWordCorrected
            floatingPanel.showRefining()

            Task {
                let refined: String
                do {
                    refined = try await llmRefiner.refine(text: hotWordCorrected)
                } catch {
                    print("[TypeAny] LLM refinement failed: \(error)")
                    refined = hotWordCorrected
                }

                await MainActor.run {
                    self.appState.currentTranscription = refined
                    self.injectAndCleanup(text: refined)
                }
            }
        } else {
            injectAndCleanup(text: hotWordCorrected)
        }
    }

    private func injectAndCleanup(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cleanupAfterFailure()
            return
        }

        appState.recordingState = .injecting

        // Small delay to let the floating panel update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.textInjector.inject(text: text)

            // Save to history
            PreferencesManager.shared.addToHistory(text)
            self.menuBar.rebuildMenu()

            // Show success feedback
            self.appState.recordingState = .success
            self.floatingPanel.showSuccess()

            // Hide panel after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.floatingPanel.hide()
                self.appState.recordingState = .idle
                self.appState.currentTranscription = ""
                self.speechRecognizer.cancel()
            }
        }
    }

    private func cleanupAfterFailure() {
        floatingPanel.hide()
        appState.recordingState = .idle
        appState.currentTranscription = ""
        speechRecognizer.cancel()
    }

    // MARK: - History Re-injection

    private func injectHistoryItem(_ text: String) {
        guard appState.recordingState == .idle else { return }
        textInjector.inject(text: text)
    }
}
