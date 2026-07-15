# Implementation Plan: Sparse-Literature Detection and Stage 4a Reconciliation

- **Task**: 867 - Add sparse-literature detection to --lit and reconcile the drifted Stage 4a flow
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: 866 (complete -- `literature-ingest-online.sh` bridge with STABLE CONTRACT header exists)
- **Research Inputs**: specs/867_sparse_lit_detection_stage4a/reports/01_sparse-lit-detection-design.md
- **Artifacts**: plans/01_sparse-lit-stage4a-wiring.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close two coupled gaps in the `--lit` literature pipeline. First, add sparse-coverage detection:
`literature-briefing.sh` must surface a machine-readable segment/coverage count and a loud
`sparse` signal (following the existing `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]` loud-banner
precedent, never silent), and `literature-lit-flag-resolve.sh` must gain a configurable
`LITERATURE_SPARSE_THRESHOLD` (default 3) and a new `SPARSE_PROMPT_NEEDED` directive that fires on
sparse-or-absent coverage on both the sub-index path and the global-search path. Second, reconcile
the drifted Stage 4a flow across all six `--lit` skills so they actually call the resolver, branch
on every directive with real (not commented-out) `AskUserQuestion` instructions, standardize on the
failure-surfacing `literature-briefing-invoke.sh` wrapper, offer a new "Search online to ingest"
option wired to the task 866 bridge, and preserve a deterministic, visible `[lit:auto]` autonomous
fallback. The six near-duplicate Stage 4a blocks are extracted into ONE shared file that all six
skills import, so this class of drift cannot silently recur. Definition of done: resolver emits
`SPARSE_PROMPT_NEEDED` at the threshold boundary; all six skills reference the single shared block;
no raw `literature-briefing.sh 2>/dev/null` call site remains; the `/orchestrate --lit` autonomy
contract holds for research, plan, and implement phases; and EXTENSION.md plus the CLAUDE.md merge
source document the new behavior.

### Research Integration

The plan implements the six Decisions and honors the four Risks in
`reports/01_sparse-lit-detection-design.md`:
- Decision 1 (surfacing count): the resolver is the single classification authority and computes
  its own up-front count; `literature-briefing.sh` surfaces a machine-readable count + `[SPARSE
  COVERAGE ...]` banner for the *second* (post-global-search) checkpoint. This split satisfies the
  two-checkpoint shape (Decision 3) that does not fit the resolver's single-shot model.
- Decision 2: `LITERATURE_SPARSE_THRESHOLD` follows the `LITERATURE_LIMIT`/`DISCOVER_LIMIT`
  env-var-with-default precedent (default 3).
- Decision 3: new `SPARSE_PROMPT_NEEDED` directive, reachable from two call sites/timings.
- Decision 4: rewrite Stage 4a in all six skills via a single extracted shared file.
- Decision 5: fix `orchestrator_mode` per option (a) -- pass `orchestrator_mode: true` uniformly
  for research/plan/implement dispatches in the two orchestrate skills -- as a prerequisite, plus a
  cross-reference note in the handoff/architecture docs (dual-consumer flag).
- Decision 6: `-hard` variants share the reconciled block verbatim (no divergence).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap flag on this dispatch).

## Goals & Non-Goals

**Goals**:
- Surface a machine-readable coverage/segment count and a loud `sparse` signal from
  `literature-briefing.sh` (never silent).
- Add `LITERATURE_SPARSE_THRESHOLD` (default 3) and a `SPARSE_PROMPT_NEEDED` directive to
  `literature-lit-flag-resolve.sh`, covering both the sub-index-sparse and global-search-sparse
  checkpoints.
- Reconcile Stage 4a across all six `--lit` skills: real resolver call, all-directive branching,
  executable `AskUserQuestion` instructions, the new "Search online to ingest" option, and
  consistent use of `literature-briefing-invoke.sh`.
- Extract the shared Stage 4a block into a single core-context file the six skills import.
- Preserve the autonomous contract: fix the `orchestrator_mode` semantic conflict so
  `/orchestrate --lit` never attempts `AskUserQuestion` during any phase, and always emits a
  visible `[lit:auto]` notice.
- Keep EXTENSION.md and the CLAUDE.md merge source (`claudemd.md`) in sync; never hand-edit the
  generated `.claude/CLAUDE.md`.

**Non-Goals**:
- Auto-downloading / auto-attaching literature to Zotero in autonomous contexts (online ingest is
  an explicit interactive user choice only; autonomous runs keep the read-only global-corpus
  fallback).
- Changing `literature-ingest-online.sh` or `literature-discover.sh` (task 866 bridge is a stable
  consumed contract).
