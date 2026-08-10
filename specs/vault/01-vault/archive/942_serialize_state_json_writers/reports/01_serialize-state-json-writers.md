# Research Report: Serialize specs/state.json Writers

- **Task**: 942 - Serialize every specs/state.json writer through one mutex-guarded helper
- **Started**: 2026-07-28T21:15:00Z
- **Completed**: 2026-07-28T22:00:54Z
- **Effort**: Large (single-session research; implementation likely spans 4-6 plan phases)
- **Dependencies**: None declared; see Findings/Ordering for a soft build-order note against the sibling session-scoping task in this topic
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/scripts/{update-task-status,orchestrator-postflight,manage-topics,skill-base,reconcile-task-status,reconcile-artifacts,archive-task,orchestrate-predispatch-review,task-lock,generate-todo,test-task-lock-reap}.sh`
  - Codebase: `agent-system/extensions/core/commands/{implement,review,plan,research}.md`, `skills/skill-orchestrate/SKILL.md`, `scripts/command-gate-in.sh`, `scripts/command-gate-out.sh`
  - Codebase: `agent-system/extensions/core/manifest.json`, `specs/state.json` (task 942/943/944/945/946 descriptions)
  - Docs: `docs/guides/creating-skills.md`, `docs/architecture/architecture-spec.md` (skill-base.sh function inventory)
- **Artifacts**: `specs/942_serialize_state_json_writers/reports/01_serialize-state-json-writers.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

## Executive Summary

- The nine-writer / two-inline-command baseline **re-verified accurate at the script level**, but the actual number of distinct read-modify-write *sites* is materially higher: `orchestrator-postflight.sh` alone has ~6 internal write sites (2 of them raw Python3 in-place writes with **zero** atomicity, not even a temp file), and `skill-base.sh` has 4 internal sites, two of which (`skill_increment_artifact_number`, `skill_propagate_memory_candidates`) are **orphaned dead code** — never called — while `orchestrator-postflight.sh` reimplements the identical logic inline instead of calling them.
- **New defect found beyond the baseline**: `archive-task.sh`'s fixed temp path (`specs/state.json.tmp`) is byte-identical to `commands/review.md`'s inline task-creation write's temp path (also `specs/state.json.tmp`) — a concrete, previously-unnamed collision pair in the "shared fixed temp path" corruption channel (baseline's Section C enumerated three path groups but missed this one).
- **New defect found beyond the baseline**: `skill-base.sh`'s `skill_propagate_memory_candidates` (and `orchestrator-postflight.sh`'s inline duplicate of it) interpolates memory-candidate JSON into a Python triple-quoted string literal — the exact fragility pattern `orchestrator-postflight.sh`'s own Stage 7d comment says was deliberately avoided for `reflection` via `jq --argjson`. Converting these two sites to the new jq-based helper fixes this as a side effect.
- `task-lock.sh`'s **scope-mutex** (`scope-acquire`/`scope-release`) already implements the fail-closed + owner-token-verified release pattern the task wants generalized; its **task-level** `release` (`cmd_release`) is the one that skips ownership verification, exactly as the baseline states.
- Verified **safe to add** an ownership check to `cmd_release`: every current caller (`command-gate-out.sh`, and the three multi-task batch loops in `implement.md`/`plan.md`/`research.md`/`skill-orchestrate/SKILL.md`) passes the **identical** `session_id` string at release that it used at acquire — no caller uses a differently-suffixed id at release time.
- Sibling task 943 (session-scoping orchestration metadata, same `orchestration-concurrency` topic) has **no file_scope overlap** with 942 today and no `dependencies[]` edge in either direction; recommend a soft build-order note only (see Recommendations), not a hard edge.

## Context & Scope

