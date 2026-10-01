import Cocoa

/// Input methods only load from ~/Library/Input Methods. When TypeAny is opened from anywhere
/// else (the DMG, /Applications, Downloads), it copies itself there, registers the input source
/// and relaunches the installed copy — so installing is just "open TypeAny".
enum SelfInstaller {
    static var inputMethodsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods", isDirectory: true)
    }

    static var isRunningFromInputMethods: Bool {
        Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath().path
            == inputMethodsDirectory.resolvingSymlinksInPath().path
    }

    static func installAndRelaunch() {
        let source = Bundle.main.bundleURL
        let destination = inputMethodsDirectory.appendingPathComponent(source.lastPathComponent)
        do {
            stopInstalledCopy()
            try FileManager.default.createDirectory(at: inputMethodsDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            alert("Couldn't install TypeAny", error.localizedDescription)
            return
        }

        // Register with the system from the installed location, then start it
        let register = Process()
        register.executableURL = destination.appendingPathComponent("Contents/MacOS/TypeAny")
        register.arguments = ["--install"]
        try? register.run()
        register.waitUntilExit()

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        let done = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, _ in done.signal() }
        _ = done.wait(timeout: .now() + 10)
    }

    /// An older installed copy keeps the input method connection; replace it cleanly
    private static func stopInstalledCopy() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        others.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(3)
        while others.contains(where: { !$0.isTerminated }) && Date() < deadline {
            usleep(100_000)
        }
        others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    }

    private static func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
