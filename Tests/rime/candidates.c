// Candidate-order regression tests for the TypeAny pinyin schema.
// Run: make test-rime
#include "rime_shim.h"
#include <stdio.h>

static RimeSessionId session;
static int failures = 0;

static void type(const char *keys) {
    ta_clear_composition(session);
    for (const char *p = keys; *p; p++) ta_process_key(session, (unsigned char)*p, 0);
}

/// `input` must produce `expected` as the first candidate
static void expect_first(const char *input, const char *expected) {
    type(input);
    TAContext c;
    ta_get_context(session, &c);
    const char *first = c.num_candidates > 0 ? c.texts[0] : "(none)";
    int ok = strcmp(first, expected) == 0;
    printf("%s %-26s → %s%s%s\n", ok ? "✓" : "✗", input, first, ok ? "" : "   expected: ", ok ? "" : expected);
    if (!ok) failures++;
    ta_free_context(&c);
}

/// `input` must offer `expected` somewhere on the first page
static void expect_on_page(const char *input, const char *expected) {
    type(input);
    TAContext c;
    ta_get_context(session, &c);
    int found = 0;
    char page[256] = "";
    for (int i = 0; i < c.num_candidates; i++) {
        if (strcmp(c.texts[i], expected) == 0) found = 1;
        if (strlen(page) + strlen(c.texts[i]) + 2 < sizeof page) {
            strcat(page, c.texts[i]);
            strcat(page, " ");
        }
    }
    printf("%s %-26s ∋ %s   [%s]\n", found ? "✓" : "✗", input, expected, page);
    if (!found) failures++;
    ta_free_context(&c);
}

/// First candidate of `input` must start with `prefix` (e.g. a date)
static void expect_first_prefix(const char *input, const char *prefix, const char *label) {
    type(input);
    TAContext c;
    ta_get_context(session, &c);
    const char *first = c.num_candidates > 0 ? c.texts[0] : "(none)";
    int ok = strncmp(first, prefix, strlen(prefix)) == 0;
    printf("%s %-26s → %s   (%s)\n", ok ? "✓" : "✗", input, first, label);
    if (!ok) failures++;
    ta_free_context(&c);
}

/// Typing `key` with nothing composed commits `expected` (punctuation)
static void expect_commit(int key, int mask, const char *label, const char *expected) {
    ta_clear_composition(session);
    ta_process_key(session, key, mask);
    TAContext c;
    ta_get_context(session, &c);
    // punctuation with alternatives opens a menu; take its first entry
    char *commit = ta_get_commit(session);
    const char *got = commit ? commit : (c.num_candidates > 0 ? c.texts[0] : "(none)");
    int ok = strcmp(got, expected) == 0;
    printf("%s %-26s → %s%s%s\n", ok ? "✓" : "✗", label, got, ok ? "" : "   expected: ", ok ? "" : expected);
    if (!ok) failures++;
    free(commit);
    ta_free_context(&c);
}

