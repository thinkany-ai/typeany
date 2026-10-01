import Foundation

/// dev vs release build (Info.plist `TypeAnyVariant`, set by `make VARIANT=…`).
/// Everything that persists is keyed off this so a dev build never touches the
/// release install's data: user dictionary, selection memory, preferences.
enum AppVariant {
    static let isDev = (Bundle.main.object(forInfoDictionaryKey: "TypeAnyVariant") as? String) == "dev"

    /// ~/Library/Application Support/TypeAny (release) or TypeAny Dev (dev)
    static var dataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(isDev ? "TypeAny Dev" : "TypeAny", isDirectory: true)
    }

    /// Preferences domain. Release keeps the pre-input-method suite so existing settings carry over.
    static var defaultsSuite: String {
        isDev ? "com.typeany.app.dev" : "com.typeany.app"
    }

    /// The input source mode, e.g. com.typeany.inputmethod.TypeAnyDev.Hans
    static var inputModeID: String {
        (Bundle.main.bundleIdentifier ?? "com.typeany.inputmethod.TypeAny") + ".Hans"
    }

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "TypeAny"
    }
}
