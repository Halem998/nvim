# Research Report: Task #891

**Task**: 891 - Gate /orchestrate completed transition on phases_completed >= phases_total
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T07:14:00Z
**Effort**: research
**Dependencies**: None (wave-1 root; tasks 895 and 897 also edit both orchestrate SKILL.md files downstream)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`,
  `agent-system/extensions/core/scripts/update-task-status.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/skills/skill-implementer/SKILL.md`,
  `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`,
  `agent-system/extensions/core/agents/general-implementation-hard-agent.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect exists **only in the base `skill-orchestrate/SKILL.md`**, at two sites: the
  single-task Stage 5 case statement (`implemented)` branch, source-store lines 410-412) and
  the multi-task Stage MT-4 per-task postflight loop (source-store line 778, inside 764-790,
  which additionally never reads `phases_completed`/`phases_total` at all). Both call
  `skill_postflight_update ... implement "$dispatch_status"` unconditionally on
  `dispatch_status = "implemented"`, and `skill_postflight_update` maps that straight to
  `update-task-status.sh postflight <task> implement`, which maps unconditionally to
  `STATE_STATUS="completed"` with zero awareness of phase accounting.
- **Key correction to the task description**: `skill-orchestrate-hard/SKILL.md` at
  source-store lines 669-681 **already implements the exact guard requested** — gated on
  `[ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]`, with a
  comment citing "hard-mode-specific gate on `implemented` (772 Item 5B)" — i.e. it was already
  fixed by a prior task. This was verified against the live source-store file, not inferred from
  the task description. Task 891's hard-mode edit target should be re-scoped from "add the
  guard" to "confirm no regression / no further change needed" unless the fix pattern itself
  needs adjustment (see below).
- However, hard mode's own **Multi-Task Mode section explicitly delegates to base's Stage
  MT-1 through MT-5** ("Same as base `skill-orchestrate` multi-task stages... Hard-mode applies
  to each individual task in the wave"), so the ungated Stage MT-4 defect in the base file is
  live for hard-mode multi-task dispatch too. Fixing base Stage MT-4 fixes both variants for the
  multi-task path; only base Stage 5 (single-task, non-hard) needs a genuinely new edit.
- `update-task-status.sh` receives no phase-accounting arguments at all (only `operation`,
  `task_number`, `target_status`, `session_id`) and cannot currently backstop the guard even if
  it wanted to. Recommendation below: keep the guard in the skill layer as the primary fix (in
  scope for this task), and treat a script-layer defense-in-depth backstop as a small,
  bounded, separately-scoped follow-up (optional additive flags, default no-op) rather than
  folding it into this task.
- `phases_completed`/`phases_total` are **optional, top-level, defaulted-to-0 integer fields**
  on `.orchestrator-handoff.json` — not required, and not nested under `continuation_context` as
  the schema doc's "Complete JSON Schema" section illustrates (a documentation/implementation
  drift, noted below). `continuation_context` is unreliable as an alternative gate signal: it is
  `null` on every `"implemented"` handoff (partial-only field), including per-phase hard-mode
  "implemented" handoffs where more phases remain — so it cannot distinguish "phase done, task
  not done" from "task fully done." The `phases_completed >= phases_total` check (with the
  `phases_total > 0` precondition) is the only sufficient signal, matching the already-fixed
  hard-mode implementation.

## Context & Scope

Task 891 asks for a guard on the base-mode `dispatch_status = "implemented"` -> `completed`
transition in `skill-orchestrate/SKILL.md`, confirmation of the equivalent hard-mode site, and a
recommendation on whether `update-task-status.sh` should also refuse an
implement-postflight-to-completed transition when phase accounting contradicts it. All line
numbers below were re-verified directly against the SOURCE STORE
(`agent-system/extensions/core/`), per the binding source-store rule; the `.claude/` deploy copy
was spot-checked and found byte-identical at the relevant lines (expected, since it is
regenerated from source and no regeneration has happened since these lines were last edited).

## Findings

### Codebase Patterns

#### Site 1 — `skill-orchestrate/SKILL.md`, Stage 5 (single-task), lines 369-416

Current text (lines 386-416, source store):

