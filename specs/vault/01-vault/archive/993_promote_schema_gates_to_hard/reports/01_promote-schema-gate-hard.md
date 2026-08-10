# Research Report: Promote SCHEMA_CONFORMANCE_GATE_MODE from advisory to hard

**Task**: Promote SCHEMA_CONFORMANCE_GATE_MODE (in `check-extension-docs.sh`, governing Rules T
and U) from its advisory default to hard, mirroring the promotion sequence
`ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE`
**Started**: 2026-08-10T00:38:21Z
**Completed**: 2026-08-10
**Effort**: small (single-file, single-variable default flip + comment update)
**Dependencies**: two prerequisite remediation tasks (index-entries.json schema migration,
EXTENSION.md slim-down) — both confirmed landed and archived; see Findings
**Sources/Inputs**: codebase (`check-extension-docs.sh`, its test suite, prerequisite task
summaries), empirical gate run
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both prerequisite remediation efforts have landed clean. Running the doc-lint gate with
  `SCHEMA_CONFORMANCE_GATE_MODE=hard` today (before any edit) produces **exit code 0, all 19
  extensions PASS** — empirically confirming the promotion is safe right now.
- The edit is confined to one file already in `file_scope`:
  `agent-system/extensions/core/scripts/check-extension-docs.sh`. Exactly one line changes
  behavior (the default-value assignment) plus its immediately preceding 8-line comment block,
  which needs rewording to record that remediation is complete — mirroring how
  `INDEX_TRUTH_GATE_MODE`'s own comment block reads post-promotion.
- No other logic in the file needs to change: all Rule T/U call sites route through the single
  `schema_conformance_report()` helper, so flipping the one default is sufficient (same shape as
  the prior `ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE` promotion).
- The test suite `test-index-entries-schema.sh` explicitly parameterizes `gate_mode` on every
  call (never relies on the shell-level default), so the promotion is a no-op for that suite's
  pass/fail behavior — it will neither newly break nor newly fix anything there.
- A pre-existing, unrelated test failure exists in that same suite ("Rule U did not fire on a
  61-line EXTENSION.md fixture") — confirmed orthogonal to this task (fixture/harness issue, not
  a gate-mode wiring issue) and out of scope for the verification bar, which is specifically
  about `check-extension-docs.sh`'s own exit code.

## Context & Scope

The task is a narrow, mechanical promotion: flip `SCHEMA_CONFORMANCE_GATE_MODE`'s default from
`advisory` to `hard` in `check-extension-docs.sh`, once its two prerequisite remediation tasks
(the index-entries.json schema migration and the EXTENSION.md slim-down) have landed. The task
explicitly warns that flipping the default before either prerequisite lands would turn a
currently-passing gate into a standing hard failure — so verifying prerequisite completion
empirically, not just trusting task-status metadata, was the primary research activity.

## Findings

### Prerequisite status (verified via specs/state.json and archived summaries)

Both dependency tasks are archived under `specs/archive/`:

- **Index-entries.json schema migration** (the Rule T prerequisite): its completion summary
  records "0 Rule T advisories (down from the 580-line baseline)" corpus-wide, and an explicit
  `SCHEMA_CONFORMANCE_GATE_MODE=hard` "confidence run" at the time showed 0 Rule T failures — but
  it also explicitly flagged that "10 unrelated pre-existing Rule U/R/deploy-drift failures
  remain" and named promoting the gate mode as "a separate follow-up task" (i.e., not this one, a
  prior one) explicitly out of that task's own scope.
- **EXTENSION.md slim-down** (the Rule U prerequisite, tracked as `project_number: 992` in
  `state.json`, still `active_projects` with `status: "completed"` pending archival by a future
  `/todo` run): its completion summary states "check-extension-docs.sh reports zero Rule U
  advisories across all 19 extensions and passes under `SCHEMA_CONFORMANCE_GATE_MODE=hard` as a
  dry proof for the follow-on gate flip" — i.e., this very task.

### Empirical verification (this research pass)

Ran the actual gate, live, with the target hard mode forced via environment override (no source
edits made yet):

```bash
REPO_ROOT=$(pwd) SCHEMA_CONFORMANCE_GATE_MODE=hard bash agent-system/extensions/core/scripts/check-extension-docs.sh
# EXIT CODE: 0
```

Output summary (tail of the run):

```
Extension       Status
---------       ------
core            PASS
cslib           PASS
email           PASS
epidemiology    PASS
filetypes       PASS
formal          PASS
founder         PASS
latex           PASS
lean            PASS
literature      PASS
memory          PASS
nix             PASS
nvim            PASS
present         PASS
project-wide    PASS
python          PASS
slidev          PASS
typst           PASS
web             PASS
z3              PASS

PASS: all extensions OK
```

