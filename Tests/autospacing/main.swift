// Unit tests for AutoSpacing (中英文自动空格). Run: make test-spacing
import Foundation
var failures = 0
func check(_ text: String, after prev: Character?, _ expected: String) {
    let got = AutoSpacing.spaced(text, after: prev)
    let ok = got == expected
    if !ok { failures += 1 }
    print(ok ? "✓" : "✗", "'\(prev.map(String.init) ?? "⌀")' + '\(text)' → '\(got)'", ok ? "" : "expected '\(expected)'")
}
check("GitHub", after: "用", " GitHub")     // 中 → 英
check("写代码", after: "b", " 写代码")        // 英 → 中
check("写代码", after: "5", " 写代码")        // 数字 → 中
check("hello", after: nil, "hello")          // start of field
check("hello", after: " ", "hello")          // already spaced
check("hello", after: "，", "hello")         // after Chinese punctuation: no space
check("，", after: "b", "，")                 // punctuation after English: no space
check("。", after: "b", "。")
check("你好", after: "，", "你好")
check("baidu.com", after: "开", " baidu.com")
check(",", after: "我", ",")                  // ASCII punctuation isn't English text
check("你好", after: "!", "你好")
check("GitHub", after: "a", "GitHub")         // English after English: untouched
print(failures == 0 ? "PASSED" : "FAILED (\(failures))")
if failures > 0 { exit(1) }