/// Picking `word` for `input` a few times should promote it to the first candidate
static void expect_learns(const char *input, const char *word, int times) {
    for (int round = 0; round < times; round++) {
        type(input);
        TAContext c;
        ta_get_context(session, &c);
        int index = -1;
        for (int i = 0; i < c.num_candidates; i++) {
            if (strcmp(c.texts[i], word) == 0) { index = i; break; }
        }
        ta_free_context(&c);
        if (index < 0) {
            printf("✗ %-26s → %s not on first page\n", input, word);
            failures++;
            return;
        }
        ta_select_candidate_on_current_page(session, index);
        free(ta_get_commit(session));
    }
    char label[64];
    snprintf(label, sizeof label, "%s (after picking ×%d)", input, times);
    type(input);
    TAContext c;
    ta_get_context(session, &c);
    const char *first = c.num_candidates > 0 ? c.texts[0] : "(none)";
    int ok = strcmp(first, word) == 0;
    printf("%s %-26s → %s%s%s\n", ok ? "✓" : "✗", label, first, ok ? "" : "   expected: ", ok ? "" : word);
    if (!ok) failures++;
    ta_free_context(&c);
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s <shared_data_dir> <user_data_dir>\n", argv[0]); return 2; }
    ta_rime_start(argv[1], argv[2], "", 0);
    session = ta_create_session();

    // high-frequency abbreviations (typeany_phrase.txt)
    expect_first("s", "是");
    expect_first("d", "的");
    expect_first("w", "我");
    expect_first("sh", "时候");
    expect_first("wm", "我们");
    expect_first("zm", "怎么");
    expect_first("wsm", "为什么");
    // full pinyin still goes through the dictionary
    expect_first("shi", "是");
    expect_first("nihao", "你好");
    expect_first("shihou", "时候");
    expect_first("zhongguoren", "中国人");
    expect_first("jintiantianqizenmeyang", "今天天气怎么样");
    // rime-ice features (lua scripts, English, emoji)
    expect_first_prefix("rq", "20", "lua: date");
    expect_on_page("hello", "hello");
    expect_on_page("github", "GitHub");
    expect_on_page("xiaoku", "😂");
    expect_on_page("haha", "哈哈");

    // user habits: the user dictionary promotes what you pick
    expect_learns("shiyan", "实验", 1);
    expect_learns("shiyan", "试验", 2);
    expect_learns("xiangmu", "项目", 1);

    // Last-choice memory relies on: highlight a candidate → Space commits it
    type("m");
    {
        TAContext c;
        ta_get_context(session, &c);
        int index = -1;
        for (int i = 0; i < c.num_candidates; i++) if (strcmp(c.texts[i], "吗") == 0) index = i;
        ta_free_context(&c);
        ta_highlight_candidate_on_current_page(session, index);
        ta_process_key(session, ' ', 0);
        char *commit = ta_get_commit(session);
        int ok = index > 0 && commit && strcmp(commit, "吗") == 0;
        printf("%s %-26s → %s\n", ok ? "✓" : "✗", "m: highlight 吗 + space", commit ? commit : "(none)");
        if (!ok) failures++;
        free(commit);
    }

    // Shift 中/英: TypeAny sets ascii_mode; letters must then pass straight through
    type("nihao");
    char *raw = ta_get_input(session);
    int raw_ok = raw && strcmp(raw, "nihao") == 0;
    printf("%s %-26s → %s\n", raw_ok ? "✓" : "✗", "raw input of nihao", raw ? raw : "(null)");
    if (!raw_ok) failures++;
    free(raw);
    ta_clear_composition(session);
    ta_set_option(session, "ascii_mode", 1);
    int handled = ta_process_key(session, 'a', 0);
    printf("%s %-26s → %s\n", !handled ? "✓" : "✗", "ascii mode: 'a'", handled ? "captured by Rime" : "passed through");
    if (handled) failures++;
    ta_set_option(session, "ascii_mode", 0);

    // "." after pinyin, once TypeAny resolves it as 句号: candidate + 。
    type("nihao");
    ta_process_key(session, '.', 0);
    {
        char *commit = ta_get_commit(session);
        int ok = commit && strcmp(commit, "你好。") == 0;
        printf("%s %-26s → %s\n", ok ? "✓" : "✗", "nihao + .", commit ? commit : "(none)");
        if (!ok) failures++;
        free(commit);
    }
    // www. stays raw in Rime itself (rime-ice url pattern)
    type("www.baidu.com");
    {
        char *raw = ta_get_input(session);
        int ok = raw && strcmp(raw, "www.baidu.com") == 0;
        printf("%s %-26s → %s\n", ok ? "✓" : "✗", "www.baidu.com composing", raw ? raw : "(none)");
        if (!ok) failures++;
        free(raw);
    }

    // Chinese punctuation (shift mask = 1)
    expect_commit('?', 1, "⇧/  (question mark)", "？");
    expect_commit('!', 1, "⇧1  (exclamation)", "！");
    expect_commit(',', 0, ",", "，");
    expect_commit('.', 0, ".", "。");

    ta_destroy_session(session);
    ta_rime_finalize();
    printf("\n%s (%d failed)\n", failures ? "FAILED" : "PASSED", failures);
    return failures ? 1 : 0;
}
