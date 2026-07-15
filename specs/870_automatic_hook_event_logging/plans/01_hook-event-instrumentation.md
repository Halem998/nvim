# Implementation Plan: Automatic Event-Store Instrumentation and Hook Logging

- **Task**: 870 - Emit structured events into the unified event store (specs/events.jsonl) automatically
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: Task 869 (event store plumbing — COMPLETE; `events-append.sh` is the append target)
- **Research Inputs**: specs/870_automatic_hook_event_logging/reports/01_automatic-hook-event-logging.md
- **Artifacts**: plans/01_hook-event-instrumentation.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Make the unified event store (`specs/events.jsonl`) receive events automatically. Task 869 shipped
`events-append.sh` as a complete, `flock`-guarded, lazy-creating append library with zero callers;
this task wires up its first consumers. Two instrumentation surfaces are added: (1) the four
`skill-base.sh` lifecycle functions (`skill_preflight_update`, `skill_context_injection`,
`skill_validate_artifact`, `skill_postflight_update`) gain start/end timing plus one non-blocking
`events-append.sh` call each; and (2) `orchestrator-postflight.sh` emits a single success/blocker
event at the point status is resolved, cross-linked to `specs/errors.json` when present. Two new
Claude-Code-native hook scripts are added — a `PostToolUse` logger keyed on `.return-meta.json`/
`errors.json` writes, and a combined `Stop`/`SubagentStop` logger keyed on marker files — then
registered in `manifest.json`/`root-files/settings.json` and reflected in `EXTENSION.md`. All edits
are confined to `agent-system/extensions/core/`. Definition of done: every dispatch through the
lifecycle produces well-formed, cross-linkable event lines; absence of `errors.json` is handled
gracefully; sync files (`manifest.json`, `index-entries.json`, `EXTENSION.md`) agree.

### Research Integration

Key findings integrated from the research report:
- `events-append.sh` has no callers today; this task is its first consumer. Its `--category` enum
  is `deviation|blocker|milestone|success`; lifecycle stages use `milestone`, orchestrator status
  uses `success` or `blocker`/`deviation`.
- The four lifecycle functions are clean, well-bounded call sites already carrying
  `task_number`/`session_id`/`operation` (plus exported `TASK_TYPE`/`TASK_DIR`); each maps onto a
  documented `checkpoint` value (preflight/context_injection/verification/postflight).
- `orchestrator-postflight.sh` resolves `status` at Stage 6 — the single highest-signal emission
  point, avoiding per-stage noise.