- Fixing the stale `.claude-extensions.json` pin state (a deployment/picker concern, out of scope
  per the research Context & Scope note).
- Editing any generated `.claude/` deploy-tree file directly.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Two-checkpoint sparsity adds a second prompt that surprises a user who already answered | M | M | Only re-prompt on the global-sparse path when the user's first choice was "Use global corpus now"; never after "Skip this run" or "Create curation task" (Phase 4 encodes this in the shared block). |
| `orchestrator_mode: false -> true` change to orchestrate skills has wider blast radius than the six skills | H | M | Verified safe by research (no research/planner skill reads the field today for any purpose; only `skill-implementer` uses it for handoff-write gating). Phase 3 changes exactly the 2 skills x 2 dispatch sites and adds a dual-consumer cross-reference so future edits do not silently regress. |
| "Search online to ingest" performs live network calls (discover + PDF download) inside Stage 4a | M | M | Gate strictly as an explicit interactive user choice; autonomous contexts default to the read-only global-corpus fallback, never online ingest. |
| Shared Stage 4a file placed in the literature extension breaks the six core skills' `@`-import when literature is not loaded | H | M | Place the shared block in **core** context (skills are core, deployed unconditionally) so the `@`-reference always resolves; it documents literature behavior but lives beside the core skills that reference it. Phase 4 fixes this location decision. |
| Counting "relevant chunks" duplicates `literature-briefing.sh`'s resolution loop | M | M | Single-source the count: resolver owns up-front classification count; briefing owns post-global-search count. Neither re-implements the other's jq queries (Decision 1 / Risk 4). |
| Off-by-one / boundary error in threshold comparison (`< 3` vs `<= 3`) | M | L | Phase 7 exercises the resolver at counts 2, 3, 4 against fixtures to pin the exact boundary (`< threshold` = sparse). |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5, 6 | 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Surface count + sparse signal + threshold in literature-briefing.sh [COMPLETED]

**Goal**: Make `literature-briefing.sh` emit a machine-readable coverage count and a loud
`[SPARSE COVERAGE ...]` banner for both modes, gated by a new `LITERATURE_SPARSE_THRESHOLD` env var.

**Tasks**:
- [x] Add `LITERATURE_SPARSE_THRESHOLD="${LITERATURE_SPARSE_THRESHOLD:-3}"` near the other
  env-var-default declarations (mirror `GLOBAL_TOP_N_DEFAULT` at ~line 52), and document it in the
  script header comment alongside `LITERATURE_DIR`.
- [x] In global mode, promote the existing internal `seg_count` (~line 311) to a machine-readable
  emission: a stable, greppable marker line (e.g. an HTML-comment token
  `<!-- lit-coverage mode=global seg_count=N sparse=true|false threshold=T -->`) rendered into the
  briefing output so a caller can parse it without scraping the human header.
- [x] In per-repo mode, compute the equivalent count from `${#briefing_lines[@]}` and emit the same
  marker line with `mode=repo`.
- [x] When the count is `< LITERATURE_SPARSE_THRESHOLD`, prepend a `[SPARSE COVERAGE - N segment(s),
  threshold T]` banner into the rendered briefing content, in the same family/placement as the
  existing `[UNVERIFIED ...]` (`FIDELITY_MARKER_TEXT`, ~lines 117-119) and `[DEGRADED RETRIEVAL
  ...]` (~lines 353-372) banners -- visible to the consuming agent, never silently dropped.
- [x] Keep the existing human-readable header lines unchanged (additive only).

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-briefing.sh` - add env var, machine-readable
  count marker (both modes), and `[SPARSE COVERAGE ...]` banner.

**Verification**:
- Run the script in both modes against a small fixture; confirm the marker line and (when under
  threshold) the banner appear; confirm existing output is otherwise byte-stable.
- `bash -n` clean.

---

### Phase 2: Add SPARSE_PROMPT_NEEDED directive + count to literature-lit-flag-resolve.sh [COMPLETED]

**Goal**: Teach the single classification authority to compute an up-front coverage count and emit
the new `SPARSE_PROMPT_NEEDED` directive for the sub-index-sparse case.

**Tasks**:
- [x] Add `LITERATURE_SPARSE_THRESHOLD="${LITERATURE_SPARSE_THRESHOLD:-3}"` with the same default as
  Phase 1; document it in the script header.
- [x] In the `SUBINDEX_PRESENT` branch, compute the resolved chunk/doc count with the lightweight
  `jq '.entries | length'` / resolution the resolver already has paths for (reuse, do not duplicate,
  `literature-briefing.sh`'s resolution loop -- Risk 4). If count `>= threshold`, keep emitting
  `SUBINDEX_PRESENT` unchanged; if `< threshold` (including 0 entries that resolve to nothing),
  emit `SPARSE_PROMPT_NEEDED` instead.
- [x] Document (in a header comment / directive list) that `SPARSE_PROMPT_NEEDED` is also reachable
  from a *second* call site -- after a global search already ran and returned `< threshold`
  segments -- which is detected by the caller via Phase 1's marker line, NOT by re-invoking the
  resolver (the resolver stays single-shot; the two-checkpoint shape lives in the skill/shared
  block, per Decision 3).
- [x] Keep the other four directives (`LIT_DISABLED`, `GLOBAL_MISSING`, `PROMPT_NEEDED`,
  `AUTONOMOUS_GLOBAL`) unchanged; `SPARSE_PROMPT_NEEDED` is a refinement, not a replacement.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` - add threshold, count
  computation, and the `SPARSE_PROMPT_NEEDED` directive.

