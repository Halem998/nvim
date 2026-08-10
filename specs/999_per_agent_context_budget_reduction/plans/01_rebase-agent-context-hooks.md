# Implementation Plan: Reduce Per-Agent Context Budget Overruns

- **Task**: 999 - Reduce the 8 standing per-agent context budget overruns
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: None (all prerequisite tasks completed)
- **Research Inputs**: `specs/999_per_agent_context_budget_reduction/reports/01_reduce-agent-budget-overruns.md`
- **Artifacts**: plans/01_rebase-agent-context-hooks.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Eight agents exceed their `validate-context-budgets.sh` token caps because each agent's
`load_when.agents` catalog in `index-entries.json` has drifted far from the set of context files
that agent's own `.md` body actually `@`-references. The fix is to rebase every affected agent's
`agents[]` hook onto its real, unconditional `@`-reference set, reclassifying conditional and
orphaned content to `task_types`-only or `on_demand: true`. Five agents clear their cap outright
this way; three implementation agents hit a structural floor (a shared always-loaded core bundle
of 9,248 tokens already exceeds their 8,000-token cap before any domain content) and receive
accurately-recomputed documented exceptions instead.

**Definition of done**: `bash .claude/scripts/validate-context-budgets.sh` reports
`Violations: 0` and exits 0, with exactly three `OK*` documented-exception rows whose declared
caps and justifications are computed from current measured file sizes. No `CAPS` value is
raised.

### Research Integration

The research report's core diagnosis is confirmed and independently re-verified at plan time.
The baseline re-measured identically (8 violations; per-agent numbers matching the report's
Finding 1 table exactly). Both correctness constraints named in the delegation were verified
directly against `index.schema.json`: `load_when` is closed (`additionalProperties: false`) over
exactly `agents`/`always`/`commands`/`task_types` — there is no `skills` key — and `on_demand:
true` is the legal disposition, already in use on 7 entries.

Plan-time verification also produced **three material corrections** to the report, each of which
changes the work:

1. **Two agents have hooked entries outside the declared `file_scope`.**
   `general-research-agent` carries 2,832 tokens from `agent-system/extensions/memory/index-entries.json`
   (`project/memory/distill-usage.md` 2,376 + `project/memory/domain/memory-reference.md` 456).
   The report's 7,160-token floor for this agent counted only core-file entries. Left untouched,
   the agent lands at 9,992 against an 8,000 cap and **fails**. Both entries are genuinely
   orphaned (verified: `general-research-agent.md` contains zero references to either) and both
   retain `commands` hooks that preserve real reach, so dropping their `agents[]` hook is the
   identical correction applied everywhere else. This requires a narrow, justified extension of
   `file_scope` — see Phase 6.

2. **The deployed index carries ghost entries with no source-store owner.**
   `.claude/context/index.json` contains `orchestration/orchestration-validation.md` (1,864 tok,
   hooked to `meta-builder-agent`) and `orchestration/subagent-validation.md` (2,504 tok, no
   agent hook), neither of which exists in any `index-entries.json`. Their content files also
   survive in the deployed tree with no source counterpart. `install-extension.sh`'s
   `merge_index_entries` is purely additive (`.entries += ...`), so a renamed or deleted entry
   persists indefinitely; the lua deploy engine's `remove_orphaned_index_entries` is keyed on
   content-file existence, which these still satisfy. **Consequence**: no source edit can remove
   the 1,864 tokens the ghost contributes to `meta-builder-agent`, and the sum of an
   implementer's edited source entries will not equal what the validator reports. The gap is
   benign for the outcome (meta-builder still clears 15,000) but must be understood in advance,
   because chasing the discrepancy is the most likely source of thrash on this task.

3. **`patterns/context-discovery.md` is hooked to `meta-builder-agent` only** (3,000 tok),
   not to the four agents the report's "Recommended `commands[]` conversion" assumed. That
   recommendation is therefore a much smaller lever than described and is not on the critical
   path for any agent; `planner-agent` and `general-research-agent` gain nothing from it. Treat
   it as optional hygiene, not a required reduction.

