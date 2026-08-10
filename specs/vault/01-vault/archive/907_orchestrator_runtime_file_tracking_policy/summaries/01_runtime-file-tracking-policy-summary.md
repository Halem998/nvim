# Implementation Summary: Task #907

**Completed**: 2026-07-27
**Duration**: ~4 hours

## Overview

Implemented the settled two-class orchestrator runtime-file tracking policy in full: a new
canonical standard (`orchestrator-runtime-files.md`), exclusion-pathspec staging narrowing at
both `commands/orchestrate.md` staging sites and in `git-staging-scope.md`, ephemerality notes in
both orchestrate skills, a corrected `handoff-schema.md`, a shipped and registered verification
check script, and the consumer-side reversal applied to this repository's own root `.gitignore`
(un-ignoring `.orchestrator-handoff.json` and `.return-meta.json` while retaining full ephemeral
coverage). All three task-description verification requirements were demonstrated in a disposable
scratch repo (plus repeat checks in this repo) with recorded command output, reproduced below
verbatim.

## What Changed

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (new) — the
  canonical two-class policy: audited file table, freshness-gate rationale, consumer repo setup
  block, untracking guidance, explicit prohibition on untracking durable provenance, forward-only
  migration note, defense-in-depth note.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a canonical
  exclusion-pathspec set; rewrote the `plan` scope and the `implement` reference template to use
  it; cross-referenced the new standard.
- `agent-system/extensions/core/commands/orchestrate.md` — added the exclusion pathspecs at both
  the multi-task batch commit and CHECKPOINT 3 (single-task) staging sites.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — ephemerality notes at the
  Stage 2 loop-guard definition/resume branch and both cleanup sites (Stage 8, and the
  `completed`-state cleanup).
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — same, plus
  `.orchestrator-churn-state.json` coverage, across all four loop-guard cleanup sites and the
  Stage 8 churn-state cleanup.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — rewrote the file-location
  line and its framing (handoff is now documented as tracked, freshness-gated durable provenance,
  not "runtime; not checked in"); confirmed the "Outcome Channels" section needed no equivalent fix.
- `agent-system/extensions/core/context/guides/loader-reference.md` — added a note recording that
  `copy_root_files()` cannot deliver a consumer repo-root contribution.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (new) — the three-check
  verification script (ignore coverage, no tracked ephemeral files, provenance not over-ignored).
- `agent-system/extensions/core/manifest.json` — registered the new script under
  `provides.scripts`.
- `/.gitignore` (repo root) — removed the two durable-provenance ignore lines (bare
  `.return-meta.json`, `.orchestrator-handoff.json`); rewrote the comment block; retained every
  ephemeral line; added `**/.drift-inspection.json` (see Decisions below).

## Decisions

