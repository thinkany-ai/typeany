import Cocoa
import Carbon

// MARK: - TriggerKey

enum TriggerKey: String, CaseIterable, Codable {
    case fn = "fn"
    case rightOption = "rightOption"
    case rightCommand = "rightCommand"
    case rightControl = "rightControl"
    case capsLock = "capsLock"
    case f5 = "f5"
    case f6 = "f6"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .fn: return "Fn"
        case .rightOption: return "Right Option (⌥)"
        case .rightCommand: return "Right Command (⌘)"
        case .rightControl: return "Right Control (⌃)"
        case .capsLock: return "Caps Lock"
        case .f5: return "F5"
        case .f6: return "F6"
        case .custom: return "Custom"
        }
    }

    var hint: String? {
        switch self {
        case .fn: return "可能被微信等应用占用"
        case .capsLock: return "按住时会改变大写状态"
        default: return nil
        }
    }

    /// The CGKeyCode for this trigger key (modifier keys use flagsChanged events)
    var keyCode: UInt16? {
        switch self {
        case .fn: return 63
        case .rightOption: return 61
        case .rightCommand: return 54
        case .rightControl: return 62
        case .capsLock: return 57
        case .f5: return 96
        case .f6: return 97
        case .custom: return nil
        }
    }

    /// Whether this key is a modifier (uses flagsChanged) vs a regular key (uses keyDown/keyUp)
    var isModifierKey: Bool {
        switch self {
        case .fn, .rightOption, .rightCommand, .rightControl, .capsLock:
            return true
        case .f5, .f6, .custom:
            return false
        }
    }
}

// MARK: - CustomKeyCombo

struct CustomKeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt64  // CGEventFlags.rawValue
    let displayString: String

    /// Check if the combo uses only modifier keys (no regular key)
    var isModifierOnly: Bool {
        // Well-known modifier keyCodes
        let modKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return modKeyCodes.contains(keyCode)
    }
}

// MARK: - HotkeyMonitor

final class HotkeyMonitor {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyIsDown = false

    private var triggerKey: TriggerKey = .fn
    private var customCombo: CustomKeyCombo?

    /// Update the trigger key and restart monitoring if active
    func configure(triggerKey: TriggerKey, customCombo: CustomKeyCombo? = nil) {
        let wasRunning = eventTap != nil
        if wasRunning { stop() }
        self.triggerKey = triggerKey
        self.customCombo = customCombo
        if wasRunning { start() }
    }

    /// Whether the last start() call succeeded in creating an event tap
    private(set) var isRunning: Bool = false

    func start() {
        var eventMask: CGEventMask = 0

        if triggerKey == .custom, let combo = customCombo, !combo.isModifierOnly {
            // Custom key combo with a regular key: listen for keyDown, keyUp, and flagsChanged
            eventMask = (1 << CGEventType.keyDown.rawValue)
                      | (1 << CGEventType.keyUp.rawValue)
                      | (1 << CGEventType.flagsChanged.rawValue)
        } else if triggerKey.isModifierKey || (triggerKey == .custom && customCombo?.isModifierOnly == true) {
            // Modifier-based triggers
            eventMask = (1 << CGEventType.flagsChanged.rawValue)
        } else {
            // Function keys (F5, F6)
            eventMask = (1 << CGEventType.keyDown.rawValue)
                      | (1 << CGEventType.keyUp.rawValue)
        }

        print("[TypeAny] HotkeyMonitor starting for key: \(triggerKey.displayName), eventMask: \(eventMask)")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[TypeAny] ❌ Failed to create CGEvent tap — accessibility permission not granted!")
            isRunning = false
            onTapCreateFailed?()
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        print("[TypeAny] ✅ HotkeyMonitor started successfully for: \(triggerKey.displayName)")
    }

