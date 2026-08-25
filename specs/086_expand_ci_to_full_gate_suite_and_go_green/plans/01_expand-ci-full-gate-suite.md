# Implementation Plan: Task #86

- **Task**: 86 - Expand ci to full gate suite and go green
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: 82 (Wire deploy verification into deploy headless) — COMPLETED, verified in code
- **Research Inputs**: specs/086_expand_ci_to_full_gate_suite_and_go_green/reports/01_expand-ci-full-gate-suite.md
- **Artifacts**: plans/01_expand-ci-full-gate-suite.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The repository's only CI workflow runs one gate script from a path that does not exist in a fresh
checkout (`.claude/` is fully gitignored), so it has failed with exit 127 on both of its two
historical runs and has never executed a single substantive check. This plan makes CI materialize
the deploy tree first, then run `verify-deploy.sh` — the same aggregator `deploy-headless.sh`
already invokes locally — as the single shared definition of "verified", and clears the 19 live
gate failures blocking green. Definition of done: a clean-clone rehearsal of the exact CI step
sequence passes end to end, and the same rehearsal with a deliberately reintroduced `line_count`
mismatch fails.

### Research Integration

Key findings carried forward from `reports/01_expand-ci-full-gate-suite.md`:

- **`.claude/` is gitignored** (`git ls-files .claude` = 0). This is the load-bearing constraint:
  every gate that inspects deployed files requires a deploy step in CI first. It is why both
  historical runs died at `bash: .claude/scripts/check-extension-docs.sh: No such file or directory`.
- **Task 82 landed for real**: `deploy-headless.sh` now invokes
  `bash "$TARGET/.claude/scripts/verify-deploy.sh" --skip-slow "$TARGET"`, satisfying SCOPE's
  "once it is callable" precondition. `verify-deploy.sh` is the aggregator to use.
- **The task body's 16-issue list is stale.** Re-confirmed live at plan time: **19 issues** —
  16 Rule R `line_count` mismatches (14 core, 2 typst) and 3 Rule S index-entry gaps. None of the
  task body's `skill-base.sh` drift, its 5 literature script drifts, or its
  `literature-index.md 144->117` item still appear.
- **Everything else already passes**: a live `verify-deploy.sh --skip-slow` run reports 1 of 23
  checks failing (the doc-lint), so the suite is green apart from Rule R/S.
- Research flagged the nvim/lazy.nvim bootstrap as "the single largest new CI-infrastructure item"
  — see the decision below, which removes it.

**Plan-time finding that supersedes research recommendation 5**: research assumed CI must pay a
full `lazy.nvim` + plugin bootstrap because `deploy-headless.sh` runs `nvim --headless` with no
`-u` override. Verified directly at plan time that this is avoidable:

```
nvim --headless --clean --cmd "set rtp+=/home/benjamin/.config/nvim" \
  -c "lua local c=require('neotex.plugins.ai.shared.extensions.config'); \
      local i=require('neotex.plugins.ai.shared.extensions.init'); \
      local ok,m=pcall(i.create, c.claude()); print('create='..tostring(ok))" -c "qa!"
```

returns `create=true` and exposes the full manager API (`load`, `resync_all`, `verify_all`,
`find_orphans`, `wipe`, ...). The extension manager has **no plugin dependency**. Phase 4
therefore adds a minimal-init escape hatch rather than an `actions/cache` plugin-warming step;
research's caching recommendation is retained only as the documented fallback (see
Rollback/Contingency).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`roadmap_path` was not supplied in the delegation context, so no roadmap phases are added and
`specs/ROADMAP.md` is untouched by this plan. Read-only for alignment: ROADMAP.md Phase 1
("Documentation Infrastructure") carries **"CI enforcement of doc-lint"** — "Add a GitHub Actions
workflow that runs `.claude/scripts/check-extension-docs.sh` on every push and fails the build on
doc drift" — which this task supersedes and exceeds (full aggregator, not the single doc-lint).
Success Metric "Doc-lint script exits 0 on every commit" is also advanced. A separate
`/plan --roadmap` pass or the `/todo` sweep may mark that item; this plan does not.

