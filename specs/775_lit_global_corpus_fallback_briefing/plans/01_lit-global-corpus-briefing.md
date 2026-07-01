# Implementation Plan: Task 775 — `--lit` No-Silent-Fallback + Global-Corpus Briefing

- **Task**: 775 - `--lit` no-silent-fallback interactive briefing with global-corpus option
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: None (coordinate doc scope with task 776; see Non-Goals)
- **Research Inputs**: specs/775_lit_global_corpus_fallback_briefing/reports/01_lit-no-silent-fallback.md
- **Artifacts**: plans/01_lit-global-corpus-briefing.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 775 removes the silent-empty behavior of `--lit` when a per-repo literature sub-index is
absent, and adds a live global-corpus briefing option. Four coordinated changes are required:
(1) extend `literature-briefing.sh` with a `--global "<query>" [--top-n N]` mode that queries the
global corpus via `literature-search.sh` and emits a `<literature-briefing>` block; (2) rewrite
the Stage 4a interactive block in all six `--lit`-aware skills to present two live outcomes
("Create curation task" vs "Use global corpus now") plus an explicit non-silent "Skip this run",
with no branch silently yielding an empty briefing; (3) guarantee both briefing modes share one
exit point that appends the "How to Use" footer; (4) resolve the autonomous-context default for
`/orchestrate` (where `AskUserQuestion` cannot prompt) and mirror the interactive-behavior
description into the CLAUDE.md source-of-truth. The definition of done: both briefing modes work
and always carry the footer; all six Stage 4a blocks route through one shared helper with a
non-silent decision in every branch; the autonomous default is deterministic and visibly logged;
and the `claudemd.md` interactive-behavior section matches the new flow.

### Research Integration

The research report (`reports/01_lit-no-silent-fallback.md`) supplies exact grounding used below:
- `literature-briefing.sh` is byte-identical across `.claude/scripts/` and
  `.claude/extensions/literature/scripts/` (verified `diff -q` = IDENTICAL); the canonical copy is
  the extension copy, mirrored to `.claude/scripts/`.
- `literature-search.sh` already does two-tier BM25 search, supports a pre-scan `--project <name>`
  filter (lines 628-641, `get_project_doc_ids` 35-53), has a zero-filtered-results retry-unfiltered
  fallback (lines 269-349), and exposes `--read <chunk_id>` / `--toc [doc_id]` for pointer
  resolution. It has no `--top-n`; result count is bounded by `LITERATURE_LIMIT` (default 20), so
  top-N selection happens inside the briefing script.
- The Stage 4a block is pseudocode-only today (no live `AskUserQuestion` wiring) and structurally
  identical across all six skills; it never references `orchestrator_mode`.
- `literature-create-setup-task.sh` is functional, silent-safe, and prints the new task number on
  stdout (line 101) — reusable unchanged for the "Create curation task" branch.
- CLAUDE.md interactive-behavior lives in `.claude/extensions/core/merge-sources/claudemd.md`
  ("Interactive Sub-Index Setup Detection", lines 328-350).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this invocation (roadmap flag not set).

## Design Decisions

### Decision D1 — Shared helper `literature-lit-flag-resolve.sh` (research recommendation, adopted)

To eliminate the 6x duplication that let the current design go stale, extract the deterministic
part of the Stage 4a decision into one helper. Because `AskUserQuestion` must be issued inline by
the skill (it cannot run inside a shell script), the helper's job is to classify the situation and
print a single machine-readable **directive** on stdout; the skill acts on that directive. The
helper is canonical at `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` and
mirrored to `.claude/scripts/literature-lit-flag-resolve.sh` (same mirror discipline as
`literature-briefing.sh`).

Helper contract (inputs via args/env, output = one directive token on stdout):
- Inputs: `--lit-flag <true|false>`, `--orchestrator-mode <true|false>`, `--query "<text>"`
  (task description used for global search), plus `LITERATURE_DIR` env.
