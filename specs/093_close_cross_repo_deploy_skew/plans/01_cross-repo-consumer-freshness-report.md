# Implementation Plan: Task #93

- **Task**: 93 - close_cross_repo_deploy_skew
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (`deploy-freshness-lib.sh` and `source_git_head` stamping already exist and are reused unmodified)
- **Research Inputs**: `specs/093_close_cross_repo_deploy_skew/reports/01_cross-repo-deploy-skew-visibility.md`
- **Artifacts**: plans/01_cross-repo-consumer-freshness-report.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Cross-repo deploy skew is currently invisible from the source-store repo: each consumer pulls
independently and freezes at its last manual reload, and nothing here knows which repos consume
this source store or how far behind they are. This plan adds a **source-side tier 3 fleet view**
on top of the existing per-repo tiers: a git-tracked consumer registry, a new
`check-consumer-freshness.sh` reporting script (with a `--discover` reconciliation mode) that
reuses `deploy_freshness_status` unmodified, a guarded call from `deploy-headless.sh`'s existing
trailing block that names newly-stale consumers after every deploy, and a bounded, non-blocking
consecutive-ignore escalation on the existing tier-1 per-repo WARN. Nothing in this plan pushes
into a consumer repo; the pull-only architecture in
`context/patterns/regeneration-is-manual-only.md` is preserved intact. Done means: one command,
run from this repo, prints every known consumer's per-extension deployed revision and flags those
behind source; and a deploy here ends by naming which known consumers are now stale.

### Research Integration

Findings carried directly into this plan:

- `deploy_freshness_status <repo_root> <extension_name>` in
  `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` is already repo-root-
  parametric and works unmodified against any consumer path (the `source_dir` it compares is an
  absolute path back into this repo). **No new comparison algorithm; no edit to that library.**
- No consumer registry exists anywhere in the source store today. Eight live consumers were
  measured on this machine: `~/.dotfiles`, `~/Projects/{BimodalLogic,ModelChecker,PersonalWebsite,cslib}`,
  `~/Projects/Logos/{Theory,Hardware}`, `~/Philosophy/Papers/PossibleWorlds`.
- `deploy-headless.sh`'s `main()` trailing verify block is the correct hook site, and its
  0/1/2/3 exit-code contract must not change.
- `command-gate-in.sh`'s CHECKPOINT 1 `... 2>&1 || true` call is the model for any non-blocking
  wiring; escalation logic belongs inside `check-deploy-freshness.sh`, not at its call site.
- The registry-staleness meta-problem is mitigated (not eliminated) by `--discover`.

**Two research assumptions corrected during planning** (verified against the manifest and the
deployed trees, not assumed):

1. The research states the registry would be "deliberately not deployed into `.claude/`". That is
   **not achievable at the recommended path**: `manifest.json`'s `provides.context` declares
   `reference` as a whole *directory* entry, so everything under
   `context/reference/` deploys (confirmed: `orchestrator-critical-paths.json` is present in
   `.claude/context/reference/` here and in `~/Projects/BimodalLogic/.claude/context/reference/`).
   This plan accepts deployment and turns it into an asset — the script resolves the registry via
   the same `$SCRIPT_DIR/../context/reference/` relative path in both the source store and the
   deployed tree, so one lookup works everywhere with no root computation.
2. The research does not mention two mandatory registration surfaces that a new script and a new
   runtime file trigger. Both are hard gates, not optional polish:
   - `check-extension-docs.sh` rule Q (`check_undeclared_scripts`) fails on any script on disk
     that is not in `manifest.json`'s `provides.scripts` — so `manifest.json` **must** be edited.
   - `check-runtime-file-tracking.sh` checks A/B enforce ignore coverage for every ephemeral
     runtime class, and `context/standards/orchestrator-runtime-files.md` is that policy's home —
     so the streak-counter file needs a `.gitignore` pattern in
     `agent-system/extensions/core/root-files/.gitignore`, a table row in that standard, and a
     probe entry in the checker.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

