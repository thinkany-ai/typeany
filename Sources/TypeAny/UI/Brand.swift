import Cocoa
import SwiftUI

/// TypeAny brand colors. Primary is the teal of the app icon (#14B8A6),
/// lifted slightly in dark mode for contrast.
enum Brand {
    static let primary = NSColor(name: "TypeAnyPrimary") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255, alpha: 1)  // #2DD4BF
            : NSColor(srgbRed: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255, alpha: 1)  // #14B8A6
    }

    static var color: Color { Color(nsColor: primary) }
}