- Claude Code hook stdin carries no workflow `session_id`/task number; correlation must reuse
  existing patterns: marker-file lookup (`subagent-postflight.sh`'s `.postflight-pending` find),
  the `workflow-active` marker + message pattern-matching (`claude-stop-notify.sh`/`memory-nudge.sh`),
  and — most precisely for `PostToolUse` — reading the `.return-meta.json`/`errors.json` content just
  written.
- `root-files/settings.json` is the authoritative wiring target; `merge-sources/settings-hooks.json`
  is a stale subset (optional/secondary).
- Pre-existing drift: `EXTENSION.md` says `hooks | 11` while `manifest.provides.hooks` has 16 —
  correct in the same edit that adds the new hooks.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path`/`roadmap_flag` in delegation context).

## Goals & Non-Goals

**Goals**:
- Instrument the four `skill-base.sh` lifecycle functions to emit timed `milestone` events.
- Emit one success/blocker/deviation event from `orchestrator-postflight.sh` at status resolution,
  cross-linked to `errors.json` when present.
- Add a `PostToolUse` events logger (content-precise, keyed on `.return-meta.json`/`errors.json`).
- Add a combined `Stop`/`SubagentStop` events logger (marker + message-pattern correlation).
- Register both hooks in `manifest.json` `provides.hooks` and `root-files/settings.json`.
- Keep `manifest.json`, `index-entries.json`, and `EXTENSION.md` in sync (fix the pre-existing
  hooks-count drift).
- Every event write is non-blocking (`|| true`) and never alters a caller's `set -e` exit behavior.

**Non-Goals**:
- Do NOT modify the store contract itself (`events-append.sh`, `events-query.sh`,
  `events-format.md`, `events-schema.json`) except to *call* the append helper.
- Do NOT deploy/sync `agent-system/extensions/core/` to the live `.claude/` tree (out of scope,
  consistent with 869).
- Do NOT edit `CLAUDE.md` (auto-generated from merge-sources).
- Do NOT author a new `context/patterns/hook-event-correlation.md` doc (research recommends this as
  a separate follow-up task; outside this task's file scope).
- Do NOT build de-duplication logic for repeated `SubagentStop` fires (accept the documented
  trade-off instead).
- No task-number citations in any deliverable under `agent-system/` — use durable anchors.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Event write failure breaks a caller's `set -e` flow | H | L | Wrap every `events-append.sh` call in `>/dev/null 2>&1 \|\| true`; never let it affect exit status |
| `PostToolUse` overhead on every matching tool call | M | M | Cheap path/pattern early-exit before any `jq`/lock work (mirror `validate-plan-write.sh`); pay `events-append.sh` cost only on the narrow `.return-meta.json`/`errors.json` match |
| Absent `specs/errors.json` treated as fatal | M | M | Guard every read with `[ -f specs/errors.json ]` before `jq`; `error_ref` stays empty on absence/no-match |
| Malformed/mid-flight `.return-meta.json`/`errors.json` at `PostToolUse` time | M | M | `jq empty "$file" 2>/dev/null \|\| exit 0` before extracting fields (mirror `skill_read_metadata`) |
| `.return-meta.json` already deleted when `Stop`/`SubagentStop` fires | M | M | `Stop`/`SubagentStop` hooks rely on marker files / message patterns only; `.return-meta.json`-derived events come from `PostToolUse` (fires at Write time, before cleanup) |
| Duplicate `SubagentStop` milestone events under loop-guard continuation | L | M | Document as accepted trade-off; downstream can dedupe by `session_id`+`checkpoint`. Optionally gate on the same "final stop" condition `subagent-postflight.sh` uses |
| `merge-sources/settings-hooks.json` staleness blocks scope | L | L | Treat `root-files/settings.json` as target of record; note drift, do not let the stale subset block the work |
| New hooks emit a blocking `decision` and stall Claude | H | L | Hooks always echo `{}` (never `"decision":"block"`), matching every non-guard hook in the directory |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 3, 4 |
| 3 | 6 | 5 |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel (they touch disjoint files).

---

### Phase 1: Instrument the four skill-base.sh lifecycle functions [COMPLETED]

**Goal**: Each of the four lifecycle functions records a start/end timer and emits one non-blocking
`milestone` event to `events-append.sh` with the correct `checkpoint`, `--task`, `--session`, and
`--duration`.

**Tasks**:
- [x] In `skill_preflight_update`: capture `_t0=$(date +%s.%N)` at entry, compute duration after the
      existing status-update + extension-hook calls, emit `--event-type lifecycle_stage --category
      milestone --checkpoint preflight --duration "$_dur" --task "$task_number" --session
      "$session_id"`, wrapped `>/dev/null 2>&1 || true`. *(completed)*
- [x] In `skill_context_injection`: same pattern, `--checkpoint context_injection` (function body is
      the hook call only — time around it). *(completed)*
- [x] In `skill_validate_artifact`: same pattern, `--checkpoint verification`; use the `status`
      argument as the `category` discriminator (`milestone` on success values; `deviation` when
      `failed`/`blocked`/`partial`). Guard on `task_number` being non-empty (already optional there). *(completed)*
- [x] In `skill_postflight_update`: same pattern, `--checkpoint postflight`, `--category milestone`. *(completed)*
- [x] Use `awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}'` for duration, matching
      the research-recommended snippet. *(completed)*
- [x] Confirm the calls use the `.claude/scripts/events-append.sh` path form already used by
      sibling `bash .claude/scripts/...` invocations in these functions. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` — add timer + one `events-append.sh` call in
  each of the four named functions.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` parses clean.
- Manual dry-run: source the file and call each function with dummy args in a temp dir; confirm a
  well-formed line lands in `specs/events.jsonl` and the function still returns 0 even if
  `events-append.sh` is made to fail.

---

### Phase 2: Emit success/blocker event from orchestrator-postflight.sh [COMPLETED]

