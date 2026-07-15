# Research Report: Task #870

**Task**: 870 - Emit structured events into the unified event store (specs/events.jsonl) automatically
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: Medium (instrumentation + 1-2 new hook scripts + sync-file updates)
**Dependencies**: Task 869 (unified event/reflection store plumbing) — COMPLETE
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/), task 869 summary, events-format.md/events-schema.json contracts
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 869's store plumbing (`events-append.sh`, `events-query.sh`, schema, format doc) is complete
  and fully documented but has **zero callers** — it exists purely as a library. Nothing writes to
  `specs/events.jsonl` today.
- The four `skill-base.sh` "lifecycle stage" functions the task names
  (`skill_preflight_update`, `skill_context_injection`, `skill_validate_artifact`,
  `skill_postflight_update`) already exist as clean, single-purpose call sites — each already has
  a documented "Stage N" comment block and an existing (currently no-op-in-practice) extension-hook
  call (`skill_run_extension_hook`). Wrapping each with a start/end timer and one
  `events-append.sh` call is a small, mechanical, additive change per function.
- The claim "no live functioning top-level lifecycle hook" is verified: the existing `Stop`/
  `SessionStart` hooks (`post-command.sh`, `log-session.sh`) write unstructured, one-line text to
  `.agent-logs/sessions.log`, a debug-only file with no machine reader anywhere in the codebase.
  No hook of any kind currently calls `events-append.sh`. This is the gap task 870 closes.