```bash
  phases_completed=$(echo "$handoff" | jq -r '.phases_completed // 0')
  phases_total=$(echo "$handoff" | jq -r '.phases_total // 0')
  echo "[orchestrate] Dispatch result: $dispatch_status — $dispatch_summary"
  [ "$phases_total" -gt 0 ] && echo "[orchestrate] Phase progress: $phases_completed/$phases_total"

  # Drift detection: arithmetic gate (cheap check before expensive inspection fork)
  if [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
    completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
    is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
    if [ "$is_below_threshold" = "yes" ]; then
      echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
      invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
    fi
  fi

  # Postflight status update: trigger state.json + TODO.md Task Order regeneration
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      ;;
    *)
      echo "[orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac
```

- `phases_completed`/`phases_total` are read at line 386-387 (top-level fields on the handoff
  object, `// 0` default) and used only for the drift-detection branch (line 392, gated on
  `dispatch_status = "partial"`) and a log line (389). The `implemented)` case arm (410-412) is
  the **exact** defect site: it ignores both variables entirely.
- Drift detection cannot catch this failure mode even in principle, because it only fires when
  `dispatch_status = "partial"` — the observed failure had `dispatch_status = "implemented"`.
  This confirms the task description's framing: the completion gate and the drift-detection gate
  are two independent mechanisms, and only the latter currently exists on the `implemented` path.

#### Site 2 — `skill-orchestrate/SKILL.md`, Stage MT-4 (multi-task), lines 711-790

The multi-task per-task postflight loop (`### Stage MT-4: Phase-Aware Dispatch and Per-Task
Postflight`, lines 711-790) restates the same dispatch-status-to-postflight mapping for each task
in a wave, but is **more exposed than Site 1**: it never reads `phases_completed`/`phases_total`
from the handoff at all in this stage (no `jq -r '.phases_completed'` call anywhere in lines
711-790). Current text (lines 772-780, source store):

```
For each task in `research_tasks + plan_tasks + implement_tasks`:
1. Read `task_dir/.orchestrator-handoff.json`. If missing: mark task in `failed_tasks`, skip.
2. Extract `dispatch_status`, `dispatch_summary`, artifact path/type/summary.
3. Call `skill_postflight_update`:
   - `dispatch_status = "researched"` → `skill_postflight_update task_num "research" "${session_id}_${task_num}" researched`
   - `dispatch_status = "planned"` → `skill_postflight_update task_num "plan" "${session_id}_${task_num}" planned`
   - `dispatch_status = "implemented"` → `skill_postflight_update task_num "implement" "${session_id}_${task_num}" implemented`
   - Other → no postflight update
```

Step 3's `implemented` bullet (line 778, the line cited in the task description) is the second
required edit site. Step 5 immediately below (lines 781-784) already re-reads `fresh_status` from
`state.json` after postflight and only adds to `completed_tasks` when `fresh_status =
"completed"` — so once step 3 is gated (skipping the postflight call when phases are incomplete),
step 5 needs **no change**: `fresh_status` will correctly remain `"implementing"` and the task
will fall into the `Otherwise: set current_statuses[task_num] = fresh_status` branch, keeping it
eligible for a later cycle. This is a favorable finding — the multi-task fix is additive
(read phases_completed/phases_total, add the same conditional as Site 1) with no follow-on
changes required downstream in Stage MT-4/MT-5.

#### Site 3 (already fixed, verify only) — `skill-orchestrate-hard/SKILL.md`, Stage 5, lines 617-683

Current text (lines 661-683, source store):

```bash
  # Postflight status update — hard-mode-specific gate on `implemented` (772 Item 5B)
  case "$dispatch_status" in
    researched)
      skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status"
      ;;
    planned)
      skill_postflight_update "$task_number" "plan" "$session_id" "$dispatch_status"
      ;;
    implemented)
      # A single per-phase "implemented" handoff (skeleton or not) must NOT flip the whole task
      # to completed. Only transition when every phase is actually done.
      if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]; then
        skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
      else
        echo "[hard-orchestrate] Phase ${phases_completed}/${phases_total} complete (skeleton=${skeleton}). Continuing." >&2
        # Leave state as `implementing` — Stage 3a re-enters the Per-Phase Dispatch handler
        # (Stage 4, H1) on the next cycle. No postflight status transition happens here.
      fi
      ;;
    *)
      echo "[hard-orchestrate] Dispatch status '$dispatch_status' — no postflight update needed"
      ;;
  esac
```