- Directives:
  - `LIT_DISABLED` — `lit_flag != true`; skill injects nothing (existing behavior).
  - `SUBINDEX_PRESENT` — `specs/literature-index.json` exists; skill calls
    `literature-briefing.sh` (no-arg per-repo mode).
  - `GLOBAL_MISSING` — sub-index absent AND global index absent; skill emits the visible
    "no literature available" notice and continues empty (this is the one acceptable empty branch,
    and it is explicitly announced, not silent).
  - `PROMPT_NEEDED` — sub-index absent, global index present, interactive context
    (`orchestrator_mode != true`); skill issues `AskUserQuestion` (see D2).
  - `AUTONOMOUS_GLOBAL` — sub-index absent, global index present, autonomous context
    (`orchestrator_mode == true`); skill takes the deterministic default from D3.

### Decision D2 — Interactive flow: two live outcomes + explicit non-silent skip (requirement 2)

When directive is `PROMPT_NEEDED`, the skill issues `AskUserQuestion` with exactly three options,
two of which produce a live literature outcome and one of which is an explicitly user-chosen skip:
1. **Use global corpus now** (new live outcome): run
   `literature-briefing.sh --global "<task description>"`; inject the resulting block this run. No
   setup, no file writes. This is the recommended default option ordering (listed first).
2. **Create curation task** (live outcome for future runs; optional run-now modifier): run
   `literature-create-setup-task.sh` to create the `populate_literature_sub_index` meta task, and
   optionally fork-populate `specs/literature-index.json` inline (the existing Stage 4a-fork
   machinery) so the current run also benefits; then inject via no-arg `literature-briefing.sh`.
3. **Skip this run** (explicit, non-silent): user deliberately declines literature this run; skill
   logs a visible `[lit] Skipped by user choice` notice and continues empty.

Constraint enforced across all six blocks: **no code path may default to an empty briefing without
an explicit user choice or a visible logged notice.** The prior silent `exit 0`/`lit_context=""`
default is removed.

### Decision D3 — Autonomous default for `/orchestrate` (requirement 4, RESOLVED)

**Decision:** In autonomous contexts (`orchestrator_mode == true`, directive `AUTONOMOUS_GLOBAL`),
the skill MUST NOT call `AskUserQuestion`. It takes the deterministic default **"Use global corpus
now"**: it runs `literature-briefing.sh --global "<task description>"` and emits a VISIBLE notice to
stderr/transcript prefixed `[lit:auto]` stating that the global-corpus briefing was auto-selected
because no per-repo sub-index exists and no human is available to prompt. It is never a silent
no-op.

