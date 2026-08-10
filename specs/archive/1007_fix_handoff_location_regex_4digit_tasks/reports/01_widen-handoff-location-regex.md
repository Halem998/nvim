# Research Report: Task #1007

**Task**: 1007 - Fix validate-handoff-location.sh's fixed-3-digit task-directory regex
**Started**: 2026-08-10T00:00:00Z
**Completed**: 2026-08-10T00:00:00Z
**Effort**: small (single-line regex widen + one new test fixture file)
**Dependencies**: None for this fix itself. Multi-task `/orchestrate` driving of this task is
  blocked by the sibling MT-1/MT-4 session-id-mismatch defect until that lands (per delegation
  constraint) — irrelevant to single-task `/research`/`/plan`/`/implement` dispatch, which this
  report assumes.
**Sources/Inputs**: Codebase (hook source, deployed mirror, sibling hook test suite, errors.json,
  capstone acceptance-gate review), `specs/state.json`, `specs/errors.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real, isolated, and precisely as described: `validate-handoff-location.sh:65`'s
  allow-pattern uses `[0-9]{3}_` (exact 3 digits), so once a task directory number reaches 1000+
  (already true today — `specs/state.json`'s `next_project_number` is `1017`), every legitimate
  handoff write under that directory fails the match, trips the `MISPLACED` exit-2 diagnostic, and
  unconditionally calls `system-defect-record.sh --defect-class HANDOFF_MISLOCATED`, recording a
  spurious `system_defect` event.
- Fix is a single-character quantifier widen: `[0-9]{3}` -> `[0-9]{3,}`, applied to both the
  bare and `OC_`-prefixed branches (they share one alternation group, so one edit covers both).
  This is the exact remediation already independently suggested in `errors.json`'s
  `err_1786349061492_XpY38x.recovery.suggested_action` and empirically verified there
  (`specs/999_foo` MATCH, `specs/1000_foo` NO_MATCH under the current pattern).
- Grepped the entire `agent-system/` source store for the literal pattern `\[0-9\]{3}_` — this is
  the **only** occurrence. No sibling hooks/scripts share this exact-3-digit assumption, so the
  fix is fully scoped to this one file; no follow-up defect class exists elsewhere in the source
  store today.
- No existing test file covers this hook at all (`scripts/tests/test-validate-handoff.sh` tests
  a *different* script — `scripts/validate-handoff.sh`, the JSON-schema content validator — not
  this location-matching hook). A new `test-validate-handoff-location.sh` is needed; the sibling
  suite `test-validate-no-task-references.sh` is the closest structural model (copies the hook
  into an isolated `mktemp -d` workdir, pipes synthetic PostToolUse JSON on stdin, asserts on
  exit code).
- Recommended approach: widen the regex, update the two comment lines (62-64) that currently
  document the allowed shapes as `{NNN}_{SLUG}` to reflect "3 or more digits", and add the new
  test file with both the negative fixture (4-digit directory must NOT trip `MISPLACED`) and a
  positive rejection fixture (a genuinely misplaced path must still trip it), so the fix doesn't
  silently over-widen the matcher into accepting non-task paths.

## Context & Scope

Task 1007 targets `agent-system/extensions/core/hooks/validate-handoff-location.sh` (source
store — never the gitignored, regenerated `.claude/` deploy mirror; verified byte-identical
today via `diff`, so there is no drift to reconcile before editing). The hook is a PostToolUse
guard that runs after every `Write`/`Edit` tool call, checking whether the file being written is
named exactly `.orchestrator-handoff.json` and, if so, whether its path matches an allowed
task-directory shape. A mismatch triggers a stderr remediation message, an unconditional
`system-defect-record.sh --defect-class HANDOFF_MISLOCATED` call, and `exit 2`.

This task is scoped narrowly to the regex widen plus a regression test. It is the single
blocking item named in `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md`'s
LIVE CYCLE sub-item 3 (the negative test requiring the system-defect recorder to emit **no**
`system_defect` event on a clean run) — that acceptance re-verification is out of scope here and
is explicitly deferred to a later capstone re-run once this fix has landed and been redeployed.

## Findings

### Codebase Patterns

**The defect, exact location** (`agent-system/extensions/core/hooks/validate-handoff-location.sh:65`):

```bash
if printf '%s' "$FILE" | grep -Eq '(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$'; then
```

`[0-9]{3}` is an **exact-count** quantifier, not a minimum — it matches precisely 3 digits
followed immediately by `_`. A 4-digit prefix like `1007_` has its first 3 digits (`100`)
consumed by `[0-9]{3}`, leaving a bare `7_...` that the regex's next literal token (`_`) cannot
match against (`7` is not `_`), so the whole alternation fails and control falls through to the
`MISPLACED` branch at line 70.

The two comment lines directly above (62-64) currently document the allowed shapes using the
`{NNN}` placeholder convention (3-digit implied), so they need a matching update, not just the
regex itself, to avoid leaving stale documentation that re-teaches the wrong invariant to a
future reader:

```bash
# Allowed shapes, absolute or relative:
#   specs/{NNN}_{SLUG}/.orchestrator-handoff.json      (Claude Code tasks)
#   specs/OC_{NNN}_{SLUG}/.orchestrator-handoff.json   (OpenCode tasks)
```

**Confirmed current state that makes this live, not hypothetical**: `specs/state.json`'s
`next_project_number` is `1017` — every task directory created from here forward is 4 digits.
The delegation context for *this very research task* (1007) already lives under a 4-digit
directory, `specs/1007_fix_handoff_location_regex_4digit_tasks/`.

**Scope check — no sibling occurrences**: `grep -rn '\[0-9\]{3}_' agent-system/` (excluding
`.git/`) returns exactly one hit: this same line. No other hook, script, or validator in the
source store shares this exact-3-digit assumption, so this fix does not need to be replicated
elsewhere.

**No existing test coverage for this hook**: `scripts/tests/test-validate-handoff.sh` exists but
tests a **different** script entirely — `scripts/validate-handoff.sh`, which validates the JSON
*content* schema of a handoff file (status vocabulary, required fields), not this hook's *path*
matching. Confirmed by reading both files: the test's `VALIDATOR_CANDIDATES` array points at
`scripts/validate-handoff.sh` / `.claude/scripts/validate-handoff.sh`, never at
`hooks/validate-handoff-location.sh`. There is no `hooks/tests/` directory in this codebase;
hook tests live alongside script tests in `scripts/tests/test-*.sh` and are auto-discovered by
`scripts/tests/run-all.sh` purely by filename glob (`test-*.sh`), so a new
`scripts/tests/test-validate-handoff-location.sh` will be picked up automatically with no
registration step needed.

**Best structural model for the new test — `test-validate-no-task-references.sh`**: this sibling
suite tests another PostToolUse-style path/content-matching hook and uses exactly the pattern
needed here:
- `mktemp -d` workdir with an `EXIT` trap cleanup
- Copies the hook (and, where the hook sources a sibling, that sibling too) into the workdir at
  the same *relative* path the hook expects, so `SCRIPT_DIR`-relative sourcing/paths still
  resolve correctly inside the isolated copy
- Builds synthetic PostToolUse JSON via `jq -n` and pipes it to the hook on stdin
- Asserts on **exit code** (2 = blocked/misplaced, 0 = allowed), not stdout, matching this hook's
  actual contract (`echo '{}'; exit 0` on allow, stderr message + `exit 2` on reject)
- `pass()`/`fail()`/`info()` counter helpers, exit 0 all-pass / 1 any-fail / 2 environment error

**Side-effect safety of the negative-test fixture (the one this task requires)**: the accept path
(lines 65-68 in the current file) returns via `echo '{}'; exit 0` *before* ever reaching the
`system-defect-record.sh` call at line 95 — that call only executes on the reject branch. This
means the required negative fixture (a 4-digit task directory must NOT trip `HANDOFF_MISLOCATED`)
is safe to exercise directly against a copied hook in an isolated workdir with no need to also
stage a working copy of `system-defect-record.sh` — the accept path never touches it. A
supplementary *reject*-path fixture (to prove the fix doesn't over-widen into accepting garbage)
would reach the `system-defect-record.sh` call, but that call is already wrapped in
`|| echo "... non-fatal" >&2` in the hook itself (line 103), and `deploy-root-guard.sh` (sourced
transitively by `system-defect-record.sh`) fails closed with a caught, swallowed error when run
from a non-`.claude`/`.opencode` parent directory (like a `mktemp` workdir) — so the hook's own
exit code (2) is unaffected either way. No stub/mock of `system-defect-record.sh` is required for
correctness, though the test author may choose to redirect its stderr note away from the pass/fail
transcript for cleanliness.

### External Resources

Not applicable — this is a self-contained internal regex/shell-test fix with no external
dependency or library surface.

### Recommendations

1. **Regex widen** (line 65): change `[0-9]{3}_` to `[0-9]{3,}_` in both places it appears — note
   it appears only *once* textually since `(OC_)?[0-9]{3}_` covers both the bare and `OC_`-
   prefixed branches via the optional group, so this is a single-token edit:
   ```bash
   if printf '%s' "$FILE" | grep -Eq '(^|/)specs/(OC_)?[0-9]{3,}_[^/]+/\.orchestrator-handoff\.json$'; then
   ```
   `{3,}` is a minimum-count quantifier (3 or more), preserving rejection of genuinely malformed
   directories (1-2 digit prefixes, non-numeric prefixes) while accepting 3-digit (legacy),
   4-digit (current), and any future digit-count growth without needing another edit at the next
   order-of-magnitude crossing.
2. **Comment update** (lines 62-64): adjust the `{NNN}` placeholder shapes documentation to note
   "3 or more digits" so the comment doesn't re-teach the fixed-3-digit assumption to a future
   reader who trusts the comment over re-deriving the regex.
3. **New test file**: `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh`,
   modeled on `test-validate-no-task-references.sh`'s structure (mktemp workdir, copied hook,
   synthetic JSON via `jq -n` on stdin, exit-code assertions, `pass`/`fail`/`info` counters, exit
   0/1/2 contract). Minimum fixture set:
   - **Accept — 3-digit (legacy)**: `specs/042_foo/.orchestrator-handoff.json` -> exit 0
   - **Accept — 4-digit (the bug, the required negative test)**: `specs/1007_foo/.orchestrator-handoff.json`
     -> exit 0, no `MISPLACED` diagnostic on stderr
   - **Accept — 4-digit with `OC_` prefix**: `specs/OC_1007_foo/.orchestrator-handoff.json` -> exit 0
   - **Accept — 5+ digit (future-proofing)**: `specs/10007_foo/.orchestrator-handoff.json` -> exit 0
   - **Reject — bare filename** (no directory): `.orchestrator-handoff.json` -> exit 2
   - **Reject — wrong location** (outside any task dir): `specs/.orchestrator-handoff.json` -> exit 2
   - **Reject — non-numeric prefix**: `specs/abc_foo/.orchestrator-handoff.json` -> exit 2
   - **Reject — too few digits**: `specs/42_foo/.orchestrator-handoff.json` -> exit 2 (confirms
     `{3,}` still enforces a 3-digit *minimum*, not "any digits")
   - **Non-trigger — different basename**: a file merely containing "handoff" in its name (e.g.
     `handoff-example.json`) at any path -> exit 0, confirming the exact-basename guard (line 57)
     is unaffected by this change
4. **Do not** widen the basename match (line 57) or touch the `system-defect-record.sh` call —
   both are out of scope and functioning correctly; this defect is confined to the digit-count
   quantifier alone.

## Decisions

- **Quantifier choice**: `{3,}` (minimum 3, unbounded) over an explicit `{3,4}` or `{4}`
  replacement — matches the task's own WORK directive ("accept 3+ digits") and avoids a repeat of
  this exact defect class at the next digit-count crossing (10000+), consistent with the
  `err_1786349061492_XpY38x` suggested fix.
- **New test file, not an extension of `test-validate-handoff.sh`**: that file tests an unrelated
  script (`scripts/validate-handoff.sh`, content-schema validation) with a different
  `VALIDATOR_CANDIDATES` resolution model; conflating the two would misfile hook-path-matching
  tests under a content-schema test suite and confuse future maintainers searching by filename.
- **No stub needed for `system-defect-record.sh`** in the required negative-test fixture, since
  the accept path never reaches that call — confirmed by reading the hook's control flow, not
  assumed.

## Risks & Mitigations

- **Risk**: over-widening could accidentally start accepting non-task paths (e.g. a 3-character
  non-digit prefix that happens to end in digits followed by `_`). **Mitigation**: `{3,}` is
  still anchored to `[0-9]` only — no character-class widening, so this risk does not apply; the
  reject fixtures above (non-numeric prefix, too-few-digits) exist specifically to catch any
  future regression here.
- **Risk**: the deployed `.claude/hooks/validate-handoff-location.sh` mirror could still carry
  the old 3-digit regex until the next `[Reload All]`/`[Regenerate]`/`deploy-headless.sh` run,
  so the bug persists live even after the source-store edit lands until redeploy happens.
  **Mitigation**: this is expected deploy-boundary behavior (see
  `.claude/rules/source-store-deploy-boundary.md`), not a defect in the fix itself; the
  implementation phase should redeploy (or note that redeploy is required) as part of closing
  this task, and the capstone LIVE CYCLE re-verification (deferred, per Context & Scope above)
  is the natural checkpoint that will catch a missed redeploy.
- **Risk**: a new test file that isn't auto-discovered. **Mitigation**: confirmed
  `scripts/tests/run-all.sh` discovers by `test-*.sh` glob in `scripts/tests/`, no manual
  registration needed — verified by reading the discovery loop, not assumed.

## Context Extension Recommendations

- **Topic**: task-directory numbering assumptions baked into path-matching regexes.
- **Gap**: no existing context file catalogs "fixed-digit-count task directory regex" as a defect
  class to watch for elsewhere in the codebase (e.g., in future extension-authored hooks). This
  task's own grep found only one occurrence today, but nothing currently prevents a new hook from
  reintroducing an exact `{3}` quantifier.
- **Recommendation**: not urgent enough to warrant a new context file for a single historical
  occurrence with no current sibling instances; if a second occurrence of this defect class is
  found in a future task, that would be the trigger to add a short pattern note (e.g. to
  `context/patterns/` or a shell-scripting standards file) recommending `{3,}` over `{3}` for any
  task-directory-number regex.

## Live Confirmation (observed during this research pass)

Writing this task's own `.orchestrator-handoff.json` to the delegation-context-supplied
`handoff_path` — `specs/1007_fix_handoff_location_regex_4digit_tasks/.orchestrator-handoff.json`,
a correctly-placed 4-digit task directory — tripped the deployed
`.claude/hooks/validate-handoff-location.sh`'s `MISPLACED` diagnostic in this very session, exit
2, exactly as this report predicts. This is a live, in-session, independent third confirmation of
the defect (after the peer-verified empirical check recorded in `err_1786349061492_XpY38x` and
this report's own static regex analysis above) — not a hypothetical.

Two additional observations from this live trip, useful for the implementation/verification
phase:
- The file write itself succeeded (PostToolUse fires after the write, so the hook's exit 2 is a
  diagnostic-only surfacing, not a rollback) — the handoff content at the correct path is intact
  and valid; no remediation of *this* file was needed or performed, since `handoff_path` was
  already the correct target and the hook's guidance not to guess an alternate path was followed.
- The hook's `system-defect-record.sh` call itself failed this time (surfaced as "Note:
  system-defect recording failed (non-fatal)" on stderr, per the hook's own swallowed-failure
  wrapping at line 103) — `specs/events.jsonl`'s `system_defect` count remained at 3 (unchanged)
  rather than becoming 4. This is NOT evidence the recorder call is safe to rely on as a backstop:
  it is an unrelated, separately-worth-investigating failure of the record call itself (not
  investigated further here, out of scope for this task), and the review document's LIVE CYCLE
  blocking argument already establishes that a live-in-loop success of that call — the common
  case — reliably does add a 4th `system_defect` event, which is the actual blocker this task
  exists to remove.

## Appendix

- Search queries used: `grep -rn '\[0-9\]{3}_' agent-system/` (source-store-wide scope check);
  `grep -rl "validate-handoff-location"` / `"HANDOFF_MISLOCATED"` (usage-site survey);
  `jq` queries against `specs/errors.json` and `specs/state.json`.
- References consulted:
  `agent-system/extensions/core/hooks/validate-handoff-location.sh`,
  `agent-system/extensions/core/scripts/validate-handoff.sh`,
  `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh`,
  `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`,
  `agent-system/extensions/core/scripts/tests/run-all.sh`,
  `agent-system/extensions/core/scripts/system-defect-record.sh`,
  `agent-system/extensions/core/scripts/deploy-root-guard.sh`,
  `specs/reviews/review-2026-08-10-agent-system-refactor-capstone.md`,
  `specs/errors.json` (`err_1786349061492_XpY38x`, `err_1786349061524_pY97cE`),
  `specs/state.json`.
