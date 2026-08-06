# Implementation Plan: Repair Stage 4 H4 Gate and Skeleton Summary Propagation

- **Task**: 959 - repair_stage4_h4_gate_and_skeleton_summary_propagation
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/959_repair_stage4_h4_gate_and_skeleton_summary_propagation/reports/01_h4-gate-and-skeleton-summary-propagation.md
- **Artifacts**: plans/01_h4-gate-and-summary-propagation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two mechanical, low-risk defects sit in the same Stage 4 region of
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. Defect A is a
literal-string H4 adversarial-verification gate that false-negatives on a stronger-but-differently-
headed claim table; Defect B is a skeleton-exhaustion exit path that transitions status and exits
without ever propagating `completion_summary`/`roadmap_items`, leaving a stale, misleading summary
in `state.json`. Both are fixed in one file. Definition of done: both known adversarial-table
header formats satisfy the H4 gate, the skeleton-exhaustion exit writes a current-plan-version
`completion_summary` and populates `roadmap_items` when the return-meta supplies them, and the
edited embedded bash is `bash -n` clean.

**Binding source-store rule**: every edit targets
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. The deployed
`.claude/skills/skill-orchestrate-hard/SKILL.md` is a gitignored, regenerated artifact and MUST
NOT be hand-edited; it picks the change up on the next deploy/resync.

### Research Integration

The research report supplies four load-bearing findings this plan builds on directly:

1. **A verified shape regex for Defect A**, tested against three fixtures with real GNU grep 3.12:
   `grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|'` matches both
   the canonical `| Claim | Source/Counterexample | ... |` header and the observed
   `| # | Claim under attack | Source / counterexample | Outcome |` header, and does not match an
   unrelated table. The report also warns that this session's interactive `grep` alias resolves to
   a `ugrep`-based wrapper that spuriously fails this pattern — fixture verification MUST run
   against `/run/current-system/sw/bin/grep`.
2. **Exactly one call site exists** for the H4 literal string across
   `agent-system/extensions/core/`, so the task description's own conditional ("prefer a named,
   reusable matcher... if a second call site exists") resolves to: keep it inline, well-commented.
3. **Defect B's data is already present and correct** at the skeleton-exhaustion branch. The last
   per-phase implement dispatch always writes `status: "implemented"` plus `completion_data` to
   `.return-meta.json`, which is the `recovered=true` path where
   `orchestrate-recover-outcome.sh` correctly populates `completion_summary`/`roadmap_items`.
   `dispatch_start_ts`, `TASK_DIR`, and `TASK_TYPE` are all still in scope and correctly valued at
   that branch — no new plumbing or timestamp variable is needed.
4. **A specific bash hazard to avoid**: never use the `"${completion_json:-{}}"` inline default
   idiom; bash default-word matching stops at the first unescaped `}`, silently corrupting the
   JSON. Use `[ -z "${completion_json:-}" ] && completion_json='{}'`, matching the existing Stage 5
   tail comment.

The report also flags an out-of-scope doc/code mismatch in `orchestrate-recover-outcome.sh` (its
header claims `completion_summary`/`roadmap_items` are populated "regardless of branch," but the
non-success `emit` calls hardcode `""`/`"[]"`). That file is outside this task's FILE SCOPE and the
mismatch does not affect this fix's correctness. Phase 4 records it for a follow-up rather than
folding it in.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no `roadmap_flag` was set. No roadmap
phases are included.

## Goals & Non-Goals

**Goals**:
- Make the Stage 4 H4 gate recognize adversarial claim tables by semantic shape rather than by a
  fixed header string, so a stronger-but-differently-headed table no longer forces a redundant
  re-dispatch.
- Make the Stage 4 skeleton-exhaustion exit propagate `completion_summary` and `roadmap_items`,
  sourced from the same return-meta mechanism the Stage 5 tail already uses.
- Route both exit paths through ONE named helper so a future third exit path cannot silently
  repeat the omission.
- Keep the edited embedded bash syntactically valid.

**Non-Goals**:
- Changing the first `grep -q "## Adversarial Self-Verification"` heading check. It was not
  reported as brittle and is out of scope.
- Creating a new shared library/pattern file for the adversarial-table matcher. Only one call site
  exists; an inline, well-commented regex is the right-sized fix per the task's own conditional.
- Fixing the `orchestrate-recover-outcome.sh` doc/code mismatch. Outside the declared FILE SCOPE.
- Supporting a hypothetical reordered table format (source/counterexample before claim). No such
  format has been observed or specified, and the canonical agent contract fixes the ordering.
