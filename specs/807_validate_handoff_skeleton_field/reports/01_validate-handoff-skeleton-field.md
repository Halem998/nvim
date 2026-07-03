# Research Report: Task #807

**Task**: 807 - Add skeleton-field validation to validate-handoff.sh
**Started**: 2026-07-03T16:33:31Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: 1-3 hours
**Dependencies**: 778 (parent task; schema origin)
**Sources/Inputs**: Codebase (`.claude/scripts/validate-handoff.sh`, `.claude/context/contracts/wrap-up.md`, `.claude/context/contracts/anti-analysis.md`, `.claude/tests/`, task 778/677 artifacts)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `.claude/scripts/validate-handoff.sh` (217 lines, single copy, **no `extensions/core` mirror
  exists** — confirmed via `find`/`grep`, so no lockstep concern) has zero `skeleton` awareness.
  Task 778 (already `[COMPLETED]`) explicitly recorded this as an out-of-scope downstream note
  (Phase 5, "NOTE (downstream)" item 2) and even ran a sample skeleton handoff through the
  unmodified script to *confirm* it silently passes — proving the gap.
- Fix is confined to one script, one region (Check 3, lines 108–124) plus one new early-read
  block and one `--help` text update. No other file references `validate-handoff.sh` except
  itself and task-artifact prose (`specs/state.json`, `TODO.md`, task 677/778 artifacts) — it is
  invoked ad hoc via `bash .claude/scripts/validate-handoff.sh <file>`, not from another script.
- **No test harness exists** for `validate-handoff.sh`. `.claude/tests/` contains exactly one
  file, `test-command-route-skill.sh`, which tests a different script
  (`command-route-skill.sh`) using a `run_test()` helper + fixture pattern. That pattern is the
  right template to imitate for a new `.claude/tests/test-validate-handoff.sh`.
- Recommended approach: read `status` and `skeleton` once, early (right after JSON-parsability
  Check 1); branch Check 3 (sorry_inventory) into a skeleton-mode path (strict) vs.
  standard-mode path (existing warn-only behavior, byte-for-byte unchanged); add an explicit
  status/skeleton invalid-combination check per the wrap-up.md table.

## Context & Scope

Task 778 added the `skeleton` boolean and the extended 7-field `sorry_inventory` schema
(`{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`) to the H9
handoff contract in `.claude/context/contracts/wrap-up.md`, plus the 5-condition strategic-sorry
test in `.claude/context/contracts/anti-analysis.md`. It deliberately did NOT touch
`validate-handoff.sh` (Non-Goal, confirmed in
`specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/plans/01_strategic-sorry-skeleton-policy.md`
line 85: *"Do NOT modify `validate-handoff.sh` or `lint-contract-compliance.sh`"*). Task 807 is
the flagged follow-up that closes that gap. Scope is limited to `validate-handoff.sh` structural
validation logic and (if a harness exists — it does not — extending it, otherwise optionally
creating a minimal one).

## Findings

### Current `validate-handoff.sh` structure (exact line anchors, current 217-line file)

| Lines | Section | Behavior |
|-------|---------|----------|
| 1–24 | Header/colors | Contract reference comment already points at `wrap-up.md` (H9), line 8 |
| 26–56 | Arg parsing + `--help` | `--help` text (lines 31–45) lists required/optional fields; **no mention of `skeleton`** |
| 87–95 | **Check 1**: JSON parsability | `jq empty` |
| 97–106 | **Check 2**: required fields | `status`, `phases_completed`, `phases_total`, `blockers` |
| **108–115** | **Check 3**: `sorry_inventory` (warn-only) | `sorry_inventory=$(jq -r ".sorry_inventory // \"__MISSING__\"" ...)`; warns if absent, passes if present — **no field-level inspection, no `skeleton` read at all (this is the "0 skeleton mentions" gap)** |
| 117–124 | continuation_path/context check | warn if both absent |
| **126–141** | **Check 4**: status value validation | `status=$(jq -r ".status // \"\"" ...)` (this is where `status` is first read — AFTER Check 3, which is why Check 3 cannot currently branch on status) |
| 143–160 | Check 5: status/continuation consistency | for `partial`/`blocked` |
| 162–174 | Check 6: phase count consistency | for `partial` only |
| 176–196 | Check 7: blockers array structure | per-entry field check pattern to imitate (`has_phase`/`has_target`, `invalid_blockers` counter) — **this is the best in-file precedent for how to write the new per-entry sorry_inventory checks** |
| 198–217 | Summary + exit codes | `FAILED>0` → exit 1; `WARNINGS>0` → exit 0 with warning banner; else exit 0 |

