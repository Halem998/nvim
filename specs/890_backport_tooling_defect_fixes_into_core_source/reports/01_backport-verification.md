# Research Report: Task #890

**Task**: 890 - Back-port review-2026-07-16 tooling-defect fixes into core extension source
**Started**: 2026-07-18T20:36:43Z
**Completed**: 2026-07-18T21:20:00Z
**Effort**: Verification-focused (mechanical back-port, no design work)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `/home/benjamin/.config/nvim/agent-system/extensions/core/` (source store)
- Codebase: `/home/benjamin/Projects/Logos/Hardware/.claude/` (finished, deployed, git-ignored source-of-truth)
- `agent-system/extensions/core/manifest.json` (`merge_targets.settings` mechanism)
- `.claude/docs/architecture/extension-system.md` (Settings Merging section)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All 6 destination paths exist (or the parent dir exists, for the new hook) under
  `agent-system/extensions/core/`. Line counts and diffs confirmed below.
- All 5 finished source-of-truth files exist under
  `/home/benjamin/Projects/Logos/Hardware/.claude/` with the expected sizes.
- Diffs for `commands/review.md`, `scripts/roadmap-integration.sh`, and
  `context/formats/task-order-format.md` are clean, additive, and match the described defect
  fixes exactly — no project-specific content leaks (one incidental comment mentions a table
  column literally named "Hardware Port" as a real-world example; harmless, not a project-name
  leak of concern).
- **CRITICAL DRIFT FOUND in `scripts/generate-task-order.sh`**: the finished Hardware file is
  MISSING the line `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`, which IS present in the
  current core source. This guard was added by a later, unrelated core change (source mtime
  2026-07-16, "wire deploy-root-guard.sh into all 24 core scripts") that postdates whatever
  source snapshot Hardware's `.claude/` was deployed from. **A raw file copy would silently
  regress the deploy-root-guard wiring.** The implementer must apply only the intended
  Defect-4 hunk (the `undeclared_topics` warning block near line 455-475), not overwrite the
  whole file.
- `merge-sources/settings-hooks.json` currently has NO `PostToolUse` key at all (only
  `SessionStart`/`Stop`/`UserPromptSubmit`). The PostToolUse hooks visible in a deployed
  `.claude/settings.json` come from a *different* merge source
  (`root-files/settings.json`, deep-merged by matcher). The new hook registration must be
  added to `merge-sources/settings-hooks.json` as a **new, standalone `PostToolUse` array entry**
  (own matcher block, not folded into an existing block) — exact shape given below.
- Core's `manifest.json` `provides.hooks` list ALREADY includes
  `"validate-no-task-references.sh"` (someone pre-staged the manifest entry) — only the actual
  hook script file is missing from `agent-system/extensions/core/hooks/`.

## Context & Scope

Mechanical back-port of 5 already-completed, already-verified tooling-defect fixes (provenance:
review review-2026-07-16) from a downstream project's disposable, git-ignored deploy tree
(`/home/benjamin/Projects/Logos/Hardware/.claude/`) into the agent-system SOURCE store
(`~/.config/nvim/agent-system/extensions/core/`), so the fixes survive the next `.claude/`
regeneration via the Neovim extension loader. Research here is verification-only: confirm paths,
diff finished-vs-source content, determine the exact settings-hooks.json entry, and flag drift
risk — no design decisions required.

## Findings

### 1. Source destination paths (agent-system/extensions/core/) — current state

| # | Path | Exists | Current line count |
|---|------|--------|---------------------|
| 1 | `scripts/roadmap-integration.sh` | yes | 466 |
| 2 | `commands/review.md` | yes | 842 |
| 3 | `scripts/generate-task-order.sh` | yes | 957 |
| 4 | `context/formats/task-order-format.md` | yes | 407 |
| 5 | `hooks/validate-no-task-references.sh` | **does not exist yet** — but parent dir `hooks/` exists and contains 17 sibling `validate-*.sh`/hook scripts (e.g. `validate-plan-write.sh`, `validate-state-sync.sh`, `validate-meta-write.sh`) |
| 6 | `merge-sources/settings-hooks.json` | yes | 29 |

### 2. Finished source-of-truth files (Hardware deploy tree) — current state

