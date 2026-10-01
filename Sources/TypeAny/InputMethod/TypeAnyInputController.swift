import Cocoa
import InputMethodKit

/// Shared state between the IMK controllers and the voice pipeline in AppDelegate.
enum InputMethodState {
    /// Controller for the text field currently focused with TypeAny as input source
    static weak var activeController: TypeAnyInputController?
    static var openSettings: (() -> Void)?
    static var openOnboarding: (() -> Void)?
    /// 中→EN mode: committed Chinese collects in a draft and is sent as English on Return
    static var translateMode = false
    /// 英文模式 (Shift toggles). Global like WeChat IME, not per text field.
    static var asciiMode = false
}

/// One instance per client text field. Feeds keystrokes to a Rime session,
/// renders the preedit as marked text and candidates in `CandidatePanel`,
/// and accepts voice transcription as marked text → committed text.
///
/// In translate mode, text Rime commits is held in `draft` (shown as marked text)
/// and translated in the background; Return commits the English, ⌥Return or Esc
/// commits the Chinese.
@objc(TypeAnyInputController)
final class TypeAnyInputController: IMKInputController {
    private static let translator = Translator()

    private var session: RimeSession?
    private var isVoiceActive = false

    /// Last text we inserted; the auto-spacing fallback when a client hides its contents.
    /// Cleared whenever a key goes straight to the app, since it may no longer be adjacent.
    private var lastCommitted = ""

    /// Next-word suggestions (联想) shown after a commit; 1–5 picks one, any other key dismisses
    private var predictions: [String] = []

    // Last-choice memory (SelectionMemory): the remembered candidate is moved to the front.
    /// Display position → Rime's index on the current page, when reordered
    private var candidateOrder: [Int]?
    /// Candidate texts as currently shown, to tell a real pick from other commits
    private var shownCandidates: [String] = []
    /// Code we already auto-highlighted for, so arrow-key navigation isn't overridden
    private var autoHighlightedCode: String?
    /// Input code + shown candidates captured just before a key that may select one
    private var pendingSelection: (code: String, candidates: [String])?

    // Domains typed in Chinese mode (baidu.com): "." after pinyin waits for the next key —
    // a letter means a domain (kept as raw ASCII), anything else means 句号 (百度。).
    private var pendingDot = false
    /// Raw ASCII being typed as a domain/URL, shown as marked text until confirmed
    private var domainBuffer: String?

    // Shift tap → 中/英 toggle. A tap only counts if nothing else was pressed in between
    // and it was quick, so Shift+click / Shift+drag selections don't flip the mode.
    private var shiftDownAt: Date?
    private var shiftUsedWithOtherKey = false
    private let shiftTapMaxDuration: TimeInterval = 0.5

    // Translate mode
    private var draft = ""
    private var translation: TranslationPreview?
    /// Draft text the current `.done` translation corresponds to
    private var translatedDraft: String?
    private var translateTask: Task<Void, Never>?
    private var commitWhenTranslated = false

    private let notFound = NSRange(location: NSNotFound, length: 0)
    private let translateDebounce: UInt64 = 400_000_000  // ns
    private var panel: CandidatePanel { .shared }

    private var isDrafting: Bool { InputMethodState.translateMode && !draft.isEmpty }

