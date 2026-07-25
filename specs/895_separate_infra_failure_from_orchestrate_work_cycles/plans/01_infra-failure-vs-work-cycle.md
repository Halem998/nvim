# Implementation Plan: Task #895

- **Task**: 895 - separate_infra_failure_from_orchestrate_work_cycles
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (file-overlap serialization only against any concurrent edit of the two SKILL.md files)
- **Research Inputs**: `specs/895_separate_infra_failure_from_orchestrate_work_cycles/reports/01_infra-failure-vs-work-cycle.md`
- **Artifacts**: plans/01_infra-failure-vs-work-cycle.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/orchestrate` currently treats *any* missing `.orchestrator-handoff.json` as a consumed work
cycle. When an Agent tool call dies at the transport/API layer before the subagent ever runs, that
outage burns one of `MAX_CYCLES`. This plan adds a corroborated two-signal discrimination rule that
distinguishes a genuine work cycle from an infrastructure failure, routes the latter to a separate
capped counter (`infra_failures`, `MAX_INFRA_FAILURES=3`) instead of `cycle_count`, and fixes the
same defect class at both of its manifestations — single-task Stage 5 and the strictly worse
multi-task Stage MT-4, which today marks a task `failed_tasks` outright with no retry at all.

The rule is defined once in a new shared pattern doc and referenced by both orchestrator variants,
mirroring how `lit-stage4a-flow.md` factors cross-variant logic into one file.

### Research Integration

Three research findings are load-bearing and are carried forward unchanged:

1. **There is no single mechanical signal.** Bash in Stage 5 runs strictly *after* the Agent tool
   call has returned, so it structurally cannot observe the tool-call-level outcome. The plan does
   not invent one. Instead it requires **two corroborating signals**: (a) a narrated orchestrator
   judgment about the Agent tool call's own outcome, and (b) a mechanical `.return-meta.json`
   mtime check against a dispatch window. Either signal alone **defaults to charging a genuine
   cycle** — this conservative default is the whole point, since a permissive rule turns
   `MAX_CYCLES` into no cap at all.
2. **`burnout_signals_this_session` is the shape to imitate** for declaration (Stage 2 `jq -n`
   blob), persistence (`.orchestrator-loop-guard`), and increment (read-modify-tmp-mv `jq`) — but
   it deliberately **diverges** on one point: burnout has no cap of its own because its increments
   convert into cycle-consuming dispatches. `infra_failures` increments deliberately do **not**
   consume cycle budget, so it MUST have an explicit cap.
3. **All line numbers in the original task description are stale.** The anchors in this plan were
   re-derived by research against the current source store, but a phase-completion gate landed
   recently in both Stage 5's `implemented)` arm and Stage MT-4. Every phase below therefore
   requires an anchor re-verification step before editing; anchors here are navigation aids, and
   the quoted `old_string` text is authoritative over the line number.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Define the two-signal infra-failure discrimination rule once, in a shared, referenced pattern doc.
- Add a `MAX_INFRA_FAILURES=3` capped `infra_failures` counter to both orchestrator variants, flat
  in both (not scaled with `MAX_CYCLES`).
- Fix single-task Stage 5 (`skill-orchestrate`, `skill-orchestrate-hard`) so a corroborated infra
  failure does not increment `cycle_count`.
- Fix multi-task Stage MT-4 so a corroborated infra failure does not mark the task `failed_tasks`.
- Make the exemption path provably bounded, with an explicit terminal condition and a distinct
  operator-facing message.
- Make every forgotten dispatch site fail toward **charging** (the safe direction).

**Non-Goals**:
- Stage 4b churn detection and its `total_churn` / `target_churn` counters (a different failure
  class — content churn, not transport failure). Not touched.
- Stage 6's blocker-research fork's own lack of a missing-handoff branch. Pre-existing and
  orthogonal; not touched.
- Any edit under `.claude/**`. That tree is a gitignored, disposable deploy artifact.
- Deploying the change (regenerating `.claude/` via the extension picker's Load Core) — user-driven,
  out of scope for the implementer.

## Binding Constraints

1. **SOURCE-STORE RULE**: the agent-system source of truth is
   `agent-system/extensions/core/`. Every edit in this plan targets
   `agent-system/extensions/core/**`. Editing `.claude/**` is a defect — that tree is regenerated
   from the source store and any edit there is silently discarded.
2. **No task-number citations** in any file outside `specs/**` (see
   `.claude/rules/no-task-references-in-deliverables.md`). Comments added to the SKILL.md files and
   the new pattern doc must cite durable anchors (section names, file names, the counter's own
   name) — never a task number. Note that pre-existing comments in these files *do* contain task
   numbers (e.g. "772 Item 5B", "task 808"); do not add new ones, and do not go on a cleanup
   crusade removing old ones — that is out of scope here.
3. **Anchors are stale-prone**: re-verify with `grep -n` before every edit. Trust the quoted
   `old_string`, not the line number.

## Design Summary (single source of truth for all phases)

### The two signals

| Signal | Kind | Where set | Value meaning |
|--------|------|-----------|---------------|
| `dispatch_was_transport_error` | narrated LLM judgment | immediately after each Agent tool call returns | `true` only if the tool call itself returned a transport/API-layer error with **no subagent-authored text at all** |
| `meta_touched` | mechanical bash | Stage 5 / MT-4 step 1 | `true` if `${TASK_DIR}/.return-meta.json` mtime `>= dispatch_start_ts` |

**Classification**: infra failure **iff** `dispatch_was_transport_error = true` **AND**
`meta_touched = false`. Every other combination preserves today's behavior exactly.

**Positive transport-error indicators** (set `true`): `ENOTFOUND`, `EAI_AGAIN`, `ECONNREFUSED`,
`ECONNRESET`, `ETIMEDOUT`, TLS/handshake failures, a harness-level exception for the tool
invocation itself, or an API-layer error object (`overloaded_error`, `api_error`, 5xx) — **with no
subagent-authored text**.

**Negative indicator** (set `false`, charge the cycle): any subagent-authored text exists, *even if
that text itself describes an error the subagent hit* ("I hit a network error while fetching X and
am reporting partial findings"). That is the subagent narrating its own experience — proof it ran.

### Why `meta_touched` is the right mechanical signal

Every agent following the early-metadata contract writes `specs/{NNN}_{SLUG}/.return-meta.json`
with `status: "in_progress"` **before any substantive work** (Stage 0). So an untouched
`.return-meta.json` is the strongest available evidence the subagent never reached its own first
tool call. Note `skill_preflight_update` is written by the *caller* before dispatch and therefore
proves nothing — it is not usable as a signal.

**Accepted residual false-negative**: a subagent that writes early metadata and *then* dies to a
transport failure is charged a genuine cycle. This is the deliberately conservative choice.

### The counter and its bound

- `MAX_INFRA_FAILURES=3`, flat and identical in both variants. Not scaled with `MAX_CYCLES` (5 vs
  13) — infra tolerance has no relationship to phase count. Matches this codebase's small-cap
  precedents (`MAX_BLOCKER_ESCALATIONS=2`, `MAX_DRIFT_INSPECTIONS=1`).
- `infra_failures` is declared in the Stage 2 loop-guard init blob, persisted in
  `.orchestrator-loop-guard`, read back in **all three** init paths (resume, fresh, lost-race), and
  incremented via read-modify-tmp-mv `jq` — exactly `burnout_signals_this_session`'s shape.

**Explicit bound (required by the plan requirements — an infra-exempt cycle must not enable an
infinite loop):** an infra-exempt iteration does not increment `cycle_count`, so the
`while [ "$cycle_count" -lt "$MAX_CYCLES" ]` condition alone does not advance. The bound comes from
the Stage 7 terminal check, which runs at the end of **every** cycle: once
`infra_failures >= MAX_INFRA_FAILURES` the run exits `partial`. Therefore the worst-case number of
loop iterations in a single invocation is exactly:

```
MAX_CYCLES + MAX_INFRA_FAILURES
  = 5 + 3 = 8   (skill-orchestrate)
  = 13 + 3 = 16 (skill-orchestrate-hard)
```

Every iteration either charges `cycle_count` or charges `infra_failures`; both are capped; no
iteration charges neither. This is the invariant the implementer must preserve.

**Explicit terminal condition on cap reached**: exit `partial` with a message *distinct* from the
`MAX_CYCLES` message so a log reader can immediately tell "infra flakiness" from "ran out of work
budget". Do **not** fall through to also incrementing `cycle_count` — the cap's entire purpose is to
stay outside the work-cycle budget. Recovery is a fresh `/orchestrate` invocation, not a consumed
cycle.

### Failing safe on omission

Every read of the two signals uses a bash defensive default chosen so a *forgotten* dispatch site
falls back to **charging**:

- `${dispatch_was_transport_error:-false}` — unset means "not infra".
- `${dispatch_start_ts:-9999999999}` — unset means the window start is in the far future, so
  `meta_mtime >= window_start` is false, so `meta_touched=false`... which is the *permissive*
  direction on its own. It is safe **only** because the `AND` with `dispatch_was_transport_error`
  (which defaults to `false`) gates it. Both defaults together yield "charge". The implementer must
  not weaken the `AND` into an `OR` or a fallthrough.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A dispatch site is missed, so its `dispatch_start_ts` is never set | M | M | Defensive defaults fail toward charging; Phase 6 runs a grep-parity count of dispatch sites vs. `dispatch_start_ts=` occurrences in both files |
| Narrated LLM judgment regresses into the "unsanctioned judgment call" problem this task exists to eliminate | H | M | The mechanical `meta_touched` gate must independently agree; the LLM judgment alone can **never** exempt a cycle |
| Rule drifts between the two variants over time | M | M | Rule text lives in one shared pattern doc; both SKILLs reference it by path rather than restating the rationale |
| Stale line anchors cause an edit to land in the wrong block | H | H | Every phase begins with a `grep -n` re-verification step; quoted `old_string` is authoritative over line numbers |
| Loop becomes unbounded if the Stage 7 infra terminal check is omitted | H | L | Phase 2 adds the terminal check *before* Phase 3 adds the exemption path, so the bound exists before the thing it bounds |
| MT-mode exemption misread as also exempting the shared wave cycle counter | M | M | Phase 4 states explicitly that `MAX_CYCLES_MT` is a per-wave counter that still increments; the MT fix is only about not marking `failed_tasks` |
| Edit lands in `.claude/**` instead of the source store | H | L | SOURCE-STORE RULE restated in every phase's task list; Phase 6 greps for accidental `.claude/` writes |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Wave 4's two phases touch **different files**
(`skill-orchestrate/SKILL.md` multi-task section vs. `skill-orchestrate-hard/SKILL.md`) — but note
Phase 4 edits the same *file* as Phases 2-3, so it must not be parallelized with them.

---

### Phase 1: Shared discrimination pattern doc [COMPLETED]

**Goal**: Establish the single source of truth for the discrimination rule, registered in the
context index and cross-linked, so both SKILL.md files can reference rather than restate it.

**Tasks**:
- [x] Create `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` with,
      at minimum, these sections (content taken verbatim from this plan's "Design Summary"):
  - `## Why there is no single mechanical signal` — Agent tool calls are LLM tool invocations
    observed at return time; Stage 5 bash runs strictly after, so it has structurally already lost
    the distinguishing signal. `skill_preflight_update` is caller-written and proves nothing.
  - `## The two required signals` — the signal table, positive/negative transport-error indicators,
    and the `AND` classification rule with its "either alone defaults to charging" statement.
  - `## Why `.return-meta.json` is the mechanical probe` — the early-metadata Stage 0 contract; the
    accepted residual false-negative.
  - `## The counter and its cap` — `infra_failures`, `MAX_INFRA_FAILURES=3` flat in both variants,
    the `burnout_signals_this_session` shape it imitates and the one point where it deliberately
    diverges (burnout has no cap because its increments are cycle-consuming; this one's are not).
  - `## Bound` — the `MAX_CYCLES + MAX_INFRA_FAILURES` worst-case iteration count for both variants,
    and the invariant "every iteration charges exactly one of the two counters".
  - `## Terminal condition` — exit `partial`, distinct message, never also charge `cycle_count`.
  - `## Failing safe` — the `${VAR:-default}` conventions and the warning not to weaken the `AND`.
  - `## Related Documentation` — link `patterns/early-metadata-pattern.md`,
    `patterns/mcp-tool-recovery.md`, `rules/error-handling.md`.
- [x] Register the new file in `agent-system/extensions/core/index-entries.json`, matching the
      existing entry shape exactly:
      ```json
      {
        "path": "patterns/infra-failure-discrimination.md",
        "domain": "core",
        "subdomain": "patterns",
        "summary": "Distinguishing Agent-tool transport failures from genuine orchestrate work cycles",
        "line_count": <actual>,
        "keywords": ["patterns", "orchestrate", "infra", "failure", "cycles"],
        "topics": ["recovery"],
        "load_when": { "agents": [], "task_types": ["meta"], "commands": [] }
      }
      ```
      Set `line_count` to the real `wc -l` of the file.
- [x] Add a cross-link to the new doc from
      `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md`'s
      "Related Documentation" section, noting it covers Agent/Task-tool transport-layer failure
      recognition (which `mcp-tool-recovery.md` does not).
- [x] Confirm no task-number citations appear anywhere in the new file.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` - NEW
- `agent-system/extensions/core/index-entries.json` - add one entry
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` - add cross-link

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` exits 0.
- `jq -r '.entries[] | select(.path=="patterns/infra-failure-discrimination.md")' agent-system/extensions/core/index-entries.json` returns the entry.
- `grep -nE '\btasks? [0-9]{2,4}\b' agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` returns nothing.
- The doc contains both the literal string `MAX_INFRA_FAILURES` and the worst-case bound arithmetic.

---

### Phase 2: Base counter plumbing — Stage 2 init, Stage 4 dispatch windows, Stage 7 terminal [NOT STARTED]

**Goal**: Add the counter, the per-dispatch window capture, and the terminal bound to
`skill-orchestrate/SKILL.md` — everything *except* the Stage 5 exemption branch. The bound is
installed before the thing it bounds.

**Tasks**:
- [ ] Re-verify anchors: `grep -n 'MAX_CYCLES=5\|Invoke the Agent tool\|MAX_CYCLES reached' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- [ ] **Stage 2 (~line 105)**: replace `MAX_CYCLES=5` with:
      ```bash
      MAX_CYCLES=5
      # Infrastructure-failure counter, separate from the work-cycle budget. See
      # context/patterns/infra-failure-discrimination.md. Flat (not scaled with MAX_CYCLES):
      # transport flakiness is unrelated to plan size.
      MAX_INFRA_FAILURES=3
      ```
- [ ] **Stage 2 resume branch (~line 113-114)**: replace with:
      ```bash
      cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
      infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
      echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
      ```
- [ ] **Stage 2 fresh-start `jq -n` blob (~line 121-134)**: add the `--argjson` and the two fields,
      and set the shell variable on success:
      ```bash
        if jq -n \
          --arg session_id "$session_id" \
          --argjson max_cycles "$MAX_CYCLES" \
          --argjson max_infra_failures "$MAX_INFRA_FAILURES" \
          --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{
            "session_id": $session_id,
            "cycle_count": 0,
            "max_cycles": $max_cycles,
            "infra_failures": 0,
            "max_infra_failures": $max_infra_failures,
            "current_state": "reading",
            "started": $started,
            "last_updated": $started
          }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
          cycle_count=0
          infra_failures=0
          echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES, MAX_INFRA_FAILURES=$MAX_INFRA_FAILURES"
      ```
- [ ] **Stage 2 lost-race branch (~line 136-138)**: read **both** counters (this branch was itself a
      past bug fix for reading only one counter — do not repeat it):
      ```bash
          # Lost the creation race: another writer won. Resume from their guard, reading BOTH
          # counters — not just cycle_count.
          cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
          infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
          echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
      ```
- [ ] **Stage 4 — all four dispatch sites**: `not_started` (~220), `researched` (~253),
      `planned`/`implementing` (~278), `partial` continuation (~312). Immediately **before** each
      `Invoke the Agent tool:` line insert:
      ````
      ```bash
      # Dispatch window for infra-failure discrimination — see
      # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
      # stale `true` can never carry over from a previous cycle.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false
      ```
      ````
      and immediately **after** each dispatch table insert (adapting the existing trailing sentence,
      which already reads "After Agent tool returns: read handoff... Increment cycle_count."):
      ```
      **After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
      `context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
      ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
      any kind. Any subagent-authored output — including text in which the subagent describes an
      error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
      charged.
      ```
      Keep each site's existing trailing sentence otherwise intact.
- [ ] **Stage 7 loop-guard persist (~line 558-562)**: add `infra_failures` to the write
      (belt-and-suspenders — the Stage 5 increment in Phase 3 persists it too; `jq` field assignment
      preserves other fields either way):
      ```bash
      jq --arg state "$current_status" \
         --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --argjson count "$cycle_count" \
         --argjson infra "${infra_failures:-0}" \
        '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .infra_failures = $infra' \
        "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      ```
- [ ] **Stage 7 terminal condition**: insert the following block **immediately before** the existing
      `If MAX_CYCLES reached` block (~line 565), so the more specific diagnosis wins:
      ```
      If MAX_INFRA_FAILURES reached (infra_failures >= MAX_INFRA_FAILURES):

      ```
      echo "[orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number — repeated Agent tool transport/API failures with no subagent execution."
      echo "This is a connectivity problem, not a work-budget problem: cycle_count is still $cycle_count/$MAX_CYCLES."
      echo "Run /orchestrate $task_number again once connectivity is confirmed."
      EXIT (partial)
      ```

      This is the explicit bound on the exemption path. Because an infra-exempt cycle does not
      increment `cycle_count`, the `while` condition alone would not advance; this check — which runs
      at the end of every cycle — is what terminates the run. Worst-case iterations per invocation
      are therefore `MAX_CYCLES + MAX_INFRA_FAILURES` = 8. Do NOT also increment `cycle_count` here:
      the cap's purpose is to stay outside the work-cycle budget.
      ```

**Timing**: 1.25 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 2, Stage 4 (x4), Stage 7

**Verification**:
- `grep -c 'dispatch_start_ts=' .../skill-orchestrate/SKILL.md` returns `4`.
- `grep -c 'Invoke the Agent tool' .../skill-orchestrate/SKILL.md` — record this number; the four
  Stage 4 state-handler dispatches must each be covered. Stage 5a/Stage 6 fork dispatches are
  intentionally *not* covered (out of scope per the research report) — confirm any excess count
  is attributable only to those.
- `grep -n 'infra_failures' .../skill-orchestrate/SKILL.md` shows hits in all three Stage 2 init
  paths, the Stage 7 persist, and the Stage 7 terminal check.
- `grep -n 'MAX_INFRA_FAILURES' .../skill-orchestrate/SKILL.md` shows the declaration and the
  terminal check.
- No new task-number citations: `git diff -- agent-system/ | grep -nE '^\+.*\btasks? [0-9]{2,4}\b'`
  returns nothing.

---

### Phase 3: Base Stage 5 discrimination branch [NOT STARTED]

**Goal**: Replace `skill-orchestrate/SKILL.md`'s unconditional missing-handoff cycle charge with the
two-signal branch, and make the `cycle_count` increment conditional.

**Tasks**:
- [ ] Re-verify the anchor: `grep -n 'Skill did not write orchestrator handoff' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- [ ] Replace this exact block (currently ~lines 374-379):
      ```bash
      if [ ! -f "$handoff_file" ]; then
        echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
        echo "This may mean orchestrator_mode was not propagated correctly."
        # Increment cycle and continue — state.json may still have been updated
      else
      ```
      with:
      ```bash
      # Reset the per-cycle exemption flag before any branch can set it.
      infra_exempt_cycle=false

      if [ ! -f "$handoff_file" ]; then
        echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
        echo "This may mean orchestrator_mode was not propagated correctly."

        # Infra-failure discrimination — see context/patterns/infra-failure-discrimination.md.
        # TWO corroborating signals are required to exempt this cycle from the work-cycle budget:
        #   (a) dispatch_was_transport_error — narrated judgment about the Agent tool call itself,
        #       set at the dispatch site in Stage 4;
        #   (b) meta_touched — mechanical check of whether the subagent's own Stage 0
        #       early-metadata write landed inside this dispatch window.
        # Either signal alone DEFAULTS TO CHARGING a genuine cycle. The defaults below are chosen
        # so a dispatch site that forgot to set its variables also falls back to charging.
        # Do not weaken the AND below into an OR or a fallthrough.
        meta_file="${TASK_DIR}/.return-meta.json"
        window_start="${dispatch_start_ts:-9999999999}"
        meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
        if [ "$meta_mtime" -ge "$window_start" ]; then
          meta_touched=true
        else
          meta_touched=false
        fi

        if [ "${dispatch_was_transport_error:-false}" = "true" ] && [ "$meta_touched" = "false" ]; then
          # Corroborated infra failure: the Agent tool call failed at the transport/API layer AND
          # the subagent left no footprint at all. Charge infra_failures, never cycle_count.
          infra_failures=$((infra_failures + 1))
          jq --argjson infra "$infra_failures" \
             --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.infra_failures = $infra | .last_updated = $updated' \
            "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
          echo "[orchestrate] INFRA FAILURE $infra_failures/$MAX_INFRA_FAILURES — Agent tool transport/API failure with no subagent footprint. Not charged against MAX_CYCLES." >&2
          infra_exempt_cycle=true
        else
          echo "[orchestrate] Missing handoff charged as a genuine work cycle (transport_error=${dispatch_was_transport_error:-false}, meta_touched=$meta_touched)." >&2
        fi
      else
      ```
- [ ] Replace the unconditional increment at the end of Stage 5 (currently ~lines 461-462):
      ```bash
      # Increment cycle_count
      cycle_count=$((cycle_count + 1))
      ```
      with:
      ```bash
      # Increment cycle_count — skipped ONLY for a corroborated infra failure, which is separately
      # bounded by MAX_INFRA_FAILURES (Stage 7). Every iteration charges exactly one of the two
      # counters; both are capped, so worst-case iterations per invocation are
      # MAX_CYCLES + MAX_INFRA_FAILURES.
      if [ "$infra_exempt_cycle" = "true" ]; then
        echo "[orchestrate] Cycle not charged (infra failure). cycle_count remains $cycle_count/$MAX_CYCLES." >&2
      else
        cycle_count=$((cycle_count + 1))
      fi
      ```
- [ ] Confirm the `implemented)` phase-completion gate block and its comment are untouched by these
      edits (they sit between the two replacement sites).

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage 5

**Verification**:
- `grep -n 'infra_exempt_cycle' .../skill-orchestrate/SKILL.md` shows exactly three occurrences
  (reset, set, test).
- The string `# Increment cycle and continue` no longer appears in `skill-orchestrate/SKILL.md`.
- `grep -n 'phases_completed" -ge "\$phases_total' .../skill-orchestrate/SKILL.md` still matches
  (the phase-completion gate survived).
- `bash -n` is not applicable (markdown), so instead: extract the Stage 5 fenced bash block to a
  temp file and run `bash -n` on it to confirm the `if`/`else`/`fi` nesting is balanced.

---

### Phase 4: Base multi-task mode — Stage MT-1 schema and Stage MT-4 step 1 [NOT STARTED]

**Goal**: Fix the worse manifestation. Today MT-4 marks any missing-handoff task into `failed_tasks`
with **no retry at all**. After this phase, a corroborated infra failure defers the task instead,
up to `MAX_INFRA_FAILURES` times, after which the historical `failed_tasks` behavior resumes.

**Important scoping note the implementer must preserve**: in multi-task mode, `cycle_count` /
`MAX_CYCLES_MT` is a **per-wave** counter incremented once per loop iteration regardless of any
individual task's outcome. This phase does **not** exempt anything from that counter — the outer
loop bound is unchanged. The fix here is exclusively about not marking a task `failed_tasks`.
Because `MAX_CYCLES_MT` still advances every cycle, the multi-task loop is already bounded and no
new terminal condition is needed; the per-task `MAX_INFRA_FAILURES` cap is a second, independent
bound ensuring a persistently failing task still lands in `failed_tasks` rather than being deferred
forever.

**Tasks**:
- [ ] Re-verify anchors: `grep -n 'MAX_CYCLES_MT = min\|mark task in \`failed_tasks\`, skip' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- [ ] **Stage MT-1 (~line 648-650)**: replace the Compute + Initialize lines with:
      ```
      Compute: `task_count = length(task_numbers)`, `MAX_CYCLES_MT = min(task_count * 5, 25)`,
      `MAX_INFRA_FAILURES = 3` (flat **per task**, not scaled by `task_count` — matching single-task
      mode; see `context/patterns/infra-failure-discrimination.md`).

      Initialize `mt_state_file = "specs/.orchestrator-multi-state.json"` with fields: `session_id`,
      `task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, `failed_tasks: []`,
      `completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`,
      `implement_agents: {}`, `infra_failures: {}` (map task_num -> count, default 0), and
      `dispatch_start_ts: {}` (map task_num -> unix seconds, written at dispatch time).
      ```
- [ ] **Stage MT-4 dispatch bullets (~lines 770-783)**: add one bullet as the **first** bullet of
      each of the three `For each task in ...` lists (`research_tasks`, `plan_tasks`,
      `implement_tasks`):
      ```
      - Record the dispatch window: `jq --arg t "$task_num" --argjson ts "$(date -u +%s)" '.dispatch_start_ts[$t] = $ts' "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"`, and reset this task's `task_transport_error` to `false`
      ```
- [ ] **Stage MT-4, after the "After all Agent tool calls complete" sentence (~line 785)**: insert:
      ```
      **Per-task transport judgment (narrated, before the handoff loop)**: for each dispatched task,
      judge that task's OWN Agent tool call outcome per
      `context/patterns/infra-failure-discrimination.md` and set `task_transport_error` for that task
      to `true` only if the call itself returned a transport/API-layer error with no
      subagent-authored text of any kind. Judge each task independently — never carry one task's
      verdict over to another in the same batch.
      ```
- [ ] **Stage MT-4 step 1 (~line 788)**: replace
      `1. Read `task_dir/.orchestrator-handoff.json`. If missing: mark task in `failed_tasks`, skip.`
      with:
      ````
      1. Read `task_dir/.orchestrator-handoff.json`. If present, continue to step 2. **If missing**,
         apply the infra-failure discrimination rule
         (`context/patterns/infra-failure-discrimination.md`) scoped to THIS task before deciding.
         This branch is the worse of the two manifestations of the defect: unlike single-task Stage 5
         it has historically had no retry at all.

         ```bash
         meta_file="${task_dir}/.return-meta.json"
         window_start=$(jq -r --arg t "$task_num" '.dispatch_start_ts[$t] // 9999999999' "$mt_state_file")
         meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
         task_infra=$(jq -r --arg t "$task_num" '.infra_failures[$t] // 0' "$mt_state_file")

         if [ "${task_transport_error:-false}" = "true" ] && [ "$meta_mtime" -lt "$window_start" ]; then
           task_infra=$((task_infra + 1))
           jq --arg t "$task_num" --argjson n "$task_infra" \
             '.infra_failures[$t] = $n' "$mt_state_file" > "${mt_state_file}.tmp" \
             && mv "${mt_state_file}.tmp" "$mt_state_file"
           if [ "$task_infra" -ge "$MAX_INFRA_FAILURES" ]; then
             echo "[orchestrate] Task #${task_num}: MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached — repeated transport/API failures. Marking failed_tasks." >&2
             # Cap reached: fall back to the historical behavior — add to failed_tasks,
             # release the per-task lock (step 6), skip steps 2-5.
           else
             echo "[orchestrate] Task #${task_num}: INFRA FAILURE ${task_infra}/${MAX_INFRA_FAILURES} — NOT marked failed; stays eligible for the next cycle." >&2
             # Do NOT add to failed_tasks. Release the per-task lock (step 6), skip steps 2-5.
           fi
         else
           # Genuine missing handoff (the subagent ran, or there is no corroborating transport
           # error): preserve the historical behavior exactly.
           echo "[orchestrate] Task #${task_num}: missing handoff charged as genuine (transport_error=${task_transport_error:-false}). Marking failed_tasks." >&2
           # Add to failed_tasks, release the per-task lock (step 6), skip steps 2-5.
         fi
         ```

         **Bound**: the shared `MAX_CYCLES_MT` still increments once per wave cycle regardless of any
         task's infra verdict, so the outer loop is unchanged and already bounded. Independently, a
         task can be infra-deferred at most `MAX_INFRA_FAILURES` times before it lands in
         `failed_tasks` anyway — so no task can keep the wave alive indefinitely.
      ````
- [ ] Confirm the per-task lock release in step 6 still runs on **all** three outcomes above
      (deferred, capped-to-failed, genuine-failed). A deferred task that keeps its lock would
      deadlock its own next cycle — verify against the task-lock same-session re-entry semantics
      documented in the Task-lock acquire block.

**Timing**: 1.25 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1, Stage MT-4

**Verification**:
- `grep -n 'dispatch_start_ts' .../skill-orchestrate/SKILL.md` shows the MT-1 schema field plus
  three MT-4 dispatch-bullet occurrences, in addition to Phase 2's four single-task sites.
- `grep -n 'task_transport_error' .../skill-orchestrate/SKILL.md` shows the narrated judgment
  paragraph and the step-1 branch.
- The exact string ``If missing: mark task in `failed_tasks`, skip.`` no longer appears.
- The MT-4 phase-completion gate text (step 3's `implemented` handling) is unchanged.

---

### Phase 5: Hard-mode variant — Stage 2, Stage 4, Stage 5, Stage 7 [NOT STARTED]

**Goal**: Apply the same changes to `skill-orchestrate-hard/SKILL.md`, matching
`burnout_signals_this_session`'s declaration/persistence shape exactly. Multi-task mode needs no
hard-mode edit — the hard variant's "Multi-Task Mode" section delegates to base MT-1..MT-5
unmodified, so Phase 4 already covers `/orchestrate --hard` multi-task runs.

**Tasks**:
- [ ] Re-verify anchors: `grep -n 'MAX_CYCLES=13\|burnout_signals_this_session\|Agent tool:\|Skill did not write orchestrator handoff\|MAX_CYCLES reached' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- [ ] **Stage 2 (~line 192)**: add `MAX_INFRA_FAILURES=3` directly after `MAX_CYCLES=13`, with the
      same explanatory comment used in the base variant. Value is identical to base — flat, not
      scaled with hard mode's larger `MAX_CYCLES`.
- [ ] **Stage 2 resume branch (~line 200-202)**: add
      `infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")` alongside the
      `burnout_signals_this_session` read, and extend the echo to report
      `(burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)`.
- [ ] **Stage 2 fresh-start `jq -n` blob (~line 210-225)**: add
      `--argjson max_infra_failures "$MAX_INFRA_FAILURES"`, the fields `"infra_failures": 0` and
      `"max_infra_failures": $max_infra_failures` alongside `"burnout_signals_this_session": 0`, and
      `infra_failures=0` alongside `burnout_signals_this_session=0` on the success path.
- [ ] **Stage 2 lost-race branch (~line 226-229)**: read `infra_failures` too. Update the existing
      comment at ~line 208-209 (which currently says the lost-race branch must read BOTH counters)
      to say it must read **all** persisted counters, naming them.
- [ ] **Stage 4 — all four dispatch sites**: `not_started` (~333), the H4 verification re-dispatch
      (~368-373), the planner dispatch inside the `adversarial_verified=true` branch (~386-390), and
      the H1 per-phase dispatch (~450-453). Immediately before each `Agent tool:` block insert:
      ```bash
      # Dispatch window for infra-failure discrimination — see
      # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false
      ```
      Note these sites are pseudo-`Agent tool:` blocks *inside* bash fences, unlike base's markdown
      tables — insert the lines inside the same fence, not a new one. After each, add the same
      narrated transport-judgment instruction used in Phase 2, adapted to hard mode's existing
      trailing sentences (e.g. `not_started`'s "Set `adversarial_verified=false`. Increment
      cycle_count.").
- [ ] **Stage 5 (~line 626-630)**: apply the Phase 3 replacement verbatim, substituting the
      `[hard-orchestrate]` log prefix for `[orchestrate]` in every echo. Preserve the surrounding
      `<!-- BEGIN/END 772 Item 5B -->` markers and the hard-mode-specific `sorry_inventory` /
      `skeleton` reads untouched.
- [ ] **Stage 5 increment (~line 714-715)**: apply the Phase 3 conditional-increment replacement,
      again with the `[hard-orchestrate]` prefix.
- [ ] **Stage 7 (~line 757-767)**: insert the MAX_INFRA_FAILURES terminal block **before** the
      existing MAX_CYCLES check, in hard mode's bash-block idiom:
      ```bash
      # MAX_INFRA_FAILURES reached — repeated transport/API failures, distinct from work-budget
      # exhaustion. This is the explicit bound on the exemption path: an infra-exempt cycle does not
      # increment cycle_count, so worst-case iterations per invocation are
      # MAX_CYCLES + MAX_INFRA_FAILURES = 16.
      if [ "${infra_failures:-0}" -ge "$MAX_INFRA_FAILURES" ]; then
        echo "[hard-orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number — repeated Agent tool transport/API failures with no subagent execution."
        echo "This is a connectivity problem, not a work-budget problem: cycle_count is still $cycle_count/$MAX_CYCLES."
        echo "Run /orchestrate $task_number --hard again once connectivity is confirmed."
        EXIT (partial, cycle_count=$cycle_count)
      fi
      ```
      Do NOT also increment `cycle_count` here.
- [ ] **Verify (do not edit)** that hard mode's "Multi-Task Mode" section still reads "Same as base
      `skill-orchestrate` multi-task stages (MT-1 through MT-5)". If it does, Phase 4's fix covers
      hard-mode multi-task runs and no hard-mode MT edit is needed. If that delegation has changed,
      STOP and report — do not silently duplicate the MT logic here.
- [ ] Confirm Stage 3b's loop-guard `jq` write uses field assignment (`.field = value`) and therefore
      preserves `infra_failures`. If so, no Stage 3b change is required; record the confirmation.

**Timing**: 1.25 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - Stage 2, Stage 4 (x4), Stage 5, Stage 7

**Verification**:
- `grep -c 'dispatch_start_ts=' .../skill-orchestrate-hard/SKILL.md` returns `4`.
- `grep -c 'infra_failures' .../skill-orchestrate-hard/SKILL.md` shows hits in all three Stage 2
  init paths, the Stage 5 increment, and the Stage 7 terminal check.
- The string `# Increment cycle and continue` no longer appears in the hard file.
- `grep -n 'burnout_signals_this_session' .../skill-orchestrate-hard/SKILL.md` count is unchanged
  from before this phase (no accidental removal).
- `grep -n 'Same as base .skill-orchestrate. multi-task stages' .../skill-orchestrate-hard/SKILL.md`
  still matches.
- Extracting the Stage 2 and Stage 5 fenced bash blocks and running `bash -n` on each confirms
  balanced nesting.

---

### Phase 6: Cross-file consistency sweep and architecture doc update [NOT STARTED]

**Goal**: Catch omissions the per-phase verifications cannot see, and update the architecture doc
that documents the loop-guard schema.

**Tasks**:
- [ ] **Dispatch-site parity audit**: for each SKILL.md, list every dispatch site and confirm the
      four in-scope Stage 4 sites each have a preceding `dispatch_start_ts=`. Confirm the
      intentionally-excluded sites are exactly: base Stage 5a drift-inspection fork, base Stage 6
      steps 2/4/5, hard Stage 4b churn-audit dispatch, hard Stage 6. Record the excluded list
      explicitly in the summary — an unrecorded exclusion is indistinguishable from an omission.
- [ ] **`.claude/` leak check**: `git status --short` and `git diff --name-only` must show no
      modified path under `.claude/`. All edits must be under `agent-system/extensions/core/`.
- [ ] **Task-number citation check**: `git diff -- agent-system/ | grep -nE '^\+.*\btasks? [0-9]{2,4}\b'`
      must return nothing.
- [ ] **Update `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`**:
  - Section `## MAX_CYCLES Enforcement` (~line 95): add `MAX_INFRA_FAILURES=3` next to
    `MAX_CYCLES=5`, and add `"infra_failures": 0` / `"max_infra_failures": 3` to the example
    loop-guard JSON (~line 100-104).
  - Add a short subsection documenting the two-signal rule by reference (link to
    `context/patterns/infra-failure-discrimination.md` — do not restate the rationale) and the
    distinct MAX_INFRA_FAILURES terminal message.
  - Terminal-conditions table (~line 29): add a row for `partial` (infra cap) with condition
    `infra_failures >= MAX_INFRA_FAILURES`.
  - Multi-task terminal table (~line 335): add a per-task infra-cap note.
- [ ] **Check `agent-system/extensions/core/commands/orchestrate.md`** (~lines 26, 460): if it
      enumerates termination reasons, add the infra-cap reason. Keep it to one line; the command doc
      is user-facing.
- [ ] **Check `agent-system/extensions/core/docs/architecture/architecture-spec.md`** for a
      loop-guard schema mention; update only if it enumerates the guard's fields.
- [ ] Run `bash agent-system/extensions/core/scripts/validate-context-index.sh` (or the repo's
      nearest equivalent) to confirm the new `index-entries.json` entry validates. If the script
      expects the deployed `.claude/context/index.json` and that tree is stale, note the result
      rather than deploying — deployment is user-driven and out of scope.

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - schema + terminal conditions
- `agent-system/extensions/core/commands/orchestrate.md` - termination reason (if enumerated)
- `agent-system/extensions/core/docs/architecture/architecture-spec.md` - only if it lists guard fields

**Verification**:
- `grep -rn 'MAX_INFRA_FAILURES' agent-system/extensions/core/` returns hits in: the pattern doc,
  both SKILL.md files, and `orchestrate-state-machine.md`.
- `git diff --name-only` lists only paths under `agent-system/extensions/core/` and `specs/`.
- The dispatch-site parity audit and its explicit exclusion list are recorded in the summary.

---

## Testing & Validation

There is no executable test harness for SKILL.md prose-plus-bash. Validation is structural:

- [ ] Every fenced bash block edited in Phases 2, 3, 5 extracted and passed to `bash -n` without
      syntax errors (balanced `if`/`else`/`fi`, correct quoting).
- [ ] `jq empty` passes on `agent-system/extensions/core/index-entries.json`.
- [ ] Dispatch-site parity: `dispatch_start_ts=` count equals 4 in each SKILL.md, plus 3 MT-4
      occurrences in the base file's multi-task section.
- [ ] The literal string `# Increment cycle and continue` appears in neither SKILL.md.
- [ ] Trace the bound by hand on paper for both variants: an invocation in which every dispatch is a
      corroborated infra failure terminates after exactly `MAX_INFRA_FAILURES` iterations; an
      invocation with no infra failures terminates after exactly `MAX_CYCLES`; a mixed invocation
      terminates after at most `MAX_CYCLES + MAX_INFRA_FAILURES`. Record this trace in the summary.
- [ ] Trace the conservative default by hand: a missing handoff with `dispatch_was_transport_error`
      unset charges a cycle; with it `true` but `.return-meta.json` freshly written, charges a cycle.
- [ ] No path under `.claude/` modified.
- [ ] No new task-number citations outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` (new)
- Modified: `agent-system/extensions/core/index-entries.json`
- Modified: `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Modified: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- Possibly modified: `agent-system/extensions/core/commands/orchestrate.md`,
  `agent-system/extensions/core/docs/architecture/architecture-spec.md`
- `specs/895_separate_infra_failure_from_orchestrate_work_cycles/summaries/01_*-summary.md`

## Rollback/Contingency

All changes are additive text edits in a git-tracked source store; `git checkout` of the six touched
files reverts cleanly, and the deployed `.claude/` tree is regenerated from the source store, so no
deploy-side rollback exists to worry about.

Partial-failure contingencies, in order of preference:

1. **If a phase fails mid-file**, revert only that file and re-run the phase. Phases 2-3 are
   sequential on the same file, so a Phase 3 failure never requires redoing Phase 2.
2. **If the discrimination rule proves too permissive in practice** (a cycle is exempted that should
   have been charged), the single-line fix is to change the Stage 5 condition from
   `transport_error AND NOT meta_touched` to always-false — i.e. delete the `if` arm and keep the
   `else`. That restores today's behavior exactly while leaving the counter plumbing in place.
3. **If it proves too conservative** (real outages still burning cycles), do **not** relax the
   `AND` — that is the failure direction the task exists to prevent. Instead raise
   `MAX_INFRA_FAILURES`, or add a third corroborating signal.
4. **If the multi-task defer causes a task to spin**, set `MAX_INFRA_FAILURES` to `0` for MT mode
   only, which restores the historical immediate-`failed_tasks` behavior there while leaving
   single-task mode fixed.
