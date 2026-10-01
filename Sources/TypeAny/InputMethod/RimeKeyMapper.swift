import Cocoa

/// Translates macOS key events into Rime (X11) keysyms and modifier masks.
enum RimeKeyMapper {
    // X11 modifier masks used by librime
    static let shiftMask: Int32 = 1 << 0
    static let lockMask: Int32 = 1 << 1
    static let controlMask: Int32 = 1 << 2
    static let altMask: Int32 = 1 << 3
    static let superMask: Int32 = 1 << 26

    /// macOS virtual keycode → X11 keysym for non-character keys
    private static let specialKeys: [UInt16: Int32] = [
        36: 0xff0d,   // Return
        76: 0xff8d,   // KP_Enter
        48: 0xff09,   // Tab
        49: 0x20,     // space
        51: 0xff08,   // BackSpace
        117: 0xffff,  // Delete
        53: 0xff1b,   // Escape
        123: 0xff51,  // Left
        124: 0xff53,  // Right
        125: 0xff54,  // Down
        126: 0xff52,  // Up
        115: 0xff50,  // Home
        119: 0xff57,  // End
        116: 0xff55,  // Page_Up
        121: 0xff56,  // Page_Down
    ]

    static func mask(for flags: NSEvent.ModifierFlags) -> Int32 {
        var mask: Int32 = 0
        if flags.contains(.shift) { mask |= shiftMask }
        if flags.contains(.capsLock) { mask |= lockMask }
        if flags.contains(.control) { mask |= controlMask }
        if flags.contains(.option) { mask |= altMask }
        if flags.contains(.command) { mask |= superMask }
        return mask
    }

    static func keysym(for event: NSEvent) -> Int32? {
        if let special = specialKeys[event.keyCode] {
            return special
        }
        // Rime expects the shifted character ("?" for ⇧/, "A" for ⇧A). charactersIgnoringModifiers
        // only applies Shift to letters, so use `characters` unless ⌃/⌥/⌘ would alter them.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = flags.isDisjoint(with: [.control, .option, .command])
            ? event.characters
            : event.charactersIgnoringModifiers
        guard let scalar = chars?.unicodeScalars.first,
              scalar.value >= 0x20, scalar.value < 0x7f else { return nil }
        return Int32(scalar.value)
    }
}