Additionally verified at plan time: both `neovim-implementation-agent` and
`nix-implementation-agent` genuinely `@`-reference the full core bundle
(`return-metadata-file.md` + `progress-file.md` + `summary-format.md` + `phase-closure.md` +
`pre-edit-gate.md` = 9,248 tok) despite none of it being hooked to them today. The report's
under-inclusion finding is real, and correcting it honestly is why these two agents cannot pass
by narrowing alone. Conversely, `standards/git-staging-scope.md` (2,624 tok) is hooked to both
but `@`-referenced by neither, so it is dropped from both.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Rebase each of the 8 overrunning agents' `load_when.agents` onto its real, unconditional
  `@`-reference set, derived mechanically from that agent's own `.md` body.
- Reclassify conditional (sub-task-gated) and orphaned content to `task_types`-only or
  `on_demand: true`, using only schema-legal hook shapes.
- Replace the stale `EXCEPTIONS` block in `validate-context-budgets.sh` with accurately computed,
  per-agent exceptions for the three implementation agents that cannot pass structurally.
- Reach `Violations: 0` with exit code 0 from the validator, with three transparent `OK*` rows.

**Non-Goals**:
- Raising any `CAPS` value. A cap set to current usage retires the check as an instrument; the
  task record explicitly forbids this and no phase below does it.
- Editing context content files to shrink them (e.g. trimming `return-metadata-file.md`). That is
  the natural follow-up identified by the research's Finding 6, out of scope here.
- Removing the ghost deployed entries or fixing the additive-merge defect in
  `install-extension.sh`. Recorded as follow-up; the plan works correctly around them.
- Extending the Double-Loading Check to catch the reverse-direction redundancy the research
  identified on `standards/status-markers.md`. Follow-up.
- Touching hard-mode agent variants' budgets (they carry no `CAPS` entry and are unmeasured).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits source files, re-runs validator, sees no change, and thrashes | H | H | Phase 1 establishes and proves the source-edit -> regenerate -> measure loop *before* any edit is made. No rebase phase begins until the loop is demonstrated working. |
| Ghost entries make measured totals disagree with hand-summed source entries | M | H | Ghosts are enumerated with exact token values in Phase 1 and carried as a known constant offset (+1,864 to meta-builder) into every later measurement. |
| `general-research-agent` misses its cap because memory-extension entries were out of scope | H | H | Phase 6 handles them explicitly as a narrow, justified scope extension; Phase 7 measures the result before any exception is written. |
| An exception is written with a cap below the measured total, leaving it inert | H | M | The validator applies an exception only when `total_tokens <= exception_cap`. Phase 8 is strictly ordered after Phase 7's measurement and writes caps from measured values, never estimates. This is exactly how the current exception became inert. |
| Dropping an `agents[]` hook removes real discovery reach for a live-query agent | M | L | Five agents run a live by-agent-name query; every entry dropped is either never referenced by that agent's body or retains a `task_types`/`commands` hook that reaches it equivalently. Each phase verifies this per entry rather than assuming it. |
| Schema-illegal edits (e.g. reaching for `load_when.skills`) | H | L | Verified closed schema; every phase gates on `test-index-entries-schema.sh`. `on_demand: true` with empty hooks is the only sanctioned disposition. |
| Task-number citations leak into deliverable files | M | M | `index-entries.json` and `validate-context-budgets.sh` are deliverables outside `specs/**`. Exception justification strings must cite file names and token composition, never task numbers. Gated in Phases 8 and 9. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4, 5, 6 | 1 |
| 3 | 3 | 2 |
| 4 | 7 | 3, 4, 5, 6 |
| 5 | 8 | 7 |
| 6 | 9 | 8 |

Phases within the same wave can execute in parallel. Phases 2 and 3 both edit
`core/index-entries.json` and are therefore serialized; Phases 4, 5, and 6 edit disjoint files
and may run alongside Phase 2.

---

### Phase 1: Establish the regenerate-and-measure loop [COMPLETED]

