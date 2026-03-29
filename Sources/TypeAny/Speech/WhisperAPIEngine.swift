import Foundation

final class WhisperAPIEngine {
    /// Transcribe a WAV file using OpenAI-compatible Whisper API
    func transcribe(audioFile: URL, language: String) async throws -> String {
        let prefs = PreferencesManager.shared

        let baseURL = prefs.whisperAPIBaseURL.isEmpty
            ? prefs.llmAPIBaseURL
            : prefs.whisperAPIBaseURL
        let apiKey = prefs.whisperAPIKey.isEmpty
            ? prefs.llmAPIKey
            : prefs.whisperAPIKey
        let model = prefs.whisperAPIModel

        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw WhisperAPIError.notConfigured
        }

        let urlString = baseURL.hasSuffix("/")
            ? baseURL + "audio/transcriptions"
            : baseURL + "/audio/transcriptions"

        guard let url = URL(string: urlString) else {
            throw WhisperAPIError.invalidURL(urlString)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Build multipart body
        let audioData = try Data(contentsOf: audioFile)
        var body = Data()

        // file field
        body.appendMultipart(boundary: boundary, name: "file",
                            filename: "audio.wav", mimeType: "audio/wav",
                            data: audioData)
        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        // language field (ISO 639-1)
        let langCode = language.components(separatedBy: "-").first ?? language
        body.appendMultipart(boundary: boundary, name: "language", value: langCode)
        // response format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")
        // closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperAPIError.apiError(httpResponse.statusCode, errorBody)
        }

        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if text.isEmpty {
            throw WhisperAPIError.emptyResponse
        }

        return text
    }

    enum WhisperAPIError: LocalizedError {
        case notConfigured
        case invalidURL(String)
        case apiError(Int, String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Whisper API not configured. Set API Base URL and API Key."
            case .invalidURL(let url):
                return "Invalid API URL: \(url)"
            case .apiError(let code, let body):
                return "API error \(code): \(body)"
            case .emptyResponse:
                return "Empty response from API"
            }
        }
    }
}

// MARK: - Data multipart helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String,
                                  mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
