# Implementation Plan: Task #1002

- **Task**: 1002 - Author the context tier-semantics standard for the derived tier classification
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 991, Task 998 (both already resolved into the current codebase state; no open blocking work)
- **Research Inputs**: specs/1002_context_tier_semantics_doc/reports/01_context-tier-semantics.md
- **Artifacts**: plans/01_context-tier-semantics.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author one new core-context standards file, `context/standards/context-tier-semantics.md`, that
documents the tier-classification semantics currently implemented — and documented *only* — inside
`validate-context-budgets.sh`'s `DERIVED_TIER` jq function. Register the new file with a single
additive entry in the core extension's source `index-entries.json`, and point the `DERIVED_TIER`
header comment back at the new doc so the two cannot drift silently. This is a documentation-only
task: the derivation logic itself is treated as correct and frozen. Definition of done is the
verification bar from the task description — the file exists, its index entry is schema-conformant
with an exact `line_count`, `check-extension-docs.sh` passes Rules R and T, and
`validate-context-budgets.sh` shows no new budget violation, zero dead entries, and a tier
distribution changed by exactly one added Tier-4 entry.

### Research Integration

The research report supplies everything needed and should be consumed directly rather than
re-derived:
- **Verified derivation rule** (read from source, not inferred): Tier 1 = `load_when.always ==
  true`; Tier 2 = non-empty `agents`; Tier 3 = non-empty `commands` or `task_types`; Tier 4 =
  every hook empty. First-match-wins, total, exhaustive — Tier 1 dominates even when `agents[]`
  is also non-empty.
- **Authoritative rationale already exists** in `context/index.schema.json`'s entry `$comment` and
  its `on_demand` property description: `tier` was removed (and made schema-illegal via
  `additionalProperties: false`) because no entry ever populated it accurately; `on_demand` exists
  precisely *because* Tier 4's fallthrough-on-emptiness would otherwise make the Dead Entry Check
  a tautology. The doc surfaces this, it does not reinvent it.
- **The most likely future-author error**, and therefore the doc's most actionable content: an
  author may believe `on_demand: true` *changes* an entry's tier. It does not. A Tier-4-classified
  entry with `on_demand: true` is still Tier 4; it is simply no longer flagged dead. Tier 4 is a
  classification outcome; `on_demand` is an intent marker that keeps the *check* meaningful.
- **Style precedent**: `context/standards/status-markers.md` plays the identical "human-readable
  gloss over a machine-readable source of truth" role and states that relationship explicitly.
  The new file opens with the equivalent framing — the `DERIVED_TIER` function wins on
  disagreement.
- **Index entry shape decided**: all three `load_when` arrays empty plus `on_demand: true`. Every
  existing on-demand entry in the index uses exactly this uniform shape, and a live run of
  `validate-context-budgets.sh` confirmed all 10 tracked agents are *already* over their caps, so
  any non-empty hook would strictly worsen an already-red number for no benefit.
- **Distribution counts are a moving target**: the live run reported `Tier 1: 3, Tier 2: 147,
  Tier 3: 33, Tier 4: 6` across 189 entries, versus the task description's older snapshot of
  `3 / 144 / 34 / 6` across 187. Expected deploy drift, not a discrepancy. The doc must document
  the *rule*, never freeze a point-in-time count as a live invariant.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md consultation was
requested. No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make the tier-derivation rule discoverable outside the one script that implements it.
- Document the `on_demand` marker's purpose and give a future entry author a concrete,
  unambiguous decision rule for when to set it.
- Register the new file in the core source index with a `line_count` that exactly matches the
  written file (Rule R is a hard gate).
- Establish a bidirectional pointer between the doc and `DERIVED_TIER`'s header comment.

**Non-Goals**:
- Changing `DERIVED_TIER`'s logic, the Dead Entry Check predicate, or any tier-consuming site.
- Fixing the standing all-agents-over-budget defect (a separate task owns that).
- Editing `context/index.schema.json` — its `$comment` already carries the rationale and is the
  upstream authority this doc glosses.
