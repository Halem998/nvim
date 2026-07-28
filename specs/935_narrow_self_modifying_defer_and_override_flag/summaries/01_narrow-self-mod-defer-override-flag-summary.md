# Implementation Summary: Task #935

**Completed**: 2026-07-28
**Duration**: ~4.5 hours across 10 phases (6 dependency waves)

## Overview

Narrowed the self-modification admission defer in `orchestrate-batch-admit.sh` and its two
callers (`skill-orchestrate/SKILL.md`, `commands/orchestrate.md`) from a whole-invocation
exclusion to a converging same-cycle/same-wave defer, added an opt-in `--allow-self-modifying`
override flag (default off, threaded through `parse-command-args.sh`), closed a verified
zero-reference gate gap in `skill-orchestrate-hard/SKILL.md` by explicit transcription, added a
tenth critical-path entry (`scripts/verify-deploy.sh`), and bumped the verdict schema to
`orchestrate-batch-admit-v3`. All eight declared source-store files were updated coherently, a
single deliberate redeploy was performed only at the end, and the standing safe default was
preserved throughout: a genuinely co-dispatched self-modifying candidate still defers unless a
human passes the override.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — v3 schema literal (9
  occurrences), rewritten `--invocation-count` contract (co-dispatch count, not whole-invocation;
  flag-name-retained note), narrowed file-top consequence paragraph, extended `Precedence (D4)`
  block with the A1 dependency-edge-exemption resolution and a corrected "strictly larger"
  rationale, updated `defer_reason` field comment, and updated the self-mod defer's `reason`
  string text.
- `agent-system/extensions/core/scripts/parse-command-args.sh` — `ALLOW_SELF_MODIFYING_FLAG`
  added through the header comment, Step 4 init/scan, Step 5 strip chain, and Step 6 export.
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — added the
  tenth `critical_paths` entry (`scripts/verify-deploy.sh`, "deploy verification gate").
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — re-applied
  the two conjunctive tests to all ten rows (nine unchanged, one new); added `deploy-headless.sh`
  to the Exclusion Table; added a new "The Same-Cycle Narrowing and Its Hazard Accounting"
  subsection (hazard-by-hazard accounting, A1 resolution, override-flag rationale); corrected
  hazard 3(i)'s premise and (iii)'s script count/list (nine→ten, six→seven); rewrote "Scope
  Limitation and Residual Risk" (Scope F) with narrowing-specific reasoning; corrected a stale
  idempotence-guard cross-reference.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — narrowed Stage MT-3 step 4.5's
  `--invocation-count` argument to `${#eligible_tasks[@]}`; added the `allow_self_modifying`
  consumer-side override branch; converted `deferred_self_modifying` from a permanent
  eligibility-exclusion set (Stage MT-1 schema, Stage MT-3 steps 2/3/4) into an append-only
  observation log; added a new `consecutive_no_dispatch_cycles` convergence guard; updated Stage
  MT-5's `exit_status` gate and reporting to be terminal-state-based rather than
  log-non-emptiness-based.
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — expanded `## Multi-Task
  Mode` from a two-sentence pointer (verified zero references to `orchestrate-batch-admit`,
  `deploy-headless`, `verify-deploy`) into an explicit, co-maintenance-marked transcription of the
  admission gate and the inter-cycle redeploy checkpoint.
- `agent-system/extensions/core/commands/orchestrate.md` — added `--allow-self-modifying` to the
  `## Options` table and STAGE 0 flag threading; rewrote the wave-split-check framing to state
  plainly that the file is illustrative only and the sole executing gate lives in
  `skill-orchestrate/SKILL.md`; narrowed the illustrative bash argument to `${#wave_tasks[@]}`;
  rewrote the `self_modifying` bullet; threaded `allow_self_modifying` into the Skill delegation
  context.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — bumped to
  `orchestrate-batch-admit-v3` throughout (Status line, three JSON examples, field table);
  rewrote "Why `--invocation-count` Exists" and its convergence-requirement paragraph; rewrote the
  Deferral-Direction Rule's `self_modifying` bullet; added the consumer-side override note to "Why
  This Check Is Blocking, Not Advisory"; updated the `Read by` list; added a `**v3**` Version
  History entry with a full five-consumer status table.