Key existing patterns worth reusing verbatim:
- The "count with `2>/dev/null || echo 0` fallback" pattern at line 177
  (`blockers_count=$(jq -r ".blockers | length" "$HANDOFF_FILE" 2>/dev/null || echo "0")`) is the
  safe way to count `sorry_inventory` too — `null | length` evaluates to `0` in jq, so this
  works even when the field is entirely absent, without tripping `set -euo pipefail`.
- The "per-entry field-presence loop with an `invalid_N` counter" pattern at lines 182–188 is the
  direct template for validating each `sorry_inventory` entry's `strategic`/`assumption`/
  `why_deferred`/`follow_up_task` fields.

### Canonical schema to validate against (`.claude/context/contracts/wrap-up.md`)

- **Handoff schema** (lines 12–35): `status ∈ {implemented, partial, blocked}` (no 4th enum
  value — task 778 deliberately avoided adding one), `skeleton: boolean` (default `false`).
- **Field semantics** (lines 37–55): `skeleton: true` is valid **only** when `status ==
  "implemented"`; MUST be `false`/absent when `status` is `partial`/`blocked`.
  `sorry_inventory` entry schema is exactly 7 fields: `file, line, statement, strategic,
  assumption, why_deferred, follow_up_task`. `follow_up_task` is **REQUIRED (non-null) when
  `strategic: true`** — "an untracked strategic sorry is a defect, not a skeleton success."
- **status/skeleton interaction table** (lines 57–63):

  | `status` | `skeleton` | Meaning |
  |----------|------------|---------|
  | `implemented` | `false`/absent | Fully complete (unchanged baseline) |
  | `implemented` | `true` | Build-green, only tracked strategic sorries — "implemented (skeleton)" |
  | `partial`/`blocked` | `true` | **Invalid combination** |

- The 5-condition strategic-sorry test lives in `.claude/context/contracts/anti-analysis.md`
  lines 61–83; condition 4 ("Tracked") is the one `validate-handoff.sh` can mechanically check:
  *"recorded in the handoff `sorry_inventory`... with `strategic: true` and a non-null
  `follow_up_task`. An undocumented or untracked sorry is never strategic."* Conditions 1
  (deliberate boundary), 2 (tightly scoped), and 5 (build-green/syntax-valid) are not
  mechanically verifiable from the JSON alone and are out of scope for a jq/bash validator —
  the report explicitly scopes the fix to what is checkable: **non-empty `sorry_inventory`,
  presence/non-nullness of the 7 fields, and non-null `follow_up_task` + non-empty `assumption`/
  `why_deferred` for every `strategic: true` entry.**

### Real-world handoff sample confirming schema shape