- Editing `manifest.json` — verified unnecessary: `provides.context` declares `standards` as a
  whole directory, so a new file inside it needs no new manifest declaration.
- Deploying to `.claude/**`. All edits land in `agent-system/extensions/core/**` per the binding
  source-store rule.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `line_count` mismatch fails Rule R | H | M | Compute `wc -l` on the final written file immediately before writing the entry; never estimate. Re-run `wc -l` if the file is touched again after the entry is written. |
| Forgetting `on_demand: true` turns the new entry into a Dead Entry Check violation | H | M | Phase 2 writes the marker as part of the same edit; Phase 4 explicitly asserts `Dead entries: 0`. |
| Concurrent edit collision on `index-entries.json` with the task sequenced after this one in the same batch | M | M | Append exactly one entry at the end of the `entries` array. No reordering, no reformatting, no whitespace churn, no touching any existing entry. Keep the diff to one added object. |
| Doc drifts from the script if `DERIVED_TIER` changes later | M | L | The doc declares the script the single source of truth, and the script's header comment names the doc — mutually discoverable from either side. |
| Doc hardcodes a point-in-time tier distribution that immediately goes stale | L | M | If a distribution is shown at all, label it explicitly as an illustrative example with no invariant status. Preferably omit exact counts. |
| Task-number citation leaks into the deliverable | M | L | The new `.md`, the index entry, and the script comment are all outside `specs/**`. No task numbers, no "task N" phrasing. A blocking PreToolUse hook also guards this. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`index-entries.json` vs `validate-context-budgets.sh`) and may be executed in either order or
concurrently; both require Phase 1's file to exist first.

---

### Phase 1: Author context/standards/context-tier-semantics.md [COMPLETED]