- `specs/935_narrow_self_modifying_defer_and_override_flag/` — plan phase headings, per-phase
  progress files, and this summary.

## Decisions

- A1 (dependency-edge exemption asymmetry) is explained, not remedied: once the count is
  same-cycle-scoped, an edge-connected pair can never share it, so an explicit exemption in the
  self-mod branch would be unreachable dead code.
- `--allow-self-modifying` defaults off because the narrowing trades a human-paced solo re-run for
  a candidate potentially running inside one automated invocation where the redeploy checkpoint
  auto-redeploys and auto-verifies with no human review — exactly the automation hazard 1
  (verification gap) warns against.
- Hard mode gets the gate by explicit transcription rather than a strengthened pointer, since the
  zero-hit grep proved a bare "same as base" pointer does not reliably carry a mechanism forward.
- `deploy-headless.sh` stays excluded from the critical-path list (loud primary failure mode,
  matching `validate-artifact.sh`'s existing rationale); `verify-deploy.sh` is included (silent
  false-PASS risk, matching the admission-predicate row's own rationale).
- Scope F (plain multi-task `/implement`/`/research`/`/plan`) is restated as an accepted, explained
  limitation rather than extended: those commands have no wave/cycle concept for the narrowed
  trigger to be counted against.

## Plan Deviations

- **Task 10.3** altered: `deploy-headless.sh`'s picker sync tool
  (`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, out of this task's declared
  file scope) silently excluded `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`
  from its skills-category scan, leaving both deployed copies stale by hundreds of lines — a
  pre-existing bug that predates this task (the immediately-preceding dependency task's edits to
  `skill-orchestrate/SKILL.md` were also never deployed). All other six source-store files synced
  correctly with no workaround. Worked around by directly copying the corrected source into
  `.claude/skills/skill-orchestrate/SKILL.md` and `.claude/skills/skill-orchestrate-hard/SKILL.md`
  as part of Phase 10's sanctioned `.claude/`-write exception, then re-verified every post-redeploy
  gate (`check-extension-docs.sh`, `verify-deploy.sh`, `bash -n`, the three behavioral traces)
  against the corrected deployed tree. **Recommend a follow-up task** to fix the picker sync
  tool's skills allow-list/scan logic so this class of silent staleness cannot recur.
- Commit granularity: phases were committed in eight commits rather than ten, because two file
  pairs (`skill-orchestrate/SKILL.md` for phases 4+5, and `batch-orchestration-guardrails.md` for
  phases 3+8) were edited sequentially without an intermediate commit and could not be cleanly
  split after the fact. Recorded explicitly in each affected commit message.

## Verification

- Build: N/A (markdown/JSON/bash sources)
- Tests: All scratch-tree smoke tests passed (solo admit, co-dispatch defer, edge-connected admit,
  `verify-deploy.sh` detection, degraded-critical-paths-file null path); `--allow-self-modifying`
  leak/default/non-interference/regression tests all passed; three paper-traced convergence
  scenarios (co-dispatch defer-then-admit, edge-connected immediate admit, mutually-colliding
  bounded partial) all check out against the edited text.
- Files verified: Yes — all eight declared source-store files present and modified;
  `bash -n` clean on both scripts pre- and post-redeploy; `jq -e .` clean on the critical-paths
  JSON and all three schema-doc JSON examples; `check-extension-docs.sh` and `verify-deploy.sh`
  both PASS post-redeploy; `validate-artifact.sh` PASSes on the plan file.

## Notes

- Zero `.claude/` paths appear in any pre-redeploy commit for this task (confirmed via
  `git log --name-only`), preserving the plan's self-hosting sequencing.
- Repo-wide `grep -rn 'orchestrate-batch-admit-v2' agent-system/` returns zero hits (every prior
  v2 literal was replaced; historical "v1-to-v2" prose references remain, as intended).
- Pre-existing task-number citations were found in `commands/orchestrate.md` (a "task 785 and task
  787" illustrative example) and `skill-orchestrate-hard/SKILL.md` ("task 808", "task 774") —
  confirmed via `git diff` to be untouched by this change and left as-is per the no-task-references
  sweep's "fix only what this change introduced" instruction.