## Goals & Non-Goals

**Goals**:
- CI materializes `.claude/` from the source store on a fresh checkout, then runs the full gate
  suite via the one aggregator `deploy-headless.sh` also uses (`verify-deploy.sh`) — one
  definition of "verified", not two.
- All 19 live gate failures fixed at the source, with no lint relaxation, suppression, or
  allow-listing.
- `check-runtime-file-tracking.sh` — currently a gate script with zero callers anywhere in the
  repo — wired into the aggregator, so "all nine gates" is true rather than nearly true.
- CI runs without a `lazy.nvim` / plugin bootstrap, keeping the job fast and removing the
  network-flakiness surface that would otherwise threaten "keep it green".
- The reintroduced-`line_count`-mismatch acceptance test demonstrated locally against the exact
  command sequence CI runs.

**Non-Goals**:
- Un-gitignoring `.claude/` or committing the deploy tree. It stays a disposable artifact.
- Wiring `check-consumer-freshness.sh` into CI. It is by design an opt-in whole-fleet audit of
  other repos, not a per-repo gate; running it in this repo's CI would assert on repositories the
  runner has never checked out. Excluded deliberately and documented in the workflow file.
- Wiring `check-deploy-freshness.sh` into CI. Its own header states it "ALWAYS EXITS 0 ... this is
  not a preflight gate" — it is structurally incapable of failing a build.
- Pushing branches, opening PRs, or triggering a live Actions run. Prohibited by
  `.claude/rules/pr-prohibition.md`; the live-CI confirmation is a user handoff step (Phase 7).
- Relaxing, skipping, or reordering any existing gate to reach green.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `line_count` drift is a moving target; any doc edit between phases reintroduces a mismatch | M | H | Run `generate-context-line-counts.sh --write` as the LAST content change (Phase 7), after every doc-touching phase has landed; never trust this plan's counts verbatim |
| `manager.load`/`resync_all` internals turn out to need a plugin under `--clean`, unlike `create()` | H | L | Phase 4 opens with a decisive end-to-end probe into a scratch clone BEFORE any script edit; on failure, fall back to research recommendation 5 (install nvim + `actions/cache` on `lazy-lock.json`) |
| Adding a 14th gate to `verify-deploy.sh` breaks its documented `gate0..gate13` findings contract for its automated consumer (`skill-orchestrate` Stage MT-3) | M | M | Phase 3 greps for every gate-count/label reference and updates them in the same commit; findings labels are append-only (`gate14`), never renumbered |
| Full (non-`--skip-slow`) run in CI is slow — gate 8 alone was measured at 117.9s of a ~2.8min total | L | H | Accepted: ACCEPTANCE says "runs the full suite". ~3min plus a deploy is acceptable for a push gate; revisit only if it becomes a bottleneck |
| Agent cannot verify the real Actions run (no push/PR permitted) | M | H | Phase 6 rehearses the exact step sequence in a clean clone, which reproduces the gitignored-`.claude/` condition faithfully; Phase 7 hands the live confirmation to the user with the precise steps |
| Deploying into a scratch clone during rehearsal accidentally writes to the working repo | H | L | Always pass the scratch path as an explicit `TARGET` argument; `deploy-headless.sh` derives `project_dir` from the explicit option, never implicitly from cwd |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 4, 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Re-derive the live gate baseline [COMPLETED]

**Goal**: Establish the authoritative, current failing set from a live run — not from the task
body (confirmed stale) and not from this plan's transcription of it.

