import Foundation

final class LLMRefiner {
    private let prefs = PreferencesManager.shared

    private let baseSystemPrompt = """
    You are a speech recognition post-processor. Your ONLY job is to fix obvious speech recognition errors. Rules:
    1. Fix clear homophones/misrecognitions in Chinese (e.g., 配森→Python, 杰森→JSON, 吉特→Git, 吉特哈布→GitHub, 瑞安→Ryan, 艾皮艾→API).
    2. Fix English technical terms that were incorrectly transcribed into Chinese characters.
    3. Fix obvious punctuation errors.
    4. NEVER rewrite, rephrase, polish, summarize, or add content.
    5. NEVER remove any content that looks correct.
    6. If the input looks correct, return it EXACTLY as-is with zero changes.
    7. Return ONLY the corrected text, no explanations or quotes.

    Critical rules for mixed Chinese-English text:
    - HTTP status codes MUST stay as Arabic numerals: 401, 404, 500, 200, 302, etc. NEVER convert to Chinese like 四零一.
    - Technical terms MUST stay in English: token, PR, bug, API, URL, SDK, JSON, Git, GitHub, Docker, Redis, MySQL, PostgreSQL, Kubernetes, npm, webpack, TypeScript, React, Vue, Node.js, etc.
    - All numbers MUST use Arabic numerals (1, 2, 3...), NEVER Chinese numerals (一, 二, 三...) unless the context is clearly non-technical Chinese prose.
    - Common dev abbreviations stay as-is: CI/CD, HTTP, HTTPS, SSH, TCP, UDP, DNS, SSL, TLS, REST, GraphQL, gRPC, etc.
    """

    private var systemPrompt: String {
        let hotWordsSection = HotWordsManager.shared.promptSection()
        return baseSystemPrompt + hotWordsSection
    }

    func refine(text: String) async throws -> String {
        guard prefs.isLLMConfigured && prefs.llmEnabled else { return text }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }

        let baseURL = prefs.llmAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)/chat/completions"
        guard let url = URL(string: urlString) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(prefs.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": prefs.llmModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": 2048
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("[TypeAny] LLM API error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return text
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return text
        }

        let refined = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return refined.isEmpty ? text : refined
    }

    func testConnection() async throws -> Bool {
        let baseURL = prefs.llmAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(baseURL)/chat/completions"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(prefs.llmAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": prefs.llmModel,
            "messages": [
                ["role": "user", "content": "Hi"]
            ],
            "max_tokens": 5
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }
}
