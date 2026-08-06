# Implementation Plan: Wire Non-Conformance Detection into the Hard-Mode Resume-Scan Sites

- **Task**: 960 - Wire non-conformance detection into the hard-mode resume-scan sites
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: Tasks 959 and 957 (both landed; verified live in the source store by research)
- **Research Inputs**: `specs/960_wire_nonconformance_detection_into_resume_scan_sites/reports/01_wire-nonconformance-detection.md`
- **Artifacts**: plans/01_nonconformance-resume-scan-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Both hard-mode resume-scan sites select the next phase with
`grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1`. Because
`PHASE_HEADING_ERE` admits conforming headings only, a non-conforming heading is not merely
unmatched — it is **invisible** to the scan, so the existing `warn_nonconforming` calls (guarded
by `next_heading` non-empty AND `extract_phase_number` failing) sit in a provably unreachable
branch. This plan inserts a whole-file conformance gate that runs **before** the filtered scan at
every affected site, funnels every inconclusive outcome into one named sentinel
(`phase_scan_inconclusive`), and gives each site a first-class inconclusive branch matched to its
own posture. It also adds the first executable regression harness for these markdown-embedded
scan blocks, exercising the `4C`/`5` verification bar directly.

This is explicitly **not** a grammar-widening task. `PHASE_HEADING_ERE` is not touched. The
deliberate, re-affirmed decision recorded in `context/formats/plan-format.md`'s "Canonical
phase-heading shape" subsection — that letter-suffixed sub-phases are unsupported and the correct
general fix is loud non-conformance detection — is the premise of this plan, not a constraint it
works around.

### Research Integration

Findings carried directly into the phase structure:

- The library needs **no** behavioral change: `has_nonconforming_phase_headings <file>` (boolean,
  non-racy under `pipefail`) and `warn_nonconforming <file> <label>` (loud, per-heading,
  line-numbered) already exist and already satisfy the verification bar's "named warning
  identifying the `4C` heading by line number" requirement. Phase 1 adds only a usage contract in
  prose.
- `update-task-status.sh`'s D3 gate is the strongest in-repo exemplar of the correct
  "whole-file check first, INCONCLUSIVE branch second" shape. Its structure is the model copied
  by Phases 2-4.
- `skill-orchestrate-hard`'s current posture ("warn and leave `next_phase` empty") is **not safe
  as implemented**: an empty `next_phase` falls through into either the skeleton-exhaustion branch
  (asserting `pr_ready`) or the "all phases genuinely complete" branch. Both claims are false when
  the real cause is a malformed plan. Phase 3 therefore adds a distinct *first* branch, not a
  reordering of the existing two.
- `skill-implementer-hard` has a second, arguably worse fallthrough: `else next_phase=1`, which
  would **re-dispatch phase 1** when the only open phase in the whole file is non-conforming. The
  gate in Phase 2 must sit *above* the whole cascade, not merely above the dead `exit 1`.
