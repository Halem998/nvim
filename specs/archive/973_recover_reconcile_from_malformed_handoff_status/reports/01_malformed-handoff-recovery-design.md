# Research Report: Task #973

**Task**: 973 - Make reconcile-task-status.sh recover from a malformed handoff status instead of refusing promotion
**Started**: 2026-07-30T01:10:00Z
**Completed**: 2026-07-30T01:30:00Z
**Effort**: small (single-function fix plus one call-site consolidation)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (direct inspection, full read)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (header/contract read)
- `agent-system/extensions/core/scripts/update-task-status.sh` (postflight vocabulary grep)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The asymmetry is real and is confined to a comparison, not a data problem: `handoff_permits_promotion()` (reconcile-task-status.sh:186-195) returns permit (0) when the handoff file is absent, but falls through to a strict `==` comparison — and therefore refuses — when the file exists but carries a `status` value outside the closed six-value vocabulary (`researched|planned|implemented|partial|failed|blocked`, normatively defined in `context/formats/return-metadata-file.md` and cross-referenced by `docs/architecture/handoff-schema.md`).
- Recommended fix: split the "not equal to expected" case into two sub-cases. An on-vocabulary mismatch (e.g. handoff says `blocked` but the phase expects `researched`) is genuine negative evidence and MUST keep refusing, exactly as today. An off-vocabulary value (e.g. `success`, `research_complete`) carries no interpretable claim at all, so it should be treated exactly like a missing handoff — permit, with a loud, non-silent diagnostic naming the offending value and the six legal values.
- This is not a relaxation of the guard's strictness; it is a correction of what the guard is strict *about*. The existing "signal absent → permit" philosophy is already explicitly named in this same file's `artifact_newer_than_last_update()` docstring (lines 214-215) as prior art — the fix is that philosophy applied consistently to the handoff-status signal too.
- A second call site needs the same treatment: the `partial` branch (lines 421-463) hand-rolls its own inline handoff-status check (lines 433-442) instead of calling `handoff_permits_promotion`, and today silently no-ops (no diagnostic, no `record_refused_promotion` call) on any non-`implemented` status, malformed or not. Refactoring it to call the shared helper both fixes its malformed-status wedge risk and removes the duplicate logic, satisfying the task's "apply consistently, not at one call site only" instruction as a natural side effect.
- Scope boundary confirmed: `orchestrate-recover-outcome.sh` is a separate, deliberately narrower `.return-meta.json`-consultation mechanism used only by `skill-orchestrate` Stage 5/MT-4 when a handoff is *missing or stale* — not by this script, and not for malformed-but-present handoffs. Importing that mechanism into `reconcile-task-status.sh` would be scope creep; it is out of scope for this fix and not recommended.

## Context & Scope

Task 973 is the SCRIPT-behavior half of a larger, already-tracked incident (three separate `not_started` tasks own the agent-contract half: whether research agents may write handoffs at all, a Stage 7 final-metadata contract for `cslib-research-agent.md`, and the artifacts array-of-objects propagation to sibling cslib agents). This research is deliberately scoped to `reconcile-task-status.sh` only, per the task description's explicit instruction not to fold this back into or redo that chain's work.

The live incident: `cslib-research-agent` wrote `"status": "success"` to `.orchestrator-handoff.json` (and `"research_complete"` to `.return-meta.json`). Neither value is in the six-value normative vocabulary. Two independent guards rejected it — `skill-orchestrate` Stage 5 Tier C (out of scope here) and `handoff_permits_promotion()` in this script (in scope). Because guard 2 also refused, the documented self-healing recovery path (re-running `/orchestrate` lets reconcile repair the stuck task) did not work, and the task required manual JSON editing to unstick.

## Findings

### Codebase Patterns

**The exact defect (verbatim, `reconcile-task-status.sh:186-195`):**

```bash
handoff_permits_promotion() {
  local expected_status="$1"
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ ! -f "$handoff_file" ]]; then
    return 0
  fi
  local handoff_status
  handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
  [[ "$handoff_status" == "$expected_status" ]]
}
```

