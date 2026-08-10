# Research Report: Task #879

**Task**: 879 - wire_reconcile_task_status_safety_net
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: medium
**Dependencies**: predecessor status-hardening and preflight-wiring work (both complete; see Context & Scope)
**Sources/Inputs**: codebase (agent-system/ canonical tree, .claude/ deploy mirror, specs/ artifacts), no web sources needed
**Artifacts**: - this report
**Standards**: report-format.md, no-task-references-in-deliverables.md

## Executive Summary

- **Canonical paths** (the `.claude/` paths in the delegation are deploy-mirror copies of these):
  `agent-system/extensions/core/scripts/reconcile-task-status.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`, plus a fourth in-scope file not
  named in the delegation's FILE SCOPE: `agent-system/extensions/core/commands/task.md`.
- **Zero-callers claim verified** in both trees: the only non-self hit anywhere under either
  `agent-system/` or `.claude/` is the deploy-manifest listing
  (`agent-system/extensions/core/manifest.json:124` / its `.claude/` mirror), which copies the
  file into place but never invokes it.
- **Recommended primary trigger: `/task --sync`.** It is already the system's documented,
  user-invoked repair path (cited from `skill-spawn/SKILL.md`, `commands/spawn.md`, and
  `docs/guides/user-guide.md` as the standard "state looks wrong, go run this" instruction) and
  already performs an adjacent, narrower repair — Sync Mode step 2.5 calls the sibling script
  `reconcile-artifacts.sh` (artifact-registration backfill only, no status changes). Wiring
  `reconcile-task-status.sh` as a companion step in the same Sync Mode section, looping over all
  non-terminal active tasks, is the smallest, most consistent change and runs only on explicit
  user request — never silently and never on a hot path.
- **Recommended secondary trigger: `/orchestrate` entry, automatic.** Once per single-task
  invocation (Stage 2/3 boundary, before the cycle loop) and once per task in multi-task mode
  (Stage MT-2, before the cycling loop) — not per-cycle. Justified because `/orchestrate` is
  explicitly autonomous/no-confirmation by design (no human is reliably present to confirm), and
  because the script's promotions are conservative by construction: it only advances status when
  a matching artifact for the *current* status already exists on disk, i.e. it finishes
  bookkeeping for work that already happened rather than inventing progress. Its non-dry-run
  branches already print `[reconcile] ...` lines to the transcript, so automatic operation here
  does not reduce visibility.
- **`skill-todo` (`/todo`): report-only-then-confirm, not automatic.** Run
  `reconcile-task-status.sh --dry-run` per non-terminal active task early in the scan, surface
  any findings through the skill's existing `AskUserQuestion` confirmation pattern, and only run
  it live if the user opts in. `/todo` is the point where the system performs its most
  irreversible operations (moving directories, rewriting CHANGE_LOG.md); silently promoting
  status immediately before silently archiving compounds two mutations with no visibility, which
  directly conflicts with the task's "user wants more visibility, not more silent mutation"
  directive.
- **The "archived-while-still-held lock" problem is NOT addressed by reconcile-task-status.sh**
  under any trigger point — the script has zero lock-awareness (no reference to `task-lock.sh` or
  `.lock/` anywhere in its body), and `skill-todo/SKILL.md` also has zero lock-awareness (no
  `task-lock`/`.lock`/`release` references found anywhere in the file). This is confirmed live in
  the current working tree: `specs/876_wire_preflight_into_orchestrate_paths/.lock/holder.json`
  is a **git-tracked** file (added in an earlier commit) now showing as locally deleted — proof
  that lock artifacts are ending up inside git-tracked task directories that Stage 10
  (`ArchiveTasks`) moves wholesale on archive, with no lock check or release anywhere in that
  path. Closing this requires a *separate* wiring of the existing `task-lock.sh check`/`release`
  subcommands into `skill-todo/SKILL.md` Stage 10, immediately before the directory move — not
  something `reconcile-task-status.sh` itself can do, since it carries no lock logic.
