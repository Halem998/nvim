# Implementation Summary: Task #937

**Completed**: 2026-07-28
**Duration**: single session, 6 phases

## Overview

Made the zero-dispatch `/orchestrate` batch outcome — every validated candidate deferred, nothing
dispatched — loud, named, and actionable across all three surfaces that can produce it: the
skill's Stage MT-5 postflight, the command's consolidated output, and the `--dry-run` reporter.
The guardrails document now names the forward-progress invariant as a standing requirement. No
admission decision changed anywhere: the same candidates are admitted, deferred, or excluded
exactly as before this task; only the outcome's legibility changed.

## What Changed

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  `### The Forward-Progress Invariant` subsection (canonical vocabulary: invariant name,
  zero-dispatch outcome name, `forward_progress_violated`, `defer_ledger`, banner string, marker
  string; detection/rendering split across three loci; relationship to the
  `consecutive_no_dispatch_cycles` guard; empirical finding that the predecessor's narrowing did
  not shrink this requirement; exit/status contract confirmation) and a new `## Rejected
  Approaches` entry recording the PRINT-ONLY decision on auto-degradation with its three-part
  justification.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-1 schema gained
  `defer_ledger: []` (append-only observation log, with its binding MUST NOT and additive-to-
  existing-fields statement) and `forward_progress_violated: false`, plus a recorded finding that
  `skill-orchestrate-hard/SKILL.md` has no MT-stage implementation of its own and inherits these
  fields via its Stage 0 delegation to these same base stages. Stage MT-3 step 4.5's three defer
  branches (`self_modifying`, `file_scope_collision`/`in_batch`, `file_scope_collision`/
  `cross_batch`) and step 7's deploy-checkpoint failure path each gained one ledger-append
  instruction, immediately after their existing byte-for-byte-preserved behavior. Stage MT-5
  gained a new step computing the invariant cause-agnostically from `dispatch_start_ts`, an
  `exit_status` precedence branch forcing `"partial"` when the invariant is violated (a
  status-legibility correction, not an admission change), an additive reporting requirement, and
  two new `.return-meta-multi.json` metadata fields.
- `agent-system/extensions/core/commands/orchestrate.md` — Step 5 now reads
  `forward_progress_violated`, `defer_ledger`, and `dispatch_start_ts`, resolves the invariant via
  a three-branch, all-non-silent scheme (direct read / computed fallback / explicit "not
  evaluable" notice), and the Consolidated Output template gained a `### ZERO DISPATCH` section
  (banner, marker, not-a-failure sentence, `defer_ledger` table, dependency-ordered re-run
  sequence derived from the existing `waves` computation), a `### Deferred (self-modifying)`
  section closing the documented template/prose mismatch, a `### Deferred (other admission
  exclusions)` section for non-zero-dispatch `file_scope_collision` visibility, and an amended
  `### Next Steps` line.
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` — emits the same banner and
  marker (byte-identical modulo counts) immediately after the title line when zero tasks are
  admitted, replaces the `no admitted tasks — nothing to split` line with the dependency-ordered
  re-run sequence derived from the existing wave computation, adds a zero-dispatch-only Note
  recording the static-vs-cycling divergence, and updates the header comment block accordingly.

## Decisions

- The invariant is detected once, at Stage MT-5, and rendered independently at two surfaces (the
  command's Step 5 and the dry-run reporter) — never re-derived with different logic.
- PRINT-ONLY was chosen over auto-degrading a zero-dispatch batch into N solo re-runs, recorded as
  a new Rejected Approaches entry with a three-part justification (cost multiplication without
  consent, no synchronous confirmation gate to obtain that consent, and inversion of
  defer-not-fail's proportionality logic).
- The `forward_progress_violated == true -> "partial"` precedence branch is framed explicitly as a
  status-legibility correction: it changes only the skill's self-reported completion string for an
  outcome that already dispatched nothing, never an admission verdict, task status, or
  `state.json` write.
- `defer_ledger` is additive to the existing `deferred_self_modifying` and
  `deferred_deploy_checkpoint` fields, never a replacement, and carries an explicit MUST NOT
  against ever becoming a fifth admission gate.

## Plan Deviations

- **Task 4** (ZERO DISPATCH section): during Phase 6's hand-trace verification, the
  `{validated_count}` placeholder used in the live banner/marker template was found to have no
  corresponding bash variable assignment in `commands/orchestrate.md`. Fixed in place with a
  `validated_count=${#validated_tasks[@]}` line, which required a second (still within Phase 6)
  redeploy to propagate to the deployed tree. See the Phase 6 progress file's `deviations` array
  for the full record.

## Verification

- Build: N/A (markdown/JSON/bash sources)
- Tests: All Phase 5 scratch-tree dry-run smoke tests passed (zero admitted / all admitted /
  partial admission — banner+marker+re-run-sequence present only in the zero-admitted case,
  `0 excluded` and wave-split lines intact in the other two). `jq -e .` passed on the amended
  `.return-meta-multi.json` construction. `bash -n` clean on both the source-store and
  post-redeploy deployed copies of `orchestrate-dry-run-report.sh`. Phase 6's admission-neutrality
  audit found zero hunks affecting any admission verdict, `defer_reason`, `--invocation-count`
  argument, eligibility condition, all-terminal condition, circuit-breaker condition, convergence
  guard trigger, or critical-paths data. The defer-not-fail confirmation found zero new
  `specs/state.json` writes, `failed_tasks` appends, or status mutations. The `defer_ledger` MUST
  NOT was verified by grep: all 11 occurrences in `skill-orchestrate/SKILL.md` are schema
  definitions, append instructions, or Stage MT-5 reads/reporting — never a term in an
  eligibility, all-terminal, circuit-breaker, or admission condition. No task-number citations
  were introduced in any file outside `specs/`. `validate-artifact.sh` PASSed against this plan
  with 0 warnings.
- Files verified: Yes — all four declared source-store files present and modified; no fifth file
  touched (confirmed via `git show --name-only` across all five phase commits). Zero `.claude/`
  paths appear in any pre-redeploy commit for this task. The two deliberate redeploys
  (`deploy-headless.sh` + `verify-deploy.sh`, PASS both times — 11 checks, 0 failures, one
  pre-existing unrelated WARN about duplicate hook registrations) and the pre-declared
  `skill-orchestrate/SKILL.md` direct-copy workaround (re-applied after the second redeploy;
  `skill-orchestrate-hard/SKILL.md` correctly untouched) are the only two sanctioned exceptions to
  the source-store rule for this task. Post-redeploy, `check-extension-docs.sh` exited 0 ("PASS:
  all extensions OK") and all four deployed copies diffed clean against their source-store
  originals.

## Notes

- The predecessor task's dependency edge (935) was honored: this task's Phase 1 explicitly cites
  the same-cycle narrowing and the resulting empirical finding that the remaining zero-dispatch
  cases are true positives, not artifacts of the now-narrowed self-modification gate.
- A follow-up task is recommended (not created by this task) for the pre-existing
  `deploy-headless.sh` picker-sync defect that excludes `skill-orchestrate/SKILL.md` and
  `skill-orchestrate-hard/SKILL.md` from its skills scan — out of this task's declared file scope
  per the plan.
- A second, unrelated adjacent defect was surfaced by the delegating session (the picker sync's
  allow-list post-filter dropping ALL skills, not just the orchestrate ones, due to a
  directory-name-vs-basename mismatch in `manifest.lua`/`sync.lua`) — explicitly out of scope for
  this task, in a different file tree, and left for its own future task per the delegation
  context's instruction not to fix it here.
