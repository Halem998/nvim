# Research Report: Fix Duplication Gate Scope and EXTENSIONS_ROOT

- **Task**: 84 - fix_duplication_gate_scope_and_extensions_root
- **Started**: 2026-08-24T21:52:00Z
- **Completed**: 2026-08-24T21:56:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**: `specs/state.json` (project_number 84), `specs/errors.json` (err_1787022038113_c3VPTR), `agent-system/extensions/core/scripts/tests/test-common-lib.sh`, `agent-system/extensions/core/scripts/tests/run-all.sh`, `agent-system/extensions/core/scripts/lib/common.sh`, live `grep`/`bash` execution against both the source store and the deployed `.claude/` tree
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- The gate is broken in two independent, compounding ways: (1) it only ever scans `*.sh`, so
  it structurally cannot see the 37 `.md` sites that carry the duplicated
  `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` generator; (2)
  `EXTENSIONS_ROOT` is resolved by a fixed `../../..` depth from `SCRIPT_DIR`, which is correct
  only in the source-store layout — from the deployed `.claude/scripts/tests/` copy it resolves
  to the **repo root**, not `agent-system/extensions/`.
- Live count today (2026-08-24): **52 total sites** matching the pattern across
  `agent-system/extensions/` (up from the 48 recorded when this task was created), confirming
  the class is still actively growing while the gate stays structurally blind to most of it.
- Of the 52: 1 is the canonical definition (`lib/common.sh`), 1 is the test file's own
  self-referential comment, 1 is a genuine `.sh` offender (`scripts/validate-state.sh`) already
  catchable by the existing `*.sh` scan, **37 are `.md` sites under `commands/`, `skills/`, or
  `agents/`** across 7 extensions (core, cslib, epidemiology, filetypes, founder, literature,
  present) — invisible to the current gate — and **12 are illustrative-prose `.md` sites** under
  `context/` (11) and `rules/` (1) that must stay excluded per the task's own scope guidance.
- `agent-system/extensions/core/scripts/tests/run-all.sh` already implements exactly the
  dual-mode detection this gate needs (probe for `core/manifest.json` at the candidate
  `../../..` root to distinguish source-store from deployed layout) — this is a ready-made
  template, not something to invent from scratch.
- `lib/common.sh` already defines and documents `common_session_id()` with 9 real `.sh`
  call-site adopters (`command-gate-in.sh`, `manage-topics.sh`,
  `orchestrate-predispatch-review.sh`, `reconcile-artifacts.sh`, `skill-base.sh` (2 sites), and
  2 quarantined `scripts/deprecated/` files) plus its own definition site — the migration target
  for all 38 real offenders already exists and needs no new code.
- Recommended fix: keep the existing `*.sh` scan over the whole (correctly-resolved)
  `EXTENSIONS_ROOT` unchanged, add a **separate** `*.md` scan restricted to each extension's
  `commands/`, `skills/`, `agents/` subdirectories (source-store) or the deployed tree's
  top-level `commands/`, `skills/`, `agents/` (deployed), and fix `EXTENSIONS_ROOT`/scan-root
  resolution using the `run-all.sh` source-store-probe pattern.

## Context & Scope

Task 84 targets the single duplication gate in this codebase
(`agent-system/extensions/core/scripts/tests/test-common-lib.sh:225-241`), which asserts that
the `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` session-ID generator exists
in exactly one place (`lib/common.sh`). Two defects are in scope:

1. **Scope defect**: `grep -rl 'sess_\$(date' --include="*.sh" "$EXTENSIONS_ROOT"` never looks
   at `.md` files, where the overwhelming majority of duplicate sites now live.
2. **Root-resolution defect** (`errors.json` `err_1787022038113_c3VPTR`, severity high,
   `fix_status: "unfixed"`): `EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"` is a
   fixed-depth walk that is correct only for the source-store path
   (`agent-system/extensions/core/scripts/tests/`); from the deployed copy
   (`.claude/scripts/tests/`) the same three-level walk lands on the repo root, not
   `agent-system/extensions/`.

Both defects were reproduced live in this session (see Findings) rather than taken on faith
from the task description.

## Findings

### 1. Both defects reproduce today, confirmed by direct execution

Running the suite from the source-store copy:
```
$ bash agent-system/extensions/core/scripts/tests/test-common-lib.sh
...
[FAIL] single-source assertion: inline sess_$(date generation found outside lib/common.sh:
[INFO]   .../agent-system/extensions/core/scripts/validate-state.sh
Passed: 23
Failed: 1
```
Running the deployed copy:
```
$ bash .claude/scripts/tests/test-common-lib.sh
...
[FAIL] single-source assertion: inline sess_$(date generation found outside lib/common.sh:
[INFO]   .../agent-system/extensions/core/scripts/validate-state.sh
[INFO]   .../.claude/scripts/validate-state.sh
Passed: 23
Failed: 1
```
The deployed run's `EXTENSIONS_ROOT` resolves to the repo root (confirmed: `SCRIPT_DIR/../../..`
from `.claude/scripts/tests/` is the repo root, not `agent-system/extensions/`), so it happens to
still catch the one `.sh` offender by scanning the *entire* repository — but this is incidental,
non-deterministic in principle (it would also match an unrelated `.sh` file anywhere else in the
repo, e.g. under `lua/`), and diverges in offender-set composition between the two run
locations exactly as `err_1787022038113_c3VPTR` describes. Neither run's `*.sh`-only scope sees
any `.md` site, so both runs currently report only 1 offender when the real count (see below) is
38.