**Verification**:
- Fixtures: sub-index with 0, 2, 3, and 4 resolving entries; confirm the directive is
  `SPARSE_PROMPT_NEEDED` for 0/2 and `SUBINDEX_PRESENT` for 3/4 (boundary = `< threshold`).
- Confirm `LIT_DISABLED` / `GLOBAL_MISSING` / `AUTONOMOUS_GLOBAL` paths are unchanged.
- `bash -n` clean.

---

### Phase 3: Fix orchestrator_mode autonomy conflict + dual-consumer doc note [COMPLETED]

**Goal**: Ensure `/orchestrate --lit` is treated as unattended in every phase (research, plan,
implement), so Stage 4a never attempts `AskUserQuestion` with no human present.

**Tasks**:
- [x] In `skill-orchestrate/SKILL.md`, change the Stage 4 dispatch context so `orchestrator_mode:
  true` is passed for the `not_started` (research) and `researched` (plan) dispatches, matching the
  existing `true` for the `planned`/`implementing` and `partial`-continuation dispatches (option (a)
  from Decision 5).
- [x] Mirror the same change in `skill-orchestrate-hard/SKILL.md` (its false-valued research/plan
  dispatch sites).
- [x] Add a one-line cross-reference in `agent-system/extensions/core/docs/architecture/handoff-schema.md`
  (and, if it documents the field, `architecture-spec.md`) noting `orchestrator_mode` now has TWO
  consumers: the `.orchestrator-handoff.json` write gate AND the literature Stage 4a
  autonomy/AskUserQuestion gate -- so future edits do not regress one while fixing the other.
- [x] Verify no research/planner skill currently reads `orchestrator_mode` for the handoff-write
  gate (only `skill-implementer` does) so this change activates only the new autonomy behavior.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - research/plan dispatch
  `orchestrator_mode: true`.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - same.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - dual-consumer note.
- `agent-system/extensions/core/docs/architecture/architecture-spec.md` - dual-consumer note (only
  if it documents `orchestrator_mode`).

**Verification**:
- Grep the two orchestrate skills for `orchestrator_mode:` and confirm all research/plan/implement
  dispatch sites now read `true`.
- Confirm the handoff-write gate description still holds (implement-only writers) after the note.

---

### Phase 4: Author the shared reconciled Stage 4a block (core context) [COMPLETED]

**Goal**: Produce ONE canonical Stage 4a "Literature" block, in core context, that all six skills
will import -- eliminating the six-way drift class.

**Tasks**:
- [x] Create a new shared file in **core** context (e.g.
  `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`) -- placed in core, not the
  literature extension, so the six core skills' `@`-import resolves even when literature is not in
  the selected extension set (Risk: broken `@`-reference).
- [x] Write the reconciled Stage 4a logic as **direct, executable instructions** (never
  commented-out pseudocode inside a bash fence -- the root cause of the current drift): (a) call
  `literature-lit-flag-resolve.sh` with the correct `--orchestrator-mode` argument threaded from the
  delegation context; (b) branch on all six directives (`LIT_DISABLED`, `SUBINDEX_PRESENT`,
  `GLOBAL_MISSING`, `PROMPT_NEEDED`, `AUTONOMOUS_GLOBAL`, `SPARSE_PROMPT_NEEDED`).
