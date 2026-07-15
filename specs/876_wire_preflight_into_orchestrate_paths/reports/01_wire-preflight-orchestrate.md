# Research Findings: Wiring the Missing Status-Transition Preflight into the `/orchestrate` Path

## Summary

The reported symptom — "tasks say PLANNED when they are being worked on" — is caused by
`skill-orchestrate` and `skill-orchestrate-hard` dispatching the Agent tool **directly** by
`subagent_type`, bypassing the top-level skills (`skill-implementer`, `skill-researcher`,
`skill-planner`) that own the status-transition preflight call. The transition capability
already exists and is correct (`update-task-status.sh` preflight actions); nothing invokes it on
the orchestrate path. The fix is to call the already-in-scope `skill_preflight_update()` wrapper
before each Agent dispatch. No new scripts.

## Verification of Cited Evidence (all confirmed accurate)

1. **`update-task-status.sh:92`** — confirmed. `preflight:implement) STATE_STATUS="implementing";
   TODO_STATUS="IMPLEMENTING"` exists exactly as claimed. The script is idempotent (lines
   133–144: no-op exit 0 if already at target status) and has useful preflight-only side effects
   currently never triggered by `/orchestrate`: a workflow-active marker write (lines 162–166)
   and auto-advance of the first `[NOT STARTED]` plan phase to `[IN PROGRESS]` (lines 260–270).
2. **`skill-orchestrate/SKILL.md`** — confirmed zero matches for `preflight` or
   `update-task-status` (`grep` exit code 1).
3. **`skill-orchestrate-hard/SKILL.md`** — confirmed exactly 2 matches, both postflight: a comment
   and the `update-task-status.sh postflight ... pr_ready ... --allow-pr-ready` skeleton-exhaustion
   branch. No preflight call anywhere.
4. **`skill-implementer/SKILL.md:76`** and **`skill-implementer-hard/SKILL.md:80`** — confirmed,
   both call `update-task-status.sh preflight ... implement ...` immediately before their own
   Agent dispatch, with matching postflight calls later.
5. **Zero agents reference `update-task-status.sh`** — confirmed (`grep -rl` over `.claude/agents/`
   returns nothing). Nothing downstream compensates.
6. **Root cause location** — confirmed. `skill-orchestrate/SKILL.md` Stage 4 State Handlers begin
   at line 193; the `planned`/`implementing` handler's Agent-tool dispatch table is at lines
   247–253.

All cited evidence checks out. No corrections needed.

## New Findings Beyond the Cited Evidence

**A. A ready-made wrapper already exists — this changes the (a)/(b) trade-off.**
`skill-base.sh` defines `skill_preflight_update()` (lines 142–149), a thin wrapper:
`update-task-status.sh preflight ...` + the `hooks.preflight` extension-hook call. It is the exact
mirror of `skill_postflight_update()` (lines 277–292), which `skill-orchestrate` **already calls**
in Stage 5 and Stage MT‑4, and which `skill-orchestrate-hard` calls in its Stage 5 equivalent.
Both orchestrate skills already `source .claude/scripts/skill-base.sh`, so `skill_preflight_update`
is already in scope, unused. Option (b) is therefore not "call the raw script" — it's "call the
same wrapper already used for postflight, for symmetry," which also picks up extension-hook parity
a raw script call would skip.

**B. The gap is identical for research and plan phases, not just implement.**
`skill-researcher/SKILL.md:71`, `skill-researcher-hard/SKILL.md:78`, `skill-planner/SKILL.md:79`,
and `skill-planner-hard/SKILL.md:72` all call their own `preflight` before dispatching. But
`skill-orchestrate`'s `not_started` handler dispatches `$RESEARCH_AGENT` directly, and its
`researched` handler dispatches `planner-agent` directly — both bypass the skills that contain
those preflight calls. So a task sits at `not_started` through an entire research dispatch, and at
`researched` through an entire planning dispatch, with zero preflight transition to
`researching`/`planning`. Same defect class, same fix shape.

**C. Multi-task mode (Stage MT‑4) has the same gap.** It batch-dispatches all three task groups
directly via the Agent tool, then only runs per-task `skill_postflight_update` afterward. No
preflight call anywhere in Stage MT‑4.

**D. Hard mode's per-phase dispatch (H1) compounds the visibility gap.**
`skill-orchestrate-hard`'s `planned`/`implementing` handler dispatches exactly one phase per
cycle, potentially across many cycles per task. Since `skill_postflight_update` only fires for
`dispatch_status ∈ {researched, planned, implemented}` and a mid-plan phase dispatch returns
`dispatch_status = "partial"`, status stays at `planned` across every one of those per-phase
cycles — the most severe instance of the reported symptom, in exactly the mode used for long,
multi-phase work where visibility matters most.

**E. The architecture doc already documents the intended-but-never-implemented behavior.**
`.claude/docs/architecture/orchestrate-state-machine.md`'s Complete State Table lists
`researching`/`planning` as reachable, meaningful states ("Wait / re-check (status update in
flight)"), implying `dispatch(research, task_n)` was always intended to set status to
`researching` before the dispatch resolves. Spec-vs-implementation drift, not just a missing
feature.