### File Scope (WIDENED — record this in state.json)

The task's declared `file_scope` lists three files. The design requires eleven. The widened scope,
all under `agent-system/extensions/core/` per the source-store rule:

| # | Path | New? | Why |
|---|------|------|-----|
| 1 | `context/reference/known-consumer-repos.json` | NEW | the registry |
| 2 | `scripts/check-consumer-freshness.sh` | NEW | the fleet report + `--discover` |
| 3 | `scripts/tests/test-consumer-freshness.sh` | NEW | fixture suite for both |
| 4 | `manifest.json` | edit | `provides.scripts` registration (rule Q hard gate) |
| 5 | `scripts/check-deploy-freshness.sh` | edit (declared) | consecutive-ignore escalation |
| 6 | `scripts/deploy-headless.sh` | edit (declared) | post-deploy stale-consumer report |
| 7 | `context/patterns/regeneration-is-manual-only.md` | edit (declared) | tier-3 documentation |
| 8 | `root-files/.gitignore` | edit | ignore the streak-counter file |
| 9 | `context/standards/orchestrator-runtime-files.md` | edit | register the streak file's class |
| 10 | `scripts/check-runtime-file-tracking.sh` | edit | ephemeral probe for the streak file |
| 11 | `docs/reference/utility-scripts-inventory.md` | edit | catalogue the new operator script |

## Goals & Non-Goals

**Goals**:
- One command, run from this repo, reports every known consumer repo's per-extension deployed
  revision and flags those behind source (acceptance criterion (a)).
- Every successful `deploy-headless.sh` run ends by naming the known consumers that are now stale
  relative to what was just deployed (acceptance criterion (b)).
- Decide and implement the tier-1 escalation question (acceptance criterion (c)): **yes,
  visibility-only, never blocking**, on a consecutive-ignored-invocation counter.
- Keep the registry honest over time via an opt-in `--discover` reconciliation mode.
- Document the result as an explicit third tier of the existing staleness model.

**Non-Goals**:
- **No push, ever.** Nothing here redeploys into, writes to, or mutates any consumer repo. Every
  consumer interaction is a read of that repo's own `.claude-extensions.json`.
- No change to `deploy-freshness-lib.sh` — its algorithm is reused verbatim.
- No change to `deploy-headless.sh`'s 0/1/2/3 exit-code contract.
- No blocking behavior anywhere: tier 1 stays always-exit-0; the new report is opt-in and its
  exit code is consumed by nobody who can be blocked by it.
- No multi-machine support. `source_dir` is an absolute machine-local path; foreign-machine
  consumers are out of scope by inheritance from tiers 1/2, not a new gap.