**Goal**: At the stage where `orchestrator-postflight.sh` has resolved the run `status`, emit exactly
one event: `success` when status matches a success value, else `blocker`/`deviation`; populate
`--error-ref` from the most recent matching `errors.json` entry when the file exists.

**Tasks**:
- [x] Locate the stage that reads `.return-meta.json`'s `status` into the `status` variable
      (research: "Stage 6", lines ~133-166). *(completed)*
- [x] After `status` is known, compute `--duration` covering the full operation if a start timestamp
      is available (else omit `--duration`). *(completed)*
- [x] Map status → category: success value → `success`; `failed`/`blocked` → `blocker`;
      `partial` → `deviation`. *(completed)*
- [x] Cross-link `errors.json`: `[ -f specs/errors.json ]` guard, then `jq` the most recent entry
      whose `context.session_id` matches `$session_id`; pass its `id` as `--error-ref`. Empty on no
      match or absent file — never fatal. *(completed)*
- [x] Emit `--event-type orchestrator_status --checkpoint postflight` (or the stage's own checkpoint
      name), wrapped `|| echo "WARNING ..." >&2` in the script's existing non-blocking idiom. *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — one new event emission at
  status resolution.

**Verification**:
- `bash -n` parses clean.
- Simulate a `.return-meta.json` with `status: implemented` (no `errors.json`) → one `success` event,
  empty `error_ref`, script exits 0.
- Simulate `status: failed` with a matching `errors.json` entry → one `blocker` event with the
  correct `error_ref`.

---

### Phase 3: Create the PostToolUse events-logger hook [COMPLETED]

**Goal**: A new hook script that, on `Write` to `specs/*/.return-meta.json` or `specs/errors.json`,
reads the just-written file and emits a corresponding event; cheap early-exit on any non-matching
path; always echoes `{}`.

**Tasks**:
- [x] Create `agent-system/extensions/core/hooks/events-log-artifact.sh`. *(completed)*
- [x] Parse `CLAUDE_TOOL_INPUT` for `.file_path`; early-exit `echo '{}'` immediately if it is neither
      a `*/.return-meta.json` nor `specs/errors.json` path (no `jq`/lock work on the hot path). *(completed)*
- [x] On match: `jq empty "$file" 2>/dev/null || { echo '{}'; exit 0; }` guard, then extract
      `session_id`/`task`/`status` (return-meta) or `context.{session_id,task}`/`id`/`severity`
      (errors.json). *(completed)*
- [x] Call `events-append.sh` with the appropriate `--event-type` (`artifact_write` vs
      `error_logged`), `--category` (`milestone`/`success` for meta status; `blocker`/`deviation`
      for an error entry), and `--error-ref` (the errors.json `id` when the write is to errors.json). *(completed)*
- [x] Wrap the append `>/dev/null 2>&1 || true`; end with `echo '{}'`. Never emit `"decision"`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/hooks/events-log-artifact.sh` — new file.

**Verification**:
- `bash -n` parses clean.
- Pipe a synthetic `CLAUDE_TOOL_INPUT` for a `.return-meta.json` write → one event appended, `{}`
  echoed.
- Pipe a non-matching path (e.g. a `.lua` file) → no event, `{}` echoed, sub-millisecond exit.
- Pipe a `Write` to a missing/malformed file → `{}` echoed, no crash, no event.

---

### Phase 4: Create the Stop/SubagentStop events-logger hook [COMPLETED]

**Goal**: A new hook script that, on `Stop`/`SubagentStop`, correlates the active task via marker
files (and message pattern-matching as fallback) and emits a lifecycle event; always echoes `{}`.

**Tasks**:
- [x] Create `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (single script handling
      both hook types; branch on the stdin payload / `agent_id` presence as existing hooks do). *(completed)*
- [x] `SubagentStop` path: reuse `find specs -maxdepth 3 -name ".postflight-pending"` to locate the
      marker; read `session_id`/`skill`/`operation` from it. Emit `--event-type subagent_stop
      --category milestone --checkpoint postflight`. *(completed)*
