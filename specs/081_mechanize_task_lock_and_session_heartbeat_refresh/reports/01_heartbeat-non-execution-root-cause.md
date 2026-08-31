# Research Report: Task #81

**Task**: 81 - Mechanize task-lock and session-registry heartbeat refresh: liveness timestamps never advance during a multi-phase /implement run
**Started**: 2026-08-31T00:00:00Z
**Completed**: 2026-08-31T00:00:00Z
**Effort**: 3-6 hours (task estimate)
**Dependencies**: None declared; cross-reference only to the subagent-postflight marker-ownership task (project 73) and the empty-block-reason task (theme overlap, no file_scope overlap)
**Sources/Inputs**:
- Live agent transcript: `~/.claude/projects/-home-benjamin-Philosophy-Papers-PossibleWorlds/f3a8ce42-59cc-456c-9245-57f3ae49e944/subagents/agent-aimpl-111-8f34b1e2c9ce0b59.jsonl` (the actual `general-implementation-agent` subagent run for the observed incident, `/implement 111`, session `sess_1787265639_358e17`)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 4D)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/scripts/task-lock.sh` (`cmd_heartbeat`, `cmd_session_heartbeat`, `resolve_task_dir`)
- `agent-system/extensions/core/scripts/update-phase-status.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`
- `agent-system/extensions/core/commands/implement.md`
- `specs/state.json` (project 73, project 81)
- Empirical shell tests (`printf "%03d"` on a literal brace placeholder)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause is empirically CONFIRMED as hypothesis (a) STRUCTURAL, in a stronger form than the task description anticipated.** The task-lock/session-registry heartbeat calls in `general-implementation-agent.md` Stage 4D did not fail on execution — they were **never emitted at all**, in any of the 8 phase-completion transitions of the real, successful `/implement 111` run. The captured subagent transcript contains 16 `update-phase-status.sh` invocations and 8 `git-commit-scoped.sh` invocations (all confirmed via `is_error: False` tool results), and exactly **zero** invocations of `task-lock.sh heartbeat` or `task-lock.sh session-heartbeat`.
- Hypotheses (b) SILENT FAILURE and (c) FALLBACK PATH are **ruled out** for this incident: nothing ran to fail, and the `update-phase-status.sh` primary path succeeded every time (no Edit-tool fallback was used). Hypothesis (d) CONDITIONAL NO-OP remains a real, separate latent risk (verified in source) but is not what happened here — it requires the call to execute first.
- The placeholder-substitution risk flagged in (b) is real and independently confirmed as a landmine (`printf "%03d" "{task_number}"` exits 1 and would make `resolve_task_dir` fail), but it is moot for this incident since the call was never attempted; it remains a hazard for whichever future mechanization mechanism ends up re-emitting these calls as agent-authored bash.
- **Recommended direction**: mechanize the refresh at `update-phase-status.sh` (the one script empirically proven, 16/16, to run at every phase transition in this file), rather than trusting agent prose. `update-phase-status.sh` currently takes exactly 4 positional args and has no session/SESSION reference — it needs a 5th optional `session_id` arg (or a wrapper) to thread the heartbeat through. This is consistent with the task's own candidate direction and is now evidence-backed rather than merely plausible.
- Call-site survey found the hazard is **wider than the observed site**: `general-implementation-hard-agent.md` carries **zero** heartbeat mentions (an absent-caller gap, not a failing-caller gap), and `skill-orchestrate-hard/SKILL.md` likewise has no actual heartbeat call sites (only a comment referencing the mutex). `skill-orchestrate/SKILL.md`'s two call sites (lines 313/318, plus 1518) are present and use correct `$shell_var` substitution, but are the same category of unenforced prose and were not empirically verified to fire (no live multi-cycle `/orchestrate` transcript was available for this research).
- The `events.jsonl` cross-session-attribution second finding is a genuine, separately-verified defect that should be **filed as a recorded amendment to project 73** (`correlate_subagent_postflight_hook_to_owning_session`, status `not_started`), not fixed under this task — no file_scope overlap exists, and the fix's correctness criterion (event attribution, not marker selection) belongs with the task that already owns `head -1` marker selection.

## Context & Scope

This is task 81's research phase. The task description (fully reproduced in the delegation
context and `specs/state.json`) pre-establishes the CRUX — the heartbeat calls exist in source,
routing reaches the agent that carries them, and the whole liveness design depends on them — and
instructs research to determine WHY, empirically, they never fired during the observed
`/implement 111` run, without pre-committing to any of hypotheses (a)-(d). The instruction to
"check placeholder substitution and cwd empirically before anything else" was followed literally:
this research located and read the actual subagent transcript for the incident run before doing
any further source-reading, which turned out to make the entire hypothesis space resolvable
directly rather than by inference from the markdown source.

Scope: establish root cause; survey all listed call sites; record decisions on the two secondary
threads (pid liveness/defense-in-depth, the never-heartbeated fingerprint, and the events.jsonl
cross-session finding's placement) as directions for the planning phase, not as implemented
fixes. No files were modified — this is a research-only report.

## Findings

### The decisive artifact: the incident's own subagent transcript exists and is complete

The observed incident (`/implement 111` in the PossibleWorlds repo, session
`sess_1787265639_358e17`, PID 263643) left a full Claude Code subagent transcript on disk:

```
~/.claude/projects/-home-benjamin-Philosophy-Papers-PossibleWorlds/f3a8ce42-59cc-456c-9245-57f3ae49e944/subagents/agent-aimpl-111-8f34b1e2c9ce0b59.jsonl
```

This is the actual `general-implementation-agent` dispatch that executed the run described in
the task's OBSERVED LIVE section — the same session ID, the same task number, the same holder.json
values (`acquired_at`/`heartbeat_at` both `2026-08-20T22:40:39Z`, confirmed byte-identical inside
a `tool_result` at transcript line 340). Rather than reasoning about what the agent *should* have
done from the markdown source alone, this transcript shows exactly what bash commands the agent
*actually issued*.

### What actually ran, 8-for-8

Every one of the plan's 8 phases produced two bundled bash blocks (IN_PROGRESS transition, then
COMPLETED transition + progress-file write + git commit), all following an identical shape:

```bash
cd /home/benjamin/Philosophy/Papers/PossibleWorlds
task_number=111
project_name=verify_interval_twisted_arrow_lemma
bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" <P> COMPLETED 2>&1 | tail -5