**Tasks**:
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and capture the full Rule R / Rule S
      issue list and the total count *(completed: 19 issues confirmed, matches plan)*
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --check` and capture the
      per-extension mismatch tallies *(completed: 16 mismatch, 0 null, 0 missing, matches plan)*
- [x] Run `bash .claude/scripts/verify-deploy.sh --findings --quiet --skip-slow` and capture the
      `FINDING ` lines (`grep '^FINDING ' | sort -u`) as the pre-change findings baseline
      *(completed: 1 of 23 checks failed, 19 FINDING lines under gate3)*
- [x] Run `bash .claude/scripts/check-runtime-file-tracking.sh` and record its exit code (expected
      0 — Phase 3 must not wire in a gate that is already red) *(completed: exit 0)*
- [x] Record all four captures in the task's progress file; note any divergence from this plan's
      numbers and treat the live capture as authoritative from here on *(completed: no divergence)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts 19 issues (16 Rule R — 14 core, 2 typst — and 3 Rule S:
`context/contracts/return-meta-artifacts-template.md`,
`context/project/literature/domain/corpus-directory-conventions.md`,
`context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`), and that
`check-runtime-file-tracking.sh` currently exits 0. Confirm by the four commands above before any
edit; if the set differs, the live set wins and Phases 2 and 7 adjust to it.

**Files to modify**:
- none (measurement only; captures go in the task progress file)

**Verification**:
- Four captures recorded, each with the exact command that produced it
- Any divergence from this plan's asserted set explicitly named

---

### Phase 2: Author the 3 missing index entries (Rule S) [COMPLETED]

**Goal**: Close the three Rule S failures with real, schema-conformant index entries in the
source store — not by suppressing the rule.

**Tasks**:
- [x] Read each orphaned file's actual content before writing its summary (do not infer from the
      filename): `context/contracts/return-meta-artifacts-template.md`,
      `context/project/literature/domain/corpus-directory-conventions.md`,
      `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`
      *(completed)*
- [x] Model each new entry on a sibling in the same subdomain — `contracts/wrap-up.md`'s entry in
      `agent-system/extensions/core/index-entries.json` for the return-meta template; existing
      `project/literature/domain/*` and `project/literature/patterns/*` entries in
      `agent-system/extensions/literature/index-entries.json` for the other two *(completed)*
- [x] Write each entry with all required fields: `summary`, `path`, `topics`, `on_demand`,
      `line_count`, `load_when.{commands,task_types,agents}`, `keywords`, `subdomain`, `domain`
      *(completed)*
- [x] Set each `line_count` from a live `wc -l` at edit time, not from this plan's numbers
      *(completed: 96, 143, 60)*
- [x] Validate both JSON files parse (`jq . <file> >/dev/null`) *(completed)*
- [x] Redeploy so `.claude/context/index.json` picks up the new entries, then re-run
      `bash .claude/scripts/check-extension-docs.sh` and confirm the Rule S count drops to 0
      *(completed: 19 -> 16 issues, Rule S 0)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly 3 files lack an index entry, and no entry exists for any of them in
*any* extension's `index-entries.json`. Confirm before authoring with
`grep -rl "return-meta-artifacts-template\|corpus-directory-conventions\|shared-module-extraction-for-gate-checks" agent-system/extensions/*/index-entries.json`
(expected: 0 hits). A hit means an entry exists with a wrong path and must be corrected rather
than duplicated.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` — add 1 entry for
  `contracts/return-meta-artifacts-template.md`
- `agent-system/extensions/literature/index-entries.json` — add 2 entries for the
  `domain/corpus-directory-conventions.md` and
  `patterns/shared-module-extraction-for-gate-checks.md` files

**Verification**:
- `jq .` parses both files
- `check-extension-docs.sh` reports 0 Rule S failures (Rule R failures still expected here)
- Each new entry's `line_count` equals a fresh `wc -l` of its source file

---

### Phase 3: Wire check-runtime-file-tracking.sh into verify-deploy.sh [COMPLETED]

**Goal**: Make the aggregator actually cover the nine gate scripts by adding the one genuine
per-repo gate that has zero callers anywhere in the repo today.