- **Plan-vs-state.json divergence detector: confirmed absent, and `reconcile-task-status.sh` is a
  defensible home, but treat as report-only.** `generate-todo.sh` was verified to read only
  `specs/state.json` (no `plans/` or `.md` reads at all), so no detector anywhere in the system
  currently compares plan-file phase/status markers against `state.json`. Post-878 phase-marker
  ownership (`update-phase-status.sh` now called from `general-implementation-agent.md`, logged
  to `.agent-logs/phase-transitions.log`) reduces *one* source of drift going forward but does not
  make the detector unnecessary — crashed runs, manual edits, or any future bypass of that call
  site can still desync the two. Because there is no unambiguous "correct side" to auto-repair
  toward (unlike the artifact-exists-so-promote case), any plan-marker check added to
  `reconcile-task-status.sh` should be report-only, never auto-repairing, and is sized as
  optional/stretch scope for this task's plan rather than a hard requirement.

## Context & Scope

Predecessor tasks (both complete) changed the ground truth this task must be specified against:

1. **Preflight-wiring** (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
   `skill-orchestrate-hard/SKILL.md`): `skill_preflight_update()` now fires immediately before
   every research/plan/implement Agent-tool dispatch on all `/orchestrate` paths (single-task and
   multi-task Stage MT-4). Tasks driven by `/orchestrate` now transition into
   `researching`/`planning`/`implementing` at dispatch time instead of sitting at their
   pre-dispatch status for the whole work window.
2. **Status-script hardening**
   (`agent-system/extensions/core/scripts/{update-task-status,update-plan-status,update-phase-status}.sh`,
   `agents/general-implementation-agent.md`): `update-task-status.sh` now admits `partial` and
   `blocked` as **postflight-only** task-level termini (`postflight:partial` ->
   `partial`/`PARTIAL`, `postflight:blocked` -> `blocked`/`BLOCKED`); the idempotency early-exit is
   scoped to the state.json write only (plan/phase side effects still fire on retry); plan
   selection is version-ordered (not `ls -t` mtime-ordered) at all three call sites; and
   `general-implementation-agent.md` now calls `update-phase-status.sh` per phase, so phase
   markers have an owning mechanism for the first time
   (`.agent-logs/phase-transitions.log` is now live).

These two predecessors change what "stuck" and "divergent" mean for this task: a task is no
longer plausibly stuck in `researching`/`planning`/`implementing` merely because nobody called
preflight — that's now wired everywhere `/orchestrate` dispatches. What remains as the genuine
target failure mode is a **crashed or killed session** (or any future bypass of the wired paths,
e.g. a raw `/research N` invocation outside `/orchestrate`) that wrote an artifact but never
reached postflight — exactly the scenario `reconcile-task-status.sh`'s own header describes.

## Findings

### The script's real interface (not assumed from the header)

`agent-system/extensions/core/scripts/reconcile-task-status.sh` (231 lines):

- **Signature**: `reconcile-task-status.sh <task_number> <session_id> [--dry-run]`. Both
  positional args are required; missing either exits 1 with a usage message.
- **Dry-run mode already exists** and is fully wired through every branch — this is not
  something a caller needs to add.
- **Exit codes**: `0` success or no-op (task not found in state.json is also a `0` no-op, treated
  as "possibly already archived", not an error); `1` validation error; `2` state.json read
  error.
- **Dispatch is keyed purely on `state.json`'s current `status`** for the one task_number given —
  it does not scan all tasks itself (a caller must loop for a system-wide sweep) and it does not
  read plan files at all today.
- **Case handling**:
  - `researching` / `planning` / `implementing`: if the corresponding artifact directory
    (`reports/`, `plans/`, `summaries/`) has a `.md` file (version-sorted latest), it links the
    artifact into `state.json` (dedup + regenerate TODO.md) and replays
    `update-task-status.sh postflight <task_number> {research|plan|implement} <session_id>` to
    advance status. No artifact -> silent no-op (correctly treated as genuinely in-progress).
    Note: for these three cases the script does **not** consult the task's
    `.orchestrator-handoff.json` at all — it assumes artifact-existence alone means success. This
    predates the post-878 `blocked` postflight status; a task that crashed after writing a report
    but whose handoff says `blocked` would still be force-promoted to `researched` rather than
    `blocked`. Flagging as a real gap but out of scope for "give it a caller" — see Recommendations.
  - `partial`: only promotes to `completed` if BOTH a summary artifact exists AND
    `.orchestrator-handoff.json`'s `status` field equals `"implemented"` — this branch already
    respects handoff semantics, unlike the three above.
  - All other statuses (`not_started`, `researched`, `planned`, `completed`, `blocked`,
    `abandoned`, `expanded`): no-op by design (terminal or already stable).