### 2. Full current inventory of `sess_$(date` sites (2026-08-24)

`grep -rl 'sess_\$(date' agent-system/extensions/` returns **52 files** (up from 48 at task
creation, 43 on 2026-08-11 — the class continues to grow while the gate is green from a normal
deployed run). Breakdown by disposition:

| Disposition | Count | Notes |
|---|---|---|
| Canonical definition | 1 | `core/scripts/lib/common.sh` — never an offender |
| Test file's own comment | 1 | `core/scripts/tests/test-common-lib.sh` — already excluded by the gate's own exclusion list |
| Genuine `.sh` offender | 1 | `core/scripts/validate-state.sh:271` — a real inline generator, already technically catchable by `*.sh` scanning if root resolution were fixed |
| **`.md` offender, in `commands/`/`skills/`/`agents/`** | **37** | Invisible to the current gate; the real target of this fix |
| `.md`, illustrative prose (`context/`, `rules/`) | 12 | 11 under `core/context/**`, 1 under `core/rules/git-workflow.md` — task explicitly asks to exclude `context/`/`docs/` illustrative prose from the new `.md` scan |

By extension, the 37 in-scope `.md` offenders: core 11 (8 `commands/*.md` + 3 `skills/*/SKILL.md`),
founder 10 (`commands/*.md`), filetypes 5 (`commands/*.md`), present 5 (`commands/*.md`),
cslib 3 (2 `commands/*.md` + 1 `skills/*/SKILL.md`), literature 2 (`skills/*/SKILL.md`),
epidemiology 1 (`commands/epi.md`).

Example in-scope offender (executed prose, not documentation):
`agent-system/extensions/core/commands/research.md:155`:
```
batch_session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```
Example correctly-excluded illustrative-prose site:
`agent-system/extensions/core/context/routing.md:41` shows the same string as a documentation
example of the ID format, not an executed generator.

### 3. `run-all.sh` already contains the exact dual-mode detection template needed

`agent-system/extensions/core/scripts/tests/run-all.sh:68-107` solves precisely this problem for
suite discovery: it computes `CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"` (the same
expression `test-common-lib.sh` uses) and then **probes** for `core/manifest.json` inside it —
present means source-store mode (`EXTENSIONS_ROOT=$CANDIDATE_EXT_ROOT`), absent means deployed
mode (falls back to `DEPLOY_SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.. " && pwd)"`, i.e. `.claude/scripts`).
This is a proven, already-tested pattern in the same file family and should be reused rather than
reinvented. Note `run-all.sh`'s deployed-mode fallback resolves to `.claude/scripts` (a scripts
subtree), not the `.claude/` root — `test-common-lib.sh`'s deployed-mode `.md` scan needs a
sibling resolution one level higher (`.claude/`) to reach `commands/`, `skills/`, `agents/`,
since those live at `.claude/` top level, not under `.claude/scripts/`.

### 4. The migration target function already exists with a working adopter base

`lib/common.sh` defines `common_session_id()` and documents 9 `.sh` call sites already migrated
in "Phase 3": `command-gate-in.sh`, `manage-topics.sh`, `orchestrate-predispatch-review.sh`,
`reconcile-artifacts.sh`, `skill-base.sh` (two call sites), plus two quarantined
`scripts/deprecated/` files (`archive-task.sh`, `vault-operation.sh`) whose source still calls
the function even though neither has a live caller. This confirms the migration pattern is
proven and low-risk for `.sh` files; for `.md` files (commands/skills), the equivalent migration
is replacing the inline bash snippet with a call to `common_session_id` after sourcing
`lib/common.sh` (or, where the `.md` file's embedded script cannot easily source a shared lib,
documenting the accepted alternative — this is a plan-stage decision, not a research-stage one).

### 5. Task-description count discrepancy (minor, worth flagging)

The task description states "10 adopters today"; direct `grep -rl 'common_session_id'`
(excluding `lib/common.sh` itself) finds 9 `.sh` files, one of which
(`tests/test-common-lib.sh`) matches only via its own descriptive comment listing the library's
exported functions, not a real call site. Real functional adopters are therefore 8 files (9
call sites, since `skill-base.sh` has two). This is a small discrepancy from the task
description's count and does not change the fix approach, but the planner should use the
grep-verified 8/9 figures rather than the task description's "10" when scoping the migration
phase.

## Decisions

