import CRime
import Foundation

/// `TypeAny --self-test`: boots Rime from the bundle's own data in a scratch user directory
/// and checks pinyin and a lua-backed feature. Used by release.sh / CI to prove a packaged
/// app finds its bundled librime and plugins without Homebrew.
enum SelfTest {
    static func run() -> Int32 {
        guard let shared = RimeEngine.sharedDataDir else {
            print("✗ no rime-data in bundle")
            return 1
        }
        let user = FileManager.default.temporaryDirectory
            .appendingPathComponent("typeany-selftest-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: user) }

        ta_rime_start(shared.path, user.path, "", 0)
        let session = ta_create_session()
        var failures: Int32 = 0

        func first(_ keys: String) -> String {
            ta_clear_composition(session)
            keys.unicodeScalars.forEach { _ = ta_process_key(session, Int32($0.value), 0) }
            var ctx = TAContext()
            guard ta_get_context(session, &ctx) != 0 else { return "" }
            defer { ta_free_context(&ctx) }
            return ctx.num_candidates > 0 ? ctx.texts[0].map { String(cString: $0) } ?? "" : ""
        }

        func check(_ name: String, _ ok: Bool, _ detail: String) {
            print("\(ok ? "✓" : "✗") \(name): \(detail)")
            if !ok { failures += 1 }
        }

        let nihao = first("nihao")
        check("pinyin", nihao == "你好", "nihao → \(nihao)")
        let date = first("rq")
        check("lua plugin", date.hasPrefix("20"), "rq → \(date)")

        ta_destroy_session(session)
        ta_rime_finalize()
        return failures
    }
}
