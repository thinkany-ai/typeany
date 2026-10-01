import Foundation
import CRime

/// Process-wide librime lifecycle. Data layout:
/// - shared: TypeAny.app/Contents/SharedSupport/rime-data (read-only schema, dicts, prebuilt bins)
/// - user:   <AppVariant.dataDirectory>/Rime (user dict, learned word frequencies)
final class RimeEngine {
    static let shared = RimeEngine()

    private(set) var isReady = false

    private init() {}

    static var userDataDir: URL {
        AppVariant.dataDirectory.appendingPathComponent("Rime", isDirectory: true)
    }

    static var sharedDataDir: URL? {
        Bundle.main.sharedSupportURL?.appendingPathComponent("rime-data", isDirectory: true)
    }

    func start() {
        guard !isReady else { return }
        guard let shared = Self.sharedDataDir,
              FileManager.default.fileExists(atPath: shared.path) else {
            print("[TypeAny] Rime data not found in bundle; pinyin input disabled")
            return
        }
        let user = Self.userDataDir
        try? FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        let logDir = user.appendingPathComponent("log")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        ta_rime_start(shared.path, user.path, logDir.path, 0)
        isReady = true
    }

    func stop() {
        guard isReady else { return }
        isReady = false
        ta_rime_finalize()
    }

    func createSession() -> RimeSession? {
        guard isReady else { return nil }
        let id = ta_create_session()
        return id == 0 ? nil : RimeSession(id: id)
    }
}

struct RimeCandidate {
    let text: String
    let comment: String
}

struct RimeContextSnapshot {
    var preedit = ""
    /// Cursor position as a String (Character) offset into `preedit`
    var cursor = 0
    var candidates: [RimeCandidate] = []
    var highlighted = 0
    var pageNo = 0
    var isLastPage = true
}

final class RimeSession {
    let id: RimeSessionId

    init(id: RimeSessionId) {
        self.id = id
    }

    deinit {
        if RimeEngine.shared.isReady {
            ta_destroy_session(id)
        }
    }

    /// librime may drop sessions (e.g. after redeploy); recreate transparently.
    var isAlive: Bool { ta_find_session(id) != 0 }

    func processKey(_ keycode: Int32, mask: Int32) -> Bool {
        ta_process_key(id, keycode, mask) != 0
    }

    func clearComposition() {
        ta_clear_composition(id)
    }

    func commitComposition() {
        _ = ta_commit_composition(id)
    }

    func selectCandidate(onCurrentPage index: Int) -> Bool {
        ta_select_candidate_on_current_page(id, index) != 0
    }

    /// Moves the highlight, so Space / confirm commits this candidate
    func highlightCandidate(onCurrentPage index: Int) -> Bool {
        ta_highlight_candidate_on_current_page(id, index) != 0
    }

    func changePage(backward: Bool) -> Bool {
        ta_change_page(id, backward ? 1 : 0) != 0
    }

    var isAsciiMode: Bool {
        get { ta_get_option(id, "ascii_mode") != 0 }
        set { ta_set_option(id, "ascii_mode", newValue ? 1 : 0) }
    }

    var isComposing: Bool {
        ta_get_status(id).is_composing != 0
    }

    /// Raw keys of the current composition ("nihao"), as opposed to the formatted preedit
    var rawInput: String {
        guard let ptr = ta_get_input(id) else { return "" }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    func takeCommit() -> String? {
        guard let ptr = ta_get_commit(id) else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    func context() -> RimeContextSnapshot {
        var raw = TAContext()
        guard ta_get_context(id, &raw) != 0 else { return RimeContextSnapshot() }
        defer { ta_free_context(&raw) }

        var snapshot = RimeContextSnapshot()
        if let preeditPtr = raw.preedit {
            let bytes = UnsafeBufferPointer(start: UnsafeRawPointer(preeditPtr).assumingMemoryBound(to: UInt8.self),
                                            count: strlen(preeditPtr))
            snapshot.preedit = String(decoding: bytes, as: UTF8.self)
            // cursor_pos is a UTF-8 byte offset; convert to Character offset
            let cursorBytes = max(0, min(Int(raw.cursor_pos), bytes.count))
            snapshot.cursor = String(decoding: bytes.prefix(cursorBytes), as: UTF8.self).count
        }
        for i in 0..<Int(raw.num_candidates) {
            let text = raw.texts[i].map { String(cString: $0) } ?? ""
            let comment = raw.comments[i].map { String(cString: $0) } ?? ""
            snapshot.candidates.append(RimeCandidate(text: text, comment: comment))
        }
        snapshot.highlighted = Int(raw.highlighted)
        snapshot.pageNo = Int(raw.page_no)
        snapshot.isLastPage = raw.is_last_page != 0
        return snapshot
    }
}
