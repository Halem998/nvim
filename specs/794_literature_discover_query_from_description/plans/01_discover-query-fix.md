# Implementation Plan: Fix literature-discover.sh query source and Zotero hint

- **Task**: 794 - Fix /literature N discovery to query task description+title instead of the slug, and hint on missing Zotero export
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None (task 793 dual-copy model already in place)
- **Research Inputs**: specs/794_literature_discover_query_from_description/reports/01_discover-query-fix.md
- **Artifacts**: plans/01_discover-query-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix two defects in the literature source-discovery script, editing the canonical
extension source `.claude/extensions/literature/scripts/literature-discover.sh` and
re-syncing the byte-identical flat deployed copy `.claude/scripts/literature-discover.sh`
(task-793 dual-copy model). FIX 1 (primary): for the `--task N` form, derive the search
query from the task's `.description` and `.title` (via jq against `specs/state.json`)
instead of `.project_name` (the bookkeeping slug), which currently makes discovery return
nothing. FIX 2 (UX): when `$LITERATURE_DIR/zotero-library.json` is missing, emit a one-time
stderr setup hint from `tier2_search`, and remove the outer stderr-swallow at the tier call
site so the hint actually surfaces on direct invocation. Definition of done: query built
from subject-matter text (not the slug), missing-Zotero hint prints to stderr while JSON
stdout stays valid, canonical and flat copies byte-identical, and the `literature` section
of `check-extension-docs.sh` still reports PASS.

### Research Integration

The research report (`reports/01_discover-query-fix.md`) supplies exact line numbers, ready-
to-use replacement code for both fixes, the `check-extension-docs.sh` baseline, and the
recommended direct-invocation verification commands. Key confirmed facts integrated here:

- Canonical (613 lines) and flat copies are currently byte-identical (`diff` empty); no
  automated sync script exists, so re-sync is a manual `cp` preserving the executable bit.
- FIX 1 replacement code lives in the report's lines 11-53 region (targets script lines
  105-132). The existing `filter_terms()`/`FILTERED_TERMS` logic (script lines 169-201,
  invoked line 196) operates on the final `SEARCH_TERMS` regardless of source, so
  description+title text gets <3-char and stopword filtering for free -- no changes needed there.
- `title` can be `null` on healthy tasks (observed: task 795), so the null guard is required.
- FIX 2 requires clearing two stderr-swallow points: the outer `tier2_search 2>/dev/null || true`
  at script lines 591-598, and the two unredirected `python3 -c` calls (~lines 403-408, 410)
  which need `2>/dev/null` added for parity once the blanket redirect is dropped.
- `check-extension-docs.sh` baseline: overall FAIL (2 pre-existing lean-extension issues,
  unrelated to this task); the `literature` section reports PASS. Verification asserts the
  `literature` line stays PASS, NOT that overall exit goes green.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so ROADMAP.md was not consulted and
no roadmap review/update phases are included.

## Goals & Non-Goals

**Goals**:
- For `--task N`, build the search query from `.description` + `.title` (jq), dropping the slug entirely.
- Handle null/empty title gracefully; error clearly (exit 2) if both description and title are empty.
- Preserve `--task N "extra terms"` append behavior and leave the free-text path untouched.
- Print a one-time stderr setup hint when `zotero-library.json` is missing, matching `zotero-search.sh` wording, without changing exit status or corrupting JSON stdout.
- Remove the outer stderr-swallow so the hint surfaces on direct invocation; add `2>/dev/null` parity to the two unredirected `python3` calls.
- Re-sync the flat copy to byte-identical with the canonical, preserving the executable bit.
- Keep the `literature` section of `check-extension-docs.sh` at PASS.

**Non-Goals**:
- Creating `zotero-library.json` (user action).
- Changing the three-tier discovery pipeline architecture or Semantic Scholar behavior.
- Fixing the whole-script stderr capture in `literature.md` (~lines 125-139) -- documented follow-up gap; the hint will surface only on direct invocation, not through `/literature N`.
- Modifying `filter_terms()`/`FILTERED_TERMS` (no changes needed).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edits to canonical and flat drift out of byte parity | M | M | Dedicated sync phase (Phase 3) uses `cp` of the canonical over the flat; Phase 4 asserts `cmp`/`diff` parity |
| Removing outer `2>/dev/null` lets noisy sub-command errors leak to stderr | M | L | Report confirms every other stderr-emitter inside `tier2_search` self-redirects; Phase 2 adds `2>/dev/null` to the two remaining `python3` calls for parity |
| Long descriptions inject noise tokens into the query | L | M | Known limitation; `filter_terms()` drops <3-char/stopword tokens; noise only mildly dilutes Tier 3, does not break substring matching |
| `title` null handling regresses (bareword `null` leaks into query) | M | L | Guard checks both non-empty and `!= "null"` before appending; Phase 4 inspects the built query |
| JSON stdout corrupted by the new hint | H | L | Hint written to stderr (`>&2`) only; Phase 4 validates stdout parses via `jq .` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 both edit the same
canonical file at disjoint line regions; they are sequenced to avoid edit conflicts.