This is line-for-line the guard the task requests (`phases_completed >= phases_total`, with the
`phases_total > 0` precondition to preserve current behavior for handoffs carrying no phase
accounting), already present and referencing a prior fix ("772 Item 5B"). **No edit is needed
here.** The task description's claim that `skill-orchestrate-hard/SKILL.md:669-673` is an
unguarded defect site does not match the current source-store content — the earlier fix already
landed. This should be treated as a **confirmation/no-op site** for task 891's implementation,
not an edit site, unless the planner wants to harmonize the exact wording/log format between the
base and hard-mode gates (cosmetic, optional).

Note the reason this matters structurally: hard mode's per-phase dispatch (H1) is why hard mode
needed this gate first and urgently — `general-implementation-hard-agent.md` (lines 258, 268-278)
documents that a single per-phase dispatch **legitimately returns `status: "implemented"`** for
just that one phase, with `phases_completed < phases_total` common and expected. In base mode,
by contrast, a single dispatch is documented to execute the **whole plan** in one shot ("Whole
plan per cycle" per the mode-comparison table at `skill-orchestrate-hard/SKILL.md` lines 791-799),
so an ungated `implemented` -> `completed` transition is not the *expected* per-cycle trigger path
there — it is a safety-net gap for agent misreporting (premature self-declaration, context
truncation, etc.), which is exactly the failure mode the observed lean4 run hit.

#### Site 4 (context, not an edit site) — Hard mode's Multi-Task Mode reuses base's ungated Stage MT-4

`skill-orchestrate-hard/SKILL.md` lines 782-786 state: "Same as base `skill-orchestrate`
multi-task stages (MT-1 through MT-5). Hard-mode applies to each individual task in the wave —
they each use the per-phase dispatch H1 loop above." This means fixing Site 2 (base Stage MT-4)
transitively fixes the multi-task path for hard mode as well — there is no separate hard-mode
Stage MT-4 to edit. This is a second correction to the task's "AFFECTS BOTH VARIANTS" framing:
the two files need edits at **three** total case-statement sites (base Stage 5, base Stage MT-4)
plus one confirmation-only site (hard-mode Stage 5), not four parallel edit sites.

### `update-task-status.sh`: exact behavior on an "implement" postflight

Verified directly (lines 143-168, 154 specifically):

```bash
map_status() {
  ...
  case "${op}:${target}" in
    ...
    postflight:implement) STATE_STATUS="completed";     TODO_STATUS="COMPLETED" ;;
    ...
  esac
}
```

`postflight:implement` maps **unconditionally** to `STATE_STATUS="completed"` /
`TODO_STATUS="COMPLETED"`. The script's argument surface (lines 10-19, parsed at 110-113) is
`<operation> <task_number> <target_status> <session_id> [--dry-run] [--allow-pr-ready]` — there
is no phase-accounting parameter anywhere in the script, and no caller in the source store
(`skill-base.sh`'s `skill_postflight_update`, `skill-implementer/SKILL.md` Stage 7, both
orchestrate skills) currently passes one. Beyond `state.json`, an implement postflight also
flips the **plan file's own Status field to `[COMPLETED]`** via `update_plan_file()` (lines
295-350, `plan_status="COMPLETED"` at line 304) — meaning the premature-completion bug does not
just mislabel `state.json`; on the observed 8-phase run it would also have stamped the plan
document itself as fully complete after phase 4, a second layer of corruption a script-level
backstop would also prevent.

Accepted `target_status` values (line 128): `research | plan | implement | pr_ready | partial |
blocked`. `partial` and `blocked` are explicitly documented (lines 156-162) as **postflight-only
task-level termini** with no preflight counterpart — i.e., the script already has precedent for
rejecting nonsensical operation/target combinations loudly (the catch-all at line 163-166 exits
1). This is relevant precedent for how a phase-accounting refusal could be added in the same
fail-loud style, if desired.

### Handoff schema contract for `phases_completed` / `phases_total` / `continuation_context`

- **Actual write-side implementation** (`scripts/skill-base.sh`,
  `skill_write_orchestrator_handoff()`, lines 497-566): both `phases_completed` and
  `phases_total` are **top-level, optional, integer fields**, sourced from caller-set env vars
  `ORCHESTRATOR_HANDOFF_PHASES_COMPLETED` / `ORCHESTRATOR_HANDOFF_PHASES_TOTAL`
  (lines 490-493, 535-536), **defaulting to `0`** when unset. `continuation_context` is likewise
  optional, sourced from `ORCHESTRATOR_HANDOFF_CONTINUATION_JSON`, **defaulting to `null`**
  (line 532).
