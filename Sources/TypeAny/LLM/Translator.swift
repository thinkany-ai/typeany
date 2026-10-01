import Foundation
import Translation

/// Translates Chinese drafts into tweet-ready English via the configured
/// OpenAI-compatible LLM, streaming partial output as it arrives.
final class Translator {
    enum TranslatorError: LocalizedError {
        case notConfigured
        case appleLanguagesMissing
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "未配置大模型 API（菜单栏 TypeAny → Settings）"
            case .appleLanguagesMissing:
                return "未下载离线翻译语言：系统设置 → 通用 → 语言与地区 → 翻译语言，下载中文和英语"
            case .http(let code, let message):
                return "翻译失败 (\(code)) \(message)"
            }
        }
    }

    private let prefs = PreferencesManager.shared

    private let systemPrompt = """
    You translate text the user is typing (usually Chinese) into natural, fluent English \
    for posting on X (Twitter). Rules:
    1. Output ONLY the translation — no quotes, notes, or alternatives.
    2. Write like a native English speaker posting casually. Do not translate literally.
    3. Preserve tone: humor, sarcasm, politeness, emphasis.
    4. Keep @mentions, #hashtags, URLs, emoji, numbers, code, and existing English words unchanged.
    5. Keep line breaks. Do not add hashtags, emoji, or content that is not in the input.
    6. Stay concise; tweets are limited to 280 characters.
    7. If the input is already English, return it with only minimal grammar fixes.
    """

    /// Streams the translation; `onPartial` receives the accumulated text so far.
    /// Uses the configured LLM; falls back to Apple's on-device translation without one.
    func translate(_ text: String, onPartial: @escaping @MainActor (String) -> Void) async throws -> String {
        guard prefs.isLLMConfigured else {
            if #available(macOS 26.0, *) {
                return try await translateOnDevice(text)
            }
            throw TranslatorError.notConfigured
        }

        let baseURL = prefs.llmAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else { throw TranslatorError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(prefs.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "model": prefs.llmModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
            "max_tokens": 1024,
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            var message = ""
            for try await line in bytes.lines { message += line }
            throw TranslatorError.http(status, String(message.prefix(120)))
        }

        // Server-sent events: `data: {json}` lines, terminated by `data: [DONE]`
        var result = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String,
                  !content.isEmpty else { continue }
            result += content
            let snapshot = result
            await onPartial(snapshot)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Apple on-device fallback

    private static let chinese = Locale.Language(identifier: "zh-Hans")
    private static let english = Locale.Language(identifier: "en")
    private var appleSession: AnyObject?

    /// Literal-ish but free and offline; requires the language pack to be installed.
    @available(macOS 26.0, *)
    private func translateOnDevice(_ text: String) async throws -> String {
        let status = await LanguageAvailability().status(from: Self.chinese, to: Self.english)
        guard status == .installed else { throw TranslatorError.appleLanguagesMissing }

        let session = (appleSession as? TranslationSession)
            ?? TranslationSession(installedSource: Self.chinese, target: Self.english)
        appleSession = session
        return try await session.translate(text).targetText
    }
}
