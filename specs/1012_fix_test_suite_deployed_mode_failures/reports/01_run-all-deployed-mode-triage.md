# Research Report: Fix test suite deployed-mode failures

**Task**: Fix run-all.sh deployed-mode failures: REPO_ROOT depth derivation and further suites
**Started**: 2026-08-10T16:20:00Z
**Completed**: 2026-08-10T16:29:00Z
**Effort**: Medium (re-measurement + per-suite root-cause tracing, no code changes)
**Dependencies**: None
**Sources/Inputs**: Live `bash .claude/scripts/tests/run-all.sh` runs (2 full, several isolated), source reads of `agent-system/extensions/core/scripts/tests/*.sh` and `agent-system/extensions/core/scripts/check-extension-docs.sh`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Re-measured (live, deployed mode): **26 passed, 8 failed, 0 skipped, 34 total**, stable across
  two independent full sequential runs. This supersedes the inherited "25 passed, 8 failed, 33
  total" count — both the pass/fail split and the total suite count differ.
- The REPO_ROOT depth defect described in the delegation context is real and confirmed, but its
  blast radius is **5 suites, not 2**: `test-skill-base-lifecycle.sh` and
  `test-update-task-status.sh` (previously confirmed) plus three newly confirmed victims —
  `test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`, and
  `test-resume-scan-nonconformance.sh` — all fail with the identical signature (paths resolving
  under `/home/benjamin` instead of the real repo root).
- `test-index-entries-schema.sh`'s single failure ("Rule U did not fire on a 61-line
  EXTENSION.md") is **unrelated to REPO_ROOT** — it is a test-fixture bug: the fixture's
  `manifest.json` never declares `merge_targets.claudemd.source`, so `check_extension_md_length`'s
  manifest-authoritative guard always short-circuits before the line-count check runs. Root
  cause fully traced to source.
- `test-common-lib.sh`'s single failure is confirmed to be exactly the opencode session-id
  duplication finding named out of scope by the delegation context — no further action needed
  here.
- `test-lint-state-writer-boundary.sh`, which the delegation context reported as 7/8, measured
  **8/8 green** in 3 isolated runs and both full sequential runs. Treat the "7/8" report as
  stale/superseded; no fix is needed unless it recurs with fresh evidence.
- **New finding, not in the delegation's original 8**: `test-four-tier-conflict.sh` fails
  reproducibly (2/2) when run as part of the full `run-all.sh` sequence, but passes reproducibly
  (4/4) in isolation. This is an order/timing-dependent flake unrelated to the REPO_ROOT defect
  class (it never touches REPO_ROOT-derived deploy paths) and its root cause is not yet
  diagnosed — flagged for dedicated follow-up, not folded into the REPO_ROOT fix.

## Context & Scope

The task's acceptance bar is: `run-all.sh` reports 0 failures, OR every residual failure has a
written, evidenced justification. This report re-measures the suite from scratch (not inheriting
prior counts), confirms the named root cause's actual scope, and individually triages each of the
six previously-"unconfirmed" failures plus one failure discovered during re-measurement that was
not in the original list.

Per the delegation's explicit instruction, `test-common-lib.sh`'s failure (the opencode
session-id duplication) is investigated only far enough to confirm the overlap and is treated as
out of scope for edits under this task.

## Findings

### Re-measurement methodology

Ran `bash .claude/scripts/tests/run-all.sh` twice, full and sequential, capturing combined
stdout+stderr each time. Both runs produced an identical pass/fail set:

```
26 passed, 8 failed, 0 skipped, 34 total
```

Failing suites (both runs, identical set):
`test-common-lib.sh`, `test-index-entries-schema.sh`, `test-loop-guard-staleness.sh`,
`test-reconcile-handoff-status.sh`, `test-resume-scan-nonconformance.sh`,
`test-skill-base-lifecycle.sh`, `test-update-task-status.sh`, `test-four-tier-conflict.sh`.

This differs from the delegation's inherited count in three ways: the total suite count (34 vs.
33), `test-lint-state-writer-boundary.sh` is NOT in the current failing set (delegation reported
7/8), and `test-four-tier-conflict.sh` IS in the current failing set (delegation did not mention
it). All three points were independently verified (see below), not assumed.

