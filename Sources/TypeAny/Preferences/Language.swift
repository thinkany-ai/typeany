import Foundation

enum Language: String, CaseIterable, Codable {
    case zhCN = "zh-CN"
    case zhTW = "zh-TW"
    case en = "en-US"
    case ja = "ja-JP"
    case ko = "ko-KR"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .zhCN: return "简体中文"
        case .zhTW: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }
}