**Tasks**:
- [x] Add a new gate to `agent-system/extensions/core/scripts/verify-deploy.sh` invoking
      `check-runtime-file-tracking.sh` from the repo root of `$TARGET`, following the existing
      gate pattern exactly (prints the command it stands for, increments `CHECKS`/`FAILURES`,
      emits a `FINDING gate14 ...` line under `--findings`) *(completed)*
- [x] Use the next free label `gate14` — append, never renumber existing gate labels; the
      documented consumer contract (`skill-orchestrate` Stage MT-3 step 7) diffs sorted
      `FINDING ` lines and must not see spurious churn *(completed)*
- [x] Decide and document whether the new gate is fast (it is — three `git check-ignore` sweeps)
      and therefore NOT deferred by `--skip-slow`; `--skip-slow` must continue to skip gate 8 only
      *(completed: gate14 always runs, not gated on --skip-slow)*
- [x] Update the script header: "fourteen gates" -> fifteen, `gate0 through gate13` ->
      `gate0 through gate14`, `gate0`..`gate13` -> `gate0`..`gate14` *(completed)*
- [x] Grep for every other reference to the gate count or label range and update each in this same
      commit — start from `grep -rn "gate13\|fourteen gates\|gate0\.\.gate13" agent-system/extensions`
      and widen to `regeneration-is-manual-only.md` and `batch-orchestration-guardrails.md`, both
      of which document this script's contract *(completed: 0 hits in either file, no edit needed)*
- [x] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --skip-slow` and
      diff its `FINDING ` set against the Phase 1 baseline: the only delta may be gate-14 lines
      *(completed: only delta is the 3 Rule S lines Phase 2 removed; gate14 passed with 0 findings)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This plan asserts the gate-count/label references are confined to
`verify-deploy.sh`'s header plus its two documenting context files. Confirm with the greps above
before editing; every hit found must be updated, and the actual hit list recorded in the progress
file rather than assumed to match this plan.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new gate 14 + header text
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — gate-count
  reference, if the grep confirms one
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — gate-count
  reference, if the grep confirms one

**Verification**:
- `bash -n` clean; `--help` renders the updated header
- Findings diff vs. Phase 1 baseline shows only gate-14 additions
- `--skip-slow` still skips exactly gate 8, and gate 14 runs under it
- Exit code unchanged from baseline apart from the (expected-passing) new gate

---

### Phase 4: Add a minimal-init escape hatch for the headless nvim calls [NOT STARTED]

**Goal**: Let CI drive the deploy and the two nvim-backed gates without loading `init.lua` — no
`lazy.nvim` bootstrap, no plugin clones, no network dependency beyond the checkout.

**Tasks**:
- [ ] **Probe first, edit second.** Clone the repo into the scratchpad, then run a full deploy
      into it using the `--clean`-style invocation directly (`nvim --headless --clean
      --cmd "set rtp+=<checkout>"` plus the existing `manager.load('core', {force=true,
      project_dir=...})` + `manager.resync_all` lua). Confirm `DEPLOY_COUNT=` is emitted and
      `.claude/` is populated. If this fails, STOP and take the Rollback/Contingency fallback
      instead of proceeding with the escape hatch.
- [ ] Add an opt-in escape hatch to `agent-system/extensions/core/scripts/deploy-headless.sh`
      that injects `--clean --cmd "set rtp+=<rtp dir>"` into its nvim invocation. Default OFF —
      absent the opt-in, behavior must be byte-for-byte unchanged, matching the additive-flag
      convention `--findings` and `--skip-slow` already follow in `verify-deploy.sh`
- [ ] The rtp directory is the **nvim config directory**, which is not always `$TARGET` (for a
      consumer repo they differ; in CI they coincide). Make it explicit and overridable rather
      than derived from `$TARGET`
- [ ] Apply the same escape hatch to `verify-deploy.sh`'s two nvim call sites (`verify_all` gate
      and `find_orphans` gate), so the whole CI path is consistent
- [ ] Document the hatch in both script headers, stating plainly that it is for CI/container
      environments with no user nvim config and that it changes nothing when unset
- [ ] Re-run the scratch-clone deploy through the real `deploy-headless.sh` with the hatch on, and
      confirm the deploy lands and its inline `verify-deploy.sh --skip-slow` runs

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The extension manager has no plugin dependency, so the full deploy path
(`manager.load` + `manager.resync_all`) and both nvim-backed gates succeed under `nvim --clean`
with only `rtp` set. Verified at plan time only for `require` + `create()` (which returned
`create=true` and the full function set); the load/resync/verify/orphan paths are UNCONFIRMED and
the opening probe step exists specifically to confirm them before any script is edited.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` — opt-in minimal-init hatch + header
- `agent-system/extensions/core/scripts/verify-deploy.sh` — same hatch at both nvim call sites

