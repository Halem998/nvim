# Research Report: Task #893

**Task**: 893 - Close stranded-status detection gap for not_started tasks with existing artifacts
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: Small (single-file patch, ~60-90 new lines in one script)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (SOURCE STORE — all line
  numbers below are re-derived against this file, current as of this research pass)
- `agent-system/extensions/core/scripts/update-task-status.sh`
- `agent-system/extensions/core/context/standards/status-markers.md`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/context/patterns/context-exhaustion-detection.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/commands/task.md`
- `agent-system/extensions/core/scripts/claude-cleanup.sh` (mtime-check convention reference)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed**: `reconcile-task-status.sh`'s `case "$current_status" in` dispatch
  (currently spanning lines 250-390) has explicit branches for `researching`, `planning`,
  `implementing`, and `partial`, but `not_started` falls into the catch-all default (the `*)`
  arm, comment at line 386, `exit 0` at line 388) alongside genuinely-terminal statuses. A
  `not_started` task with a completed plan and committed phases is indistinguishable, to this
  script, from a brand-new task — both no-op.
- **The plans/\*.md signal alone would have caught the observed case.** The task's own framing
  is correct: a plan existed, so a `not_started` + plan-file-exists check is sufficient to
  detect the reported defect. The `handoffs/`-or-phase-commits signal (case (b)) is a genuine
  but much rarer defense-in-depth addition — see recommendation below on git-log detection
  (not worth it).
- **A real, concrete false-positive source exists and must be guarded against**: `/task
  --recover` (`commands/task.md` lines 318-324) moves an archived task's *entire* directory —
  including its old `plans/`, `reports/`, `summaries/`, and `handoffs/` — back into
  `specs/{PADDED}_{slug}/` and explicitly resets `status` to `"not_started"` (line 307:
  `.status = "not_started"`), while also stamping `last_updated` to the recovery timestamp
  (same jq call). Every recovered task therefore looks, to a naive "not_started + artifact
  exists" check, exactly like a stranded task — but the human's intent in recovering it is to
  reopen the task at `not_started` (often to redo research or planning), not to have it
  silently fast-forwarded back to `planned`/`partial`. **Recommendation**: gate promotion on
  artifact mtime being *newer* than the task's `last_updated` timestamp in state.json, not on
  artifact presence alone. This single, cheap, filesystem-plus-jq check resolves the
  false-positive risk without inventing new state-vocabulary or touching `/task --recover`.
- **Recommend implementing case (a) (plan-file check) with the mtime guard, and case (b)
  (handoffs/ non-empty, same mtime guard) as defense-in-depth — but recommend AGAINST the
  git-log "phase commits exist" signal.** A phase commit cannot exist without a prior plan
  file (implementation only proceeds against a plan's phase headings, and plan files are never
  deleted — later `/revise` versions are added, not swapped in place), so the plans/\*.md check
  already covers every realistic case a git-log query would additionally catch. The git query
  also costs more (spawns `git log`, requires history depth, is fragile to the commit-message
  convention drifting) for effectively zero incremental coverage.
- `handoff_permits_promotion` (lines 163-172) and `handoff_status_value` (lines 175-180) are
  the correct, already-designed-for-this generalization point (header comment lines 158-162
  explicitly says so) and compose cleanly with the new `not_started` branches using the same
  pattern the `researching`/`planning`/`implementing` branches already use.

## Context & Scope

Task 893 is one of six agent-system defects observed during a single full `/orchestrate` run
(lean4 task, 8 implementation phases, 5 cycles). The specific defect: a task remained at
`status="not_started"` in `specs/state.json` despite an implementation plan already existing on
disk and three phases already committed to git. `skill-orchestrate`'s entry reconcile step
(`skill-orchestrate/SKILL.md` lines 164-183) ran `reconcile-task-status.sh` live (no
`--dry-run`, no human present — `/orchestrate`'s design has no confirmation gate) and reported
"no stranded status found," because the script's dispatch has no branch for `not_started` at
all.

This research characterizes the exact code paths to change, re-derives every line anchor
against the current source-store copy of the script, and works out the disambiguation logic
needed so that the fix does not introduce a new failure mode (silently skipping needed
research/planning on a task the user deliberately reset).

**SOURCE-STORE RULE**: all recommended edits below target
`agent-system/extensions/core/scripts/reconcile-task-status.sh`. The deployed copy at
`.claude/scripts/reconcile-task-status.sh` is a gitignored, disposable build artifact and must
never be edited directly.

## Findings

### Codebase Patterns

#### The dispatch gap (verified line anchors, source store, current as read)

```
250  case "$current_status" in
252    researching)      ... reports/*.md -> handoff_permits_promotion("researched") -> postflight research
285    planning)         ... plans/*.md   -> handoff_permits_promotion("planned")    -> postflight plan
317    implementing)      ... summaries/*.md -> handoff_permits_promotion("implemented") -> postflight implement
349    partial)           ... summaries/*.md -> inline handoff-status=="implemented" check -> postflight implement
385    *)
386      # All other statuses (not_started, researched, planned, completed, blocked, abandoned, expanded)
387      # are either terminal or already at a stable state — no-op
388      exit 0
389      ;;
390  esac
```

`not_started` is lumped into the same catch-all as five genuinely-terminal/stable statuses
(`researched`, `planned`, `completed`, `blocked`, `abandoned`, `expanded`), even though — unlike
those — a `not_started` task with artifacts present is not stable at all; it is either a crashed
run (needs promotion) or a deliberate reset (correctly at rest). The catch-all cannot
distinguish the two because it does no artifact inspection whatsoever for this status.

The module header (lines 17-21) already documents exactly the artifact-to-phase mapping the fix
needs to extend:
```
17  # Artifact-to-phase mapping:
18  #   reports/*.md    -> research phase   (researching -> researched)
19  #   plans/*.md      -> planning phase   (planning -> planned)
20  #   summaries/*.md  -> implement phase  (implementing -> completed)
21  #   partial state   -> check handoff for continuation_context
```
This is the same signal set the task description points at — `plans/*.md` is already understood
by the script as the "planning is done" signal; it simply never gets checked when the
*originating* status is `not_started` instead of `planning`.

#### `handoff_permits_promotion` and `handoff_status_value` — precise characterization

```bash
158  # --- Helper: does a handoff permit promotion to this phase's success status? ---
159  # Generalizes the contract the `partial` branch below already implements: if the handoff file is
160  # absent, permit promotion (preserves pre-existing behavior for tasks with no handoff); if
161  # present and its `.status` matches the expected success value for this phase, permit; otherwise
162  # refuse. Returns 0 (permit) or 1 (refuse) via exit status.
163  handoff_permits_promotion() {
164    local expected_status="$1"
165    local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
166    if [[ ! -f "$handoff_file" ]]; then
167      return 0
168    fi
169    local handoff_status
170    handoff_status=$(jq -r '.status // ""' "$handoff_file" 2>/dev/null)
171    [[ "$handoff_status" == "$expected_status" ]]
172  }
```
- **Signature**: `handoff_permits_promotion(expected_status)` → exit status 0 (permit) / 1
  (refuse). No output.
- **Gates on**: `${TASK_DIR}/.orchestrator-handoff.json`'s `.status` field (JSON, task-root
  level — distinct from the per-phase `handoffs/phase-{P}-handoff-{TS}.md` markdown files used
  as case (b)'s evidence signal). If the file is absent, it **permits** (returns 0) — this is
  the load-bearing default the header calls out, and it is what keeps the existing three
  branches a no-op change for tasks that never ran under `--hard` mode.
- **Important scope note discovered in this research**: `.orchestrator-handoff.json` at the task
  root is written **only by hard-mode dispatch paths** (`wrap-up.md` line 8: "This entire
  contract is loaded exclusively by hard-mode dispatch paths ...; STANDARD mode never loads this
  file"). `general-implementation-agent.md` (standard mode) never writes this file — it uses
  `.return-meta.json`'s `partial_progress.handoff_path` instead (a different, unrelated
  mechanism; see `context-exhaustion-detection.md` line 133 for that schema). So in standard
  mode `handoff_permits_promotion` is essentially always a pass-through (file absent → permit);
  it becomes a real gate only for `--hard` dispatches. This is existing, correct behavior — just
  worth stating plainly since the task description's "reuse `handoff_permits_promotion`"
  directive should not be read as "this alone disambiguates recovered vs. stranded tasks" (it
  does not — see False-Positive Risk below).

```bash
174  # --- Helper: read the handoff's status field (empty string if no handoff file) ---
175  handoff_status_value() {
176    local handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
177    if [[ -f "$handoff_file" ]]; then
178      jq -r '.status // ""' "$handoff_file" 2>/dev/null
179    fi
180  }
181  ```
- **Signature**: `handoff_status_value()` → echoes the handoff's `.status` string, or empty
  string (no output at all, not even a blank line, when the file is absent — note this is used
  only inside `echo "... handoff status=$handoff_status ..."` diagnostics and inside
  `record_refused_promotion`, both of which tolerate an empty value).
- Used purely for diagnostics/refusal-routing (`record_refused_promotion`, lines ~186-200 in the
  current file — see below), never for the permit decision itself (that is
  `handoff_permits_promotion`'s job).

`record_refused_promotion(handoff_status)` (helper immediately following, roughly lines
186-200) maps `blocked|partial` handoff statuses onto the corresponding sanctioned postflight
termini via `update-task-status.sh postflight ... blocked|partial`, and treats every other value
(including empty/`"failed"`) as an intentional no-op ("ambiguous mapping — no recording"). Both
new `not_started` branches below should call this exact same helper on refusal, for the same
reason the existing three branches do: consistent, already-reviewed refusal semantics.

### The concrete false-positive risk (not called out in the task description, discovered during this research)

`commands/task.md`'s Recover Mode (`--recover`, lines 249-336) is the single existing workflow
that puts a task into `not_started` *while artifacts already exist on disk* — and it does so
deliberately, not as a bug:

```bash
297  **Move to active_projects via jq** ...
306    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson task "$task_data" \
307      '.active_projects = [$task | .status = "not_started" | .last_updated = $ts] + .active_projects' \
308      specs/state.json > specs/tmp/state.json && ...
...
318  **Move project directory from archive** (handle both legacy unpadded and new padded formats):
319  ```bash
320  PADDED_NUM=$(printf "%03d" "$task_number")
321  if [ -d "specs/archive/${task_number}_${slug}" ]; then
322    mv "specs/archive/${task_number}_${slug}" "specs/${PADDED_NUM}_${slug}"
```

`/task --recover N` moves the *entire* archived task directory back — `plans/`, `reports/`,
`summaries/`, `handoffs/`, everything — and explicitly forces `status = "not_started"`, stamping
`last_updated` to the recovery time in the same jq call. A recovered task that had gotten as far
as planning (or further) before being archived is now `not_started` with a fully populated
`plans/` directory (and possibly `handoffs/`, `summaries/`) — structurally identical, to a naive
"not_started + plan exists" check, to the genuinely-stranded case this task is trying to fix.
Silently auto-promoting a recovered task back to `planned`/`partial` the next time
`/orchestrate`'s unattended entry reconcile runs would defeat the purpose of recovering it (the
human typically wants to redo or continue work, not have the tracker claim it's already further
along) — this is exactly the "over-eager promotion silently skips research or planning the task
actually needs" failure mode the task description warns about, made concrete.

**Distinguishing signal**: artifact mtime vs. `state.json`'s `last_updated` for the task.
- **Genuinely stranded**: the plan (or handoff) file was written *during the crashed run*,
  which is necessarily *after* the last successful status write for that task (which, in the
  observed defect, never advanced past task-creation time because every subsequent
  preflight/postflight write was lost). So `artifact_mtime > last_updated`.
- **Freshly recovered**: `/task --recover`'s jq call stamps `last_updated` to *now*, which is
  necessarily *after* every artifact in the directory (all of which predate archival). So
  `last_updated > artifact_mtime` (or, at worst, ties at the same second on a directory move —
  covered by using a non-strict rejection: require `>`, not `>=`, so ties refuse, not permit).

This is the same "recency" signal in spirit as the mtime checks already used elsewhere in the
codebase (`scripts/claude-cleanup.sh` lines 149, 226, 243, 348 use the GNU/BSD-portable pattern
`stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo <fallback>`), so the
recommended patch should reuse that exact fallback idiom rather than assuming GNU-only `stat`.

**Why this doesn't need to touch `/task --recover` itself**: the reconcile script has no way to
know a task was "just recovered" versus "genuinely stranded" from status alone — both look like
`not_started`. The mtime comparison is a self-contained, local disambiguator that requires no
new state, no new file, and no change to the recover flow.

### Edit sites (re-derived against source store, current)

All in `agent-system/extensions/core/scripts/reconcile-task-status.sh`:

1. **New helper**, inserted after `handoff_status_value` (after line 180, before
   `record_refused_promotion`'s comment block) — compares an artifact's mtime against the
   task's `last_updated` field from `$task_data` (already read into scope at line 79/80):
   ```bash
   artifact_newer_than_last_update() {
     local artifact_path="$1"
     local artifact_mtime last_updated_epoch
     artifact_mtime=$(stat -c %Y "$artifact_path" 2>/dev/null || stat -f %m "$artifact_path" 2>/dev/null) || return 1
     last_updated_epoch=$(date -u -d "$(echo "$task_data" | jq -r '.last_updated // empty')" +%s 2>/dev/null) || return 0
     [[ "$artifact_mtime" -gt "$last_updated_epoch" ]]
   }
   ```
   (Falls open — returns 0/"newer" — only when `last_updated` is missing/unparseable, matching
   the existing "signal absent → permit" philosophy already used by `handoff_permits_promotion`;
   falls closed — `return 1` — when the artifact itself can't be stat'd, which should not
   happen since the caller only invokes this after `find_latest_artifact` already found the
   file.)

2. **New `not_started)` case**, inserted immediately before the `*)` catch-all currently at
   line 385, restructuring the trailing comment to no longer claim `not_started` is
   unconditionally a no-op:
   ```bash
   not_started)
     # Case (a): plan exists and postdates the last recorded status write -> promote to planned.
     plan_file=$(find_latest_artifact "plans")
     if [[ -n "$plan_file" ]] && artifact_newer_than_last_update "$plan_file"; then
       if ! handoff_permits_promotion "planned"; then
         handoff_status=$(handoff_status_value)
         echo "[reconcile] Task $task_number: status=not_started, plan exists but handoff status=$handoff_status — refusing promotion"
         record_refused_promotion "$handoff_status"
         exit 0
       fi
       plan_basename=$(basename "$plan_file")
       if [[ "$DRY_RUN" == "true" ]]; then
         echo "[reconcile] Task $task_number: status=not_started, found plan $plan_basename"
         echo "[reconcile] Would promote: not_started -> planned via postflight plan"
         link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
       else
         echo "[reconcile] Task $task_number: status=not_started but plan exists ($plan_basename) — replaying postflight"
         link_artifact "$plan_file" "plan" "Implementation plan: $plan_basename"
         "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "plan" "$session_id"
         echo "[reconcile] Task $task_number: promoted not_started -> planned"
       fi
       exit 0
     fi

     # Case (b): no (fresh) plan, but a non-empty handoffs/ dir postdates the last status write
     # -> promote to partial (never "implementing" -- no agent is actively working right now).
     handoff_dir="${TASK_DIR}/handoffs"
     if [[ -d "$handoff_dir" ]]; then
       latest_handoff=$(ls -1t "$handoff_dir"/*.md 2>/dev/null | head -1 || true)
       if [[ -n "$latest_handoff" ]] && artifact_newer_than_last_update "$latest_handoff"; then
         if ! handoff_permits_promotion "partial"; then
           handoff_status=$(handoff_status_value)
           echo "[reconcile] Task $task_number: status=not_started, handoffs/ non-empty but handoff status=$handoff_status — refusing promotion"
           record_refused_promotion "$handoff_status"
           exit 0
         fi
         if [[ "$DRY_RUN" == "true" ]]; then
           echo "[reconcile] Task $task_number: status=not_started, found non-empty handoffs/"
           echo "[reconcile] Would promote: not_started -> partial via postflight partial"
         else
           echo "[reconcile] Task $task_number: status=not_started but handoffs/ is non-empty — replaying postflight"
           "$SCRIPT_DIR/update-task-status.sh" postflight "$task_number" "partial" "$session_id"
           echo "[reconcile] Task $task_number: promoted not_started -> partial"
         fi
         exit 0
       fi
     fi

     # No fresh artifacts -- genuinely new (or deliberately reset, e.g. /task --recover) task.
     if [[ "$DRY_RUN" == "true" ]]; then
       echo "[reconcile] Task $task_number: status=not_started, no fresh artifacts found — no-op"
     fi
     ;;
   ```

3. **Catch-all comment update** at the current lines 385-389: drop `not_started` from the
   enumerated list now that it has its own case, e.g. `# All other statuses (researched,
   planned, completed, blocked, abandoned, expanded) ...`.

4. **Module header update** at lines 17-22: add a fifth bullet documenting the new mapping,
   e.g. `not_started + plans/*.md (newer than last_updated) -> planning phase (not_started ->
   planned)` and `not_started + handoffs/ (newer than last_updated) -> partial`, and a short
   note on the recover-mode disambiguation rationale so a future reader does not "simplify" the
   mtime guard away.

No other files need edits — `update-task-status.sh` already supports both `postflight plan`
(→ `planned`) and `postflight partial` (→ `partial`) as valid `operation:target_status`
combinations (lines 153 and 161 respectively of that script), so no new target-status value or
new `map_status()` case is required there.

### Recommendations

1. **Implement case (a) as the primary fix.** It alone reproduces the fix for the observed
   defect (a plan existed) and is the cheapest, most robust signal (filesystem-only, no git
   dependency, plan files are append-only across `/revise` versions so there's no
   plan-file-disappears-while-implementation-continues scenario to worry about).
2. **Implement case (b) as defense-in-depth**, using the `handoffs/` directory (already written
   by both standard and hard-mode implementation agents per-phase — see
   `general-implementation-agent.md` lines 293-313) rather than a git query. Since a phase
   cannot be implemented without a prior plan, any real-world case case (b) would catch is
   already covered by case (a) unless the plan file itself has gone missing after
   implementation started (no code path in this repo does that), so case (b)'s incremental
   value is narrow — but it is cheap enough (one more `find_latest_artifact`-style filesystem
   check) that there's no reason to omit it.
3. **Do not implement the git-log "phase commits exist" signal.** It is strictly weaker
   coverage than case (a) (a phase commit requires a pre-existing plan file, so anything it
   would catch, case (a) already catches), it is more expensive (spawns `git log`, needs
   history depth, and depends on the `task {N} phase {P}: {name}` commit-message convention
   documented in `context/checkpoints/checkpoint-commit.md` line 65 remaining stable), and it
   adds a second, harder-to-reason-about signal to an already-unattended, unreviewed promotion
   path. Skip it.
4. **Gate both new branches on the artifact-mtime-vs-last_updated check**, not on artifact
   presence alone. This is required to avoid silently fast-forwarding recovered (`/task
   --recover`) tasks — a concrete, already-implemented workflow that produces the exact
   "not_started + artifacts already present" shape this task is trying to detect, but for which
   promotion would be the wrong outcome the vast majority of the time (recovery generally means
   "reopen for more work," not "treat as already further along").
5. **Promote case (b) to `partial`, not `implementing`.** `implementing` is the preflight
   ("work is actively underway right now") status per `status-markers.md` (line 89: "Non-terminal;
   ... Normally completes to `[COMPLETED]` or `[PARTIAL]`"); a reconcile pass finding cold
   evidence of a stalled run is not "work actively underway" — it is exactly the "implementation
   partially completed (can resume)" description `status-markers.md` gives for `[PARTIAL]`
   (line 109). `partial` is also what `record_refused_promotion` and the existing `partial`
   branch already treat as the correct resting state for this situation, so this keeps the
   status vocabulary internally consistent, and per the "Permissive Rule" (any command can run
   from any non-terminal status, `status-markers.md` line 283) `partial` still routes cleanly
   into `/implement` on the next dispatch — no functional loss versus `implementing`.
6. **No test file currently exists for `reconcile-task-status.sh`** (confirmed by search — only
   the script itself was found under that name in the source store). The implementation plan
   for this task should include a manual `--dry-run` verification pass against a synthetic
   `not_started` task directory with (i) a fresh plan, (ii) a stale/recovered-looking plan
   (older mtime than `last_updated`), and (iii) no artifacts at all, to confirm the three
   branches behave as designed before relying on it in a live, unattended `/orchestrate` run.

## Decisions

- Promote `not_started` + fresh `plans/*.md` → `planned` (case a), reusing the exact
  `link_artifact` + `update-task-status.sh postflight ... plan ...` sequence the `planning`
  branch already uses.
- Promote `not_started` + fresh non-empty `handoffs/` (and no fresher plan match) → `partial`
  (case b), via `update-task-status.sh postflight ... partial ...`, not `implementing`.
- Reject the git-log "phase commits exist" signal as not worth the added cost/complexity.
- Add a new `artifact_newer_than_last_update()` helper as the false-positive guard, applied to
  both new branches, to protect the `/task --recover` workflow from being misread as a stranded
  task.
- Reuse `handoff_permits_promotion` and `handoff_status_value` unchanged, calling them with
  `expected_status` values `"planned"` and `"partial"` respectively for the two new branches —
  no changes needed to either helper's signature or body.

## Risks & Mitigations

- **Risk**: the mtime guard could still misfire if a recovered task is touched again (e.g. a
  human manually edits the plan file after recovery, updating its mtime past `last_updated`,
  without an intervening status-changing command). **Mitigation**: this is a narrow, low-blast-
  radius edge case (the "wrong" outcome is promoting to `planned`, still a safe, resumable,
  non-terminal state — not `completed` — and `/plan` can simply be re-run since the "any command
  can run from any non-terminal status" rule applies); not worth adding further complexity for.
- **Risk**: `stat`'s GNU/BSD flag difference (`-c` vs `-f`) could make the mtime read silently
  fail on a non-Linux host. **Mitigation**: reuse the exact fallback idiom already established
  in `scripts/claude-cleanup.sh` (`stat -c ... || stat -f ... || <fallback>`), so behavior is
  consistent with the rest of the codebase's existing portability posture.
- **Risk**: this reconcile pass runs live/unattended (`/orchestrate` design, no `--dry-run`, no
  human present — `skill-orchestrate/SKILL.md` line 171-173 states this explicitly and notes
  "the handoff-aware promotion guard now bounds what an automatic promotion can do"). **Mitigation**:
  the new branches inherit the same `handoff_permits_promotion`/`record_refused_promotion`
  safety valve already trusted for the other three branches, plus the new mtime guard adds an
  additional, independent check specific to the new ambiguity `not_started` introduces (recover
  vs. stranded) that the other three branches never had to solve.

## Context Extension Recommendations

- **Topic**: reconcile-task-status.sh's artifact-to-phase mapping documentation
- **Gap**: the module header (lines 17-22) is the closest thing to a spec for this script's
  behavior but does not currently mention the `not_started` case or the mtime-based recover
  disambiguation; once the fix lands, the header should be the canonical place documenting why
  the mtime check exists (see Edit site 4 above) so a future maintainer doesn't remove it as
  apparently-redundant complexity.
- **Recommendation**: fold this into the same edit (item 4 above) rather than a separate context
  file — this is script-header documentation, not a broader pattern needing its own file under
  `context/patterns/`.

## Appendix

- Searches performed: `find` for `agent-system` and `reconcile-task-status.sh`/
  `update-task-status.sh`/`status-markers.md`/`deploy-root-guard.sh` locations; `grep` for
  `handoffs/`, git commit-message conventions (`task {N} phase {P}:`), `not_started` across
  `commands/`, `skills/`, `context/`; `grep` for `stat -c`/`date -d` usage conventions in
  `scripts/`; read of `wrap-up.md`, `context-exhaustion-detection.md`, `general-implementation-
  agent.md` (Stage 4D-iii and 4E handoff-writing sections) to confirm `.orchestrator-handoff.json`
  is hard-mode-only while `handoffs/*.md` phase-end files are written in both modes.
- Full text of `reconcile-task-status.sh` and `update-task-status.sh` read in full (393 and 414
  lines respectively) to re-derive every line anchor cited above against the current source
  store.