**Goal**: Write the new standards file, complete and final, so its line count is stable before
Phase 2 records it.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/standards/context-tier-semantics.md`. *(completed)*
- [x] Open with a single-source-of-truth statement: the `derived_tier` jq function in
      `scripts/validate-context-budgets.sh` is authoritative; this document explains and motivates
      it; if the two disagree, the script wins. Mirror `status-markers.md`'s framing. *(completed)*
- [x] Write the four-tier rule table in first-match-wins order. Per tier give (a) the exact
      `load_when` predicate and (b) its operational meaning — when in an agent's session the entry
      actually loads. *(completed)*
- [x] State the precedence explicitly: an entry with `always: true` AND a non-empty `agents[]`
      lands in Tier 1, not Tier 2. Note that no entry does this today but the ordering is part of
      the semantics. *(completed)*
- [x] Explain why the authored `tier` field was abandoned, paraphrasing `index.schema.json`'s entry
      `$comment` and naming its `additionalProperties: false` enforcement (an authored `tier` key
      is schema-illegal, not merely discouraged). *(completed)*
- [x] Document the `on_demand` marker: what it is for, why it exists as a direct consequence of
      Tier 4's fallthrough-on-emptiness design, and the decision rule — *set `on_demand: true` if
      and only if all `load_when` arrays are empty by deliberate design, i.e. the file is meant to
      be reachable only via grep or explicit Read. Leaving it unset on an all-empty entry is a Dead
      Entry Check violation, not a lesser tier.* *(completed)*
- [x] State the Tier-4-vs-Dead-Entry-Check distinction precisely: Tier 4 is a classification
      outcome; `on_demand` is an intent marker. Setting `on_demand: true` does not change an
      entry's tier — it only stops the entry being flagged dead. Note that the Dead Entry Check's
      predicate is independent of the derived tier value. *(completed)*
- [x] Add a short worked example: this file's own index entry (all hooks empty, `on_demand: true`,
      therefore Tier 4) as a self-referential illustration of why an entry lands in Tier 4. *(completed)*
- [x] Cross-reference `context/patterns/context-discovery.md`'s "Hook-Shape Policy" section as the
      companion doc, framing the split: this doc answers "what tier does this shape produce and what
      does `on_demand` mean"; that one answers "which shape should I author for a given loading
      intent". *(completed)*
- [x] Note that `validate-context-budgets.sh`'s `DERIVED_TIER` header comment points back at this
      file (the bidirectional half completed in Phase 3). *(completed)*
- [x] If any tier-distribution numbers are included, label them explicitly as an illustrative
      snapshot with no invariant status. Preferably omit counts entirely. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The finished file is expected to land in the 150-220 line range, calibrated
against comparable narrow-topic standards docs (`postflight-tool-restrictions.md` at 216 lines,
`orchestrator-runtime-files.md` at 272). This is a hypothesis about size, not a target to pad or
trim toward — confirm the actual value with `wc -l` at the end of this phase and carry that exact
number into Phase 2. A result outside the range is not a defect; a `line_count` that does not match
`wc -l` is.

**Files to modify**:
- `agent-system/extensions/core/context/standards/context-tier-semantics.md` - new file, the
  entire deliverable of this phase.

**Verification**:
- File exists at the source-store path (not under `.claude/**`) and is non-empty.
- Read the rule table back against `DERIVED_TIER` in
  `agent-system/extensions/core/scripts/validate-context-budgets.sh` and confirm all four cases and
  their order match the jq function exactly.
- Confirm zero task-number citations anywhere in the file (this is a deliverable outside
  `specs/**`).
- Record `wc -l agent-system/extensions/core/context/standards/context-tier-semantics.md` for
  Phase 2.

---

### Phase 2: Add the index entry to core index-entries.json [COMPLETED]

**Goal**: Register the new file with one minimal, additive, schema-conformant entry carrying an
exact `line_count`.

**Tasks**:
- [x] Re-run `wc -l` on the Phase 1 file to get the authoritative count (do not reuse a stale
      number if the file was touched after Phase 1 closed). *(completed: 142)*
- [x] Append exactly one entry to the end of the `entries` array in
      `agent-system/extensions/core/index-entries.json`:
      `path: "standards/context-tier-semantics.md"`, `domain: "core"`,
      `subdomain: "standards"`,
      `summary: "Derived tier classification (1-4) for context index entries: rule, rationale, on_demand marker"`,
      `line_count: <exact wc -l>`,
      `keywords: ["tier", "derived_tier", "on_demand", "index.json", "load_when", "context-budget"]`,
      `topics: ["context-architecture"]`,
      `load_when: { "agents": [], "commands": [], "task_types": [] }`,
      `on_demand: true`. *(completed)*
- [x] Confirm `on_demand: true` is present. Its absence on an all-empty-hooks entry is exactly the
      Dead Entry Check violation this shape exists to avoid. *(completed)*
- [x] Confirm no forbidden keys (`description`, `tags`) and no `load_when` keys beyond
      `agents`/`commands`/`task_types`/`always` (Rule T). *(completed)*
- [x] Confirm the diff is strictly one added object — no reordering, reformatting, key reordering,
      or whitespace change to any existing entry. *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The `entries` array currently holds 133 objects, so the post-edit count should
be 134. Confirm with `jq '.entries | length'` before and after rather than trusting this number —
another task in the same batch also modifies this file and may land first, in which case the
baseline shifts and only the `+1` delta is meaningful.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one appended entry object.

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` exits 0 (valid JSON).
- `jq '.entries | length'` is exactly one greater than the pre-edit value.
- `jq '.entries[] | select(.path == "standards/context-tier-semantics.md")'` returns the entry with
  `on_demand: true` and all three `load_when` arrays empty.
- The declared `line_count` equals `wc -l` of the Phase 1 file.
- `git diff --stat` on this file shows only additions.

---

### Phase 3: Point the DERIVED_TIER header comment at the new doc [COMPLETED]

**Goal**: Close the drift loop by naming the new file from the script that owns the rule.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/validate-context-budgets.sh`, locate the
      `# --- Tier derivation ---` comment block immediately preceding the `DERIVED_TIER='` shell
      assignment (reference it by that anchor, not by line number). *(completed)*
- [x] Append a one-line pointer inside that existing comment block naming
      `context/standards/context-tier-semantics.md` and stating the division of labor: this comment
      states the rule, that file explains it and carries the `on_demand` decision rule. *(completed)*
- [x] Make no other change to the script — no logic, no predicate, no formatting elsewhere. *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` - comment-only addition inside
  the existing tier-derivation comment block.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-context-budgets.sh` exits 0.
- `git diff` on this file shows only added lines, all of them beginning with `#` and all inside the
  tier-derivation comment block.
- The `DERIVED_TIER='...'` jq body is byte-identical to its pre-edit form.

---

### Phase 4: Verification sweep against the task's verification bar [COMPLETED WITH EXCLUSIONS]

**Goal**: Demonstrate, with command output, that every condition in the task's stated verification
bar holds.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm it passes
      — specifically Rule R (source `line_count` accuracy; it reads `EXT_DIR` defaulting to
      `agent-system/extensions`, so it sees this source-store change directly) and Rule T (entry
      schema conformance). *(completed: zero Rule R and zero Rule T findings anywhere in the run;
      note under Deviations below regarding the run's overall non-zero exit)*
- [x] Run `bash .claude/scripts/validate-context-budgets.sh` against the deployed index to capture
      the unchanged baseline, and confirm no new budget violation is introduced. Note explicitly in
      the summary that the deployed `.claude/context/index.json` does not yet contain the new entry
      — it is regenerated at deploy time — so this run establishes the no-regression baseline, not
      the post-entry state. *(completed: 189 entries, Tier 1: 3, Tier 2: 147, Tier 3: 33, Tier 4: 6,
      Dead entries: 0, 8 pre-existing agent-budget violations unrelated to this task)*
- [x] Build a temporary merged index (deployed index plus the new entry) in the scratch directory
      and run `bash .claude/scripts/validate-context-budgets.sh --index <tmp>` against it. Confirm:
      `Dead entries: 0`; the tier distribution differs from baseline by exactly `+1` in Tier 4 and
      is unchanged in Tiers 1-3; and every per-agent token total is byte-identical to baseline
      (guaranteed structurally, since the entry carries no `agents`/`commands`/`task_types` hook —
      confirm rather than assume). *(completed: 190 entries, Tier 4: 7 (+1), Tiers 1-3 unchanged,
      Dead entries: 0, per-agent lines byte-identical to baseline via diff)*
- [x] Confirm no task-number citations were introduced in any of the three edited files (all are
      outside `specs/**`). *(completed: grep found none)*
- [x] Confirm no file under `.claude/**` was written by this task. *(completed: git show --stat on
      both phase commits shows only agent-system/extensions/core/** and specs/1002_.../** paths)*

**Timing**: 30 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None. This phase is verification only; any fix it surfaces belongs in the phase that owns the
  file.

**Verification**:
- `check-extension-docs.sh` exits 0 with no Rule R or Rule T finding naming
  `standards/context-tier-semantics.md`.
- The `--index <tmp>` budget run reports `Dead entries (all hooks empty, not marked on_demand): 0
  -- OK` and a Tier 4 count exactly one higher than baseline.
- Per-agent budget lines are identical between the baseline and merged-index runs.
- `git status --short` shows exactly three modified/added paths, all under
  `agent-system/extensions/core/`.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `check-extension-docs.sh` exits 0 overall | The run's sole finding is `FAIL: deployed script content drift (deployed != extension source): scripts/validate-context-budgets.sh` — a distinct check (drift between `.claude/scripts/` and the source store), not Rule R or Rule T. It exists solely because Phase 3 edited the source-store script without redeploying to `.claude/**`, which the plan's Non-Goals and Implementer Constraints explicitly forbid ("Deploying to `.claude/**`... All edits land in `agent-system/extensions/core/**`"). Deploying to clear this finding would itself violate the binding source-store rule, so the finding cannot be cleared within this task's scope. | `bash .claude/scripts/check-extension-docs.sh` output: `[core] FAIL: deployed script content drift (deployed != extension source): scripts/validate-context-budgets.sh`, immediately followed by zero occurrences of the strings `Rule R` or `Rule T` anywhere in the full run output (`grep -n "Rule R\|Rule T"` on the captured output returns no matches). |
| `git status --short` shows exactly three modified/added paths | Concurrent batch tasks (995, 1001, and others visible in the same working tree) are modifying unrelated files in parallel, and this task's own three edited source-store files were already committed per-phase rather than left pending, so neither the literal working-tree diff nor a same-instant snapshot isolates this task's change set. | `git show --stat` on this task's two phase commits (`4fcb00d6d` phase 1, `6448aae0b` phases 2-3) shows exactly three deliverable paths under `agent-system/extensions/core/`: `context/standards/context-tier-semantics.md`, `index-entries.json`, `scripts/validate-context-budgets.sh` — matching the plan's Artifacts & Outputs list exactly, with all other changed paths in each commit confined to `specs/1002_context_tier_semantics_doc/**`. |

---

## Testing & Validation

- [x] `agent-system/extensions/core/context/standards/context-tier-semantics.md` exists, is
      non-empty, and its rule table matches `DERIVED_TIER` case-for-case and in order. *(completed)*
- [x] `jq empty agent-system/extensions/core/index-entries.json` exits 0. *(completed)*
- [x] The new entry's `line_count` equals `wc -l` of the new file exactly. *(completed: 142)*
- [x] The new entry has `on_demand: true` with all three `load_when` arrays empty. *(completed)*
- [x] `bash -n agent-system/extensions/core/scripts/validate-context-budgets.sh` exits 0. *(completed)*
- [x] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes Rules R and T.
      *(completed: zero Rule R/T findings; see Phase 4's Reasoned Exclusions for the unrelated
      deploy-drift finding on the overall exit code)*
- [x] Merged-index budget run: `Dead entries: 0`, Tier 4 `+1`, Tiers 1-3 unchanged, per-agent
      totals unchanged. *(completed)*
- [x] No task-number references in any file outside `specs/**`. *(completed)*
- [x] No writes under `.claude/**`. *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/context-tier-semantics.md` (new)
- `agent-system/extensions/core/index-entries.json` (one appended entry)
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` (comment-only pointer)
- `specs/1002_context_tier_semantics_doc/summaries/01_context-tier-semantics-summary.md`

## Rollback/Contingency

All three edits are independently and trivially revertible, and none changes executable behavior:
- Delete the new markdown file.
- Revert the single appended object in `index-entries.json` (`git checkout` the file if no other
  task's entry has landed in the same edit window; otherwise remove just the one object by hand to
  avoid clobbering a concurrent additive edit).
- Revert the comment-only hunk in `validate-context-budgets.sh`.

Nothing is deployed to `.claude/**`, so no regeneration or redeploy is needed to roll back, and no
runtime path can be affected. If Phase 2 or 3 fails verification, Phase 1's file may be left in
place harmlessly — an unindexed source file is inert until deploy — but the index entry and the
file must land together in the same commit, since an entry pointing at a missing file is a Rule R
failure.

## Implementer Constraints (binding)

- **Source-store rule**: edit `agent-system/extensions/core/**` only. Never write `.claude/**`.
- **Deliverable rule**: no task numbers or "task N" phrasing in any of the three edited files —
  all are outside `specs/**`. Cite durable anchors (file names, function names, section headings)
  instead.
- **Concurrency**: another task in this same batch also edits
  `agent-system/extensions/core/index-entries.json` and is sequenced after this one. Keep the
  change strictly minimal and additive: one appended object, zero touches to existing entries,
  zero reformatting.
- **Do not modify the derivation logic.** `DERIVED_TIER` and the Dead Entry Check predicate are
  frozen for this task's scope.