- Editing any file under `.claude/**`, or editing any file other than the one in FILE SCOPE.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Fixture verification run under the session's `ugrep`-based `grep` alias yields a false failure and the implementer "fixes" a correct regex | H | M | Phase 1 mandates invoking `/run/current-system/sw/bin/grep` by absolute path for every fixture check, per the report's explicit warning |
| Helper extraction touches the working Stage 5 tail, widening the diff and risking a regression in a currently-correct path | M | M | Phase 3 preserves the tail's `$recover_json` reuse by giving the helper an optional pre-computed-JSON parameter; Phase 4 diff-reads the tail to confirm behavior is byte-equivalent. Documented fallback: if the tail refactor proves risky, leave the tail untouched and call the helper only from the skeleton branch — the VERIFICATION BAR is still met |
| New regex admits a false positive on an unrelated table, letting an unverified report pass the H4 gate | M | L | Phase 1 includes a negative fixture (`\| Some other table \| with columns \| not adversarial \|`) that must NOT match |
| `bash -n` cannot validate the fenced blocks as whole files (they interleave literal shell with `Agent tool:` and `EXIT (...)` pseudo-statements) | M | H | Phase 4 extracts only the added/changed shell statements into a function-wrapped scratch file and runs `bash -n` on that, exactly as the report's Appendix did |
| Edits land in the gitignored `.claude/` deploy tree and are silently wiped | H | L | Every phase names the `agent-system/extensions/core/**` path explicitly; Phase 4 greps the diff to confirm no `.claude/**` path was written |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: all four
phases edit or verify the same file, so serializing them avoids edit conflicts even where no
logical dependency exists.

---

### Phase 1: Shape-based H4 adversarial-table matcher (Defect A) [COMPLETED]

**Goal**: Replace the literal-string claim-table grep in the Stage 4 `researched` handler's H4 gate
with a case- and spacing-insensitive shape match tolerant of extra columns, and update the adjacent
comment so a future reader does not reintroduce a literal check.

**Tasks**:
- [x] Locate the H4 gate's second `grep -q` in the `researched` handler of
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (currently
      `grep -q "| Claim | Source/Counterexample" "$research_path"`, inside the
      `if [ "$adversarial_verified" = "false" ]` block). *(completed)*
- [x] Replace it with the verified shape regex:
      `grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"`
      *(completed)*