**Rationale:** the global corpus is directly queryable with zero setup, so the autonomous agent
still receives literature this run; the choice is announced (satisfying the user directive "no
silent fallbacks"); and it reuses the same `--global` path built in Phase 1 with no extra plumbing.
Detection uses the existing `orchestrator_mode` context field (passed today but never read),
requiring no new flag. If the global index is also missing under autonomy, the helper returns
`GLOBAL_MISSING` and the skill announces the empty result — still non-silent.

## Goals & Non-Goals

**Goals**:
- Add `--global "<query>" [--top-n N]` mode to `literature-briefing.sh`; keep no-arg per-repo mode
  behavior unchanged; both modes share one exit point that appends the "How to Use" footer.
- Keep the two `literature-briefing.sh` copies byte-identical (canonical + mirror).
- Introduce `literature-lit-flag-resolve.sh` (canonical + mirror) implementing the D1 directive
  contract.
- Rewrite the Stage 4a block in all six skills to the D2 three-option flow with the D3 autonomous
  default; no branch silently yields an empty briefing.
- Update the `claudemd.md` interactive-behavior description to match the new flow.

**Non-Goals**:
- The broader `--lit` model rewrite (the "What `--lit` Does" / `literature-retrieve.sh` narrative
  in `claudemd.md`) is owned by task 776 — 775 touches ONLY the "Interactive Sub-Index Setup
  Detection" description to avoid a merge conflict.
- No change to `literature-search.sh` internals, `literature-create-setup-task.sh`, or the
  deprecated `literature-retrieve.sh`.
- No change to how `lit_flag`/`orchestrator_mode` are produced by `/orchestrate` (they are already
  threaded; 775 only consumes `orchestrator_mode`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Canonical/mirror copies drift (briefing.sh or new helper) | M | M | Phase verification runs `diff -q` on both copies; a drift check is repeated in the integration phase (Phase 6). |
| Refactor to single exit point breaks the unchanged no-arg per-repo path | H | L | Preserve early `exit 0` semantics via mode dispatch that routes both modes into the shared output/footer section only when `briefing_lines` is non-empty; regression-test no-arg mode with a missing sub-index (must stay silent). |
| `literature-search.sh --global` JSON field names differ from assumed (`chunk_id`, `doc_id`, `section_path`, `title`, `summary`, `token_count`, `snippet`) | M | M | Phase 1 first runs a live `literature-search.sh "<query>"` and inspects the JSON keys before writing the jq extraction; adapt field names to actual output. |
| Six-file Stage 4a edits diverge again | M | M | D1 helper centralizes logic so each block becomes a thin wrapper; Phase 4/6 grep-verify all six blocks match the template. |
| Doc scope overlaps task 776 | M | M | Restrict edits to the "Interactive Sub-Index Setup Detection" section only; add an inline scoping note pointing to 776 for the broader rewrite. |
| CLAUDE.md not regenerated from merge-source | L | M | Phase 5 regenerates `.claude/CLAUDE.md` via the extension merge mechanism (or notes regeneration-on-load) and greps the rendered file for the new wording. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is sequential: each phase builds a
dependency consumed by the next (briefing mode -> helper -> template skills -> mirror skills ->
docs -> integration).

### Phase 1: Extend `literature-briefing.sh` with `--global` mode and single-exit footer [COMPLETED]

- **Goal:** Add a `--global "<query>" [--top-n N]` mode that builds a `<literature-briefing>` block
  from global-corpus search results, refactor so both modes share one exit point that appends the
  "How to Use" footer, keep the no-arg per-repo path behavior unchanged, and keep both file copies
  byte-identical (requirements 1 and 3).
- **Tasks:**
  - [x] In the canonical `.claude/extensions/literature/scripts/literature-briefing.sh`, add
    argument parsing: no args = existing per-repo mode; `--global "<query>"` = new global mode;
    optional `--top-n N` (default constant `GLOBAL_TOP_N=8`). *(completed)*
  - [x] Before writing extraction jq, run `bash .claude/extensions/literature/scripts/literature-search.sh "sample query"`
    once and confirm the JSON field names used per result (`chunk_id`, `doc_id`, `section_path`,
    `title`, `summary`, `token_count`, `snippet`); adapt to actual keys. *(completed: fields matched exactly)*
  - [x] Implement global mode: call `literature-search.sh --project "$(basename "$PROJECT_ROOT")" "<query>"`
    first; if it yields zero results, retry unfiltered `literature-search.sh "<query>"` (reuse the
    script's own fallback semantics). Take the top-N results; build one `briefing_lines` entry per
    chunk with title/section_path/summary/token_count and a `--read <chunk_id>` pointer. *(completed: the retry-unfiltered fallback is internal to literature-search.sh itself, confirmed by source read; briefing.sh calls it once with --project and relies on that internal fallback)*
  - [x] Refactor output: route both modes into ONE output section (open `<literature-briefing>`,
    provenance header, entries, then the existing `FOOTER` heredoc) so no mode emits the footer via
    a separate early `cat`/`exit`. Global-mode header: `## Available Literature — Global Corpus Search Results for: "<query>" (${N} segment(s))`. *(completed)*
  - [x] Preserve no-arg per-repo behavior exactly: still `exit 0` silently when sub-index is
    missing/empty/global-index-missing (the empty-branch policy is enforced upstream in Stage 4a,
    not here). *(completed)*
  - [x] Copy the finished file verbatim to the mirror `.claude/scripts/literature-briefing.sh`. *(completed)*
- **Timing:** ~1.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/literature/scripts/literature-briefing.sh` - add `--global` mode, single
    exit point + footer.
  - `.claude/scripts/literature-briefing.sh` - mirror (byte-identical copy).
- **Verification:**
  - [x] `bash -n` (syntax) passes on both copies; `shellcheck` if available. *(completed: bash -n passed both; shellcheck not installed, skipped)*
  - [x] `bash .claude/scripts/literature-briefing.sh --global "test"` emits a `<literature-briefing>`
    block that ends with the "How to Use" footer (`grep -q "## How to Use"`). *(completed)*
  - [x] `bash .claude/scripts/literature-briefing.sh` (no args) with no `specs/literature-index.json`
    still prints nothing and exits 0 (regression). *(completed)*
  - [x] `diff -q .claude/scripts/literature-briefing.sh .claude/extensions/literature/scripts/literature-briefing.sh` reports identical. *(completed)*

### Phase 2: Create `literature-lit-flag-resolve.sh` shared helper [COMPLETED]

- **Goal:** Implement the D1 directive contract in one helper (canonical + mirror) so all six
  Stage 4a blocks share the deterministic decision logic, including the D3 autonomous default
  branch.
- **Tasks:**
  - [x] Create `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` accepting
    `--lit-flag`, `--orchestrator-mode`, `--query`, honoring `LITERATURE_DIR`. *(completed)*
  - [x] Implement classification returning exactly one directive on stdout: `LIT_DISABLED`,
    `SUBINDEX_PRESENT`, `GLOBAL_MISSING`, `PROMPT_NEEDED`, `AUTONOMOUS_GLOBAL` (per D1/D3). *(completed)*
  - [x] Emit human-readable rationale to stderr (never stdout) so the skill can surface a visible
    notice; keep stdout to the single directive token for clean capture. *(completed)*
  - [x] Add a usage header documenting inputs, directives, and that `AskUserQuestion` remains the
    caller's responsibility. *(completed)*
  - [x] Mirror verbatim to `.claude/scripts/literature-lit-flag-resolve.sh`. *(completed)*
- **Timing:** ~1 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` - new helper.
  - `.claude/scripts/literature-lit-flag-resolve.sh` - mirror.
- **Verification:**
  - [x] `bash -n` passes on both copies. *(completed)*
  - [x] Directive matrix verified with fixtures: `--lit-flag false` -> `LIT_DISABLED`; sub-index
    present -> `SUBINDEX_PRESENT`; sub-index+global absent -> `GLOBAL_MISSING`; sub-index absent,
    global present, `--orchestrator-mode false` -> `PROMPT_NEEDED`; same with
    `--orchestrator-mode true` -> `AUTONOMOUS_GLOBAL`. *(completed: all 5 fixtures verified)*
  - [x] stdout contains only the directive token (no extra lines); rationale goes to stderr. *(completed)*
  - [x] `diff -q` on the two copies reports identical. *(completed)*

### Phase 3: Rewrite Stage 4a in the three standard skills (template) [COMPLETED]

- **Goal:** Replace the pseudocode 3-option block with the D2/D3 live flow in `skill-researcher`,
  `skill-planner`, and `skill-implementer`, establishing the canonical template on
  `skill-researcher` first, then applying it to the other two.
- **Tasks:**
  - [x] Rewrite `skill-researcher` Stage 4a (approx lines 167-251): call
    `literature-lit-flag-resolve.sh`, branch on the directive; `PROMPT_NEEDED` issues the D2
    three-option `AskUserQuestion` (Use global corpus now / Create curation task / Skip this run);
    `AUTONOMOUS_GLOBAL` takes the D3 default with `[lit:auto]` visible notice; `SUBINDEX_PRESENT`
    calls no-arg briefing; `GLOBAL_MISSING` emits visible notice + empty; `LIT_DISABLED` no-op. *(completed)*
  - [x] Ensure the "Use global corpus now" and `AUTONOMOUS_GLOBAL` branches call
    `literature-briefing.sh --global "$description"` and capture into `lit_context`. *(completed: verified live with a runnable-extract test — AUTONOMOUS_GLOBAL produced a real global briefing)*
  - [x] Preserve the reusable Stage 4a-fork machinery for the "Create curation task" run-now
    modifier. *(completed: fork section retained, retitled to "Create curation task")*
  - [x] Verify NO branch sets `lit_context=""` without a visible notice or explicit user skip. *(completed: LIT_DISABLED is the sole exception, exempt because --lit was never requested)*
  - [x] Apply the identical template to `skill-planner` (approx 157-267) and `skill-implementer`
    (approx 139-249), adjusting only surrounding line offsets. *(completed)*
- **Timing:** ~1 hour
- **Depends on:** 2
- **Files to modify:**
  - `.claude/skills/skill-researcher/SKILL.md` - Stage 4a rewrite (template).
  - `.claude/skills/skill-planner/SKILL.md` - Stage 4a rewrite.
  - `.claude/skills/skill-implementer/SKILL.md` - Stage 4a rewrite.
- **Verification:**
  - [x] `grep -c orchestrator_mode` >= 1 in each of the three files (previously zero). *(completed: count=4 in each)*
  - [x] Each file contains the three option labels "Use global corpus now", "Create curation task",
    "Skip this run". *(completed)*
  - [x] No occurrence of an unannotated silent-empty default (manual read of each branch confirms a
    notice or explicit user choice precedes every empty `lit_context`). *(completed)*
  - [x] `literature-briefing.sh --global` referenced in each file. *(completed)*

### Phase 4: Rewrite Stage 4a in the three hard-mode skills [COMPLETED]

- **Goal:** Apply the Phase 3 template to `skill-researcher-hard`, `skill-planner-hard`, and
  `skill-implementer-hard`, adapting to each file's line offsets while keeping the block identical
  in behavior.
- **Tasks:**
  - [x] Rewrite Stage 4a in `skill-researcher-hard` (approx 121-217), `skill-planner-hard`
    (approx 129-226), `skill-implementer-hard` (approx 144-236) using the Phase 3 template verbatim. *(completed)*
  - [x] Confirm each hard variant preserves any hard-mode-specific surrounding text while replacing
    only the Stage 4a decision block. *(completed: surrounding hard-mode text, e.g. skill-implementer-hard's per-phase-dispatch orchestrator_mode usage, untouched)*
- **Timing:** ~1 hour
- **Depends on:** 3
- **Files to modify:**
  - `.claude/skills/skill-researcher-hard/SKILL.md` - Stage 4a rewrite.
  - `.claude/skills/skill-planner-hard/SKILL.md` - Stage 4a rewrite.
  - `.claude/skills/skill-implementer-hard/SKILL.md` - Stage 4a rewrite.
- **Verification:**
  - [x] Same greps as Phase 3 pass in all three hard files (`orchestrator_mode`, three labels,
    `--global`). *(completed)*
  - [x] Cross-file consistency: the Stage 4a decision block matches the Phase 3 template across all
    six skills (spot-diff the directive-branch structure). *(completed: programmatic diff confirms the case/esac block is byte-identical across all six SKILL.md files)*

### Phase 5: Update CLAUDE.md source-of-truth (interactive-behavior only) [COMPLETED]

- **Goal:** Rewrite the "Interactive Sub-Index Setup Detection" section in
  `.claude/extensions/core/merge-sources/claudemd.md` to describe the new two-live-options +
  explicit-skip flow, the global-corpus briefing, the shared helper, and the autonomous default —
  scoped narrowly to avoid conflict with task 776 (requirement 4 doc portion).
- **Tasks:**
  - [x] Replace lines ~328-350 ("Interactive Sub-Index Setup Detection") with the new flow: options
    become "Use global corpus now" / "Create curation task" / "Skip this run"; document the
    `AUTONOMOUS_GLOBAL` default for `/orchestrate` and the `[lit:auto]` visible notice; mention
    `literature-lit-flag-resolve.sh` and `literature-briefing.sh --global`. *(completed)*
  - [x] Add an inline scoping note: the broader `--lit` model description ("What `--lit` Does" /
    `literature-retrieve.sh`) is owned by task 776 and intentionally left unchanged here. *(completed)*
  - [x] Do NOT edit the "What `--lit` Does" or other Literature Mode subsections. *(completed: git diff confirms only the Interactive Sub-Index Setup Detection section changed)*
  - [x] Regenerate `.claude/CLAUDE.md` from merge-sources via the extension merge mechanism (or, if
    no direct generator exists, note that it regenerates on next extension load) and confirm the
    rendered file reflects the new wording. *(deviation: altered — no merge-source generator script was found on disk (searched .claude/scripts/ and repo root for "merge-sources" references); per the plan's own Rollback/Contingency note, left claudemd.md edited and relying on regeneration-on-load; .claude/CLAUDE.md was NOT manually edited)*
- **Timing:** ~0.5 hours
- **Depends on:** 4
- **Files to modify:**
  - `.claude/extensions/core/merge-sources/claudemd.md` - interactive-behavior section rewrite.
  - `.claude/CLAUDE.md` - regenerated output (if generator available).
- **Verification:**
  - [x] `grep -q "Use global corpus now" .claude/extensions/core/merge-sources/claudemd.md` and the
    other two option labels present. *(completed)*
  - [x] The "What `--lit` Does" subsection is unchanged (`git diff` shows edits confined to the
    Interactive Sub-Index Setup Detection section). *(completed)*
  - [x] Task 776 scoping note present. *(completed)*

### Phase 6: Integration verification and mirror-consistency audit [COMPLETED]

- **Goal:** Confirm the end-to-end behavior, mirror integrity, and doc-lint pass across all touched
  files.
- **Tasks:**
  - [x] Run `bash .claude/scripts/check-extension-docs.sh` (doc-lint) and confirm it exits 0. *(deviation: skipped — the script reports FAIL: 2 issues on the unrelated `lean` extension (routing_hard targets `skill-lean-research-hard`/`skill-lean-implementation-hard` not deployed); confirmed via `git stash` that this identical FAIL exists on master before any task-775 changes. The `literature` extension itself reports OK. Fixing the lean extension is out of scope for task 775.)*
  - [x] Re-run `diff -q` on both mirror pairs (`literature-briefing.sh`,
    `literature-lit-flag-resolve.sh`) — both identical. *(completed)*
  - [x] Simulate the autonomous path: call `literature-lit-flag-resolve.sh --lit-flag true
    --orchestrator-mode true --query "sample"` with no sub-index and a present global index; confirm
    `AUTONOMOUS_GLOBAL` and that a subsequent `literature-briefing.sh --global "sample"` produces a
    footer-terminated block. *(completed)*
  - [x] Final grep sweep: all six skills reference the helper and `--global`, contain the three
    option labels, and read `orchestrator_mode`. *(completed: all six skills pass all checks)*
- **Timing:** ~0.5 hours
- **Depends on:** 5
- **Files to modify:** none (verification only; fix-forward into prior phases if a check fails).
- **Verification:**
  - [x] `check-extension-docs.sh` exits 0. *(deviation: skipped — pre-existing unrelated lean-extension FAIL; literature extension itself is OK; see task note above)*
  - [x] Both mirror pairs identical. *(completed)*
  - [x] Autonomous simulation yields `AUTONOMOUS_GLOBAL` + footer-terminated global briefing. *(completed)*
  - [x] Six-skill consistency sweep passes. *(completed)*

## Testing & Validation

- [ ] `bash -n` passes on both `literature-briefing.sh` copies and both
  `literature-lit-flag-resolve.sh` copies.
- [ ] `literature-briefing.sh --global "<query>"` emits a footer-terminated `<literature-briefing>`
  block; no-arg mode still silent when sub-index missing.
- [ ] Helper directive matrix (five directives) verified with fixtures.
- [ ] All six skills: `orchestrator_mode` read, three option labels present, `--global` referenced,
  no unannotated silent-empty default.
- [ ] `claudemd.md` interactive section rewritten; "What `--lit` Does" untouched; 776 scoping note
  present.
- [ ] `check-extension-docs.sh` exits 0; both mirror pairs byte-identical.

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/literature-briefing.sh` (+ mirror `.claude/scripts/`)
- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (+ mirror `.claude/scripts/`)
- `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`
- `.claude/skills/skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`,
  `skill-implementer-hard/SKILL.md`
- `.claude/extensions/core/merge-sources/claudemd.md` (+ regenerated `.claude/CLAUDE.md`)
- `specs/775_lit_global_corpus_fallback_briefing/summaries/01_*-summary.md` (on implementation)

## Rollback/Contingency

- All changes are additive or localized. To revert: `git checkout -- <file>` for the specific
  touched files. The `--global` briefing mode and the helper are new codepaths; reverting the six
  Stage 4a blocks restores the prior pseudocode behavior without affecting the no-arg per-repo path.
- If the shared-helper extraction proves problematic mid-implementation, the fallback is to inline
  the directive logic directly into each Stage 4a block (accepting the 6x duplication) while keeping
  the D2/D3 behavior — the plan's behavioral contract is independent of the helper factoring.
- If CLAUDE.md regeneration has no direct script, leave `claudemd.md` edited and rely on
  regeneration-on-load; no manual edit of `.claude/CLAUDE.md` is committed.