**F. Idempotency makes the fix low-risk to insert liberally.** Because `update-task-status.sh`
no-ops (exit 0) when already at the target status, `skill_preflight_update` is safe to call on
every dispatch cycle, including repeated per-phase implement dispatches in hard mode and the
`partial`-with-continuation resume branch.

## Recommendation: Option (b), via `skill_preflight_update()`

**Reject (a) — routing Stage 4 handlers through `skill-implementer`/`skill-researcher`/
`skill-planner`.** These are top-level skills invoked via the Skill tool, not composable functions
callable mid-loop from within another skill. Nesting a full skill invocation (with its own GATE
IN, context-loading, extension hooks, artifact validation, git-commit stage) inside
`skill-orchestrate`'s loop would duplicate status writes, double-fire extension hooks, and
conflict with `skill-orchestrate-hard`'s "pure dispatcher" tool-constraints contract
(`allowed-tools: Agent, Bash, Read` — no `Edit`). Large, architecture-changing diff for a problem
with a two-line fix per state handler.

**Recommend (b), specifically via the existing `skill_preflight_update()` wrapper.** This:
- Requires no new scripts (satisfies the constraint).
- Mirrors the already-used `skill_postflight_update()` pattern in the same files — minimal,
  consistent diff.
- Is already sourced and in scope in both orchestrate skills.
- Picks up the `hooks.preflight` extension-hook call for free.
- Naturally extends to research and plan phases and to Stage MT‑4 with the same
  one-line-per-dispatch-site change.
- Is idempotent/safe to call even on repeated per-phase hard-mode cycles.

## Concrete Insertion Points for the Plan

**`skill-orchestrate/SKILL.md`** (base):
- `not_started` handler (before the Agent tool table):
  `skill_preflight_update "$task_number" "research" "$session_id"`
- `researched` handler (before the Agent tool table):
  `skill_preflight_update "$task_number" "plan" "$session_id"`
- `planned`/`implementing` handler (before the Agent tool table):
  `skill_preflight_update "$task_number" "implement" "$session_id"`
- `partial` / continuation-available sub-state (before its Agent tool table): same `implement`
  call, for defense in depth (typically no-ops given the fix above).
- Stage MT‑4: add the matching `skill_preflight_update` call per task, per group, before each
  dispatch line, using `"${session_id}_${task_num}"` as the session id (matching the existing
  postflight call convention).

**`skill-orchestrate-hard/SKILL.md`**:
- `not_started` handler (before the Agent tool block): `research` preflight.
- `researched` H4 gate: `plan` preflight — placed immediately before the planner Agent tool call,
  i.e. *after* `adversarial_verified` is confirmed true, NOT before the verification-pass research
  re-dispatch.
- `planned`/`implementing` H1 per-phase handler (before the Agent tool call inside the
  `if [ -n "$next_phase" ]` branch): `implement` preflight.
- `partial` continuation sub-state: same `implement` call for consistency.

**Heading rename (both files)**:
- `skill-orchestrate/SKILL.md` `### Stage 2: Preflight — Loop Guard` → e.g. `### Stage 2: Loop
  Guard Initialization`. Drop "Preflight" entirely; that term is reserved elsewhere
  (`skill-base.sh`, `status-markers.md`, `inline-status-update.md`) for the status-transition
  operation this heading has nothing to do with.
- `skill-orchestrate-hard/SKILL.md` `### Stage 2: Preflight — Loop Guard and Churn State` →
  analogous rename, e.g. `### Stage 2: Loop Guard and Churn State Initialization`.

**Documentation follow-up** (durable anchor, no task-number citations):
`.claude/docs/architecture/orchestrate-state-machine.md`'s Complete State Table already describes
`researching`/`planning` as real, reachable states — add a short note there that `dispatch()` now
performs the preflight status transition immediately before invoking the Agent tool, keeping doc
and implementation in sync.

## Risks / Things the Planner Should Address

- **No existing test harness** covers `skill-orchestrate` behavior (nothing under `.claude/tests/`
  is orchestrate-specific) — the plan should include a manual verification step (drive a scratch
  task through each state, or a dry run of `/orchestrate` against a throwaway task) rather than
  relying on an automated regression test.
- **The H4 adversarial-verification re-dispatch loop** in `skill-orchestrate-hard` re-dispatches
  `$RESEARCH_AGENT` while status is `researched` — this must NOT get a `research`-preflight call
  (it would incorrectly regress status to `researching` for what is a verification pass within the
  already-completed research phase); only the final planner dispatch after
  `adversarial_verified=true` should get the `plan`-preflight call. Getting this ordering wrong
  introduces a new status-flicker bug.
- **The plan-file phase auto-advance and workflow-active marker write** (implement-only side
  effects of the underlying script) fire only once, on the first `planned→implementing`
  transition (idempotency short-circuits afterward). Confirm they don't collide with hard mode's
  per-phase heading-scan logic — they shouldn't — but call this out explicitly as a one-time-only
  side effect.
