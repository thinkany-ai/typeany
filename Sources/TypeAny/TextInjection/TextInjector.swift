import Cocoa
import Carbon

final class TextInjector {

    func inject(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 1. Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        // 2. Check if current input source is CJK
        let originalInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let isCJK = isCurrentInputSourceCJK()
        var asciiSource: TISInputSource?

        if isCJK {
            // Switch to ASCII input source
            asciiSource = findASCIIInputSource()
            if let ascii = asciiSource {
                TISSelectInputSource(ascii)
                usleep(50_000) // 50ms for input source switch
            }
        }

        // 3. Write text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 4. Simulate Cmd+V (small delay to ensure clipboard is ready)
        usleep(50_000) // 50ms
        simulatePaste()

        // 5. Restore original input source after paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if isCJK, let original = originalInputSource {
                TISSelectInputSource(original)
            }

            // 6. Restore clipboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.restorePasteboard(pasteboard, items: savedItems)
            }
        }
    }

    // MARK: - Clipboard Save/Restore

    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [PasteboardItem] {
        var items: [PasteboardItem] = []
        guard let types = pasteboard.types else { return items }
        for type in types {
            if let data = pasteboard.data(forType: type) {
                items.append(PasteboardItem(type: type, data: data))
            }
        }
        return items
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, items: [PasteboardItem]) {
        pasteboard.clearContents()
        for item in items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }

    // MARK: - Input Source Detection

    private func isCurrentInputSourceCJK() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
        let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

        let cjkPrefixes = [
            "com.apple.inputmethod.SCIM",      // Simplified Chinese
            "com.apple.inputmethod.TCIM",      // Traditional Chinese
            "com.apple.inputmethod.Japanese",   // Japanese
            "com.apple.inputmethod.Korean",     // Korean
            "com.sogou.inputmethod",            // Sogou
            "com.baidu.inputmethod",            // Baidu
            "com.tencent.inputmethod",          // QQ
            "com.iflytek.inputmethod",          // iFlytek
            "com.google.inputmethod.Japanese",  // Google Japanese
        ]

        return cjkPrefixes.contains { sourceID.hasPrefix($0) }
    }

    private func findASCIIInputSource() -> TISInputSource? {
        let conditions: [String: Any] = [
            kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
            kTISPropertyInputSourceIsASCIICapable as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        guard let sources = TISCreateInputSourceList(conditions as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        // Prefer "ABC" or "US" keyboard
        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            if sourceID == "com.apple.keylayout.ABC" || sourceID == "com.apple.keylayout.US" {
                return source
            }
        }

        return sources.first
    }

    // MARK: - Keystroke Simulation

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 9 = V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
