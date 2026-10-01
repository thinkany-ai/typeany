// Thin C shim over librime's function-table API.
// Handles RIME_STRUCT initialisation and copies results into plain
// heap-allocated structs so Swift never touches librime-owned memory.
#ifndef TYPEANY_RIME_SHIM_H
#define TYPEANY_RIME_SHIM_H

#include <rime_api.h>
#include <stdlib.h>
#include <string.h>

static inline RimeApi *ta_api(void) {
    static RimeApi *api = NULL;
    if (!api) api = rime_get_api();
    return api;
}

static inline char *ta_strdup(const char *s) { return s ? strdup(s) : NULL; }

/// Set up and initialise librime, then run maintenance (deploy) synchronously.
static inline void ta_rime_start(const char *shared_dir, const char *user_dir,
                                 const char *log_dir, int full_check) {
    RIME_STRUCT(RimeTraits, traits);
    // librime may keep these pointers; they are intentionally never freed.
    traits.shared_data_dir = ta_strdup(shared_dir);
    traits.user_data_dir = ta_strdup(user_dir);
    traits.log_dir = ta_strdup(log_dir);
    traits.distribution_name = "TypeAny";
    traits.distribution_code_name = "TypeAny";
    traits.distribution_version = "1.0";
    traits.app_name = "rime.typeany";
    traits.min_log_level = 1;  // WARNING
    ta_api()->setup(&traits);
    ta_api()->initialize(&traits);
    if (ta_api()->start_maintenance(full_check)) {
        ta_api()->join_maintenance_thread();
    }
}

static inline void ta_rime_finalize(void) { ta_api()->finalize(); }

static inline RimeSessionId ta_create_session(void) { return ta_api()->create_session(); }
static inline void ta_destroy_session(RimeSessionId sid) { ta_api()->destroy_session(sid); }
static inline int ta_find_session(RimeSessionId sid) { return ta_api()->find_session(sid); }

static inline int ta_process_key(RimeSessionId sid, int keycode, int mask) {
    return ta_api()->process_key(sid, keycode, mask);
}

static inline void ta_clear_composition(RimeSessionId sid) { ta_api()->clear_composition(sid); }
static inline int ta_commit_composition(RimeSessionId sid) { return ta_api()->commit_composition(sid); }

static inline int ta_select_candidate_on_current_page(RimeSessionId sid, size_t index) {
    return ta_api()->select_candidate_on_current_page(sid, index);
}

static inline int ta_highlight_candidate_on_current_page(RimeSessionId sid, size_t index) {
    return ta_api()->highlight_candidate_on_current_page(sid, index);
}

static inline int ta_change_page(RimeSessionId sid, int backward) {
    return ta_api()->change_page(sid, backward);
}

static inline void ta_set_option(RimeSessionId sid, const char *option, int value) {
    ta_api()->set_option(sid, option, value);
}

static inline int ta_get_option(RimeSessionId sid, const char *option) {
    return ta_api()->get_option(sid, option);
}

/// Raw keys typed in the current composition, e.g. "nihao" (caller frees), or NULL.
static inline char *ta_get_input(RimeSessionId sid) {
    return ta_strdup(ta_api()->get_input(sid));
}

/// Returns committed text (caller frees with free()), or NULL if none.
static inline char *ta_get_commit(RimeSessionId sid) {
    RIME_STRUCT(RimeCommit, commit);
    char *result = NULL;
    if (ta_api()->get_commit(sid, &commit)) {
        result = ta_strdup(commit.text);
        ta_api()->free_commit(&commit);
    }
    return result;
}

typedef struct {
    char *preedit;        // UTF-8, may be NULL
    int cursor_pos;       // byte offset into preedit
    int num_candidates;
    char **texts;
    char **comments;
    int highlighted;
    int page_no;
    int is_last_page;
} TAContext;

/// Fills `out` with a heap copy of the current context. Free with ta_free_context.
static inline int ta_get_context(RimeSessionId sid, TAContext *out) {
    memset(out, 0, sizeof(*out));
    RIME_STRUCT(RimeContext, ctx);
    if (!ta_api()->get_context(sid, &ctx)) return 0;
    out->preedit = ta_strdup(ctx.composition.preedit);
    out->cursor_pos = ctx.composition.cursor_pos;
    out->num_candidates = ctx.menu.num_candidates;
    out->highlighted = ctx.menu.highlighted_candidate_index;
    out->page_no = ctx.menu.page_no;
    out->is_last_page = ctx.menu.is_last_page;
    if (ctx.menu.num_candidates > 0) {
        out->texts = calloc(ctx.menu.num_candidates, sizeof(char *));
        out->comments = calloc(ctx.menu.num_candidates, sizeof(char *));
        for (int i = 0; i < ctx.menu.num_candidates; i++) {
            out->texts[i] = ta_strdup(ctx.menu.candidates[i].text);
            out->comments[i] = ta_strdup(ctx.menu.candidates[i].comment);
        }
    }
    ta_api()->free_context(&ctx);
    return 1;
}

static inline void ta_free_context(TAContext *c) {
    for (int i = 0; i < c->num_candidates; i++) {
        free(c->texts[i]);
        free(c->comments[i]);
    }
    free(c->texts);
    free(c->comments);
    free(c->preedit);
    memset(c, 0, sizeof(*c));
}

typedef struct {
    int is_composing;
    int is_ascii_mode;
} TAStatus;

static inline TAStatus ta_get_status(RimeSessionId sid) {
    TAStatus s = {0, 0};
    RIME_STRUCT(RimeStatus, status);
    if (ta_api()->get_status(sid, &status)) {
        s.is_composing = status.is_composing;
        s.is_ascii_mode = status.is_ascii_mode;
        ta_api()->free_status(&status);
    }
    return s;
}

#endif