    /// Called on the main thread when CGEvent.tapCreate fails (accessibility permission missing)
    var onTapCreateFailed: (() -> Void)?

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        keyIsDown = false
        isRunning = false
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        switch triggerKey {
        case .fn:
            return handleFn(type: type, event: event)
        case .rightOption:
            return handleModifier(type: type, event: event, keyCode: 61, flag: .maskAlternate)
        case .rightCommand:
            return handleModifier(type: type, event: event, keyCode: 54, flag: .maskCommand)
        case .rightControl:
            return handleModifier(type: type, event: event, keyCode: 62, flag: .maskControl)
        case .capsLock:
            return handleCapsLock(type: type, event: event)
        case .f5:
            return handleFunctionKey(type: type, event: event, keyCode: 96)
        case .f6:
            return handleFunctionKey(type: type, event: event, keyCode: 97)
        case .custom:
            return handleCustomCombo(type: type, event: event)
        }
    }

    // MARK: - Fn Key

    private func handleFn(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let isFnDown = flags.contains(.maskSecondaryFn)

        if isFnDown && !keyIsDown {
            keyIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            return nil // Suppress
        } else if !isFnDown && keyIsDown {
            keyIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Right Modifier Keys

    private func handleModifier(type: CGEventType, event: CGEvent, keyCode: UInt16, flag: CGEventFlags) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else { return Unmanaged.passRetained(event) }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return Unmanaged.passRetained(event) }

        let flags = event.flags
        let isDown = flags.contains(flag)

        if isDown && !keyIsDown {
            keyIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            return nil
        } else if !isDown && keyIsDown {
            keyIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Caps Lock

    private func handleCapsLock(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else { return Unmanaged.passRetained(event) }

        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == 57 else { return Unmanaged.passRetained(event) }

        // Caps Lock toggles: each physical press sends flagsChanged.
        // We treat flag present = down, flag absent = up.
        let flags = event.flags
        let isCapsDown = flags.contains(.maskAlphaShift)

        if isCapsDown && !keyIsDown {
            keyIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            return nil
        } else if !isCapsDown && keyIsDown {
            keyIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Function Keys (F5, F6)

    private func handleFunctionKey(type: CGEventType, event: CGEvent, keyCode: UInt16) -> Unmanaged<CGEvent>? {
        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return Unmanaged.passRetained(event) }

        if type == .keyDown && !keyIsDown {
            keyIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            return nil // Suppress to prevent system function
        } else if type == .keyUp && keyIsDown {
            keyIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Custom Key Combo

    private func handleCustomCombo(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let combo = customCombo else { return Unmanaged.passRetained(event) }

        if combo.isModifierOnly {
            // Treat like a modifier key
            guard type == .flagsChanged else { return Unmanaged.passRetained(event) }
            let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard eventKeyCode == combo.keyCode else { return Unmanaged.passRetained(event) }

            // Check if the key's corresponding flag is set
            let flags = event.flags
            let isDown = flags.rawValue & combo.modifierFlags != 0

            if isDown && !keyIsDown {
                keyIsDown = true
                DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
                return nil
            } else if !isDown && keyIsDown {
                keyIsDown = false
                DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
                return nil
            }
        } else {
            // Regular key + optional modifiers
            let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard eventKeyCode == combo.keyCode else { return Unmanaged.passRetained(event) }

            // Check modifiers match
            let requiredMods = CGEventFlags(rawValue: combo.modifierFlags)
            let checkFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            let currentMods = event.flags.intersection(checkFlags)
            let neededMods = requiredMods.intersection(checkFlags)
            guard currentMods == neededMods else { return Unmanaged.passRetained(event) }

            if type == .keyDown && !keyIsDown {
                keyIsDown = true
                DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
                return nil
            } else if type == .keyUp && keyIsDown {
                keyIsDown = false
                DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - Key Recording Helper

final class KeyRecorder {
    var onRecorded: ((CustomKeyCombo) -> Void)?
    var onCancelled: (() -> Void)?

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func startRecording() {
        // Monitor local events (when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
            return nil // Consume event
        }

        // Monitor global events (when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        // Escape cancels
        if event.type == .keyDown && event.keyCode == 53 {
            stopRecording()
            DispatchQueue.main.async { [weak self] in self?.onCancelled?() }
            return
        }

        if event.type == .keyDown {
            // Regular key press (possibly with modifiers)
            let combo = CustomKeyCombo(
                keyCode: event.keyCode,
                modifierFlags: UInt64(event.modifierFlags.rawValue) & UInt64(CGEventFlags([.maskCommand, .maskShift, .maskAlternate, .maskControl]).rawValue),
                displayString: Self.displayString(keyCode: event.keyCode, modifiers: event.modifierFlags)
            )
            stopRecording()
            DispatchQueue.main.async { [weak self] in self?.onRecorded?(combo) }
        }
    }

    static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        let mapping: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "PgUp",
            117: "FwdDel", 118: "F4", 119: "End", 120: "F2", 121: "PgDn",
            122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return mapping[keyCode] ?? "Key\(keyCode)"
    }
}