- No routine filesystem scanning on the primary report path (that is what the registry is for).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A `deploy-headless.sh` edit breaks the deploy engine or its exit-code contract | H | M | Hook call is fully guarded (`[ -f ... ] && bash ... \|\| true`), added strictly inside `main()` (never at top level — SELF-OVERWRITE HAZARD), verify result captured to a variable so both the exit-0 and exit-3 paths still exit with exactly their existing code. Phase 4 is `full` tier |
| An escalation regression in `check-deploy-freshness.sh` breaks CHECKPOINT 1 on every command | H | M | Preserve the `set -uo pipefail` + always-`exit 0` contract; every new step degrades to a silent skip; counter I/O wrapped so a missing/unwritable `specs/` is a no-op. Phase 5 is `full` tier |
| Registry goes stale (the same problem, one meta-level up) | M | H | `--discover` reconciliation mode (Phase 3) names on-disk consumers absent from the registry |
| New script/runtime file trips `check-extension-docs.sh` or `check-runtime-file-tracking.sh` | M | H | Registration is explicit plan work: manifest in Phase 2, gitignore/standard/probe in Phase 5 |
| `git rev-list --count` fails when a recorded head is not an ancestor (rebased/GC'd source history) | L | M | Guard the commits-behind computation; print `?` rather than aborting or claiming 0 |
| Consumer path unreadable / on another disk / not yet cloned | L | M | Report `MISSING` / `NOEXTSTATE` rows explicitly — the opt-in audit reports completely, unlike tier 1's deliberate silence |
| Deployed copies of the new script also land in consumers | L | H | Harmless by construction: all paths in the registry and in `source_dir` are absolute, so the report reads identically wherever it runs. Documented, not prevented |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 5 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 6, 7 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Consumer registry file and schema [COMPLETED]

**Goal**: A git-tracked registry naming this source store's known consumer repos, with a stable
schema the reporting script can read.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/reference/known-consumer-repos.json` with: *(completed)*
      `$schema` (`known-consumer-repos-v1`), `source_repo` (absolute path of this repo),
      `discover_roots` (array of root directories for `--discover`), and `consumers` (array of
      `{path, note}` objects).
- [x] Seed `consumers` with the eight consumers named in the research report, each with a short *(completed)*
      `note`. Confirm each path exists and its `.claude-extensions.json` records a `source_dir`
      under this repo's `agent-system/extensions/` before listing it.
- [x] Seed `discover_roots` with `~`, `~/.dotfiles`, `~/Projects`, `~/Projects/Logos`, *(completed)*
      `~/Philosophy/Papers` (written as absolute paths, no `~` expansion dependency).
- [x] Add a top-of-file `_comment` field stating: this file is source-repo metadata that also *(completed)*
      deploys (because `provides.context` declares `reference` directory-wide); its deployed
      copies are informational and never authoritative for any consumer's own behavior.
- [x] Validate with `jq empty`. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The consumer set is hypothesized to be exactly the eight repos measured in
the research report. Confirm at implementation time by running, for each candidate,
`jq -r '.extensions | to_entries[] | .value.source_dir' <path>/.claude-extensions.json` and
checking the result is under this repo's `agent-system/extensions/`. Record any repo that has
appeared or disappeared since the research pass rather than transcribing the list blind.

**Files to modify**:
- `agent-system/extensions/core/context/reference/known-consumer-repos.json` - NEW registry

**Verification**:
- `jq empty` on the file passes.
- Every listed `path` exists on disk and carries a `.claude-extensions.json` whose `source_dir`
  points into this repo (or is explicitly annotated as intentionally-listed-but-absent).

---

### Phase 2: `check-consumer-freshness.sh` core report + manifest registration [COMPLETED]

**Goal**: One command that reports every registered consumer's per-extension deployed revision and
flags those behind source. This is acceptance criterion (a).

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/check-consumer-freshness.sh` with a header *(completed)*
      documenting: purpose, its relation to tiers 1/2, its exit-code contract, and that it never
      writes to any consumer repo.
- [x] Resolve the shared library as a sibling of this script's OWN location (`$SCRIPT_DIR/lib/ *(completed)*
      deploy-freshness-lib.sh`), copying `check-deploy-freshness.sh`'s existing sibling-lookup
      comment and rationale — never anchor off the repo being checked.
- [x] Resolve the registry at `$SCRIPT_DIR/../context/reference/known-consumer-repos.json` (this *(completed)*
      one relative path is correct in both the source store and the deployed tree).
- [x] For each `consumers[]` entry: emit `MISSING` if the path is absent; `NOEXTSTATE` if it has *(completed)*
      no `.claude-extensions.json`; otherwise enumerate that repo's own recorded extensions
      (`jq -r '.extensions // {} | keys[]?'`) and call `deploy_freshness_status <path> <ext>` per
      extension. The registry stores only a path — never a duplicated per-extension list.
- [x] Add a commits-behind column: locate the recorded head's position in the path-scoped history *(completed)*
      via `git -C <toplevel> rev-list --count <recorded>..<recomputed> -- <source_dir>`; print `?`
      when the recorded head is not reachable (rebase/GC) rather than asserting a number.
- [x] Print a fixed-width table (repo, extension, status, behind) plus a one-line summary. Report *(completed)*
      **every** registered entry including `CANNOTVERIFY`/`MISSING`/`NOEXTSTATE` — unlike tier 1's
      deliberate silence, an opt-in audit's value is completeness. Add a header comment saying so.
- [x] Mark the `source_repo` row distinctly (fresh by construction) rather than omitting it. *(completed)*
- [x] Support `--stale-only` (print only non-FRESH rows) for the deploy hook's use in Phase 4. *(completed)*
- [x] Exit codes: `0` = no registered consumer is stale; `1` = at least one stale; `2` = registry *(completed)*
      missing/unparseable or usage error. Document that callers who must not be affected are
      expected to invoke it guarded (`|| true`).
- [x] `chmod +x` the script. *(completed)*
- [x] Register `check-consumer-freshness.sh` in `manifest.json`'s `provides.scripts` (required — *(completed)*
      `check-extension-docs.sh` rule Q fails otherwise).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/check-consumer-freshness.sh` - NEW reporting script
- `agent-system/extensions/core/manifest.json` - add the script to `provides.scripts`

**Verification**:
- `bash -n` passes.
- Running the script from this repo prints a row for each of the registry's consumers and
  correctly flags the known-stale ones from the research measurement.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes (rule Q satisfied).
- No consumer repo's files are modified: `git -C <consumer> status --porcelain` unchanged for a
  sampled consumer before and after the run.

---

### Phase 3: `--discover` reconciliation mode [COMPLETED]

**Goal**: Keep the registry from silently going stale by naming on-disk consumers that are not
registered.

**Tasks**:
- [x] Add a `--discover` flag to `check-consumer-freshness.sh`. *(completed)*
- [x] For each `discover_roots[]` entry, run a bounded scan (`find <root> -maxdepth 3 -name *(completed)*
      .claude-extensions.json`, pruning `.git`) and keep files where any extension's `source_dir`
      is under this repo's `agent-system/extensions/`.
- [x] Diff the discovered set against `consumers[].path`; print an `UNREGISTERED` line per repo *(completed)*
      found on disk but absent from the registry, and a `REGISTERED-BUT-ABSENT` line per registry
      entry not found by the scan (informational — an absent entry is deliberately NOT auto-removed).
- [x] Print the exact registry edit to make (the JSON object to add), never edit the registry *(completed)*
      automatically.
- [x] Document in the header that `--discover` is the expensive path the registry exists to avoid *(completed)*
      paying routinely; it is manual/occasional and is never called from `deploy-headless.sh`.
- [x] Make `--discover` degrade cleanly on an unreadable root (skip with a named note, never abort). *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Verification**:
- `--discover` on this machine rediscovers the registered set and reports no `UNREGISTERED` rows
  (or reports exactly the ones genuinely missing).
- Temporarily removing one entry from the registry makes that repo appear as `UNREGISTERED`.
- The registry file is byte-identical before and after a `--discover` run.

---

### Phase 4: Post-deploy stale-consumer report in `deploy-headless.sh` [COMPLETED]

**Goal**: A deploy here ends by naming which known consumer repos are now stale. This is
acceptance criterion (b).

**Tasks**:
- [x] Inside `main()` (never at top level — see the script's SELF-OVERWRITE HAZARD header), change *(completed)*
      the trailing verify block to capture the verify outcome into a local variable instead of
      exiting directly from each branch.
- [x] After the verify outcome is captured and its message printed, call the consumer report, *(completed)*
      fully guarded: only when not `--dry-run`, only when
      `"$TARGET/.claude/scripts/check-consumer-freshness.sh"` exists, and always suffixed with
      `|| true` so no failure can propagate.
- [x] Invoke it as `--stale-only`, prefixed with a line such as *(completed)*
      `[deploy-headless] Known consumer repos now stale relative to the source store:`, and print a
      short "these need their own reload" remedy line naming `deploy-headless.sh` run *in that repo*.
- [x] Exit with exactly the captured verify code (`0` or `3`) after the report. Re-read the *(completed)*
      script's `# Exit codes:` header block and confirm all four codes still mean exactly what it
      says.
- [x] Add an inline comment stating this block reports only and MUST NOT deploy into any named *(completed)*
      consumer, citing `context/patterns/regeneration-is-manual-only.md`'s pull-only design.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: The hook site is hypothesized to be the `verify-deploy.sh --skip-slow` block
at the end of `main()`, and the only two success-side exits are `0` and `3`. Confirm at
implementation time by re-reading `main()` end-to-end and by `grep -n 'exit ' ` over the whole
script to enumerate every exit path before editing any of them.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` - capture verify result, add guarded
  consumer report before the final exit

**Verification**:
- `bash -n` passes.
- `deploy-headless.sh --dry-run` still returns 0 and prints no consumer report.
- A real resync in this repo exits 0 and prints the consumer report as its last output.
- Simulating a verify failure still exits 3 (test with a temporarily stubbed `verify-deploy.sh`
  in a scratch copy, never by breaking the real tree).
- Deleting the deployed `check-consumer-freshness.sh` makes the deploy still exit 0 silently.

---

### Phase 5: Tier-1 consecutive-ignore escalation + runtime-file registration [COMPLETED]

**Goal**: Decide and implement acceptance criterion (c): a tier-1 WARN ignored N times in a row
escalates its presentation — visibility only, never blocking.

**Decision recorded**: escalate, but **never block**. Tier 2 already provides the blocking
backstop for this repo's own commits, and a cross-repo blocking mechanism has no enforcement lever
anyway (this repo cannot compel a consumer's commands to run). The counter is **consecutive
command invocations**, not wall-clock days: the check only ever fires on an invocation, so
invocations are the honest measure of "how many chances did the operator have to notice", and a
day-based check would add a timestamp-diffing dependency for a weaker signal.

**Tasks**:
- [x] In `check-deploy-freshness.sh`, after computing `STALE_NAMES`: if the set is non-empty, *(completed)*
      increment a streak counter; if empty, reset it (deleting the file).
- [x] Store the counter at `<repo_root>/specs/.freshness-warn-streak.json` as *(completed)*
      `{"streak": N, "extensions": [...], "updated": "<ISO8601>"}`. Skip counter I/O silently when
      `<repo_root>/specs/` does not exist or is not writable, or when `jq` is unavailable.
- [x] Threshold: at `streak >= 5`, print an escalated multi-line banner naming the consecutive *(completed)*
      count and the remedy, in addition to (not instead of) the existing per-extension WARN lines.
      Below the threshold, output is byte-identical to today's.
- [x] Cap the stored streak at 999 so the file cannot grow unbounded in value. *(completed)*
- [x] Preserve the existing contract exactly: `set -uo pipefail` (not `-e`), always `exit 0`, *(completed)*
      every new step degrading to a silent skip. Do not touch `deploy-freshness-lib.sh`.
- [x] Document in the script header that a reset also happens on a `CANNOTVERIFY` result, because *(completed)*
      tier 1 deliberately collapses fresh and cannot-verify into the same silence — this is an
      accepted, named consequence of that collapse, not an oversight.
- [x] Add `**/.freshness-warn-streak.json` to this repo's OWN root `.gitignore` *(deviation: altered — root-files/.gitignore deploys only into a consumer's `.claude/` directory per this same standard's "Consumer Repo Setup" section, so a specs/-rooted pattern placed there would resolve to `.claude/specs/...` and match nothing; the correct target, verified by grepping every existing sibling ephemeral-file registration site, is this repo's own top-level `.gitignore` plus the documented "Consumer Repo Setup" block in orchestrator-runtime-files.md, both of which now carry the pattern)*
      alongside the existing ephemeral-runtime patterns.
- [x] Add a row for the file to the two-class table in *(completed)*
      `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (writer:
      `check-deploy-freshness.sh`; reader: same; cleanup: reset-on-fresh; disposition:
      **Ephemeral**), with a note that it is a freshness-check runtime file rather than an
      orchestrator one and is listed here because this file is the repo's single runtime-file policy home.
- [x] Add `specs/.freshness-warn-streak.json` to `check-runtime-file-tracking.sh`'s *(completed)*
      `EPHEMERAL_PROBES` array.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: The registration surfaces for a new ephemeral runtime file are hypothesized
to be exactly three (`root-files/.gitignore`, `orchestrator-runtime-files.md`'s table,
`check-runtime-file-tracking.sh`'s `EPHEMERAL_PROBES`). Confirm at implementation time by running
`bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` after the change and by
`grep -rn '.orchestrator-churn-state.json' agent-system/extensions/core/` to enumerate every place
an existing sibling ephemeral file is registered, then matching that set.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` - streak counter + escalated banner
- `.gitignore` (repo root, NOT `agent-system/extensions/core/root-files/.gitignore` — see the
  deviation note on the gitignore task above) - ignore the streak file
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - register the
  class (table row) AND add the pattern to the "Consumer Repo Setup" documented block
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - add the probe

**Verification**:
- `bash -n` passes on both edited scripts.
- Script still exits 0 in every path, including with the counter file absent, unwritable, or
  containing invalid JSON.
- Five consecutive runs against a stale fixture produce the escalated banner on the fifth; a run
  against a fresh fixture removes the counter file.
- `git check-ignore -v specs/.freshness-warn-streak.json` reports the new pattern.
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0.

---

### Phase 6: Fixture test suite [NOT STARTED]

**Goal**: Pin the new report's status branches, exit codes, and the escalation counter so a future
edit cannot silently regress them.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh`, following
      the structure of the existing `tests/test-deploy-freshness.sh`.
- [ ] Fixtures: temp consumer repos with synthetic `.claude-extensions.json` files (fresh head,
      stale head, missing `source_git_head`, missing directory, missing extension state) plus a
      temp registry pointing at them, injected via an env-var override the script reads for its
      registry path (add that override in Phase 2 if not already present, or inject via a
      scratch `$SCRIPT_DIR` layout).
- [ ] Assert: one row per registered consumer; correct `STALE`/`FRESH`/`CANNOTVERIFY`/`MISSING`/
      `NOEXTSTATE` classification; exit `0` with no stale, `1` with a stale, `2` with a missing
      registry; `--stale-only` suppresses `FRESH` rows; `--discover` reports an unregistered repo.
- [ ] Assert the no-write invariant: consumer fixture directories are byte-identical before and
      after a run.
- [ ] Add streak-counter cases (increment, threshold banner at 5, reset on fresh, cap, silent skip
      with no `specs/`) either in this suite or appended to `tests/test-deploy-freshness.sh`.
- [ ] Register `tests/test-consumer-freshness.sh` in `manifest.json`'s `provides.scripts`
      (`tests/run-all.sh` auto-discovers `tests/test-*.sh`, but rule Q still requires the manifest entry).
- [ ] `chmod +x` the test file.

**Timing**: 1.25 hours

**Depends on**: 2, 3, 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` - NEW suite
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - streak cases (if added here)
- `agent-system/extensions/core/manifest.json` - register the new test

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes with no new failures.
- All fixtures are created under a temp directory and removed on exit; no real consumer repo is
  touched by the suite.

---

### Phase 7: Documentation — tier 3 and the utility inventory [NOT STARTED]

**Goal**: Record the fleet report as an explicit third tier of the staleness model, and catalogue
the new operator-facing script.

**Tasks**:
- [ ] In `context/patterns/regeneration-is-manual-only.md`'s `## Detecting When You're Stale`
      section, add a clearly-labeled additive subsection **"Tier 3 (fleet report,
      source-repo-initiated, opt-in)"** naming the registry path, the script, its exit-code
      contract, its deliberate report-everything posture (contrasted with tier 1's silence), and
      the explicit no-push invariant.
- [ ] Update the existing "A now-two-tier staleness model" paragraph to a three-tier model,
      extending rather than rewriting the tier-1/tier-2 description already there.
- [ ] Document the tier-1 consecutive-ignore escalation in that same section: the threshold, that
      it counts invocations not days, that it remains exit-0 and non-blocking, and that a
      `CANNOTVERIFY` result resets the counter.
- [ ] Document the post-deploy consumer report in the `## Automated Exception` /
      `### deploy-headless.sh's Inline Verification and Exit Code 3` neighborhood, stating that it
      is additive output that does not change the 0/1/2/3 contract.
- [ ] Add `## Related Documentation` entries for `scripts/check-consumer-freshness.sh`,
      `context/reference/known-consumer-repos.json`, and `scripts/tests/test-consumer-freshness.sh`.
- [ ] Add an entry for `.claude/scripts/check-consumer-freshness.sh` to
      `docs/reference/utility-scripts-inventory.md`, matching that file's existing one-line style.
- [ ] Verify no task-number references appear in any file touched outside `specs/**` (per
      `.claude/rules/no-task-references-in-deliverables.md`); cite filenames and section headings
      as durable anchors instead.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - tier 3 section,
  three-tier model update, escalation and deploy-hook documentation, related-docs entries
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - new script entry

**Verification**:
- Every changed hunk is prose/markdown only.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no new violations.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes.
- Every path named in the new documentation exists on disk.

---

## Testing & Validation

- [ ] `bash -n` clean on `check-consumer-freshness.sh`, `check-deploy-freshness.sh`,
      `deploy-headless.sh`, `check-runtime-file-tracking.sh`, and the new test file.
- [ ] `jq empty` clean on `known-consumer-repos.json` and `manifest.json`.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no new violations.
- [ ] **Acceptance (a)**: one command run from this repo prints every registered consumer's
      per-extension revision status and flags those behind source.
- [ ] **Acceptance (b)**: a real `deploy-headless.sh` run in this repo ends by naming the stale
      known consumers, and still exits 0.
- [ ] **Acceptance (c)**: the escalation decision is implemented and documented; the fifth
      consecutive stale run produces the escalated banner and still exits 0.
- [ ] **No-push invariant**: no consumer repo's working tree or `.claude/` tree is modified by any
      command added in this plan (spot-check `git -C <consumer> status --porcelain` before/after).

## Artifacts & Outputs

- `agent-system/extensions/core/context/reference/known-consumer-repos.json` (new)
- `agent-system/extensions/core/scripts/check-consumer-freshness.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` (new)
- Edits to `manifest.json`, `check-deploy-freshness.sh`, `deploy-headless.sh`,
  `check-runtime-file-tracking.sh`, `root-files/.gitignore`,
  `context/patterns/regeneration-is-manual-only.md`,
  `context/standards/orchestrator-runtime-files.md`,
  `docs/reference/utility-scripts-inventory.md`
- `specs/093_close_cross_repo_deploy_skew/summaries/01_*-summary.md` at completion

## Rollback/Contingency

- Every phase commits separately, so any single phase can be reverted with `git revert` without
  disturbing the others.
- Phases 1, 2, 3, and 6 are purely additive (new files plus manifest lines); reverting them
  removes the new capability and nothing else.
- Phase 4 is the highest-risk revert target: if a deploy regression appears, revert
  `deploy-headless.sh` alone — the report is optional output and its absence restores the exact
  prior behavior.
- Phase 5's escalation degrades safely by construction; if the counter misbehaves, deleting
  `specs/.freshness-warn-streak.json` resets it, and reverting `check-deploy-freshness.sh` alone
  restores the pre-escalation tier-1 behavior with no other file needing to change.
- Nothing in this plan mutates a consumer repo, so no rollback ever needs to reach outside this
  repository.
