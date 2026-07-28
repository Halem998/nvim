# Orchestrator Runtime-File Tracking Policy

## Overview

`/orchestrate` and the skills it dispatches write several small scratch files directly under
`specs/{NNN}_{SLUG}/` (and a couple under `specs/` itself, for multi-task batches). This standard
is the single canonical policy for which of those files are **git-tracked** and which are
**gitignored**, and why. It is the authority `git-staging-scope.md`, both orchestrate skills,
`handoff-schema.md`, and the verification check script all point back to — extend this table when
a new runtime file class is discovered rather than re-deriving the split ad hoc at each call site.

## The Two-Class Split

Every runtime file falls into exactly one of two classes:

- **Ephemeral (gitignored, untracked)** — per-cycle scratch state that a resume/read site trusts
  with **no freshness check**. If a stale copy of one of these were restored from git history, it
  would silently corrupt in-flight orchestration state (a wrong `cycle_count`, a stale mutex, a
  bogus churn counter) with nothing to catch it.
- **Durable provenance (tracked)** — per-dispatch audit trail that a documented freshness gate
  already protects against exactly that "restored from an old commit" scenario, so tracking it
  costs nothing beyond history noise and gains a genuine audit trail of what each dispatch did.

### Class Table

| File | Writer | Reader | Cleanup site | Disposition |
|------|--------|--------|---------------|-------------|
| `.orchestrator-loop-guard` | `skill-orchestrate`/`skill-orchestrate-hard` Stage 2 (loop-guard init) | Same skills' Stage 2 resume branch (unconditional trust, see Rationale) | `rm -f` only at full-loop termination (base Stage 8; hard-mode equivalent) | **Ephemeral** |
| `.orchestrator-churn-state.json` | `skill-orchestrate-hard` Stage 2 (`churn_file`) | Hard-mode convergence-policing (H6) reads | `rm -f` only at full-loop termination, alongside the loop guard | **Ephemeral** |
| `.lock/` (directory, e.g. `holder.json`) | `task-lock.sh` mutex primitives (see `context/patterns/task-lock.md`) | Lock-holder checks during an in-flight dispatch | Released (removed) when the mutex is released | **Ephemeral** |
| `.drift-inspection.json` | `skill-orchestrate` Stage 5a (drift-inspection fork) | The same Stage 5a call, immediately after the fork returns | `rm -f` only at Stage 8 postflight (full-loop termination) — same timing class as the loop guard, not per-cycle | **Ephemeral** (newly identified by this audit — see note below) |
| `.orchestrator-handoff.json` | Skills when `orchestrator_mode: true` (currently: the hard-mode implementation agent's H9 wrap-up; see `docs/architecture/handoff-schema.md`) | `skill-orchestrate`/`skill-orchestrate-hard` Stage 5 (single-task) and Stage MT-4 (multi-task) | Overwritten in place each dispatch cycle (static filename, never deleted) | **Durable provenance** |
| `.return-meta.json` | Every research/plan/implement dispatch's own Stage 7 postflight (base and hard mode alike) | `orchestrate-recover-outcome.sh` fallback recovery path | Overwritten each dispatch; also proactively `rm -f`'d by `skill_cleanup()`/`orchestrator-postflight.sh` Stage 10 **after** it has already been staged/committed in Stage 9 of the same run — this is disk hygiene, not a tracking decision | **Durable provenance** |
| `specs/.orchestrator-multi-state-{session_id}.json` | `skill-orchestrate` multi-task batch dispatch (Stage MT, `specs/` root, not per-task) | The batch commit step in `commands/orchestrate.md`, which hard-fails on a `session_id` mismatch rather than silently trusting a foreign batch's file | Not explicitly cleaned up between batch runs; scratch state for one batch invocation; reaped by `scripts/reap-session-runtime-files.sh` after `ORCHESTRATOR_SESSION_REAP_MIN` | **Ephemeral**. The path carries a `{session_id}` suffix so two concurrent multi-task batches never collide on the same file. |
| `specs/.events.lock` | `scripts/events-append.sh` (`flock` guard around the append-only event store) | Itself, for the duration of a single append | Released by `flock` at the end of the append | **Ephemeral** |
| `.continuation-loop-guard` / `.continuation-loop-guard.tmp` | `skill-implementer`/`skill-implementer-hard` (their own internal continuation-retry counter, distinct from the orchestrator loop guard above) | Same skills, own resume branch | Removed at postflight (`orchestrator-postflight.sh` Stage 10 for `implement`; also inline at each skill's own postflight) | **Ephemeral** |
| `.postflight-loop-guard` | `skill-planner`/`skill-researcher`/`skill-implementer`/`skill-reviser`/`skill-spawn` (their own postflight retry marker) | Same skills' own postflight | Removed at postflight (`skill_cleanup()`, `orchestrator-postflight.sh` Stage 10) | **Ephemeral** |
| `.return-meta-*.json` (suffixed variants, e.g. `.return-meta-orchestrate.json`, `specs/.return-meta-multi-{session_id}.json`) | Distinct from the bare `.return-meta.json` above — see "The bare-vs-suffixed distinction" below | Varies by variant. **`specs/.return-meta-multi-{session_id}.json` has no reader anywhere in the source store today** — it is written for collision/audit hygiene only; a future reader-adder must add the read-time `session_id` verification check together with the reader, not separately | Varies | **Ephemeral** |

**Not classified here (reviewed and deliberately excluded)**: `.stray-handoff-{timestamp}.json`.
Both orchestrate skills' stray-handoff sweep (`docs/architecture/handoff-schema.md`'s "Handoff
Writers" section) moves a misplaced handoff aside into this timestamped name specifically to
**preserve evidence of a bug** for a human to inspect — it is diagnostic output, not per-cycle
control-flow state nothing reads back with unconditional trust. Silently gitignoring it would
suppress the very evidence the sweep exists to surface. It is intentionally left out of both the
ephemeral and durable-provenance classes above; if it recurs often enough to need policy, that
policy belongs to the stray-handoff sweep mechanism itself, not this file-tracking split.

### The bare-vs-suffixed `.return-meta.json` distinction

**This distinction must never be collapsed.** The bare `specs/{NNN}_{SLUG}/.return-meta.json` is
the durable, per-dispatch outcome-recovery record described above and MUST stay tracked. Suffixed
variants — `specs/{NNN}_{SLUG}/.return-meta-orchestrate.json`, `specs/.return-meta-multi-{session_id}.json`,
round-numbered variants like `.return-meta-02.json` observed in this repo's archive — are a
different, ephemeral class: batch/scratch state or artifacts of a prior naming scheme, not the
one documented outcome-recovery contract in `docs/architecture/handoff-schema.md` and
`context/formats/return-metadata-file.md`. Keep the ignore pattern for the suffixed form (`**/.return-meta-*.json`)
even while the bare form is un-ignored — they are opposite dispositions, not the same file with a
looser glob.

### A newly-identified ephemeral class: `.drift-inspection.json`

The audit behind this standard was scoped to not assume the previously-known runtime-file names
were complete (`skills/skill-orchestrate/SKILL.md` Stage 5a). `.drift-inspection.json` fits the
ephemeral rationale exactly: it has no freshness gate, and — like the loop guard — its cleanup
fires only at Stage 8 postflight (full-loop termination), not between cycles, so a mid-loop
Stage 9 whole-directory `git add` can capture it while a multi-cycle run is still in flight. It is
therefore adopted into the ephemeral (gitignored) class alongside the loop guard, churn state, and
`.lock/`, consistent with (not a re-opening of) the decided two-class split — that split concerns
the two named durable files, not an exhaustive enumeration of every ephemeral name.

## Rationale: the freshness-gate asymmetry

The two classes are not an arbitrary grouping — they track a real, verifiable difference in how
each file is read back.

The loop guard is read completely unconditionally
(`skill-orchestrate/SKILL.md` Stage 2): `if [ -f "$loop_guard_file" ] && jq empty ...` resumes
`cycle_count` and `infra_failures` from whatever is on disk, with **no `session_id` comparison and
no mtime/staleness check**. Any syntactically valid guard at the expected path is trusted,
regardless of its age or which session wrote it. The same is true of `.orchestrator-churn-state.json`
(hard mode) and of `.drift-inspection.json` (trusted the instant its writer-fork returns, no
independent freshness re-check). A committed-then-git-restored copy of any of these is a genuine
correctness hazard: it would silently resume a stale cycle count, a stale churn history, or a
stale drift signal.

The handoff has the opposite contract. `docs/architecture/handoff-schema.md` states: "**Readers
MUST check freshness.** ... Both orchestrators compare the file's mtime against
`dispatch_start_ts` ... and treat an out-of-window handoff exactly as they treat a missing one."
A restored-from-history handoff simply fails this check and is treated as absent — never silently
trusted. `.return-meta.json` has the equivalent gate at its one documented read site
(`orchestrate-recover-outcome.sh`): "A recovered outcome is fail-closed: only a present, **fresh
(within the current dispatch window)**, parseable `.return-meta.json` ... is ever treated as a
success," with the gate keyed on `meta_mtime` versus the current dispatch's `window_start_ts`.

**Ephemeral-and-ungated must be ignored; gated provenance is safe to track.** This is the
mechanism-level justification for the settled split, independent of (and consistent with) the
"durable audit trail" framing used to motivate it.

## Consumer Repo Setup

There is no automatic way for the source store to deliver a repo-root `.gitignore` contribution —
`copy_root_files()` deploys `root-files/` into the consumer's `.claude/` directory, not the repo
root (see `context/guides/loader-reference.md`), so a `specs/*/` pattern placed there would
resolve to `.claude/specs/*/` and silently match nothing. Add the following block to the
consumer repo's **own root** `/.gitignore` **by hand, once**:

```gitignore
# Ephemeral orchestrator runtime state: per-dispatch scratch, mutex directories, and loop
# guards. Ignored because these have no freshness gate on read — a git-restored copy would
# silently corrupt in-flight cycle/churn state. See
# agent-system/extensions/core/context/standards/orchestrator-runtime-files.md for the full
# two-class policy and rationale. Deliberately does NOT include .orchestrator-handoff.json or
# .return-meta.json — those are durable, freshness-gated provenance and MUST stay tracked.
**/.lock/
**/.orchestrator-loop-guard
**/.continuation-loop-guard
**/.orchestrator-churn-state.json
**/.postflight-loop-guard
**/.orchestrator-multi-state*.json
**/.drift-inspection.json
**/.return-meta-*.json
**/.events.lock
```

Run `check-runtime-file-tracking.sh` afterward to confirm coverage (see "Verification" below).

**This gitignore coverage is the primary, sufficient control.** The staging-narrowing described in
`git-staging-scope.md` is defense-in-depth for a repo that has not yet applied this block — it
does not replace it. A repo with full coverage above is protected purely by gitignore, regardless
of what any automated `git add` stages.

## Untracking Already-Committed Ephemeral Files

If any ephemeral-class file was committed before this policy was applied (as observed live in
other consumer repos), untrack it while leaving it on disk:

```bash
git rm --cached specs/{NNN}_{SLUG}/.orchestrator-loop-guard
git rm -r --cached specs/{NNN}_{SLUG}/.lock/
```

`git rm --cached` (and its `-r` form for directories) removes the file from git's index only —
the working-tree copy is untouched, so an in-flight orchestration reading that file is never
disrupted by the untracking operation itself.

**Explicit prohibition: never run this against `.orchestrator-handoff.json` or
`.return-meta.json`.** They are the per-dispatch audit trail this policy is built to keep; the
`check-runtime-file-tracking.sh` script (Check C) actively verifies they are NOT ignored and
never suggests untracking them.

## Forward-Only Migration Note

Adopting this policy in a repo whose root `.gitignore` previously ignored
`.orchestrator-handoff.json`/`.return-meta.json` (a reversal, not a fresh addition) makes every
existing on-disk file of those two classes newly stageable the moment the ignore lines are
removed — but it does **not** retroactively backfill git history. A task directory that never
receives another commit keeps its existing handoff/return-meta files untracked indefinitely; only
future writes to directories that get a future commit are picked up. This is the accepted,
intentional shape of the migration: no bulk backfill commit is created as part of applying this
policy.

## Verification

`scripts/check-runtime-file-tracking.sh` (see that script's header for the full contract) proves
three things from any consumer repo root:

1. Every ephemeral pattern above actually ignores a representative path (`git check-ignore -q`).
2. No ephemeral-class file is currently tracked (`git ls-files` scan; prints the exact
   `git rm --cached` remediation if one is found).
3. `.orchestrator-handoff.json` and `.return-meta.json` are **not** ignored.

## Related Documentation

- `context/standards/git-staging-scope.md` — the staging-narrowing defense-in-depth layer
- `docs/architecture/handoff-schema.md` — the handoff's own freshness-gate contract and outcome-channel design
- `context/patterns/task-lock.md` — the `.lock/` mutex primitives
- `scripts/check-runtime-file-tracking.sh` — the verification check
