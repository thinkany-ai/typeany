import Cocoa
import SwiftUI

/// Onboarding runs as a second instance of the bundle (`TypeAny --onboarding`),
/// not inside the input method process: IMK calls are synchronous, so the input
/// method can't serve text fields in its own windows. As a separate client app,
/// the practice fields behave exactly like Slack or X would.
enum OnboardingLauncher {
    static let argument = "--onboarding"
    static let activateNotification = Notification.Name("com.typeany.onboarding.activate")

    private static var lockFD: Int32 = -1

    /// Held for the process lifetime; released automatically when the process exits.
    private static func acquireLock() -> Bool {
        let dir = AppVariant.dataDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        lockFD = open(dir.appendingPathComponent("onboarding.lock").path, O_CREAT | O_RDWR, 0o644)
        return lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0
    }

    /// `--step N` jumps straight to a step (for development)
    static var initialStep: OnboardingModel.Step {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--step"), i + 1 < args.count,
              let raw = Int(args[i + 1]), let step = OnboardingModel.Step(rawValue: raw) else { return .welcome }
        return step
    }

    /// From the input method process: open the onboarding window.
    static func launch() {
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = [argument]
        config.createsNewApplicationInstance = true
        config.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, error in
            if let error = error {
                print("[TypeAny] Failed to open onboarding: \(error.localizedDescription)")
            }
        }
    }

    /// Entry point when this process was started with `--onboarding`.
    @MainActor
    static func runApp() {
        // Single instance: if another onboarding window is open, bring it forward instead
        guard acquireLock() else {
            DistributedNotificationCenter.default().postNotificationName(
                activateNotification, object: nil, userInfo: nil, deliverImmediately: true)
            return
        }

        let app = NSApplication.shared
        let delegate = OnboardingAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
private final class OnboardingAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let model = OnboardingModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "TypeAny"
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: OnboardingView(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        model.step = OnboardingLauncher.initialStep
        model.start()

        DistributedNotificationCenter.default().addObserver(
            forName: OnboardingLauncher.activateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Minimal menu so ⌘Q and ⌘V (pasting the API key) work
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 TypeAny 引导", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        return main
    }
}