| # | Path | Line count | Size | mtime |
|---|------|------------|------|-------|
| 1 | `scripts/roadmap-integration.sh` | 548 (vs 466 source; matches task description) | 20979 bytes | 2026-07-18 10:18 |
| 2 | `commands/review.md` | 854 (vs 842 source) | 27054 bytes | 2026-07-18 10:06 |
| 3 | `scripts/generate-task-order.sh` | 971 (vs 957 source) | 31514 bytes | 2026-07-18 10:08 |
| 4 | `context/formats/task-order-format.md` | 415 (vs 407 source) | 15884 bytes | 2026-07-18 10:08 |
| 5 | `hooks/validate-no-task-references.sh` | 61 (matches task description exactly) | 3070 bytes, **already `chmod +x`** (`-rwxr-xr-x`) | 2026-07-18 10:10 |

### 3. Per-file diff summary (finished Hardware vs current core source)

#### `scripts/roadmap-integration.sh` (299-line unified diff — matches "~236 changed lines")

Two independently-located changes, both confirmed:

- **Defect 1 (argv overflow), call site A** (~line 111-113 in source): the original
  `ROADMAP_CONTENT=$(cat "$ROADMAP_PATH")` + `python3 - "$ROADMAP_CONTENT"` argv-pass is
  replaced with passing `$ROADMAP_PATH` (a short string) as argv and having Python
  `open(sys.argv[1]).read()` the file directly. Comment cross-references the second call site
  as "defect 1, line ~238" (matches task description's "line ~111/113" reference, off by a
  small amount due to earlier drift in the file, not a discrepancy of substance).
- **Defect 1, call site B** (~line 271-283 in the finished file, corresponds to task's
  "near line 238" in source): `ROADMAP_STATE` and `ALL_COMPLETED` are now written to two
  `mktemp` temp files with `printf '%s'`, a `trap 'rm -f ... ' EXIT` cleanup, and the Python
  heredoc reads both via `json.load(open(sys.argv[N]))` instead of `json.loads(sys.argv[N])`.
  This is the exact argv-length fix described.
- **Defect 3 (annotations matcher)**: the old fixed-arity 3-column regex
  `^\|(.+)\|(.+)\|(.+)\|$` is replaced with a generic `^\|(.*)\|\s*$` + `.split('|')` that
  handles any column count; separator-row detection now uses `^:?-+:?$` (any width) instead of
  a 3-column-only check; header-row detection switched from a keyword heuristic
  (`'status' in cols[1].lower()`, which false-positived on data cells containing the substring
  "status") to a **lookahead check**: a row is a header iff the *next* line is a same-width
  separator row. A new `find_match()` helper factors out the existing
  `(Task N)` / `roadmap_items` / title / keyword matching logic (previously inlined only in the
  checkbox loop) so it can be reused by a **new, additive loop over `status_tables` entries**
  with a strict `STATUS_ALLOWLIST_RE = r'\b(complete|resolved|done)\b'` gate — this is what
  makes `annotations_made` non-zero against table-format `ROADMAP.md` files. The checkbox-based
  matching loop is functionally unchanged (only refactored to call the shared `find_match()`).
- No unrelated content. No project-specific strings other than one benign inline comment
  example: `"Hardware Port" is the actual completion-status column in several 4-/5-column
  ROADMAP tables` — this describes a real column name in the downstream project's own
  `ROADMAP.md` schema as a rationale example; it is prose inside a code comment explaining WHY
  the fix scans all non-component columns, not a leaked identifier that needs stripping. Safe to
  keep verbatim, or the implementer may generalize the wording if desired (non-blocking).

#### `commands/review.md` (29-line unified diff — matches "~18 changed lines" order of magnitude)

- **Defect 2 (silent guard)**: `roadmap_output=$(bash .claude/scripts/roadmap-integration.sh ...)`
  is now followed by `|| roadmap_exit=$?` (with `roadmap_exit=0` initialized beforehand), and the
  error-handling section gains a new `elif [[ "$roadmap_exit" -ne 0 ]] || [[ -z "$roadmap_output" ]]`
  branch that emits a warning and falls back to the same empty-state defaults as the
  file-missing branch. Clean, additive, no unrelated changes.

#### `scripts/generate-task-order.sh` (diff — matches "~16 changed lines" for the intended fix, PLUS one unrelated removed line — see Risk below)

