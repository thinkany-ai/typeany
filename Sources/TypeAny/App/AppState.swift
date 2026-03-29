import Foundation
import Combine

enum RecordingState {
    case idle
    case recording
    case processing    // speech recognition finalizing
    case transcribing  // Whisper transcription in progress
    case refining      // LLM refinement in progress
    case injecting   // text injection in progress
    case success     // injection succeeded, showing checkmark
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var recordingState: RecordingState = .idle
    @Published var currentTranscription: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var selectedLanguage: Language

    private init() {
        self.selectedLanguage = PreferencesManager.shared.selectedLanguage
    }

    func updateLanguage(_ language: Language) {
        selectedLanguage = language
        PreferencesManager.shared.selectedLanguage = language
    }
}
