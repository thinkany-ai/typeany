import Cocoa

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let appState = AppState.shared
    private let settingsWindowController = SettingsWindowController()
    var onQuit: (() -> Void)?
    var onOpenOnboarding: (() -> Void)?
    var onHistoryInject: ((String) -> Void)?
    var onTriggerKeyChanged: (() -> Void)?

    func setup() {
        // Dev builds show a "Dev" label next to the icon so they're never mistaken for release
        statusItem = NSStatusBar.system.statusItem(
            withLength: AppVariant.isDev ? NSStatusItem.variableLength : NSStatusItem.squareLength)
        if AppVariant.isDev, let button = statusItem?.button {
            button.title = "Dev"
            button.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
            button.imagePosition = .imageLeading
        }

        updateIcon(recording: false)
        rebuildMenu()
    }

    func updateIcon(recording: Bool) {
        guard let button = statusItem?.button else { return }
        // Idle: the TypeAny mark (template PDF); recording: a mic so it's obvious we're listening
        let image = recording
            ? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "TypeAny")
            : (NSImage(named: "TypeAny") ?? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "TypeAny"))
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        button.image = image
    }

    func updateIconForPermissionIssue() {
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: "TypeAny - Permission Required")
            button.image?.size = NSSize(width: 16, height: 16)
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Language submenu
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(languageSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            if lang == appState.selectedLanguage {
                item.state = .on
            }
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // Trigger Key submenu
        let triggerItem = NSMenuItem(title: "Trigger Key", action: nil, keyEquivalent: "")
        let triggerMenu = NSMenu()
        let currentTrigger = PreferencesManager.shared.triggerKey
        for key in TriggerKey.allCases where key != .custom {
            let item = NSMenuItem(title: key.displayName, action: #selector(triggerKeySelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key.rawValue
            if key == currentTrigger {
                item.state = .on
            }
            triggerMenu.addItem(item)
        }
        // Show custom entry if one is configured
        if let combo = PreferencesManager.shared.customKeyCombo {
            triggerMenu.addItem(NSMenuItem.separator())
            let customItem = NSMenuItem(title: "Custom: \(combo.displayString)", action: #selector(triggerKeySelected(_:)), keyEquivalent: "")
            customItem.target = self
            customItem.representedObject = TriggerKey.custom.rawValue
            if currentTrigger == .custom {
                customItem.state = .on
            }
            triggerMenu.addItem(customItem)
        }
        triggerItem.submenu = triggerMenu
        menu.addItem(triggerItem)

        menu.addItem(NSMenuItem.separator())

        // VAD toggle
        let vadItem = NSMenuItem(
            title: "Auto Stop (VAD)",
            action: #selector(toggleVAD(_:)),
            keyEquivalent: ""
        )
        vadItem.target = self
        vadItem.state = PreferencesManager.shared.vadEnabled ? .on : .off
        menu.addItem(vadItem)

        // Live typing toggle
        let liveItem = NSMenuItem(
            title: "Live Typing",
            action: #selector(toggleLiveTyping(_:)),
            keyEquivalent: ""
        )
        liveItem.target = self
        liveItem.state = PreferencesManager.shared.liveTypingEnabled ? .on : .off
        menu.addItem(liveItem)

        menu.addItem(NSMenuItem.separator())

        // Hot Words
        let hotWordsItem = NSMenuItem(title: "Hot Words...", action: #selector(openHotWords(_:)), keyEquivalent: "")
        hotWordsItem.target = self
        menu.addItem(hotWordsItem)

        menu.addItem(NSMenuItem.separator())

        // LLM Refinement submenu
        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()

        let enableItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleLLM(_:)),
            keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = PreferencesManager.shared.llmEnabled ? .on : .off
        llmMenu.addItem(enableItem)

        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(NSMenuItem.separator())

        // History submenu
        let historyItem = NSMenuItem(title: "Recent History", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu()

        let history = PreferencesManager.shared.injectionHistory
        if history.isEmpty {
            let emptyItem = NSMenuItem(title: "(No history)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
        } else {
            for (index, text) in history.enumerated() {
                let truncated = text.count > 30 ? String(text.prefix(30)) + "..." : text
                let item = NSMenuItem(title: truncated, action: #selector(historyItemSelected(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.representedObject = text
                historyMenu.addItem(item)
            }

            historyMenu.addItem(NSMenuItem.separator())

            let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory(_:)), keyEquivalent: "")
            clearItem.target = self
            historyMenu.addItem(clearItem)
        }

        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        // Settings (top-level)
        let topSettingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings(_:)), keyEquivalent: ",")
        topSettingsItem.target = self
        menu.addItem(topSettingsItem)

        let onboardingItem = NSMenuItem(title: "使用引导…", action: #selector(openOnboarding(_:)), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit TypeAny", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func languageSelected(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? Language else { return }
        appState.updateLanguage(lang)
        rebuildMenu()
    }

    @objc private func triggerKeySelected(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let key = TriggerKey(rawValue: rawValue) else { return }
        PreferencesManager.shared.triggerKey = key
        onTriggerKeyChanged?()
        rebuildMenu()
    }

    @objc private func toggleVAD(_ sender: NSMenuItem) {
        PreferencesManager.shared.vadEnabled.toggle()
        rebuildMenu()
    }

    @objc private func toggleLiveTyping(_ sender: NSMenuItem) {
        PreferencesManager.shared.liveTypingEnabled.toggle()
        rebuildMenu()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        PreferencesManager.shared.llmEnabled.toggle()
        rebuildMenu()
    }

    @objc private func openOnboarding(_ sender: NSMenuItem) {
        onOpenOnboarding?()
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        showSettings()
    }

    func showSettings(tab: SettingsTab = .general) {
        settingsWindowController.onTriggerKeyChanged = { [weak self] in
            self?.onTriggerKeyChanged?()
            self?.rebuildMenu()
        }
        settingsWindowController.onPreferencesChanged = { [weak self] in
            self?.rebuildMenu()
        }
        settingsWindowController.show(tab: tab)
    }

    @objc private func openHotWords(_ sender: NSMenuItem) {
        showSettings(tab: .hotWords)
    }

    @objc private func historyItemSelected(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        onHistoryInject?(text)
    }

    @objc private func clearHistory(_ sender: NSMenuItem) {
        PreferencesManager.shared.clearHistory()
        rebuildMenu()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        onQuit?()
    }
}