- **Defect 4 (warning symmetry), intended change**: near line 455-475 (source), a new
  `local -a undeclared_topics=()` / `declare -A undeclared_topic_task=()` pair is populated
  during the existing loop that already appends unseen topics to `topics_to_render`, then a new
  block emits `echo "Warning: topic '$tp' on task ${undeclared_topic_task[$tp]} is not declared
  in active_topics and will render after curated topics" >&2` for each distinct undeclared
  topic — symmetric to the existing `Uncategorized` warning. This part is exactly as described
  and safe to port.
- **UNRELATED, MUST-NOT-PORT removal**: the diff also shows
  `- . "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` being *removed* going from source to
  Hardware's finished file (i.e. Hardware's file never had this line). See "Drift Risk" below —
  this line must be **preserved** in the source file; it is unrelated to Defect 4 and its
  absence in the Hardware file is drift, not an intended change.

#### `context/formats/task-order-format.md` (8-line unified diff — matches "~10 changed lines")

- **Defect 4 (documentation)**: step 7 of the algorithm description gains an "Append-extras
  behavior" paragraph documenting that an undeclared topic is rendered as its own section
  (appended after curated topics, first-encountered-task order) rather than dropped or folded
  into `Uncategorized`, and that each triggers a one-time stderr warning. One incidental
  self-referential note: an EXISTING (unmodified) line elsewhere in this same file already reads
  `*Updated 2026-05-15. Generated from state.json. Tasks 139-141 archived.*` — this is
  pre-existing content in the current core source itself (not something the Defect-4 diff
  introduces), so it is out of scope for this back-port and should not be touched.

### 4. `merge-sources/settings-hooks.json` — exact registration entry required

**Current core source** (`agent-system/extensions/core/merge-sources/settings-hooks.json`, 29
lines) has hook categories `SessionStart`, `Stop`, `UserPromptSubmit` only — **no
`PostToolUse` key exists in this file at all.**

**Where deployed PostToolUse hooks actually come from**: `agent-system/extensions/core/
root-files/settings.json` (a *separate* merge target, `merge_targets.claudemd`/`.index`/
`.settings` are three distinct declarations in `manifest.json`; `root-files/settings.json` is
copied wholesale via `copy_root_files`, not deep-merged via `merge_targets.settings`). It
already declares `PostToolUse` matchers for `Write` (validate-state-sync, conditional on
`specs/state.json`) and `Write|Edit` (validate-plan-write.sh + events-log-artifact.sh, both in
one block).