**Verification**:
- With the hatch unset, a local `deploy-headless.sh --dry-run` and a `verify-deploy.sh
  --findings --skip-slow` produce output identical to the Phase 1/Phase 3 baselines
- With the hatch set, a deploy into the scratch clone populates `.claude/` and reports a
  `DEPLOY_COUNT`
- `bash -n` clean on both scripts

---

### Phase 5: Rewrite the CI workflow to deploy-then-verify [NOT STARTED]

**Goal**: Replace the single missing-file invocation with a deploy step followed by the full
aggregator run, so CI and local deploy share one entry point.

**Tasks**:
- [ ] Rewrite `.github/workflows/check-extension-docs.yml`: rename the workflow and job to reflect
      that it now runs the full gate suite, not just the doc-lint
- [ ] Steps: checkout (`actions/checkout@v4`) -> install neovim on the runner (not preinstalled on
      `ubuntu-latest`) -> deploy `.claude/` via `deploy-headless.sh` with the Phase 4 minimal-init
      hatch enabled and the checkout as explicit `TARGET` -> run
      `bash .claude/scripts/verify-deploy.sh "$GITHUB_WORKSPACE"`
- [ ] Run the aggregator **without** `--skip-slow`: ACCEPTANCE says "CI runs the full suite", and
      the deferred gate 8 (`tests/run-all.sh`) is exactly the kind of coverage a push gate should
      not silently drop. Record this as a deliberate choice in a workflow comment
- [ ] Add `--findings` so a red build's log carries the machine-diffable `FINDING ` set, not just
      a narrative failure
- [ ] Treat `verify-deploy.sh` exit 2 ("cannot run") as failure, per that script's own header —
      never as a pass. Confirm no step swallows a non-zero exit (no `|| true`, no `continue-on-error`)
- [ ] Comment in the YAML which gate scripts are deliberately NOT run and why:
      `check-deploy-freshness.sh` (always exits 0, structurally cannot gate) and
      `check-consumer-freshness.sh` (opt-in whole-fleet audit of other repos, not a per-repo gate)
- [ ] Keep the existing triggers (`push` to master, `pull_request`) — ACCEPTANCE requires every push
- [ ] Lint the YAML for syntax before committing

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `.github/workflows/check-extension-docs.yml` — full rewrite

**Verification**:
- YAML parses
- Every step's command is one an operator can copy and run locally verbatim
- No step can mask a non-zero exit code
- The two deliberate gate exclusions are named in comments, not silently absent

---

### Phase 6: Clean-clone CI rehearsal and the reintroduced-mismatch negative test [NOT STARTED]

**Goal**: Prove the workflow green, and prove it actually fails on a real regression — the
ACCEPTANCE criterion — without pushing anything.

**Tasks**:
- [ ] `git clone` the repo into the scratchpad. This faithfully reproduces the CI condition: the
      clone has no `.claude/` (gitignored), exactly like a fresh Actions checkout. Confirm with
      `test ! -d <clone>/.claude`
