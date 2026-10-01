import Cocoa
import InputMethodKit

/// Kept alive for the process lifetime; IMK connects clients through it.
private var imkServer: IMKServer?

@main
struct TypeAnyApp {
    static func main() {
        if CommandLine.arguments.contains("--install") {
            InputSourceRegistrar.install(bundleURL: Bundle.main.bundleURL)
            return
        }
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTest.run())
        }
        // Opened from the DMG / Applications / Downloads: install into ~/Library/Input Methods
        if !SelfInstaller.isRunningFromInputMethods {
            SelfInstaller.installAndRelaunch()
            return
        }
        if CommandLine.arguments.contains(OnboardingLauncher.argument) {
            OnboardingLauncher.runApp()
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // LSUIElement equivalent

        RimeEngine.shared.start()
        PredictionEngine.shared.loadInBackground()

        let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
            ?? "com.typeany.inputmethod.TypeAny_Connection"
        imkServer = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

        app.run()
    }
}
