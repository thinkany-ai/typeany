import Foundation

final class PreferencesManager {
    static let shared = PreferencesManager()
    // Per-variant suite (AppVariant): dev and release builds keep separate settings.
    private let defaults = UserDefaults(suiteName: AppVariant.defaultsSuite) ?? .standard

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Constants.Defaults.selectedLanguage: Language.zhCN.rawValue,
            Constants.Defaults.llmEnabled: false,
            Constants.Defaults.llmAPIBaseURL: "https://api.openai.com/v1",
            Constants.Defaults.llmAPIKey: "",
            Constants.Defaults.llmModel: "gpt-4o-mini",
            Constants.Defaults.vadEnabled: true,
            Constants.Defaults.liveTypingEnabled: true,
            Constants.Defaults.predictionEnabled: true,
            Constants.Defaults.autoSpacingEnabled: true,
            Constants.Defaults.asrEngine: ASREngineType.apple.rawValue,
            Constants.Defaults.whisperModelPath: WhisperLocalEngine.defaultModelPath,
            Constants.Defaults.whisperAPIBaseURL: "",
            Constants.Defaults.whisperAPIKey: "",
            Constants.Defaults.whisperAPIModel: "whisper-1",
            Constants.Defaults.triggerKey: TriggerKey.fn.rawValue,
        ])
    }

    var selectedLanguage: Language {
        get {
            guard let raw = defaults.string(forKey: Constants.Defaults.selectedLanguage),
                  let lang = Language(rawValue: raw) else { return .zhCN }
            return lang
        }
        set { defaults.set(newValue.rawValue, forKey: Constants.Defaults.selectedLanguage) }
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.llmEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.llmEnabled) }
    }

    var llmAPIBaseURL: String {
        get { defaults.string(forKey: Constants.Defaults.llmAPIBaseURL) ?? "https://api.openai.com/v1" }
        set { defaults.set(newValue, forKey: Constants.Defaults.llmAPIBaseURL) }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: Constants.Defaults.llmAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.llmAPIKey) }
    }

    var llmModel: String {
        get { defaults.string(forKey: Constants.Defaults.llmModel) ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: Constants.Defaults.llmModel) }
    }

    var isLLMConfigured: Bool {
        !llmAPIBaseURL.isEmpty && !llmAPIKey.isEmpty && !llmModel.isEmpty
    }

    // MARK: - ASR Engine

    var asrEngine: ASREngineType {
        get {
            guard let raw = defaults.string(forKey: Constants.Defaults.asrEngine),
                  let engine = ASREngineType(rawValue: raw) else { return .apple }
            return engine
        }
        set { defaults.set(newValue.rawValue, forKey: Constants.Defaults.asrEngine) }
    }

    var whisperModelPath: String {
        get { defaults.string(forKey: Constants.Defaults.whisperModelPath) ?? WhisperLocalEngine.defaultModelPath }
        set { defaults.set(newValue, forKey: Constants.Defaults.whisperModelPath) }
    }

    var whisperAPIBaseURL: String {
        get { defaults.string(forKey: Constants.Defaults.whisperAPIBaseURL) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.whisperAPIBaseURL) }
    }

    var whisperAPIKey: String {
        get { defaults.string(forKey: Constants.Defaults.whisperAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.whisperAPIKey) }
    }

    var whisperAPIModel: String {
        get { defaults.string(forKey: Constants.Defaults.whisperAPIModel) ?? "whisper-1" }
        set { defaults.set(newValue, forKey: Constants.Defaults.whisperAPIModel) }
    }

    // MARK: - Trigger Key

    var triggerKey: TriggerKey {
        get {
            guard let raw = defaults.string(forKey: Constants.Defaults.triggerKey),
                  let key = TriggerKey(rawValue: raw) else { return .fn }
            return key
        }
        set { defaults.set(newValue.rawValue, forKey: Constants.Defaults.triggerKey) }
    }

    var customKeyCombo: CustomKeyCombo? {
        get {
            guard let data = defaults.data(forKey: Constants.Defaults.customKeyCombo) else { return nil }
            return try? JSONDecoder().decode(CustomKeyCombo.self, from: data)
        }
        set {
            if let combo = newValue, let data = try? JSONEncoder().encode(combo) {
                defaults.set(data, forKey: Constants.Defaults.customKeyCombo)
            } else {
                defaults.removeObject(forKey: Constants.Defaults.customKeyCombo)
            }
        }
    }

    // MARK: - VAD

    var vadEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.vadEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.vadEnabled) }
    }

    // MARK: - Onboarding

    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Constants.Defaults.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Constants.Defaults.onboardingCompleted) }
    }

    /// Short key-cap label for the voice trigger, e.g. "右 ⌥"
    var triggerKeyLabel: String {
        if triggerKey == .custom, let combo = customKeyCombo {
            return combo.displayString
        }
        return triggerKey.shortLabel
    }

    // MARK: - Pinyin

    /// Show next-word suggestions (联想) after committing Chinese text
    var predictionEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.predictionEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.predictionEnabled) }
    }

    /// 中英文之间自动加空格 for committed text (我用 GitHub 写代码)
    var autoSpacingEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.autoSpacingEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.autoSpacingEnabled) }
    }

    // MARK: - Live Typing

    /// Type partial transcription into the input field while speaking (Apple ASR only)
    var liveTypingEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.liveTypingEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.liveTypingEnabled) }
    }

    // MARK: - Hot Words

    /// Stored as array of dictionaries: [["from": "配森", "to": "Python"], ...]
    var hotWords: [[String: String]] {
        get { defaults.array(forKey: Constants.Defaults.hotWords) as? [[String: String]] ?? [] }
        set { defaults.set(newValue, forKey: Constants.Defaults.hotWords) }
    }

    // MARK: - Injection History

    var injectionHistory: [String] {
        get { defaults.stringArray(forKey: Constants.Defaults.injectionHistory) ?? [] }
        set { defaults.set(newValue, forKey: Constants.Defaults.injectionHistory) }
    }

    func addToHistory(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var history = injectionHistory
        // Remove duplicate if exists
        history.removeAll { $0 == text }
        // Insert at front
        history.insert(text, at: 0)
        // Keep only 10
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        injectionHistory = history
    }

    func clearHistory() {
        injectionHistory = []
    }
}