Five call sites use this helper directly (`researching` block ~326, `planning` block ~358, `implementing` block ~390, and two `not_started` sub-cases ~475 and ~511). All five, on refusal, call `handoff_status_value()` for logging and then `record_refused_promotion()` (lines 247-261), whose `case` statement maps only `blocked|partial` to an actual state.json write via `update-task-status.sh`; any other value (including `failed`, and — critically — any malformed value) falls to the `*` default, which is a bare no-op comment. So today, a malformed status refusal produces a log line and nothing else: the task's `state.json` status never changes, and since the underlying artifact was already present before this reconcile run, nothing about the situation changes on a re-run either. That is the literal mechanism of "genuinely wedged."

**The un-consolidated sixth call site (`partial` branch, lines 421-463):**

```bash
handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
if [[ -f "$handoff_file" ]]; then
  handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
  if [[ "$handoff_status" != "implemented" ]]; then
    [[ dry-run echo only ]]
    exit 0
  fi
fi
```

This duplicates the missing-handoff-permits / present-handoff-strict-equality shape of `handoff_permits_promotion` inline, but never calls it, and never calls `record_refused_promotion`. Its resting state is `partial`, already a documented legitimate resume-later state, so a malformed status here is less severe than in the other five call sites (it stays `partial`, not stuck emitting a false refusal loop with no state change) — but it is still silently inconsistent: no diagnostic is emitted for a malformed value even in non-dry-run mode, and the task's explicit instruction to check "any other call site" names exactly this kind of duplication.

**The normative vocabulary (from `context/formats/return-metadata-file.md`, restated by `docs/architecture/handoff-schema.md`):**

```
researched | planned | implemented | partial | failed | blocked
```

This is a *closed* six-value enumeration, explicitly distinguished in `return-metadata-file.md` from two other, unrelated status vocabularies that happen to share words (`state.json`'s task-status vocabulary, which uses `"completed"`, and the wezterm notification-mapping vocabulary) — a reminder not to widen the accepted set to include those by conflation.

**Existing "signal absent → permit" precedent already in this file.** `artifact_newer_than_last_update()` (lines 205-241) documents its own fail-open behavior explicitly:

> "Fails OPEN (0) when last_updated is missing or unparseable -- the same 'signal absent -> permit' philosophy handoff_permits_promotion above already uses, so a task predating the last_updated field behaves as it did before."

This is direct textual evidence that the codebase already has, and names, the exact governing principle the fix needs: an *absent or uninterpretable* signal should default toward the same permissive behavior as a genuinely absent one, while a *present, interpretable, negative* signal should not. The current `handoff_permits_promotion` implements "absent" correctly but treats "present-but-uninterpretable" as if it were "present-and-negative" — that is the bug, stated in the codebase's own vocabulary.

**Scope check: `orchestrate-recover-outcome.sh` is a different mechanism at a different call site.** Its header states it is invoked only by `skill-orchestrate` Stage 5 / Stage MT-4 when the handoff is missing or stale (not malformed-but-present), reads only `.return-meta.json`, and accepts only the strict `researched|planned|implemented` success subset — never a fallback for an off-vocabulary value either. It explicitly documents (in its own "Item C decision" comment) a deliberate refusal to add permissive fallbacks for off-schema writes, precisely to keep writer drift visible rather than silently correcting it. Reusing or invoking this script from `reconcile-task-status.sh` would (a) be a different call path than what it's built for, (b) duplicate policy that belongs to a different reader, and (c) contradict its own documented philosophy of narrowness. This confirms the task's own framing that the malformed-handoff fix in this script should be self-contained, not routed through `.return-meta.json` recovery.

### External Resources

Not applicable — this is a pure codebase/internal-documentation research task (shell script + two markdown standards documents already inside the repository); no external library or web research was needed.

### Recommendations

**Chosen design: treat off-vocabulary status as equivalent to a missing handoff, with a loud diagnostic — not a silent relaxation, and not a refuse-with-diagnostic-only approach.**

Rationale for choosing this over the task's other two enumerated options:

1. *Rejected: "refuse promotion but emit a loud, actionable diagnostic."* This preserves today's wedge (state.json status never changes, re-runs hit the identical guard forever) and only adds visibility. It does not solve "the documented recovery path did not work" — the task's stated symptom. A loud diagnostic alone is necessary but not sufficient.
2. *Rejected: "narrow normalization of known-bad synonyms"* (e.g., mapping `"success"` → `"researched"`, `"research_complete"` → `"researched"`). This requires maintaining a synonym table that can never be complete (any future agent-contract typo needs a new entry), silently launders a class of malformed writes as if they were compliant, and — worst — actively risks *false positive* promotion: a synonym table has no way to distinguish "agent wrote `success` meaning researched-successfully" from a hypothetical future "agent wrote `success` meaning some other outcome." Permit-via-fallthrough-to-artifact-evidence (the chosen design) is strictly safer because it defers to the same artifact-presence check every other permit path already defers to, rather than trusting a string match to a hand-maintained table.
3. *Chosen: treat off-vocabulary as equivalent to missing, loudly.* This is exactly as safe as the missing-handoff case (identical code path, not merely "as safe in spirit") — satisfying the task's explicit safety bar — while remaining strict for every on-vocabulary non-matching value (`blocked`, `partial`, `failed`, or a different phase's success value), which continues to refuse exactly as today. It also requires no synonym table, so it needs no maintenance as new malformed values are (inevitably) discovered, and it degrades open by falling back to the SAME evidence (artifact-on-disk) that already governs the no-handoff permissive path, rather than inventing a new trust source.

