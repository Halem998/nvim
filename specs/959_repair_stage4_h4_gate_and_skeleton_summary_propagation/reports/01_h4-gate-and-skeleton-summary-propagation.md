# Research Report: Task #959

**Task**: 959 - repair_stage4_h4_gate_and_skeleton_summary_propagation
**Started**: 2026-08-05T00:00:00Z
**Completed**: 2026-08-05T00:00:00Z
**Effort**: small (two mechanical, low-risk edits in one Stage 4 region)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Codebase: `agent-system/extensions/core/scripts/skill-base.sh` (`skill_propagate_completion_summary`)
- Codebase: `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- Codebase: `agent-system/extensions/core/agents/general-research-hard-agent.md` (Stage 4.5)
- Codebase: `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 5/7)
- Codebase: `agent-system/extensions/core/context/contracts/adversarial-verification.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect A** (H4 gate, `SKILL.md` line 425): the `researched` handler's skip-check greps for
  the LITERAL header string `| Claim | Source/Counterexample`. The canonical header
  (`general-research-hard-agent.md` Stage 4.5) and the stronger observed variant
  `| # | Claim under attack | Source / counterexample | Outcome |` share a semantic shape (a
  "claim" cell immediately followed by a "source"+"counterexample" cell) but not a literal
  spelling. A tolerant, case-/spacing-insensitive, shape-based regex fixes this with a one-line
  change; no second call site exists today, so an inline (well-commented) regex — not a new
  shared library file — is the right-sized fix, consistent with the task's own conditional
  ("prefer a named matcher... if a second call site exists").
- **Defect B** (skeleton-exhaustion, `SKILL.md` lines 566-582): this `elif` branch transitions
  status to `pr_ready` and `EXIT`s directly from Stage 4, entirely bypassing the Stage 5 shared
  tail (lines 1060-1162) where `skill_propagate_completion_summary` is the only call site in this
  file. Fix: read `.return-meta.json`'s `completion_data` via
  `orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}"` (the exact
  mechanism the Stage 5 tail already uses, confirmed safe to reuse here — see Findings) and call
  `skill_propagate_completion_summary` before the branch's `EXIT`.
- **Recommended structure**: extract the read-and-propagate steps into one small named helper
  (e.g. `hard_orchestrate_propagate_completion`) defined once near `build_hard_mode_prompt_context`
  and called from BOTH the skeleton-exhaustion branch and the Stage 5 tail, so a future third exit
  path cannot repeat the omission — this was explicitly invited by the task description's
  "Consider whether..." framing, not merely a nice-to-have.
- Both fixes are confined to `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  per the task's FILE SCOPE; no other file needs to change for either defect.

## Context & Scope

Both defects sit in the same "Per-Phase Dispatch (H1)" and "Adversarial Verification Gate (H4)"
region of Stage 4 in `skill-orchestrate-hard/SKILL.md` (hard-mode `/orchestrate --hard` state
machine). The task bundles them deliberately since both edit the same file and would otherwise
need to be dependency-chained.

Per the binding SOURCE-STORE RULE, all edits target
`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — never the gitignored,
regenerated `.claude/` deploy tree.

## Findings

### Defect A — H4 gate literal-string brittleness

Current code (`SKILL.md` lines 420-428):

```bash
if [ -n "$research_path" ] && [ -f "$research_path" ]; then
  if grep -q "## Adversarial Self-Verification" "$research_path" && \
     grep -q "| Claim | Source/Counterexample" "$research_path"; then
    echo "[hard-orchestrate] H4: Adversarial verification section with Claim Verification Table found in report. Proceeding to planning." >&2
    adversarial_verified=true
  else
    ...re-dispatch...
```

- Only ONE call site for this pattern exists in the whole codebase (confirmed by
  `grep -rn "Claim | Source\|Adversarial Self-Verification\|Claim Verification Table"` across
  `agent-system/extensions/core/`) — `general-research-hard-agent.md` Stage 4.5 defines the
  canonical table (`| Claim | Source/Counterexample | Verification Method | Confidence |`) but
  never greps for it itself; the ONLY consumer of the literal string is this one Stage 4 gate.
  This satisfies the task's own conditional for staying inline (no second call site to justify a
  new shared matcher/library file).
