import Cocoa

@main
struct TypeAnyApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // LSUIElement equivalent
        app.run()
    }
}
