# Implementation Plan: Task #885

- **Task**: 885 - Enable and verify passive signal capture
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours (agent) + user-owned manual regeneration (out of agent effort)
- **Dependencies**: 874 (self-sync guard removal — CONFIRMED COMPLETE, commit dc6d5e450)
- **Research Inputs**: reports/01_enable-verify-passive-signal-capture.md
- **Artifacts**: plans/01_passive-signal-capture-deploy.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The events/reflection store landed in `agent-system/extensions/core/` but was never deployed to
nvim's gitignored `.claude/` tree, and every call site failed silently via `|| true`, hiding the
gap for a full day. Research settled the central feasibility question: there is **no headless/CI
path** to trigger the `<leader>al` regeneration that would deploy it (`execute_sync` is a
module-local closure with no exported entry point; `vim.fn.confirm()` is unconditional). Therefore
this task **cannot complete end-to-end today and will finish [PARTIAL]**. This plan lands every
deliverable that does NOT depend on regeneration — the observable-failure fix (scope 2), the
nullable `cwd` schema field (scope 5, `cwd` only), and the deploy-drift/completeness gate in
`check-extension-docs.sh` (scope 6) — each verified today by something actually run and observed
against the live, still-stale tree. It then cleanly hands off the genuinely gated remainder: the
manual `<leader>al` regeneration (scope 1) and the dotfiles-repo telemetry/retention settings
(scope 3/4), with exact, copy-pasteable instructions.

**Definition of done for the landable scope (Phases 1-4)**: source-store edits committed, each
verified by a run-and-observe check that did not exist or behaved differently before the edit.
**Definition of done for the gated scope (Phases 5-6)**: precise, user-executable handoff
documented; task honestly marked [PARTIAL] with the two [BLOCKED] phases enumerated. No phase
claims event flow is verified today.

### Research Integration

The research report is integrated wholesale:
- **Feasibility (settled)**: no headless bypass; the confirm dialog is mandatory for every repo.
  This plan does NOT plan a bypass, monkeypatch, or synthetic re-implementation of `execute_sync`.
- **Scope 2 call sites (verified)**: 4 in `skill-base.sh`, 2 in `orchestrator-postflight.sh`
  (already partially observable — the pattern to generalize), 2 in `events-log-lifecycle.sh`, 2 in
  `events-log-artifact.sh`.
- **Scope 5 (settled)**: add nullable `cwd` ONLY; derive "repo" from `cwd` at query time; do NOT
  add `cc_session_id` (sibling design still unfrozen).
- **Scope 6 (proven live)**: the doc-lint gate already reports `core: FAIL` for `skill-base.sh`/
  `orchestrator-postflight.sh` drift, but silently info-skips never-deployed
  `events-append.sh`/`events-query.sh`. That inversion ("never deployed" < "deployed but drifted")
  is the structural hole; its before/after behavior is observable today.