- [ ] Execute the Phase 5 workflow's step commands against the clone, in order, verbatim — do not
      substitute a shortcut or reuse the working repo's already-deployed `.claude/`
- [ ] **Positive case**: confirm the full `verify-deploy.sh` run exits 0 with 0 findings. If any
      gate fails, fix the underlying cause at the source and re-run — do not relax the gate
- [ ] **Negative case (ACCEPTANCE)**: in the clone, add one line to any indexed `.md` file whose
      `line_count` is declared in an `index-entries.json`, re-run the same command sequence from
      the top, and confirm the run exits non-zero with a Rule R `line_count` mismatch naming that
      file. Capture the exact failing output
- [ ] Revert the deliberate edit in the clone and confirm the sequence returns to green
- [ ] Record both transcripts (green run, red run) in the task progress file as the acceptance
      evidence
- [ ] Delete the scratch clone

**Timing**: 1.5 hours

**Depends on**: 2, 4, 5

**Verification Tier**: full

**Files to modify**:
- none in the repo (all work happens in a scratchpad clone; fixes discovered here are made in the
  working repo and re-rehearsed)

**Verification**:
- Green transcript: clean clone with no `.claude/` -> deploy -> `verify-deploy.sh` exit 0, empty
  `FINDING ` set
- Red transcript: same sequence with a one-line doc edit -> non-zero exit, Rule R mismatch naming
  the edited file
- Both transcripts show the same command sequence as the committed YAML

---

### Phase 7: Capture the CI bootstrap pattern, regenerate line counts, confirm green [NOT STARTED]

**Goal**: Absorb all doc churn from every prior phase into a final `line_count` regeneration,
capture the working CI recipe so it never has to be re-derived, and leave the suite green.

**Tasks**:
- [ ] Write `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` capturing
      the recipe: `.claude/` is gitignored and absent in any fresh checkout; CI must deploy before
      any gate touching deployed files can run; the extension manager needs no plugins so the
      minimal-init hatch avoids a `lazy.nvim` bootstrap; the aggregator is `verify-deploy.sh` and
      exit 2 counts as failure. This closes research recommendation 6, whose stated cost was
      several tool calls of rediscovery per future CI task
- [ ] Add a matching entry for the new doc to `agent-system/extensions/core/index-entries.json`
      (same field set as Phase 2) — a new context file without an entry reintroduces Rule S
- [ ] Redeploy, then run `bash .claude/scripts/generate-context-line-counts.sh --check` to see the
      full accumulated mismatch set (Phase 3's doc edits, this phase's new doc, and the 16
      pre-existing mismatches)
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --write` **from the deployed copy**
      — the source-store copy refuses to run with a guard error. It rewrites the source-store
      `index-entries.json` files in place via line-oriented substitution, so the diff must be
      `line_count`-only; review `git diff` to confirm that
- [ ] Redeploy and re-run `bash .claude/scripts/check-extension-docs.sh`: expect 0 issues
- [ ] Run the full `bash .claude/scripts/verify-deploy.sh --findings` (no `--skip-slow`) and
      confirm exit 0 with an empty findings set
- [ ] Write the user handoff note: the live-CI confirmation (push to a branch, watch the Actions
      run go green, then reintroduce a mismatch and watch it go red) requires a push and is
      therefore the user's step after `/merge` — agents may not push or open PRs per
      `.claude/rules/pr-prohibition.md`. Give the exact commands

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: This plan asserts the final regeneration resolves 16 pre-existing mismatches
plus whatever Phase 3 and this phase's doc edits added. Confirm with `--check` immediately before
`--write` and record the actual delta; the pre-existing count in particular is a moving target and
must not be transcribed from this plan.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` — new
- `agent-system/extensions/core/index-entries.json` — new entry + regenerated `line_count`s
- `agent-system/extensions/typst/index-entries.json` — regenerated `line_count`s
- `agent-system/extensions/literature/index-entries.json` — regenerated `line_count`s if affected