- [x] For `PROMPT_NEEDED` and `SPARSE_PROMPT_NEEDED` (interactive), issue a real `AskUserQuestion`
  with the options: "Use global corpus now", "Create curation task", "Search online to ingest"
  (new), and "Skip this run". Encode the "Search online to ingest" chain: `literature-discover.sh
  "<query>"` -> filter records with `status` in {open_access, paywall, in_zotero_no_pdf} ->
  per-record `literature-ingest-online.sh --record '<json>'` -> re-run
  `literature-briefing-invoke.sh` (per-repo mode, since the bridge self-registers into the
  sub-index).
- [x] Encode the two-checkpoint shape: after "Use global corpus now" runs a global search, inspect
  Phase 1's `<!-- lit-coverage ... sparse=true -->` marker; if sparse, re-prompt with the
  `SPARSE_PROMPT_NEEDED` option set (adding "Search online to ingest"). Only re-prompt if the first
  choice was "Use global corpus now" -- never after "Skip this run"/"Create curation task" (Risk 1).
- [x] Encode the autonomous path: when the resolved directive is `AUTONOMOUS_GLOBAL` (or any
  prompt-needing directive is reached while unattended), MUST NOT call `AskUserQuestion`; take the
  deterministic read-only global-corpus default and emit a visible `[lit:auto]` notice. Autonomous
  runs never trigger online ingest (Risk 3).
- [x] Standardize the briefing call on `literature-briefing-invoke.sh` (never raw
  `literature-briefing.sh 2>/dev/null`) throughout the block (Finding 4).

**Timing**: 2 hours

**Depends on**: 2, 3

**Files to modify**:
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (new) - the single shared
  Stage 4a block.

**Verification**:
- Re-read the file; confirm every `AskUserQuestion` is a direct instruction (not inside a comment or
  a `bash` fence as `#` pseudocode).
- Confirm all six directives are handled and the autonomous branch never prompts.
- Confirm the online-ingest chain names `literature-discover.sh` and `literature-ingest-online.sh
  --record` correctly.

---

### Phase 5: Wire all six --lit skills to the shared block [COMPLETED]

**Goal**: Replace each skill's drifted inline Stage 4a with an `@`-import of the shared block, and
remove every raw briefing call site.

**Tasks**:
- [x] In each of the six `SKILL.md` files (`skill-researcher`, `skill-planner`, `skill-implementer`,
  `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`), replace the ~70-110-line
  drifted Stage 4a block with a reference/`@`-import to
  `context/patterns/lit-stage4a-flow.md` (deployed path), preserving each skill's surrounding stage
  numbering and injection point (after `<memory-context>`, before task instructions).
- [x] Remove the four remaining raw `literature-briefing.sh 2>/dev/null` call sites
  (`skill-researcher`, `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`);
  the shared block is now the single caller and it uses `literature-briefing-invoke.sh`.
- [x] Confirm `skill-planner` and `skill-implementer` (already on the wrapper) converge to the same
  shared block with no divergence.
- [x] Ensure the `--orchestrator-mode` argument passed by the shared block is sourced from each
  skill's delegation context (now `true` for all `/orchestrate --lit` phases after Phase 3).

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher/SKILL.md`
- `agent-system/extensions/core/skills/skill-planner/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md`
- `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-planner-hard/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`

**Verification**:
- `grep -rl 'literature-briefing.sh 2>/dev/null' agent-system/extensions/core/skills/` returns
  nothing.
- All six skills reference `lit-stage4a-flow.md`; no skill retains an inline commented-out
  `AskUserQuestion` pseudocode block.

---

### Phase 6: Sync EXTENSION.md, CLAUDE.md merge source, and adhoc directive [COMPLETED]

**Goal**: Bring the documentation in line with the new behavior; never hand-edit the generated
`.claude/CLAUDE.md`.

**Tasks**:
- [x] Add a "Sparse-Coverage Detection" subsection to
  `agent-system/extensions/literature/EXTENSION.md` summarizing the `SPARSE_PROMPT_NEEDED`
  directive, the `LITERATURE_SPARSE_THRESHOLD` env var (default 3), the "Search online to ingest"
  option, and a cross-reference to the fuller spec in `claudemd.md`.
- [x] Update the CLAUDE.md merge source `agent-system/extensions/core/merge-sources/claudemd.md`:
  extend the `--lit` "Interactive Sub-Index Setup Detection" section to list six directives
  (add `SPARSE_PROMPT_NEEDED`), document the `LITERATURE_SPARSE_THRESHOLD` env var, add the
  "Search online to ingest" option to the prompt option list, and note the `orchestrator_mode`
  dual-consumer/autonomy contract for all `/orchestrate --lit` phases.
- [x] Update `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
  so its "Sources of Truth" / option list matches the reconciled Stage 4a (six directives, new
  online-ingest option) -- it is cited by CLAUDE.md as the ad-hoc counterpart of Stage 4a.