**Goal**: Prove, before editing anything, that a change to a source `index-entries.json` reaches
`.claude/context/index.json` and moves the validator's numbers — and record the ghost-entry
offset so later measurements are interpretable.

**Tasks**:
- [x] Record the baseline: `bash .claude/scripts/validate-context-budgets.sh` (expect 8
      violations; capture the full per-agent table verbatim into the progress file). *(completed:
      8 violations confirmed, matches research/plan table exactly)*
- [x] Identify the regeneration path that rebuilds `.claude/context/index.json` from
      `agent-system/extensions/*/index-entries.json`. Candidates to evaluate:
      `install-extension.sh`'s `merge_index_entries`, the lua deploy engine's pre-load cleanup
      (`lua/neotex/plugins/ai/shared/extensions/init.lua`, the `remove_orphaned_index_entries`
      path), and `deploy-headless.sh`. Document the exact working invocation. *(completed:
      `bash .claude/scripts/deploy-headless.sh`, default resync mode)*
- [x] Make a trivial reversible probe edit to one source entry's `load_when.agents`, regenerate,
      and confirm the validator's number for that agent moves by the expected amount. Revert the
      probe. *(completed: spawn-agent 5568 -> 6840 on a 1272-tok probe hook, reverted cleanly)*
- [x] Enumerate every deployed index entry with no source-store owner and record its token cost
      and agent hooks. Expected: `orchestration/orchestration-validation.md` (1,864 tok ->
      meta-builder-agent) and `orchestration/subagent-validation.md` (2,504 tok, no agent hook).
      *(completed: confirmed by full set-difference, exactly these two, no others)*
- [x] Record the resulting per-agent "unremovable offset" constant (expected: meta-builder-agent
      +1,864; all others +0) in the progress file for use by Phases 7 and 8. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly two ghost entries exist, at 1,864 and 2,504
tokens. Confirm by diffing the deployed index's path set against the union of all
`agent-system/extensions/*/index-entries.json` path sets, rather than checking only the two
predicted paths — a third ghost would silently break Phase 7's arithmetic.

**Files to modify**:
- None (measurement and probe-revert only; the probe edit must be reverted before the phase
  closes)

**Verification**:
- The documented regeneration invocation demonstrably changes a validator number and the probe is
  confirmed reverted (`git diff` on `agent-system/extensions/` is empty).
- Ghost enumeration is complete by set-difference, not by spot check.

---

### Phase 2: Rebase meta-builder-agent in core/index-entries.json [COMPLETED]

**Goal**: Bring `meta-builder-agent` from 132,984 tokens under its 15,000 cap by removing hooks
for entries its own `.md` never references.

**Tasks**:
- [x] Extract `meta-builder-agent`'s real `@`-reference set:
      `grep -oP '@\.claude/context/\K[A-Za-z0-9_./-]+\.(md|json)' agent-system/extensions/core/agents/meta-builder-agent.md | sort -u`.
      *(completed: 5 files -- formats/return-metadata-file.md, patterns/anti-stop-patterns.md,
      templates/thin-wrapper-skill.md, templates/agent-template.md,
      patterns/topic-assignment-pattern.md)*
- [x] Enumerate every core entry currently hooked to `meta-builder-agent` with its token cost.
      *(completed: 49 entries, matching plan-time count)*
- [x] For each hooked entry NOT in the real reference set: remove `meta-builder-agent` from
      `load_when.agents`. If the entry's hooks then become entirely empty, set `on_demand: true`
      in the same edit (an all-hooks-empty entry without that marker fails the Dead Entry Check).
      *(completed: 46 dropped, 39 got on_demand:true, 7 retained other hooks)*
- [x] For any real reference NOT currently hooked, add the hook (correct under-inclusion in the
      same pass, so the resulting number is honest). *(completed: added to
      formats/return-metadata-file.md and patterns/anti-stop-patterns.md)*