**Verification**:
- `generate-context-line-counts.sh --check` reports 0 mismatch, 0 null, 0 missing source
- `check-extension-docs.sh` reports 0 issues across all extensions and project-wide
- Full `verify-deploy.sh --findings` exits 0 with an empty `FINDING ` set
- `git diff` on the regenerated files shows `line_count` value changes only (plus the one new
  entry), no reformatting or re-serialization

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` -> 0 issues, every extension PASS
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` -> 0 mismatch, 0 null, 0 missing
- [ ] `bash .claude/scripts/verify-deploy.sh --findings` (full, no `--skip-slow`) -> exit 0, empty findings
- [ ] `bash .claude/scripts/check-runtime-file-tracking.sh` -> exit 0, and reachable as a gate via the aggregator
- [ ] Clean-clone rehearsal of the exact CI step sequence -> green (Phase 6 positive transcript)
- [ ] Same rehearsal with a deliberately reintroduced `line_count` mismatch -> red on Rule R (Phase 6 negative transcript; this is the ACCEPTANCE test)
- [ ] Minimal-init hatch unset -> `deploy-headless.sh` and `verify-deploy.sh` behavior byte-for-byte unchanged from the Phase 1 baseline
- [ ] `bash -n` clean on both modified shell scripts; `jq .` parses every modified `index-entries.json`
- [ ] No gate was relaxed, suppressed, allow-listed, or removed to reach green

## Artifacts & Outputs

- `.github/workflows/check-extension-docs.yml` — rewritten: deploy-then-verify, full suite
- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate 14 added, minimal-init hatch, header updated
- `agent-system/extensions/core/scripts/deploy-headless.sh` — minimal-init hatch, header updated
- `agent-system/extensions/core/index-entries.json` — 2 new entries, regenerated `line_count`s
- `agent-system/extensions/literature/index-entries.json` — 2 new entries
- `agent-system/extensions/typst/index-entries.json` — regenerated `line_count`s
- `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` — new pattern doc
- Possible gate-count reference updates in `regeneration-is-manual-only.md` and `batch-orchestration-guardrails.md`
- Task progress file: Phase 1 baseline captures, Phase 6 green/red transcripts, user handoff note
- `specs/086_expand_ci_to_full_gate_suite_and_go_green/summaries/01_*-summary.md`

## Rollback/Contingency

- **All changes are source-store edits plus one YAML file** — every phase is a small, independently
  revertable commit. `.claude/` is disposable: any bad deploy is undone by re-running
  `deploy-headless.sh` from a reverted source store.
- **If the Phase 4 probe fails** (the manager turns out to need a plugin under `--clean`): abandon
  the minimal-init hatch entirely, revert Phase 4, and fall back to research recommendation 5 —
  install neovim on the runner, let `init.lua` bootstrap `lazy.nvim` normally, and add
  `actions/cache` over `~/.local/share/nvim` and `~/.local/state/nvim` keyed on `lazy-lock.json`'s
  hash. Phases 5-7 proceed unchanged apart from the CI deploy step's invocation. This is slower and
  carries network-flakiness risk, which is why it is the fallback and not the primary path.
- **If the new gate 14 destabilizes the aggregator's consumer contract**: revert Phase 3 only. CI
  still runs the other gates via `verify-deploy.sh` and the task's core acceptance (green build,
  reintroduced mismatch fails) is unaffected — gate 14 is an improvement, not a precondition.
- **If CI proves too slow without `--skip-slow`**: do not silently switch. Either supplement an
  on-push fast run with a schedule-triggered full run, or get explicit sign-off that "full suite"
  means the fast gate set — research recommendation 4 names both options. Changing the invocation
  silently would recreate the two-definitions-of-verified drift this task exists to prevent.
- **Never** reach green by relaxing a lint, adding a suppression, or removing a gate. If a gate
  cannot be made to pass legitimately, mark the phase `[BLOCKED]` and surface it.