- The `*.sh` scan scope should **not** be narrowed to `commands/`/`skills/`/`agents/` — doing so
  would stop catching `scripts/validate-state.sh`, a real, already-present offender outside
  those three directories, and would be a regression relative to today's (accidentally-working)
  deployed-mode behavior. Only the **new** `.md` scan should be scoped to
  `commands/`/`skills/`/`agents/`; the existing `.sh` scan should keep its current whole-tree
  reach, just with a correctly-resolved root.
- `EXTENSIONS_ROOT` resolution should reuse `run-all.sh`'s `core/manifest.json`-probe pattern
  rather than inventing a new detection heuristic, for consistency within the same file family
  and because it is already proven correct in both modes.
- `rules/*.md` should be treated the same as `context/*.md` (excluded from the `.md` scan) since
  it is documentation, not an executed surface — the task description names only `docs/` and
  `context/` explicitly, but `rules/git-workflow.md`'s occurrence
  (`sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` shown as a portable-command
  illustration) is the same kind of illustrative prose. The planner should confirm this
  explicitly rather than let it fall through a gap between the task description's two named
  exclusions and the three named inclusions.

## Recommendations

1. **Fix `EXTENSIONS_ROOT`/scan-root resolution first**, reusing `run-all.sh`'s
   `core/manifest.json`-probe: source-store mode sets `EXTENSIONS_ROOT` to the probed
   `agent-system/extensions/` (or repo-relative equivalent); deployed mode sets a
   `DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"` (one level above `run-all.sh`'s
   `DEPLOY_SCRIPTS_ROOT`, i.e. `.claude/`) so `commands/`, `skills/`, `agents/` are reachable.
2. **Keep the existing `.sh` scan unchanged in reach** (whole `EXTENSIONS_ROOT`/`DEPLOY_ROOT`
   tree via `--include="*.sh"`), only fixing which root it points at.
3. **Add a second, `.md`-scoped scan** restricted per-mode:
   - Source-store: iterate `EXTENSIONS_ROOT"/*/{commands,skills,agents}` (skip missing dirs).
   - Deployed: scan `DEPLOY_ROOT/{commands,skills,agents}` directly (already flat, no
     per-extension loop needed).
   Merge both scans' offender lists before the existing exclusion filters
   (`/lib/common.sh`, `/tests/test-common-lib.sh`) and the pass/fail decision.
4. **Migrate the 38 real offenders** (1 `.sh` + 37 `.md`) to `common_session_id()` (for `.sh`) or
   the equivalent inline replacement documented for `.md` command/skill files, following the
   proven Phase-3 `.sh` migration pattern already in `lib/common.sh`'s adopter list.
5. **Close `err_1787022038113_c3VPTR`** with evidence once the gate is confirmed to (a) fail on a
   deliberately reintroduced inline generator under `commands/`, (b) pass identically from both
   the source-store and deployed run locations, and (c) report zero live offenders outside
   `lib/common.sh`.
6. Add a regression case exercising the deployed-mode `.md` scan specifically (not just the
   source-store case), since the root-resolution defect is invisible when testing only from the
   source store.

## Risks & Mitigations

- **Risk**: narrowing scope in a way that regresses `scripts/validate-state.sh` detection.
  **Mitigation**: keep `.sh` scan whole-tree (Decision above); verify post-fix that
  `validate-state.sh` still appears as an offender pre-migration.
- **Risk**: migrating 37 `.md` command/skill files touches a wide, cross-extension surface
  (7 extensions) in one task — high blast radius for a single plan phase.
  **Mitigation**: this is a planning-stage sizing decision; the plan should likely phase the
  migration per-extension or batch it, and the plan should explicitly decide the `.md`
  replacement idiom (call `common_session_id` after sourcing `lib/common.sh` from the command's
  embedded bash, vs. an accepted inline-but-flagged exception) before starting the migration
  phase, since command/skill `.md` files execute in varying shell contexts.
- **Risk**: deployed-mode root resolution regressing again in the future if `.claude/`'s
  top-level layout changes. **Mitigation**: probe-based detection (matching `run-all.sh`) is
  more robust to future layout drift than a fixed-depth walk, since it fails loudly (empty/no
  match) rather than silently resolving to the wrong root.

## Appendix

- Search queries used: `grep -rl 'sess_\$(date' agent-system/extensions/`,
  `grep -rl 'common_session_id' agent-system/extensions/ --include="*.sh" --include="*.md"`,
  direct `bash` execution of both the source-store and deployed copies of
  `test-common-lib.sh`.
- Key files referenced: `agent-system/extensions/core/scripts/tests/test-common-lib.sh:225-241`,
  `agent-system/extensions/core/scripts/tests/run-all.sh:68-107`,
  `agent-system/extensions/core/scripts/lib/common.sh:23-89`,
  `agent-system/extensions/core/scripts/validate-state.sh:271`,
  `specs/errors.json` entry `err_1787022038113_c3VPTR`.