- **Read-side (both orchestrate skills)**: `jq -r '.phases_completed // 0'` /
  `jq -r '.phases_total // 0'` — both consumers already treat the fields as optional-with-
  zero-default, which is exactly the safe posture task 891 asks to preserve ("Preserve the
  existing behavior when `phases_total` is 0 or absent").
- **Documentation drift** (informational, not required for this task): the schema's own
  "Complete JSON Schema" illustration in `docs/architecture/handoff-schema.md` (lines 39-87)
  shows `phases_completed`/`phases_total` **nested inside `continuation_context`**, not as
  top-level siblings — this does not match either the writer (`skill-base.sh`) or the two
  reader sites (both Stage 5 implementations), which all treat them as top-level fields. The
  doc's own worked examples ("Partial with Continuation", lines 330-358) are internally
  consistent with the nested placement, but disagree with the general field definitions used
  elsewhere in the same file's prose and with the actual code. This is a pre-existing,
  independent documentation-accuracy gap; flagging it here since this task's research scope
  explicitly asked about the schema contract, but it is not required to be fixed as part of
  gating the completion transition.
- **`continuation_context` is not a usable alternative or supplementary gate signal** for this
  task: it is written only for `status = "partial"` (writer default is `null`; see
  "When to Write `continuation_context`" in the schema doc). Hard-mode per-phase `"implemented"`
  handoffs — the exact case this task exists to guard — carry `continuation_context: null` by
  design (they are not partial), so checking `continuation_context == null` would either always
  pass (useless, since it's null on the not-done-yet handoffs too) or always fail depending on
  interpretation. The task description's phrasing ("gate ... on phases_completed >=
  phases_total (and/or continuation_context == null)") should be read as: use
  `phases_completed >= phases_total` as the sole condition; `continuation_context` is not an
  independently meaningful signal here and should not be added to the boolean expression.

### Recommendations

1. **Primary fix (in scope for this task), Site 1** — `skill-orchestrate/SKILL.md` lines
   410-412: replace the unconditional `implemented)` arm with the same pattern already proven in
   `skill-orchestrate-hard/SKILL.md` lines 669-679 — gate on
   `[ "$phases_total" -gt 0 ] && [ "$phases_completed" -ge "$phases_total" ]`, with an `else`
   branch that logs a `[orchestrate] Phase N/M complete. Continuing.` message and performs no
   status transition (state remains `implementing`, next cycle re-dispatches implement).
2. **Primary fix (in scope for this task), Site 2** — `skill-orchestrate/SKILL.md` Stage MT-4
   (around line 778): first add a read of `phases_completed`/`phases_total` from the per-task
   handoff (mirroring Stage 5's lines 386-387, scoped inside the per-task loop), then apply the
   same conditional to the `"implemented"` bullet. No changes needed to step 5 (lines 781-784) —
   it already handles a non-`"completed"` `fresh_status` correctly.
3. **Site 3 confirmation** — `skill-orchestrate-hard/SKILL.md` lines 669-683: no functional edit
   required; the guard already matches the requested behavior verbatim. The implementer should
   verify this during the implementation task rather than re-deriving it, and should update the
   task's plan/scope to reflect "confirm, don't re-fix" for this specific site, to avoid
   redundant or conflicting edits during the 895/897 chain that also touches these two files.
4. **`update-task-status.sh` defense-in-depth — recommend as a separate, small follow-up, not
   folded into this task.** Rationale: (a) it requires plumbing two new optional arguments
   through every call site that wants to opt in (`skill-base.sh`'s
   `skill_postflight_update`/`skill_write_orchestrator_handoff` wiring, both orchestrate Stage
   5/MT-4 sites, and optionally `skill-implementer/SKILL.md` Stage 7 which already has
   `phases_completed`/`phases_total` in scope from its own Stage 6 read of `.return-meta.json`);
   (b) the script is also called by `reconcile-task-status.sh`, `manage-topics.sh`, and
   `command-gate-out.sh` for other operations where phase accounting is not relevant, so any new
   flags must be strictly optional and default to current (unchecked) behavior to avoid
   regressing those callers; (c) the skill-layer fix (Sites 1-2 above) is the proximate,
   directly-requested fix for task 891's stated scope and is sufficient on its own to fix the observed failure
   mode, since both call sites that can produce a premature "implemented" postflight for
   orchestrator-dispatched work are the two sites being fixed. A script-level backstop is
   valuable insurance (it would have caught the case even if a future skill edit reintroduces the
   bug, or if a third, not-yet-existing call site is added later) but is a bounded, independently
   shippable enhancement: add optional `--phases-completed N --phases-total M` flags to
   `update-task-status.sh`; when both are provided, non-empty, and `phases_completed <
   phases_total` on a `postflight:implement` call, exit non-zero with a fail-loud message
   instead of mapping to `completed` (mirroring the existing fail-loud precedent at lines
   163-166 for unknown operation/target combinations); when either flag is absent, preserve
   current unconditional behavior exactly. Recommend spinning this into its own task rather than
   growing task 891's diff, since it touches a shared, multi-caller script.

## Decisions

- Scope task 891's implementation to two skill-layer edits (base Stage 5 lines 410-412, base
  Stage MT-4 around line 778) plus a verification-only pass over the already-fixed hard-mode
  Stage 5 (lines 669-683) — do not re-edit the hard-mode site.
- Do not add `continuation_context == null` to the gating condition; `phases_completed >=
  phases_total` (with `phases_total > 0` precondition) is the sole, sufficient signal.
- Recommend (not require) a separate follow-up task for the `update-task-status.sh`
  defense-in-depth backstop, scoped as optional additive flags with no behavior change for
  existing callers that omit them.

## Risks & Mitigations

- **Risk**: Editing base Stage MT-4 without adding the `phases_completed`/`phases_total` read
  first would silently leave the variables unset (bash unbound-variable or stale-value bugs
  under `set -u`-style discipline used elsewhere in this codebase). **Mitigation**: the plan must
  include the read step (mirroring Stage 5 lines 386-387) as an explicit sub-step before the
  conditional, scoped per-task inside the MT-4 loop (each task's handoff must be read fresh, not
  reused from a prior task in the same wave).
- **Risk**: tasks 895 and 897 (per the dependency note) also edit both orchestrate SKILL.md
  files; if task 891 lands first without tight scoping, merge/edit conflicts or duplicated gate
  logic are possible. **Mitigation**: keep task 891's diff minimal and localized to the three
  sites identified above; document the "already fixed, do not re-touch" status of the hard-mode
  site clearly in the implementation plan so 895/897 do not attempt to re-add it.
- **Risk**: A future regression could remove the guard from either orchestrate skill without a
  script-level backstop noticing. **Mitigation**: covered by the recommended (separately-scoped)
  `update-task-status.sh` defense-in-depth follow-up.

## Context Extension Recommendations

- **Topic**: Orchestrator handoff `phases_completed`/`phases_total` field placement.
- **Gap**: `docs/architecture/handoff-schema.md`'s "Complete JSON Schema" section (lines 39-87)
  shows these fields nested under `continuation_context`, but the actual writer
  (`scripts/skill-base.sh`'s `skill_write_orchestrator_handoff`) and both reader sites
  (`skill-orchestrate/SKILL.md` Stage 5, `skill-orchestrate-hard/SKILL.md` Stage 5) treat them as
  top-level fields.
- **Recommendation**: a future meta/docs task should update the schema's top-level example to
  include `phases_completed`/`phases_total` as siblings of `status`/`artifacts` (as the code
  already does), and clarify that the nested placement inside `continuation_context` is specific
  to the `"partial"`-status "Partial with Continuation" example, not a general rule. Not required
  for task 891.

## Appendix

- Search queries / commands used: `wc -l` on the three target files; `grep -n` for
  `implemented)`, `phases_completed`, `phases_total`, `orchestrator-handoff`,
  `skill_write_orchestrator_handoff`, `continuation_context` across
  `agent-system/extensions/core/{skills,scripts,agents,docs}`; `sed -n` extracts of exact current
  line ranges for citation; a `diff` spot-check of `.claude/skills/skill-orchestrate/SKILL.md`
  lines 380-420 against the source-store equivalent (found byte-identical).
- Key files read in full or in relevant part: `skills/skill-orchestrate/SKILL.md` (lines 1-449,
  619-843), `skills/skill-orchestrate-hard/SKILL.md` (lines 600-800), `scripts/update-task-status.sh`
  (full, 413 lines), `scripts/skill-base.sh` (lines 340-566), `skills/skill-implementer/SKILL.md`
  (lines 300-560), `skills/skill-implementer-hard/SKILL.md` (grep only — confirmed it reads but
  never writes `.orchestrator-handoff.json`), `agents/general-implementation-hard-agent.md`
  (grep — confirmed per-phase `"implemented"` contract), `docs/architecture/handoff-schema.md`
  (full), `context/formats/return-metadata-file.md` (full).