- [x] Do NOT edit `.claude/CLAUDE.md` (auto-generated from merge sources).

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `agent-system/extensions/literature/EXTENSION.md`
- `agent-system/extensions/core/merge-sources/claudemd.md`
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`

**Verification**:
- Grep the three docs for `SPARSE_PROMPT_NEEDED`, `LITERATURE_SPARSE_THRESHOLD`, and "Search online
  to ingest"; confirm present and consistent.
- Confirm no edits were made to any `.claude/` deploy-tree file.

---

### Phase 7: End-to-end verification [NOT STARTED]

**Goal**: Confirm the scripts, skills, and docs are internally consistent and the boundary behavior
is correct.

**Tasks**:
- [ ] `bash -n` (and `shellcheck` if available) on both modified scripts.
- [ ] Drive `literature-lit-flag-resolve.sh` against fixtures at counts 2/3/4 and confirm the exact
  `SPARSE_PROMPT_NEEDED` <-> `SUBINDEX_PRESENT` boundary (`< threshold`); repeat with an overridden
  `LITERATURE_SPARSE_THRESHOLD` to confirm the env var is honored.
- [ ] Drive `literature-briefing.sh` in both modes and confirm the machine-readable marker line and
  `[SPARSE COVERAGE ...]` banner appear under threshold and are absent at/above threshold.
- [ ] Confirm all six skills reference the shared block and no raw `literature-briefing.sh
  2>/dev/null` remains (`grep`).
- [ ] Confirm the autonomous path emits `[lit:auto]` and never `AskUserQuestion` (static read of the
  shared block + the two orchestrate dispatch contexts).
- [ ] Run the extension doc-lint if present
  (`.claude/scripts/check-extension-docs.sh` / `check-extension-docs.sh`) and resolve any failures.

**Timing**: 1 hour

**Depends on**: 5, 6

**Files to modify**:
- None (verification only; fix-forward into the relevant phase's files if a defect is found).

**Verification**:
- All checks above pass; boundary behavior matches the documented threshold semantics.

## Testing & Validation

- [ ] `bash -n` clean on `literature-briefing.sh` and `literature-lit-flag-resolve.sh`.
- [ ] Resolver emits `SPARSE_PROMPT_NEEDED` for resolved counts `< LITERATURE_SPARSE_THRESHOLD` and
  `SUBINDEX_PRESENT` at/above it; env-var override honored.
- [ ] Briefing emits a greppable machine-readable coverage marker in both modes and a loud
  `[SPARSE COVERAGE ...]` banner under threshold.
- [ ] `grep -rl 'literature-briefing.sh 2>/dev/null' agent-system/extensions/core/skills/` returns
  nothing.
- [ ] All six skills reference the single shared `lit-stage4a-flow.md`; none retains commented-out
  `AskUserQuestion` pseudocode.
- [ ] `/orchestrate --lit` dispatch contexts pass `orchestrator_mode: true` for research, plan, and
  implement; autonomous Stage 4a emits `[lit:auto]` and never prompts.
- [ ] EXTENSION.md, `claudemd.md`, and `adhoc-navigation-directive.md` document the new directive,
  threshold, and online-ingest option consistently; `.claude/CLAUDE.md` untouched.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-briefing.sh` (modified)
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` (modified)
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (new, shared Stage 4a block)
- Six `agent-system/extensions/core/skills/skill-{researcher,planner,implementer}{,-hard}/SKILL.md`
  (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md` (modified)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (and possibly
  `architecture-spec.md`) (modified)
- `agent-system/extensions/literature/EXTENSION.md` (modified)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified)
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`
  (modified)
- `specs/867_sparse_lit_detection_stage4a/summaries/01_sparse-lit-stage4a-wiring-summary.md`
  (on completion)

## Rollback/Contingency

- All changes are source-tree edits under `agent-system/extensions/` (no runtime state, no data
  migration). Revert is a `git checkout` / `git revert` of the touched files.
- The scripts are additive: the new marker line, banner, and `SPARSE_PROMPT_NEEDED` directive are
  refinements that leave the five existing directives and existing output intact, so a partial
  landing (scripts only, skills not yet wired) is non-breaking -- skills that do not yet call the
  resolver simply do not see the new directive.
- If the shared-block `@`-import proves unresolvable for a skill (e.g. a deploy-path mismatch),
  fall back to keeping the reconciled block inline per-skill for that skill only, and file a
  follow-up to complete the extraction -- the behavioral fix (real resolver call, executable
  prompt, wrapper usage) must land regardless of whether the DRY extraction fully succeeds.
