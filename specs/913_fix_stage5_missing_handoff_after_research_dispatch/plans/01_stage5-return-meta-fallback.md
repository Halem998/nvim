# Implementation Plan: Task #913

- **Task**: 913 - fix_stage5_missing_handoff_after_research_dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: `specs/913_fix_stage5_missing_handoff_after_research_dispatch/reports/01_stage5-research-handoff-mismatch.md`
- **Artifacts**: plans/01_stage5-return-meta-fallback.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/orchestrate` Stage 5 reads `.orchestrator-handoff.json` after every dispatch and treats its
absence as a defect, but the only agent that writes one is the hard-mode implementation agent.
Research dispatches are contractually forbidden from writing one, and base-mode plan and implement
dispatches simply never implemented it — so a successful dispatch routinely lands in a branch that
performs no postflight status update, stranding the task at `researching`/`planning`/`implementing`
until a human intervenes. This plan adds `.return-meta.json` as a second outcome channel: a new
shared helper script normalizes it into the same fields Stage 5 already reads from a handoff, and
three call sites (base Stage 5, hard Stage 5, multi-task Stage MT-4 step 1) consult it before
declaring a defect. Definition of done: a research dispatch that writes only `.return-meta.json`
drives the same `researching -> researched` postflight transition and artifact link that a handoff
would have, with no change to the handoff-present path and no new agent-side writing obligations.

### Research Integration

The plan follows the research report's recommendations 1-4, 6, 7 and its two binding corrections:

- **Not research-specific.** The fix covers every dispatch whose writer is documented as "Not
  implemented" in `handoff-schema.md`'s Handoff Writers table — base-mode researcher, planner, and
  implementer alike. There is no plan-vs-research special case; the report refuted that premise
  against the current source and a ~200-file live artifact census.
- **Do not re-break `skill-orchestrate-hard`'s H4 / H5 / Stage 6 sub-dispatches.** Those already
  pass `orchestrator_mode: false`, omit the `task_dir`/`handoff_path` anchor, and skip the Stage 5
  handoff read entirely. They are out of scope and must be left byte-identical. Only the *primary*
  Stage 4 dispatches in both orchestrate skills, plus Stage MT-4, are in scope.
- **Candidate (b) is rejected.** Making research agents write handoffs would require amending the
  standalone Stage 3.6 "Scoping Decision" prohibition in both research agents plus the consumer
  allowlist in `context/contracts/wrap-up.md` and the Handoff Writers table — a much larger contract
  change that still would not cover base-mode plan/implement. Reading a file those dispatches
  already write is strictly smaller.
- **`command-gate-out.sh` is the precedent.** It already uses `.return-meta.json`'s `.status` as its
  sole outcome channel for the non-orchestrator `/research`, `/plan`, `/implement` path. This plan
  extends the same channel to the orchestrator path rather than inventing a third mechanism.

**One deliberate deviation from the research report.** Recommendation 5 is internally inconsistent:
it says a recovered success should "not be charged against MAX_CYCLES" and then says it should be
"charged as a normal, successful cycle-completing dispatch." This plan takes the second reading and
charges exactly one work cycle, identical to the handoff-present success path. Rationale: the
infra exemption exists because *no work happened*; on a recovered success real work happened and
produced a status transition, so it is the same event as a handoff-present success and must cost the
same. Exempting it would also remove the only bound on a loop that keeps recovering.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap phases were requested; no
ROADMAP.md was consulted or modified.

## Goals & Non-Goals

**Goals**:

- A dispatch that writes `.return-meta.json` but no handoff drives the correct postflight status
  transition and artifact link automatically, in single-task base mode, single-task hard mode, and
  multi-task mode.
- The recovery rule lives in exactly one executable place, so base, hard, and multi-task cannot
  drift apart — the same discipline `skill_gate_completion_claim` and
  `orchestrate-triage-classify.sh` already enforce for their rules.
- Recovery is fail-closed: a stale, missing, unparseable, `in_progress`, or non-success
  `.return-meta.json` preserves today's error path exactly, including the infra-failure
  discrimination and the phase-marker recovery grep.
- The "orchestrator_mode was not propagated correctly, or the handoff was written outside the task
  directory" diagnostic fires only when it is actually plausible — i.e. when recovery also failed.
- The multi-task path stops marking genuinely successful tasks into `failed_tasks`.

**Non-Goals**:

- Making any agent or skill start writing `.orchestrator-handoff.json` (candidate (b), rejected).
- Amending the Stage 3.6 prohibition in the research agents or the `wrap-up.md` consumer allowlist.
- Touching `skill-orchestrate-hard`'s H4, H5, or Stage 6 sub-dispatches.
- Changing the handoff-present path, the staleness gate, the stray-handoff sweep, or the
  infra-failure discrimination rule itself.
- Deploying or regenerating `.claude/` — the source store is edited; sync is a separate manual step.
- Wiring `skill_write_orchestrator_handoff` (still zero callers; left as-is).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Recovery masks a broken agent that wrote a stale/incorrect `.return-meta.json` | H | M | Apply the identical mtime-vs-`dispatch_start_ts` window check the handoff staleness gate already uses, with the same fail-closed `9999999999` default; only `researched`/`planned`/`implemented` are recoverable |
| An interrupted agent leaves `status: "in_progress"` early metadata and is read as success | H | M | `in_progress` is explicitly non-recoverable; it maps to `reason=STATUS_IN_PROGRESS` and falls through to today's error path, which is exactly the delegation-interrupted case |
| A recovered `implemented` claim flips a task to `completed` without phase evidence | H | L | Route through the existing `skill_gate_completion_claim` with `plan_markers_verified="absent"` — its Case 3 refuses unless the marker is `true`, so an absent marker conservatively refuses. No new gate logic |
| Three call sites drift apart again | M | M | All recovery logic lives in one script with a forbidden-calls header; call sites only parse its JSON and branch |
| Widening Stage 5 reads violates the Context Flatness Constraint | M | L | `.return-meta.json` is already stat'd in this exact branch; only `.status`, `.artifacts[0]`, and two integers are extracted. The constraint text is amended explicitly rather than silently stretched |
| Editing two regions of the same `SKILL.md` in parallel causes a lost edit | M | M | Phases 2 and 4 both touch `skill-orchestrate/SKILL.md` and are sequenced into different waves; only Phases 2 and 3 (different files) run in parallel |
| New script is not deployed because the manifest was not updated | M | M | Manifest registration is part of Phase 1, not a follow-up, and is verified in Phase 6 |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 2, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 2 and 4 both edit
`skills/skill-orchestrate/SKILL.md` and are deliberately placed in different waves.

---

### Phase 1: Shared outcome-recovery helper script [COMPLETED]

**Goal**: One executable, read-only source of truth that turns a task's `.return-meta.json` plus a
dispatch window into the same outcome fields Stage 5 reads from a handoff.

**Tasks**:

- [x] Create `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- [x] Write a header contract modeled on `orchestrate-triage-classify.sh`'s: purpose, why it exists
      (three call sites that must not diverge), and an explicit **Forbidden calls** list — this
      script must never call `task-lock.sh`, `update-task-status.sh`, `generate-todo.sh`, any
      `skill-base.sh` write function, `reconcile-task-status.sh` without `--dry-run`, or the Agent
      or Skill tool