- **Mutations**: writes `state.json` (via the existing tmp-file-rename pattern, Issue #1132-safe
  jq), calls `generate-todo.sh` (non-fatal on failure), and delegates the actual status transition
  to `update-task-status.sh postflight` (which itself may touch plan/phase files per the
  post-878 hardening). It never touches `.lock/` or task-lock state.

### Zero-callers claim: verified

```
grep -rn "reconcile-task-status" agent-system/  ->  only manifest.json:124 (deploy listing) + the script itself
grep -rln "reconcile-task-status" .claude/      ->  only the deployed script + its manifest mirror
```

No caller in either tree. Confirmed as stated.

### Canonical-source correction (source-of-truth warning, verified per-file)

All three files named in the delegation's FILE SCOPE, plus `commands/task.md` (relevant to the
recommended primary trigger, and not listed in the delegation), have their canonical, git-tracked
source under `agent-system/extensions/core/`, with `.claude/` as the gitignored deploy mirror:

| Deliverable | Canonical path |
|---|---|
| reconcile script | `agent-system/extensions/core/scripts/reconcile-task-status.sh` |
| orchestrate skill | `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` |
| todo skill | `agent-system/extensions/core/skills/skill-todo/SKILL.md` |
| sync command (not in delegation's scope list) | `agent-system/extensions/core/commands/task.md` |

Per the precedent set by the immediately-preceding predecessor tasks, edits must land in
`agent-system/extensions/core/` and be mirrored into the deployed `.claude/` copies for
immediate same-session effect.

### Trigger point evaluation

**`/task --sync` (recommended primary).** `commands/task.md`'s Sync Mode already has a step 2.5
"Artifact reconciliation" that calls the sibling script `reconcile-artifacts.sh` — verified to be
a genuinely distinct, complementary script: it sweeps ALL active task directories in one pass,
backfilling any `.md` artifact under `reports/`/`plans/`/`summaries/` that is missing from
`state.json`'s `artifacts` array, with **append-only** semantics (explicitly preserves multiple
report files for team research) and **never touches `status`**. It has no `task_number` argument
— it is inherently system-wide. `reconcile-task-status.sh` is the natural, status-advancing
continuation of that same step: loop over `state.json`'s non-terminal `active_projects`
(`researching`/`planning`/`implementing`/`partial`), and call
`reconcile-task-status.sh <task_number> <sync_session_id>` for each (live, not dry-run, since the
user explicitly invoked a repair command). This trigger point is also independently reinforced by
existing documentation: `docs/guides/user-guide.md`'s troubleshooting section, and both
`skill-spawn/SKILL.md` and `commands/spawn.md`, already tell users to run `/task --sync` to
recover from partial/timeout states — so wiring the actual status-repair machinery there closes a
gap between documented behavior and actual behavior. Cost/risk: zero impact on any hot path (only
runs on explicit invocation); minor new work needed since Sync Mode currently has no
`session_id` of its own (`command-gate-in.sh` is explicitly NOT sourced in Sync Mode) — a
lightweight session ID can be generated inline following the standard
`sess_$(date +%s)_$(...)` pattern from `git-workflow.md`.

