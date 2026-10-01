import Foundation

/// Next-word prediction (联想) after a commit, e.g. 谢谢 → 你 / 你们 / 大家.
/// Data: SharedSupport/predict.tsv, built by scripts/build-predict-data.sh
/// (`word<TAB>next1 next2 …`, most frequent first). Loaded once in the background.
final class PredictionEngine {
    static let shared = PredictionEngine()

    private var table: [String: [String]] = [:]
    private var isLoaded = false
    private let queue = DispatchQueue(label: "com.typeany.prediction", qos: .utility)

    /// Longest word suffix tried as a lookup key
    private let maxKeyLength = 4

    private init() {}

    func loadInBackground() {
        queue.async { [weak self] in
            guard let self = self, !self.isLoaded,
                  let url = Bundle.main.sharedSupportURL?.appendingPathComponent("predict.tsv"),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            var table: [String: [String]] = [:]
            table.reserveCapacity(180_000)
            content.enumerateLines { line, _ in
                guard let tab = line.firstIndex(of: "\t") else { return }
                let word = String(line[..<tab])
                let nexts = line[line.index(after: tab)...].split(separator: " ").map(String.init)
                table[word] = nexts
            }
            DispatchQueue.main.async {
                self.table = table
                self.isLoaded = true
            }
        }
    }

    /// Predictions for what follows `committed`, matching its longest known suffix.
    func predict(after committed: String, limit: Int = 5) -> [String] {
        guard isLoaded, let last = committed.last, last.isChineseCharacter else { return [] }
        let chars = Array(committed)
        for length in stride(from: min(maxKeyLength, chars.count), through: 1, by: -1) {
            let key = String(chars.suffix(length))
            if let nexts = table[key], !nexts.isEmpty {
                return Array(nexts.prefix(limit))
            }
        }
        return []
    }
}

private extension Character {
    var isChineseCharacter: Bool {
        unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains($0.value) }
    }
}
