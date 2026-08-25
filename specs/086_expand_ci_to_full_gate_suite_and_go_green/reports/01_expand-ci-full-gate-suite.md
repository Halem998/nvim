# Research Report: Task #86

**Task**: 86 - Expand ci to full gate suite and go green
**Started**: 2026-08-25
**Completed**: 2026-08-25
**Dependencies**: Task 82 (Wire deploy verification into deploy headless) - COMPLETED, confirmed unblocking
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/*, .github/workflows/*), live
  local script runs, `gh run view` logs of the two actual GitHub Actions executions of this
  workflow, specs/TODO.md task 82/85 history
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md
- **Effort**: TBD

## Executive Summary

- **CI has never actually executed the doc-lint.** Both historical runs of
  `Extension Docs Gate` (2026-07-29, 2026-08-18) fail in 11-13s with
  `bash: .claude/scripts/check-extension-docs.sh: No such file or directory`, exit code 127 —
  not a substantive check failure. `.claude/` is entirely gitignored (`/.claude/` in
  `.gitignore`, `git ls-files .claude` returns 0), so a fresh Actions checkout has no deployed
  tree at all. This is the load-bearing finding for the whole task: any gate that inspects
  `.claude/**` requires a deploy step to run first, in CI, from scratch.
- **The dependency (Task 82) is done and unblocks this task.** `deploy-headless.sh:248` now
  really invokes `bash .claude/scripts/verify-deploy.sh --skip-slow "$TARGET"` instead of
  echoing a suggestion. `verify-deploy.sh` is confirmed callable as the aggregator SCOPE's
  parenthetical names.
- **The task's 16-issue snapshot is stale.** A live run right now shows **19** issues, not
  16, with a different composition: the skill-base.sh drift and the 5 literature deployed-script
  drifts and the literature line_count item from the task body are gone (already resolved by an
  intervening deploy); 2 new typst `line_count` mismatches and 2 new Rule S index-orphans have
  appeared since the task was written. The implementer must re-run the live check at execution
  time, not transcribe the task body's list.
- All 16 current `line_count` (Rule R) mismatches are mechanically fixable with one existing,
  read-verified tool: `bash .claude/scripts/generate-context-line-counts.sh --write` (must be
  run from the **deployed** copy, not the source-store copy — it refuses to run from
  `agent-system/...` with a clear error). Confirmed via `--check` (read-only): 16 mismatches
  (14 core, 2 typst), 0 null, 0 missing-source — an exact match to check-extension-docs.sh's
  live Rule R output.
- The 3 Rule S failures are genuine content gaps, not auto-fixable: `grep -rl` across every
  extension's `index-entries.json` for all three filenames returns zero hits — no entry exists
  at all for `return-meta-artifacts-template.md` (core), `corpus-directory-conventions.md`
  (literature), or `shared-module-extraction-for-gate-checks.md` (literature). Each needs a new,
  schema-conformant entry hand-authored into its extension's source `index-entries.json`.
- Materializing `.claude/` in CI (a hard prerequisite, see above) means CI must run
  `deploy-headless.sh`, which shells out to `nvim --headless` running this repo's own
  `init.lua` unconditionally (no `-u` override) — which bootstraps `lazy.nvim` and the full
  plugin set on a cold runner. This is a real CI-environment cost (install neovim, network
  access for plugin clone, non-trivial first-run time) that the plan must account for, likely
  with `actions/cache` keyed on `lazy-lock.json`.

## Context & Scope

Researched: (1) what the current CI workflow actually does versus what it is documented to do;
(2) what "the nine check/lint scripts" refers to precisely; (3) whether `verify-deploy.sh` (the
SCOPE's named alternative aggregator) is now callable per the Task 82 dependency; (4) the true
current-state gate failures (not the task-body snapshot, which is now stale); (5) which of the
16 failures are mechanically fixable and which require real content; (6) what blocks CI from
running any of this today.

Out of scope for this research pass (left for `/plan`): the exact YAML restructuring, whether to
run `verify-deploy.sh` with or without `--skip-slow` in CI, and whether to wire
`check-runtime-file-tracking.sh` / `check-consumer-freshness.sh` in as well (see Decisions
below).

## Findings

### Codebase Patterns

**Current workflow** (`.github/workflows/check-extension-docs.yml`, added by a task-864 commit
`490cb9ded`, whose own message says "not pushed"):
```yaml
on:
  push:
    branches: [master]
  pull_request:
jobs:
  check-extension-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash .claude/scripts/check-extension-docs.sh
```
No deploy step. `.claude/` is fully gitignored (confirmed: `git ls-files .claude` = 0 entries;
`git check-ignore -v .claude/scripts/check-extension-docs.sh` matches `.gitignore:6:/.claude/`).

**Live GH Actions history** (`gh run list --workflow=check-extension-docs.yml`): exactly 2 runs,
both `failure`, both ~11-13s. `gh run view <id> --log` on both shows the identical failure:
```
bash: .claude/scripts/check-extension-docs.sh: No such file or directory
##[error]Process completed with exit code 127.
```
Never reached the doc-lint's own logic. The task description's "it exits 1 today" is therefore
imprecise about the mechanism (it's a shell exit 127 from a missing file, verified from actual
run logs), though accurate about the net effect (red build, ignored).

**Task 82 (dependency) status — COMPLETED, verified in code, not just TODO.md**:
`agent-system/extensions/core/scripts/deploy-headless.sh:248`:
```bash
if bash "$TARGET/.claude/scripts/verify-deploy.sh" --skip-slow "$TARGET"; then
  ...
else
  echo "[deploy-headless] Re-run the full gate set for detail: bash $TARGET/.claude/scripts/verify-deploy.sh" >&2
  ... (exit 3)
```
This replaced the old `echo "Verify with: ..."; exit 0` line 233 the task-82 description named.
`verify-deploy.sh` is confirmed callable — Task 86's SCOPE parenthetical ("or verify-deploy.sh
as the aggregator, once it is callable") is now satisfied.

**`verify-deploy.sh`'s 13 gates** (`agent-system/extensions/core/scripts/verify-deploy.sh`,
`--quiet --findings --skip-slow` flags all confirmed working via a live run):
1. Event/error-store file presence
2. Hook registrations in `.claude/settings.json`
3. Doc-lint (`check-extension-docs.sh --quiet`, plus a second `STRICT_CORE_DEPLOY=1` pass)
4. Task-reference lint (`check-task-references.sh --quiet`)
5. Manifest-driven category parity + content-hash equality (`verify.lua`, run via
   `nvim --headless`)
6. Agent contracts lint (`lint-agent-contracts.sh --verbose`, run from source store)
7. Routing wiring lint (`lint-routing-wiring.sh --verbose`, run from source store)
8. Shell test suite runner (`tests/run-all.sh`) — the one gate `--skip-slow` defers
9. Postflight boundary lint (`lint-postflight-boundary.sh`) — explicitly requires the
   **deployed** copy (`$TARGET/.claude/scripts/lint/...`), not source store
10. `specs/state.json` schema validation (`validate-state.sh --deep`)
11. Contract compliance lint (`lint-contract-compliance.sh --verbose`, source store)
12. State-writer boundary lint (`lint-state-writer-boundary.sh --verbose`, source store)
13. Whole-tree orphan detection (`find_orphans`, via `nvim --headless`)

Live `--skip-slow` run today: **1 of 23 checks failed** (gate 3, doc-lint) — everything else
passes, including all 5 contract lints, task-ref lint, verify.lua parity, validate-state,
hook registrations, and orphan detection. So today, once `.claude/` exists and is current,
essentially the whole suite is already green except doc-lint's Rule R/S findings.

**"The nine check/lint scripts" — resolved**: there are exactly 10 scripts on disk named
`check-*.sh` or `lint-*.sh` (excluding one `deprecated/check-vault-threshold.sh`):
`check-consumer-freshness.sh`, `check-deploy-freshness.sh`, `check-extension-docs.sh`,
`check-runtime-file-tracking.sh`, `check-task-references.sh`,
`lint-agent-contracts.sh`, `lint-contract-compliance.sh`, `lint-postflight-boundary.sh`,
`lint-routing-wiring.sh`, `lint-state-writer-boundary.sh`. The most defensible reading of "nine"
excludes `check-deploy-freshness.sh` specifically: its own header states it "ALWAYS EXITS 0...
this is not a preflight gate" — it is structurally incapable of failing a build, so it cannot be
one of the "nine check/lint scripts" a CI gate would run. That leaves exactly 9 candidate gate
scripts, matching the task body's count. Of those 9, `verify-deploy.sh` currently wires in 7
(doc-lint, task-ref lint, and all 5 contract lints); it does **not** wire in
`check-runtime-file-tracking.sh` (confirmed zero callers anywhere in the repo, even after Task
82 — this was already noted as an open gap in Task 82's own description) or
`check-consumer-freshness.sh` (by design a different-purpose, opt-in, whole-fleet audit script,
not a per-repo gate).

**Deploying `.claude/` in CI requires a full neovim + plugin bootstrap.**
`deploy-headless.sh` shells out to `nvim --headless -c "lua ..." -c "qa!"` with no `-u`
override, so it loads this repo's own `init.lua` in full before running the deploy Lua. `init.lua`
bootstraps `lazy.nvim` if `stdpath("data")/lazy/lazy.nvim` is absent (git-clones it), then
`lazy.nvim` installs the full plugin set from `lazy-lock.json`. On a fresh Actions runner this
is a real cost: neovim must be installed (not present by default on `ubuntu-latest`), and the
first bootstrap needs network access to GitHub for every plugin. `verify-deploy.sh` gates 5 and
13 (`verify.lua`, `find_orphans`) also shell out to `nvim --headless` the same way. This is the
single largest new CI-infrastructure item this task introduces; it did not exist before because
the workflow never got far enough to need it.

### Live Current-State Gate Results (superseding the task body's snapshot)

Direct run, `bash .claude/scripts/check-extension-docs.sh` (no flags): **FAIL: 19 issue(s)
found** — composition, verified twice (direct run and via `verify-deploy.sh --findings`,
identical Rule R/S line lists):

- **16x Rule R** (`index-entries.json` `line_count` mismatch), all in the `core` and `typst`
  extensions:
  - core (14): `architecture/context-layers.md` 219->221, `contracts/wrap-up.md` 209->212,
    `formats/return-metadata-file.md` 615->622, `guides/extension-development.md` 271->308,
    `guides/loader-reference.md` 182->191, `patterns/file-footprint-overlap.md` 194->202,
    `patterns/file-metadata-exchange.md` 305->314, `patterns/lit-stage4a-flow.md` 233->274,
    `patterns/postflight-control.md` 275->318, `patterns/skill-postflight-flow.md` 126->177,
    `reference/orchestrator-critical-paths.json` 70->74, `schemas/state-schema.json` 262->267,
    `standards/postflight-tool-restrictions.md` 216->219,
    `standards/shell-script-testing.md` 101->127
  - typst (2): `project/typst/standards/textbook-standards.md` 221->226,
    `project/typst/standards/type-theory-foundations.md` 198->203
- **3x Rule S** (deployed `context/*.md` file with zero `index.json` entry):
  - `context/contracts/return-meta-artifacts-template.md` (core; 96 lines)
  - `context/project/literature/domain/corpus-directory-conventions.md` (literature; 143 lines)
  - `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`
    (literature; 60 lines)

None of the task body's original 8 core Rule R paths, the 1 literature Rule R
(`literature-index.md 144->117`), the `skill-base.sh` drift, or the 5 literature script drifts
appear in the current live run — that portion of the original 16 has already been resolved.
The 2 typst mismatches and 2 of the 3 Rule S orphans are new since the task was authored.

### External Resources

Not applicable — this is a pure codebase/CI-infrastructure task; no external library or API
research was needed.

### Recommendations

1. **Fix Rule R (16 mismatches) mechanically.** From the deployed copy (source-store copy
   refuses to run with a clear guard error):
   `bash .claude/scripts/generate-context-line-counts.sh --write`. Verified read-only via
   `--check`: reports exactly the same 16 mismatches, 0 null, 0 missing-source. This rewrites
   `agent-system/extensions/{core,typst}/index-entries.json` in place (source store, not the
   deployed copy — the deploy is disposable) via a surgical line-oriented substitution, not a
   full re-serialize, so the diff will be line_count-only.
2. **Fix Rule S (3 orphans) by hand-authoring index entries**, not by suppressing the rule.
   Model each new entry on a sibling in the same subdomain (e.g.
   `contracts/wrap-up.md`'s entry in `agent-system/extensions/core/index-entries.json` for the
   return-meta template; existing `project/literature/domain/*` and
   `project/literature/patterns/*` entries in `agent-system/extensions/literature/index-entries.json`
   for the other two). Each entry needs: `summary`, `path`, `topics`, `on_demand`, `line_count`
   (96 / 143 / 60 respectively, matching `wc -l`), `load_when.{commands,task_types,agents}`,
   `keywords`, `subdomain`, `domain`. Read each file's actual content before writing its summary
   — do not guess from the filename alone.
3. **Re-run the live check before implementing**, not the task-body list — it is confirmed
   stale (see above). A `/plan` or `/implement` pass should re-derive the failure set from
   `bash .claude/scripts/check-extension-docs.sh` (or `verify-deploy.sh --findings`) at the
   start of its own work, and treat the task-body list as historical context only.
4. **CI workflow expansion**: prefer invoking `verify-deploy.sh` over reassembling 9 individual
   script calls in YAML — SCOPE explicitly offers this as the equivalent option, and it is now
   callable (Task 82). Concretely this means adding a deploy step
   (`bash agent-system/extensions/core/scripts/deploy-headless.sh $(pwd)` or the picker's
   headless equivalent) before `bash .claude/scripts/verify-deploy.sh`, since `.claude/` does
   not exist on a fresh checkout. Decide explicitly whether CI passes `--skip-slow` (faster,
   defers the shell test suite, matches deploy-headless.sh's own inline usage) or the full run
   (matches ACCEPTANCE's "runs the full suite" wording more literally, costs ~2.8 min plus the
   nvim/plugin bootstrap). Given ACCEPTANCE explicitly says "CI runs the full suite," the
   full (non-`--skip-slow`) invocation is the more literal reading; if `--skip-slow` is chosen
   instead, ACCEPTANCE's "full suite" claim needs either a schedule-triggered full run
   supplementing the on-push fast run, or explicit sign-off that "full suite" means the fast
   11(non-8)-of-13-gate set.
5. **Neovim/plugin bootstrap cost**: install `nvim` on the runner (not preinstalled on
   `ubuntu-latest`) and cache `~/.local/share/nvim` (lazy.nvim + plugins) and
   `~/.local/state/nvim` via `actions/cache`, keyed on `lazy-lock.json`'s hash, to avoid paying
   full plugin-clone cost on every push. This is new CI-infrastructure work with no existing
   precedent in this repo (no prior workflow has ever run `nvim --headless` in Actions).
6. **`check-runtime-file-tracking.sh` and `check-consumer-freshness.sh` are open questions, not
   silently in scope.** Neither is wired into `verify-deploy.sh` today. If "run all nine gates"
   is read literally, both need either a direct CI step or a new `verify-deploy.sh` gate; if
   "or verify-deploy.sh as the aggregator" is read as license to use the existing aggregator
   as-is, both stay out of CI for now (same as Task 82 left them). Flagging this ambiguity for
   `/plan` to resolve explicitly rather than silently pick one.
7. **Reintroduced-mismatch acceptance check**: since Rule R is content-driven (any doc edit that
   changes line count without a matching `index-entries.json` update reproduces it), the
   ACCEPTANCE test ("a deliberately reintroduced line_count mismatch fails the build") is a
   direct, cheap manual verification once the CI deploy step exists: edit any indexed `.md` by
   one line, push to a throwaway branch/PR, confirm the Actions run goes red on Rule R, then
   revert.

## Decisions

- Treat the task body's 16-item list as **historical context, not a fix checklist** — the fix
  checklist is the live 19-item run captured above, re-verified at report time via two
  independent invocations (`check-extension-docs.sh` direct, `verify-deploy.sh --findings`).
- Treat "the nine check/lint scripts" as the 9 `check-*.sh`/`lint-*.sh` scripts excluding
  `check-deploy-freshness.sh` (structurally always-exit-0, cannot be a gate) — see Findings for
  the full justification; noted as an interpretation, not a value read verbatim from any single
  source.
- Confirmed (did not assume) that Task 82 already wired `deploy-headless.sh` to call
  `verify-deploy.sh` for real, satisfying the "once it is callable" precondition in SCOPE.
- Did not run any `--write` operations during this research pass (only `--check`/read-only
  invocations) — the fixes above are recommendations for `/plan` and `/implement`, not applied
  here.

## Risks & Mitigations

- **Risk**: CI's nvim/lazy.nvim bootstrap is slow or flaky on a cold runner (network dependency
  on GitHub for every plugin on first run). **Mitigation**: `actions/cache` keyed on
  `lazy-lock.json`; consider a scheduled/manual cache-warm job if first-run latency proves an
  issue in practice.
- **Risk**: `line_count` drift is a moving target — any concurrent doc edit between research and
  implementation reintroduces the count. **Mitigation**: the implementer should re-run
  `generate-context-line-counts.sh --check` immediately before `--write`, not trust this
  report's exact numbers verbatim.
- **Risk**: choosing `--skip-slow` for the CI invocation could be read as not meeting
  ACCEPTANCE's "full suite" wording. **Mitigation**: flagged explicitly above (Recommendation 4)
  for `/plan` to make a deliberate, documented choice rather than default silently to the faster
  path.

## Context Extension Recommendations

- **Topic**: CI/GitHub Actions patterns for this repo.
- **Gap**: no existing context file documents that `.claude/` is fully gitignored and thus
  unavailable in a fresh CI checkout, nor that any gate touching deployed files requires a
  neovim+lazy.nvim bootstrap step first. This cost several tool calls to discover from scratch
  (`gh run view --log`, `.gitignore` inspection, `deploy-headless.sh` reading) and will recur for
  any future CI-related task.
- **Recommendation**: after this task lands a working CI job, capture the working recipe (deploy
  step + verify-deploy.sh invocation + any caching) as a short pattern doc, e.g.
  `context/patterns/ci-deploy-tree-bootstrap.md` in the core extension, so a future CI change
  does not have to re-derive the `.claude/`-is-gitignored / nvim-bootstrap chain from scratch.

## Appendix

Commands used (all read-only / `--check`-mode, no writes):
- `bash .claude/scripts/check-extension-docs.sh` (direct live run)
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --skip-slow` (background)
- `bash .claude/scripts/generate-context-line-counts.sh --check`
- `gh run list --workflow=check-extension-docs.yml --limit 10`
- `gh run view 32104331689 --log`, `gh run view 30485631142 --log`
- `git show --stat 490cb9ded`, `git log -1 --format=%B 490cb9ded`
- `grep -rl "return-meta-artifacts-template\|corpus-directory-conventions\|shared-module-extraction-for-gate-checks" agent-system/extensions/*/index-entries.json` (0 hits, confirms genuine gap)
- `grep -rln "check-runtime-file-tracking.sh"` across core scripts (only self-match, confirms still-orphaned)