- [x] Rewrite the adjacent comment (currently describing "the required Claim Verification Table
      header") to state that the match is shape-based — a claim-bearing cell immediately followed by
      a cell containing both "source" and "counterexample" — and to name both known passing formats
      as examples, so the invariant is legible without re-deriving it. *(completed)*
- [x] Leave the first `grep -q "## Adversarial Self-Verification"` heading check unchanged.
      *(completed)*
- [x] Verify with three fixtures using the real binary at `/run/current-system/sw/bin/grep` (NOT a
      bare `grep`, which resolves to a `ugrep`-based wrapper in this session that spuriously fails
      this pattern):
      - `| Claim | Source/Counterexample | Verification Method | Confidence |` -> MATCH
      - `| # | Claim under attack | Source / counterexample | Outcome |` -> MATCH
      - `| Some other table | with columns | not adversarial |` -> NOMATCH
      *(completed: all three fixtures verified against /run/current-system/sw/bin/grep)*

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The plan asserts there is exactly ONE call site for the literal
`| Claim | Source/Counterexample` string across `agent-system/extensions/core/` (the basis for
keeping the matcher inline rather than extracting a shared library). Confirm at implementation time
with `grep -rn 'Claim | Source' agent-system/extensions/core/` — if a second grepping consumer has
appeared since the research pass, escalate to a named shared matcher per the task description's
conditional and note the deviation in the summary.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — H4 gate regex + adjacent
  comment in the Stage 4 `researched` handler.

**Verification**:
- All three fixtures produce the expected match/nomatch under `/run/current-system/sw/bin/grep`.
- Diff read-through confirms only the one `grep -q` line and its comment changed; the
  `## Adversarial Self-Verification` heading check is untouched.

---

### Phase 2: Define the shared completion-propagation helper [NOT STARTED]

**Goal**: Add one named helper to the file that reads `.return-meta.json` via the sanctioned single
reader and calls `skill_propagate_completion_summary`, so both Stage 4 and Stage 5 exit paths can
share it.

**Tasks**:
- [ ] Define `hard_orchestrate_propagate_completion()` in the same fenced helper block that holds
      `build_hard_mode_prompt_context()` (the file's one existing inline-helper location), or in an
      adjacent block if placement there would disturb the prompt-context block's readability.
- [ ] Give it this parameter contract, mirroring `skill_propagate_completion_summary`'s own optional
      trailing-argument pattern:
      `hard_orchestrate_propagate_completion <task_number> <task_type> <task_dir> <dispatch_start_ts> [precomputed_json]`
- [ ] Body: when `precomputed_json` is non-empty, use it directly; otherwise call
      `bash .claude/scripts/orchestrate-recover-outcome.sh "$task_dir" "$dispatch_start_ts" 2>/dev/null`.
      Guard the non-empty check on the value itself, never on control-flow position.
- [ ] Default an empty result with `[ -z "${completion_json:-}" ] && completion_json='{}'` — never
      the `"${completion_json:-{}}"` inline idiom. Carry forward the existing explanatory NOTE
      comment about why that idiom corrupts JSON, so the hazard stays documented at the one place
      the code now lives.
- [ ] Extract `completion_summary` via `jq -r '.completion_summary // ""'` and `roadmap_items` via
      `jq -c '.roadmap_items // []'`, each with `2>/dev/null` and a fail-closed `|| var=default`.
- [ ] Call `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"`.
- [ ] Emit the existing empty-summary warning (`[hard-orchestrate] WARNING: task completed with
      empty completion_summary (reason=...)`, reading `.reason` from the JSON) from inside the
      helper so BOTH call sites inherit it rather than only the Stage 5 tail.
- [ ] Add a short comment stating that this helper is the single propagation path for every
      terminal exit in this file, and that a new exit path must call it.

**Timing**: 25 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — new helper function
  definition alongside `build_hard_mode_prompt_context()`.

**Verification**:
- The helper body, extracted to a scratch file, is `bash -n` clean.
- Read-through confirms the parameter order matches what Phase 3's two call sites will pass, and
  that no `"${var:-{}}"` idiom appears anywhere in the new code.

---

### Phase 3: Wire both exit paths to the helper (Defect B) [NOT STARTED]

**Goal**: Call the helper from the Stage 4 skeleton-exhaustion branch before its `EXIT`, and
refactor the Stage 5 `implemented` tail to call the same helper while preserving its
`$recover_json` reuse optimization.

**Tasks**:
- [ ] In the `elif [ "$last_skeleton" = "true" ]` branch, insert the propagation call AFTER the
      `follow_up_tasks`/`follow_up_count` extraction and BEFORE
      `rm -f "$loop_guard_file"` / `EXIT`. Placement relative to the
      `update-task-status.sh postflight ... pr_ready` call should match the Stage 5 tail's ordering
      (propagate after the status transition), so both paths write state in the same order.
- [ ] Pass no precomputed JSON from this site — the skeleton branch has no cached `$recover_json`
      and needs a fresh read:
      `hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}"`
- [ ] Add a comment at this call site explaining why `dispatch_start_ts` is still correct here: this
      branch is only entered on a cycle where no new dispatch occurred, so the variable still holds
      the last real per-phase implement dispatch's timestamp, which precedes that dispatch's
      `.return-meta.json` write — exactly the freshness window the recovery script's staleness gate
      expects.
- [ ] In the Stage 5 `implemented` tail, replace the inline block (the `if [ -n "${recover_json:-}" ]`
      selection, the `[ -z ] && completion_json='{}'` default, the two `jq` extractions, the
      `skill_propagate_completion_summary` call, and the trailing empty-summary warning) with a
      single call passing the cached JSON as the optional fifth argument:
      `hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}" "${recover_json:-}"`
- [ ] Confirm by read-through that the refactored tail preserves the "only ONE reader of
      `.return-meta.json` per cycle" invariant: when `recover_json` is non-empty the helper must not
      issue a second read.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: The plan asserts there are exactly TWO terminal exit paths in this file that
need completion propagation (the Stage 4 skeleton-exhaustion branch and the Stage 5 `implemented`
tail), and that `skill_propagate_completion_summary` has exactly ONE existing call site here.
Confirm at implementation time with
`grep -n 'skill_propagate_completion_summary\|^  EXIT \|EXIT (success' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
If a third terminal exit that should propagate is found, wire it to the same helper and record the
addition in the summary rather than leaving it inconsistent.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — skeleton-exhaustion branch
  (new call) and Stage 5 `implemented` tail (inline block replaced by call).

**Verification**:
- Both call sites pass arguments in the helper's declared order.
- The skeleton branch's call sits before `rm -f "$loop_guard_file"` and before `EXIT`.
- The Stage 5 tail no longer contains a duplicate inline propagation block.
- Extracted shell from both edited regions is `bash -n` clean.

**Fallback (documented, lower-risk)**: if the Stage 5 tail refactor turns out to disturb the
`$recover_json` reuse or the surrounding `skill_gate_completion_claim` structure, leave the tail
untouched and call the helper only from the skeleton-exhaustion branch. The VERIFICATION BAR is
still satisfied; note the deviation and the reason in the implementation summary.

---

### Phase 4: Verification, syntax check, and scope confirmation [NOT STARTED]

**Goal**: Confirm the VERIFICATION BAR is met end to end, that no out-of-scope file was touched, and
that no task-number citation leaked into the deliverable.

**Tasks**:
- [ ] Re-run all three Phase 1 fixtures against the final regex as it appears in the file, using
      `/run/current-system/sw/bin/grep` by absolute path. Both adversarial-table headers must match;
      the unrelated table must not.
- [ ] Extract every added/changed shell statement from both edited regions into one
      function-wrapped scratch file under the scratchpad directory and run `bash -n` on it. Do not
      attempt `bash -n` over an entire fenced block — the blocks interleave literal shell with
      `Agent tool:` and `EXIT (...)` pseudo-statements and will not parse.
- [ ] Trace the skeleton-exhaustion path by read-through and confirm it now reaches
      `skill_propagate_completion_summary` with a summary sourced from the current dispatch's
      `.return-meta.json`, and that `roadmap_items` is passed through as a JSON array (so
      `skill_propagate_completion_summary`'s `[ "$roadmap_items" != "[]" ]` guard admits it when
      non-empty).
- [ ] Confirm `git status --short` and the staged diff show changes ONLY under
      `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (plus `specs/**`
      artifacts). No `.claude/**` path may appear.
- [ ] Run `bash .claude/scripts/check-task-references.sh` (or scan the diff) to confirm no
      task-number citation was introduced into the edited SKILL.md.
- [ ] Record in the implementation summary the out-of-scope `orchestrate-recover-outcome.sh`
      doc/code mismatch surfaced by research (header claims `completion_summary`/`roadmap_items` are
      populated regardless of branch; the `STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS` `emit` calls
      hardcode `""`/`"[]"`) as a candidate follow-up. Do not fix it here.

**Timing**: 20 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- None (verification only). Any defect found is repaired in the phase that introduced it.

**Verification**:
- All three grep fixtures behave as specified.
- `bash -n` exits 0 on the extracted shell.
- Diff scope is confined to the one in-scope file plus `specs/**`.
- Task-reference check passes.

---

## Testing & Validation

- [ ] `| Claim | Source/Counterexample | Verification Method | Confidence |` satisfies the H4 gate.
- [ ] `| # | Claim under attack | Source / counterexample | Outcome |` satisfies the H4 gate.
- [ ] `| Some other table | with columns | not adversarial |` does NOT satisfy the H4 gate.
- [ ] All fixture checks were run with `/run/current-system/sw/bin/grep`, not a shell alias.
- [ ] The skeleton-exhaustion exit calls `skill_propagate_completion_summary` (via the shared
      helper) with a non-empty `completion_summary` derived from the current dispatch's
      `.return-meta.json`.
- [ ] `roadmap_items` reaches `skill_propagate_completion_summary` as a JSON array and is written
      when the return-meta supplies entries.
- [ ] `bash -n` is clean on the extracted added/changed shell.
- [ ] No `"${var:-{}}"` inline-default idiom appears in any new or edited line.
- [ ] Diff touches only `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` and
      `specs/**`.
- [ ] No task-number citation appears in the edited SKILL.md.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (modified — the sole
  deliverable file)
- `specs/959_repair_stage4_h4_gate_and_skeleton_summary_propagation/plans/01_h4-gate-and-summary-propagation.md`
  (this plan)
- `specs/959_repair_stage4_h4_gate_and_skeleton_summary_propagation/summaries/01_h4-gate-and-summary-propagation-summary.md`
  (implementation summary, including the recorded out-of-scope follow-up candidate)

## Rollback/Contingency

All changes are confined to one markdown file with no build artifacts and no state mutation at edit
time. To revert: `git checkout HEAD -- agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
(safe only on a clean tree, or after `bash .claude/scripts/git-snapshot.sh 959` on a dirty one, per
the No Destructive Git on Uncommitted Work rule).

Partial rollback is available per defect: Phase 1 (Defect A) and Phases 2-3 (Defect B) touch
disjoint regions of the file and can be reverted independently. If the Phase 3 Stage 5 tail refactor
proves problematic, take the documented fallback in that phase (helper called from the
skeleton-exhaustion branch only) rather than reverting Defect B entirely — the fallback still meets
the VERIFICATION BAR.

The deployed `.claude/skills/skill-orchestrate-hard/SKILL.md` needs no rollback action; it is
regenerated from the source store on the next deploy/resync.