- The most reliable place to source **command/agent lifecycle + deviation/blocker** events for a
  `PostToolUse` hook is the moment a `.return-meta.json` or `specs/errors.json` write completes —
  both already carry `session_id`/`task` fields per their documented schemas, so a hook can read the
  file just written and emit a well-formed event without reconstructing context from Claude Code's
  sparse `Stop`/`SubagentStop` stdin payload (which has no workflow-level `session_id` or task
  number at all — only Claude Code's own internal session UUID and an `agent_id` field).
- `SubagentStop` should reuse the exact marker-discovery pattern already in
  `subagent-postflight.sh` (`find specs -maxdepth 3 -name ".postflight-pending"`), since that
  marker file already embeds `session_id`, `skill`, and `operation`. `Stop` should reuse the
  `workflow-active` marker (`.claude/tmp/workflow-active`, written by `update-task-status.sh
  preflight`) that `claude-stop-notify.sh` already reads, plus the pattern-matching approach in
  `memory-nudge.sh` for extracting a task number from the last assistant message when no marker
  is present.
- Recommended new/changed files, all within `file_scope`:
  - `agent-system/extensions/core/scripts/skill-base.sh` — instrument the 4 functions.
  - `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — emit a `success`/`blocker`
    event at Stage 7 (status determination) since this is where `researched|planned|implemented`
    vs `failed`/`partial` is already known, and cross-link to `errors.json` if the metadata's
    status is `failed`/`blocked`.
  - Two new hook scripts under `agent-system/extensions/core/hooks/`: an events-focused
    `PostToolUse` hook (e.g. `events-log-artifact.sh`) and a combined `Stop`/`SubagentStop` logger
    (e.g. `events-log-lifecycle.sh`, or two thin scripts sharing a helper).
  - `agent-system/extensions/core/manifest.json` — add new hook filenames to `provides.hooks`
    (currently 16 entries, though `EXTENSION.md`'s table already says 11 — pre-existing drift to
    fix while this table is touched anyway).
  - `agent-system/extensions/core/root-files/settings.json` — the authoritative, fuller hooks
    template (see Findings below) — add `PostToolUse`/`Stop`/`SubagentStop` entries for the new
    scripts.
  - `agent-system/extensions/core/merge-sources/settings-hooks.json` — optionally extend for
    consistency, though this file is a stale subset (see Findings) and may not be the live sync
    path for this already-bootstrapped repo.
  - `EXTENSION.md` (hooks/scripts counts + a "Hook-Based Event Logging" Key Capabilities bullet)
    and `index-entries.json` (no new context docs are strictly required, since `events-format.md`/
    `events-schema.json` entries already exist from task 869 — only add entries if new
    documentation files are created).

## Context & Scope

Task 870 depends on task 869 (COMPLETE) and must NOT re-touch the store contract itself
(`events-append.sh`, `events-query.sh`, `events-format.md`, `events-schema.json`) except to
*call* the append helper. Scope is instrumentation + hook wiring only, confined to
`agent-system/extensions/core/{hooks,scripts/skill-base.sh,scripts/orchestrator-postflight.sh,
root-files,manifest.json,EXTENSION.md,index-entries.json}` per the delegation's `file_scope`.
`agent-system/` is the versioned **source** for the "core" extension; it is a separate tree from
the deployed `.claude/` in this same repo (confirmed: `.claude/scripts/events-append.sh` does not
yet exist — task 869 likewise never deployed to `.claude/`). This task therefore only needs to
edit `agent-system/extensions/core/`; deployment/sync to `.claude/` is out of scope (consistent
with 869's precedent).

## Findings

### 1. The event store has no callers today

`events-append.sh` (`agent-system/extensions/core/scripts/events-append.sh`) is a complete,
validated, `flock`-guarded append helper. `events-query.sh` is a complete filter/aggregate reader.
Both tolerate the store's lazy absence. A repo-wide grep for `events-append.sh` / `events-query.sh`
usage outside their own definitions and the 869 summary returns nothing — no skill, hook, or
script currently invokes them. Task 870 is the first consumer.

### 2. `skill-base.sh`'s four lifecycle functions are clean, well-bounded instrumentation points

Read in full (478 lines). The four functions named in the task map exactly onto the documented
`checkpoint` common values in `events-format.md`:

| Function | Line | Current behavior | `checkpoint` value |
|---|---|---|---|
| `skill_preflight_update` | 142 | Calls `update-task-status.sh preflight`, then `skill_run_extension_hook "preflight" ...` | `preflight` |
| `skill_context_injection` | 180 | Calls `skill_run_extension_hook "context_injection" ...` only (pure hook call site — no other body) | `context_injection` |
| `skill_validate_artifact` | 253 | Runs `validate-artifact.sh --fix` (only if `status != failed` and file exists), then `skill_run_extension_hook "verification" ...` | `verification` |
| `skill_postflight_update` | 277 | Calls `update-task-status.sh postflight` only on success statuses, then `skill_run_extension_hook "postflight" ...` | `postflight` |

Each already receives (or has available in scope) `task_number`, `session_id`, and — via the
already-exported `TASK_TYPE`/`TASK_DIR` — enough context to build an `events-append.sh` call
with `--task`, `--session`, `--checkpoint`. `skill_validate_artifact` additionally already has the
`status` value (from `.return-meta.json`), which is the natural `category` discriminator
(`success` when `status` is a success value, `blocker`/`deviation` when `failed`/`blocked`/
`partial`).

Recommended pattern per function (timing via `date +%s.%N`, non-blocking via `|| true`, never
altering `set -e` exit behavior of the calling skill):
```bash
skill_preflight_update() {
  local task_number="$1" operation="$2" session_id="$3"
  local _t0; _t0=$(date +%s.%N)
  bash .claude/scripts/update-task-status.sh preflight "$task_number" "$operation" "$session_id"
  skill_run_extension_hook "preflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
  local _dur; _dur=$(awk -v a="$_t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.3f", b-a}')
  bash .claude/scripts/events-append.sh --event-type lifecycle_stage --category milestone \
    --session "$session_id" --task "$task_number" --checkpoint preflight --duration "$_dur" \
    --message "Preflight completed for ${operation}" >/dev/null 2>&1 || true
}
```
This mirrors the existing non-blocking conventions already used pervasively in
`orchestrator-postflight.sh` (every stage there is `|| echo "WARNING ..." >&2`, never fatal).

### 3. `orchestrator-postflight.sh` is where success/blocker status is already resolved

Stage 6 (lines 133-166) reads `.return-meta.json`'s `status` field into the `status` variable —
this is the single best place to emit a `success` (status matches `success_status`) or
`blocker`/`deviation` (status is `failed`/`partial`/`blocked`) event with `--duration` covering
the full research/plan/implement operation, and `--error-ref` populated by scanning
`specs/errors.json` (if present) for the most recent entry whose `context.session_id` matches, or
left empty if no match / file absent (never a hard dependency, per the store's own contract).

### 4. No hook anywhere writes to `specs/events.jsonl`; existing Stop/SessionStart hooks write to a dead-end debug log

`post-command.sh` (Stop) and `log-session.sh` (SessionStart) both `mkdir -p .agent-logs && echo
"[$TIMESTAMP] ..." >> .agent-logs/sessions.log`. A repo-wide grep confirms `.agent-logs/` is
referenced only in troubleshooting docs (`tail -f .agent-logs/subagent-postflight.log`) — i.e. it
exists solely for human tailing during debugging, never parsed by any script. This substantiates
the task's framing: no hook establishes a "live functioning" structured lifecycle log today. Task
870 is the first to make the `provides.hooks` + `settings.json` wiring convention actually feed a
structured, cross-linkable store rather than a plain-text scratch file.

Separately, `manifest.json`'s own top-level `"hooks"` object (the *extension lifecycle hook*
mechanism consumed by `skill_run_extension_hook`, distinct from Claude-Code-native
`provides.hooks`/`settings.json` wiring) is `{}` for `core` but **is** populated for `nix`
(`preflight`, `context_injection`) and `nvim` (`context_injection`) — so that particular mechanism
is not universally dead, just unused by `core` itself. The task's "no live functioning top-level
lifecycle hook" claim is accurate specifically for the Claude-Code-native `Stop`/`SubagentStop`/
`PostToolUse` hook wiring feeding any structured store — which is the mechanism in scope here.

### 5. `root-files/settings.json` is the fuller, authoritative hooks template; `merge-sources/settings-hooks.json` is a stale subset

Comparing the two:
- `root-files/settings.json` (deployed to a project's `.claude/settings.json` root file) has
  `PreToolUse` (2 matchers), `PostToolUse` (2 matchers: `state.json` write validation,
  `validate-plan-write.sh` on `Write|Edit`), `SessionStart` (2 matchers), `Stop` (1 matcher, 3
  hooks: `post-command.sh`, `claude-stop-notify.sh`, `memory-nudge.sh`), `UserPromptSubmit` (1
  matcher, 2 hooks), `SubagentStop` (1 matcher: `subagent-postflight.sh`), `Notification` (1
  matcher: `tts-notify.sh`).
- `merge-sources/settings-hooks.json` (the deep-merge source used to graft new hook registrations
  into an *existing* target repo's `.claude/settings.json` — see the manifest's own `_comment`
  documenting deep-merge array-append semantics) only has `SessionStart` (1 hook),
  `Stop` (1 hook: `claude-stop-notify.sh` only), and `UserPromptSubmit` (2 hooks) — a strict subset
  frozen at some earlier merge wave. It does not include `PostToolUse`, `SubagentStop`,
  `PreToolUse`, `Notification`, or the newer `Stop` hooks (`post-command.sh`, `memory-nudge.sh`).

**Implication for the plan**: new hook registrations must go into `root-files/settings.json` (the
file this repo's own `.claude/settings.json` was actually built from/kept in sync with — same
`PostToolUse`/`Stop`/`SubagentStop` shape). Updating `merge-sources/settings-hooth-hooks.json` too
is optional/lower-priority — it is a narrower historical artifact whose freshness relative to the
live wiring convention is already questionable and updating it is not required to make the new
hooks "live" in this repo. Flag this drift in the plan; do not silently let it block scope.

### 6. Session/task correlation without a native Claude-Code session_id

Claude Code's own `Stop`/`SubagentStop`/`PostToolUse` hook stdin JSON carries no workflow-level
`session_id` or task number — only `agent_id` (used by `claude-stop-notify.sh`/`memory-nudge.sh`
purely to detect "is this a subagent") and (for `PostToolUse`) `tool_input`/`tool_response`.
Existing hooks solve correlation two ways, both reusable here:
1. **Marker file lookup** (`subagent-postflight.sh`): `find specs -maxdepth 3 -name
   ".postflight-pending"` locates the active task's marker, which already contains
   `session_id`, `skill`, `operation`, written by `skill_create_postflight_marker`. Works for
   `SubagentStop`.
2. **`workflow-active` marker + message pattern-matching** (`claude-stop-notify.sh` +
   `memory-nudge.sh`): `.claude/tmp/workflow-active` (task number + timestamp, written by
   `update-task-status.sh preflight`) tells a `Stop` hook whether a lifecycle command is active;
   `memory-nudge.sh` additionally regexes the `last_assistant_message` stdin field for
   `task [0-9]+` / `Task #[0-9]+` to recover a task number when no marker is available. A new
   `Stop` events-logger hook should follow this same combination rather than inventing a third
   correlation mechanism.
3. **`.return-meta.json` / `errors.json` content itself** is the most precise source for a
   `PostToolUse` hook, since both already carry `session_id` (return-meta: documented required
   field; errors.json: `context.session_id`) and `task` (return-meta: implicit via directory path
   / errors.json: `context.task`) directly in the JSON that was just written — no reconstruction
   needed. This is the strongest design for the `PostToolUse` logger: match on `Write` to
   `specs/*/.return-meta.json` or `specs/errors.json`, then `jq` the file just written (or
   `tool_input.content` if available) directly into an `events-append.sh` call.

### 7. `specs/errors.json` schema and lazy-absence handling

Per `error-handling.md`, entries have `id` (`err_{timestamp}`), `timestamp`, `type`, `severity`,
`message`, `context.{session_id,command,task,phase,checkpoint}`, `trajectory`, `recovery`,
`fix_status`. `specs/errors.json` is confirmed absent in this repo right now (`test -f` returns
false) — exactly the "lazy absence" case the task calls out. Both `events-append.sh` (no
dependency on `errors.json` at all — `error_ref` is a bare optional string) and any new hook that
reads `errors.json` for cross-linking must `[ -f specs/errors.json ] || <skip gracefully>` before
any `jq` read, mirroring the pattern `events-query.sh` itself already uses for the absent-store
case.

Minor unrelated doc inconsistency spotted (informational only, not in this task's scope): a
different doc, `context/standards/error-handling.md`, describes a `.agent-logs/errors.json` format
that does not match the actual `specs/errors.json` convention used by the `error-handling.md`
*rule*. Not touched here; worth a future doc-lint pass.

### 8. Pre-existing count drift in `EXTENSION.md` (adjacent to this task's required sync)

`EXTENSION.md`'s summary table currently states `hooks | 11` while `manifest.json`'s
`provides.hooks` array has 16 entries (`validate-no-task-references.sh` and several
`wezterm-*`/`validate-*` hooks added since the table was last updated). Since task 870 must touch
this exact table row anyway (to reflect the new hook(s) it adds), correcting the pre-existing
count in the same edit is low-cost and consistent with how task 869 fixed the analogous
`scripts | 27 -> 52` drift.

## Decisions

- **Instrumentation lives in `skill-base.sh`, not in a wrapper script**: adding a
  `date +%s.%N` timer + one `events-append.sh` call directly inside each of the four functions is
  simpler and more legible than introducing a generic "instrument this function" helper, given
  there are exactly four call sites and their bodies already differ (some update status, some
  only call the extension hook).
- **`orchestrator-postflight.sh` gets exactly one new event emission** (at Stage 6, where `status`
  is already resolved), not one per stage — that script already has 10 documented stages and
  adding an event per stage would be noisy; the single success/blocker/deviation event at the
  point status is known is the highest-signal point.
- **Two new hook scripts, not one monolith**: a `PostToolUse` events logger (content-precise,
  triggered on `.return-meta.json`/`errors.json` writes) and a `Stop`/`SubagentStop` events logger
  (marker + message-pattern based) are different enough in their correlation strategy that
  separate single-responsibility scripts (matching the existing one-hook-one-job convention:
  `validate-plan-write.sh` vs `validate-meta-write.sh` vs `validate-state-sync.sh` all being
  separate despite similar stdin-parsing boilerplate) are more maintainable than one hook handling
  three Claude Code hook types.
- **New hooks are always non-blocking and never emit a `decision` field** — every event-store
  write is wrapped in `|| true`/`2>/dev/null` and the hook always echoes `{}` (or an
  `additionalContext` at most, never `"decision": "block"`), consistent with every existing hook
  in this directory except the two whose entire purpose IS to block (`guard-destructive-git.sh`,
  `subagent-postflight.sh`'s loop-guard branch).
- **`root-files/settings.json` is the wiring target of record**; `merge-sources/settings-hooks.json`
  is optional/secondary given its demonstrated staleness (Finding 5).

## Risks & Mitigations

- **Performance overhead on every hook fire**: `events-append.sh` shells out to `jq` and takes a
  `flock`. `PostToolUse` fires on every matching tool call. Mitigation: keep the `PostToolUse`
  hook's early-exit path (path/pattern match before any `jq`/lock work) as cheap as the existing
  `validate-plan-write.sh` pattern (`~1ms` for non-matching paths per its own comment) — only pay
  the `events-append.sh` cost for the narrow `.return-meta.json`/`errors.json` match.
- **`flock` contention** if a `PostToolUse` event write and a concurrent skill-base.sh lifecycle
  event write race on `specs/.events.lock` — already handled by `events-append.sh`'s own
  `flock -x`; no additional locking needed in the callers.
- **Absent `specs/errors.json`**: every new read path must check `[ -f specs/errors.json ]` before
  `jq`, matching `events-query.sh`'s own absent-store tolerance. Never treat this as fatal.
- **`.return-meta.json` already deleted by the time a `Stop`/`SubagentStop` hook fires**:
  `skill_cleanup`/`orchestrator-postflight.sh` Stage 10 removes it as part of the SAME turn's
  postflight, generally before Claude "stops" — so a `Stop` hook cannot rely on reading it. This is
  exactly why the `PostToolUse` hook (which fires at Write time, before cleanup) is the correct
  place for `.return-meta.json`-derived events, while `Stop`/`SubagentStop` hooks should rely on
  marker files / message pattern-matching only (Finding 6), not on re-reading metadata.
- **Double-counting**: `SubagentStop` can fire multiple times per subagent turn while
  `subagent-postflight.sh`'s loop guard forces continuation (up to `MAX_CONTINUATIONS=3`). A naive
  events-logger hook added to the same array would emit duplicate milestone events on each fire.
  Mitigation: gate the new hook's emission on the same "final stop" condition
  `subagent-postflight.sh` uses (marker absent, i.e. postflight already completed and cleaned up)
  rather than "marker present" — or accept one milestone event per loop iteration and let
  `category=milestone` + `event_type=subagent_stop` absorb the redundancy (downstream consumers can
  dedupe by `session_id`+`checkpoint` if needed). Recommend documenting this as an explicit,
  accepted trade-off in the plan rather than over-engineering de-duplication logic into the hook.
- **Non-JSON or malformed `.return-meta.json`/`errors.json` at PostToolUse time** (write may be
  mid-flight or the file may be transiently invalid): guard every read with
  `jq empty "$file" 2>/dev/null || exit 0` before extracting fields, matching the existing
  `skill_read_metadata` guard in `skill-base.sh`.

## Context Extension Recommendations

- **Topic**: Hook-to-event-store wiring pattern (PostToolUse content-read vs Stop marker-file
  correlation) is a reusable pattern not yet documented outside this report.
- **Gap**: `events-format.md` documents the *schema* but not *how a hook should source
  session_id/task without native Claude Code support*. A short "Emitting Events from Hooks" section
  (or a new `context/patterns/hook-event-correlation.md`) capturing Finding 6's three correlation
  strategies would help future hook authors (e.g. a future `/distill` consumer or a `--lit`
  literature-access event) avoid re-deriving this.
- **Recommendation**: add this as a follow-up documentation task after 870's implementation lands,
  rather than folding it into 870 itself (870's `file_scope` does not include a new
  `context/patterns/` file).

## Appendix

- Files read in full: `agent-system/extensions/core/scripts/skill-base.sh`,
  `orchestrator-postflight.sh`, `events-append.sh`, `events-query.sh`, `events-format.md`,
  `events-schema.json`, `command-gate-in.sh`, `command-gate-out.sh`, `manifest.json`,
  `root-files/settings.json`, `merge-sources/settings-hooks.json`, hooks:
  `log-session.sh`, `post-command.sh`, `subagent-postflight.sh`, `memory-nudge.sh`,
  `claude-stop-notify.sh`, `wezterm-preflight-status.sh`, `wezterm-task-number.sh`,
  `validate-state-sync.sh`, `validate-plan-write.sh`, `validate-meta-write.sh`,
  `error-handling.md` (rule), `return-metadata-file.md`.
- Commands run: `jq '.provides.hooks'`, `jq '.hooks'` across all `agent-system/extensions/*/manifest.json`,
  `grep -rn session_id`, `grep -rln agent-logs`, `test -f specs/errors.json`.
- 869 summary reviewed: `specs/869_unified_event_reflection_store/summaries/01_event-store-plumbing-summary.md`.