37 advisory lines appear in the run (all `core script never deployed` items under the
`STRICT_CORE_DEPLOY`/deploy-drift advisory lane, e.g. zotero/literature scripts) — these are a
**separate, pre-existing, always-advisory lane** (`check_core_deploy_advisory`, controlled by
`STRICT_CORE_DEPLOY`, not `SCHEMA_CONFORMANCE_GATE_MODE`) and do not affect the PASS/FAIL verdict
either before or after this promotion. Zero Rule T or Rule U findings appeared in the log at all
(`grep -in "rule t\|rule u"` against the full run output returned no matches), confirming both
checks are silent corpus-wide.

**Source/deploy sync check**: `agent-system/extensions/core/scripts/check-extension-docs.sh` and
its deployed `.claude/scripts/` counterpart are byte-identical (`diff` returned nothing), and
`git status --short` on the source file shows no pending changes — the file is a clean baseline
to edit.

### Exact edit targets (both in-scope, same file, `agent-system/extensions/core/scripts/check-extension-docs.sh`)

**1. Header/rule-list comment (lines 40-46)** — describes the check family at the top of the
file, currently reads:

```
#   - per-extension source `index-entries.json` schema conformance against
#     context/index.schema.json's real field set: required keys present, forbidden keys
#     (description, tags, non-agents/commands/task_types/always load_when keys) absent, domain
#     value in the enum (source-level, per entry; severity controlled by
#     SCHEMA_CONFORMANCE_GATE_MODE, defaults advisory)
#   - EXTENSION.md exceeding the 60-line limit from extension-slim-standard.md (severity
#     controlled by SCHEMA_CONFORMANCE_GATE_MODE, defaults advisory)
```