### REPO_ROOT depth defect — confirmed scope is 5 suites

The defect: `SCRIPT_DIR/../../../../..` (5 levels up) correctly reaches the repo root only when
a test file executes from its **source-store** location
(`agent-system/extensions/core/scripts/tests/`, 5 levels below repo root). From the **deployed**
location (`.claude/scripts/tests/`, only 3 levels below repo root), the same 5-level climb
overshoots by 2 levels and lands at `$HOME` (`/home/benjamin`).

Confirmed on this machine: `/home/benjamin/.claude` exists (the real global Claude Code state
directory) but `/home/benjamin/.claude/scripts/` does **not** exist, and `/home/benjamin/agent-system`
does not exist at all. So any `$REPO_ROOT/.claude/scripts/...` or `$REPO_ROOT/agent-system/...`
reference built from the wrongly-resolved REPO_ROOT points at a path that can never exist,
regardless of deploy state — while the correct repo-root-relative path was confirmed to exist in
every case checked.

**Grep across the source store found 18 test files using the literal 5-level pattern**, but only
5 actually fail in deployed mode:

| Suite | Fails? | Why |
|---|---|---|
| `test-skill-base-lifecycle.sh` | Yes (delegation-confirmed) | Requires the genuine deployed `.claude/scripts/` tree (copies `state-write.sh`, `task-lock.sh`, `deploy-root-guard.sh`, `lib/*.sh` from it into a fixture); no source-store fallback by design, since the point is to exercise the deployed lifecycle chain |
| `test-update-task-status.sh` | Yes (delegation-confirmed) | Same shape as above |
| `test-loop-guard-staleness.sh` | **Yes (newly confirmed)** | `REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`, no fallback candidate — file exists at the correct repo-root path (verified), never at `$HOME` |
| `test-reconcile-handoff-status.sh` | **Yes (newly confirmed)** | Candidate list is `["$REPO_ROOT/agent-system/extensions/core/scripts", "$REPO_ROOT/.claude/scripts"]` — both derived from the same wrong REPO_ROOT, so the fallback never actually diversifies; deployed `reconcile-task-status.sh` exists at the correct location (verified) |
| `test-resume-scan-nonconformance.sh` | **Yes (newly confirmed)** | Four required files (`skill-implementer-hard/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `skill-lean-implementation-hard/SKILL.md`, `update-task-status.sh`), all source-store paths, no fallback — all four confirmed to exist at the correct repo-root-relative location |
| 13 others (e.g. `test-validate-handoff.sh`, `test-errors-append.sh`, `test-corroborate-phase-counts.sh`, `test-handoff-reader-parity.sh`, `test-index-entries-schema.sh`, `test-lint-state-writer-boundary.sh`, `test-lint-postflight-boundary.sh`, `test-postflight-marker-schema.sh`, `test-status-vocabulary.sh`, `test-phase-heading-patterns.sh`, `test-validate-state.sh`, `test-deploy-propagation.sh`, `test-double-loading-check.sh`) | No | Each resolves its script-under-test via a `resolve_candidate`/array pattern where **one candidate is `$SCRIPT_DIR/../...`-relative** (always correct, independent of REPO_ROOT), tried either first or as a fallback — confirmed directly for `test-validate-handoff.sh` and `test-errors-append.sh`; the remainder share the identical documented "Structural model" comment referencing this pattern |

These 13 are only **accidentally** safe: they carry the same broken REPO_ROOT literal, masked by
a fallback. A future edit to any of them that adds a new REPO_ROOT-only check (as
`test-skill-base-lifecycle.sh`'s `DEPLOY_SCRIPTS_SRC` check already does) would silently
reproduce the same failure class.

**Proven-good pattern already in-tree** (`test-deploy-propagation.sh`, lines ~44-46):
```bash
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi
```
This resolves correctly from both invocation sites because `git rev-parse --show-toplevel` is
depth-independent; the literal 5-level climb is retained only as a last-resort fallback for a
non-git checkout.

**Recommendation for the plan phase**: adopt this exact pattern in the 5 confirmed-failing
suites at minimum. For durability, consider migrating all 18 occurrences uniformly rather than
patching only the suites that fail loudly today — the fix is small and mechanical, and leaving
13 "accidentally correct" instances in place is a latent recurrence risk for the same defect
class. Do **not** invent a third pattern; the git-rev-parse-with-fallback shape is already
proven and precedented.

### `test-index-entries-schema.sh` — fixture bug, not a REPO_ROOT issue (root cause traced)

The single failure is:
```
[FAIL] Rule U did not fire on a 61-line EXTENSION.md
```

Traced to `check_extension_md_length()` in `agent-system/extensions/core/scripts/check-extension-docs.sh`:

```bash
check_extension_md_length() {
  local ext_path="$1"
  local ext_md="$ext_path/EXTENSION.md"
  local actual
  [[ -f "$ext_md" ]] || return 0
  [[ "$(claudemd_source_for "$ext_path")" == "EXTENSION.md" ]] || return 0
  actual=$(wc -l < "$ext_md")
  ...
}
```

`claudemd_source_for()` reads `.merge_targets.claudemd.source` from the extension's
`manifest.json` — this is a deliberate manifest-authoritative design (see the function's own
rationale comment: an extension whose manifest doesn't declare `EXTENSION.md` as its claudemd
merge source should never be length-checked, since no code path reads that file).

The test's fixture `manifest.json` (built inline in `test-index-entries-schema.sh`) is:
```json
{ "name": "fixture", "version": "0.0.1", "provides": {} }
```
There is no `merge_targets` key at all. So `claudemd_source_for` always returns an empty string,
the guard's `[[ ... == "EXTENSION.md" ]] || return 0` always takes the `return 0` branch, and
Rule U **never executes** for this fixture — regardless of how many lines `EXTENSION.md` has.
The "60-line negative case" assertion passes only vacuously (the rule never ran, not because it
correctly declined to fire at the boundary); the "61-line positive case" assertion fails because
the rule never ran either.

This is a pure test-fixture gap, almost certainly introduced when the manifest-authoritative
resolution was added after the fixture was originally written (the function's own comment notes
"Before this helper existed... hardcoded the filename EXTENSION.md" — implying the fixture predates
this guard). `check-extension-docs.sh` itself needs no change; deployed and source-store copies
are byte-identical (diffed, zero output), ruling out redeploy drift as a factor.

**Fix locus**: `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`'s fixture
`manifest.json` needs a `"merge_targets": {"claudemd": {"source": "EXTENSION.md"}}` key added.

### `test-common-lib.sh` — confirmed out of scope

The single failure:
```
[FAIL] single-source assertion: inline sess_$(date generation found outside lib/common.sh:
  /home/benjamin/.config/nvim/.opencode/scripts/command-gate-in.sh
```
This is exactly the opencode session-id duplication the delegation context named as being fixed
under a separate task's scope. Confirmed by direct inspection of the assertion output — no
further investigation performed here per the delegation's explicit instruction. **No edits to
this suite or `.opencode/scripts/command-gate-in.sh` under this task.**

### `test-lint-state-writer-boundary.sh` — not reproduced, treat as stale

Delegation reported 7/8 for this suite. Measured **8/8 green** across 3 dedicated isolated runs
and both full-sequence `run-all.sh` runs — 5 total green measurements, zero red. No evidence of a
current gap in the new lint. Recommend the plan phase leave this suite untouched and treat the
prior "7/8" report as superseded (consistent with how the delegation itself flagged the earlier
5-suite REPO_ROOT count as superseded).

### `test-four-tier-conflict.sh` — new finding, order-dependent flake, root cause undiagnosed

Not in the delegation's original list of 8. Failed in **both** full `run-all.sh` runs performed
here, with this signature:

```
[INFO] Fixture built at /tmp/four-tier-conflict-test.XXXXXX (dead pid probe resolved to 999999)
[FAIL] 1: Tier-2 resolving case -- ... 
  .../task-lock.sh: line 301: .../.lock/holder.json.tmp: No such file or directory
  ERROR: failed to write holder.json (jq produced empty output)
Results: 10 passed, 1 failed
```

Ran the same suite **in isolation 4 times** — 11/11 passed every time, zero failures. This rules
out a simple deterministic bug in the suite's own logic and points at an order- or
load-dependent interaction specific to running inside the full `run-all.sh` sequence (which is
sequential, not parallel, so this is not a same-process race — more likely PID-recycling
sensitivity in the "dead pid probe" heuristic, or scheduling/timing sensitivity under the
cumulative CPU load of 33 preceding suites). No leftover `/tmp/four-tier-conflict-test.*`
directories were found between runs, ruling out stale-fixture reuse as the cause.

This defect class is **unrelated to the REPO_ROOT issue** — the suite never derives or uses a
REPO_ROOT-based deploy path; it is a pure `task-lock.sh` fixture test. Root cause is not
determined here. **Recommend a dedicated, separately-scoped investigation** (e.g. rerun the full
suite under `bash -x`, or bisect which specific preceding suite(s) leave interfering state) rather
than bundling a guess-fix into the REPO_ROOT remediation phase.

## Decisions

- Treat the delegation's inherited failure counts and named-suite list as superseded by this
  report's live re-measurement (26 passed, 8 failed, 34 total), per the delegation's own
  "measure, don't inherit" instruction.
- Scope the REPO_ROOT fix to (at minimum) the 5 confirmed-failing suites; recommend — but do not
  mandate — extending the fix to all 18 occurrences of the literal pattern for defect-class
  elimination.
- `test-index-entries-schema.sh`'s failure is a fixture-authoring gap, fixed independently of the
  REPO_ROOT work.
- `test-common-lib.sh` is explicitly out of scope; no edits recommended here.
- `test-lint-state-writer-boundary.sh` needs no action; its earlier "7/8" report did not
  reproduce.
- `test-four-tier-conflict.sh` is a newly discovered, order-dependent flake that needs its own
  diagnostic pass before a fix can be written — it should not be silently folded into the
  REPO_ROOT phase, since the evidence shows the two are unrelated defect classes.

## Risks & Mitigations

- **Risk**: migrating all 18 REPO_ROOT occurrences (rather than just the 5 broken ones) touches
  more files than strictly required by the failing-suite count, raising review surface.
  **Mitigation**: the change is mechanical and uses an already-proven in-tree pattern
  (`test-deploy-propagation.sh`); a plan phase can size this as a single small, uniform edit
  across the 18 files with no behavioral risk to the 13 currently-passing suites (their
  `$SCRIPT_DIR/../...` fallback candidates are untouched by the REPO_ROOT line's own correctness).
- **Risk**: `test-four-tier-conflict.sh`'s flake may not be reproducible during a single
  diagnostic session if it depends on the full 34-suite sequence's cumulative timing.
  **Mitigation**: budget the follow-up as "investigate and document," accepting that the
  acceptance bar's "written, evidenced justification" branch may be the realistic outcome for
  this one suite if root cause proves elusive, rather than a guaranteed fix.
- **Risk**: acting on `test-common-lib.sh`'s failure here would collide with the separate
  in-flight task already scoped to fix the opencode session-id duplication.
  **Mitigation**: confirmed the overlap explicitly (this report) and left it untouched; the
  implementation phase for this task should do the same.

## Context Extension Recommendations

None — this is a self-contained diagnostic task; no gaps in `.claude/context/` documentation were
identified during this research.

## Appendix

Commands used (representative):
```bash
bash .claude/scripts/tests/run-all.sh   # x2 full runs, captured combined stdout+stderr
bash .claude/scripts/tests/test-lint-state-writer-boundary.sh   # x3 isolated
bash .claude/scripts/test-four-tier-conflict.sh                 # x4 isolated
grep -rn 'cd "\$SCRIPT_DIR/\.\./\.\./\.\./\.\./\.\." && pwd' agent-system/extensions/core/scripts/tests/
grep -rln 'common_repo_root' agent-system/extensions/core/scripts/tests/
```
Key source files read: `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule U,
`claudemd_source_for`), `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`,
`test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`,
`test-resume-scan-nonconformance.sh`, `test-validate-handoff.sh`, `test-errors-append.sh`,
`test-index-entries-schema.sh`, `test-deploy-propagation.sh`.
