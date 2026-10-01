import Foundation

/// 中英文之间自动加空格 (pangu spacing) for text the input method commits:
/// 我用 GitHub 写代码 — a space goes in wherever Chinese meets Latin text.
/// The space is added on the side that's being committed, so nothing dangles
/// before punctuation or at the end of a message.
enum AutoSpacing {
    /// `text` with a leading space if it meets `previous` across a Chinese/Latin boundary.
    static func spaced(_ text: String, after previous: Character?) -> String {
        guard let previous = previous, let first = text.first else { return text }
        if isLatinRun(text) && previous.isCJK {
            return " " + text          // 我用 + GitHub
        }
        if first.isCJK && previous.isLatinAlphanumeric {
            return " " + text          // GitHub + 写代码
        }
        return text
    }

    /// Committed English: ASCII-only, containing a letter or digit, not starting with a space
    /// (hello, GitHub, iPhone15, baidu.com). Pure punctuation like "," doesn't count.
    static func isLatinRun(_ text: String) -> Bool {
        guard let first = text.first, !first.isWhitespace else { return false }
        return text.unicodeScalars.allSatisfy(\.isASCII)
            && text.contains { $0.isLatinAlphanumeric }
    }
}

extension Character {
    /// CJK ideographs (incl. extension A); Chinese punctuation is deliberately excluded
    var isCJK: Bool {
        unicodeScalars.allSatisfy { (0x3400...0x4DBF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
    }

    var isLatinAlphanumeric: Bool {
        unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.alphanumerics.contains($0) }
    }
}