Re-measurement scope is exactly this task's `file_scope`: the nine core scripts, `commands/implement.md` + `commands/review.md` (their `specs/state.json` write sites only — `review.md` also writes a *separate* file, `specs/reviews/state.json`, which is out of scope), `task-lock.sh`, `generate-todo.sh`, and the two context pattern docs. A repo-wide grep also surfaced dozens of extension `SKILL.md` files (web, cslib, memory, present, python, typst, lean, latex, nix, nvim, z3, founder, epidemiology, formal, literature) with their own inline `jq ... > specs/tmp/state.json && mv ...` or `/tmp/state.tmp` write patterns. These are **explicitly out of file_scope** for 942 and are noted only as a follow-up recommendation, not designed here.

## Findings

### A. Writer inventory (re-measured)

Confirmed at the **script** level, all nine still exist with the claimed mutex posture:

| Script | Mutex today | Internal RMW sites (re-measured) |
|---|---|---|
| `update-task-status.sh` | Yes (`acquire_state_mutex`/`release_state_mutex`, guest-mode via `SCOPE_MUTEX_HELD`) | 1 (`update_state_json`, symbol) |
| `orchestrator-postflight.sh` | Yes (own `scope_token` bracket, Stages 7-8a) | ~6: Stage 7a (`next_artifact_number`, python3 **no temp file**), Stage 7b (delegates to `skill_propagate_completion_summary`, 2 sites), Stage 7c (`memory_candidates`, python3 **no temp file**, fragile triple-quote interpolation), Stage 7d (`reflection`, jq/mv), Stage 8 (artifact link, two-step jq/mv) |
| `skill-base.sh` | No | 4: `skill_propagate_completion_summary` (2 sites), `skill_link_artifacts` (2 sites) — plus 2 **orphaned, uncalled** functions `skill_increment_artifact_number` / `skill_propagate_memory_candidates` (python3, no temp file, string-interpolated) |
| `manage-topics.sh` | No | 2 (`add`, `set` subcommands) |
| `reconcile-task-status.sh` | No | 2 (both inside `link_artifact`'s two-step jq) |
| `reconcile-artifacts.sh` | No | 1 (append-only artifact registration) |
| `archive-task.sh` | No | 1 (`del(...)` removal from `active_projects`; the earlier archive-file write targets a *different* file, `archive/state.json`, and is out of this task's `specs/state.json` scope) |
| `orchestrate-predispatch-review.sh` | No (deliberately, by its own header comment — see below) | 1 (`--repair` only; default report-only path never writes) |
| `commands/implement.md` | No | 1 (Step 4, completion_summary) |
| `commands/review.md` | No | 2 (task-creation append at Step 4; `active_goal` write at Step 6-equivalent) — plus 2 more against `specs/reviews/state.json`, out of scope |

`orchestrate-predispatch-review.sh`'s own header comment (symbol: "State-write atomicity") already documents that it deliberately skips the mutex because it is "direct-invocation-only, never called from a live or automated path" — this reasoning predates task 942 and is superseded by the "convert ALL nine writers" deliverable; it must still be converted.

### B. Fail-open on timeout (confirmed, unchanged)

- `acquire_state_mutex` (`update-task-status.sh`, symbol) and the inline mutex block in `orchestrator-postflight.sh` (symbol: "specs/.scope-lock mutex: brackets Stages 7 through 8a") both log a `WARNING` and **proceed unserialized** on a `task-lock.sh scope-acquire` timeout — confirmed fail-open exactly as baseline states.
- Contrast confirmed: `task-lock.sh`'s `cmd_scope_acquire` itself (the primitive both callers wrap) already `return 2`s (fail-closed) on its own internal timeout inside `acquire_named_mutex`. The fail-open behavior is layered on **top** of a fail-closed primitive by the two *callers* choosing to swallow the non-zero return — the new helper should stop swallowing it.

### C. Shared fixed temp paths (confirmed, with one addition)

Re-measured groupings, all still present:
- `specs/tmp/state.json` — `orchestrator-postflight.sh` (Stages 7d, 8), `reconcile-task-status.sh` (both sites), `skill-base.sh` (all 4 sites), `commands/implement.md` (Step 4).
- `specs/tmp/state-reconcile.json` — `reconcile-artifacts.sh` only (not shared with anything else; lower risk).
- `$TMP_DIR/state.json.tmp` (= `specs/tmp/state.json.tmp`) — `manage-topics.sh`, `update-task-status.sh`.
- **New**: `specs/state.json.tmp` (note: directly under `specs/`, not `specs/tmp/`) — `archive-task.sh` (symbol: `"${STATE_FILE}.tmp"`) **and** `commands/review.md`'s task-creation write (Step 4) use the byte-identical literal path. Baseline's Section C did not enumerate this pair.
- `orchestrate-predispatch-review.sh --repair` already uses its own script-namespaced temp (`specs/tmp/orchestrate-predispatch-review.state.tmp`) — not part of the shared-path collision channel, though it still lacks the mutex.
- **New, more severe than a shared-temp collision**: `orchestrator-postflight.sh` Stage 7a/7c and `skill-base.sh`'s two orphaned functions write via Python3 `json.load`/`json.dump` **directly back to `specs/state.json`**, with no temp file and no `mv` at all. A single interrupted write (not even requiring a second process) can leave `specs/state.json` truncated/corrupt. These four sites need the same `mktemp` + `jq empty` + `mv` treatment as every jq-based writer, expressed as jq transforms (`.next_artifact_number = (.next_artifact_number // 1) + 1`, and `.memory_candidates += $new` via `--argjson`) rather than Python.
- Several `rm -f` EXIT traps target these shared paths unconditionally (e.g. `update-task-status.sh`'s `cleanup()`, `manage-topics.sh`'s bare `trap`), confirming the cross-process staging-file corruption channel is real and independent of mutex coverage.

### D. `task-lock.sh release` ownership (confirmed, and verified safe to fix)

- `cmd_release` (symbol) takes `session_id` as its second positional argument but never reads it — it unconditionally `rm -rf`s the `.lock` directory. Confirmed exactly as baseline states.
- `cmd_acquire` (symbol) already branches on `holder_session = session_id` **first**, before any staleness check, and same-session re-entry returns 0 immediately without touching heartbeat-age logic — this is the load-bearing property to preserve.
- The scope/commit mutex releases (`cmd_scope_release`, `cmd_commit_release`) are **already** owner-token-verified: they compare a `token` (not raw `session_id`) written at acquire time against the value passed to release, WARN-and-no-op on mismatch, and always `return 0` (never fail a caller's cleanup). This is the exact precedent to mirror for `cmd_release`, using `session_id` (the only identity `cmd_acquire`/`cmd_release`'s existing interface carries) as the comparison key instead of a token.
- **Caller audit (all 5 call sites of `task-lock.sh release`)** — every one passes the *same* session_id string used at the matching acquire; an ownership check breaks none of them:
  - `command-gate-out.sh` (symbol: `bash .claude/scripts/task-lock.sh release "$task_number" "$session_id"`) — mirrors `command-gate-in.sh`'s acquire, same `$SESSION_ID`.
  - `commands/implement.md`, `commands/plan.md`, `commands/research.md` (multi-task loops) — all release with `"${batch_session_id}_${task_num}"`, matching their own acquire call with the identical string.
  - `skills/skill-orchestrate/SKILL.md` (multi-task loop) — releases with `"${session_id}_${task_num}"`, matching its own acquire.

### E. `generate-todo.sh` torn view (confirmed characterization)

- `generate-todo.sh` already does an atomic write of its own **output** (`mktemp -p ... todo.XXXXXX` then `mv`, symbol). The hazard is not a torn *read* of `state.json` (a `jq`/`cat` read against a file that is only ever replaced via `mv` gets a consistent whole-file snapshot, old or new, never partial).
- The real hazard is a **lost-update on TODO.md itself**: two regenerations can race such that the one reading an *older* `state.json` snapshot finishes its `mv` into `TODO.md` *after* the one reading the newer snapshot, leaving `TODO.md` stale relative to `state.json` until the next regeneration happens to fire. Baseline's fix (run the regen inside the same mutex as the write that triggered it) closes this by making "write state.json, then regen TODO.md" one atomic unit relative to other writers.

### F. `workflow-active` singleton (confirmed)

- Single writer: `update-task-status.sh` preflight branch (symbol: `"Write workflow-active marker on preflight"`), writing to the fixed path `$SCRIPT_DIR/../tmp/workflow-active` (i.e. `.claude/tmp/workflow-active`).
- Three consumers, all keyed on the bare fixed path with no session component: `hooks/claude-stop-notify.sh` (reads it to suppress mid-workflow Stop fires), `hooks/wezterm-preflight-status.sh` (deletes it unconditionally on ESC-cancel/non-lifecycle cleanup), `hooks/events-log-lifecycle.sh` (reads it as a fallback signal).
- Confirmed global-singleton hazard: any concurrently-active second session's preflight overwrites the marker's `task_number`/timestamp content, and `wezterm-preflight-status.sh`'s unconditional `rm -f` deletes it regardless of which session's workflow it belongs to.

### Ordering note vs. sibling task 943

- `specs/state.json` shows task 943 ("Session-scope batch-level orchestration metadata and verify session_id on read") in the same `orchestration-concurrency` topic, currently `researching`, with `dependencies: []` in both directions relative to 942.
- No `file_scope` overlap exists between the two tasks today: 943's targets (`specs/.orchestrator-multi-state.json`, `specs/.return-meta-multi.json`, handoff-reader session_id checks) are files distinct from `specs/state.json` and from 942's `file_scope` list.
- Recommend a **soft build-order preference, not a hard `dependencies[]` edge**: land 942's `state-write.sh` first, since 943's singleton-file fixes could reuse the same `mktemp` + fail-closed-mutex-acquire idiom this task establishes, avoiding a second independent invention of the same pattern. This is advisory only — 943's own planning is out of scope here.

## Decisions

- **Interface shape**: the helper must accept an **arbitrary jq filter** (plus `--arg`/`--argjson` bindings), not a narrow "task_number + field" API. Verified necessary because caller transforms vary structurally: single-task field updates (`update-task-status.sh`), top-level array mutation (`manage-topics.sh`'s `active_topics`), and multi-candidate bulk updates (`orchestrate-predispatch-review.sh --repair`'s `$cands`-scoped `|=`) are all real, current shapes.
- **Standalone script, not a sourced function**: the dominant convention in this codebase for single-purpose state mutation is a standalone invocable script (`task-lock.sh`, `generate-todo.sh`, `update-task-status.sh`, `manage-topics.sh`), callable uniformly via `bash .claude/scripts/state-write.sh ...` from both shell scripts (subprocess call) and markdown command bash blocks (no `source` needed across separate Bash-tool invocations). `skill-base.sh`'s sourced-function style exists because it bundles many distinct lifecycle stages in one process, not because a single-purpose write needs sourcing.
- **Fail-closed on mutex timeout**: adopt `task-lock.sh`'s `cmd_scope_acquire` return-2 precedent unconditionally; the two current callers' `WARNING`-and-proceed fallback is removed, not preserved as an option.
- **Reentrancy**: honor `SCOPE_MUTEX_HELD=1` exactly as `update-task-status.sh`'s `acquire_state_mutex` already does — skip the nested acquire and run as a guest inside an outer holder's critical section.
- **`cmd_release` ownership check**: add a `session_id` comparison against `holder.json`'s `session_id` field, WARN-and-no-op (never force) on mismatch, always `return 0` — mirroring `cmd_scope_release`'s token-mismatch handling, substituting `session_id` for `token` since that is the identity `cmd_acquire`/`cmd_release`'s existing CLI already carries.
- **`workflow-active`**: make the marker per-session, either as a `{session_id}`-suffixed filename or a small JSON registry keyed by session_id under the same `.claude/tmp/` directory; whichever form is chosen, all three consumers (`claude-stop-notify.sh`, `wezterm-preflight-status.sh`, `events-log-lifecycle.sh`) must be updated in the same change, since a partial conversion (e.g. writer updated but `wezterm-preflight-status.sh`'s unconditional `rm -f` left unchanged) reintroduces the same cross-session deletion hazard.

## Recommendations

1. **Consolidate before converting**: delete `skill-base.sh`'s two orphaned functions (`skill_increment_artifact_number`, `skill_propagate_memory_candidates`) rather than converting dead code, and instead convert `orchestrator-postflight.sh`'s Stage 7a/7c inline duplicates (the only call sites that actually execute). This shrinks the real conversion surface by two sites and removes a maintenance trap (two logic copies that could silently diverge).
2. **Build `state-write.sh` first, standalone**, implementing exactly: `task-lock.sh scope-acquire` (bounded retry, fail-closed return-2 on timeout, skip if `SCOPE_MUTEX_HELD=1`) → `mktemp` a private temp under `specs/tmp/` → apply caller's jq filter/bindings → `jq empty` validate → `mv` into place → optional `generate-todo.sh` regen (still inside the mutex) → `task-lock.sh scope-release`.
3. **Convert in this order** (lowest-risk/most-isolated first): `manage-topics.sh` → `reconcile-artifacts.sh` → `archive-task.sh` (state.json `del()` site only) → `reconcile-task-status.sh` → `orchestrate-predispatch-review.sh --repair` → `skill-base.sh`'s two live functions → `update-task-status.sh` (already has the closest analog of the target mutex logic, so this becomes mostly a call-site swap) → `orchestrator-postflight.sh`'s remaining Stage 7a/7b(indirect)/7c/7d/8 sites → the two inline command-file sites (`implement.md` Step 4; `review.md`'s two `specs/state.json` sites, leaving its separate `specs/reviews/state.json` sites untouched).
4. **`task-lock.sh` changes**: add the `cmd_release` ownership check (Decisions above); no change needed to `cmd_scope_acquire`/`cmd_scope_release`/`cmd_commit_acquire`/`cmd_commit_release`, which already match the target fail-closed + owner-verified pattern.
5. **`generate-todo.sh`**: no internal change required (its own output write is already atomic); the fix is entirely in caller discipline — every writer's regen call must happen before the new helper's `scope-release`, not after.
6. **`workflow-active`**: convert the write (`update-task-status.sh` preflight) and all three consumers together in one phase; do not split across phases, per the Decisions note on partial-conversion risk.
7. **Deploy path**: add `state-write.sh` to `manifest.json`'s `provides.scripts` array (alphabetically after `skill-base.sh` / before `task-lock.sh`, matching the existing sorted list). This is necessary but **not sufficient** for reaching an already-deployed repo — the documented gap in `.claude/rules/no-task-references-in-deliverables.md`'s Enforcement section (headless "Load Core" sync skips `copy_scripts` for already-loaded extensions) applies here identically to how it applied to `scripts/lib/task-reference-patterns.sh`; plan for the same one-off direct-loader-primitive workaround used there, and flag it explicitly as a manual step in the implementation plan rather than assuming `/meta`'s normal sync covers it.
8. **Verification**: build `scripts/test-state-write-concurrency.sh` following `test-task-lock-reap.sh`'s isolated-temp-root precedent exactly (copy `state-write.sh`, `task-lock.sh`, `deploy-root-guard.sh` into a throwaway `$TMPROOT/.claude/scripts/`, fixture a minimal `specs/state.json` with 2+ task entries). Two cases:
   - **No lost update**: launch two `state-write.sh` invocations backgrounded (`&`) targeting *different* task entries, `wait` on both, assert both mutations are present in the final file (deterministic interleaving via a short injected `sleep` inside a test-only hook point, or by controlling mutex-hold duration through the fixture's own transform complexity — follow whatever mechanism `test-task-lock-reap.sh`'s no-sleeping epoch-arithmetic convention analogously offers for a two-process race, since that suite avoids wall-clock sleeps for its own timing).
   - **Staging-file isolation**: launch one process that intentionally fails after claiming its `mktemp` temp (simulating an EXIT-trap cleanup) and a second concurrent process also mid-write; assert the second process's temp file is untouched by the first's trap, proving each process's cleanup trap is scoped to its own `mktemp` path, not a shared fixed name.

## Risks & Mitigations

- **Risk**: converting `orchestrator-postflight.sh`'s Stage 7a/7c from Python3 in-place writes to jq changes the exact JSON key ordering / float-vs-int formatting `next_artifact_number` and `memory_candidates` currently get from `json.dump(..., indent=2)`. **Mitigation**: diff a sample state.json before/after conversion in the implementation phase; jq's default `--indent 2` output should match closely enough that no downstream reader (which all use `jq`, never raw string diffing) is affected.
- **Risk**: fail-closed mutex acquisition on `update-task-status.sh`/`orchestrator-postflight.sh` changes existing behavior under real contention from "slow but eventually succeeds" to "hard failure requiring caller retry." **Mitigation**: this is the explicit, accepted trade-off the task specifies (baseline Section B); ensure the new helper's non-zero exit is surfaced loudly enough (matching `cmd_acquire`'s `ABORT:`-prefixed pattern) that callers/orchestration retry logic can react rather than silently stalling.
- **Risk**: the `cmd_release` ownership check could, in principle, strand a lock if a future caller ever passes a different session_id at release than at acquire (unlike today's five verified-consistent call sites). **Mitigation**: WARN-and-no-op (never force-refuse) mirrors `cmd_scope_release`'s existing precedent exactly, so a future mismatched caller degrades to "lock not released, logged loudly" rather than a hard failure — consistent with `cmd_release`'s existing "release must never fail a caller's cleanup path" contract.
- **Risk**: the deploy-mechanism gap (manifest.json addition not reaching an already-deployed `.claude/scripts/`) could cause the implementation to test-pass in the source-store checkout while silently not deploying to this very repo's own `.claude/scripts/`. **Mitigation**: explicit manual copy/loader-primitive step, called out as its own plan phase (see Recommendation 7), not left implicit.

## Context Extension Recommendations

- **Topic**: state.json write conventions. **Gap**: no single context file documents "every state.json writer must go through `state-write.sh`" as a standing convention (analogous to how `context/patterns/task-lock.md` documents the lock protocol). **Recommendation**: after implementation, add a short section to `context/patterns/multi-task-operations.md` (which already references the pre-fix race) describing the converged helper, or a new `context/patterns/state-write.md` mirroring `task-lock.md`'s structure.

## Appendix

- Search queries/greps used: repo-wide `grep -rln state\.json` across `agent-system/extensions/`; targeted `grep -n` for `mv.*state\.json|state\.json.*tmp` scoped to the nine core scripts + two command files; `grep -n` for `workflow-active`, `scope-acquire`, `scope-release`, `cmd_release`; `jq` queries against `specs/state.json` for tasks 942-946 (`orchestration-concurrency` topic).
- Full extension-wide inline-write survey (out of `file_scope`, listed for future follow-up only): `web`, `cslib`, `memory`, `present`, `python`, `typst`, `lean`, `latex`, `nix`, `nvim`, `z3`, `founder`, `epidemiology`, `formal`, `literature` extension `SKILL.md` files all contain their own inline `jq ... > .../state.json.tmp && mv ...` or `/tmp/state.tmp` patterns against `specs/state.json`, none serialized. Not designed here; recommend a separate follow-up task once the core helper exists, so extension skills can be converted to call it too.
