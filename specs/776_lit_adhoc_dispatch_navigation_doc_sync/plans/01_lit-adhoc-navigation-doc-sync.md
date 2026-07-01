# Implementation Plan: Task #776

- **Task**: 776 - Make --lit navigation work for ad-hoc dispatch and sync stale CLAUDE.md docs
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: 775 (completed — provides the two reusable scripts and the already-correct "Interactive Sub-Index Setup Detection" text this plan builds on)
- **Research Inputs**: specs/776_lit_adhoc_dispatch_navigation_doc_sync/reports/01_lit-adhoc-dispatch-doc-sync.md
- **Artifacts**: plans/01_lit-adhoc-navigation-doc-sync.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two coupled, documentation-only fixes so `--lit` behavior is reachable outside the formal
`/research|/plan|/implement --lit` command path and is documented accurately. **Requirement 1**
is greenfield (root cause G3): create a new pattern file that tells the primary/root session how
to reproduce skill Stage 4a's literature navigation conversationally — by directly reusing the two
already-built task-775 scripts (`literature-lit-flag-resolve.sh` for classification,
`literature-briefing.sh` for briefing generation) with `--orchestrator-mode false` hardcoded, then
register and cross-reference it for discoverability. **Requirement 2** (root cause G4) finishes the
CLAUDE.md doc sync that task 775 deliberately left half-done: rewrite the stale "What `--lit` Does"
subsection (which still describes the dead `literature-retrieve.sh` / `<literature-context>` /
`TOKEN_BUDGET=4000` static-dump model) to the live `literature-briefing.sh` → `<literature-briefing>`
navigate-on-demand model, and delete the now-orphaned scoping note. No new scripts are created; no
deployed `.claude/CLAUDE.md` is hand-edited (following 775's precedent — no generator script exists).

Definition of done: the new pattern file exists (canonical + byte-identical mirror) and is
registered + discoverable; the CLAUDE.md merge-source Literature Mode section describes only the
live briefing model with no surviving references to `literature-retrieve.sh`, `<literature-context>`,
or `TOKEN_BUDGET`/`MAX_FILES`; and the scoping note is gone.

### Research Integration

All findings are drawn from `reports/01_lit-adhoc-dispatch-doc-sync.md`:
- Requirement 1 is a documentation/procedure gap, not a code gap — the two task-775 scripts are
  generic and directly callable from the primary session (report "The reusable primitives already
  exist"). No new script.
- The new directive must mirror Stage 4a's `PROMPT_NEEDED` branch **verbatim** (three options:
  "Use global corpus now" / "Create curation task" / "Skip this run") and hardcode
  `--orchestrator-mode false` (a live user is always present in a conversational request, so
  `AUTONOMOUS_GLOBAL` is unreachable).
- Canonical single source of truth for classification remains `literature-lit-flag-resolve.sh`;
  the new file cites Stage 4a (`.claude/skills/skill-researcher/SKILL.md` lines 146-278) rather than
  re-deriving classification prose, to avoid drift.
- Requirement 2 touches only `.claude/extensions/core/merge-sources/claudemd.md`. Exact edit
  boundaries confirmed against the file: "What `--lit` Does" spans lines 313-327 (heading + preamble
  + 5 bullets); the orphaned scoping note is lines 330-333; "Interactive Sub-Index Setup Detection"
  (lines 335-379) is already correct and must not otherwise change.
- Token-budget drift is reconciled by **dropping** the `TOKEN_BUDGET`/`MAX_FILES` claim entirely
  (no live path uses a static budget; the only live limiter is `--top-n`, default 8 chunks, for
  global mode).

### Prior Plan Reference

No prior plan. This is the first plan for task 776.

### Roadmap Alignment

No ROADMAP.md consultation was requested (no `roadmap_path` / `roadmap_flag` in delegation
context). No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Create `adhoc-navigation-directive.md` (canonical in the literature extension + byte-identical
  mirror in `.claude/context/`) documenting the primary-session conversational `--lit` procedure.
- Register the new file in `.claude/extensions/literature/index-entries.json` (same shape as the
  existing `agent-exploration.md` entry).
- Add a discoverability pointer subsection to the Literature Mode section of the CLAUDE.md
  merge-source that names the new file and states its one-line contract.
- Rewrite "What `--lit` Does" (+ the Literature Mode section preamble) in
  `.claude/extensions/core/merge-sources/claudemd.md` to the live `literature-briefing.sh` →
  `<literature-briefing>` model, dropping the `TOKEN_BUDGET`/`MAX_FILES` claim.
- Delete the orphaned task-776 scoping note (claudemd.md lines 330-333).
- Leave the merge-source Literature Mode section internally consistent (no surviving
  `<literature-context>` / `literature-retrieve.sh` references within it).

**Non-Goals** (explicit scope boundaries — confirmed from research):
- **No new scripts.** The two task-775 scripts are reused as-is.
- **No hand-edit of the deployed `.claude/CLAUDE.md`.** Following 775's precedent, only the
  merge-source `claudemd.md` is edited; regeneration is deferred to the next extension load (no
  generator script exists on disk).
- **The six `.claude/extensions/core/skills/*/SKILL.md` mirrors are OUT of scope.** They are stale
  post-775 (only the deployed `.claude/skills/*` copies were updated), but this is not named in
  776's G3/G4 root causes. Recorded as a fast-follow risk in Phase 4, not fixed here.
- **`.claude/context/guides/literature-organization.md` is OUT of scope.** It shares the identical
  `literature-retrieve.sh`/`TOKEN_BUDGET=4000` drift but is a distinct file not named in 776's
  description. Recorded as a follow-up in Phase 4.
- No behavioral/script changes to `literature-briefing.sh` or `literature-lit-flag-resolve.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New directive duplicates Stage 4a classification logic and drifts over time | M | M | New file cites Stage 4a (`skill-researcher/SKILL.md` lines 146-278) and `literature-lit-flag-resolve.sh` as the single sources of truth; documents only primary-session-specific routing (self-execution vs subagent dispatch), not the classification rules. |
| Rewriting "What `--lit` Does" without deleting the scoping note leaves a "task 776 will fix this" note in a file 776 just fixed | M | M | Scoping-note deletion (lines 330-333) is an explicit task in the same phase (Phase 3) as the rewrite; Phase 4 greps to confirm removal. |
| Merge-source edit leaves the section self-contradicting (preamble still says `<literature-context>` after body rewritten to `<literature-briefing>`) | M | M | Phase 3 includes the section preamble (lines 315-317) in the rewrite and runs an in-phase consistency sweep of the remaining Literature Mode subsections; Phase 4 greps the whole section for stale tokens. |
| Canonical and mirror pattern files drift (not byte-identical) | L | M | Phase 1 writes canonical first, then copies it verbatim to the mirror; Phase 4 verifies with `diff` (must be identical). |
| A future "Load Core Agent System" sync reverts 775's Stage 4a rewrite (stale `extensions/core/skills/*` mirrors) | H | L | Explicitly documented as a known follow-up risk in the Phase 4 summary and Non-Goals; not silently ignored. |
| index-entries.json edit produces invalid JSON | M | L | Phase 2 validates with `jq empty` immediately after editing. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phase 2 (edits `index-entries.json`) and
Phase 3 (edits `claudemd.md`) touch disjoint files and are parallel-safe.

### Phase 1: Create the ad-hoc navigation directive pattern file [COMPLETED]

**Goal**: Author the new documentation-only pattern file (canonical + byte-identical mirror) that
tells the primary/root session how to produce a `<literature-briefing>` block conversationally by
reusing the two task-775 scripts.

**Tasks**:
- [x] Read the two reference sources for exact wording/interfaces before writing: *(completed)*
  - `.claude/skills/skill-researcher/SKILL.md` Stage 4a (lines 146-278) — directive branch
    `case/esac`, the `PROMPT_NEEDED` three-option `AskUserQuestion` block, Stage 4a-fork
    population (lines 254-275), and the Stage 5 injection-placement rule (lines 361-367).
  - `.claude/context/project/literature/patterns/agent-exploration.md` (60 lines) — the
    dispatched-agent-side "how to explore" pattern the new file will cross-reference for the
    self-execution routing case.
- [x] Create canonical file *(completed)*
  `.claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
  with these sections:
  1. **Trigger**: user asks conversationally to consult/search "the literature" / a paper / invoke
     `--lit`-like behavior while the primary session is NOT inside a `/research|/plan|/implement|
     /orchestrate --lit` dispatch (Stage 4a did not run).
  2. **Procedure** (mirrors Stage 4a, `--orchestrator-mode` hardcoded `false`):
     - Run `bash .claude/scripts/literature-lit-flag-resolve.sh --lit-flag true
       --orchestrator-mode false --query "<user request text>"`.
     - Branch on the four live directives (`AUTONOMOUS_GLOBAL` unreachable here):
       - `SUBINDEX_PRESENT` → `bash .claude/scripts/literature-briefing.sh` (no args).
       - `GLOBAL_MISSING` → visible chat notice ("no literature available"); do not proceed silently.
       - `PROMPT_NEEDED` → `AskUserQuestion` with the **identical** three options and wording as
         Stage 4a: "Use global corpus now" (recommended default, first) → `literature-briefing.sh
         --global "<query>"`; "Create curation task" → `literature-create-setup-task.sh` + inline
         fork population then no-arg `literature-briefing.sh`; "Skip this run" → explicit logged
         `[lit] Skipped by user choice`.
       - Note `LIT_DISABLED` is not applicable (the primary session runs this only when the user
         has requested `--lit`-equivalent behavior, so `--lit-flag` is always `true`).
  3. **Routing the result** — two cases: (a) self-execution (primary session answers directly): use
     the briefing content itself, running `literature-search.sh` and `Read`ing chunks per
     `agent-exploration.md`; (b) subagent dispatch: inject the `<literature-briefing>` block into
     the subagent's prompt using the same placement rule as skill-researcher Stage 5 (after
     `<memory-context>` if any, before task-specific instructions). Never dispatch an empty
     `<literature-briefing>` block.
  4. **Non-silence invariant** (restated): no branch may silently inject nothing or silently
     auto-search.
  5. A **Sources of truth** note citing Stage 4a and `literature-lit-flag-resolve.sh` (per the
     drift-mitigation risk) so classification logic is not re-derived in prose.
- [x] Copy the canonical file verbatim to the mirror
  `.claude/context/project/literature/patterns/adhoc-navigation-directive.md` (byte-identical). *(completed: verified with diff)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` — new canonical file.
- `.claude/context/project/literature/patterns/adhoc-navigation-directive.md` — new byte-identical mirror.

**Verification**:
- Both files exist and are non-empty.
- `diff` between canonical and mirror shows no differences.
- File contains the three exact option labels ("Use global corpus now", "Create curation task",
  "Skip this run") and the string `--orchestrator-mode false`.
- File contains no invented script names (only `literature-lit-flag-resolve.sh`,
  `literature-briefing.sh`, `literature-create-setup-task.sh`, `literature-search.sh`).

---

### Phase 2: Register the new file in the literature index-entries.json [COMPLETED]

**Goal**: Make the new pattern file loadable for skill/agent/command context discovery, matching
the shape of the existing `agent-exploration.md` entry.

**Tasks**:
- [x] Read the existing `agent-exploration.md` entry in
  `.claude/extensions/literature/index-entries.json` as the template. *(completed)*
- [x] Add a sibling entry for
  `project/literature/patterns/adhoc-navigation-directive.md` with the same `domain`/`subdomain`
  (`project`/`literature`), appropriate `topics`/`keywords` (e.g. `adhoc`, `conversational`,
  `navigation`, `directive`, `briefing`, `primary-session`), a one-line `summary`, the actual
  `line_count` of the file written in Phase 1, and the same `load_when` blocks
  (agents: literature-agent, general-research-agent, general-implementation-agent, planner-agent;
  skills: skill-literature, skill-researcher, skill-implementer, skill-planner; commands:
  /literature, /research, /plan, /implement). *(completed: line_count=92, verified against wc -l)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/index-entries.json` — add one entry.

**Verification**:
- `jq empty .claude/extensions/literature/index-entries.json` exits 0 (valid JSON).
- `jq '.entries[] | select(.path|test("adhoc-navigation-directive"))'` returns the new entry.
- The entry's `line_count` matches `wc -l` of the canonical file from Phase 1.

---

### Phase 3: Sync the CLAUDE.md merge-source Literature Mode section [COMPLETED]

**Goal**: Rewrite the stale static-dump documentation to the live briefing model, delete the
orphaned scoping note, drop the token-budget claim, and add the ad-hoc directive pointer — all in
the single merge-source `.claude/extensions/core/merge-sources/claudemd.md`. Do NOT touch the
deployed `.claude/CLAUDE.md`.

**Tasks**:
- [x] Rewrite the Literature Mode section preamble (lines 315-317) so it no longer claims `--lit`
  "injects reference files from `specs/literature/` as `<literature-context>`"; describe the live
  navigate-on-demand briefing instead. *(completed)*
- [x] Rewrite "What `--lit` Does" (lines 319-327) to describe the live model: *(completed)*
  - `--lit` triggers a live, navigate-on-demand `<literature-briefing>` (never a static content
    dump) against a corpus of pre-segmented literature chunks.
  - Two source modes matching `literature-briefing.sh`: per-repo mode (sourced from
    `specs/literature-index.json` resolved against `$LITERATURE_DIR/index.json`) and global-corpus
    mode (`literature-briefing.sh --global "<query>"` live relevance search when no sub-index
    exists).
  - Both modes emit one `<literature-briefing>` block with document/chunk metadata + a "How to Use"
    footer instructing the agent to run `literature-search.sh` and `Read` chunks on demand; no
    full-file content is injected.
  - Injection placement unchanged: after `<memory-context>` (if any), before task-specific
    instructions — re-anchored to `<literature-briefing>`.
  - Keep the "nothing injected when `--lit` not passed / `LIT_DISABLED`" statement, reworded to the
    directive-token model; do NOT keep the "silently ignored" phrasing for the missing-sub-index
    case (775 explicitly disallowed that).
  - Cross-reference the "Interactive Sub-Index Setup Detection" subsection for the missing-sub-index
    decision flow (avoid duplicating 775's correct text).
  - **Drop** `TOKEN_BUDGET`/`MAX_FILES` entirely; if a numeric limit is stated, cite `--top-n`
    (default 8 chunks) for global-corpus mode only.
- [x] Delete the orphaned scoping note at lines 330-333 (the `> **Scoping note**: ...` block inside
  "Interactive Sub-Index Setup Detection"). Make no other change to that subsection (lines 335-379
  are already correct per 775). *(completed)*
- [x] Add a new short subsection to the Literature Mode section titled e.g. "Ad-Hoc /
  Conversational Literature Requests" that names the new file
  (`.claude/context/project/literature/patterns/adhoc-navigation-directive.md`) and states its
  one-line contract: when a user requests `--lit`-like behavior conversationally (outside a skill
  Stage 4a dispatch), the primary session runs `literature-lit-flag-resolve.sh
  --orchestrator-mode false` and surfaces the SAME three-option interactive question as Stage 4a —
  never silently injecting nothing and never silently auto-searching. *(completed)*
- [x] Consistency sweep: scan the remaining Literature Mode subsections in this file (including
  "specs/literature/ Directory Convention" and the Memory Extension "Literature-Augmented Research"
  paragraph) and reconcile any surviving `<literature-context>` / `literature-retrieve.sh` /
  `TOKEN_BUDGET` references that would contradict the rewritten section. Limit edits to what is
  needed for internal consistency of this file's Literature Mode content; do not expand into other
  files. *(completed: swept "specs/literature/ Directory Convention" — no stale references found;
  the Memory Extension "Literature-Augmented Research" paragraph lives in a separate merge-source
  file (.claude/extensions/memory/EXTENSION.md), out of scope per "do not expand into other files"
  and per the explicit task-776 scope boundary limiting edits to claudemd.md only)*

**Timing**: 1 hour

**Depends on**: 1 (the pointer subsection references the Phase 1 file path)

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` — rewrite preamble + "What `--lit` Does",
  delete scoping note, add ad-hoc pointer subsection, consistency sweep.

**Verification**:
- `grep -n "literature-retrieve.sh\|<literature-context>\|TOKEN_BUDGET\|MAX_FILES"` over the
  Literature Mode section of `claudemd.md` returns no matches.
- `grep -n "Scoping note"` returns no matches in `claudemd.md`.
- `grep -n "literature-briefing\|<literature-briefing>"` confirms the new model is described.
- The "Interactive Sub-Index Setup Detection" body (former lines 335-379) is unchanged except for
  the deleted note (spot-check the three-option list is intact).
- The new pointer subsection names the mirror path
  `.claude/context/project/literature/patterns/adhoc-navigation-directive.md`.

---

### Phase 4: Cross-artifact verification and follow-up documentation [NOT STARTED]

**Goal**: Confirm all edits are internally consistent and record the explicitly-out-of-scope
follow-ups so they are not silently lost.

**Tasks**:
- [ ] Verify canonical vs mirror pattern files are byte-identical (`diff` clean).
- [ ] Verify `index-entries.json` is valid JSON and the new entry's `line_count` matches the file.
- [ ] Re-grep `claudemd.md` for all stale tokens (`literature-retrieve.sh`, `<literature-context>`,
  `TOKEN_BUDGET`, `MAX_FILES`, `Scoping note`) — all must be absent from the Literature Mode section.
- [ ] Run the doc-lint script `bash .claude/scripts/check-extension-docs.sh` and confirm it does not
  newly fail due to these edits (record output; pre-existing unrelated failures are noted, not fixed).
- [ ] Record in the implementation summary the two confirmed out-of-scope follow-ups:
  (a) the six stale `.claude/extensions/core/skills/*/SKILL.md` mirrors (sync source not updated by
  775 — a future "Load Core Agent System" sync would revert 775's Stage 4a rewrite), and
  (b) `.claude/context/guides/literature-organization.md` sharing the identical stale-model drift.
  Recommend each as a small fast-follow task.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification + summary only).

**Verification**:
- All grep/diff/jq checks above pass.
- `check-extension-docs.sh` output captured; no new failures attributable to this task.
- Follow-up items recorded in the summary.

## Testing & Validation

- [ ] `diff .claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md .claude/context/project/literature/patterns/adhoc-navigation-directive.md` → no output (identical).
- [ ] New pattern file contains the three verbatim option labels and `--orchestrator-mode false`.
- [ ] `jq empty .claude/extensions/literature/index-entries.json` exits 0; new entry present.
- [ ] `grep -nE "literature-retrieve\.sh|<literature-context>|TOKEN_BUDGET|MAX_FILES|Scoping note" .claude/extensions/core/merge-sources/claudemd.md` → no matches.
- [ ] `grep -n "literature-briefing" .claude/extensions/core/merge-sources/claudemd.md` → matches (live model documented).
- [ ] Deployed `.claude/CLAUDE.md` left unmodified (git status shows no change to that file).
- [ ] `bash .claude/scripts/check-extension-docs.sh` produces no new failures from this task.

## Artifacts & Outputs

- `.claude/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` (new canonical)
- `.claude/context/project/literature/patterns/adhoc-navigation-directive.md` (new mirror, byte-identical)
- `.claude/extensions/literature/index-entries.json` (one added entry)
- `.claude/extensions/core/merge-sources/claudemd.md` (Literature Mode section rewrite + note deletion + pointer subsection)
- `specs/776_lit_adhoc_dispatch_navigation_doc_sync/summaries/01_lit-adhoc-navigation-doc-sync-summary.md` (implementation summary with out-of-scope follow-ups recorded)

## Rollback/Contingency

All changes are documentation-only and confined to four files (two new, two edited); no scripts or
deployed runtime files change. To revert: `git checkout` the two edited files
(`.claude/extensions/literature/index-entries.json`,
`.claude/extensions/core/merge-sources/claudemd.md`) and `git rm` the two new pattern files. Because
the deployed `.claude/CLAUDE.md` is intentionally not edited, no regeneration/re-sync rollback is
required. If the consistency sweep in Phase 3 proves broader than expected, keep the two
research-specified edits (What `--lit` Does rewrite + scoping-note deletion) and defer the remaining
subsection reconciliation to a follow-up rather than expanding scope.
