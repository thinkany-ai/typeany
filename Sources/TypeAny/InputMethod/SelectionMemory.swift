import Foundation

/// Remembers the last candidate picked for each input code, so the next time the
/// same code is typed that candidate comes first — m → 吗 after choosing 吗 once,
/// regardless of code length. Complements Rime's frequency-based user dictionary,
/// which only promotes a word after it has been picked more often than the others.
final class SelectionMemory {
    static let shared = SelectionMemory()

    private let maxEntries = 5000
    private var choices: [String: String] = [:]
    /// Codes from least to most recently used, for eviction
    private var recency: [String] = []
    private var saveWork: DispatchWorkItem?

    private var fileURL: URL {
        AppVariant.dataDirectory.appendingPathComponent("selection_memory.json")
    }

    private struct Stored: Codable {
        var choices: [String: String]
        var recency: [String]
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            choices = stored.choices
            recency = stored.recency.filter { stored.choices[$0] != nil }
        }
    }

    func preferred(for code: String) -> String? {
        choices[code]
    }

    func record(code: String, text: String) {
        guard !code.isEmpty, !text.isEmpty else { return }
        if choices[code] != text {
            choices[code] = text
        }
        recency.removeAll { $0 == code }
        recency.append(code)
        if recency.count > maxEntries {
            let evicted = recency.prefix(recency.count - maxEntries)
            evicted.forEach { choices.removeValue(forKey: $0) }
            recency.removeFirst(evicted.count)
        }
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = Stored(choices: choices, recency: recency)
        let url = fileURL
        let work = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2, execute: work)
    }
}