**Proposed shape of the fix** (for the planner/implementer; not applied by this research task):

```bash
handoff_permits_promotion() {
  local expected_status="$1"
  local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  if [[ ! -f "$handoff_file" ]]; then
    return 0
  fi
  local handoff_status
  handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
  if [[ "$handoff_status" == "$expected_status" ]]; then
    return 0
  fi
  # An on-vocabulary but non-matching status (blocked/partial/failed/a different phase's
  # success value) is genuine negative evidence -- refuse, exactly as before.
  case "$handoff_status" in
    researched|planned|implemented|partial|failed|blocked)
      return 1
      ;;
    *)
      # Off-vocabulary: this value makes no interpretable claim about outcome at all (unlike
      # blocked/partial/failed above), so it carries strictly less information than a genuine
      # refusal signal -- exactly the missing-handoff case this function already permits.
      # Treating it as MORE suspicious than a missing handoff (as the old bare `==` fallthrough
      # did) is backwards: see the header note and the recover_reconcile_from_malformed_handoff_status
      # standalone fix. Fall through to permit, deferring to the same artifact-on-disk evidence
      # the missing-handoff branch above already relies on. Do NOT re-tighten this by reflex --
      # a synonym table or blanket refusal were both considered and rejected (see research
      # report for this fix).
      echo "[reconcile] WARNING: task ${task_number:-?} handoff status '$handoff_status' is not in the normative vocabulary (researched|planned|implemented|partial|failed|blocked) -- treating as if the handoff were absent (permitting promotion on artifact evidence alone)" >&2
      return 0
      ;;
  esac
}
```

`handoff_status_value()` itself needs no change — it already just reads and returns the raw string, and the existing call sites already log it in their refusal messages; the malformed case now simply never reaches those refusal messages, and instead gets its own WARNING line above.

**Sixth call site consolidation:** replace the `partial` branch's inline duplicate (lines 433-442) with a call to `handoff_permits_promotion "implemented"`, following the same pattern the other five branches already use (including the `handoff_status_value()` + refusal-log + `record_refused_promotion` triad on refusal). This is not optional scope creep — the task explicitly asks for consistent semantics across "any other call site," and this is the only other site reading `.status`. The behavior change here is: (a) malformed values now get the same loud diagnostic and fall-through-to-permit as the other five sites (fixing an identical, if less severe, wedge risk in this branch too), and (b) on-vocabulary non-`implemented` values (e.g. a handoff that legitimately says `blocked`) now get a logged refusal + `record_refused_promotion` call instead of a silent no-op — bringing this branch's diagnostics up to parity with the other five rather than leaving it as the one under-instrumented site.

## Decisions