- [x] `Stop` path: read `.claude/tmp/workflow-active` for an active task number; if absent, regex the
      `last_assistant_message` stdin field for `task [0-9]+`/`Task #[0-9]+` (mirror `memory-nudge.sh`)
      to recover a task number. Emit `--event-type session_stop --category milestone`. If no task can
      be recovered, still emit a session-scoped event (task omitted) or exit `{}` cleanly. *(deviation: altered — session_id for the Stop path resolved via state.json lookup keyed on the recovered task number, since neither correlation source carries session_id directly)*
- [x] Do NOT re-read `.return-meta.json` (may be cleaned up already). Correlation is marker/message
      only. *(completed)*
- [x] Document the accepted `SubagentStop` duplicate-event trade-off in a header comment; optionally
      gate emission on the same "final stop" condition `subagent-postflight.sh` uses. *(completed)*
- [x] Wrap the append `>/dev/null 2>&1 || true`; end with `echo '{}'`. Never emit `"decision"`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — new file.

**Verification**:
- `bash -n` parses clean.
- With a `.postflight-pending` marker present, a synthetic `SubagentStop` payload → one
  `subagent_stop` event carrying the marker's `session_id`; `{}` echoed.
- With `.claude/tmp/workflow-active` present, a synthetic `Stop` payload → one `session_stop` event;
  `{}` echoed.
- With neither marker nor a task-bearing message → `{}` echoed, no crash.

---

### Phase 5: Register hooks in manifest.json and root-files/settings.json [COMPLETED]

**Goal**: Wire the two new hook scripts so they are copied on deploy and fire on the right Claude Code
events.

**Tasks**:
- [x] Add `events-log-artifact.sh` and `events-log-lifecycle.sh` to `manifest.json`
      `provides.hooks` (16 → 18 entries), preserving array ordering conventions. *(completed)*
- [x] In `root-files/settings.json`: append an `events-log-artifact.sh` hook to the existing
      `PostToolUse` `Write|Edit` matcher (or add a dedicated `Write` matcher), following the
      `bash .claude/hooks/<name> 2>/dev/null || echo '{}'` idiom. *(completed)*
- [x] Append `events-log-lifecycle.sh` to the existing `Stop` matcher's hooks array and to the
      `SubagentStop` matcher's hooks array. *(completed)*
- [x] Confirm every added command uses the `|| echo '{}'` fallback so a hook failure never blocks. *(completed)*
- [x] Note (do not require): `merge-sources/settings-hooks.json` is a stale subset; leave a plan
      note that updating it is optional/secondary and not needed to make the hooks live in this repo. *(completed)*

**Timing**: 30 minutes

**Depends on**: 3, 4

**Files to modify**:
- `agent-system/extensions/core/manifest.json` — `provides.hooks` array.
- `agent-system/extensions/core/root-files/settings.json` — `PostToolUse`/`Stop`/`SubagentStop`.

**Verification**:
- `jq -e '.provides.hooks | index("events-log-artifact.sh") and index("events-log-lifecycle.sh")'
  manifest.json` succeeds.
- `jq -e '.hooks.PostToolUse' root-files/settings.json` and the `Stop`/`SubagentStop` arrays contain
  the new commands.
- `jq empty manifest.json root-files/settings.json` — both remain valid JSON.

---

### Phase 6: Sync EXTENSION.md and index-entries.json [NOT STARTED]

**Goal**: Documentation counts and capability descriptions agree with `manifest.json`; no dangling
index entries.

**Tasks**:
- [ ] Update `EXTENSION.md` summary table: `hooks | 11` → `hooks | 18` (corrects the pre-existing
      drift AND reflects the two new hooks in one edit). Confirm the `scripts | 52` row still matches
      `manifest.provides.scripts` length (no new scripts added — the new files are hooks).
- [ ] Add a short "Hook-Based Event Logging" bullet to the Key Capabilities section describing
      automatic emission into the unified event store, using durable anchors (reference
      `events-format.md` / the hook filenames), never a task number.
- [ ] Confirm `index-entries.json` needs no new entries: `events-format.md`/`events-schema.json`
      entries already exist from the store work; no new context docs are created by this task. Add an
      entry only if a doc file is created (it is not).
- [ ] Grep the touched files for accidental `task N` citations; ensure durable anchors only.