- The observed failing case,
  `| # | Claim under attack | Source / counterexample | Outcome |`, differs from the canonical
  header in three ways simultaneously: an extra leading `#` column, extra words inside both the
  claim and source/counterexample cells, and a space around the `/` in "Source / counterexample".
  A literal-string grep fails on all three independently.
- **Shape invariant that holds across both formats**: a "claim"-bearing cell is immediately
  followed (next pipe-delimited cell) by a cell containing both "source" and "counterexample".
  This holds for the 2-column canonical header AND the 4-column observed variant, regardless of
  leading/trailing columns.
- Verified regex (GNU grep, case-insensitive extended regex):
  ```
  grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"
  ```
  Tested against three fixtures with GNU grep 3.12 (`/run/current-system/sw/bin/grep`):
  - `| Claim | Source/Counterexample | Verification Method | Confidence |` -> MATCH
  - `| # | Claim under attack | Source / counterexample | Outcome |` -> MATCH
  - `| Some other table | with columns | not adversarial |` -> NOMATCH (no false positive)
  (Note: this session's interactive `grep` shell alias resolves to a `ugrep`-based wrapper via
  `exec -a ugrep ...`, under which the same pattern spuriously failed to match even the canonical
  header — an artifact of that wrapper's `-G` basic-regex forcing, not of the pattern or of plain
  `grep -E`/`grep -qE` as actually used in the codebase's existing bash blocks, e.g. the
  `PHASE_HEADING_ERE` matcher at line 516. Verification was re-run against the real
  `/run/current-system/sw/bin/grep` binary to rule this out.)
- The `## Adversarial Self-Verification` heading check (first `grep -q`) was not reported as
  brittle and is left unchanged — the observed defect was specifically about the table header,
  not the section heading.

### Defect B — skeleton-exhaustion never propagates completion_summary/roadmap_items

Current code (`SKILL.md` lines 566-582, the `elif [ "$last_skeleton" = "true" ]` branch of the
`planned`/`implementing` per-phase-dispatch handler):

```bash
elif [ "$last_skeleton" = "true" ]; then
  follow_up_tasks=$(jq -r '...' "$handoff_file")
  follow_up_count=$(jq -r '...' "$handoff_file")
  echo "[hard-orchestrate] Skeleton plan exhausted — follow-up tasks pending: {${follow_up_tasks}}" >&2
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready
  rm -f "$loop_guard_file"
  EXIT (success, pr_ready — skeleton exhausted, ${follow_up_count} follow-up task(s): ${follow_up_tasks})
```

- `skill_propagate_completion_summary` (`scripts/skill-base.sh` lines 464-489) is the single
  shared writer of `completion_summary`/`roadmap_items` into `state.json`. Its only call site in
  this file today is the Stage 5 `implemented` tail (lines 1095-1123), reached only when the
  `dispatch_status` case-statement is entered via the shared postflight tail (`have_outcome=true`)
  — a code path this `elif` branch structurally never reaches, since it `EXIT`s directly from
  Stage 4.
- Confirmed via `agents/general-implementation-hard-agent.md` (Stage 5/7): every per-phase
  implement dispatch that finishes a phase — skeleton or not — writes `status: "implemented"` to
  BOTH `.orchestrator-handoff.json` (no `completion_data`-equivalent field there by design; see
  `docs/architecture/handoff-schema.md`) AND `.return-meta.json`, where `completion_data` with a
  mandatory `completion_summary` (and optional `roadmap_items`) IS written for `implemented`
  status (Stage 7: "`completion_summary` mandatory for `implemented`"). This means the LAST
  phase's `.return-meta.json` always carries the current-plan-version completion data by the time
  the skeleton-exhaustion branch runs — it is simply never read there.
- `orchestrate-recover-outcome.sh` is the sanctioned single reader of `.return-meta.json` for this
  purpose (its own header: "the ONE place that reads a task's `.return-meta.json`... so the three
  call sites... cannot drift into three separately-maintained recovery rules"). Its
  `completion_summary`/`roadmap_items` output fields are populated from `.completion_data` on the
  `recovered=true` path (status `researched|planned|implemented`), which is exactly the status the
  last skeleton-phase dispatch wrote. **Caveat discovered but out of this task's file scope**: the
  script's header doc claims `completion_summary`/`roadmap_items` are populated "regardless of
  branch," but its actual `emit` calls on the `STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS`
  non-success branches hardcode `""`/`"[]"` rather than the computed variables — a doc/code
  mismatch in `orchestrate-recover-outcome.sh` itself. This does not block Defect B's fix: the
  skeleton-exhaustion branch's last dispatch always has status `implemented` (per the agent
  contract above), which follows the `recovered=true` path where the values ARE correctly
  populated. Flagging this mismatch for a possible separate follow-up task since
  `orchestrate-recover-outcome.sh` is outside this task's FILE SCOPE.