- [x] Review the single `meta-builder-agent` entry in `nvim/index-entries.json` (976 tok) under
      the same rule and note whether it survives; if it is to be dropped, do so in Phase 4, which
      owns that file. *(completed: left for Phase 4's ownership, noted in progress file)*
- [x] Confirm no `load_when.skills` key was introduced anywhere. *(completed: schema test passes)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The research asserts 51 hooked entries of which only 5 are genuinely
referenced, and a post-rebase floor of ~11,432 tokens; plan-time measurement found 49 hooked
entries in the core file plus 1 in nvim. Re-derive both the hooked set and the reference set at
implementation time and reconcile against these figures before editing — do not assume 5
survivors. Remember the +1,864 ghost offset when comparing to the validator.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - remove `meta-builder-agent` from
  `load_when.agents` on unreferenced entries; add `on_demand: true` where all hooks empty; add
  missing hooks for genuine references

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- Regenerate and confirm `meta-builder-agent` reports under 15,000, accounting for the +1,864
  ghost.
- Dead Entry Check reports 0.

---

### Phase 3: Rebase planner, general-research, and general-implementation in core [COMPLETED]

**Goal**: Rebase the three remaining core-owned agents onto their real reference sets, bringing
`planner-agent` and `general-research-agent` under cap and reducing
`general-implementation-agent` to its true irreducible floor.

**Tasks**:
- [x] For each of `planner-agent`, `general-research-agent`, `general-implementation-agent`:
      extract the real `@`-reference set from its `.md` body and enumerate its currently hooked
      core entries with token costs. *(completed: 5/16, 8/14, 11/34 respectively -- the
      general-implementation-agent hooked count re-derived as 34, not the report's approximate
      33, per this phase's own re-enumeration instruction)*
- [x] Drop `agents[]` hooks for entries absent from that agent's reference set. High-confidence
      candidates verified at plan time: `patterns/task-lock.md` (9,336 tok, referenced only in
      prose, never with `@`-syntax) from `general-implementation-agent`; the four skill-lifecycle
      entries `patterns/skill-preflight-flow.md` (624), `patterns/skill-postflight-flow.md`
      (1,008), `patterns/skill-self-execution-fallback.md` (496), `patterns/lit-stage4a-flow.md`
      (1,864) — consumed by the orchestrating `SKILL.md` files, not the agent bodies — from all
      three agents; and `standards/postflight-tool-restrictions.md` (1,728) from
      `general-implementation-agent`. *(completed, plus one deliberate additional drop beyond the
      literal reference-set test: `patterns/checkpoint-before-overflow.md` was dropped from
      `general-research-agent` despite being genuinely `@`-referenced, per the plan/report's
      Finding 4 rare-path determination, numerically necessary to reach the 7,160-token floor)*
- [x] Evaluate `standards/status-markers.md` (3,304 tok, hooked to `planner-agent` and
      `general-implementation-agent`): its `commands` hook already covers `/plan` and
      `/implement`, which route to exactly those two agents. Drop the `agents[]` hook, keeping
      `commands[]`, which additionally reaches `/task`. *(completed, confirmed commands:[/task,
      /plan, /implement] preserved)*
- [x] Set `on_demand: true` on any entry left with all hooks empty. *(completed: 4 for
      planner-agent, 4 for general-research-agent, 7 for general-implementation-agent, some
      overlapping across agents on the same shared entry)*
- [x] Add hooks for any genuine unconditional reference currently missing. *(completed: none
      needed -- every agent's unconditional refs were already hooked)*
- [x] Record `general-implementation-agent`'s resulting measured total — it is expected to remain
      over 8,000 and is the input to Phase 8's exception. *(completed: 16,688 tok measured)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts specific entries are droppable at the token values
above (all verified against the current source file at plan time) and that `planner-agent` and
`general-research-agent` will clear their caps while `general-implementation-agent` will not.
Confirm each drop by re-grepping the owning agent's `.md` for that exact path before removing the
hook, and confirm the three outcomes by measurement in Phase 7 rather than by this assertion.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - same edit class as Phase 2, for the three
  remaining core agents

**Verification**:
- Schema test passes; Dead Entry Check reports 0.
- `planner-agent` under 15,000 and `general-research-agent` under 8,000 **after** Phase 6's
  memory-file edit is also in place (checked jointly in Phase 7).

---

### Phase 4: Rebase both Neovim agents in nvim/index-entries.json [COMPLETED]

**Goal**: Bring `neovim-research-agent` under its 8,000 cap and reduce
`neovim-implementation-agent` to its honest structural floor.

**Tasks**:
- [x] Extract real `@`-reference sets for `neovim-research-agent` and
      `neovim-implementation-agent` from their `.md` bodies. *(completed: 5 and 8 refs
      respectively, the latter matching the plan's explicit list exactly)*
- [x] `neovim-research-agent`: keep unconditional references hooked; move conditionally-loaded
      and unreferenced entries to `task_types`-only or `on_demand: true`. Target floor per
      research: ~7,360 (`return-metadata-file.md` 4,768 + `report-format.md` 704 +
      `neovim-api.md` 1,888), which requires the first two to be hooked from the core file — if
      they are not, coordinate the addition with Phase 3's owner of that file rather than
      duplicating entries here. *(completed: measured exactly 7,360; core-file additions made
      directly since one session executed all phases sequentially)*
- [x] `neovim-implementation-agent`: hook its genuine unconditional references, which
      plan-time grep confirms are `contracts/phase-closure.md`, `contracts/pre-edit-gate.md`,
      `formats/progress-file.md`, `formats/return-metadata-file.md`, `formats/summary-format.md`,
      `project/neovim/patterns/keymap-patterns.md`, `project/neovim/patterns/plugin-spec.md`,
      `project/neovim/standards/lua-style-guide.md`. Drop every hooked entry outside that set.
      *(completed: measured 15,336, exactly matching the report's prediction)*
- [x] Drop the `meta-builder-agent` hook on this file's single such entry if Phase 2 determined
      it is unreferenced. *(completed: dropped from project/neovim/domain/extension-deploy-modes.md,
      confirmed unreferenced, on_demand:true set)*
- [x] Note: `standards/git-staging-scope.md` (2,624 tok, core-owned) is hooked to
      `neovim-implementation-agent` but not `@`-referenced by it. Its removal belongs to the
      core file — record it for Phase 3's owner rather than editing core from this phase.
      *(completed: dropped directly from core/index-entries.json)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts 14 entries hooked to `neovim-research-agent` and 22 to
`neovim-implementation-agent` in this file (measured at plan time), and an 8-entry reference set
for the implementation agent. Re-enumerate both at implementation time; the reference-set grep is
authoritative over this list.

**Files to modify**:
- `agent-system/extensions/nvim/index-entries.json` - narrow `agents[]` hooks to real reference
  sets; `on_demand: true` where hooks become empty

**Verification**:
- Schema test passes; Dead Entry Check reports 0.
- `neovim-research-agent` under 8,000 after regeneration.
- `neovim-implementation-agent` reduced to a stable measured floor (expected ~15,336) for
  Phase 8's exception.

---

### Phase 5: Rebase both Nix agents in nix/index-entries.json [COMPLETED]

**Goal**: Bring `nix-research-agent` under its 8,000 cap with real margin and reduce
`nix-implementation-agent` to its honest structural floor.

**Tasks**:
- [x] Extract real `@`-reference sets for both agents. *(completed: 12 hooked entries each in
      the nix file, matching plan-time count exactly)*
- [x] `nix-research-agent`: keep only unconditional references hooked. The eight sub-task-gated
      files (`flakes.md`, `home-manager.md`, `derivation-patterns.md`, `module-patterns.md`,
      `overlay-patterns.md`, `nixos-modules.md`, `home-manager-guide.md`,
      `nixos-rebuild-guide.md`) are gated behind "Package tasks:" / "NixOS module tasks:" /
      "Flake tasks:" / "Build/deploy tasks:" headings and do not meet the Tier 2 "loaded whenever
      this agent is dispatched" bar — move them to `task_types`-only, preserving their existing
      `task_types` hook. *(completed)*
- [x] The research computes this agent at exactly 8,000 (at cap, no margin). Additionally move
      `project/nix/README.md` (808 tok) to `on_demand`/`task_types`-only for margin, so a future
      line-count drift does not silently re-break the check. *(completed: measured 7,192, margin
      808)*
- [x] `nix-implementation-agent`: hook its genuine unconditional references — the core bundle
      (`phase-closure.md`, `pre-edit-gate.md`, `progress-file.md`, `return-metadata-file.md`,
      `summary-format.md`) plus the unconditionally-listed `project/nix/README.md`,
      `project/nix/domain/nix-language.md`, `project/nix/standards/nix-style-guide.md`. Its
      remaining eleven nix references are sub-task-gated and stay `task_types`-only. *(completed:
      measured 14,104, exactly matching the report's prediction)*
- [x] Record for Phase 3: `standards/git-staging-scope.md` is hooked to
      `nix-implementation-agent` but not `@`-referenced by it; drop belongs in the core file.
      *(completed: dropped directly from core/index-entries.json)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts 12 entries hooked to each nix agent in this file, and that the
core-bundle references are currently unhooked for `nix-implementation-agent` (both measured at
plan time). Re-enumerate before editing; note that the nix agents' hooks are inert catalog
metadata with no live runtime consumer, so these edits correct the metric without changing
behavior — which is a reason for accuracy, not a licence for approximation.

**Files to modify**:
- `agent-system/extensions/nix/index-entries.json` - narrow `agents[]` hooks; preserve
  `task_types` hooks on conditional domain content

**Verification**:
- Schema test passes; Dead Entry Check reports 0.
- `nix-research-agent` under 8,000 with non-zero margin after regeneration.
- `nix-implementation-agent` reduced to a stable measured floor (expected ~14,104).

---

### Phase 6: Drop orphaned general-research hooks in memory/index-entries.json [NOT STARTED]

**Goal**: Remove the 2,832 tokens of memory-extension entries hooked to `general-research-agent`
that its `.md` body never references — without which that agent cannot clear its cap.

**Tasks**:
- [ ] Re-confirm the orphan status: `grep -n "distill-usage\|memory-reference"
      agent-system/extensions/core/agents/general-research-agent.md` must return no matches.
- [ ] Remove `general-research-agent` from `load_when.agents` on
      `project/memory/distill-usage.md` (2,376 tok) and
      `project/memory/domain/memory-reference.md` (456 tok).
- [ ] Leave both entries' `commands` hooks intact (`/distill`, and `/learn` on the second) —
      these are the real, correct reach and both commands are direct-execution, so the entries
      leave the Double-Loading Check's dual-hook population entirely rather than becoming
      redundant.
- [ ] Record the `file_scope` extension explicitly in the implementation summary: the declared
      scope named three `index-entries.json` files, and this is a fourth, justified by the
      measured fact that `general-research-agent` cannot reach its cap otherwise and that the
      edit is the identical orphan-hook correction applied in every other phase.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Asserts exactly two memory-extension entries are hooked to
`general-research-agent`, totalling 2,832 tokens. Confirm by set-differencing the agent's
deployed hooked-entry path list against the three in-scope source files, which is how these two
were found — a spot check of the two predicted paths would miss a third.

**Files to modify**:
- `agent-system/extensions/memory/index-entries.json` - remove the `general-research-agent`
  entry from `load_when.agents` on the two named entries

**Verification**:
- Schema test passes; Dead Entry Check reports 0 (both entries retain `commands` hooks, so
  neither becomes hook-empty and neither needs `on_demand`).
- Double-Loading Check still reports 0 redundant.

---

### Phase 7: Regenerate and measure all eight post-rebase totals [NOT STARTED]

**Goal**: Produce the authoritative measured token total for every one of the eight agents, which
is the sole input to Phase 8's exception values.

**Tasks**:
- [ ] Run the regeneration invocation established in Phase 1 so every source edit reaches
      `.claude/context/index.json`.
- [ ] Run `bash .claude/scripts/validate-context-budgets.sh --verbose` and capture the full
      per-agent table plus per-agent entry listings.
- [ ] For each of the five agents expected to pass (`meta-builder-agent`, `planner-agent`,
      `general-research-agent`, `neovim-research-agent`, `nix-research-agent`), confirm it is
      under cap and record its margin. Any agent at zero or negative margin gets a further
      conditional-content reclassification pass before proceeding.
- [ ] For each of the three expected survivors (`general-implementation-agent`,
      `neovim-implementation-agent`, `nix-implementation-agent`), record the exact measured total
      and the exact entry-by-entry composition from the `--verbose` listing. These compositions
      become the exception justification text.
- [ ] Reconcile each measured total against the hand-summed source entries plus the Phase 1 ghost
      offset. An unexplained discrepancy is a stop condition, not a rounding artifact.
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --check` to confirm no
      `line_count` drift was introduced (no content files were edited, so this must be clean).

**Timing**: 0.5 hours

**Depends on**: 3, 4, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: Asserts exactly three agents will remain over cap. If four or more remain,
do not proceed to Phase 8 with an extra exception — return to the relevant rebase phase, because
a fourth survivor indicates an incomplete rebase rather than a genuine structural floor. If fewer
than three remain, reduce the exception count accordingly.

**Files to modify**:
- None (measurement only; the regenerated `.claude/context/index.json` is a disposable deploy
  artifact, not a source edit)

**Verification**:
- Every measured total is reconciled against source sums plus the ghost offset.
- Violations count has strictly decreased from 8 and the five expected-pass agents show positive
  margin.

---

### Phase 8: Rewrite the EXCEPTIONS block with measured floors [NOT STARTED]

**Goal**: Replace the stale, inert single exception with three accurate per-agent exceptions
whose caps are the Phase 7 measured totals and whose justifications state real current
composition.

**Tasks**:
- [ ] Replace the `EXCEPTIONS` associative array. The current entry is stale on three independent
      counts: it names `patterns/checkpoint-execution.md`, which
      `general-implementation-agent.md` no longer references; its declared cap of 8,048 is far
      below the measured total, making the exception inert (the `elif` branch requires
      `total_tokens <= exception_cap`); and its token figures use an outdated line-count ratio.
- [ ] Write one entry per surviving agent, with `exception_cap` set to the Phase 7 measured total
      (with a small deliberate headroom allowance stated in the justification, so ordinary drift
      does not immediately re-break the gate) and a justification naming the actual irreducible
      composition — the 9,248-token shared core bundle plus that agent's specific unconditional
      domain content.
- [ ] Generalize the hardcoded summary narration block, which currently prints
      `general-implementation-agent`'s stale composition as literal text regardless of the
      `EXCEPTIONS` contents. Replace it with a loop over `EXCEPTIONS` so the two can never drift
      apart again — this same drift is what made the existing exception misleading.
- [ ] Add a maintenance note in the script stating that these caps are computed from current file
      sizes and must be recomputed whenever the core bundle's files change, and that the
      structural cause is core-doc size rather than hook authorship.
- [ ] Confirm no task-number references appear anywhere in the added text. This file is a
      deliverable outside `specs/**`; cite file names and token composition as the durable
      anchors.

**Timing**: 0.75 hours

**Depends on**: 7

**Verification Tier**: interface

**Scope Hypothesis**: Asserts three exception entries are needed and that the summary narration
block is the only other site hardcoding exception text. Confirm the latter by grepping the script
for the stale literals (`checkpoint-execution`, `8,048`, `4,016`) before declaring the phase
complete — a residual literal elsewhere would keep the output misleading even with a correct
array.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` - replace `EXCEPTIONS`
  array; generalize the summary narration to loop over it; add the recomputation maintenance note

**Verification**:
- `bash -n` on the script passes.
- After regeneration, the validator reports `Violations: 0`, exits 0, and prints exactly three
  `OK*` rows whose narrated composition matches the `EXCEPTIONS` array contents.
- No stale literal remains.

---

### Phase 9: Final verification sweep [NOT STARTED]

**Goal**: Confirm the whole change set is green across every gate the repository already runs,
and that no adjacent invariant was broken in passing.

**Tasks**:
- [ ] `bash .claude/scripts/validate-context-budgets.sh` -> `Violations: 0`, exit 0, three `OK*`
      rows.
- [ ] Schema and index gates: `test-index-entries-schema.sh`, `validate-context-index.sh`,
      `validate-index.sh` all pass for all four edited source files.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift.
- [ ] Tier 1 Check, Tier Classification Check, Dead Entry Check, and Double-Loading Check each
      report clean, as they did at baseline — this change must not trade a budget violation for a
      different check's violation.
- [ ] `bash .claude/scripts/check-task-references.sh` passes (no task-number citations introduced
      into the four deliverable files).
- [ ] `bash .claude/scripts/check-extension-docs.sh` passes.
- [ ] Confirm the five passing agents each retain a positive margin and record the margins, so a
      future maintainer can see how much headroom exists.
- [ ] Record in the summary the deferred follow-ups this task deliberately did not do: the
      content-duplication candidates (`patterns/metadata-file-return.md`,
      `patterns/early-metadata-pattern.md`), shrinking `return-metadata-file.md` as the structural
      unblocker for the three exception agents, the reverse-direction Double-Loading Check gap,
      and the additive-merge ghost-entry defect with its two stranded deployed files.

**Timing**: 0.5 hours

**Depends on**: 8

**Verification Tier**: full

**Scope Hypothesis**: Asserts a final state of three exception rows and five under-cap agents,
totalling the same eight agents that were over cap at baseline. Confirm against the validator's
own output rather than against this plan's expectations; if the arithmetic does not close over
all eight, the discrepancy is the finding and the sweep does not pass.

**Files to modify**:
- None (verification only)

**Verification**:
- Every gate above exits 0.

## Testing & Validation

- [ ] `bash .claude/scripts/validate-context-budgets.sh` exits 0 with `Violations: 0`.
- [ ] Exactly three documented exceptions appear as `OK*` rows, each with a justification naming
      current file composition and no stale file names.
- [ ] No `CAPS` value differs from its baseline value.
- [ ] All four edited `index-entries.json` files validate against `index.schema.json`; no
      `load_when.skills` key exists anywhere.
- [ ] Dead Entry Check, Tier 1 Check, Tier Classification Check, and Double-Loading Check are each
      no worse than baseline.
- [ ] `check-task-references.sh` and `check-extension-docs.sh` pass.
- [ ] No context content file was modified (`git diff --stat` shows changes confined to the four
      files named in Artifacts & Outputs).

## Artifacts & Outputs

- `agent-system/extensions/core/index-entries.json` - rebased `agents[]` hooks for
  `meta-builder-agent`, `planner-agent`, `general-research-agent`,
  `general-implementation-agent`; `on_demand: true` added where hooks became empty
- `agent-system/extensions/nvim/index-entries.json` - rebased hooks for both Neovim agents
- `agent-system/extensions/nix/index-entries.json` - rebased hooks for both Nix agents
- `agent-system/extensions/memory/index-entries.json` - two orphaned `general-research-agent`
  hooks removed (justified `file_scope` extension)
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` - three accurate per-agent
  exceptions replacing the stale inert one; generalized summary narration; maintenance note
- `specs/999_per_agent_context_budget_reduction/summaries/01_rebase-agent-context-hooks-summary.md`

## Rollback/Contingency

All edits are confined to five source files under `agent-system/extensions/`, all git-tracked, and
no content files are touched. Reverting is `git checkout` of those five paths followed by a
regeneration of `.claude/context/index.json`, which is a disposable deploy artifact rebuilt from
source.

Partial-completion contingency: the phases are ordered so that any prefix ending at Phase 7 leaves
the repository in a strictly-improved, self-consistent state — fewer violations than baseline, with
the validator still failing loudly on the remainder rather than silently passing. The one ordering
that must not be broken is writing exceptions (Phase 8) before measuring (Phase 7); an exception
whose cap is below the measured total is inert and reproduces exactly the defect this task exists
to fix.

If Phase 7 shows an agent still over cap that was expected to pass, the correct response is a
further conditional-content reclassification pass in that agent's owning phase — never an added
exception and never a cap increase.