- **Off-vocabulary handoff status is treated as equivalent to a missing handoff (permit, deferring to artifact evidence), not as a refusal, and not as a normalized synonym.** Recorded rationale: it carries strictly less information than an on-vocabulary refusal signal, so treating it as more suspicious than "no handoff at all" was the actual defect.
- **On-vocabulary non-matching statuses continue to refuse exactly as today.** No relaxation for `blocked`/`partial`/`failed`/cross-phase success values — the guard's deliberate strictness for genuinely interpretable negative signals is preserved.
- **The diagnostic is mandatory, not optional**, and must name both the offending value and the full six-value legal set, per the task's verification bar.
- **A synonym-normalization table is explicitly rejected** as a design direction — it cannot be complete, requires ongoing maintenance, and its imagined safety is illusory next to plain fall-through-to-artifact-evidence.
- **`orchestrate-recover-outcome.sh` is out of scope** for this fix; it is a different, narrower mechanism serving a different call site (missing/stale handoff, not malformed-but-present) with its own documented policy against permissive fallbacks. Do not route this fix through it.
- **The `partial` branch's inline duplicate must be consolidated into `handoff_permits_promotion`**, both to fix its own (lesser) instance of the same wedge risk and to satisfy the task's consistency requirement across call sites.

## Risks & Mitigations

- **Risk**: treating a malformed status as permit could theoretically promote a task whose agent actually failed but wrote a garbled status instead of `failed`. **Mitigation**: this risk already exists identically today for the *missing-handoff* case (a crashed agent that never wrote a handoff at all is already permitted through on artifact evidence alone) — the fix does not introduce a new risk, it extends an already-accepted one to a case that is strictly better-evidenced (an artifact was actually found on disk in every branch that calls this guard) than the missing-handoff case it mirrors.
- **Risk**: a future reader might see the permissive branch and "simplify" it back to strict refusal, re-introducing the wedge. **Mitigation**: the recommended code includes an explicit "Do NOT re-tighten this by reflex" comment naming the rejected alternatives, per the task's explicit requirement that the rationale be recorded in the script itself.
- **Risk**: consolidating the `partial` branch changes its behavior for on-vocabulary non-`implemented` values (previously silent no-op, now a logged refusal + `record_refused_promotion` call). **Mitigation**: this is a deliberate, called-out behavior change, not a side effect discovered late — `record_refused_promotion` already only writes state for `blocked`/`partial`, and writing `partial` when the task is already `partial` is idempotent; `record_refused_promotion` calling `update-task-status.sh postflight <task> partial` on an already-`partial` task is a no-op state transition, not a regression.

## Context Extension Recommendations

None — the relevant standards (`context/formats/return-metadata-file.md`'s normative vocabulary table, `docs/architecture/handoff-schema.md`'s cross-reference) are already documented and already correctly describe the six-value closed set this fix depends on. No gap was found in existing context documentation; the gap was purely in this one script's handling of a value outside that documented set.

## Appendix

- Direct read of `agent-system/extensions/core/scripts/reconcile-task-status.sh` (full file, 547 lines).
- Grep across the same file for `handoff_permits_promotion|handoff_status_value|orchestrator-handoff.json|handoff_status=` to enumerate all six call sites (five via the helper, one inline duplicate).
- Read of `agent-system/extensions/core/docs/architecture/handoff-schema.md` (full file) for the schema, vocabulary cross-reference, and Outcome Channels section distinguishing this script's self-healing role from `orchestrate-recover-outcome.sh`'s handoff-missing/stale fallback role.
- Grep of `agent-system/extensions/core/context/formats/return-metadata-file.md` for the normative status vocabulary table and its explicit "three overlapping-but-distinct vocabularies" warning.
- Header read of `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` to confirm its scope and philosophy (no permissive off-schema fallback, by its own documented "Item C decision").
- Grep of `agent-system/extensions/core/scripts/update-task-status.sh` to confirm the `postflight` target-status vocabulary (`research|plan|implement|pr_ready|partial|blocked`) mapping to state.json's `researched|planned|implemented|partial|blocked` values, corroborating the six-value normative set used throughout.