**`/orchestrate` entry (recommended secondary, automatic).** Verified structurally: Stage 3's
`current_status` is read fresh at the top of *every* cycle iteration (`while` loop, Stage 3a), but
within one continuous `/orchestrate` run the post-876 preflight wiring already keeps status
current between dispatches — so a per-cycle reconcile call would be redundant cost on every
iteration (a `/orchestrate` run can loop up to `MAX_CYCLES=5` single-task / `MAX_CYCLES_MT=25`
multi-task). The actual failure this script exists for — a *previous, separate* invocation
crashed before postflight — is only observable once, at the start of a fresh invocation. Correct
placement is therefore a single call at the Stage 2/Stage 3 boundary (single-task, after loop-guard
init, before the `while` loop begins) and a single per-task loop at Stage MT-2 (multi-task, after
the per-task routing table is built, before Stage MT-3's cycling loop begins) — never inside the
loop body. This also correctly handles the delegation's note that "a multi-task `/orchestrate` run
has no single 'entry' per task": Stage MT-2 already iterates every `task_number` once to build the
routing table, so the reconcile call rides that same existing iteration rather than needing new
per-task entry detection.

**`skill-todo` (recommended: report-only, not a repair trigger by default).** Verified: Stage 2
(`ScanTasks`) scans for the *literal* strings `status == "completed"` / `status == "abandoned"` —
a task stuck in `researching`/`planning`/`implementing`/`partial` with a matching artifact already
on disk is invisible to this scan today and can never be archived, even indefinitely, until
something else promotes it. Adding a `reconcile-task-status.sh --dry-run` pass per non-terminal
active task early in the flow (e.g., a new Stage 1.5, before Stage 2's scan) and surfacing any
findings through the skill's already-established `AskUserQuestion` pattern (Stage 9
`InteractivePrompts` already exists for exactly this kind of "confirm before we act" gate) would
make previously-invisible stuck tasks visible and archivable on user opt-in, without ever
silently promoting status right before silently moving the directory. This is a deliberately
more conservative choice than `/orchestrate`'s automatic wiring, justified by the difference in
context: `/todo` is inherently interactive/human-reviewed (it already blocks on `AskUserQuestion`
for vault operations and topic backfill), whereas `/orchestrate` is inherently autonomous by
design and has no human reliably present to gate on.

### The archived-while-still-held-lock problem

`agent-system/extensions/core/context/patterns/task-lock.md` documents `task-lock.sh`'s
`acquire`/`heartbeat`/`release`/`check`/`init-marker` contract and explicitly enumerates its
consumers ("Consumers (Two Distinct Wiring Paths)" section): single-task gate scripts,
multi-task/wave dispatch in `skill-orchestrate/SKILL.md` and `implement.md`, and `init-marker`
call sites in the orchestrate skills. **`skill-todo/SKILL.md` is not listed as a consumer, and a
direct grep for `task-lock`/`.lock`/`release` across the file returns zero matches.** Stage 10
(`ArchiveTasks`) moves the entire project directory to `specs/archive/` (`mv "$source_dir"
"$target_dir"`) with no lock check beforehand. Live corroborating evidence in the current working
tree: `specs/876_wire_preflight_into_orchestrate_paths/.lock/holder.json` is tracked by git
(added in a prior commit, `git log` shows one hit) and the current `git status` shows it as
locally deleted (` D specs/876.../.lock/holder.json`) — direct proof that lock directories are
ending up committed inside task directories that Stage 10 would sweep wholesale into the archive
on the next `/todo` run, with no release step anywhere in that path.

`reconcile-task-status.sh` cannot fix this — it has no lock-awareness in its own code and adding
any would be outside "give it a caller" scope. The correct fix is a **separate** wiring of the
already-existing `task-lock.sh check`/`release` subcommands into `skill-todo/SKILL.md` Stage 10,
immediately before the directory move (release if stale/self-held, warn-and-skip-archiving-this-
task if freshly held by another session — mirroring the `ABORT:`-style messaging pattern
`task-lock.md` already documents for other consumers). Since `skill-todo/SKILL.md` is already in
this task's FILE SCOPE, this could be bundled into the same implementation pass, but it is a
distinct decision (lock release, not status reconciliation) and should be called out as its own
plan phase rather than folded silently into the reconcile wiring.

### Plan-vs-state.json divergence detector

Verified: `generate-todo.sh` (427 lines) contains no reference to `plans/` or any plan-file read
— it is driven entirely from `state.json`. No script or skill anywhere in either tree currently
compares a plan file's `- **Status**:` field or `### Phase N [STATUS]` headings against
`state.json`'s `status`. `reconcile-task-status.sh` is architecturally the right home if this is
pursued: it already resolves `TASK_DIR` per task number, already reads `state.json`'s `status`,
and its postflight-replay path already indirectly drives `update-plan-status.sh`/
`update-phase-status.sh` through `update-task-status.sh`. Post-878's phase-marker ownership
(`general-implementation-agent.md` now calls `update-phase-status.sh` per phase) reduces future
drift for the phase-heading case specifically, but does not eliminate the need for a detector —
crashed runs, manual edits, or any future bypass of that call site remain possible. Because there
is no unambiguous "correct side" for a plan-vs-state mismatch (unlike "artifact exists, therefore
promote," which has one obviously correct direction), any check added here should be report-only
(a `[reconcile] WARNING: plan says X, state.json says Y` line), never auto-repairing either
direction. Recommend sizing this as optional/stretch scope in the implementation plan rather than
a hard requirement, since it is new comparison logic rather than pure wiring.

## Decisions

- Primary trigger: `/task --sync` (Sync Mode, `commands/task.md`), live/non-dry-run, looping over
  all non-terminal active tasks, as a companion step to the existing `reconcile-artifacts.sh` call.
- Secondary trigger: `/orchestrate` single-task entry (once per invocation, before the cycle loop)
  and multi-task entry (Stage MT-2, once per task, before the cycling loop) — automatic/live, not
  gated on confirmation, consistent with `/orchestrate`'s existing no-confirmation design.
- `skill-todo`: dry-run-and-surface only by default, gated on the skill's existing
  `AskUserQuestion` pattern before any live status promotion.
- The lock-leak-on-archive problem is real (independently corroborated by a live git-tracked
  `.lock/holder.json` artifact) but is NOT addressed by `reconcile-task-status.sh` under any
  wiring choice; it needs a separate `task-lock.sh check`/`release` wiring into `skill-todo`
  Stage 10, which may be bundled into the same implementation pass since the file is already in
  scope, but should be tracked as its own plan phase.
- Plan-vs-state.json divergence detection belongs in `reconcile-task-status.sh` if pursued, but
  should be report-only and treated as optional/stretch scope, not a hard requirement of this
  task.

## Risks & Mitigations

- **Risk**: automatic reconciliation at `/orchestrate` entry masks a genuine `blocked` outcome as
  a success promotion, because the `researching`/`planning`/`implementing` branches don't consult
  the handoff file the way the `partial` branch does. **Mitigation**: flag as a known limitation
  in the plan; consider extending those three branches to check `.orchestrator-handoff.json`
  status the same way the `partial` branch already does, before promoting — this is a small,
  contained change to the existing script (not a new script) and directly leverages post-878's
  new `blocked` postflight target.
- **Risk**: looping `reconcile-task-status.sh` per task in `/task --sync` and multi-task
  `/orchestrate` entry adds N script invocations to those paths. **Mitigation**: both are
  bounded by the number of active/non-terminal tasks (typically small), and the script itself is
  a fast, single-`jq`-pass shell script with an early no-op exit for any task not in one of the
  four reconcilable statuses.
- **Risk**: bundling the lock-release fix into the same `skill-todo/SKILL.md` edit as the
  dry-run-reconcile wiring could conflate two distinct decisions in one plan phase. **Mitigation**:
  plan should treat them as separate phases even if implemented in the same task.

## Context Extension Recommendations

- **Topic**: `task-lock.md`'s "Consumers" section currently omits `skill-todo/SKILL.md` as a
  non-consumer by silence rather than by explicit statement.
- **Gap**: a future reader auditing lock-safety could miss that archival is an unguarded path,
  since the document only lists who DOES call the lock, not who conspicuously doesn't.
- **Recommendation**: once the Stage 10 lock-check wiring (see Findings above) lands, update
  `task-lock.md`'s Consumers section to add `skill-todo/SKILL.md` Stage 10 as a third consumer,
  closing the gap this research identified.

## Appendix

Key commands run:
- `grep -rn "reconcile-task-status" agent-system/ .claude/` (zero-callers verification, both trees)
- `git log --oneline -- specs/876_.../.lock/holder.json` and `git status --porcelain | grep 876`
  (lock-leak corroboration)
- `grep -n "plans/\|plan_file\|\.md" agent-system/extensions/core/scripts/generate-todo.sh`
  (divergence-detector-absence verification)
- Full read of `reconcile-task-status.sh` (231 lines) and `reconcile-artifacts.sh` (partial,
  header + core logic) to confirm the two scripts are complementary, not overlapping
- Read of `commands/task.md` Sync Mode section (lines 413-484), `skill-orchestrate/SKILL.md`
  Stages 0-8 and MT-1/MT-2/MT-3, `skill-todo/SKILL.md` Stages 1-16, and
  `context/patterns/task-lock.md` in full
