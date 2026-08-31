# Implementation Plan: Build hard_contracts manifest key and contract-text injection

- **Task**: 118 - Build hard_contracts manifest key and contract-text injection at dispatch-prep time
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: Task 117 (Stage 3.5 Dispatch Prep) — landed, confirmed by research
- **Research Inputs**: specs/118_build_hard_contracts_injection/reports/01_hard-contracts-injection-design.md
- **Artifacts**: plans/01_hard-contracts-injection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Centralize hard-mode contract text so that a `--hard` dispatch injects the ordered
`context/contracts/*.md` reference block into its sub-agent prompt from ONE place —
`skill-orchestrate/SKILL.md`'s Stage 3.5 Dispatch Prep — instead of from seven separate `-hard`
skill/agent files. Three deliverables: (1) a `hard_mode` boolean derived once at Stage 1/MT-1 and
a new gated contract-injection subsection in Stage 3.5 producing a 4th output,
`hard_contracts_block`; (2) an optional `hard_contracts` manifest key resolved through a new
one-level sibling of the routing ladder, `routing_lookup_flat()`; (3) a non-blocking deploy-time
warning steering extensions off `routing_hard`/`routing_agents_hard`. Definition of done: a
`--hard` orchestrate dispatch's prompt carries the correct per-phase contract list, a default
dispatch's prompt is byte-identical to today's, and `verify-deploy.sh` still exits 0.

### Research Integration

The research report is the primary input and its Findings/Decisions are adopted wholesale. Four
findings shape this plan directly:

1. **Stage 3.5 is the single injection point.** It already has an `Inputs` table, named
   procedures, and an `Outputs and injection contract` paragraph consumed by exactly 10
   dispatch-site pointer lines (7 single-task, 3 multi-task). Adding a 4th output is a
   find-and-replace across shared fixed phrasings, not 10 hand-edits.
2. **`skill-orchestrate-hard/SKILL.md` is unreachable.** `commands/orchestrate.md` hardcodes
   `skill: "skill-orchestrate"` for both single- and multi-task dispatch and never names the
   `-hard` variant as a Skill-tool target. All `hard_mode` logic therefore lands in
   `skill-orchestrate/SKILL.md`. **No edit to `skill-orchestrate-hard/SKILL.md` is in scope.**
3. **`hard_contracts` has a different manifest shape** (`{task_type: [...]}`, one level) than the
   four existing routing blocks (`{op: {task_type: value}}`, two levels), so it needs a parallel
   `routing_lookup_flat()` rather than a forced reuse of `routing_lookup()` with a fabricated
   `op` key.
4. **The deploy warning's wording deviates from the originating design report deliberately** —
   see Decision 4 below. This deviation is recorded, not silent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- Derive a `hard_mode` boolean once, at Stage 1 and Stage MT-1, from `effort_flag == "hard"`.
- Add a `hard_mode`-gated contract-injection subsection to Stage 3.5 producing a
  `hard_contracts_block` output with fixed, ordered per-phase contract lists.
- Add `hard_contracts_block` as the 4th appended output at all 10 dispatch sites, with the same
  empty-skip rule as the existing three.
- Add `routing_lookup_flat(block, task_type)` to `manifest-routing-lib.sh` with the same 4-step
  non-core/core x exact/compound precedence against a one-level `jq` path.
- Resolve extension-declared `hard_contracts` entries, supporting `replace:core.md:override.md`
  substitution as well as plain additive entries.
- Add a non-blocking `gate16` + `warn()` helper to `verify-deploy.sh` flagging any extension still
  declaring `routing_hard`/`routing_agents_hard`.
- Document `hard_contracts` in `manifest-routing-schema.md` and cross-reference it from
  `hard-mode-routing.md`.

**Non-Goals**:
- Stateful hard-mode logic: churn/three-strikes counters (H5/H6), the burnout circuit breaker,
  and the single-blocking-phase-per-cycle implement dispatch limiter (H1). These are state-machine
  branches, not prompt-injectable text, and belong to the dependent follow-on task. This plan only
  defines the `hard_mode` boolean that work will read.