    // MARK: - Lifecycle

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        InputMethodState.activeController = self
        lastCommitted = ""
        // Carry the global 中/英 state into this field's session
        if let session = ensureSession(), session.isAsciiMode != InputMethodState.asciiMode {
            session.isAsciiMode = InputMethodState.asciiMode
        }
    }

    override func deactivateServer(_ sender: Any!) {
        commitPendingComposition(sender)
        panel.hide()
        if InputMethodState.activeController === self {
            InputMethodState.activeController = nil
        }
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        commitPendingComposition(sender)
    }

    private func ensureSession() -> RimeSession? {
        if let session = session, session.isAlive { return session }
        session = RimeEngine.shared.createSession()
        return session
    }

    private func textClient(_ sender: Any?) -> (IMKTextInput & NSObjectProtocol)? {
        (sender as? IMKTextInput & NSObjectProtocol) ?? client()
    }

    // MARK: - Key Handling

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event,
              !isVoiceActive,
              let client = textClient(sender),
              let session = ensureSession() else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.type {
        case .flagsChanged:
            if event.keyCode == 56 || event.keyCode == 60 {  // left / right Shift
                handleShift(isDown: modifiers.contains(.shift), modifiers: modifiers,
                            session: session, client: client)
            } else if shiftDownAt != nil {
                shiftUsedWithOtherKey = true  // e.g. ⇧⌘ chord
            }
            // Never swallow modifier events; apps still need them
            return false

        case .keyDown:
            if shiftDownAt != nil { shiftUsedWithOtherKey = true }  // ⇧A, ⇧/ …
            // ⌃⇧T toggles translate mode
            if event.keyCode == 17, modifiers == [.control, .shift] {
                toggleTranslateMode(client: client)
                return true
            }
            // Leave app shortcuts alone
            if modifiers.contains(.command) {
                lastCommitted = ""
                dismissPredictions()
                return false
            }

            if let handled = handleDomainKey(event, modifiers: modifiers, session: session, client: client) {
                return handled
            }

            if !predictions.isEmpty && !session.isComposing {
                if let handled = handlePredictionKey(event, modifiers: modifiers, client: client) {
                    return handled
                }
                // Any other key: drop the suggestions and handle the key normally
                dismissPredictions()
            }

            if isDrafting && !session.isComposing,
               let handled = handleDraftKey(event, modifiers: modifiers, session: session, client: client) {
                return handled
            }

            if session.isComposing,
               let handled = handleReorderedDigit(event, modifiers: modifiers, session: session, client: client) {
                return handled
            }

            guard let keysym = RimeKeyMapper.keysym(for: event) else { return isDrafting }
            if session.isComposing {
                pendingSelection = (session.rawInput, shownCandidates)
            }
            var handled = session.processKey(keysym, mask: RimeKeyMapper.mask(for: modifiers))

            // Keys Rime passes through (space, ASCII-mode letters…) belong to the draft too,
            // otherwise they'd land in the field outside the marked text.
            if !handled, isDrafting, !modifiers.contains(.control),
               let chars = event.characters, !chars.isEmpty,
               chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7f }) {
                appendToDraft(chars)
                handled = true
            }
            sync(session: session, client: client)
            if !handled {
                lastCommitted = ""  // the app typed this key itself
            }
            return handled

        default:
            return false
        }
    }

    // MARK: - Domains (baidu.com)

    private static let domainCharacters = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_/:?=&#%~+@")

    /// Returns nil to let the key continue through normal handling.
    private func handleDomainKey(_ event: NSEvent, modifiers: NSEvent.ModifierFlags,
                                 session: RimeSession, client: IMKTextInput & NSObjectProtocol) -> Bool? {
        let plainKey = modifiers.isDisjoint(with: [.control, .option, .command])
        let chars = event.characters ?? ""

        // Typing a domain: collect ASCII until a confirming / unrelated key
        if var buffer = domainBuffer {
            switch event.keyCode {
            case 51:  // BackSpace
                buffer.removeLast()
                domainBuffer = buffer.isEmpty ? nil : buffer
                render(session: session, client: client)
                return true
            case 53:  // Escape cancels
                domainBuffer = nil
                render(session: session, client: client)
                return true
            default:
                break
            }
            if plainKey, chars.count == 1, chars.unicodeScalars.allSatisfy(Self.domainCharacters.contains) {
                domainBuffer = buffer + chars
                render(session: session, client: client)
                return true
            }
            domainBuffer = nil
            commitText(buffer, client: client)
            render(session: session, client: client)
            // Space / Return just confirm the domain; other keys (punctuation …) still apply
            return [36, 49, 76].contains(event.keyCode) ? true : nil
        }

        // "." is pending: a letter makes it a domain, anything else a full stop
        if pendingDot {
            pendingDot = false
            if plainKey, chars.count == 1, chars.unicodeScalars.allSatisfy(CharacterSet.letters.contains),
               chars.unicodeScalars.allSatisfy({ $0.isASCII }) {
                domainBuffer = session.rawInput + "." + chars
                session.clearComposition()
                render(session: session, client: client)
                return true
            }
            resolvePendingDot(session: session, client: client)
            return nil
        }

        // "." right after pinyin letters: hold it until the next key
        if chars == ".", modifiers.isDisjoint(with: [.control, .option, .command, .shift]),
           session.isComposing, !session.isAsciiMode,
           session.rawInput.range(of: "^[a-z]+$", options: .regularExpression) != nil {
            pendingDot = true
            render(session: session, client: client)
            return true
        }
        return nil
    }

    /// Treat a held "." as 句号: Rime commits the candidate and punctuates as usual.
    private func resolvePendingDot(session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        pendingDot = false
        _ = session.processKey(Int32(UnicodeScalar(".").value), mask: 0)
        sync(session: session, client: client)
    }

    // MARK: - 中/英 (Shift)

    private func handleShift(isDown: Bool, modifiers: NSEvent.ModifierFlags,
                             session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        if isDown {
            shiftDownAt = Date()
            shiftUsedWithOtherKey = !modifiers.isDisjoint(with: [.command, .control, .option])
            return
        }
        guard let downAt = shiftDownAt else { return }
        shiftDownAt = nil
        guard !shiftUsedWithOtherKey,
              Date().timeIntervalSince(downAt) < shiftTapMaxDuration else { return }
        toggleAsciiMode(session: session, client: client)
    }

    private func toggleAsciiMode(session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        dismissPredictions()
        if let buffer = domainBuffer {
            domainBuffer = nil
            commitText(buffer, client: client)
        }
        pendingDot = false
        // Like WeChat IME: switching mid-pinyin commits the typed letters as English
        if session.isComposing {
            let raw = session.rawInput
            session.clearComposition()
            if !raw.isEmpty {
                commitText(raw, client: client)
            }
        }
        InputMethodState.asciiMode.toggle()
        session.isAsciiMode = InputMethodState.asciiMode
        render(session: session, client: client)
        panel.showStatus(InputMethodState.asciiMode ? "英" : "中", cursorRect: cursorRect(client))
    }

    /// Digits pick a prediction, Esc dismisses; nil lets the key through.
    private func handlePredictionKey(_ event: NSEvent, modifiers: NSEvent.ModifierFlags,
                                     client: IMKTextInput & NSObjectProtocol) -> Bool? {
        guard modifiers.isDisjoint(with: [.control, .option, .shift]) else { return nil }
        if event.keyCode == 53 {  // Escape
            dismissPredictions()
            refreshUI()
            return true
        }
        if let digit = event.characters.flatMap(Int.init), (1...predictions.count).contains(digit) {
            commitPrediction(at: digit - 1, client: client)
            return true
        }
        return nil
    }

    /// Keys acting on the whole draft while no pinyin is being composed.
    /// Returns nil to fall through to Rime.
    private func handleDraftKey(_ event: NSEvent, modifiers: NSEvent.ModifierFlags,
                                session: RimeSession, client: IMKTextInput & NSObjectProtocol) -> Bool? {
        switch event.keyCode {
        case 36, 76:  // Return / Enter
            if modifiers.contains(.option) {
                commitDraft(english: false, client: client)
            } else {
                requestEnglishCommit(client: client)
            }
            return true
        case 53:  // Escape
            commitDraft(english: false, client: client)
            return true
        case 51:  // BackSpace
            draft.removeLast()
            draftDidChange()
            render(session: session, client: client)
            return true
        case 48, 115, 116, 117, 119, 121, 123, 124, 125, 126:
            // Tab / navigation would move the caret out of the marked draft
            return true
        default:
            return nil
        }
    }

    /// Push Rime's commit / composition / menu state out to the client and panel.
    private func sync(session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        let selection = pendingSelection
        pendingSelection = nil
        if let commit = session.takeCommit() {
            // A whole-composition pick of a shown candidate is remembered for next time
            if let selection = selection, !session.isComposing, selection.candidates.contains(commit) {
                SelectionMemory.shared.record(code: selection.code, text: commit)
            }
            commitText(commit, client: client)
            predictions = PreferencesManager.shared.predictionEnabled
                ? PredictionEngine.shared.predict(after: commit) : []
        }
        render(session: session, client: client)
    }

    /// With a reordered page, digit N means the Nth candidate as displayed.
    private func handleReorderedDigit(_ event: NSEvent, modifiers: NSEvent.ModifierFlags,
                                      session: RimeSession, client: IMKTextInput & NSObjectProtocol) -> Bool? {
        guard let order = candidateOrder,
              modifiers.isDisjoint(with: [.control, .option, .command, .shift]),
              let digit = event.characters.flatMap(Int.init),
              (1...order.count).contains(digit) else { return nil }
        selectDisplayed(at: digit - 1, session: session, client: client)
        return true
    }

    private func selectDisplayed(at index: Int, session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        let rimeIndex = candidateOrder?[safe: index] ?? index
        pendingSelection = (session.rawInput, shownCandidates)
        _ = session.selectCandidate(onCurrentPage: rimeIndex)
        sync(session: session, client: client)
    }

    /// Committed text goes into the translate draft in translate mode, else straight to the field.
    private func commitText(_ text: String, client: IMKTextInput & NSObjectProtocol) {
        let autoSpacing = PreferencesManager.shared.autoSpacingEnabled
        if InputMethodState.translateMode {
            appendToDraft(autoSpacing ? AutoSpacing.spaced(text, after: draft.last) : text)
            return
        }
        let output = autoSpacing ? AutoSpacing.spaced(text, after: characterBeforeInsertion(client)) : text
        client.insertText(output, replacementRange: notFound)
        lastCommitted = output
    }

    /// The character the commit will follow: just before the marked pinyin (which it replaces),
    /// else before the caret. Clients that don't expose their text fall back to our last commit.
    private func characterBeforeInsertion(_ client: IMKTextInput & NSObjectProtocol) -> Character? {
        let marked = client.markedRange()
        let location = marked.location != NSNotFound ? marked.location : client.selectedRange().location
        if location != NSNotFound, location > 0,
           let text = client.attributedSubstring(from: NSRange(location: location - 1, length: 1))?.string,
           let previous = text.last {
            return previous
        }
        return lastCommitted.last
    }

    private func commitPrediction(at index: Int, client: IMKTextInput & NSObjectProtocol) {
        guard predictions.indices.contains(index) else { return }
        let word = predictions[index]
        commitText(word, client: client)
        // Keep suggesting, like 谢谢 → 大家 → 的
        predictions = PredictionEngine.shared.predict(after: word)
        refreshUI()
    }

    private func dismissPredictions() {
        guard !predictions.isEmpty else { return }
        predictions = []
    }

    private func render(session: RimeSession, client: IMKTextInput & NSObjectProtocol) {
        let draftPrefix = isDrafting ? draft : ""
        if let buffer = domainBuffer {
            setMarked(draftPrefix + buffer, cursor: draftPrefix.count + buffer.count, client: client)
            panel.hide()
            return
        }

        var ctx = session.context()
        if pendingDot {
            // Show the raw letters plus the dot; candidates stay for the 句号 case
            ctx.preedit = session.rawInput + "."
            ctx.cursor = ctx.preedit.count
        }
        let showingPredictions = ctx.preedit.isEmpty && ctx.candidates.isEmpty && !predictions.isEmpty
        if showingPredictions {
            ctx.candidates = predictions.map { RimeCandidate(text: $0, comment: "") }
            ctx.highlighted = -1
            ctx.pageNo = 0
            ctx.isLastPage = true
        }
        applySelectionMemory(to: &ctx, session: session, enabled: !showingPredictions)
        let showDraft = isDrafting
        guard !ctx.preedit.isEmpty || !ctx.candidates.isEmpty || showDraft else {
            setMarked("", cursor: 0, client: client)
            panel.hide()
            return
        }

        let prefix = showDraft ? draft : ""
        setMarked(prefix + ctx.preedit, cursor: prefix.count + ctx.cursor, client: client)

        // Pinyin is already shown inline as marked text; the panel lists candidates only
        var panelContext = ctx
        panelContext.preedit = ""
        panel.onSelect = { [weak self, weak client] index in
            guard let self = self, let client = client, let session = self.session else { return }
            if showingPredictions {
                self.commitPrediction(at: index, client: client)
            } else {
                self.selectDisplayed(at: index, session: session, client: client)
            }
        }
        panel.onPage = { [weak self, weak client] backward in
            guard let self = self, let client = client, let session = self.session else { return }
            _ = session.changePage(backward: backward)
            self.sync(session: session, client: client)
        }
        if ctx.candidates.isEmpty && !showDraft {
            panel.hide()
        } else {
            let preview = showDraft ? (translation ?? TranslationPreview(text: "", state: .waiting)) : nil
            panel.show(context: panelContext, translation: preview, cursorRect: cursorRect(client))
        }
    }

    /// Puts the candidate last picked for this code first, and highlights it in Rime
    /// so Space commits it too.
    private func applySelectionMemory(to ctx: inout RimeContextSnapshot, session: RimeSession, enabled: Bool) {
        candidateOrder = nil
        defer { shownCandidates = ctx.candidates.map(\.text) }
        guard enabled, session.isComposing else {
            autoHighlightedCode = nil
            return
        }
        let code = session.rawInput
        guard ctx.pageNo == 0,
              let preferred = SelectionMemory.shared.preferred(for: code),
              let index = ctx.candidates.firstIndex(where: { $0.text == preferred }),
              index > 0 else { return }

        if autoHighlightedCode != code {
            autoHighlightedCode = code
            if session.highlightCandidate(onCurrentPage: index) {
                ctx.highlighted = index
            }
        }
        var order = Array(ctx.candidates.indices)
        order.remove(at: index)
        order.insert(index, at: 0)
        candidateOrder = order
        ctx.candidates = order.map { ctx.candidates[$0] }
        ctx.highlighted = order.firstIndex(of: ctx.highlighted) ?? 0
    }

    private func refreshUI() {
        // Don't clobber the streaming voice text with a late translation update
        guard !isVoiceActive, let client = client(), let session = ensureSession() else { return }
        render(session: session, client: client)
    }

    private func commitPendingComposition(_ sender: Any?) {
        predictions = []
        guard let client = textClient(sender) else { return }
        if let buffer = domainBuffer {
            domainBuffer = nil
            commitText(buffer, client: client)
        }
        if pendingDot, let session = session {
            resolvePendingDot(session: session, client: client)
        }
        if let session = session, session.isComposing {
            session.commitComposition()
            sync(session: session, client: client)
        }
        if !draft.isEmpty {
            // Losing focus mid-draft: keep what the user wrote
            commitDraft(english: false, client: client)
        }
    }

    // MARK: - Translate Mode

    private func toggleTranslateMode(client: IMKTextInput & NSObjectProtocol) {
        InputMethodState.translateMode.toggle()
        if !InputMethodState.translateMode && !draft.isEmpty {
            commitDraft(english: false, client: client)
        }
        panel.showStatus(InputMethodState.translateMode ? "中→EN 翻译" : "翻译关闭", cursorRect: cursorRect(client))
    }

    private func appendToDraft(_ text: String) {
        draft += text
        draftDidChange()
    }

    /// Restart the debounced, streaming translation for the current draft.
    private func draftDidChange() {
        translateTask?.cancel()
        translateTask = nil
        commitWhenTranslated = false
        translatedDraft = nil

        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translation = nil
            return
        }
        // Keep the stale English (greyed) until the new one streams in
        translation = TranslationPreview(text: translation?.text ?? "", state: .waiting)

        let source = draft
        translateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.translateDebounce ?? 0)
            guard let self = self, !Task.isCancelled, self.draft == source else { return }
            do {
                let result = try await Self.translator.translate(source) { [weak self] partial in
                    guard let self = self, !Task.isCancelled, self.draft == source else { return }
                    self.translation = TranslationPreview(text: partial, state: .streaming)
                    self.refreshUI()
                }
                guard !Task.isCancelled, self.draft == source else { return }
                self.translation = TranslationPreview(text: result, state: .done)
                self.translatedDraft = source
                if self.commitWhenTranslated, let client = self.client() {
                    self.commitDraft(english: true, client: client)
                } else {
                    self.refreshUI()
                }
            } catch {
                guard !Task.isCancelled, self.draft == source else { return }
                self.translation = TranslationPreview(text: "", state: .failed(error.localizedDescription))
                self.commitWhenTranslated = false
                self.refreshUI()
            }
        }
    }

    /// Return pressed: commit English now if ready, otherwise as soon as it arrives.
    private func requestEnglishCommit(client: IMKTextInput & NSObjectProtocol) {
        if translatedDraft == draft, let text = translation?.text, !text.isEmpty {
            commitDraft(english: true, client: client)
            return
        }
        if case .failed = translation?.state {
            draftDidChange()  // retry
        }
        commitWhenTranslated = true
    }

    private func commitDraft(english: Bool, client: IMKTextInput & NSObjectProtocol) {
        let text = english ? (translation?.text ?? draft) : draft
        translateTask?.cancel()
        translateTask = nil
        draft = ""
        translation = nil
        translatedDraft = nil
        commitWhenTranslated = false
        // insertText replaces the marked draft
        client.insertText(text, replacementRange: notFound)
        if let session = session {
            render(session: session, client: client)
        } else {
            panel.hide()
        }
    }

    // MARK: - Marked Text

    private func setMarked(_ text: String, cursor: Int, client: IMKTextInput & NSObjectProtocol) {
        let attributed = NSAttributedString(string: text, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .markedClauseSegment: 0,
        ])
        let utf16Cursor = String(text.prefix(cursor)).utf16.count
        client.setMarkedText(attributed,
                             selectionRange: NSRange(location: utf16Cursor, length: 0),
                             replacementRange: notFound)
    }

    private func cursorRect(_ client: IMKTextInput & NSObjectProtocol) -> NSRect {
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        if rect == .zero {
            // Some clients don't report a caret rect; fall back to the mouse location
            let mouse = NSEvent.mouseLocation
            rect = NSRect(x: mouse.x, y: mouse.y, width: 0, height: 16)
        }
        return rect
    }

    // MARK: - Voice Input

    /// Clears any pending pinyin and takes over the field for voice output.
    func beginVoice() {
        isVoiceActive = true
        predictions = []
        pendingDot = false
        domainBuffer = nil
        session?.clearComposition()
        panel.hide()
        if let client = client() {
            setMarked(isDrafting ? draft : "", cursor: draft.count, client: client)
        }
    }

    /// Streaming transcription shown inline as underlined marked text.
    func showVoicePartial(_ text: String) {
        guard isVoiceActive, let client = client() else { return }
        let prefix = isDrafting ? draft : ""
        setMarked(prefix + text, cursor: prefix.count + text.count, client: client)
    }

    func commitVoice(_ text: String) {
        isVoiceActive = false
        guard let client = client() else { return }
        if InputMethodState.translateMode {
            // Spoken Chinese joins the draft; Return sends the English
            appendToDraft(text)
            refreshUI()
        } else {
            // insertText replaces the current marked text
            client.insertText(text, replacementRange: notFound)
        }
    }

    func cancelVoice() {
        isVoiceActive = false
        refreshUI()
    }

    // MARK: - Input Menu

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let translate = NSMenuItem(title: "翻译模式（中→EN）⌃⇧T", action: #selector(toggleTranslateFromMenu(_:)),
                                   keyEquivalent: "")
        translate.target = self
        translate.state = InputMethodState.translateMode ? .on : .off
        menu.addItem(translate)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "TypeAny 设置…", action: #selector(openSettings(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        let guide = NSMenuItem(title: "使用引导…", action: #selector(openOnboarding(_:)), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        return menu
    }

    @objc private func toggleTranslateFromMenu(_ sender: Any?) {
        guard let client = client() else {
            InputMethodState.translateMode.toggle()
            return
        }
        toggleTranslateMode(client: client)
    }

    @objc private func openSettings(_ sender: Any?) {
        InputMethodState.openSettings?()
    }

    @objc private func openOnboarding(_ sender: Any?) {
        InputMethodState.openOnboarding?()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