- **Scope 3/4 (settled home)**: both belong in `~/.dotfiles/config/claude/settings.json`
  (Home-Manager-managed user-level settings), NOT this repo. `cleanupPeriodDays: 0` DISABLES
  persistence (issue #23710); recommend `365`, never `0`. This task does not edit dotfiles.

### Prior Plan Reference

No prior plan. A prior planning session was killed by a session limit at the very start; no plan
file existed. This plan starts fresh.

### Roadmap Alignment

No `roadmap_flag` in the delegation context; roadmap not consulted. This task advances passive
signal capture / telemetry infrastructure for the agent system.

## Goals & Non-Goals

**Goals**:
- Replace the `|| true` silent-fail idiom at all 10 verified sites with an observable-but-non-fatal
  signal (scope 2), verified today.
- Add a single nullable `cwd` field to `events-schema.json` and thread `--cwd` through
  `events-append.sh` and the two hooks; derive "repo" in `events-query.sh` (scope 5), verified today.
- Extend `check-extension-docs.sh` so `core`-extension never-deployed scripts/hooks are FAIL (not
  info-skip), additively with respect to the concurrent memory-extension manifest change (scope 6),
  verified today against the still-stale tree.
- Document the no-headless-regeneration constraint in the source store and produce a precise,
  copy-pasteable user handoff (regeneration keystrokes + dotfiles snippet) for the gated remainder.
- Finish honestly [PARTIAL] with the two [BLOCKED] phases clearly enumerated.

**Non-Goals**:
- Any headless bypass, monkeypatch, or re-implementation of `execute_sync` / the confirm dialog.
- Editing `.claude/**` (gitignored, disposable, wiped on regeneration) — ALL edits target
  `agent-system/extensions/**`.
- Editing `~/.dotfiles/**` (scope 3/4 is a handoff, not an edit from this task).
- Adding `cc_session_id` to the schema (sibling design unfrozen).
- Adding a `repo` field to `manifest.provides.scripts` in a way that conflicts with the concurrent
  memory-extension manifest change.
- Claiming event flow is verified — it is doubly gated (manual regeneration, then accumulated real
  usage over time).
- Staging or reverting the pre-existing uncommitted edits to
  `lua/neotex/plugins/editor/which-key.lua` and
  `lua/neotex/plugins/tools/himalaya/utils/cli.lua`.
- Touching `specs/state.json` or `specs/TODO.md` (sibling tasks run concurrently); all `specs/`
  writes are confined to this task's directory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edits land in `.claude/**` and are silently wiped on next regeneration | H | M | Every phase's file list is under `agent-system/extensions/**`; verification runs source-store copies, not deployed copies. Reject any diff touching `.claude/**`. |
| Observable-failure signal becomes fatal to the enclosing operation (a hook emitting a non-`{}` decision, or a lifecycle stage aborting a skill) | H | M | The wrapper MUST always return 0 to its caller; verification explicitly asserts the enclosing script still exits 0 when the helper is absent. |
| Scope 3/4 telemetry/retention edits land in `root-files/settings.json` by habit (it is in `file_scope`) | H | M | Research settled the home is dotfiles; this plan hands off the exact snippet and forbids editing `root-files/settings.json` for telemetry/cleanup. |
| `check-extension-docs.sh` drift-check extension collides with the concurrent memory-extension `manifest.provides.scripts` addition | M | M | The drift check operates on the CORE extension's deploy status (`routing_exempt: true`), a separate concern from registering memory's scripts. Keep the change additive; do not modify shared manifest keys. |
| Premature `cc_session_id` adoption freezes an unfrozen sibling design | M | L | Schema change is `cwd`-only; "repo" is derived at query time, not stored. |
| Reader mistakes the manual/gated phases for agent-completable | H | M | Phases 5-6 marked [BLOCKED]; task marked [PARTIAL]; no phase verifies event flow today. |
| `check-extension-docs.sh` `REPO_ROOT` auto-detect miscomputes when run from the source-store path | L | M | Flagged as a known latent bug; verification invokes with an explicit `REPO_ROOT=$(pwd)`; optional one-line fix noted but not required. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 4 | -- |
| 2 | 2 | 1 |
| 3 | 5 | 1, 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 1, 3, and 4 touch disjoint files.
Phase 2 shares the two events hooks with Phase 1, so it follows Phase 1 to avoid edit conflicts.
Phases 5-6 are user-owned/[BLOCKED] and gated behind the landable source-store edits.

---

### Phase 1: Observable-but-non-fatal failure signal (scope 2) [COMPLETED]

**Goal**: Replace the `|| true` silent-fail idiom at all 10 verified sites so a missing/failing
`events-append.sh` helper produces an observable signal, while NEVER becoming fatal to the
enclosing skill lifecycle stage or hook.

**Design (concrete, per delegation instruction)**: Introduce one small shared shell helper (e.g.
`_events_append_observable`) that wraps the `events-append.sh` invocation. On the helper being
missing/non-executable, or on the helper itself exiting non-zero, it:
1. Emits a one-time-per-process stderr WARNING distinguishing "helper missing" from "helper present
   but failed (exit N)" — generalizing `orchestrator-postflight.sh`'s existing
   `... || echo "[postflight] WARNING: ... (non-blocking)" >&2` convention, which is the strictly
   better starting point than `skill-base.sh`'s bare `|| true`.
2. Writes a one-time drift/sentinel marker (e.g. under `.claude/tmp/`) so the failure is durable and
   surfaceable, not just a transient stderr line a user may not be watching.
3. **Always returns 0** to its caller — the enclosing lifecycle stage / hook decision is never
   affected. Hooks continue to emit their normal `{}` (or existing) decision; skill stages continue.

Choose the minimal viable version (stderr WARNING) if the sentinel adds risk, but the WARNING must
distinguish missing-vs-failed and must be non-fatal. Do not make any call site fatal.

**Tasks**:
- [x] Add the shared observable wrapper (define once; reuse at all sites) in a location sourced by
      both `skill-base.sh` and the hooks, or duplicate a tiny inline guard if sourcing is not clean.
      *(completed: chose the duplicate-inline-guard fallback — the 4 target files span sourced
      (skill-base.sh) and standalone (orchestrator-postflight.sh, 2 hooks) execution contexts with
      no existing shared-sourcing convention, so a small identical `_events_append_observable`
      function is duplicated in each of the 4 files rather than adding a 5th new script file that
      would also need manifest.json registration outside this task's edit-target scope.)*
- [x] `agent-system/extensions/core/scripts/skill-base.sh`: replace the 4 `|| true` sites
      (preflight, context_injection, verification, postflight). *(completed)*
- [x] `agent-system/extensions/core/scripts/orchestrator-postflight.sh`: generalize the 2 existing
      partially-observable sites to the shared pattern (main status event + reflection event).
      *(completed)*
- [x] `agent-system/extensions/core/hooks/events-log-lifecycle.sh`: replace the 2 internal sites
      (SubagentStop path, Stop path). *(completed: also removed an early
      `[ -x "$EVENTS_APPEND" ] || exit_success` bypass guard that would have short-circuited
      before the wrapper could ever signal a missing helper)*
- [x] `agent-system/extensions/core/hooks/events-log-artifact.sh`: replace the 2 internal sites
      (return_meta match, errors_json match). *(completed: same early-bypass-guard removal as
      events-log-lifecycle.sh)*
- [x] Verify (see Verification) with a controlled present-vs-absent helper harness. *(completed;
      also caught and fixed a real `set -e` correctness bug: the internal helper invocation was
      not protected by an `if`, so under `set -e`/`set -euo pipefail` a present-but-failing helper
      would abort the enclosing script before the wrapper could capture its exit code and return 0
      — exactly the kind of fatal-by-accident regression the plan's risk table flagged.)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify** (source store only):
- `agent-system/extensions/core/scripts/skill-base.sh` - 4 call sites + wrapper
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - 2 call sites
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` - 2 internal sites
- `agent-system/extensions/core/hooks/events-log-artifact.sh` - 2 internal sites

**Verification** (run and observe today; no regeneration needed):
- Point the wrapper at a PRESENT, executable stub `events-append.sh`: run the modified
  `skill-base.sh` stage(s) and each hook; observe normal behavior, no warning, enclosing exit 0.
- Point the wrapper at an ABSENT / non-executable helper path: run the same; observe the one-time
  stderr WARNING (correctly labeled "missing"), the sentinel marker written, and — critically —
  the enclosing script/hook STILL exits 0 (assert this explicitly; a non-zero exit here is a
  regression to reject).
- Point at a PRESENT helper that exits non-zero: observe the WARNING labeled "failed (exit N)",
  enclosing exit still 0.

---

### Phase 2: Nullable `cwd` schema field and threading (scope 5) [COMPLETED]

**Goal**: Add a single nullable `cwd` field to the event schema and thread it end-to-end, so
cross-repo federation can derive "repo" from `cwd` at query time — without storing a redundant
`repo` field and without adopting the unfrozen `cc_session_id`.

**Tasks**:
- [x] `agent-system/extensions/core/context/schemas/events-schema.json`: add a nullable `cwd`
      field (string, nullable; document it as the invoking working directory). Add `cwd` ONLY.
      *(completed)*
- [x] `agent-system/extensions/core/scripts/events-append.sh`: add a `--cwd` flag; when supplied,
      write it into the event object; when absent, write `null` (backward compatible).
      *(completed)*
- [x] `agent-system/extensions/core/hooks/events-log-lifecycle.sh`: capture `cwd` from the
      already-parsed hook stdin and pass `--cwd` to `events-append.sh`. *(completed: both
      SubagentStop and Stop paths)*
- [x] `agent-system/extensions/core/hooks/events-log-artifact.sh`: same — thread `--cwd` from stdin.
      *(completed: both return_meta and errors_json branches)*
- [x] `agent-system/extensions/core/scripts/events-query.sh`: derive "repo" as a computed value
      from `cwd` (e.g. basename of the git toplevel for that `cwd`) rather than reading a stored
      `repo` field. Keep it tolerant of `cwd: null` (older rows). *(completed: derived as
      basename(cwd) via pure jq rather than a per-row git-toplevel shell-out, to stay consistent
      with events-query.sh's native-jq streaming-filter design — documented as a deliberate
      simplification in events-format.md; added `--repo` filter and `by_repo` summary-counts
      aggregate)*
- [x] Update `agent-system/extensions/core/context/formats/events-format.md` if it enumerates
      fields, to document `cwd` (nullable) and the derived-repo query behavior. Do NOT document
      `cc_session_id`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1 (shares `events-log-lifecycle.sh` and `events-log-artifact.sh`; sequence to avoid
edit conflict)

**Files to modify** (source store only):
- `agent-system/extensions/core/context/schemas/events-schema.json`
- `agent-system/extensions/core/scripts/events-append.sh`
- `agent-system/extensions/core/scripts/events-query.sh`
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh`
- `agent-system/extensions/core/hooks/events-log-artifact.sh`
- `agent-system/extensions/core/context/formats/events-format.md` (if it enumerates fields)

**Verification** (run and observe today):
- Run `events-append.sh --cwd /some/path ...` and inspect the emitted JSONL line: it contains
  `"cwd": "/some/path"`; run without `--cwd` and confirm `"cwd": null`.
- Validate an emitted line against the updated `events-schema.json` (jq/ajv or a manual field
  check) — `cwd` present and nullable, `cc_session_id` absent.
- Run `events-query.sh` over a small fixture containing rows with and without `cwd`; confirm it
  derives a repo value for populated rows and does not error on `cwd: null` rows.

---

### Phase 3: Deploy-drift / completeness gate for core (scope 6) [NOT STARTED]

**Goal**: Extend `check-extension-docs.sh` so that for the `core` extension specifically
(identifiable via `routing_exempt: true`), a never-deployed script/hook is a FAIL, not an
info-skip — closing the "never deployed < deployed-but-drifted" inversion. Additive with respect to
the concurrent memory-extension manifest change.

**Tasks**:
- [ ] `agent-system/extensions/core/scripts/check-extension-docs.sh`: in `check_deployed_script_drift`
      (and analogous logic), treat "not deployed" as FAIL for the `core` extension (baseline,
      present in every `.claude/` tree by construction), while keeping the existing info-skip for
      optional extensions a repo may legitimately not have loaded.
- [ ] Add a drift/completeness check for `provides.hooks` (currently never iterated by any
      drift check) so the two events hooks' non-deployment is visible for core.
- [ ] Add a completeness check for `root-files/settings.json`'s hook-registration set relative to
      the deployed `.claude/settings.json` (currently entirely unchecked), so missing hook
      registrations (and the known duplicate `claude-stop-notify.sh` Stop-matcher artifact) become
      visible.
- [ ] Keep the change ADDITIVE: it operates on the CORE extension's deploy status only. Do NOT
      modify shared manifest keys; the concurrent memory-extension task's
      `manifest.provides.scripts` addition is a separate concern and must not conflict.
- [ ] (Optional, note-only) Flag the `REPO_ROOT` auto-detect latent bug when the script is invoked
      from its source-store path; a one-line guard is acceptable but not required.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify** (source store only):
- `agent-system/extensions/core/scripts/check-extension-docs.sh`

**Verification** (run and observe today against the LIVE, still-stale `.claude/` tree):
- Before the edit (baseline, already captured in research): `events-append.sh`/`events-query.sh`
  are info-skipped ("script not deployed, skipping drift check"), NOT failed.
- After the edit: run
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm
  the never-deployed core scripts/hooks now report FAIL (the info-skip lines are replaced by
  FAILs). This before/after delta is the phase's proof and requires no regeneration.
- Confirm the run does not error on, or interfere with, the memory extension's entries (additivity
  check).

---

### Phase 4: Document the no-headless constraint and produce the user handoff [NOT STARTED]

**Goal**: Prevent future retreading of the settled feasibility question, and produce a precise,
copy-pasteable handoff for the two genuinely gated items (manual regeneration; dotfiles telemetry/
retention). Landable today; no regeneration dependency.

**Tasks**:
- [ ] Add a short note to the source store (e.g.
      `agent-system/extensions/core/docs/guides/creating-extensions.md`, or a new
      `agent-system/extensions/core/context/patterns/` file) stating plainly that `<leader>al`'s
      "Load Core"/"Load All" sync has NO headless/CI equivalent and always requires a human
      `confirm()` selection — so future automation/CI-deploy-verification attempts don't retread
      this. Honor no-task-references-in-deliverables (no task numbers in this file).
- [ ] Write a durable handoff document under this task's directory (specs/ — task-number
      references allowed here):
      `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md`, containing:
      - The exact regeneration keystrokes and success criteria (Phase 5 content below).
      - The exact dotfiles snippet (Phase 5 content below).
- [ ] Verify the source-store note contains no task-number references and the handoff doc reproduces
      the exact snippet and keystrokes.

**Timing**: 0.5 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/docs/guides/creating-extensions.md` (or a new source-store
  `context/patterns/` file) - constraint note, no task numbers
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` (new; specs/ handoff artifact)

**Verification** (run and observe today):
- `grep -nE 'task [0-9]|tasks [0-9]' <the source-store note file>` returns no matches
  (no-task-references compliance).
- The handoff doc exists and contains both the keystroke sequence and the dotfiles snippet verbatim.

---

### Phase 5: Manual `<leader>al` regeneration handoff (scope 1) [BLOCKED]

**Goal**: Deploy the finished source-store edits into each repo's `.claude/` tree. USER-OWNED —
no agent/headless path exists.

**Blocked on**: a human performing the interactive `<leader>al` regeneration after Phases 1-4 land.
This phase is [BLOCKED], not skipped, and the task terminus is [PARTIAL].

**Exact procedure (per repo)**:
1. Open Neovim with cwd at the target repo root (nvim itself; then at least one other, e.g.
   `~/.dotfiles`, confirmed to have the identical undeployed gap).
2. Press `<leader>al` (normal mode).
3. Select the "Load All" entry (the `is_load_all` special row) and press Enter.
4. At the `vim.fn.confirm()` dialog, choose **"Sync all (replace existing)"** (button 1 / `&Sync
   all`) — **NOT** the default Cancel, and NOT "Add new only" (which would skip re-copying the
   already-stale `skill-base.sh`, `orchestrator-postflight.sh`, `settings.json`).
5. **What success looks like** (independently verifiable, do not trust self-report):
   - `ls .claude/scripts/events-append.sh .claude/scripts/events-query.sh` — both exist.
   - `ls .claude/hooks/events-log-artifact.sh .claude/hooks/events-log-lifecycle.sh` — both exist.
   - `ls .claude/context/schemas/events-schema.json .claude/context/formats/events-format.md` —
     both exist.
   - `jq '.hooks.Stop, .hooks.SubagentStop, .hooks.PostToolUse' .claude/settings.json` — shows the
     events hook command entries (and the pre-existing duplicate `claude-stop-notify.sh` Stop
     matcher is resolved).
   - `bash .claude/scripts/check-extension-docs.sh --quiet` — `core`'s FAILs resolve to 0, and the
     never-deployed info-skips for the events scripts/hooks disappear.
   - The new non-silent self-load note appears; `Lib: 0 | Tests: 0` is expected-and-flagged, not a
     failure.
6. Repeat steps 1-5 in at least one other repo (`~/.dotfiles`).

**Timing**: user-owned (agent effort: handoff already produced in Phase 4)

**Depends on**: 1, 2, 3, 4 (regenerate only after the corrected source is committed, so the deploy
carries the finished edits)

---

### Phase 6: End-to-end verification of event flow (scope 1) [BLOCKED]

**Goal**: Confirm events actually FLOW (not merely that files exist). DOUBLY GATED — first on the
manual regeneration (Phase 5), then on accumulated REAL USAGE OVER TIME.

**Blocked on**: Phase 5 completion AND real `/research`/`/plan`/`/implement` invocations occurring
post-regeneration so lifecycle/artifact hooks actually fire. This CANNOT be verified today. No
phase in this plan claims otherwise.

**What "end-to-end verified" will mean (once unblocked)**:
- `specs/events.jsonl` has grown with real lines (not just that the file exists).
- `check-extension-docs.sh` reports 0 FAILs for `core`.
- At least one lifecycle event (preflight/postflight/Stop) has actually fired from a real command
  invocation post-regeneration.
- Do NOT infer success from the code changes alone; do NOT fabricate this verification.

**Timing**: gated (not today)

**Depends on**: 5

---

## Dotfiles / telemetry handoff (scope 3/4 — NOT edited by this task)

The correct home for both settings is `~/.dotfiles/config/claude/settings.json` (Home-Manager-
managed, user-level, cross-repo). This task must NOT edit that file. Apply as a user step or a
separate dotfiles-repo task, then run `home-manager switch`. `cleanupPeriodDays: 0` DISABLES
persistence (issue #23710) — never `0`; the documented default is 30; recommend `365`.

```json
"cleanupPeriodDays": 365,
"env": {
  "...": "existing keys unchanged",
  "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
  "OTEL_METRICS_EXPORTER": "console",
  "OTEL_LOGS_EXPORTER": "console"
}
```

(Console exporter chosen to avoid requiring collector infrastructure; upgrading to OTLP is a
follow-up, not a blocker.) Do NOT add these to
`agent-system/extensions/core/root-files/settings.json` — despite that file being in `file_scope`,
its `env` block is project-scoped only and would miss cross-repo/ad-hoc invocations.

## Testing & Validation

- [ ] Phase 1: present-vs-absent-vs-failing helper harness observed; enclosing exit always 0 when
      helper missing/failing; warning correctly labels missing vs failed.
- [ ] Phase 2: emitted JSONL contains `"cwd"` (populated and `null` cases); schema validates; no
      `cc_session_id`; `events-query.sh` derives repo and tolerates `cwd: null`.
- [ ] Phase 3: `check-extension-docs.sh` before/after delta observed against the live stale tree —
      never-deployed core scripts/hooks now FAIL; additive w.r.t. memory-extension entries.
- [ ] Phase 4: source-store note free of task-number references; HANDOFF.md contains exact
      keystrokes + dotfiles snippet.
- [ ] No `.claude/**` file modified; no `specs/state.json` / `specs/TODO.md` modified; the two
      pre-existing uncommitted lua edits untouched.
- [ ] Phases 5-6 remain [BLOCKED]; task terminus [PARTIAL]; no event-flow claim made today.

## Artifacts & Outputs

- `specs/885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md`
  (this plan)
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` (Phase 4)
- `specs/885_enable_and_verify_passive_signal_capture/summaries/01_passive-signal-capture-deploy-summary.md`
  (on implementation)
- Modified source-store files under `agent-system/extensions/core/**` (Phases 1-4)

## Rollback/Contingency

- All landable edits are text edits to committed source-store files; revert via `git checkout` of
  the specific `agent-system/extensions/core/**` files (NOT a tree-wide reset — the two pre-existing
  uncommitted lua edits must be preserved).
- No deploy happens from this task, so there is nothing to un-deploy; a regeneration performed by
  the user in Phase 5 can itself be re-run from corrected source if an issue is found.
- If Phase 3's additivity check reveals a collision with the concurrent memory-extension manifest
  change, defer/reconcile the manifest-touching portion and keep the core-deploy-status check
  (which needs no manifest change).
