import Carbon
import Foundation

/// Registers and enables TypeAny as a system input source.
/// Run as `TypeAny.app/Contents/MacOS/TypeAny --install` after copying the
/// bundle to ~/Library/Input Methods.
enum InputSourceRegistrar {
    static var inputModeID: String { AppVariant.inputModeID }

    static func install(bundleURL: URL) {
        let status = TISRegisterInputSource(bundleURL as CFURL)
        print("[TypeAny] Register input source: \(status == noErr ? "ok" : "error \(status)")")
        persistEnabled()
    }

    /// Whether TypeAny is in the input menu, and whether it's the current input source
    static func status() -> (enabled: Bool, selected: Bool) {
        guard let source = inputModeSource() else { return (false, false) }
        let enabled = isPersisted() && boolProperty(source, kTISPropertyInputSourceIsEnabled)
        return (enabled, boolProperty(source, kTISPropertyInputSourceIsSelected))
    }

    /// Switch the current input source to TypeAny (works from a foreground app)
    @discardableResult
    static func select() -> Bool {
        guard let source = inputModeSource() else { return false }
        return TISSelectInputSource(source) == noErr
    }

    private static func inputModeSource() -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: inputModeID] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
        return sources?.first
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }

    private static let enabledSourcesKey = "AppleEnabledThirdPartyInputSources"
    private static var inputSourcePrefs: UserDefaults? { UserDefaults(suiteName: "com.apple.inputsources") }

    private static func isPersisted() -> Bool {
        let entries = inputSourcePrefs?.array(forKey: enabledSourcesKey) as? [[String: Any]] ?? []
        return entries.contains { ($0["Bundle ID"] as? String) == Bundle.main.bundleIdentifier }
    }

    /// Recent macOS no longer persists TISEnableInputSource for third-party input
    /// methods, so the source never shows up in the input menu. Record it the same
    /// way System Settings → Input Sources → "+" does.
    private static func persistEnabled() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let prefs = inputSourcePrefs,
              !isPersisted() else { return }
        var entries = prefs.array(forKey: enabledSourcesKey) as? [[String: Any]] ?? []
        entries.append(["Bundle ID": bundleID, "Input Mode": inputModeID, "InputSourceKind": "Input Mode"])
        entries.append(["Bundle ID": bundleID, "InputSourceKind": "Keyboard Input Method"])
        prefs.set(entries, forKey: enabledSourcesKey)
        prefs.synchronize()

        // Make the input menu pick up the change
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["TextInputMenuAgent"]
        try? killall.run()
        killall.waitUntilExit()
        print("[TypeAny] Enabled input source (switch to it from the input menu)")
    }
}
