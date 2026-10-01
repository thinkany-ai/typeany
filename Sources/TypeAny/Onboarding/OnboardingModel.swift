import AVFoundation
import Cocoa
import Speech

/// Drives the onboarding flow. Runs in its own process (`TypeAny --onboarding`)
/// so its practice text fields are a real client of the TypeAny input method.
@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, permissions, inputMethod, voice, translate

        var title: String {
            switch self {
            case .welcome: return "欢迎"
            case .permissions: return "授权"
            case .inputMethod: return "输入法"
            case .voice: return "语音"
            case .translate: return "翻译"
            }
        }
    }

    @Published var step: Step = .welcome

    @Published private(set) var micGranted = false
    @Published private(set) var speechGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var imeEnabled = false
    @Published private(set) var imeSelected = false

    // Practice fields
    @Published var voiceText = ""
    @Published var translateText = ""

    @Published var apiKey: String {
        didSet { prefs.llmAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    let triggerKeyLabel: String

    private let prefs = PreferencesManager.shared
    private var timer: Timer?

    init() {
        apiKey = PreferencesManager.shared.llmAPIKey
        triggerKeyLabel = PreferencesManager.shared.triggerKeyLabel
    }

    var allPermissionsGranted: Bool { micGranted && speechGranted && accessibilityGranted }

    /// The reply contains English, i.e. the translation was committed
    var translateSucceeded: Bool {
        translateText.unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.isASCII }.count >= 3
    }

    func start() {
        refresh()
        // Permissions and input sources change in System Settings; poll while open
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        let ime = InputSourceRegistrar.status()
        imeEnabled = ime.enabled
        imeSelected = ime.selected
    }

    // MARK: - Navigation

    func next() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish()
        }
    }

    func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    func finish() {
        prefs.onboardingCompleted = true
        NSApp.terminate(nil)
    }

    // MARK: - Actions

    func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in self.refresh() }
            }
        } else {
            openPrivacyPane("Privacy_Microphone")
        }
    }

    func requestSpeech() {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { _ in
                Task { @MainActor in self.refresh() }
            }
        } else {
            openPrivacyPane("Privacy_SpeechRecognition")
        }
    }

    func requestAccessibility() {
        // Adds TypeAny to the Accessibility list so the user only has to flip the switch
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacyPane("Privacy_Accessibility")
    }

    func enableInputMethod() {
        InputSourceRegistrar.install(bundleURL: Bundle.main.bundleURL)
        refresh()
    }

    func selectInputMethod() {
        InputSourceRegistrar.select()
        refresh()
    }

    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