`specs/772_hardmode_orchestrator_pure_dispatcher/.orchestrator-handoff.json` (status:
`implemented`, `skeleton: false`, empty `sorry_inventory`) confirms the schema is used verbatim
in production, plus extra practical fields (`summary`, `artifacts`, `next_action_hint`) beyond
the minimal contract — the validator should NOT reject unknown extra top-level fields (it
doesn't today; no change needed there).

Task 778's own testing note (plan lines 313–317, 329–336) states a *sample skeleton handoff was
run through the unmodified `validate-handoff.sh` and passed* — i.e., the confirmed defect this
task fixes: `skeleton: true` with an under-specified `sorry_inventory` currently produces zero
failures.

### Test harness status

- `find`/`grep` confirm **no test harness references `validate-handoff.sh`**. The only file
  under `.claude/tests/` is `test-command-route-skill.sh` (tests `command-route-skill.sh`, an
  unrelated routing script).
- `test-command-route-skill.sh`'s pattern is directly reusable: a `run_test()` bash function,
  `PASS`/`FAIL` counters, `FAILURES` accumulator string, fixture-driven assertions, `set -euo
  pipefail`-safe subshell execution. For `validate-handoff.sh` the fixture unit would be a
  temp JSON file (via `mktemp`) rather than sourcing with positional args, since
  `validate-handoff.sh` takes a file path argument and communicates via exit code + stdout
  rather than an exported shell variable.
- Recommendation: create `.claude/tests/test-validate-handoff.sh` with fixtures for (a) standard
  handoff (skeleton absent) — passes unchanged; (b) skeleton:true well-formed — passes; (c)
  skeleton:true with empty `sorry_inventory` — fails; (d) skeleton:true with a `strategic:true`
  entry missing `follow_up_task` — fails; (e) skeleton:true + status:"partial" — fails (invalid
  combination). This is optional per task framing ("Add/extend test coverage **if** a test
  harness exists") but strongly recommended as a natural byproduct of this task's own five
  numbered conditions, mirrored 1:1 as five fixtures.

### Mirror/lockstep check

`grep -rln "validate-handoff" .claude` and `find .claude -iname "validate-handoff.sh"` both
return exactly one path: `.claude/scripts/validate-handoff.sh`. No `extensions/core` mirror
exists (unlike `skill-implementer-hard/SKILL.md` and
`general-implementation-hard-agent.md`, which task 778 kept in dual-copy lockstep). **No
lockstep concern for this task** — single-copy fix only.

## Recommendations (exact code to add)

### 1. Early status/skeleton read (new block, insert after Check 1, i.e. after current line 95,
before current line 97 "Check 2")

```bash
# --- Read status and skeleton early (needed for skeleton-aware Check 3 below) ---
status=$(jq -r ".status // \"\"" "$HANDOFF_FILE" 2>/dev/null)
skeleton=$(jq -r ".skeleton // false" "$HANDOFF_FILE" 2>/dev/null)
```

Then the pre-existing `status=$(jq -r ".status // \"\"" "$HANDOFF_FILE" 2>/dev/null)` inside
current Check 4 (current line 127) becomes a redundant re-read of the same value — harmless to
leave (idempotent) but can be deleted for cleanliness; not required for correctness.

### 2. Replace Check 3 (current lines 108–115) with a skeleton-aware branch

```bash
# --- Check 3: sorry_inventory validation (skeleton-aware) ---
sorry_inventory_present=true
if [[ "$(jq -r ".sorry_inventory // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)" == "__MISSING__" ]]; then
  sorry_inventory_present=false
fi
sorry_count=$(jq -r ".sorry_inventory | length" "$HANDOFF_FILE" 2>/dev/null || echo "0")

if [[ "$skeleton" == "true" ]]; then
  # --- status/skeleton combination (wrap-up.md interaction table) ---
  if [[ "$status" != "implemented" ]]; then
    log_fail "Invalid status/skeleton combination: skeleton=true requires status=='implemented' (found status='$status'); see wrap-up.md status/skeleton interaction table"
  else
    log_pass "skeleton=true paired with status='implemented' (valid combination)"
  fi

  # --- skeleton mode requires a non-empty sorry_inventory ---
  if [[ "$sorry_inventory_present" == "false" ]] || [[ "$sorry_count" -eq 0 ]]; then
    log_fail "skeleton=true requires non-empty sorry_inventory enumerating every strategic sorry"
  else
    log_pass "sorry_inventory present with $sorry_count entry(s) (skeleton mode)"

    invalid_entries=0
    strategic_count=0
    for i in $(seq 0 $((sorry_count - 1))); do
      strategic=$(jq -r ".sorry_inventory[$i].strategic // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
      if [[ "$strategic" == "true" ]]; then
        strategic_count=$((strategic_count + 1))
        assumption=$(jq -r ".sorry_inventory[$i].assumption // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        why_deferred=$(jq -r ".sorry_inventory[$i].why_deferred // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        follow_up_task=$(jq -r ".sorry_inventory[$i].follow_up_task // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        entry_bad=false
        if [[ -z "$assumption" ]] || [[ "$assumption" == "__MISSING__" ]] || [[ "$assumption" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but assumption is empty/missing"
          entry_bad=true
        fi
        if [[ -z "$why_deferred" ]] || [[ "$why_deferred" == "__MISSING__" ]] || [[ "$why_deferred" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but why_deferred is empty/missing"
          entry_bad=true
        fi
        if [[ "$follow_up_task" == "__MISSING__" ]] || [[ "$follow_up_task" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but follow_up_task is null/missing (untracked strategic sorry -- relaxed zero-debt must stay tracked)"
          entry_bad=true
        fi
        if [[ "$entry_bad" == "true" ]]; then
          invalid_entries=$((invalid_entries + 1))
        fi
      fi
    done

    if [[ "$strategic_count" -eq 0 ]]; then
      log_fail "skeleton=true but no sorry_inventory entry has strategic:true (skeleton dispatch requires at least one tracked strategic sorry)"
    elif [[ "$invalid_entries" -eq 0 ]]; then
      log_pass "All $strategic_count strategic sorry entry(s) are fully tracked (assumption, why_deferred, follow_up_task all present)"
    fi
  fi
else
  # --- STANDARD mode (skeleton absent/false): existing behavior, byte-for-byte unchanged ---
  if [[ "$sorry_inventory_present" == "false" ]]; then
    log_warn "Optional field absent: sorry_inventory (H9 contract field; use [] for empty)"
  else
    log_pass "Optional field present: sorry_inventory"
  fi
fi
```

This satisfies all four task requirements: (1) `skeleton:true` is read and branched on; (2)
non-empty `sorry_inventory` is required in skeleton mode, and every entry is inspected; (3) each
`strategic:true` entry is checked for non-empty `assumption`/`why_deferred` and non-null
`follow_up_task`; (4) an untracked strategic sorry (`entry_bad`) or a skeleton with zero
strategic entries both trigger `log_fail`, keeping relaxed zero-debt visible (loud shell output)
and enforceably tracked (non-zero exit code via the existing `FAILED>0 → exit 1` summary logic
at current lines 208–210, unchanged).

### 3. `--help` text update (current lines 31–45)

Add a line documenting the skeleton branch, e.g. after the existing "Optional fields:" line:
```
echo "  skeleton=true additionally requires: non-empty sorry_inventory; every strategic:true"
echo "  entry must have non-empty assumption/why_deferred and non-null follow_up_task"
```
and add `skeleton` to the "Required fields"/"Optional fields" listing as conditionally-required.

### 4. STANDARD-mode regression guard

Because the skeleton branch is `if [[ "$skeleton" == "true" ]] ... else <exact prior Check 3
logic> fi`, any handoff with `skeleton` absent or `false` takes the untouched `else` path —
this is the mechanism that keeps STANDARD-mode validation byte-identical to current behavior, as
required by the task ("Keep STANDARD-mode validation unchanged").

## Decisions

- Validate only the mechanically-checkable subset of the anti-analysis.md 5-condition test
  (condition 4, "Tracked") — conditions 1/2/5 require semantic/build knowledge the shell
  validator cannot access; this is a deliberate scope boundary, not an oversight.
- Do not introduce a 4th `status` enum value or otherwise touch the schema — pure consumer-side
  validation logic, matching task 778's own precedent of minimizing blast radius.
- Reuse existing script idioms (`length`-with-fallback, per-entry counters à la Check 7) rather
  than introducing new jq/bash patterns, for internal consistency and easier review.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `set -euo pipefail` could abort on a malformed `sorry_inventory` entry (e.g., a bare string instead of an object) inside per-entry `jq` calls used in `var=$(...)` assignments | Existing script already has this same latent risk for other fields (e.g. Check 2's field loop); not a regression introduced by this change, and consistent with current script conventions. If desired, wrap the per-entry jq calls with `|| echo "__MISSING__"` for extra safety, matching the `blockers_count` fallback pattern already in the file. |
| New checks could break existing production handoffs that predate task 778 (no `skeleton` field at all) | The `else` branch (skeleton absent/false) is untouched from current behavior — no regression for legacy handoffs. |
| No test harness to catch a regression before deployment | Recommended new `.claude/tests/test-validate-handoff.sh` (five fixtures matching the five task-807 requirements) — optional but strongly recommended; can be Phase N+1 if the planner wants it non-blocking. |

## Context Extension Recommendations

- **Topic**: validate-handoff.sh test coverage
- **Gap**: No `.claude/tests/` file exercises `validate-handoff.sh` at all (only
  `command-route-skill.sh` has coverage), despite it being a hard-mode contract-compliance gate.
- **Recommendation**: Create `.claude/tests/test-validate-handoff.sh` (see "Test harness status"
  above) as part of this task's implementation, or as an immediate follow-up if the planner
  wants to keep this task's diff minimal.

## Appendix

- Read: `.claude/scripts/validate-handoff.sh` (full, 217 lines)
- Read: `.claude/context/contracts/wrap-up.md` (full, 129 lines)
- Read: `.claude/context/contracts/anti-analysis.md` (lines 40–90, Sub-Sorry Policy section)
- Read: `specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/plans/01_strategic-sorry-skeleton-policy.md` (full)
- Read: `.claude/tests/test-command-route-skill.sh` (lines 1–60, pattern reference)
- Grep: `grep -rln "validate-handoff" .claude` → only `.claude/scripts/validate-handoff.sh`
  itself (plus prose mentions in `specs/state.json`, `specs/TODO.md`, task 677/778 artifacts —
  no code-level consumer)
- Grep: `find .claude -iname "validate-handoff.sh"` → single result, no `extensions/core` mirror
- Sample handoff inspected: `specs/772_hardmode_orchestrator_pure_dispatcher/.orchestrator-handoff.json`
  (confirms production schema shape with `skeleton: false`, empty `sorry_inventory`)
