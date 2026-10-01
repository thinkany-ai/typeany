import Cocoa
import Carbon

/// Types streaming transcription directly into the focused input field.
/// Each update diffs against what was already typed, backspaces the changed
/// tail, and types the new tail — so ASR revisions are corrected in place.
final class LiveTextTyper {
    private(set) var typedText = ""
    private(set) var isActive = false

    private var originalInputSource: TISInputSource?

    /// Max UTF-16 units CGEvent accepts per unicode keyboard event.
    private let maxChunkLength = 20

    func begin() {
        typedText = ""
        isActive = true
        originalInputSource = nil
    }

    func update(_ text: String) {
        guard isActive, text != typedText else { return }

        // Switch away from CJK IME lazily, on first real output, so typed
        // characters are not swallowed as pinyin composition.
        if originalInputSource == nil, TextInjector.isCurrentInputSourceCJK(),
           let ascii = TextInjector.findASCIIInputSource() {
            originalInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
            TISSelectInputSource(ascii)
            usleep(50_000) // 50ms for input source switch
        }

        let old = Array(typedText)
        let new = Array(text)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] {
            common += 1
        }

        let deleteCount = old.count - common
        for _ in 0..<deleteCount {
            postBackspace()
        }

        let suffix = String(new[common...])
        if !suffix.isEmpty {
            postUnicode(suffix)
        }

        typedText = text
    }

    /// Replace live text with the final processed text and restore input source.
    func finish(with finalText: String) {
        guard isActive else { return }
        update(finalText)
        isActive = false

        if let original = originalInputSource {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                TISSelectInputSource(original)
            }
        }
        originalInputSource = nil
    }

    // MARK: - Keystroke Simulation

    private func postBackspace() {
        // Key code 51 = Delete (backspace)
        post(virtualKey: 51, unicode: nil)
    }

    private func postUnicode(_ text: String) {
        // Chunk on Character boundaries so grapheme clusters are never split
        var chunk: [UniChar] = []
        for ch in text {
            let units = Array(String(ch).utf16)
            if chunk.count + units.count > maxChunkLength {
                post(virtualKey: 0, unicode: chunk)
                chunk = []
            }
            chunk.append(contentsOf: units)
        }
        if !chunk.isEmpty {
            post(virtualKey: 0, unicode: chunk)
        }
    }

    private func post(virtualKey: CGKeyCode, unicode: [UniChar]?) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: keyDown) else { continue }
            // The trigger key may still be physically held (⌥ / Fn / ⌘);
            // clear modifiers so backspace isn't turned into word/forward delete.
            event.flags = []
            if let unicode = unicode {
                event.keyboardSetUnicodeString(stringLength: unicode.count, unicodeString: unicode)
            }
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