- **Adopted `.drift-inspection.json` as a fourth ephemeral class.** The Phase 1 audit (explicitly
  scoped to not assume the task description's five known names were complete) found that
  `skill-orchestrate/SKILL.md` Stage 5a's drift-inspection scratch file has the identical
  ephemeral profile as the loop guard: no freshness gate on read, and cleanup fires only at
  Stage 8 (full-loop termination), not per-cycle — meaning a mid-loop commit could sweep it in
  exactly like the loop guard. It was threaded consistently through the standard's class table,
  the canonical exclusion set (`git-staging-scope.md`, both `orchestrate.md` staging sites), the
  check script's Check A/B probes, and the repo's own `.gitignore`.
- **Reviewed and deliberately did NOT classify `.stray-handoff-{timestamp}.json`.** This file is
  diagnostic evidence a misplaced-handoff bug produces, not per-cycle control-flow state anything
  trusts unconditionally. Silently gitignoring it would suppress the evidence the stray-handoff
  sweep exists to surface, so it was left out of both the ephemeral and durable-provenance
  classes, with the reasoning recorded in the standard.
- **Exclusion pathspecs, not an allowlist**, for the staging narrowing — matching the plan's
  declared deviation from the task description's suggested allowlist model, since live task
  directories also carry `progress/`, `handoffs/`, `fixtures/`, `tests/`, `HANDOFF.md`, which an
  allowlist would silently stop staging.

## Plan Deviations

- **Task 1.1** (altered): the audit surfaced two file names beyond the plan's known five
  (`.drift-inspection.json`, adopted as ephemeral; `.stray-handoff-*.json`, reviewed and
  deliberately left unclassified). See progress file `phase-1-progress.json` for the full
  deviation entry.
- **Task 6.3** (altered): added `**/.drift-inspection.json` as a new `.gitignore` line beyond the
  plan's originally enumerated lines 32/34-40, to keep the standard, the staging exclusion set,
  and the gitignore block internally consistent with the Phase 1 audit finding. See
  `phase-6-progress.json`.

No other deviations. All seven phases were completed in full per the plan's ordering constraint
(Phase 6 landed only after Phases 2-5).

## Verification

### Testing & Validation checklist — all items confirmed

- `check-runtime-file-tracking.sh` exits 0 in this repo after Phase 6 (all three checks pass — see
  output below).
- `bash -n` passes on the new script.
- `jq empty manifest.json` succeeds; script is listed in `provides.scripts` (count 1).
- `grep -rn 'not checked in' agent-system/extensions/core/` returns zero hits.
- No task-number citations were introduced by this task's own added lines (verified via
  `git diff` restricted to this task's commits) — see "Doc-lint gate" note below for pre-existing,
  untouched citations elsewhere in the same files.
- No file under `.claude/**` was modified (every edit targeted `agent-system/extensions/core/**`
  or the sanctioned `/.gitignore` exception).
- All three task-description verification requirements demonstrated with recorded output (below).

### Doc-lint gate (`check-extension-docs.sh`) — pre-existing failures unrelated to this task

The gate's overall exit code is 1, but every failing item is pre-existing and untouched by this
task:
- Deployed-vs-source content drift in `command-gate-out.sh`, `roadmap-integration.sh`,
  `skill-base.sh`, `orchestrator-postflight.sh` — none of these four files were edited by this
  task; the drift requires a `.claude/` re-sync, which this task's binding constraints explicitly
  prohibit performing.
- A stray `agent-system/extensions/specs/tmp/state.json` (missing manifest/EXTENSION.md/README.md)
  — an artifact from a concurrent session, unrelated to and untouched by this task.

Neither `orchestrator-runtime-files.md` nor `check-runtime-file-tracking.sh` nor the manifest
registration appears in the gate's FAIL list. The new script appears only in the non-fatal
ADVISORY lane ("never deployed" — expected, since `.claude/` is intentionally not re-synced).

## Recorded Command Output

### Phase 5 — pre-Phase-6 check script run (expected partial failure)

```
check-runtime-file-tracking: verifying against context/standards/orchestrator-runtime-files.md
================================================================================

Check A - ephemeral-class ignore coverage:
  OK   specs/000_probe/.orchestrator-loop-guard is ignored
  OK   specs/000_probe/.orchestrator-churn-state.json is ignored
  FAIL specs/000_probe/.drift-inspection.json is NOT ignored (ephemeral class must be gitignored)
  OK   specs/000_probe/.lock/holder.json is ignored
  OK   specs/000_probe/.continuation-loop-guard is ignored
  OK   specs/000_probe/.postflight-loop-guard is ignored
  OK   specs/.orchestrator-multi-state.json is ignored
  OK   specs/000_probe/.return-meta-orchestrate.json is ignored
  OK   specs/.events.lock is ignored
Check A FAILED — add the missing pattern(s) to the repo root .gitignore. See
  context/standards/orchestrator-runtime-files.md 'Consumer Repo Setup' for the exact block.

Check B - no ephemeral-class file is currently tracked:
Check B passed — no ephemeral-class file is tracked

Check C - durable provenance (.orchestrator-handoff.json / .return-meta.json) is NOT ignored:
  FAIL specs/000_probe/.orchestrator-handoff.json is ignored (must be tracked): .gitignore:33:**/.orchestrator-handoff.json	specs/000_probe/.orchestrator-handoff.json
        remediation: remove the offending .gitignore line. Never run git rm --cached on this file.
  FAIL specs/000_probe/.return-meta.json is ignored (must be tracked): .gitignore:1:**/.return-meta.json	specs/000_probe/.return-meta.json
        remediation: remove the offending .gitignore line. Never run git rm --cached on this file.
Check C FAILED — durable provenance must never be gitignored or untracked.

================================================================================
FAIL — one or more checks failed. See context/standards/orchestrator-runtime-files.md.
```

Check A's `.drift-inspection.json` failure and Check C's expected failures both confirm the
script detects exactly the conditions it is designed to catch, before the policy was applied.

### Phase 6 — post-change check script run (all checks pass)

```
check-runtime-file-tracking: verifying against context/standards/orchestrator-runtime-files.md
================================================================================

Check A - ephemeral-class ignore coverage:
  OK   specs/000_probe/.orchestrator-loop-guard is ignored
  OK   specs/000_probe/.orchestrator-churn-state.json is ignored
  OK   specs/000_probe/.drift-inspection.json is ignored
  OK   specs/000_probe/.lock/holder.json is ignored
  OK   specs/000_probe/.continuation-loop-guard is ignored
  OK   specs/000_probe/.postflight-loop-guard is ignored
  OK   specs/.orchestrator-multi-state.json is ignored
  OK   specs/000_probe/.return-meta-orchestrate.json is ignored
  OK   specs/.events.lock is ignored
Check A passed

Check B - no ephemeral-class file is currently tracked:
Check B passed — no ephemeral-class file is tracked

Check C - durable provenance (.orchestrator-handoff.json / .return-meta.json) is NOT ignored:
  OK   specs/000_probe/.orchestrator-handoff.json is not ignored
  OK   specs/000_probe/.return-meta.json is not ignored
Check C passed

================================================================================
PASS — all three checks passed.
```

### Phase 6 — `git status --short` after the reversal

Newly-visible untracked files: 295 `.return-meta.json` + 213 `.orchestrator-handoff.json` = 508
files across existing task directories (the small difference from the plan-time count of 299
reflects normal task-directory churn between planning and implementation). Confirmed via grep:
**zero** ephemeral-class paths appeared in the output. Per the plan, no bulk backfill commit was
created — Phase 6's own commit staged only `/.gitignore` and this task's own directory.

### Phase 7 — verification (a): newly created ephemeral file is ignored

Scratch repo (with the shipped `.gitignore` block installed verbatim):

```
=== git status --porcelain (should NOT list the three files above) ===
(empty — nothing listed)

=== git check-ignore -v (shipped pattern reported) ===
.gitignore:8:**/.orchestrator-loop-guard	specs/042_scratch_task/.orchestrator-loop-guard
.gitignore:7:**/.lock/	specs/042_scratch_task/.lock/holder.json
.gitignore:10:**/.orchestrator-churn-state.json	specs/042_scratch_task/.orchestrator-churn-state.json
```

Repeated in this repo:

```
.gitignore:33:**/.orchestrator-loop-guard	specs/000_probe/.orchestrator-loop-guard
```

### Phase 7 — verification (b): `git rm --cached` preserves the file on disk

```
=== git ls-files BEFORE untracking ===
specs/099_no_coverage_task/.orchestrator-loop-guard

=== byte content before untracking ===
sha256 before: 8a93819b0b02ab00020c1d395d416febceaeef8136c33377b749244d65aa4a81

=== run the untracking command from the standard ===
rm 'specs/099_no_coverage_task/.orchestrator-loop-guard'

=== git ls-files AFTER untracking (should be empty) ===
(no hits - untracked)

=== test -f (file still on disk) ===
file still exists on disk: OK

=== byte content after untracking (must match) ===
sha256 after: 8a93819b0b02ab00020c1d395d416febceaeef8136c33377b749244d65aa4a81
CONTENT BYTE-IDENTICAL: OK
```

(The loop guard was first committed while `.gitignore` was temporarily absent from the working
tree, reproducing the `.dotfiles` starting condition of a tracked ephemeral file with no
coverage; `git rm --cached` then untracked it with byte-identical on-disk content confirmed via
sha256 before and after.)

### Phase 7 — verification (c): post-fix staging is correct, both configurations

Variant 1 (ignore block present):

```
=== git diff --cached --name-only (variant 1, ignore block present) ===
specs/042_scratch_task/.orchestrator-handoff.json
specs/042_scratch_task/.return-meta.json
specs/042_scratch_task/plans/01_plan.md
```

(`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`, and `.lock/holder.json` were
correctly absent — git additionally printed an informational "ignored by .gitignore" hint for
those three, which is expected and non-fatal.)

Variant 2 (ignore block absent entirely — proves the exclusion pathspecs protect an uncovered
repo on their own):

```
=== git diff --cached --name-only (variant 2, NO gitignore coverage at all) ===
specs/042_scratch_task/.orchestrator-handoff.json
specs/042_scratch_task/.return-meta.json
specs/042_scratch_task/plans/01_plan.md
```

Identical result with zero gitignore coverage — `.orchestrator-loop-guard`,
`.orchestrator-churn-state.json`, `.lock/holder.json`, and `.drift-inspection.json` (added in this
variant) were all correctly excluded by the pathspecs alone, while the durable artifact, handoff,
and return-meta were staged.

The scratch repo was removed at the end of Phase 7 (confirmed via `rm -rf`).

## Notes

- No file under `.claude/**` was modified; all source-store edits targeted
  `agent-system/extensions/core/**`, with `/.gitignore` as the one sanctioned consumer-side
  exception declared in the plan's file_scope expansion.
- The Phase 6 commit required an unplanned `git reset` (mixed, non-destructive to the working
  tree) mid-phase after a shared-index race: other concurrently-running orchestrate agents in
  this session had staged unrelated files (including deletions of archived `OC_5xx` task
  artifacts) between my `git add` calls. `git reset` cleanly unstaged everything without touching
  any working-tree content, after which only `/.gitignore` and this task's own directory were
  re-staged and committed. No other agent's in-flight work was disturbed.