**Timing**: 30 minutes

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/core/EXTENSION.md` — counts + capability bullet.
- `agent-system/extensions/core/index-entries.json` — verify only (expected no change).

**Verification**:
- `EXTENSION.md` hooks count equals `jq '.provides.hooks | length' manifest.json` (18).
- `EXTENSION.md` scripts count equals `jq '.provides.scripts | length' manifest.json`.
- `grep -nE 'task [0-9]+|Task #[0-9]+' EXTENSION.md` returns nothing new (no task-number citations).

---

### Phase 7: End-to-end verification [NOT STARTED]

**Goal**: Confirm the whole path works: a simulated lifecycle produces well-formed, cross-linkable
event lines, and graceful degradation holds when `errors.json` is absent.

**Tasks**:
- [ ] `bash -n` all modified/new shell files.
- [ ] Run each new/changed emission path against a scratch `specs/events.jsonl` in a temp working
      dir; validate every produced line against `context/schemas/events-schema.json` (e.g. with the
      existing validation used by `events-append.sh`, or `jq` field checks).
- [ ] Verify absent-`errors.json` case: remove/omit the file and confirm no path errors and events
      still append with empty `error_ref`.
- [ ] Verify non-blocking guarantee: force `events-append.sh` to fail and confirm callers/hooks still
      exit 0 and echo `{}` where applicable.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` (doc-lint) if available; confirm it passes
      for the core extension.
- [ ] Confirm all edits are confined to `agent-system/extensions/core/` (git status scope check).

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4, 5, 6

**Files to modify**:
- None (verification only).

**Verification**:
- All produced event lines are schema-valid.
- Doc-lint passes; `jq empty` passes on all touched JSON.
- `git status --short` shows changes only under `agent-system/extensions/core/`.

---

## Testing & Validation

- [ ] `bash -n` passes on `skill-base.sh`, `orchestrator-postflight.sh`, `events-log-artifact.sh`,
      `events-log-lifecycle.sh`.
- [ ] `jq empty` passes on `manifest.json`, `root-files/settings.json`, `index-entries.json`.
- [ ] A simulated preflight→context_injection→verification→postflight sequence appends four
      `milestone` lifecycle events with correct `checkpoint` values and numeric `duration`.
- [ ] `orchestrator-postflight.sh` emits exactly one status event; `success` with no `errors.json`,
      `blocker` with a matching `error_ref` when `errors.json` is present.
- [ ] `PostToolUse` hook early-exits on non-matching paths and emits on `.return-meta.json`/
      `errors.json` writes; malformed files do not crash it.
- [ ] `Stop`/`SubagentStop` hook correlates via markers/messages and emits; missing correlation
      degrades to `{}` cleanly.
- [ ] `EXTENSION.md` hook/script counts equal the `manifest.json` array lengths.
- [ ] Every produced line validates against `events-schema.json`.
- [ ] No task-number citations in any file under `agent-system/`.
- [ ] All changes confined to `agent-system/extensions/core/`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` (instrumented — 4 functions)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (one status event)
- `agent-system/extensions/core/hooks/events-log-artifact.sh` (new PostToolUse hook)
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` (new Stop/SubagentStop hook)
- `agent-system/extensions/core/manifest.json` (provides.hooks 16 → 18)
- `agent-system/extensions/core/root-files/settings.json` (PostToolUse/Stop/SubagentStop wiring)
- `agent-system/extensions/core/EXTENSION.md` (hooks count 11 → 18, capability bullet)
- `specs/870_automatic_hook_event_logging/summaries/NN_hook-event-instrumentation-summary.md`
  (implementation summary)

## Rollback/Contingency

- All changes are additive and confined to `agent-system/extensions/core/`; revert is a single
  `git checkout -- agent-system/extensions/core/` (or reverting the task's commits).
- The new hooks and instrumentation are non-blocking by construction: if any event write fails or a
  hook misbehaves, callers still exit 0 and hooks echo `{}`, so a defect cannot stall the lifecycle.
- If a new hook proves noisy or costly in practice, removing its `manifest.json`/`settings.json`
  registration (Phase 5) disables it without touching the emission logic.
- The instrumentation does not deploy to the live `.claude/` tree, so a defect here cannot affect the
  running configuration until a separate, out-of-scope sync occurs.