- [x] State in the header that it reads ONLY `<task_dir>/.return-meta.json` — never a report, plan,
      summary, or handoff (Context Flatness Constraint)
- [x] Implement the usage contract: `orchestrate-recover-outcome.sh <task_dir> <window_start_ts>`
- [x] Emit a single-line JSON object on stdout with these fields:
      `recovered` (bool), `status` (string, `"unknown"` when unreadable), `reason` (token),
      `artifact_path`, `artifact_type`, `artifact_summary`, `phases_completed` (int),
      `phases_total` (int), `meta_mtime` (int), `window_start` (int)
- [x] Implement the staleness check with the same idiom and the same fail-closed default already
      used in Stage 5: `stat -c %Y ... || stat -f %m ... || echo 0`, compared against
      `${window_start:-9999999999}`; `meta_mtime -ge window_start` is fresh
- [x] Set `recovered=true` only for `status` in `researched|planned|implemented` on a present,
      fresh, parseable file. Every other case sets `recovered=false` with one of the reason tokens
      `META_MISSING`, `META_STALE`, `META_UNPARSEABLE`, `STATUS_IN_PROGRESS`, `STATUS_NOT_SUCCESS`,
      `USAGE`
- [x] Always populate `status` from the file when it is parseable, even when `recovered=false`, so
      callers can log a `partial`/`failed`/`blocked`/`in_progress` outcome without acting on it
- [x] Read phase accounting as `.metadata.phases_completed // .partial_progress.phases_completed // 0`
      and likewise for `phases_total`; read artifact fields from `.artifacts[0]` with `// ""` defaults
- [x] Exit 0 when `recovered=true`, 1 when `recovered=false`, 2 on usage or missing-`jq` errors —
      and document that callers MUST treat exit 2 identically to exit 1 (fail closed)
