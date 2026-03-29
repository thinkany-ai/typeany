import Foundation

final class HotWordsManager {
    static let shared = HotWordsManager()
    private let prefs = PreferencesManager.shared

    private init() {}

    /// Get all hot word pairs
    var hotWords: [(from: String, to: String)] {
        prefs.hotWords.compactMap { dict in
            guard let from = dict["from"], let to = dict["to"],
                  !from.isEmpty, !to.isEmpty else { return nil }
            return (from: from, to: to)
        }
    }

    func addHotWord(from: String, to: String) {
        var words = prefs.hotWords
        // Remove existing entry with same "from"
        words.removeAll { $0["from"] == from }
        words.append(["from": from, "to": to])
        prefs.hotWords = words
    }

    func removeHotWord(at index: Int) {
        var words = prefs.hotWords
        guard index >= 0 && index < words.count else { return }
        words.remove(at: index)
        prefs.hotWords = words
    }

    /// Apply hot word replacements to text (simple string replacement)
    func applyReplacements(_ text: String) -> String {
        var result = text
        for pair in hotWords {
            result = result.replacingOccurrences(of: pair.from, with: pair.to)
        }
        return result
    }

    /// Generate hot words section for LLM prompt injection
    func promptSection() -> String {
        let words = hotWords
        guard !words.isEmpty else { return "" }
        var lines = ["\nUser-defined correction rules (MUST apply these):"]
        for pair in words {
            lines.append("- \"\(pair.from)\" → \"\(pair.to)\"")
        }
        return lines.joined(separator: "\n")
    }
}
