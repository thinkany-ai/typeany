import Cocoa

/// English preview shown under the candidates while composing in translate mode
struct TranslationPreview {
    enum State {
        case waiting
        case streaming
        case done
        case failed(String)
    }

    var text: String
    var state: State
}

/// Horizontal candidate window shown under the text cursor:
///
///     1 你好  2 拟好  3 你  4 尼  5 呢      ‹ ›
///     ─────────────────────────────────────
///     EN  Hello there
///     ⏎ 发英文 · ⌥⏎ 发中文 · Esc 中文上屏
final class CandidatePanel {
    static let shared = CandidatePanel()

    /// Called with the on-page index when a candidate is clicked
    var onSelect: ((Int) -> Void)?
    /// Called with `backward` when a page arrow is clicked
    var onPage: ((Bool) -> Void)?

    private let panel: NSPanel
    private let contentView = CandidateView()
    private var statusHideWork: DispatchWorkItem?

    private init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = contentView

        contentView.onSelect = { [weak self] in self?.onSelect?($0) }
        contentView.onPage = { [weak self] in self?.onPage?($0) }
    }

    func show(context: RimeContextSnapshot, translation: TranslationPreview? = nil, cursorRect: NSRect) {
        statusHideWork?.cancel()
        contentView.mode = .candidates(context, translation)
        present(at: cursorRect)
    }

    /// Brief mode indicator, e.g. "中" / "英" after a Shift toggle
    func showStatus(_ text: String, cursorRect: NSRect) {
        statusHideWork?.cancel()
        contentView.mode = .status(text)
        present(at: cursorRect)
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        statusHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func hide() {
        statusHideWork?.cancel()
        panel.orderOut(nil)
    }

    private func present(at cursorRect: NSRect) {
        let size = contentView.layoutContent()
        let screen = NSScreen.screens.first { $0.frame.contains(cursorRect.origin) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var origin = NSPoint(x: cursorRect.minX, y: cursorRect.minY - size.height - 4)
        if origin.y < visible.minY {
            origin.y = cursorRect.maxY + 4  // flip above the line
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        contentView.needsDisplay = true
        panel.orderFrontRegardless()
    }
}

// MARK: - Drawing

private final class CandidateView: NSView {
    enum Mode {
        case candidates(RimeContextSnapshot, TranslationPreview?)
        case status(String)
    }

    var mode: Mode = .status("")
    var onSelect: ((Int) -> Void)?
    var onPage: ((Bool) -> Void)?

    private let padding = NSEdgeInsets(top: 6, left: 10, bottom: 7, right: 10)
    private let candidateSpacing: CGFloat = 14
    private let rowSpacing: CGFloat = 6
    private let cornerRadius: CGFloat = 8
    private let maxTranslationWidth: CGFloat = 440

    private let preeditFont = NSFont.systemFont(ofSize: 13)
    private let labelFont = NSFont.systemFont(ofSize: 13)
    private let textFont = NSFont.systemFont(ofSize: 17)
    private let commentFont = NSFont.systemFont(ofSize: 12)
    private let arrowFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    private let translationFont = NSFont.systemFont(ofSize: 15)
    private let badgeFont = NSFont.systemFont(ofSize: 10, weight: .bold)
    private let hintFont = NSFont.systemFont(ofSize: 11)

    private let hint = "⏎ 发英文 · ⌥⏎ 发中文 · Esc 中文上屏"
    private let badge = "EN"

    // Layout results, in view coordinates (flipped)
    private var preeditOrigin: NSPoint?
    private var candidateRects: [NSRect] = []
    private var prevRect = NSRect.zero
    private var nextRect = NSRect.zero
    private var separatorY: CGFloat?
    private var badgeRect = NSRect.zero
    private var translationRect = NSRect.zero
    private var hintOrigin = NSPoint.zero

    override var isFlipped: Bool { true }

    private var accent: NSColor { Brand.primary }

    /// Computes layout and returns the panel size
    func layoutContent() -> NSSize {
        preeditOrigin = nil
        candidateRects = []
        prevRect = .zero
        nextRect = .zero
        separatorY = nil
        translationRect = .zero

        switch mode {
        case .status(let text):
            let size = (text as NSString).size(withAttributes: [.font: textFont])
            return NSSize(width: max(size.width + 24, 36), height: size.height + 12)

        case .candidates(let ctx, let translation):
            var y = padding.top
            var contentWidth: CGFloat = 0

            if !ctx.preedit.isEmpty {
                let size = (ctx.preedit as NSString).size(withAttributes: [.font: preeditFont])
                preeditOrigin = NSPoint(x: padding.left, y: y)
                contentWidth = max(contentWidth, size.width)
                y += size.height + 3
            }

            if !ctx.candidates.isEmpty {
                let rowHeight = textFont.boundingRectForFont.height
                var x = padding.left
                for (i, cand) in ctx.candidates.enumerated() {
                    let width = candidateString(index: i, candidate: cand, highlighted: false).size().width
                    candidateRects.append(NSRect(x: x - 4, y: y - 1, width: width + 8, height: rowHeight + 2))
                    x += width + candidateSpacing
                }
                if ctx.pageNo > 0 || !ctx.isLastPage {
                    let arrowWidth = ("‹" as NSString).size(withAttributes: [.font: arrowFont]).width + 8
                    prevRect = NSRect(x: x, y: y, width: arrowWidth, height: rowHeight)
                    nextRect = NSRect(x: x + arrowWidth, y: y, width: arrowWidth, height: rowHeight)
                    x += arrowWidth * 2
                } else {
                    x -= candidateSpacing
                }
                contentWidth = max(contentWidth, x - padding.left)
                y += rowHeight
            }

            if let translation = translation {
                if y > padding.top {
                    y += rowSpacing / 2
                    separatorY = y
                    y += rowSpacing / 2 + 1
                }
                let badgeSize = (badge as NSString).size(withAttributes: [.font: badgeFont])
                badgeRect = NSRect(x: padding.left, y: y + 3, width: badgeSize.width + 8, height: badgeSize.height + 2)

                let textX = badgeRect.maxX + 6
                let bounds = translationString(translation).boundingRect(
                    with: NSSize(width: maxTranslationWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
                translationRect = NSRect(x: textX, y: y, width: ceil(bounds.width) + 2, height: ceil(bounds.height))
                contentWidth = max(contentWidth, translationRect.maxX - padding.left)
                y += translationRect.height + 4

                let hintSize = (hint as NSString).size(withAttributes: [.font: hintFont])
                hintOrigin = NSPoint(x: padding.left, y: y)
                contentWidth = max(contentWidth, hintSize.width)
                y += hintSize.height
            }

            return NSSize(width: max(contentWidth + padding.left + padding.right, 60),
                          height: y + padding.bottom)
        }
    }

    private func candidateString(index: Int, candidate: RimeCandidate, highlighted: Bool) -> NSAttributedString {
        let textColor: NSColor = highlighted ? accent : .labelColor
        let result = NSMutableAttributedString(
            string: "\(index + 1) ",
            attributes: [.font: labelFont, .foregroundColor: NSColor.secondaryLabelColor,
                         .baselineOffset: 1]
        )
        result.append(NSAttributedString(string: candidate.text,
                                         attributes: [.font: textFont, .foregroundColor: textColor]))
        if !candidate.comment.isEmpty {
            result.append(NSAttributedString(string: " " + candidate.comment,
                                             attributes: [.font: commentFont,
                                                          .foregroundColor: NSColor.tertiaryLabelColor,
                                                          .baselineOffset: 1]))
        }
        return result
    }

    private func translationString(_ translation: TranslationPreview) -> NSAttributedString {
        let text: String
        let color: NSColor
        switch translation.state {
        case .waiting:
            text = translation.text.isEmpty ? "翻译中…" : translation.text
            color = .secondaryLabelColor
        case .streaming:
            text = translation.text + " ▍"
            color = .labelColor
        case .done:
            text = translation.text
            color = .labelColor
        case .failed(let message):
            text = message
            color = .systemRed
        }
        return NSAttributedString(string: text, attributes: [.font: translationFont, .foregroundColor: color])
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                      xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.windowBackgroundColor.setFill()
        background.fill()
        NSColor.separatorColor.setStroke()
        background.lineWidth = 1
        background.stroke()

        switch mode {
        case .status(let text):
            let attrs: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: NSColor.labelColor]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                                y: (bounds.height - size.height) / 2),
                                    withAttributes: attrs)

        case .candidates(let ctx, let translation):
            if let origin = preeditOrigin {
                (ctx.preedit as NSString).draw(
                    at: origin,
                    withAttributes: [.font: preeditFont, .foregroundColor: NSColor.secondaryLabelColor]
                )
            }
            for (i, cand) in ctx.candidates.enumerated() where i < candidateRects.count {
                let isHighlighted = i == ctx.highlighted
                let rect = candidateRects[i]
                if isHighlighted {
                    accent.withAlphaComponent(0.12).setFill()
                    NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
                }
                candidateString(index: i, candidate: cand, highlighted: isHighlighted)
                    .draw(at: NSPoint(x: rect.minX + 4, y: rect.minY + 1))
            }
            if prevRect != .zero {
                drawArrow("‹", in: prevRect, enabled: ctx.pageNo > 0)
                drawArrow("›", in: nextRect, enabled: !ctx.isLastPage)
            }

            guard let translation = translation else { return }
            if let y = separatorY {
                NSColor.separatorColor.setFill()
                NSRect(x: padding.left, y: y, width: bounds.width - padding.left - padding.right, height: 1).fill()
            }
            accent.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3).fill()
            (badge as NSString).draw(at: NSPoint(x: badgeRect.minX + 4, y: badgeRect.minY + 1),
                                     withAttributes: [.font: badgeFont, .foregroundColor: NSColor.white])
            translationString(translation).draw(
                with: translationRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            (hint as NSString).draw(at: hintOrigin,
                                    withAttributes: [.font: hintFont, .foregroundColor: NSColor.tertiaryLabelColor])
        }
    }

    private func drawArrow(_ arrow: String, in rect: NSRect, enabled: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: arrowFont,
            .foregroundColor: enabled ? NSColor.labelColor : NSColor.quaternaryLabelColor,
        ]
        let size = (arrow as NSString).size(withAttributes: attrs)
        (arrow as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                                 withAttributes: attrs)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = candidateRects.firstIndex(where: { $0.contains(point) }) {
            onSelect?(index)
        } else if prevRect.contains(point) {
            onPage?(true)
        } else if nextRect.contains(point) {
            onPage?(false)
        }
    }
}