- [x] `chmod +x` the script
- [x] Add `orchestrate-recover-outcome.sh` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, preserving the array's existing alphabetical
      ordering

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` - new shared helper
- `agent-system/extensions/core/manifest.json` - register the new script for deployment

**Verification**:

- `bash -n` parses the script clean; `shellcheck` (if available) reports no errors
- Against a fixture dir with a fresh `researched` `.return-meta.json`: exit 0, `recovered=true`,
  `status=researched`, `artifact_path` populated
- Against the same fixture with `window_start` set past the file mtime: exit 1, `reason=META_STALE`
- Against a missing file: exit 1, `reason=META_MISSING`
- Against `status: "in_progress"`: exit 1, `reason=STATUS_IN_PROGRESS`
- Against malformed JSON: exit 1, `reason=META_UNPARSEABLE` (no unhandled `jq` crash)
- `jq -e '.provides.scripts | index("orchestrate-recover-outcome.sh")' manifest.json` succeeds

---

### Phase 2: Base-mode Stage 5 recovery branch [COMPLETED]

**Goal**: `skill-orchestrate` Stage 5 consults the recovery helper before declaring a missing
handoff a defect, and drives the existing postflight `case` and artifact-linking code from the
recovered values.

**Tasks**:

- [x] In `skills/skill-orchestrate/SKILL.md` Stage 5, immediately inside the
      `if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then` branch and *before* any
      existing diagnostic `echo`, call the helper with `"$TASK_DIR"` and
      `"${dispatch_start_ts:-9999999999}"`, capturing its stdout and exit status
- [x] On `recovered=true`: log a neutral, non-error note naming the recovered status and the fact
      that no handoff is expected from this dispatch's writer; set `dispatch_status`,
      `phases_completed`, `phases_total`, and the three `handoff_artifact_*` variables from the
      recovered JSON; set `plan_markers_verified="absent"`
- [x] On `recovered=true`, run the SAME postflight `case "$dispatch_status"` block and the SAME
      `skill_link_artifacts` field-mapping block the handoff-present branch uses — do not write a
      second copy. Restructure so both branches share one block (extract the shared tail out of the
      `else` branch, or set a `have_outcome` flag both branches feed into); a duplicated `case` is
      the drift this task exists to prevent
- [x] On `recovered=true`, skip the infra-failure discrimination block and the phase-marker recovery
      grep entirely — a recovered success is by definition neither an infra failure nor an unusable
      outcome
- [x] On `recovered=true`, charge exactly one work cycle (leave `infra_exempt_cycle=false`) so the
      cycle accounting matches the handoff-present success path; add a comment recording that this
      is deliberate and why
- [x] On `recovered=false` (including exit 2): leave today's behavior byte-identical — the existing
      "Skill did not write orchestrator handoff" / "orchestrator_mode was not propagated correctly"
      diagnostics, the infra-failure discrimination block, the phase-marker grep, and the cycle
      charge all run exactly as they do now
- [x] When `recovered=false` but the helper reported a parseable non-success `status`, add one extra
      log line naming it (e.g. `.return-meta.json reports status=partial`) so the operator sees why
      recovery declined
- [x] Soften the `RECOVERY: no plan file available` message so it does not read as a surprise when
      no `plans/` directory exists yet (the normal case after a research dispatch), while keeping it
      loud when a plan directory exists but yields no readable plan
- [x] Leave the staleness gate and the stray-handoff sweep untouched

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5 only

**Verification**:

- The Stage 5 bash block still parses: extract the fenced block and run `bash -n` on it
- Exactly one `case "$dispatch_status"` postflight block exists in Stage 5 (`grep -c`)
- The `orchestrator_mode was not propagated correctly` string is reachable only on the
  `recovered=false` path (read the branch structure to confirm)
- The H4/H5/Stage 6 dispatch sites are not in this file and remain untouched
- `git diff` for this phase touches only Stage 5

---

### Phase 3: Hard-mode Stage 5 recovery branch [COMPLETED]

**Goal**: `skill-orchestrate-hard` Stage 5 gets the identical recovery branch, preserving every
hard-mode-specific difference around it.

**Tasks**:

- [x] Apply the Phase 2 change to `skills/skill-orchestrate-hard/SKILL.md` Stage 5, with the
      `[hard-orchestrate]` log prefix throughout
- [x] Preserve the hard-mode-only reads and logs on the handoff-present path unchanged: `skeleton`,
      `sorry_inventory`, the follow-up-task log line, and the hard-mode comment block on the
      `implemented` gate
- [x] On a recovered outcome, set `skeleton=false` and `sorry_inventory=[]` explicitly, and note in
      a comment that `.return-meta.json` carries no hard-mode wrap-up fields — so hard-mode logging
      degrades visibly rather than reading uninitialized values from a previous cycle
- [x] Keep the hard-mode `else` arm of the `implemented` gate (the `skeleton=... at refusal` log)
      working for both the handoff-present and recovered paths
- [x] Do NOT touch the H4 adversarial-verification re-dispatch, the H5 divergence audit, or the
      Stage 6 blocker-research dispatch — they already pass `orchestrator_mode: false`, omit the
      anchor, and skip this stage. Confirm all three still do after the edit
- [x] Preserve the `<!-- BEGIN 772 Item 5B ... -->` / `<!-- END ... -->` comment markers around the
      stage

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 5 only

**Verification**:

- The Stage 5 bash block parses under `bash -n`
- `grep -c 'orchestrator_mode: false'` over the H4/H5/Stage 6 sites is unchanged from before the
  edit, and none of those three sections appear in this phase's `git diff`
- Recovery-branch log lines all carry the `[hard-orchestrate]` prefix
- The BEGIN/END comment markers are still present and still wrap the whole stage

---

### Phase 4: Multi-task Stage MT-4 recovery [NOT STARTED]

**Goal**: Stage MT-4 step 1 stops marking successful tasks into `failed_tasks` on a missing handoff.

**Tasks**:

- [ ] In `skills/skill-orchestrate/SKILL.md` Stage MT-4 step 1, call the helper for this task
      before the existing infra-discrimination `if`, using `"$task_dir"` and the per-task window
      already read as `window_start` from `.dispatch_start_ts[$t]` in `mt_state_file`
- [ ] On `recovered=true`: log a per-task neutral note, populate this task's `dispatch_status`,
      artifact path/type/summary, `phases_completed`, `phases_total`, and `plan_markers_verified="absent"`
      from the recovered JSON, and **continue into steps 2-6 unchanged** — the task must NOT be added
      to `failed_tasks` and must NOT be infra-deferred
- [ ] Make explicit in the surrounding prose that step 2's "Extract ... from *this* task's own
      handoff" now reads "from this task's own handoff, or from its recovered `.return-meta.json`
      outcome when the handoff was absent", and that these values are still re-read per task and
      never carried over between tasks in a wave
- [ ] On `recovered=false` (including exit 2): the existing infra-vs-`failed_tasks` logic runs
      exactly as it does now, unchanged
- [ ] Update the inline comment that reads "This branch is the worse of the two manifestations of
      the defect ... it has historically had no retry at all" to describe the post-fix behavior
      accurately, without citing a task number
- [ ] Confirm the recovered path still reaches step 6's unconditional per-task
      `task-lock.sh release`

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-4 step 1 and the step-2
  prose only

**Verification**:

- The MT-4 step 1 bash block parses under `bash -n`
- The recovered path provably reaches steps 2-6 (read the branch structure; every non-recovered
  arm still says "skip steps 2-5" and every arm still reaches step 6)
- Stage 5 (Phase 2's territory) is untouched by this phase's `git diff`
- No task-number citations were introduced into this file

---

### Phase 5: Constraint and documentation updates [NOT STARTED]

**Goal**: The written contracts match the new behavior, so the next reader does not re-derive the
old "handoff is the only outcome channel" assumption.

**Tasks**:

- [ ] In `skills/skill-orchestrate/SKILL.md`, amend the "MUST NOT (Context Flatness Constraint)"
      section: the sentence "The ONLY file read after each dispatch is `.orchestrator-handoff.json`"
      must now name `.return-meta.json` as a second, bounded read
- [ ] Add a "Recovery exception (return-meta fallback)" paragraph alongside the existing
      "Recovery exception (phase-marker grep)", with the same four binding bounds: fields-only (no
      report prose), missing/stale-handoff-branch-only precondition, a stated token ceiling, and the
      fact that it DOES drive a status transition (unlike the grep, which is diagnostic-only) — call
      that difference out explicitly, since it is the one place the two exceptions diverge
- [ ] Mirror the same constraint amendment into `skills/skill-orchestrate-hard/SKILL.md` if that
      file carries its own copy of the constraint section; if it defers to the base file, leave it
- [ ] In `docs/architecture/handoff-schema.md`, add an "Outcome Channels" section stating that
      `.orchestrator-handoff.json` is the primary channel and `.return-meta.json` is the fallback
      consulted by Stage 5 and Stage MT-4, and naming `orchestrate-recover-outcome.sh` as the single
      implementation
- [ ] In the same file, rewrite the Handoff Writers table's "Not implemented" row so it no longer
      reads as an unaddressed gap: these dispatches are an expected, return-meta-recoverable case,
      not a fault
- [ ] In `context/patterns/infra-failure-discrimination.md`, record the new ordering: outcome
      recovery is attempted first, and the two-signal infra discrimination applies only when recovery
      declined. Note that this narrows when the discrimination fires without changing its rule
- [ ] Verify no task-number citations were introduced in any file outside `specs/**`

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - constraint section
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - constraint section, if present
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Outcome Channels + Writers table
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` - ordering note

**Verification**:

- The amended constraint text names both files that may be read after a dispatch
- `grep -rniE '\btasks? [0-9]{2,4}\b' agent-system/extensions/core/` shows no new hits introduced by
  this task's diff
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 (or fails only on
  pre-existing issues, recorded as such)

---

### Phase 6: End-to-end verification against the live reproduction [NOT STARTED]

**Goal**: Prove the exact failure observed during this task's own research dispatch now resolves
automatically.

**Tasks**:

- [ ] Build a fixture task directory containing only a `.return-meta.json` with
      `status: "researched"` and a well-formed `artifacts[0]` entry — no handoff — matching the
      shape this task's own research dispatch produced
- [ ] Run `orchestrate-recover-outcome.sh` against it with a window start below the file mtime and
      confirm `recovered=true`, `status=researched`, and a populated `artifact_path`
- [ ] Trace the Phase 2 Stage 5 branch by hand against that JSON and record which
      `skill_postflight_update` call it reaches and with what arguments — it must be
      `skill_postflight_update <n> research <session> researched`
- [ ] Repeat the trace for the Phase 3 hard-mode branch and the Phase 4 MT-4 branch
- [ ] Confirm the negative cases still take the old path: missing meta, stale meta, `in_progress`
      meta, and `failed` meta each still reach the error diagnostics and the infra-discrimination
      block
- [ ] Confirm no file under `.claude/` was modified by any phase
      (`git status --porcelain .claude/` and a check that `.claude/` is gitignored)
- [ ] Record in the summary that `.claude/` must be re-synced from the source store for the fix to
      take effect at runtime, and that this plan deliberately does not perform that sync

**Timing**: 0.75 hours

**Depends on**: 5

**Files to modify**:

- None (verification only; fixtures live in a scratch directory and are not committed)

**Verification**:

- All six fixture cases behave as specified above
- `git status --porcelain .claude/` is empty
- Every touched path is under `agent-system/extensions/core/**` or this task's `specs/` directory

---

## Testing & Validation

- [ ] `bash -n` passes on `orchestrate-recover-outcome.sh` and on every edited fenced bash block in
      both orchestrate SKILL.md files
- [ ] The helper returns the correct `recovered`/`reason` pair for all six fixture cases: fresh
      success, stale, missing, `in_progress`, non-success status, malformed JSON
- [ ] A recovered `researched` outcome reaches `skill_postflight_update ... research ... researched`
      in base mode, hard mode, and multi-task mode
- [ ] A recovered `implemented` outcome reaches `skill_gate_completion_claim` with
      `plan_markers_verified="absent"` and is refused when phase accounting is also absent
- [ ] The handoff-present path is unchanged in all three call sites
- [ ] `skill-orchestrate-hard`'s H4, H5, and Stage 6 dispatch sites are byte-identical to their
      pre-change state
- [ ] No new task-number citations outside `specs/**`
- [ ] No modifications under `.claude/**`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (new)
- `agent-system/extensions/core/manifest.json` (script registration)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 5, Stage MT-4, constraint)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 5, constraint)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (Outcome Channels, Writers table)
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` (ordering note)
- `specs/913_fix_stage5_missing_handoff_after_research_dispatch/summaries/01_stage5-return-meta-fallback-summary.md`

## Rollback/Contingency

Every change is additive and confined to `agent-system/extensions/core/**`. Reverting the commits
for Phases 1-5 restores the prior behavior exactly, since the recovery branch is entered only where
the code previously fell straight through to the error path.

If the recovery branch misbehaves in production before a full revert is practical, the fastest
neutralizing change is a single edit at each call site forcing the helper's result to
`recovered=false` — every downstream path then takes today's behavior unchanged, which is the
fail-closed default the helper is already designed around.

If the shared-helper approach proves unworkable during Phase 1 (for example, if a call site cannot
invoke a script at that point in its flow), the fallback is an inline `jq` read of
`.return-meta.json` at each of the three sites — functionally equivalent but with the three-way
drift risk this plan is structured to avoid. Take that fallback only with the drift risk recorded
explicitly in the summary.