- Deleting `skill-orchestrate-hard/SKILL.md` or any of the six other `-hard` skill/agent files.
  This task is purely additive; the deletion is a later link in the same chain.
- Any change to `command-route-skill.sh` / `command-route-agent.sh` resolution, or to
  `/research`, `/plan`, `/implement` routing. `routing_hard`/`routing_agents_hard` stay live and
  consulted after this task lands.
- Populating any extension's `hard_contracts` block. Zero of the 19 manifests declare one today;
  the mechanism is additive and stays unexercised by real data on day one.
- Authoring new contract prose. `context/contracts/*.md` already holds the text; this is a
  consumer-count reduction.

## Decisions

1. **`hard_mode` derivation site**: Stage 1 (single-task) and Stage MT-1 (multi-task), not inside
   Stage 3.5. Both stages already read `effort_flag` from the delegation context. Deriving it
   above Stage 3.5 lets the follow-on stateful work read the same boolean from the loop-guard,
   burnout, and churn-detection stages without re-deriving it.

2. **Contract lists are fixed, per-phase, ordered arrays** — not re-derived per dispatch. Order is
   each collapsed file's own declared reference order:

   | Phase | Contracts, in order |
   |-------|----------------------|
   | `research` | `anti-analysis.md`, `reference-grounding.md`, `adversarial-verification.md` |
   | `plan` | `reference-grounding.md`, `wrap-up.md`, `anti-analysis.md` |
   | `implement` | `anti-analysis.md`, `wrap-up.md`, `territory.md` (conditional), `recovery.md`, `phase-closure.md`, `pre-edit-gate.md` |

   Two contracts are deliberately excluded from every list: `convergence.md` (stateful counters,
   not prompt text — follow-on task's scope) and `orchestrator-discipline.md` (governs the
   orchestrator's own behavior, read directly, never injected into a sub-agent prompt).

3. **`territory.md` is conditional on a Stage 3.5 `territory` input that no call site sets today.**
   `skill-orchestrate/SKILL.md` carries an existing decision record that base mode does NOT gain a
   `territory` dispatch key. Defining the input now — always empty, so `territory.md` never
   appears in practice — makes the sibling team-mode fan-out task a data change rather than a
   redesign of contract selection.

4. **Deploy-warning wording deviates from the originating design report, deliberately.** That
   report's suggested text says `routing_hard`/`routing_agents_hard` are "no longer consulted".
   That statement would be **factually false the moment this gate starts running**: both blocks
   remain genuinely consulted by `command-route-skill.sh` (for `/research`, `/plan`,
   `/implement`) and by `command-route-agent.sh` until the two dependent follow-on tasks land.
   Use "being replaced / migrate to `hard_contracts`" framing instead — true now (migration in
   progress) and true afterwards (when the remaining audience is a new extension mistakenly
   adding the old blocks). The implementer may adjust exact wording but MUST NOT restore the "no
   longer consulted" framing.

5. **`routing_lookup_flat()` is a sibling function, never a wrapper over `routing_lookup()`** with
   a fabricated `op` key. Its doc comment must state the one-level/two-level shape mismatch
   explicitly so a future editor does not "simplify" it into the two-level path.

6. **Grep-count correction to the research report** (verified against the current file at plan
   time): the report states the shared lead-in phrase
   `` `memory_context`, `lit_context`, and `effort_note`. `` occurs 10 times. It occurs **7**
   times — the 3 multi-task occurrences are line-wrapped and the phrase spans two lines there.
   The 10-count holds for the shorter substring `` `lit_context`, and `effort_note`. ``. Phase 3
   uses the shorter substring. The other two counts in the report (7 and 3) were re-verified and
   are correct.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A dispatch-site phrasing drifted since the counts were taken, so a global replace silently misses a site | H | L | Phase 3 re-runs all three greps as a hard precondition and aborts if any count differs from 7/3/10; re-runs them after editing to confirm 0 old / 7-3-10 new |
| A future editor collapses `routing_lookup_flat()` into `routing_lookup()` with a fake `op` | M | M | Doc comment states the shape mismatch verbatim; Phase 6 confirms the comment survived |
| `hard_mode=false` dispatches change (regression on the default path) | H | L | Phase 6 verifies default-path prompt construction is byte-identical: empty-skip, never an empty `<hard-mode-contracts>` tag pair |
| `gate16` accidentally flips `verify-deploy.sh`'s exit code | M | L | `warn()` increments `CHECKS` only, never `FAILURES`; Phase 4 verifies exit code 0 with 3 warnings present |
| Deploy-warning wording reverts to "no longer consulted" during review | L | M | Decision 4 records the reasoning in this plan; Phase 4 tasks state the prohibition inline |
| Task-number references leak into `agent-system/**` deliverables | M | L | Every phase's edits use durable anchors (file names, section headings); Phase 6 greps for task-number patterns in the diff |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 5 | 1, 4 |
| 3 | 3 | 2 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add `routing_lookup_flat()` to the routing library [COMPLETED]

**Goal**: `manifest-routing-lib.sh` can resolve a one-level manifest block
(`{task_type: [...]}`) with the same precedence ladder it already applies to two-level blocks,
without changing any existing function.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` in full, noting
      `routing_lookup()`'s local-variable naming (`_route_*`), its unset-before-return discipline,
      and how it sets `_ROUTE_LAST_VALUE` / `_ROUTE_LAST_VIA`.
- [x] Add `routing_lookup_flat(block, task_type)` immediately after `routing_lookup()`'s closing
      brace and before `routing_trace()`.
- [x] Implement the same 4-step first-match-wins precedence: non-core exact -> non-core
      compound-base -> core exact -> core compound-base -> miss (empty output, return 0).
- [x] Use `jq -c '(.[$b] // {})[$tt] // empty'` — `-c`, not `-r`, because the resolved value is a
      JSON array, not a scalar.
- [x] Set `_ROUTE_LAST_VALUE` / `_ROUTE_LAST_VIA` on the same terms as `routing_lookup()`
      (`noncore-exact|noncore-compound|core-exact|core-compound|miss`).
- [x] Preserve the library's stated contract: never call `exit`, never set shell options, prefix
      and unset every internal variable, always return 0.
- [x] Write a doc comment above the function stating the one-level vs. two-level shape mismatch
      and why this is NOT a wrapper over `routing_lookup()` (Decision 5).
- [x] Add one `routing_lookup_flat "hard_contracts" "general"` usage line to the file's header
      `# Usage:` block.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — new function + header usage line

**Verification**:
- `bash -n agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` passes.
- Source the library and call `routing_lookup_flat "hard_contracts" "general"` against the current
  tree; confirm it returns cleanly with `_ROUTE_LAST_VIA=miss` and empty `_ROUTE_LAST_VALUE` (no
  manifest declares the block yet).
- Add a temporary `hard_contracts` block to a scratch copy of a manifest under a temporary
  `ROUTE_MANIFEST_ROOT` and confirm exact-match and compound-base (`ext:subtype`) resolution both
  hit, then remove the scratch copy.
- Both existing consumers still pass unmodified:
  `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` and
  `bash agent-system/extensions/core/scripts/test-routing-resolution.sh` (resolve the exact
  paths at implementation time; the function is purely additive so neither should need edits).

---

### Phase 2: Stage 3.5 hard-mode contract injection [NOT STARTED]

**Goal**: `skill-orchestrate/SKILL.md` derives `hard_mode` once and Stage 3.5 produces a 4th
output, `hard_contracts_block`, when `hard_mode == "true"`.

**Tasks**:
- [ ] Stage 1 ("Input Validation"): add a `hard_mode` bullet to the delegation-context read list,
      derived as `hard_mode="false"; [ "$effort_flag" = "hard" ] && hard_mode="true"`, with a
      one-line note that it is consumed by Stage 3.5 and reserved for later conditional
      state-machine branches.
- [ ] Stage MT-1 ("Parse Multi-Task Context"): add the identical derivation and note.
- [ ] Stage 3.5 `Inputs` table: add a `hard_mode` row (source: Stage 1 / Stage MT-1) and a
      `territory` row (optional; currently set by no call site — per Decision 3).
- [ ] Insert a new subsection, "Hard-mode contract injection (gated on `hard_mode == \"true\"`)",
      between the existing "Effort-depth note" and "Outputs and injection contract" paragraphs.
- [ ] In that subsection, specify (a) the fixed per-phase `core_contracts` array via a case
      statement over `$phase`, using the exact three lists in Decision 2, with `territory.md`
      appended only when the `territory` input is non-empty.
- [ ] Specify (b) extension resolution: call
      `routing_lookup_flat "hard_contracts" "$task_type"`; on a hit, apply every
      `replace:{core-basename}:{override-path}` entry as an in-place substitution of the matching
      core-list element (matched by exact basename), then append every remaining non-`replace:`
      entry additively. On a miss, the core list stands unchanged.
- [ ] Specify (c) the `hard_contracts_block` string build: a `<hard-mode-contracts>` tag wrapping
      one `- context/contracts/{file}` line per resolved entry, in resolved order. When
      `hard_mode` is `"false"`, `hard_contracts_block` stays empty and NO tag is emitted.
- [ ] Update the "Outputs and injection contract" paragraph: name `hard_contracts_block` as a 4th
      output, appended LAST (after `effort_note`), under the same empty-skip rule, and likewise
      never added to the dispatch's `context` JSON object.
- [ ] Use durable anchors only — no task-number references anywhere in the added prose.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three per-phase contract lists (3, 3, and 6
entries) naming 6 distinct files, and that `convergence.md` and `orchestrator-discipline.md` are
correctly excluded. Confirm at implementation time by listing
`agent-system/extensions/core/context/contracts/` and checking every named file exists, and by
re-reading the collapsed `-hard` skill/agent files' own reference lists to confirm the orders
still match before transcribing them.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage 1, Stage MT-1, Stage
  3.5 Inputs table, new Stage 3.5 subsection, Outputs paragraph

**Verification**:
- Every file named in the three contract lists exists under
  `agent-system/extensions/core/context/contracts/`.
- `convergence.md` and `orchestrator-discipline.md` appear in NO list.
- The Stage 3.5 Inputs table has both new rows; the Outputs paragraph names all four outputs in
  append order.
- The default path is explicit in the prose: `hard_mode="false"` yields an empty
  `hard_contracts_block` and no `<hard-mode-contracts>` tag pair.
- `grep -c 'hard_mode' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` shows hits
  in Stage 1, Stage MT-1, and Stage 3.5 only — not in any dispatch-site table row.

---

### Phase 3: Thread `hard_contracts_block` through all 10 dispatch sites [NOT STARTED]

**Goal**: Every dispatch-site pointer line in `skill-orchestrate/SKILL.md` names
`hard_contracts_block` as the 4th appended output.

**Tasks**:
- [ ] **Precondition (hard gate)**: re-run all three greps against
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and confirm the counts
      below exactly. If ANY count differs, stop and re-scope rather than editing:
      - `` `lit_context`, and `effort_note`. `` -> 10 (the "to produce X, Y, and Z" lead-in;
        note this is the SHORTER substring, per Decision 6)
      - ``then append `memory_context`, then `lit_context`, then `effort_note` from Stage 3.5, each skipped when empty`` -> 7 (single-task rows)
      - ``with `memory_context`, then `lit_context`, then `effort_note` from Stage 3.5 appended, each skipped when empty`` -> 3 (multi-task loop rows)
- [ ] Pass 1 (10 sites): extend the lead-in phrase so each pointer line says it produces the
      fourth output too.
- [ ] Pass 2 (7 single-task rows): extend the trailing append clause with `hard_contracts_block`
      as the final item, preserving the "each skipped when empty" rule.
- [ ] Pass 3 (3 multi-task rows): same extension to the multi-task phrasing.
- [ ] Confirm no dispatch site adds any of the four outputs to its `context` JSON object.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts 10 / 7 / 3 occurrences of three fixed phrasings in one
file. Confirm by running the three greps immediately before editing (the precondition gate above)
and again immediately after, expecting 0 hits on each OLD pattern and 10 / 7 / 3 on each NEW
pattern. Any deviation is a scope change, not an edit to force through.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — 10 dispatch-site pointer lines

**Verification**:
- Post-edit greps: 0 hits for each of the three OLD patterns; 10 / 7 / 3 hits for the
  corresponding NEW patterns.
- `grep -c 'hard_contracts_block' <file>` equals 10 dispatch-site hits plus the Stage 3.5
  definition/outputs hits; enumerate and account for each.
- Spot-read three sites (one research, one implement-resume, one multi-task loop) end to end to
  confirm the append order reads `memory_context` -> `lit_context` -> `effort_note` ->
  `hard_contracts_block`.

---

### Phase 4: `verify-deploy.sh` non-blocking migration warning [NOT STARTED]

**Goal**: The deploy verifier warns — without failing — about any extension still declaring
`routing_hard` or `routing_agents_hard`.

**Tasks**:
- [ ] Add a `warn()` helper alongside `pass()` / `fail()`: increments `CHECKS`, NEVER `FAILURES`,
      echoes to stderr the way `fail()` does, and appends to `FINDINGS_LIST` when `FINDINGS` mode
      is on.
- [ ] Add `gate16` immediately after `gate15`'s closing `fi` and before the final `say ""` /
      PASS-FAIL summary block.
- [ ] `gate16` iterates `${CLAUDE_DIR}/extensions/*/manifest.json` and warns on any manifest
      matching `has("routing_hard") or has("routing_agents_hard")`, naming the extension.
- [ ] Warning text uses the "being replaced / migrate to `hard_contracts`" framing and points at
      `context/guides/manifest-routing-schema.md`. **Do NOT use "no longer consulted"** — see
      Decision 4; that phrasing would be factually false while those blocks are still consulted.
- [ ] Update the file's header comment gate range from "(gate0 through gate15)" to
      "(gate0 through gate16)".
- [ ] Emit a `pass()` when no manifest declares either block, so the gate is never silent.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly 3 of 19 extension manifests declare
`routing_hard`/`routing_agents_hard` (`core`, `cslib`, `lean`). Confirm at implementation time by
re-running the `has()` check across `agent-system/extensions/*/manifest.json` before writing the
gate, and by counting `gate16` findings after.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `warn()` helper, `gate16`, header
  comment gate range

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` passes.
- Running the deployed verifier emits exactly 3 `gate16` warnings (`core`, `cslib`, `lean`) and
  the final line still reports `0 failure(s)`.
- Exit code is 0 (`echo $?` after the run) — the warnings do not flip it.
- `--findings` mode lists 3 `FINDING gate16` lines.
- `grep -n 'no longer consulted' agent-system/extensions/core/scripts/verify-deploy.sh` returns
  nothing.

---

### Phase 5: Document `hard_contracts` in the routing guides [NOT STARTED]

**Goal**: The canonical manifest-key enumeration covers `hard_contracts`, so the warning added in
Phase 4 points at a live explanation rather than a dead reference.

**Tasks**:
- [ ] In `manifest-routing-schema.md`, extend the "## The Four Blocks" section to cover
      `hard_contracts` as a fifth block, renaming the heading accordingly (it is now five, and
      the fifth has a genuinely different shape).
- [ ] Document `hard_contracts`'s one-level `{task_type: [path, ...]}` shape and contrast it with
      the four two-level `{op: {task_type: value}}` blocks; state that it resolves via
      `routing_lookup_flat()`, not `routing_lookup()`.
- [ ] Document the `replace:{core-basename}:{override-path}` entry form alongside plain additive
      entries, with one short example.
- [ ] Note that no extension declares the block today and that its consumer is
      `skill-orchestrate/SKILL.md`'s Stage 3.5 Dispatch Prep.
- [ ] Add one cross-reference line to `hard-mode-routing.md` (its "Related Files" section or the
      nearest apt heading) pointing at the schema doc's `hard_contracts` coverage — do not
      duplicate the mechanism there; that file is scoped to `--hard` skill/agent resolution, a
      different mechanism.
- [ ] Check whether "Four Blocks" is referenced by name elsewhere in the repo and update any such
      reference to match the renamed heading.

**Timing**: 45 minutes

**Depends on**: 1, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — fifth block documented, heading renamed
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — one cross-reference line

**Verification**:
- Diff read-through confirms every changed hunk is prose/markdown with no executable surface.
- `grep -rn 'Four Blocks' agent-system/extensions/` returns no stale references to the old
  heading name.
- The path named in Phase 4's warning text resolves to a section that actually describes
  `hard_contracts`.

---

### Phase 6: Cross-file audit and verification bar [NOT STARTED]

**Goal**: Confirm the whole change satisfies the research report's five-point verification bar and
introduced no regressions on the default (non-`--hard`) path.

**Tasks**:
- [ ] (a) Trace `EFFORT_FLAG` from `parse-command-args.sh` -> `commands/orchestrate.md` -> Stage 1
      / Stage MT-1 and confirm `hard_mode` is `"false"` unless `--hard` was passed.
- [ ] (b) For each of `research`, `plan`, `implement`, confirm the Stage 3.5 prose yields a
      `<hard-mode-contracts>` block naming exactly that phase's list in the documented order when
      `hard_mode` is true.
- [ ] (c) Confirm the `hard_mode=false` path is unchanged: empty-skip, no empty
      `<hard-mode-contracts>` tag pair, and the other three outputs' order untouched.
- [ ] (d) Re-run `lint-routing-wiring.sh` and `test-routing-resolution.sh` unmodified; both pass.
- [ ] (e) Re-run the deploy verifier: exactly 3 `gate16` findings, exit code 0.
- [ ] Confirm `skill-orchestrate-hard/SKILL.md` and the six other `-hard` skill/agent files are
      untouched by this task's diff.
- [ ] Grep the full diff for task-number references in files outside `specs/**` and remove any
      found (durable anchors only).
- [ ] Run the repo's task-reference lint and any agent-contract lint that covers the touched
      files.
- [ ] Deploy the source store to `.claude/` and re-run the verifier against the deployed tree, so
      the gate is exercised where it actually runs.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None expected (audit phase); any fix lands in the phase that owns the file.

**Verification**:
- All five points of the research report's verification bar pass and are recorded in the
  implementation summary with the actual command output.
- `git diff --stat` lists exactly the five files named across Phases 1-5 and nothing else.

---

## Testing & Validation

- [ ] `bash -n` clean on both edited shell files.
- [ ] `routing_lookup_flat()` resolves exact and compound-base keys against a scratch manifest and
      misses cleanly against the current tree.
- [ ] `lint-routing-wiring.sh` and `test-routing-resolution.sh` pass unmodified.
- [ ] Dispatch-site greps: 0 old-pattern hits, 10 / 7 / 3 new-pattern hits.
- [ ] Deploy verifier: 3 `gate16` warnings, `0 failure(s)`, exit code 0.
- [ ] Default-path prompt construction is byte-identical to pre-change behavior.
- [ ] No task-number references in any file outside `specs/**`.
- [ ] No file under `.claude/**` was hand-edited (source store only).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` — `routing_lookup_flat()`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `hard_mode` derivation,
  Stage 3.5 contract-injection subsection, 4th output threaded through 10 dispatch sites
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `warn()` helper and `gate16`
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` — fifth block documented
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` — cross-reference line
- `specs/118_build_hard_contracts_injection/summaries/01_hard-contracts-injection-summary.md`

## Rollback/Contingency

Every phase is additive and independently revertible by file:

- Phase 1: delete `routing_lookup_flat()` and its header usage line. No existing consumer calls
  it, so removal is side-effect free.
- Phases 2-3: revert `skill-orchestrate/SKILL.md`. These two phases must revert together — a
  Stage 3.5 that produces `hard_contracts_block` with dispatch sites that never append it is
  inert (harmless) but confusing; dispatch sites appending an output Stage 3.5 does not produce is
  a real defect, so never revert Phase 2 alone.
- Phase 4: delete `gate16` and `warn()`, restore the header gate range. Since `warn()` never
  touches `FAILURES`, removing it cannot change any pass/fail outcome.
- Phase 5: revert both guide files.

If the whole task must be abandoned, reverting all five files returns the system to a state where
`--hard` continues to route through `routing_hard`/`routing_agents_hard` exactly as it does today
— nothing in this task removes or disables that path.