### Phase 1: FIX 1 -- derive query from description+title [COMPLETED]

- **Goal:** Replace the slug-based `--task N` query construction (canonical lines ~105-132) with description+title derivation via jq, dropping `.project_name` entirely.
- **Tasks:**
  - [x] Read `.claude/extensions/literature/scripts/literature-discover.sh` around lines 105-132 to confirm the current `--task` block and surrounding variable names (`TASK_NUM`, `SEARCH_TERMS`). *(completed)*
  - [x] Replace the block with the report's replacement (report lines 11-53): read `.description // ""` and `.title // ""` via jq against `$git_root/specs/state.json`; guard each with a non-empty AND `!= "null"` check; trim leading/trailing whitespace; error with exit 2 if both are empty; error with exit 2 if the task is not found or `state.json` is missing. *(completed)*
  - [x] Preserve `--task N "extra terms"` append behavior: when `SEARCH_TERMS` is already set, prepend `task_terms` (`SEARCH_TERMS="$task_terms $SEARCH_TERMS"`). *(completed)*
  - [x] Confirm the free-text path (no `--task`) never enters the `if [ -n "$TASK_NUM" ]` block and is therefore unaffected. *(completed: no changes made to argument-parsing section; --task block only entered when TASK_NUM set)*
  - [x] Confirm no changes are made to `filter_terms()`/`FILTERED_TERMS` (lines 169-201/196) -- they already filter the final `SEARCH_TERMS`. *(completed: verified untouched)*
- **Timing:** ~0.75 hour
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/literature/scripts/literature-discover.sh` (canonical) -- lines ~105-132
- **Verification:**
  - [ ] `bash -n .claude/extensions/literature/scripts/literature-discover.sh` (syntax check passes).
  - [ ] Inspect the edited region: no reference to `.project_name` remains in the `--task` block; both `.description` and `.title` are read with null guards.

### Phase 2: FIX 2 -- Zotero missing-export hint + clear swallow points [COMPLETED]

- **Goal:** Add a one-time stderr setup hint in `tier2_search` when `zotero-library.json` is absent, remove the outer stderr-swallow at the tier call site, and add `2>/dev/null` parity to the two unredirected `python3` calls. Exit status unchanged.
- **Tasks:**
  - [x] In `tier2_search` (canonical lines ~334-336), inside the `if [ ! -f "$zotero_library" ]` branch, before `return 0`, add two `>&2` echo lines matching `zotero-search.sh` wording (report lines 74-80): a "Tier 2 (Zotero) skipped: no export found at $zotero_library" line and a "To enable: in Zotero, File -> Export Library -> format \"Better CSL JSON\", check \"Keep updated\", save to $zotero_library" line. *(completed)*
  - [x] At the tier call site (canonical lines ~591-598), change `tier2_search 2>/dev/null || true` to `tier2_search || true` so the hint is no longer swallowed. *(completed)*
  - [x] Add `2>/dev/null` to the two unredirected `python3 -c` calls building `authors_arr` (~lines 403-408 and ~410) for defensive parity now that the blanket redirect is removed. *(completed)*
  - [x] Cross-check hint wording against `.claude/extensions/literature/scripts/zotero-search.sh` lines 143-169 for consistency. *(completed: matches "File -> Export Library", "Better CSL JSON", "Keep updated" phrasing)*
- **Timing:** ~0.75 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/literature/scripts/literature-discover.sh` (canonical) -- lines ~334-336, ~403-410, ~591-598
- **Verification:**
  - [ ] `bash -n .claude/extensions/literature/scripts/literature-discover.sh` (syntax check passes).
  - [ ] Confirm the tier call site reads `tier2_search || true` (no `2>/dev/null`) and both `python3` calls now carry `2>/dev/null`.

### Phase 3: Re-sync flat deployed copy [COMPLETED]