**Hardware's deployed `.claude/settings.json` `PostToolUse` array** (the finished target shape)
has exactly 3 blocks:
```json
[
  { "matcher": "Write", "hooks": [ /* validate-state-sync, conditional */ ] },
  { "matcher": "Write|Edit", "hooks": [ /* validate-plan-write.sh only */ ] },
  { "matcher": "Write|Edit", "hooks": [ /* validate-no-task-references.sh */ ] }
]
```
Note: Hardware's deployed file is MISSING `events-log-artifact.sh` from the second block
entirely (see Risk #2 below) — this confirms the Hardware `.claude/` tree predates a
`root-files/settings.json` change that isn't part of this back-port's scope, so it should NOT
be used as a template for the `Write|Edit`+`validate-plan-write.sh` block. Only the **third**
block — the new, standalone `validate-no-task-references.sh` entry — is the thing to port.

**Exact entry to add** to `merge-sources/settings-hooks.json`, as a NEW top-level `"PostToolUse"`
key containing one array entry (per `manifest.json`'s documented `_comment`: "deep_merge appends
array entries per-matcher rather than merging into an existing '*' matcher" — the same append
semantics apply to non-`*` matchers, so this new `Write|Edit` block will append alongside, not
merge into, `root-files/settings.json`'s existing `Write|Edit` block, exactly mirroring what is
observed in Hardware's deployed settings.json):

```json
{
  "hooks": {
    "SessionStart": [ /* unchanged, 1 entry */ ],
    "Stop": [ /* unchanged, 1 entry */ ],
    "UserPromptSubmit": [ /* unchanged, 1 entry */ ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'"
          }
        ]
      }
    ]
  }
}
```

`manifest.json`'s `provides.hooks` array (which controls which files `copy_hooks()` actually
copies from `hooks/` to the deployed `.claude/hooks/`) **already lists
`"validate-no-task-references.sh"`** alphabetically between `validate-meta-write.sh` and
`validate-plan-write.sh` — no manifest change needed for hook *copying*; only the settings
*registration* (this JSON) and the hook *file itself* are missing.

### 5. Per-fix verification procedure (to run in source context after copying)

1. **Defect 1 (argv overflow)** — `scripts/roadmap-integration.sh`: construct a
   `specs/state.json` (or a copy) whose `completed_tasks`/`archived_tasks` serialize to
   >131072 bytes (`getconf ARG_MAX` on this machine reports 2097152 total exec-args+env budget,
   but the per-string `MAX_ARG_STRLEN` kernel constant the defect describes is a fixed 131072
   and is not queryable via `getconf`), then run
   `bash agent-system/extensions/core/scripts/roadmap-integration.sh --roadmap <path> --state
   <path> --annotate` and confirm exit code 0 (previously exit 126, "Argument list too long").
   Python3 is confirmed available (`python3 -c "print('ok')"` succeeded).
2. **Defect 2 (silent guard)** — `commands/review.md`: this is a documented bash snippet inside
   a markdown command file, not directly executable standalone; verification is a read-through
   confirming `roadmap_exit=$?` is captured immediately after the invocation and the new
   `elif` branch checks it, OR construct a throwaway broken `roadmap-integration.sh` (e.g.
   `exit 1`) and confirm the documented snippet, if extracted and run, surfaces the warning
   rather than silently defaulting `annotations_made=0` with no message.
3. **Defect 5 (hook)** — `hooks/validate-no-task-references.sh`: after copying and `chmod +x`
   (already `+x` on the Hardware source; preserve that bit on copy), invoke it directly with a
   synthetic PostToolUse JSON payload on stdin: one with `file_path` outside `specs/**`
   containing a "task 42" citation (expect `additionalContext` reminder, exit 0) and one with
   `file_path` under `specs/**` containing the same text (expect bare `{}`, exit 0, silent). Both
   paths must exit 0 — never a non-zero/blocking exit, confirming non-blocking behavior.
4. **Defect 3 (annotations matcher)** — `scripts/roadmap-integration.sh`: run the script (no
   `--annotate` needed for a dry parse) against a synthetic table-format `ROADMAP.md` (4-5
   columns, no checkboxes, at least one row whose status column matches `complete|resolved|done`
   and references a real completed task number/title from a test `state.json`), and confirm the
   `annotation_summary.annotations_made` field in stdout is non-zero (previously always 0 for
   this input shape).

### 6. Drift Risk — files generated from a newer/older source than current core

**Confirmed drift (high severity)**: `scripts/generate-task-order.sh`. Current core source
(mtime 2026-07-16 00:15, corresponding to a change titled "wire deploy-root-guard.sh into all 24
core scripts" per git history) contains, near the top of the file:
```bash
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
```
Hardware's finished file (mtime 2026-07-18 10:08) does **not** contain this line — it was
deployed from (or hand-edited against) a core snapshot that predates the guard-wiring change.
**A raw `cp` of this file into source would silently delete the deploy-root-guard sourcing
line**, regressing unrelated, already-landed work. The implementer must apply ONLY the
Defect-4 hunk (the `undeclared_topics`/warning block) via a targeted edit, not a whole-file
copy, for this one file.

By contrast, `scripts/roadmap-integration.sh` in current core source does **not** source
`deploy-root-guard.sh` either (grep confirms absence in both source and Hardware versions), so
no equivalent drift exists there — that file's diff is clean and a value can be reasoned about
hunk-by-hunk or applied wholesale with equal safety, though hunk-by-hunk is still the safer
general practice per the guidance below.

**Secondary drift (low severity, informational only, does not block this task)**: Hardware's
deployed `.claude/settings.json` `PostToolUse` `Write|Edit` block for `validate-plan-write.sh`
is missing the `events-log-artifact.sh` hook that current core's `root-files/settings.json`
already pairs with it. This is further evidence Hardware's `.claude/` tree is stale relative to
current core `root-files/settings.json`, but `root-files/settings.json` is explicitly out of
scope for this task (the task only touches `merge-sources/settings-hooks.json`), so no action
is needed beyond not using Hardware's full `PostToolUse` array as a copy template — only its
third (`validate-no-task-references.sh`) block should be extracted.

**General implication for the implementer**: treat "finished Hardware file" as a *diff source*
to extract intended hunks from, not a file to `cp` wholesale over the current core source,
for any of the 4 modified files — even where no drift was found in 3 of the 4, the one
confirmed drift case (`generate-task-order.sh`) means a uniform "diff review, then targeted
edit" discipline is safer than a per-file "copy if clean" heuristic.

## Decisions

- The `merge-sources/settings-hooks.json` addition is a NEW top-level `PostToolUse` key with one
  `Write|Edit` matcher block (single hook), not a merge into any existing block — confirmed by
  both the `manifest.json` `_comment` describing per-matcher array-append semantics and by
  directly observing Hardware's deployed settings.json having 3 distinct `PostToolUse` blocks
  rather than 2.
- `generate-task-order.sh` requires a hand-applied targeted hunk (not a whole-file copy) to avoid
  regressing the `deploy-root-guard.sh` sourcing line.
- The other 3 modified files (`roadmap-integration.sh`, `review.md`, `task-order-format.md`) have
  clean, single-purpose diffs against current core source and can be applied as their respective
  unified diffs (patch-style) with low risk, though the implementer should still diff-review
  before applying per the general implication above.
- `manifest.json`'s `provides.hooks` list is already correct and requires no edit — only the hook
  file itself needs to be created.

## Risks & Mitigations

- **Risk**: whole-file copy of `generate-task-order.sh` silently drops
  `deploy-root-guard.sh` sourcing. **Mitigation**: apply only the Defect-4 hunk via targeted
  edit; verify post-edit that `grep -n "deploy-root-guard" scripts/generate-task-order.sh` still
  matches after the change.
- **Risk**: copying Hardware's full deployed `PostToolUse` array into
  `merge-sources/settings-hooks.json` would drop `events-log-artifact.sh` wiring (which lives in
  `root-files/settings.json`, untouched by this task) if someone mistakenly treats the deployed
  file as the merge-source template. **Mitigation**: only add the single new
  `validate-no-task-references.sh` block, as specified in Finding 4 above.
- **Risk**: this is a disposable, git-ignored deploy tree — if the Hardware project is
  redeployed via the Neovim loader before this back-port lands, the fixes are unrecoverable.
  **Mitigation**: this is explicitly called out in the task description as the reason for
  urgency; no further research action needed, but the implementer should treat this as a
  same-session, non-deferrable follow-up.

## Context Extension Recommendations

None — this is a meta task whose only source-of-truth is the Hardware deploy tree and the
current core source; no gaps in `.claude/context/` documentation were identified as blocking
this back-port. (Optional, non-blocking observation: `agent-system/extensions/core/README.md`
lists hook files in prose near the string "validate-plan-write.sh, validate-state-sync.sh" and
could be updated to also mention `validate-no-task-references.sh` for completeness, but this is
outside the task's explicit 6-item scope and not required.)

## Appendix

### Search queries / commands used

- `wc -l` on all 4 modified source + 5 finished files
- `diff -u` between each of the 4 modified files (source vs Hardware finished)
- `python3 -c "..."` to inspect `hooks.PostToolUse` in Hardware's deployed `settings.json` and
  core's `manifest.json` `merge_targets`
- `grep -rl "PostToolUse"` / `grep -rl "merge-sources"` across `agent-system/` and `.claude/` to
  locate the merge mechanism and its documentation
- `grep -n "deploy-root-guard"` against both source and Hardware versions of
  `generate-task-order.sh` and `roadmap-integration.sh` to confirm the drift's scope
- `grep -n "Hardware\|Logos"` across all 5 finished files to check for project-name leakage
- `git log --oneline -3 -- agent-system/extensions/core/scripts/generate-task-order.sh` to date
  the deploy-root-guard wiring commit

### References

- `agent-system/extensions/core/manifest.json` (`merge_targets.settings`, `provides.hooks`)
- `.claude/docs/architecture/extension-system.md` ("Settings Merging" section)
- `.claude/rules/no-task-references-in-deliverables.md` (the rule the new hook enforces)
- `agent-system/extensions/core/hooks/validate-plan-write.sh` (structural precedent for the new
  hook's stdin/env-fallback parsing pattern, already followed by the finished hook file)