This mentions "defaults advisory" twice. The sibling `INDEX_TRUTH_GATE_MODE` bullets at lines
37/39 do NOT carry a "defaults X" qualifier at all (they just say "severity controlled by
INDEX_TRUTH_GATE_MODE") — because by the time that gate's header bullets were written, hard was
already the baked-in default and calling it out inline was redundant. The cleanest mirror is to
drop the "defaults advisory" clause from these two bullets entirely (matching the
`INDEX_TRUTH_GATE_MODE` bullet style exactly), rather than rewording it to "defaults hard" (either
works; dropping it is the closer mirror of precedent). This block is inside `file_scope` (same
file) but is not the block the task description calls "the preceding comment block" — it is
optional polish, not the primary edit.

**2. The primary edit — default assignment + its immediately preceding comment block (lines
646-654)**, which the task description explicitly names ("the preceding comment block"). Current
text:

```bash
# SCHEMA_CONFORMANCE_GATE_MODE controls severity for Rules T and U (the two checks this block
# introduces) -- a SIBLING to INDEX_TRUTH_GATE_MODE above, not an overload of it.
# INDEX_TRUTH_GATE_MODE already defaults to "hard" because Rules R/S landed after their
# remediation was already complete; routing these new, pre-remediation rules through it would
# either hard-fail 14 of 19 extensions (Rule T) and 7 of 19 (Rule U) on day one, or force
# demoting Rules R/S back to advisory. Defaults to "advisory" until the bulk index-entries.json
# migration and EXTENSION.md slim-down follow-on tasks land; promote to "hard" only once those
# have shipped (mirrors the ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE promotion precedent).
SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-advisory}"
```

Recommended replacement, mirroring `INDEX_TRUTH_GATE_MODE`'s own post-promotion comment (lines
580-589) in structure and tense (past-tense "has landed" / "was confirmed", "override only for
local debugging"):

```bash
# SCHEMA_CONFORMANCE_GATE_MODE controls severity for Rules T and U (the two checks this block
# introduces) -- a SIBLING to INDEX_TRUTH_GATE_MODE above, not an overload of it.
# INDEX_TRUTH_GATE_MODE already defaults to "hard" because Rules R/S landed after their
# remediation was already complete; the same is now true here -- the bulk index-entries.json
# schema migration and EXTENSION.md slim-down follow-on tasks have both landed, and a
# SCHEMA_CONFORMANCE_GATE_MODE=hard dry run confirmed 0 Rule T and 0 Rule U findings across all
# 19 extensions. Defaults to "hard" now that source-store remediation has already landed and a
# clean run was confirmed -- override to "advisory" only for temporary local debugging, never in
# committed config (mirrors the ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE promotion precedent).
SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-hard}"
```

Only the trailing `:-advisory` -> `:-hard` fragment on the assignment line is behavior-changing;
everything else is comment text.

### No other call sites need to change

`grep -n "schema_conformance_report"` shows every Rule T/U finding (10 call sites: entry-level
required-key checks, two forbidden-key checks, one load_when-key check, one domain-enum check,
plus the Rule U length check) routes through the single `schema_conformance_report()` gate
function defined immediately below the assignment (lines 656-663). That function's own logic
(`if hard -> fail; else -> info ADVISORY`) is untouched by this promotion — it already branches
correctly on whatever `SCHEMA_CONFORMANCE_GATE_MODE` resolves to. This is the same shape the
`ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE` promotion took: a single default-value flip is
sufficient because the severity-branching logic was written generically from the start.

### Test suite impact: none from this promotion; one unrelated pre-existing failure noted

`agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` never relies on the
shell-level default — every `run_check` call explicitly passes `gate_mode` as an argument
(`advisory` for the message-content assertions, `hard` for the one severity-wiring assertion at
line 229). Running the suite today (pre-edit) gives **8 passed, 1 failed**:

- The 1 failure is `[FAIL] Rule U did not fire on a 61-line EXTENSION.md` — a fixture/harness
  issue unrelated to gate-mode wiring (the corresponding 60-line negative case and the
  hard-mode severity-wiring case both pass correctly). This is pre-existing in the current
  committed state (confirmed via clean `git status` on the source file before any edit) and is
  orthogonal to this task's verification bar, which concerns `check-extension-docs.sh`'s own
  exit code, not this unit test suite. Not in `file_scope` for this task; flagged here for
  visibility only, not as work to perform.

### Related but out-of-scope: extension-slim-standard.md still says "defaulting advisory"

`agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` (lines 9-12)
currently reads: "severity controlled by `SCHEMA_CONFORMANCE_GATE_MODE`, defaulting `advisory`".
This will become stale prose once the default flips to hard. This file is **not** in this task's
`file_scope` (`state.json` scopes only `check-extension-docs.sh`), so it is out of scope for this
task's edit — noted here as a candidate one-line follow-up rather than folded into this task's
diff, consistent with how the prerequisite migration task explicitly deferred out-of-scope
cleanup items rather than silently expanding its own scope.

## Decisions

- Treat the header/rule-list bullets (lines 40-46) as optional companion polish, not the primary
  edit — the task description's "preceding comment block" phrase points specifically at lines
  646-653, immediately above the assignment on line 654.
- Recommend dropping "defaults advisory" from the header bullets (matching sibling
  `INDEX_TRUTH_GATE_MODE` bullet style) rather than rewording to "defaults hard", since the
  sibling gate's header bullets carry no "defaults X" qualifier at all post-promotion.
- Do not touch `extension-slim-standard.md` — out of `file_scope`; noted as a follow-up only.
- Do not touch the test suite — its one failure is unrelated and pre-existing; not in
  `file_scope`.

## Risks & Mitigations

- **Risk**: a future extension regresses Rule T/U compliance and the now-hard gate blocks
  `verify-deploy.sh` for everyone. **Mitigation**: this is the intended behavior of promoting to
  hard (same trade-off already accepted for `ORPHAN_GATE_MODE`/`INDEX_TRUTH_GATE_MODE`); the
  `SCHEMA_CONFORMANCE_GATE_MODE=advisory` override remains available for temporary local
  debugging per the recommended comment text.
- **Risk**: the empirical hard-mode run above could go stale between this research pass and
  implementation if new extension content lands in between. **Mitigation**: the implementation
  phase's own verification bar (`bash agent-system/extensions/core/scripts/check-extension-docs.sh`
  exits 0 with the new baked-in default, no env override) re-confirms this at edit time — it is
  not being taken on faith from this report alone.

## Context Extension Recommendations

None — this is a narrow mechanical change to an existing, well-documented gate-mode pattern
already recorded in the file's own comments; no new context file is warranted.

## Appendix

- Commands run: `jq` queries against `specs/state.json` for prerequisite task status;
  `REPO_ROOT=$(pwd) SCHEMA_CONFORMANCE_GATE_MODE=hard bash agent-system/extensions/core/scripts/check-extension-docs.sh`;
  `diff` between source and deployed script copies; `git status --short` on the source file;
  `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`.
- Files read: `agent-system/extensions/core/scripts/check-extension-docs.sh` (lines 1-100,
  570-790, 1095-1120), `agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`,
  `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` (excerpt),
  archived summaries for the two prerequisite tasks.