- **Goal:** Make `.claude/scripts/literature-discover.sh` byte-identical to the edited canonical, preserving the executable bit (task-793 dual-copy model).
- **Tasks:**
  - [x] Copy the canonical over the flat: `cp .claude/extensions/literature/scripts/literature-discover.sh .claude/scripts/literature-discover.sh`. *(completed: used `cp -p`)*
  - [x] Ensure the executable bit is preserved: `chmod +x .claude/scripts/literature-discover.sh` (or use `cp -p`). *(completed)*
- **Timing:** ~0.25 hour
- **Depends on:** 1, 2
- **Files to modify:**
  - `.claude/scripts/literature-discover.sh` (flat re-sync)
- **Verification:**
  - [ ] `cmp .claude/extensions/literature/scripts/literature-discover.sh .claude/scripts/literature-discover.sh` reports no difference.
  - [ ] `test -x .claude/scripts/literature-discover.sh` (flat copy is executable).

### Phase 4: Verification [COMPLETED]

- **Goal:** Verify both fixes behave correctly, byte parity holds, and the `literature` doc-lint section stays PASS.
- **Tasks:**
  - [x] (a) Query built from description: pick a task with a topical description and confirm the constructed query contains subject-matter terms, not the slug. Add a temporary debug print or run with `bash -x` on the `--task N` path, or invoke directly and inspect the emitted Tier 3 query. Confirm no "collect/literature/sources/task" slug tokens appear. *(completed: `bash -x .claude/scripts/literature-discover.sh --task 794` shows `task_terms` built from task 794's full description+title text; no reference to project_name slug "literature_discover_query_from_description" in SEARCH_TERMS)*
  - [x] (b) Missing-Zotero hint via DIRECT invocation (not through `/literature`, which swallows stderr): `LITERATURE_DIR=/nonexistent-dir bash .claude/scripts/literature-discover.sh "some terms" 1>/tmp/out.json 2>/tmp/err.txt`; then `jq . /tmp/out.json` must parse (stdout valid JSON) and `grep -i zotero /tmp/err.txt` must find the hint (stderr). *(completed: stdout valid JSON confirmed, hint found in stderr, exit status 1 confirmed identical before/after via git stash comparison)*
  - [x] (c) Byte parity: `diff .claude/extensions/literature/scripts/literature-discover.sh .claude/scripts/literature-discover.sh` is empty. *(completed: diff empty)*
  - [x] (d) Run `bash .claude/scripts/check-extension-docs.sh`; confirm the `literature` extension section reports PASS. Overall exit still FAILs due to pre-existing, unrelated lean-extension issues (`skill-lean-research-hard` / `skill-lean-implementation-hard` not deployed) -- that is expected and NOT a regression. *(completed: literature=PASS, lean=FAIL (pre-existing, unrelated), overall FAIL: 2 issue(s) as expected)*
- **Timing:** ~0.75 hour
- **Depends on:** 3
- **Files to modify:** none (verification only)
- **Verification:**
  - [ ] All four checks (a)-(d) pass as described above.

## Testing & Validation

- [ ] `bash -n` syntax check passes on both canonical and flat copies.
- [ ] `--task N` query contains subject terms from description/title, not slug tokens.
- [ ] `--task N "extra terms"` still appends the extra terms.
- [ ] Free-text invocation path unchanged (does not enter the `--task` block).
- [ ] Missing `zotero-library.json` prints the setup hint to stderr on direct invocation; stdout remains valid JSON (`jq .`).
- [ ] Exit status of the script is unchanged when Zotero export is missing.
- [ ] `cmp`/`diff` confirms canonical and flat copies are byte-identical; flat copy is executable.
- [ ] `check-extension-docs.sh` `literature` section reports PASS (overall FAIL from pre-existing lean issues is expected).

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/literature-discover.sh` (canonical, edited: FIX 1 + FIX 2)
- `.claude/scripts/literature-discover.sh` (flat, re-synced byte-identical)
- `specs/794_literature_discover_query_from_description/plans/01_discover-query-fix.md` (this plan)
- `specs/794_literature_discover_query_from_description/summaries/01_discover-query-fix-summary.md` (produced by /implement)

## Rollback/Contingency

Both files are under git. To revert: `git checkout -- .claude/extensions/literature/scripts/literature-discover.sh .claude/scripts/literature-discover.sh`. Because the canonical and flat copies started byte-identical and both are restored from the same committed state, a single checkout returns them to a consistent baseline. If only the flat copy drifts, re-run the Phase 3 `cp` to restore parity.
