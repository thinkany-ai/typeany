import Foundation

enum ASREngineType: String, CaseIterable {
    case apple = "apple"
    case localWhisper = "localWhisper"
    case whisperAPI = "whisperAPI"

    var displayName: String {
        switch self {
        case .apple: return "Apple ASR"
        case .localWhisper: return "本地 Whisper"
        case .whisperAPI: return "Whisper API"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return "免费 · 实时"
        case .localWhisper: return "免费 · 离线"
        case .whisperAPI: return "按量付费 · 最强"
        }
    }
}