- Timestamp correctness: `dispatch_start_ts` is reset only at the four actual dispatch sites in
  this file (`SKILL.md` lines 386, 432, 468, 553) — never elsewhere. The skeleton-exhaustion
  branch, by construction, is only entered on a cycle where NO new Agent dispatch happens this
  cycle (the heading-scan found nothing AND `last_skeleton=true` came from the PRIOR cycle's
  handoff). Therefore `dispatch_start_ts` still holds the timestamp from the last real per-phase
  implement dispatch (line 553), which precedes that same dispatch's `.return-meta.json` write —
  exactly the freshness window `orchestrate-recover-outcome.sh`'s staleness gate expects. Reusing
  `"${dispatch_start_ts:-9999999999}"` unchanged (the same expression the Stage 5 tail already
  uses at line 1110) is therefore correct here too, with no new timestamp variable needed.
- `TASK_TYPE` and `TASK_DIR` (non-`_ABS` form, matching the Stage 5 tail's own
  `orchestrate-recover-outcome.sh "$TASK_DIR" ...` call at line 1110) are both set once near the
  top of the state machine (`TASK_DIR` at line 133) and remain in scope throughout Stage 4, so no
  new plumbing is needed to reach this branch.
- Verified with an isolated `bash -n` pass (see Appendix) that the proposed shell-only addition
  (recover-outcome call + jq extraction + `skill_propagate_completion_summary` call, inserted
  before the existing `rm -f "$loop_guard_file"` / `EXIT`) is syntactically valid.

### Recommendations

