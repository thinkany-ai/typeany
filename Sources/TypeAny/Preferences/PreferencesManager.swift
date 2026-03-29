import Foundation

final class PreferencesManager {
    static let shared = PreferencesManager()
    private let defaults = UserDefaults.standard

    private init() {
        // Register defaults
        defaults.register(defaults: [
            Constants.Defaults.selectedLanguage: Language.zhCN.rawValue,
            Constants.Defaults.llmEnabled: false,
            Constants.Defaults.llmAPIBaseURL: "https://api.openai.com/v1",
            Constants.Defaults.llmAPIKey: "",
            Constants.Defaults.llmModel: "gpt-4o-mini",
            Constants.Defaults.vadEnabled: true,
            Constants.Defaults.asrEngine: ASREngineType.apple.rawValue,
            Constants.Defaults.whisperModelPath: WhisperLocalEngine.defaultModelPath,
            Constants.Defaults.whisperAPIBaseURL: "",
            Constants.Defaults.whisperAPIKey: "",
            Constants.Defaults.whisperAPIModel: "whisper-1",
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

    // MARK: - VAD

    var vadEnabled: Bool {
        get { defaults.bool(forKey: Constants.Defaults.vadEnabled) }
        set { defaults.set(newValue, forKey: Constants.Defaults.vadEnabled) }
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