cat > specs/111_verify_interval_twisted_arrow_lemma/progress/phase-<P>-progress.json <<'EOF'
...
EOF
task_dir="specs/111_verify_interval_twisted_arrow_lemma"
session_id="sess_1787265639_358e17"
bash .claude/scripts/git-commit-scoped.sh \
  --message "task 111 phase <P>: <phase_name>" \
  --session "$session_id" \
  -- "${task_dir}/" specs/TODO.md specs/state.json <touched files> 2>&1 | tail -20
```

Confirmed programmatically against the transcript:
- **16** `update-phase-status.sh` invocations (8 `IN_PROGRESS` + 8 `COMPLETED`), all with `is_error: false` in their tool results (spot-checked; the run's own success through 8 phases corroborates all 16).
- **8** `git-commit-scoped.sh` invocations, each with `session_id` set as an actual shell variable **immediately above** its use and passed correctly — proving the agent *does* correctly perform value substitution for this file's `$var`-style placeholders when the call is actually included in its bash block.
- **0** `task-lock.sh heartbeat` invocations.
- **0** `task-lock.sh session-heartbeat` invocations.
- Grepping the entire 356-line transcript for the substring `"heartbeat"` returns exactly **one** hit, and it is not a command — it is the literal `heartbeat_at` JSON field name appearing inside a `holder.json` dump the agent cat'd out during a *diagnostic* check near the very end of the run (transcript line 339, `task-lock.sh release` diagnostics), not a phase-transition heartbeat call.

This directly falsifies hypotheses (b) and (c) as stated ("the calls ran but failed" / "the
fallback path bypassed the heartbeat site") and confirms (a): the calls are pure prose in a
markdown agent-definition file, and the LLM executing that file's Stage 4D simply never included
them in its actual tool-use stream, across 8 consecutive opportunities in a real successful run.
This is not selective failure under some condition — it is total, unconditional omission of an
instruction the agent otherwise clearly had access to (it is in the very same file, a few lines
below the block the agent DID execute every time).

### Why hypothesis (a) is structural, and a plausible mechanism for the omission

Stage 4D's "D. Mark Phase Complete" section is authored as:
1. A single fenced bash block for `update-phase-status.sh` — the block the agent visibly treats
   as "the command for this step."
2. A "Fallback" paragraph (Edit-tool alternative).
3. A "Phase status lives ONLY in the heading" note.
4. A **separate**, bold-lead-in paragraph — "**Task-lock heartbeat**: at this same
   phase-transition point, ..." — with its own fenced bash block, using brace-placeholder form
   (`"{task_number}"`, `"{session_id}"`) rather than the `$task_number`/`$session_id` shell-var
   form used in the block immediately above it and used throughout the rest of the file for the
   same values.
5. A further separate paragraph — "**In-flight session registry heartbeat**: immediately
   adjacent to the task-lock heartbeat above, ..." — with a third fenced bash block, same
   brace-placeholder convention.

Two structural properties compound: (i) the heartbeat instructions are visually and structurally
*trailing commentary* rather than a bundled, numbered part of the "Mark Phase Complete" checklist
item the agent already reliably executes; (ii) they use the file's *other* placeholder
convention (bare `{token}` prose markers, elsewhere in this same file reserved for values a
downstream template — like a `--session "{session_id}"` argument to a *different* subagent's
prompt string — must literally construct textually, not values to substitute into an
already-executing bash command). Both properties make it easy for an LLM constructing its Stage
4D tool call to treat the heartbeat paragraphs as descriptive prose about the design ("refresh
the task lock so a run never goes stale...") rather than as an executable step co-equal with
`update-phase-status.sh`. The empirical result — 0/8 — is consistent with exactly that reading.

### The placeholder-substitution hazard is real, independent of the above

Confirmed empirically in this research (not merely argued):

```
$ printf "%03d" "{task_number}"
000
exit=1
```

If a call *were* emitted with the literal, unsubstituted brace placeholder, `cmd_heartbeat`'s
first step — `padded=$(printf "%03d" "$task_number" 2>/dev/null) || return 1` — fails
immediately (`printf`'s own non-numeric-argument error triggers the `2>/dev/null`-then-`||
return 1` path), `resolve_task_dir` returns 1, `cmd_heartbeat` prints `ERROR: could not resolve
task directory for task {task_number}` to stderr and returns 2 — and the caller's
`2>/dev/null || true` discards all of it. This is a genuine, verified silent-failure landmine
for any future mechanization that re-emits these calls as agent-authored bash using
brace-placeholder syntax. It did not cause the observed incident (nothing was emitted to trigger
it), but it is a concrete argument against "the fix is clearer prose" — even *correctly worded*
prose using the wrong placeholder convention would silently no-op.

### cwd was not a factor in this incident

Every phase-transition bash block observed in the transcript opens with an explicit
`cd /home/benjamin/Philosophy/Papers/PossibleWorlds` before any script invocation, and this
`cd` is present and correct in all 8 blocks. The relative-path hazard flagged in hypothesis (b)
("Agent threads reset cwd between bash calls") is real in general (confirmed structurally: each
Bash tool call in this transcript does start a fresh shell, and the agent evidently knows this
and compensates by re-`cd`-ing every time) but did not contribute to this incident, since the
calls that *were* made all resolved correctly from the re-established cwd.

### Fallback path (hypothesis c) not taken

No `Edit` tool call touching a `[IN PROGRESS]`/`[COMPLETED]` phase heading was found anywhere in
the transcript. All 16 phase-status transitions went through the primary `update-phase-status.sh`
path, confirmed successful. Hypothesis (c) is ruled out for this incident.

### Conditional no-op in `cmd_heartbeat`/`cmd_session_heartbeat` (hypothesis d) — real but not causal here

Both functions verified to no-op-with-WARN (never a hard failure) on: no lock directory /
missing holder.json, and holder `session_id` mismatch (`cmd_heartbeat`, lines ~831-853;
`cmd_session_heartbeat` mirrors this at ~1283-1305 for a missing/unparseable session entry).
This is a legitimate, separately-worth-fixing defense-in-depth gap for whatever call site ends
up actually firing (see Decisions below), but it cannot be the cause of the observed incident
since the call was never invoked to reach this logic at all.

### Call-site survey (task's "SURVEY REQUIREMENT")

| Site | Present? | Form | Empirically confirmed firing? |
|---|---|---|---|
| `general-implementation-agent.md` Stage 4D (single-task `/implement`, the observed site) | Yes, lines ~283/296 | Brace-placeholder (`"{task_number}"`, `"{session_id}"`) | **No — confirmed NOT firing, 0/8, via live transcript** |
| `general-implementation-hard-agent.md` | **Absent** — zero occurrences of "heartbeat" anywhere in the file | N/A | N/A (absent-caller gap, not a failing-caller gap; hard-mode `/implement` has never had this hook at all) |
| `skill-orchestrate/SKILL.md` lines ~313/318 (multi-cycle `/orchestrate` loop) | Yes | Shell-var (`"$task_number"`, `"$session_id"`) — the *correct* form, unlike the agent file | Not verified this research (no live multi-cycle `/orchestrate` transcript was located); same unenforced-prose risk class as the confirmed-failing site, since `skill-orchestrate` is a direct-execution skill (prose read and run by the orchestrating Claude session itself, same mechanism that failed above) |
| `skill-orchestrate/SKILL.md` line ~1518 (batch session-heartbeat) | Yes | Shell-var | Not verified this research |
| `skill-orchestrate-hard/SKILL.md` | **Absent as an actual call** — only a passing mention inside a comment ("the real same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex...") | N/A | N/A (absent-caller gap, same category as the hard-mode implementation agent) |
| `commands/implement.md` lines ~169-183 | Documents an *intentional* omission of an intra-batch session heartbeat, explicitly deferring to "the per-*phase* heartbeat ... one layer down, inside each dispatched `general-implementation-agent.md`'s Stage 4D" | — | **This deferral's premise is now falsified.** The reasoning was sound in structure (a per-cycle-loop heartbeat at this layer would be redundant with the per-phase one) but the per-phase one it defers to does not fire. Net effect: the single-task `/implement` path currently has **no working heartbeat at any layer**, not merely a redundancy-avoided one. |

**Systemic reading**: every confirmed-present call site in this system is unenforced markdown
prose, read and executed (or not) by an LLM at its own discretion. The one site with hard
empirical evidence (Stage 4D) shows 0% execution over 8 real opportunities. There is no evidence
either direction for the `skill-orchestrate` sites — they were not exercised by any transcript
this research located — but they share the identical risk profile (unenforced prose, executed by
an LLM reading a `SKILL.md` directly) and should not be assumed reliable merely because their
placeholder syntax is more careful than the failing site's. Design question 1 from the task
("does heartbeat refresh belong in agent prose at all?") is answered by this research: no —
the one site tested empirically fired 0/8, and nothing about the *content* of that prose
(clarity, placement, placeholder form) explains the omission better than "prose instructions
compete with, and lose to, the agent's own judgment about what constitutes the actionable step."

### Severity: 30-minute threshold crossing, inconclusive from available telemetry

`specs/events.jsonl` in this repo (nvim config) carries a `duration_seconds` field, but it
measures only individual lifecycle-stage spans (pre/postflight), sub-minute in every sample
checked, not whole-run wall-clock time — it could not be used to establish whether any real
`/implement` run in *this* repo has crossed the 30-minute `TASK_LOCK_STALE_MIN` threshold. The
observed incident itself (PossibleWorlds, `/implement 111`) ran ~18 minutes, under the
threshold, so the honest severity statement from the task description stands unchanged by this
research: this is a live latent hazard whose blast radius scales with run length, not an
already-fired incident. Establishing whether any run anywhere has crossed 30 minutes would
require either broader telemetry mining than this research's scope covered or a live long-running
reproduction (see Decisions/Recommendations for the acceptance-criterion-1 reproduction this
implies for the plan/implementation phase).

### Second finding: events.jsonl cross-session attribution — placement decision

Independently verified (not re-derived beyond confirming the described mechanism in source):
`agent-system/extensions/core/hooks/subagent-postflight.sh`'s `find_marker()` does
`find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1` — an
arbitrary, uncorrelated marker selection, exactly as described in project 73's own task
description (`specs/state.json`, project 73, `correlate_subagent_postflight_hook_to_owning_session`,
status `not_started`). Project 73 already owns this `head -1` selection defect and its
consequences. Per the task-81 description's own default expectation, the events.jsonl
cross-session misattribution is a **consequence** of that same defect, not a distinct root cause,
and should not be fixed under task 81 (no file_scope overlap exists between task 81's declared
scope and `agent-system/extensions/core/hooks/`).

## Decisions

- **Root cause is hypothesis (a) STRUCTURAL**, empirically confirmed via the incident's own
  subagent transcript: the heartbeat calls were never emitted, not emitted-and-failed. This
  should be stated as settled fact in the plan, not re-investigated.
- **Do not mechanize by improving the prose.** The placement/wording/placeholder-form
  differences between the failing site (brace-placeholder, trailing paragraph) and the
  untested-but-more-careful `skill-orchestrate` sites (shell-var form) do not explain a 0/8
  result satisfactorily enough to bet on "better prose" as the fix; recommend the plan phase
  treat "move to a mechanically-invoked script" as the baseline direction per the task's own
  design-question 1, using `update-phase-status.sh` (proven 16/16 in the transcript) as the
  concrete mechanization anchor for the single-task `/implement` path, needing a 5th optional
  `session_id` positional arg or equivalent threading mechanism — exactly the candidate the task
  description names, now evidence-backed.
- **`general-implementation-hard-agent.md` and `skill-orchestrate-hard/SKILL.md` need the
  heartbeat call sites added (absent-caller gap), not fixed** — the survey found no existing
  instruction there to have failed. Whatever mechanization mechanism is chosen for the base-mode
  path should be extended to (or reused directly by) both hard-mode counterparts rather than
  re-authoring a second prose instruction that would carry the identical risk.
- **`skill-orchestrate/SKILL.md`'s call sites (313/318/1518) are unverified, not confirmed-good.**
  Recommend the plan phase treat them as "same risk class, no positive evidence either way" and,
  if the mechanization approach generalizes cleanly, fold them into the same mechanized mechanism
  rather than leaving them as the one remaining prose-based site once the higher-severity
  single-task path is fixed.
- **`implement.md`'s "no intra-batch session heartbeat" reasoning needs a documentation update**,
  not necessarily a behavior change: its stated justification ("the per-phase heartbeat...is what
  makes it resolve correctly") is now known to be false in the base-mode agent's current state.
  Once Stage 4D's heartbeat is mechanized and verified firing, this reasoning becomes true again
  and the existing intentional-omission stands; until then the comment is misleading and should
  be flagged for correction alongside the fix.
- **The events.jsonl cross-session attribution finding is filed as a recorded amendment
  recommendation to project 73** (`correlate_subagent_postflight_hook_to_owning_session`), not
  fixed under this task. This report records the decision per the task's acceptance criterion 8;
  actually amending project 73's acceptance criteria is left to whoever next touches that task
  (planning or a dedicated `/spawn`/task-description edit), since this research task's own
  `file_scope` does not include `agent-system/extensions/core/hooks/`.
- **Defense-in-depth (pid liveness on `holder.json`) and the never-heartbeated fingerprint
  (`acquired_at == heartbeat_at`) are validated as real, still-open design questions** — this
  research confirms both premises from source (`write_holder` persists exactly 7 fields, no pid;
  `cmd_reap`/`cmd_acquire`'s stale-override have nothing but the timestamp to act on) but does
  not resolve them; they are plan-phase decisions per the task's acceptance criteria 6-7, and
  should be weighed alongside whichever mechanization approach is chosen, since a pid-aware
  reaper reduces the blast radius of *any* future heartbeat gap, not just this one.

## Risks & Mitigations

- **Risk**: mechanizing via `update-phase-status.sh` adds a 5th positional arg, which is a
  breaking-signature change for every existing caller of that script. **Mitigation**: make the
  new arg optional (default empty/no-op when absent) so existing callers without a session_id
  keep working; only the Stage 4D call site threads a real value.
- **Risk**: silently swallowing heartbeat no-ops (`2>/dev/null || true`) is correct for
  "never block phase progression" but is exactly what made this incident undiagnosable for 8
  consecutive transitions. **Mitigation** (task's design question 3): separate "never block" from
  "never report" — e.g., append a one-line trace to a log file or the progress-file's own
  metadata on a no-op, without making the call itself blocking. This is a plan-phase decision,
  not implemented here.
- **Risk**: fixing only the confirmed-failing site (Stage 4D) leaves the hard-mode agents and
  `skill-orchestrate-hard` with the pre-existing absent-caller gap, understating the task's own
  "do not spot-fix one call site" requirement. **Mitigation**: plan phase should size the fix to
  cover all four call-site categories identified in the survey table above, or explicitly and
  individually justify deferring each one.
- **Risk**: this research could not establish whether any real run has crossed the 30-minute
  stale threshold, so the severity argument rests on the task description's own honest framing
  (a latent hazard, not a fired incident) rather than a confirmed additional data point.
  **Mitigation**: none needed for research; the plan/implementation phase's acceptance-criterion-1
  reproduction (a real multi-phase `/implement` showing `heartbeat_at` advancing) is the load-
  bearing verification regardless of historical threshold-crossing evidence.

## Context Extension Recommendations

- **Topic**: prose-instruction reliability in agent/skill markdown files.
- **Gap**: this is the second concretely-measured case (after the events.jsonl/`head -1`
  arbitrary-marker theme) of a documented, structurally-sound bash snippet in an agent contract
  simply not being executed by the LLM reading it, with a 2>/dev/null-swallowed failure mode
  making it undiagnosable in production. There is no existing context file cataloguing this as a
  systemic risk class (as opposed to a one-off defect per file).
- **Recommendation**: consider a `context/patterns/` or `context/standards/` note on when a
  behavior MUST be mechanized (invoked from a script/hook the lifecycle calls unconditionally)
  versus when agent prose is acceptable (non-critical, cosmetic, or already covered by an
  independent enforcement layer) — this task's own resolution, once implemented, would be a good
  worked example to cite.

## Appendix

### Search queries / commands used

- `jq`/`python3 -c` queries against `specs/state.json` (`active_projects[]`) to load task 81's
  full description and to locate project 73.
- `grep -n "Stage 4D"` / targeted `sed -n` ranges against `general-implementation-agent.md` to
  read Stage 4D verbatim.
- `grep -n '\$task_number\|\$project_name\|\$phase_num\|\$session_id\|{task_number}\|{session_id}\|{project_name}\|{phase_num}'` against the same file to establish the file's two competing placeholder conventions.
- `printf "%03d" "{task_number}"` — direct empirical test of the placeholder-substitution
  hazard against `cmd_heartbeat`'s first line.
- `sed -n` / `grep -n` against `task-lock.sh` (`cmd_heartbeat`, `cmd_session_heartbeat`,
  `resolve_task_dir`, `cmd_release`) to confirm the no-op/no-pid/silence contract described in
  the task.
- `grep -n` against `update-phase-status.sh` to confirm its 4-arg signature and absence of
  session logic.
- `find / -maxdepth 6 -iname "*358e17*"` and `grep -rl "358e17" ~` to locate the incident's own
  Claude Code subagent transcript on disk.
- `python3 -c` (json parsing) against the located transcript
  (`agent-aimpl-111-8f34b1e2c9ce0b59.jsonl`) to enumerate every `Bash` and `Edit` tool_use call,
  count `update-phase-status.sh`/`git-commit-scoped.sh`/`heartbeat` occurrences, and confirm
  `is_error` status on results.
- `grep -n "heartbeat"` against `general-implementation-hard-agent.md`, `skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md`, and `sed -n` against `commands/implement.md` for the
  call-site survey.
- `grep -n "marker.ownership\|subagent-postflight\|head -1"` against `specs/TODO.md`/`state.json`
  and `subagent-postflight.sh` to verify the events.jsonl second-finding placement decision.
- `python3 -c` (json parsing) against `specs/events.jsonl` attempting to establish 30-minute
  threshold-crossing history; inconclusive given the field's per-stage (not per-run) granularity.

### Key file:line references

- `agent-system/extensions/core/agents/general-implementation-agent.md:270,283,296` — the
  `update-phase-status.sh` call and the two heartbeat paragraphs (brace-placeholder form).
- `agent-system/extensions/core/scripts/task-lock.sh:831-853` — `cmd_heartbeat`.
- `agent-system/extensions/core/scripts/task-lock.sh:1283-1305` — `cmd_session_heartbeat`.
- `agent-system/extensions/core/scripts/task-lock.sh:249-280` — `resolve_task_dir`.
- `agent-system/extensions/core/scripts/update-phase-status.sh:3` — usage line, confirms 4-arg
  signature, no session parameter.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:308-318,1511-1518,2115` —
  the `/orchestrate` multi-cycle and batch heartbeat sites, and the bare-`session_id` threading
  rationale.
- `agent-system/extensions/core/commands/implement.md:169-183` — the intentional
  no-intra-batch-heartbeat reasoning, now stale pending Stage 4D's fix.
- `agent-system/extensions/core/hooks/subagent-postflight.sh:20` — `find_marker()`'s `head -1`
  arbitrary selection underlying the events.jsonl second finding.