**Defect A**: replace the second `grep -q` in the `researched` handler's H4 gate (line 425) with:
```bash
grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"
```
Keep the first `grep -q "## Adversarial Self-Verification"` check unchanged (out of reported
scope). Update the adjacent comment (currently describing "the required Claim Verification Table
header") to describe the shape-based match and both known passing formats, so a future reader
does not reintroduce a literal-string check.

**Defect B**: add a propagation step to the `elif [ "$last_skeleton" = "true" ]` branch before its
`EXIT`, sourcing `completion_summary`/`roadmap_items` from `.return-meta.json` exactly as the
Stage 5 tail does:
```bash
completion_json=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "${dispatch_start_ts:-9999999999}" 2>/dev/null)
[ -z "${completion_json:-}" ] && completion_json='{}'
completion_summary=$(echo "$completion_json" | jq -r '.completion_summary // ""' 2>/dev/null) || completion_summary=""
roadmap_items=$(echo "$completion_json" | jq -c '.roadmap_items // []' 2>/dev/null) || roadmap_items="[]"
skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$TASK_TYPE"
```
(Use `[ -z "${completion_json:-}" ] && completion_json='{}'` — never the `"${completion_json:-{}}"`
inline idiom; the file's own existing comment at line 1112-1115 explains why that idiom corrupts
the JSON, and the same hazard applies verbatim to any new call site.)

**Structural consideration (explicitly invited by the task description)**: rather than duplicating
these five lines at a second call site, extract them into one small helper function — e.g.
`hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR"
"${dispatch_start_ts:-9999999999}"` — defined once (a natural place is alongside
`build_hard_mode_prompt_context()` at line 595, the file's one existing inline helper) and called
from BOTH the skeleton-exhaustion branch (Defect B site) and the Stage 5 tail (replacing lines
1107-1119). The Stage 5 tail currently has an optimization the skeleton branch does not need
(reusing `$recover_json` when the recovery branch already ran this cycle, to preserve "only ONE
reader of `.return-meta.json`" per cycle) — if extracted, the helper should accept an optional
pre-computed JSON blob (mirroring `skill_propagate_completion_summary`'s own optional 5th
`session_id` arg pattern) so the Stage 5 call site can still pass its cached `$recover_json` and
avoid a second read, while the skeleton-exhaustion call site simply omits it and gets a fresh read.
This closes the gap for a hypothetical third exit path in one place rather than three.

## Decisions

- Defect A fix stays a single inline regex (no new shared library/pattern file), because only one
  call site exists today — satisfying the task's explicit conditional for when a named matcher is
  preferred.
- Defect B fix reuses `orchestrate-recover-outcome.sh` + `skill_propagate_completion_summary`
  exactly as the Stage 5 tail already does, rather than inventing a second recovery mechanism —
  preserving the "single reader of `.return-meta.json`" and "single writer of
  `completion_summary`/`roadmap_items`" invariants already documented in this file and in
  `scripts/skill-base.sh`.
- The `orchestrate-recover-outcome.sh` doc/code mismatch on non-success-branch
  `completion_summary`/`roadmap_items` values (found during Defect B investigation) is
  out-of-scope for this task's FILE SCOPE (`skill-orchestrate-hard/SKILL.md` only) and does not
  affect the fix's correctness, since the skeleton-exhaustion branch's relevant dispatch status is
  always `implemented` (the `recovered=true` path, which IS correctly populated). Recorded here
  for a possible separate follow-up task rather than folded into this one.

## Risks & Mitigations

- **Risk**: a future adversarial-verification table format that reorders columns (source/
  counterexample BEFORE claim) would not match the new regex. **Mitigation**: not addressed here
  since no such format has been observed or specified; the canonical agent contract
  (`general-research-hard-agent.md`) fixes claim-before-source/counterexample ordering, so this is
  speculative, not a current gap.
- **Risk**: extracting a shared helper touches the existing Stage 5 tail's five lines as well as
  adding new code, widening the diff. **Mitigation**: this is optional per the task's "Consider
  whether..." framing; a minimally-scoped alternative (duplicate the five lines verbatim at the
  skeleton-exhaustion site, matching the Stage 5 tail exactly) is also acceptable and lower-risk if
  the planner prefers to minimize touched lines. Either satisfies the VERIFICATION BAR.
- **Risk**: `bash -n` cannot validate the SKILL.md's fenced bash blocks as a whole file, since they
  interleave literal shell with non-shell "Agent tool:" pseudo-blocks and an `EXIT (...)`
  pseudo-statement. **Mitigation**: verification should extract just the shell-only statements
  being added/changed (as done in this report's Appendix) rather than running `bash -n` over an
  entire fenced block — consistent with how the file already mixes idioms.

## Context Extension Recommendations

None — this task type is `meta` and its target file already documents the relevant patterns
(`orchestrate-recover-outcome.sh` header, `skill_propagate_completion_summary`'s own header
comment, and the `PHASE_HEADING_ERE` shared-matcher precedent at line 512-524) sufficiently for
implementation.

## Appendix

**Search queries / commands used**:
- `grep -n "| Claim | Source/Counterexample\|grep -q\|Stage 4\|researched)\|skeleton\|skill_propagate_completion_summary\|completion_summary\|roadmap_items" SKILL.md`
- `grep -rln "completion_data" agent-system/extensions/core/`
- `grep -rn "Claim | Source\|Adversarial Self-Verification\|Claim Verification Table" agent-system/extensions/core/`
- `grep -n "dispatch_start_ts" SKILL.md`
- Regex fixture test against GNU grep 3.12 (`/run/current-system/sw/bin/grep`), three fixtures
  (canonical header, observed variant, unrelated table) — see Findings, Defect A.
- `bash -n` against an isolated extraction of the proposed Defect B shell addition (function-wrapped
  to satisfy `bash -n`'s single-file requirement) — passed with no syntax errors.

**Key files referenced**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (lines 373-482 Stage 4
  `researched` H4 gate; lines 487-591 Stage 4 per-phase dispatch + skeleton-exhaustion; lines
  1060-1162 Stage 5 shared postflight tail)
- `agent-system/extensions/core/scripts/skill-base.sh` (lines 435-489,
  `skill_propagate_completion_summary`)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (full file, especially the
  `emit` calls per branch and the `completion_summary`/`roadmap_items` field extraction)
- `agent-system/extensions/core/agents/general-research-hard-agent.md` (lines 220-268, Stage 4.5
  Adversarial Self-Verification, canonical table header)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (lines 338-460,
  Stage 5 wrap-up + Stage 7 metadata, confirms `completion_data`/`completion_summary` on every
  `implemented`-status dispatch including skeleton dispatches)
