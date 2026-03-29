import Foundation

final class WhisperLocalEngine {
    static let defaultModelPath = NSHomeDirectory() + "/.typeany/models/ggml-base.bin"

    /// Check if whisper-cli (or whisper) is installed
    static func isInstalled() -> Bool {
        return whisperCommand() != nil
    }

    /// Find the whisper command name
    static func whisperCommand() -> String? {
        for cmd in ["whisper-cli", "whisper"] {
            let result = runShell("/usr/bin/which", arguments: [cmd])
            if result.exitCode == 0 && !result.output.isEmpty {
                return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Check if the model file exists at the configured path
    static func modelExists(at path: String? = nil) -> Bool {
        let modelPath = path ?? PreferencesManager.shared.whisperModelPath
        return FileManager.default.fileExists(atPath: modelPath)
    }

    /// Transcribe a WAV file using local whisper-cli
    func transcribe(audioFile: URL, language: String) async throws -> String {
        guard let cmd = WhisperLocalEngine.whisperCommand() else {
            throw WhisperError.notInstalled
        }

        let modelPath = PreferencesManager.shared.whisperModelPath
        guard WhisperLocalEngine.modelExists(at: modelPath) else {
            throw WhisperError.modelNotFound(modelPath)
        }

        // whisper-cli -m <model> -l <lang> -otxt <audio_file>
        // It writes output to <audio_file>.txt
        let langCode = language.components(separatedBy: "-").first ?? language
        let result = runShell(cmd, arguments: [
            "-m", modelPath,
            "-l", langCode,
            "-otxt",
            audioFile.path
        ])

        if result.exitCode != 0 {
            // Try to get text from stderr/stdout
            let errorMsg = result.output.isEmpty ? result.error : result.output
            throw WhisperError.transcriptionFailed(errorMsg)
        }

        // Read the output txt file
        let txtPath = audioFile.path + ".txt"
        if let text = try? String(contentsOfFile: txtPath, encoding: .utf8) {
            // Clean up the txt file
            try? FileManager.default.removeItem(atPath: txtPath)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fallback: try to parse from stdout
        let stdout = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return stdout
        }

        throw WhisperError.noOutput
    }

    enum WhisperError: LocalizedError {
        case notInstalled
        case modelNotFound(String)
        case transcriptionFailed(String)
        case noOutput

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "whisper-cli not found. Install via: brew install whisper-cpp"
            case .modelNotFound(let path):
                return "Model not found at: \(path)"
            case .transcriptionFailed(let msg):
                return "Transcription failed: \(msg)"
            case .noOutput:
                return "No transcription output"
            }
        }
    }
}

// MARK: - Shell helper

private struct ShellResult {
    let output: String
    let error: String
    let exitCode: Int32
}

private func runShell(_ command: String, arguments: [String] = []) -> ShellResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    // Inherit PATH from user environment
    var env = ProcessInfo.processInfo.environment
    if let path = env["PATH"] {
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
    } else {
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    }
    process.environment = env

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ShellResult(output: "", error: error.localizedDescription, exitCode: -1)
    }

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

    return ShellResult(
        output: String(data: outData, encoding: .utf8) ?? "",
        error: String(data: errData, encoding: .utf8) ?? "",
        exitCode: process.terminationStatus
    )
}