- Two audit hits outside the declared `file_scope` (Site C: the lean extension's structural clone;
  Site D: `update-task-status.sh`'s `first_phase_heading`) are decided explicitly in Phase 4.
- No existing test exercises these blocks, because they live inside markdown pseudo-bash fences.
  Phase 5 closes that gap.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (`roadmap_path` not supplied; `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Make non-conformance detection **reachable** at both declared resume-scan sites by running a
  whole-file check before any filtered scan.
- Give each site a first-class inconclusive branch that cannot fall through into a branch
  asserting a different, false claim (skeleton-exhaustion, full completion, or "dispatch phase 1").
- Preserve the two sites' deliberately different postures, and record the reasoning in-code and
  in `plan-format.md`.
- Make an explicit, recorded in-scope/out-of-scope decision for both audit-discovered sites.
- Add an executable regression harness that exercises the `4C` verification bar, not just
  `bash -n`.

**Non-Goals**:
- Widening `PHASE_HEADING_ERE` or any other pattern in `phase-heading-patterns.sh`. Forbidden.
- Changing any library function's behavior, signature, or return convention.
- Changing happy-path resume behavior on a fully conforming plan. Byte-for-byte equivalent
  selection is a hard requirement, asserted by the harness.
- Auto-repairing non-conforming headings. Detection stops the scan; it never rewrites the plan.
- Touching `.claude/**`. Every edit targets `agent-system/extensions/**`.

## Scope Decisions (made explicitly, per the task's requirement)

### Decision 1 — Site C, `skill-lean-implementation-hard`: **IN SCOPE**

`agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` Stage 3 is a
structural clone of the implementer-hard site, carrying the identical unreachable
`warn_nonconforming` branch. Brought in scope for three reasons:

1. `plan-format.md`'s consumer list **already names it** as bound by the same contract the same
   document calls "a closed contract, not an aspiration." Fixing the two declared sites while
   leaving this one broken would make that claim false at the moment this task lands — a
   documentation regression created by the fix itself.
2. The fix is the same ~12-line gate, the same library, no new predicate, no new test
   infrastructure. The marginal cost is a few minutes; a separate task costs a full
   research/plan/implement lifecycle.
3. `file_scope` is defined by `state-management.md` as **descriptive/anticipated, not
   filesystem-validated, and never mutated by status-sync** — it is a lock-overlap hint, not a
   permission boundary. Extending it for a directly audit-discovered instance of the exact defect
   is within its intended semantics.

It is isolated in its own phase (Phase 4) so it can be dropped cleanly without disturbing
Phases 2-3 if the implementer finds an unanticipated blocker in the lean extension.

### Decision 2 — Site D, `update-task-status.sh`'s `first_phase_heading`: **IN SCOPE (minimal guard only)**

`first_phase_heading=$(grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT STARTED\]" ...)` in the
plan-initialization convenience path has the same filter-before-check shape. It is self-documented
as "a redundant convenience... Non-fatal." Brought in scope as a **minimal guard**, not a full
restructure, because:

- Unlike Sites A/B/C it does not select a dispatch target, but it *does perform a state mutation*:
  if phase 1's heading is non-conforming, it silently marks a **different** phase `IN_PROGRESS`.
  That is a wrong-phase write, not merely a missed convenience.
- The cost is three lines. The library is already sourced at file scope in this script (it backs
  the D3 gate), so `has_nonconforming_phase_headings` is available with no new plumbing.
- The guard is strictly subtractive: on a hit it **warns and skips** the convenience entirely. It
  never guesses. Skipping is harmless by the path's own documented rationale — the dispatched
  agent owns every per-phase transition directly.

Deliberately **not** done here: promoting this path to fatal, or restructuring it. Its non-fatal
character is preserved exactly.

### Decision 3 — Posture asymmetry between Sites A and B: **KEEP DIFFERENT, and make A's real**

| Site | Role | Posture | Why |
|------|------|---------|-----|
| `skill-implementer-hard` (B) | Single-shot leaf worker | Hard stop, `exit 1` | The check runs in the skill's own bash preamble, strictly before the first `Agent tool:` dispatch. No subagent has run, so no handoff write is owed (H9 wrap-up binds a *dispatched* agent's termination, not a dispatching skill's precondition check). The caller — a human, or `skill-orchestrate-hard`'s `Agent tool` call — is already equipped to observe a failed dispatch. |
| `skill-lean-implementation-hard` (C) | Single-shot leaf worker | `return error ...` | Same role as B; adopts B's shape via the file's own existing `return error` convention rather than a raw `exit`. |
| `skill-orchestrate-hard` (A) | The long-running orchestration loop itself | New first branch → `EXIT (partial, ...)` | A raw `exit 1` from this skill's preamble is a nonlocal jump out of the entire `/orchestrate --hard` execution, with no `EXIT (...)` bookkeeping and no message shaped like the six other terminal paths in the same file. That would be worse than the bug. The file has an established terminal-condition vocabulary; the fix uses it. |
| `update-task-status.sh` (D) | Non-fatal convenience | Warn and skip | Preserves the path's documented non-fatal contract. |

The asymmetry is **leaf worker vs. orchestration loop**, not an accident. It is recorded in-code
at each site and in `plan-format.md` (Phase 6).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Site A fixed by moving the check earlier but leaving the `if/elif/else` cascade intact — a warning is printed on the way to the same wrong conclusion | H | M | Phase 3's acceptance criterion is structural: the inconclusive branch must be the **first** branch of the cascade and must terminate via `EXIT (partial, ...)`. Phase 5 asserts this by grep, checking branch **order**, not mere presence. |
| Site B's `else next_phase=1` re-dispatches phase 1 on a plan whose only open phase is non-conforming | H | M | Phase 2 places the guard **above** the entire cascade, not above the dead `exit 1`. Phase 5 asserts the guard precedes the first `elif` of the cascade. |
| Happy-path regression: a conforming plan resolves a different phase than before | H | L | Phase 5 asserts a conforming fixture resolves the identical `next_phase` at all three sites, plus `phase_scan_inconclusive=false` and empty stderr. This is a required, not optional, assertion. |
| The scan blocks live in markdown pseudo-bash fences that also contain non-bash pseudo-syntax (`Agent tool:`, `EXIT (partial)`), so the enclosing fence is **not** `bash -n` clean and never was | M | H (certain) | The gate region is delimited by explicit sentinel comments and is pure, executable bash. `bash -n` and execution both target the extracted region, never the whole fence. Posture branches containing pseudo-syntax are verified structurally instead. This limit is stated, not papered over. |
| `nonconforming_phase_headings \| grep -q .` used instead of the boolean predicate (racy under `pipefail`) | M | L | The canonical snippet in Phase 1 is copied verbatim by every site; Phase 5 greps for the forbidden pipe form and fails on any occurrence. |
| Implementer's `Edit` blocked by the `validate-no-task-references.sh` PreToolUse gate | M | L | Verified: `TASK_PATTERN` requires the literal word `task`/`tasks`. The `772 Item 5A` fence comments wrapping Site A do **not** match and will not block. New comments added by any phase must still avoid `task N` citations — the plan file may cite them, the deliverables may not. |
| Edits land in `.claude/**` and are wiped by the next regeneration | H | L | Every phase names an `agent-system/extensions/**` path. No phase writes under `.claude/**`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5, 6 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Wave 2's three phases touch disjoint files
(territory: Phase 2 owns `skill-implementer-hard/SKILL.md`; Phase 3 owns
`skill-orchestrate-hard/SKILL.md`; Phase 4 owns the lean SKILL.md and `update-task-status.sh`).

---

### Phase 1: Canonical Gate Snippet and Library Usage Contract [COMPLETED]

**Goal**: Establish the one gate shape every site copies verbatim, and record in the library's own
header the filter-before-check anti-pattern that produced this defect at four sites — so a fifth
call site cannot silently reintroduce it.

**Tasks**:
- [x] Edit `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` header prose only
      (no code, no pattern, no function-body change) to add a "Ordering contract for filtered
      scans" note stating: `PHASE_HEADING_ERE` filters to conforming headings, so a non-conforming
      heading is **invisible** to any grep using it, not merely unmatched; therefore any consumer
      that derives a **selection or a count** from such a grep MUST call
      `has_nonconforming_phase_headings <file>` over the **whole file first** and take a named
      INCONCLUSIVE branch on a hit. Name `has_nonconforming_phase_headings` as the required
      predicate and state explicitly that the `nonconforming_phase_headings | grep -q .` pipe form
      is forbidden (unsafe under `pipefail`). Reference `update-task-status.sh`'s phase-check gate
      by function/gate name as the reference implementation. *(completed)*
- [x] Record the canonical gate snippet below as the copy target for Phases 2-4. It is
      site-independent except for the `warn_nonconforming` label and the surrounding variable name
      for the plan path: *(completed)*

```bash
next_phase=""
phase_scan_inconclusive=false
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  . .claude/scripts/lib/phase-heading-patterns.sh
  # --- resume-scan-conformance-gate:begin ---
  # Whole-file conformance check BEFORE the filtered scan below. PHASE_HEADING_ERE admits
  # conforming headings only, so a non-conforming heading is not merely unmatched by that grep --
  # it is INVISIBLE to it, and the scan would silently select the next conforming OPEN heading
  # instead, dispatching out of order on top of unfinished work. has_nonconforming_phase_headings
  # is the required boolean predicate; the `nonconforming_phase_headings | grep -q .` pipe form is
  # forbidden (unsafe under pipefail).
  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "<SITE_LABEL>" || true
    phase_scan_inconclusive=true
  else
    next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1)
    if [ -n "$next_heading" ]; then
      next_phase=$(extract_phase_number "$next_heading") || next_phase=""
      if [ -z "$next_phase" ]; then
        # Defense-in-depth only, and unreachable by construction: the grep above already
        # guarantees this line matches PHASE_HEADING_ERE. Funnelled into the same sentinel so
        # there is exactly one inconclusive path, never a second silent one.
        phase_scan_inconclusive=true
      fi
    fi
  fi
  # --- resume-scan-conformance-gate:end ---
fi
```

- [x] Confirm the sentinel comment markers `resume-scan-conformance-gate:begin` /
      `:end` are unique strings not already present anywhere in the repo (they are the extraction
      anchor Phase 5 depends on). *(completed: confirmed zero pre-existing hits via
      grep -r "resume-scan-conformance-gate" before use)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the library needs **no behavioral change** — that both
required predicates already exist with the contracts research reported. Confirm at implementation
time by reading `has_nonconforming_phase_headings` and `warn_nonconforming` in full and verifying:
(a) `has_nonconforming_phase_headings` captures producer output via command substitution before
testing emptiness (not a pipe), (b) `warn_nonconforming` emits a line number per finding, and
(c) `warn_nonconforming` returns non-zero when findings exist. If any is false, this phase gains a
library-code sub-step and the plan's "prose only" claim is superseded.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` — header comment block
  only; add the ordering contract note.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` clean.
- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` still exits 0
  (proves the comment-only edit changed no behavior).
- `git diff` on the library shows comment lines only — zero changes below the header block.

---

### Phase 2: Site B — `skill-implementer-hard` Reachable Hard Stop [COMPLETED]

**Goal**: Make the existing `exit 1` posture reachable, and place it above the entire cascade so
the `else next_phase=1` false-re-dispatch path is gated too.

**Tasks**:
- [x] In `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` Stage 3b, replace
      the `next_phase=""` ... `fi` scan region with the Phase 1 canonical snippet, label
      `"implementer-hard-next-phase"` (label preserved verbatim — it appears in operator-facing
      warnings). *(completed)*
- [x] Insert the posture branch **immediately after** the gate region's closing `fi` and
      **immediately before** the existing `if [ -n "$next_phase" ]` cascade: *(completed)*

```bash
if [ "$phase_scan_inconclusive" = "true" ]; then
  echo "[hard-mode] STOP: resume-scan found a non-conforming phase heading -- refusing to guess a resume point. See the named, line-numbered warning above." >&2
  exit 1
fi
```

- [x] Delete the now-superseded `warn_nonconforming` + `echo` + `exit 1` lines from the old inner
      `if [ -z "$next_phase" ]` branch (the canonical snippet replaces that branch body with the
      sentinel assignment). *(completed)*
- [x] Update the block's leading comment to state the ordering contract and to record the
      leaf-worker posture rationale from Decision 3 in one or two sentences. No task-number
      citations. *(completed)*
- [x] Confirm the cascade below is otherwise untouched: `if [ -n "$next_phase" ]` /
      `elif ... skeleton ...` / `else next_phase=1` remain byte-identical. *(completed: confirmed
      by diff -- only the scan region above the cascade changed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` — Stage 3b scan block.

**Verification**:
- Extract the region between the sentinel markers and confirm `bash -n` clean.
- Grep confirms the `phase_scan_inconclusive` guard's line number is **less than** the line number
  of the cascade's first `elif`.
- Grep confirms exactly one `has_nonconforming_phase_headings` call and zero occurrences of
  `nonconforming_phase_headings |` in the file.
- Full behavioral assertion deferred to Phase 5's harness.

---

### Phase 3: Site A — `skill-orchestrate-hard` Dedicated Inconclusive Branch [COMPLETED]

**Goal**: Replace the unsafe "leave `next_phase` empty and fall through" posture with a distinct
first branch that terminates via this file's own `EXIT (partial, ...)` convention, so an
inconclusive scan can never be mistaken for skeleton-exhaustion or full completion.

**Tasks**:
- [x] In `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, State
      `planned`/`implementing` Per-Phase Dispatch (H1), replace the `next_phase=""` ... `fi` scan
      region with the Phase 1 canonical snippet, label `"orchestrate-hard-next-phase"` (preserved
      verbatim). *(completed)*
- [x] Restructure the cascade so the inconclusive branch is **first**: *(completed)*

```bash
if [ "$phase_scan_inconclusive" = "true" ]; then
  echo "[hard-orchestrate] H1: non-conforming phase heading(s) in $plan_path — the filtered resume scan cannot see them, so the true next phase is UNKNOWN." >&2
  echo "[hard-orchestrate] Refusing to dispatch, and refusing to claim skeleton-exhaustion or completion. Fix the plan's heading grammar (see plan-format.md's canonical phase-heading shape) and re-run." >&2
  EXIT (partial, non-conforming phase heading — next phase unknown)

elif [ -n "$next_phase" ]; then
  ...unchanged...
elif [ "$last_skeleton" = "true" ]; then
  ...unchanged...
else
  ...unchanged...
fi
```

- [x] Confirm the branch does **not** remove `$loop_guard_file`. Verified against the file's other
      `EXIT (partial` sites (the "no handoff, no blockers" sub-state and the
      MAX_INFRA_FAILURES / MAX_CYCLES exits): none of them clean the loop guard — that cleanup is
      reserved for `EXIT (success...)` loop-termination paths. Matching this keeps the new branch
      consistent with the established convention. *(completed: confirmed by grep, new branch body
      contains neither `loop_guard_file` nor `update-task-status.sh`)*
- [x] Confirm the branch performs **no** status transition and does **not** call
      `skill_preflight_update` — that call must remain inside the dispatch branch only, per the
      existing comment stating it belongs to that branch exclusively. *(completed: confirmed by
      grep, only occurrence within this cascade is inside the dispatch branch)*
- [x] Update the block's leading comment to record the orchestration-loop posture rationale from
      Decision 3 and to state explicitly why `exit 1` is wrong here. No task-number citations.
      *(completed)*
- [ ] Optional consistency cleanup (non-blocking, take only if the diff stays clean): the
      `=== BEGIN/END 772 Item 5A ===` fence comments wrapping this region cite an ephemeral
      identifier. They do **not** trip the write-time guard (its pattern requires the literal word
      `task`), so purging them is not required. If purged, replace with the durable anchor
      `=== BEGIN/END heading-scan phase selection + skeleton-exhaustion routing ===`.
      *(deviation: skipped — explicitly optional per the task's own wording; left unchanged to
      keep the diff minimal and reduce risk of an unrelated cleanup interfering with the
      structural edit)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — H1 per-phase dispatch
  block.

**Verification**:
- Extract the region between the sentinel markers and confirm `bash -n` clean. (The surrounding
  fence contains `Agent tool:` and `EXIT (...)` pseudo-syntax and is **not** valid bash — this is
  pre-existing and expected; do not attempt `bash -n` on the whole fence.)
- Grep confirms branch **order**: the `phase_scan_inconclusive` test's line number is less than the
  `[ -n "$next_phase" ]` test's, which is less than the `last_skeleton` test's.
- Grep confirms the new branch body contains `EXIT (partial` and contains neither `exit 1` nor
  `loop_guard_file` nor `update-task-status.sh`.
- Full behavioral assertion deferred to Phase 5's harness.

---

### Phase 4: Audit-Derived Sites — Lean Clone (Site C) and `first_phase_heading` (Site D) [COMPLETED]

**Goal**: Execute Scope Decisions 1 and 2, closing the two sites the consumer audit found outside
the declared `file_scope`.

**Tasks**:

Site C — `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`, Stage 3:
- [x] Replace the scan region with the Phase 1 canonical snippet, adapting the plan-path variable
      name to the site's existing `$plan_file` and preserving the label
      `"lean-implementation-hard-next-phase"` verbatim. Keep the site's existing variable names
      (`next_phase_heading`, `phase_number`) rather than renaming to the core sites' names — the
      change under test is the ordering gate, not a rename. *(completed)*
- [x] Add the posture branch after the gate region, using this file's own convention: *(completed)*

```bash
if [ "$phase_scan_inconclusive" = "true" ]; then
  return error "Non-conforming phase heading(s) found during resume-scan -- the filtered scan cannot see them, so the resume point is UNKNOWN. Refusing to guess. See the named, line-numbered warning above."
fi
```

- [x] Delete the superseded `warn_nonconforming` + `return error` from the old inner
      `if [ -z "$phase_number" ]` branch. *(completed)*
- [x] Add a one-line comment recording that this site adopts the leaf-worker posture for the same
      reason as the core implementer-hard site. No task-number citations. *(completed)*

Site D — `agent-system/extensions/core/scripts/update-task-status.sh`, plan-initialization
convenience path:
- [x] Guard the `first_phase_heading` grep with the whole-file check, warn on a hit, and **skip**
      the convenience entirely rather than guessing: *(completed)*

```bash
if has_nonconforming_phase_headings "$plan_file"; then
  warn_nonconforming "$plan_file" "update-task-status-first-phase" || true
  echo "[first-phase] Non-conforming phase heading(s) in $(basename "$plan_file") -- skipping the first-phase auto-advance convenience rather than advancing a wrong phase. Non-fatal; the dispatched agent owns every per-phase transition directly." >&2
else
  ...existing first_phase_heading grep + extract_phase_number + auto-advance, unchanged...
fi
```

- [x] Confirm no new sourcing is required — the library is already sourced at file scope (it backs
      the existing phase-check gate). If it is not in scope at this point in the script, stop and
      record Site D as out-of-scope follow-up rather than adding new plumbing to a self-documented
      non-fatal path. *(completed: confirmed `has_nonconforming_phase_headings`/`warn_nonconforming`
      are already in scope at this point in the script, backing the pre-existing D3 gate; no new
      sourcing added)*
- [x] Preserve the path's non-fatal character exactly: no new `exit`, no new return code, no change
      to the surrounding function's contract. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts these are the **only** two remaining sites with the
filter-before-check ordering defect. Confirm at implementation time by re-running the library's own
documented consumer-discovery command,
`grep -rl 'phase-heading-patterns.sh' agent-system/extensions`, and checking every non-test,
non-doc, non-manifest hit for a filtered grep that feeds a selection or count without a preceding
whole-file check. Research verified the remaining consumers are already correctly wired; if a new
one has appeared, add it here or record it as follow-up — do not leave it silently unaddressed.
**Confirmed at implementation time**: re-ran `grep -rl 'phase-heading-patterns.sh'
agent-system/extensions`; the consumer list is unchanged from the research report's audit (same
23 hits: the four now-fixed sites A/B/C/D, plus the already-correctly-wired sites
`update-task-status.sh`'s D3 gate, `skill-base.sh`'s `skill_corroborate_phase_counts`,
`validate-artifact.sh`, `general-implementation-agent.md`/`general-implementation-hard-agent.md`
Stage 5a, `commands/task.md` Step 3, `skill-orchestrate/SKILL.md`'s recovery diagnostic, and the
parameter-driven exception `update-phase-status.sh`, plus test/doc/manifest hits). No new consumer
has appeared; no follow-up needed.

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — Stage 3 scan
  block.
- `agent-system/extensions/core/scripts/update-task-status.sh` — plan-initialization
  `first_phase_heading` path.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/update-task-status.sh` clean.
- Extract the lean site's sentinel-delimited region and confirm `bash -n` clean.
- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` exits 0.
- Grep confirms zero `nonconforming_phase_headings |` pipe forms in either file.
- Consumer-discovery command re-run; result recorded in the phase's completion note.

---

### Phase 5: Verification Harness Exercising the `4C` Bar [COMPLETED]

**Goal**: Add the first executable regression test for these markdown-embedded scan blocks,
asserting the task's verification bar directly rather than by inspection.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh`,
      structurally modeled on the existing `tests/test-phase-heading-patterns.sh`
      (`pass()`/`fail()`/`info()` helpers, PASSED/FAILED counters, exit 0 all-pass / 1 any-fail /
      2 environment error, deploy-tree-first then source-store-fallback library resolution).
      *(completed)*
- [x] Implement region extraction: `awk` between `resume-scan-conformance-gate:begin` and
      `:end` from each of the three SKILL.md files; rewrite the
      `. .claude/scripts/lib/phase-heading-patterns.sh` line to the resolved `$LIB` path; `eval`
      the region in a subshell with `plan_path`/`plan_file` bound to a fixture. Fail with a clear
      message (not a silent skip) if a marker pair is missing from any of the three files.
      *(deviation: altered — the sourcing line sits immediately BEFORE the sentinel
      `:begin` marker at all three sites, per the Phase 1 canonical snippet, so it is not
      textually present inside the extracted region to rewrite. The harness instead sources
      `$LIB` directly inside `run_region()`'s subshell before `eval`'ing the region and
      initializes the result variable / `phase_scan_inconclusive`, which is behaviorally
      identical to rewriting an in-region line since the region's own logic never re-sources the
      library. Marker-missing detection is still a loud, clear failure via `extract_region()`.)*
- [x] Fixture A (the verification bar), a plan containing in order: a `[COMPLETED]` conforming
      phase, `### Phase 4C: ... [IN PROGRESS]`, then `### Phase 5: ... [NOT STARTED]`. Assert, per
      site:
      - stderr contains a warning naming `4C`,
      - that warning carries the fixture **line number** of the `4C` heading,
      - `phase_scan_inconclusive` is `true`,
      - `next_phase` is empty — and specifically **not** `5`.
      *(completed: all assertions pass at all three sites)*
- [x] Fixture B (happy path), a fully conforming plan: phase 1 `[COMPLETED]`, phase 2
      `[IN PROGRESS]`, phase 3 `[NOT STARTED]`. Assert `next_phase` is exactly `2`,
      `phase_scan_inconclusive` is `false`, and stderr is empty. This is the no-behavior-change
      assertion and is required, not optional. *(completed: all assertions pass at all three
      sites)*
- [x] Fixture C (decimal sub-phase), a conforming plan whose open phase is `3.1`. Assert
      `next_phase` is `3.1` — guards against a regression that silently drops decimal support while
      adding the gate. *(completed: passes at all three sites)*
- [x] `bash -n` assertion on every extracted region. *(completed)*
- [x] Structural assertions on the posture branches (which contain pseudo-syntax and cannot be
      executed): Site B's `exit 1` is guarded by `phase_scan_inconclusive` and precedes the
      cascade's first `elif`; Site A's `EXIT (partial` branch is guarded by
      `phase_scan_inconclusive` and is the **first** branch, preceding both `[ -n "$next_phase" ]`
      and `last_skeleton`; Site C's `return error` is guarded by the sentinel. *(completed)*
- [x] Repo-wide assertion: zero occurrences of the racy `nonconforming_phase_headings | grep -q`
      form under `agent-system/extensions/`. *(completed: the assertion excludes backtick-quoted
      doc-comment references to the forbidden form — e.g. the canonical gate snippet's own header
      comment, which intentionally quotes it as documentation — since real invocation syntax is
      never backtick-wrapped; this cannot hide a genuine violation)*
- [x] Register the new script in `agent-system/extensions/core/manifest.json` under
      `provides.scripts` as `"tests/test-resume-scan-nonconformance.sh"`, keeping the existing
      alphabetical ordering within the `tests/` group. *(completed)*
- [x] Record in the script header the honest scope limit: the enclosing markdown fences are **not**
      valid bash and never were (`Agent tool:`, `EXIT (...)` pseudo-syntax); this suite covers the
      sentinel-delimited executable regions plus structural assertions on the posture branches, and
      Site D is covered by `bash -n` and structural grep only, not by execution. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts three sentinel-delimited regions exist and are
independently extractable and executable. Confirm at implementation time by running the extraction
against each of the three files before writing any assertion; if a region does not `bash -n` clean
in isolation, the phase's first corrective step is to narrow that site's markers, never to relax
the assertion.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` — new.
- `agent-system/extensions/core/manifest.json` — one `provides.scripts` entry.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` exits 0
  with every case reported PASS. *(confirmed: 39 passed, 0 failed, exit 0)*
- Adversarial check: temporarily revert one site's gate to the pre-fix ordering in a scratch copy
  and confirm the suite **fails** on Fixture A. A suite that passes against the pre-fix code
  proves nothing; record the observed failure output in the phase completion note. *(confirmed:
  reverted Site B's `resume-scan-conformance-gate` region in a scratch copy of
  `agent-system/extensions/` to the pre-fix filtered-grep-first ordering (no whole-file check
  before the grep). Re-ran the suite against the scratch copy: exit code 1, "Results: 34 passed,
  5 failed", with the 5 failures being exactly the Fixture A assertions for Site B — including
  "Site B (skill-implementer-hard): Fixture A result variable was '5' -- phase 5 was silently
  selected despite the non-conforming 4C heading". This is the exact silent-mis-selection bug the
  fix eliminates. Scratch copy discarded after the check.)*
- `jq . agent-system/extensions/core/manifest.json` parses. *(confirmed)*
- `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` exits 0
  (unchanged). *(confirmed: 35 passed, 0 failed, exit 0 — identical result to before Phase 5)*

---

### Phase 6: Record the Contract and Posture Asymmetry in `plan-format.md` [IN PROGRESS]

**Goal**: Make the document's "closed contract, not an aspiration" claim verifiably true
end-to-end, so a future reader need not re-derive whether the resume-scan sites actually honor it.

**Tasks**:
- [ ] In `agent-system/extensions/core/context/formats/plan-format.md`, "Canonical phase-heading
      shape" subsection, extend the "Non-conforming headings" paragraph with a short note recording
      the **ordering** obligation: every consumer that derives a selection or a count from a
      `PHASE_HEADING_ERE`-filtered grep runs `has_nonconforming_phase_headings` over the whole file
      **first**, because a non-conforming heading is invisible to — not merely unmatched by — that
      grep.
- [ ] Record the posture asymmetry in one or two sentences: leaf-worker resume scans stop hard;
      the orchestration loop routes to its own `EXIT (partial, ...)` terminal convention. State
      that the difference is deliberate and name the reason (no subagent dispatched yet vs. a
      long-running loop with established terminal-condition bookkeeping).
- [ ] Leave the existing consumer-list sentence's structure intact — it already names the
      resume-scan sites and the live `grep -rl` discovery mechanism. Do not convert it back to a
      hand-maintained list.
- [ ] Do **not** touch the letter-suffix prohibition, the canonical regex table, or any other
      grammar text. Verify by diff that the D1 decision paragraph is byte-identical after the edit.
- [ ] No task-number citations anywhere in the edit — reference the fix by its mechanism ("the
      resume-scan sites run `has_nonconforming_phase_headings` before selection"), never by task
      number.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` — "Canonical phase-heading shape"
  subsection only.

**Verification**:
- `git diff` confirms changes are confined to the "Canonical phase-heading shape" subsection and
  that the letter-suffix prohibition paragraph and regex table are unchanged.
- `bash .claude/scripts/check-task-references.sh` (or the source-store equivalent) reports no new
  findings.
- The claims written are true of the code as landed in Phases 2-4 — re-read those diffs before
  writing this text, not from the plan.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` exits 0.
- [ ] Verification bar, met explicitly: a plan containing `### Phase 4C: ... [IN PROGRESS]` followed
      by `### Phase 5: ... [NOT STARTED]` produces a loud, named warning identifying the `4C`
      heading **by line number**, and `next_phase` is empty — never `5` — at every wired site.
- [ ] Happy-path invariance: a fully conforming plan resolves the identical next phase as before,
      with empty stderr, at every wired site.
- [ ] Decimal sub-phase (`3.1`) resolution preserved.
- [ ] `bash -n` clean on `phase-heading-patterns.sh`, `update-task-status.sh`, and every
      sentinel-delimited extracted region.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-phase-heading-patterns.sh` exits 0
      (library behavior unchanged).
- [ ] `jq . agent-system/extensions/core/manifest.json` parses.
- [ ] Adversarial check recorded: the new suite demonstrably fails against pre-fix ordering.
- [ ] Zero `nonconforming_phase_headings | grep -q` pipe forms under `agent-system/extensions/`.
- [ ] Zero edits under `.claude/**`; every modified path is under `agent-system/extensions/**`.
- [ ] No task-number citations introduced in any deliverable outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` (header contract note)
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (Site B gate + posture)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Site A gate + first branch)
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` (Site C)
- `agent-system/extensions/core/scripts/update-task-status.sh` (Site D minimal guard)
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` (new)
- `agent-system/extensions/core/manifest.json` (one entry)
- `agent-system/extensions/core/context/formats/plan-format.md` (contract + posture record)
- `specs/960_wire_nonconformance_detection_into_resume_scan_sites/summaries/01_*-summary.md`

## Rollback/Contingency

- Every phase is an independent, additive edit to a distinct file region; `git revert` of a phase's
  commit restores the prior behavior exactly. The pre-fix behavior is the current shipped behavior,
  so a partial rollback degrades to today's state rather than to a broken intermediate.
- Phases 2, 3, and 4 touch disjoint files and can be reverted independently.
- If Phase 4's Site C proves unexpectedly entangled with lean-specific control flow, drop that
  half of the phase, record it as follow-up work in the implementation summary naming the file and
  Stage, and proceed — Phase 5's harness must then be narrowed to two sites and its header must
  state which site is uncovered and why. Silently dropping it is not an acceptable outcome.
- If Phase 5's extraction proves infeasible for a site, the fallback is **not** to delete the
  assertion: narrow that site's sentinel markers until the enclosed region is executable. If that
  still fails, the harness must record the site as structurally-verified-only in its header, and
  the implementation summary must name it as a verification gap.
