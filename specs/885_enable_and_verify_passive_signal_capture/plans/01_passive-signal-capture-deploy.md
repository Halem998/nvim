# Implementation Plan: Task #885

- **Task**: 885 - Enable and verify passive signal capture
- **Status**: [PARTIAL]
- **Effort**: 5 hours (agent) + user-owned manual regeneration (out of agent effort)
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
| 5 | 7 | -- (independent of 1-6; corrects a gap Phase 5/6 exposed) |

Phases within the same wave can execute in parallel. Phases 1, 3, and 4 touch disjoint files.
Phase 2 shares the two events hooks with Phase 1, so it follows Phase 1 to avoid edit conflicts.
Phases 5-6 are user-owned/[BLOCKED] and gated behind the landable source-store edits. Phase 7 is a
later-session source-store fix for the exact gap Phase 5's re-verification exposed; it has no
plan-declared dependency on 1-6 but a subsequent re-run of Phase 5 (regeneration) is required for
its edit to take deployment effect.

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

### Phase 3: Deploy-drift / completeness gate for core (scope 6) [COMPLETED]

**Goal**: Extend `check-extension-docs.sh` so that for the `core` extension specifically
(identifiable via `routing_exempt: true`), a never-deployed script/hook is a FAIL, not an
info-skip — closing the "never deployed < deployed-but-drifted" inversion. Additive with respect to
the concurrent memory-extension manifest change.

**Tasks**:
- [x] `agent-system/extensions/core/scripts/check-extension-docs.sh`: in `check_deployed_script_drift`
      (and analogous logic), treat "not deployed" as FAIL for the `core` extension (baseline,
      present in every `.claude/` tree by construction), while keeping the existing info-skip for
      optional extensions a repo may legitimately not have loaded. *(completed: altered from FAIL
      to a new ADVISORY lane per the orchestrator's binding concurrency guardrail — see the
      deviation note below and `check_core_deploy_advisory`'s in-file rationale comment)*
- [x] Add a drift/completeness check for `provides.hooks` (currently never iterated by any
      drift check) so the two events hooks' non-deployment is visible for core. *(completed)*
- [x] Add a completeness check for `root-files/settings.json`'s hook-registration set relative to
      the deployed `.claude/settings.json` (currently entirely unchecked), so missing hook
      registrations (and the known duplicate `claude-stop-notify.sh` Stop-matcher artifact) become
      visible. *(completed: live-verified — the duplicate claude-stop-notify.sh Stop-matcher
      artifact was actually detected in the live tree, confirming the research's claim)*
- [x] Keep the change ADDITIVE: it operates on the CORE extension's deploy status only. Do NOT
      modify shared manifest keys; the concurrent memory-extension task's
      `manifest.provides.scripts` addition is a separate concern and must not conflict.
      *(completed: verified byte-identical `[memory]` section output before/after; no manifest
      files touched)*
- [x] (Optional, note-only) Flag the `REPO_ROOT` auto-detect latent bug when the script is invoked
      from its source-store path; a one-line guard is acceptable but not required. *(completed:
      note-only, per the optional/not-required latitude — no behavior change)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify** (source store only):
- `agent-system/extensions/core/scripts/check-extension-docs.sh`

**Verification** (run and observe today against the LIVE, still-stale `.claude/` tree; ACTUALLY
RUN, not inferred):
- **DEVIATION from the original FAIL design** (see deviation note below): ran the git-committed
  (pre-edit) `check-extension-docs.sh` via `git show HEAD:...` as the literal "before" baseline
  (`REPO_ROOT=$(pwd) bash <before-copy> --quiet`) — confirmed `exit=1`, `FAIL: 5 issue(s) found`,
  and `events-append.sh`/`events-query.sh`/the two events hooks entirely absent from the output
  (silently info-skipped, invisible under `--quiet`).
- Ran the edited `check-extension-docs.sh` the same way (`REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`): confirmed `exit=1`,
  `FAIL: 5 issue(s) found` -- **byte-identical pass/fail verdict to the pre-edit baseline** -- plus
  a new, always-visible "Core Deploy-Drift Advisory" section listing 41 items including
  `events-append.sh`, `events-query.sh`, both events hooks, AND a live-confirmed instance of the
  duplicate `claude-stop-notify.sh` Stop-matcher artifact the research predicted.
- `diff` of the full before/after output showed the ONLY delta was the additive ADVISORY block --
  nothing else changed, confirming the guardrail (ordinary invocations keep their prior verdict).
- Confirmed the `[memory]` extension's output section is byte-identical before/after (additivity
  check; no interference with the concurrent memory-extension manifest change).
- Confirmed the opt-in `STRICT_CORE_DEPLOY=1` lane works: same run with that env var set produces
  `FAIL: 46 issue(s) found` (5 + 41 advisories promoted) -- proving the same detection logic can
  be promoted to a hard gate for a future post-regeneration verification run, without that
  promotion affecting the default/ordinary invocation used by this task and its concurrent
  siblings today.

---

### Phase 4: Document the no-headless constraint and produce the user handoff [COMPLETED]

**Goal**: Prevent future retreading of the settled feasibility question, and produce a precise,
copy-pasteable handoff for the two genuinely gated items (manual regeneration; dotfiles telemetry/
retention). Landable today; no regeneration dependency.

**Tasks**:
- [x] Add a short note to the source store (e.g.
      `agent-system/extensions/core/docs/guides/creating-extensions.md`, or a new
      `agent-system/extensions/core/context/patterns/` file) stating plainly that `<leader>al`'s
      "Load Core"/"Load All" sync has NO headless/CI equivalent and always requires a human
      `confirm()` selection — so future automation/CI-deploy-verification attempts don't retread
      this. Honor no-task-references-in-deliverables (no task numbers in this file). *(completed:
      new file `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`,
      chosen over creating-extensions.md since it's a deployment/loader concept, not an
      extension-authoring one; registered in `index-entries.json` for lazy-load discoverability)*
- [x] Write a durable handoff document under this task's directory (specs/ — task-number
      references allowed here):
      `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md`, containing:
      - The exact regeneration keystrokes and success criteria (Phase 5 content below).
      - The exact dotfiles snippet (Phase 5 content below). *(completed)*
- [x] Verify the source-store note contains no task-number references and the handoff doc reproduces
      the exact snippet and keystrokes. *(completed: grep -nE 'task [0-9]|tasks [0-9]' returns no
      matches on the source-store note; HANDOFF.md verified to contain the keystroke sequence and
      the dotfiles snippet verbatim)*

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

### Phase 5: Manual `<leader>al` regeneration handoff (scope 1) [COMPLETED]

**Goal**: Deploy the finished source-store edits into each repo's `.claude/` tree. USER-OWNED —
no agent/headless path exists.

**RESOLVED — second regeneration after the merge-source fix landed.** The user ran `<leader>al`
"Sync all" in both repos again, this time with the corrected
`merge-sources/settings-hooks.json` in place. Verified live in BOTH trees:

- All six event files present (mtime `2026-07-27 03:46`).
- `.claude/settings.json` now registers all three hooks — the events-log commands appear under
  `PostToolUse` (matcher `Write|Edit` -> `events-log-artifact.sh`), `Stop` (matcher `*` ->
  `events-log-lifecycle.sh`), and the new `SubagentStop` key (matcher `*` ->
  `events-log-lifecycle.sh`). Each is its own single-command matcher object, as designed.
- `check-extension-docs.sh --quiet` -> `PASS: all extensions OK`, exit 0, zero FAILs.
- `STRICT_CORE_DEPLOY=1 ... | grep -c 'events-'` -> **0** in both repos (was 9).

**One original criterion is NOT met, and is now known to be unachievable by regeneration**: the
pre-existing duplicate `claude-stop-notify.sh` Stop-matcher entry is still present twice in both
trees. That criterion was written on the assumption the merge could deduplicate; the merge is
add-only and dedups at whole-matcher-object granularity, so no regeneration can ever remove it.
This is carved out to the follow-ups, not counted against this phase.

(The `~/.dotfiles` doc-lint run reports `agent-system/extensions does not exist` — expected, since
that repo is a deploy consumer and not the source store. Not a failure.)

**Independently re-verified (this session, not self-reported)**: the original blocker (a human
performing the interactive `<leader>al` regeneration) has cleared — a "Sync all" regeneration ran
in both nvim and `~/.dotfiles` (all six new event files present in both trees, `.claude/settings.json`
mtime advanced to the same moment as the new files). However, running the plan's own stated
success checks against the live, regenerated trees shows the regeneration is **incomplete**, not
fully successful:

- `ls` checks for the six deployed files (`events-append.sh`, `events-query.sh`,
  `events-log-artifact.sh`, `events-log-lifecycle.sh`, `events-schema.json`, `events-format.md`) —
  **PASS** in both nvim and `~/.dotfiles`.
- `jq '.hooks.Stop, .hooks.SubagentStop, .hooks.PostToolUse' .claude/settings.json` — **FAIL**.
  Neither repo's deployed `settings.json` contains the `events-log-artifact.sh` (PostToolUse) or
  `events-log-lifecycle.sh` (Stop, SubagentStop) hook command entries that the source-store
  `agent-system/extensions/core/root-files/settings.json` declares. The pre-existing duplicate
  `claude-stop-notify.sh` Stop-matcher entry is also **not** resolved (still 2 occurrences in both
  repos' deployed `settings.json`).
- `bash .claude/scripts/check-extension-docs.sh --quiet` — **PARTIAL**. `core`'s 5 pre-existing
  hard FAILs did resolve to 0 (`core: PASS` in the Summary table) — but the "events-related lines
  should disappear from the ADVISORY section" criterion **FAILS**: 4 events-specific advisory
  lines are still emitted (2 missing-hook-registration lines for `PostToolUse`/`Stop`, 1 for
  `SubagentStop`, 1 duplicate-registration line for `claude-stop-notify.sh`). The remaining
  zotero/literature "never deployed" advisory lines are expected per the plan and are correct, not
  a bug.
- `STRICT_CORE_DEPLOY=1 bash .claude/scripts/check-extension-docs.sh --quiet 2>&1 | grep -c 'events-'`
  — **FAIL**: returns `9`, not `0`.

**Root cause (identified, not fixed — out of this task's edit scope)**: unlike the plain-copy
scripts/hooks/schema files, `.claude/settings.json` is deployed via a merge routine
(`merge_settings` in the nvim-config sync plugin, delegating to a shared merge helper) rather than
overwritten wholesale. That merge step is what advanced `settings.json`'s mtime without actually
injecting the new hook command entries or deduplicating the existing `claude-stop-notify.sh`
Stop-matcher entry. This is a plugin-code defect in the sync mechanism itself, living outside
`agent-system/extensions/**` (this task's only permitted edit target) — fixing it is new,
unscoped work and is called out below as a follow-up rather than attempted here.

**CORRECTION (later session, Phase 7)**: the diagnosis above ("plugin-code defect in the sync
mechanism itself") is superseded by a more precise, independently-verified three-cause account —
see Phase 7. In short, the merge step was not defective: its declared source
(`merge-sources/settings-hooks.json`, per `manifest.json`'s `merge_targets.settings.source`) never
contained the events hook entries in the first place. They had been added only to the install-once
`root-files/settings.json`, and `copy_root_files` in `loader.lua` skips (`goto continue`) copying
any `INSTALL_ONCE_ROOT_FILES` entry — including `settings.json` — when the target already exists,
so that addition could never reach an already-initialized repo through either mechanism. The
mtime-advanced-without-new-content observation is fully explained by the merge running correctly
against an empty-of-events-hooks source; it was not evidence of a merge bug. The dedup-is-add-only
observation about the duplicate `claude-stop-notify.sh` entry remains accurate and unresolved —
`merge.lua`'s `deep_merge` (`vim.deep_equal` at whole-matcher-object granularity) only declines to
re-add an equal object, it never removes one. Phase 7 fixes the actual gap (the merge source) but
does not and cannot fix the duplicate or the install-once self-heal defect — see Phase 7's own
scope boundaries.

**"Repeat in at least one other repo"**: satisfied in the sense that `~/.dotfiles` also received a
regeneration (same six files present, same mtime-advanced-without-content-change pattern on
`settings.json`), but with the identical partial outcome — so the cross-repo repeat does not
change the verdict.

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

### Phase 6: End-to-end verification of event flow (scope 1) [PARTIAL]

**Goal**: Confirm events actually FLOW (not merely that files exist). DOUBLY GATED — first on the
manual regeneration (Phase 5), then on accumulated REAL USAGE OVER TIME.

**UPDATE — post-deployment status: hooks proven functional, live flow not yet observed.**

Gate 1 (deployment) is now satisfied — see Phase 5. Gate 2 (real usage) is NOT, for a specific
and expected reason: hook registrations are read at session start, and `.claude/settings.json`
was rewritten at `2026-07-27T10:46:01Z` while the newest event in `specs/events.jsonl` is
`2026-07-27T10:18:47Z`. Zero events postdate the regeneration, because the session observing it
had already loaded the pre-regeneration settings. **A new session is required.**

To distinguish "not yet fired" from "wired wrong", both hooks were executed directly against a
sandboxed deploy-shaped tree (never the real store, so no synthetic lines were written to
`specs/events.jsonl`). All three target event types emit correctly, with `task` correlation and
the `cwd` field populated:

| Trigger | Precondition supplied | Event emitted |
|---------|----------------------|---------------|
| PostToolUse `Write\|Edit` on a `.return-meta.json` | synthetic return-meta | `artifact_write` |
| SubagentStop (payload carries `agent_id`) | `.postflight-pending` marker under `specs/` | `subagent_stop` |
| Stop (no `agent_id`) | task recoverable + `state.json` `session_id` | `session_stop` |

Two correlation characteristics worth recording, both by design rather than defects:
- The **artifact** hook is deliberately narrow — it early-exits unless the written path is a
  task's `.return-meta.json` or `specs/errors.json`. It will not log ordinary file writes.
- The **Stop** hook emits nothing when no task number can be recovered (from
  `.claude/tmp/workflow-active` or a `[Tt]ask N` / `Task #N` match in `last_assistant_message`),
  and nothing when that task has no `session_id` in `state.json`. Purely conversational sessions
  therefore produce no `session_stop` event.

**Remaining to close this phase**: start a new session, exercise a real
`/research`/`/plan`/`/implement`, and confirm `artifact_write` / `subagent_stop` / `session_stop`
lines with timestamps after `2026-07-27T10:46:01Z` appear in `specs/events.jsonl`.

**Independently re-verified (this session, not self-reported)**, against `specs/events.jsonl`
(181 lines, 60797 bytes as observed) and a live `check-extension-docs.sh` run:

- `specs/events.jsonl` has grown with real lines from real command invocations **after** the
  Phase 5 regeneration timestamp — **PASS**, but only partially in scope. Timestamps span
  2026-07-15 through 2026-07-27, and include genuine `lifecycle_stage` preflight/postflight events
  for real, verifiable task numbers that match `git log` (e.g. task 908's plan and implement
  lifecycle, and this task's own `sess_1785147452_169888` preflight event at
  `2026-07-27T10:18:47Z`, all timestamped after the regeneration).
- `check-extension-docs.sh` reports 0 FAILs for `core` — **PASS** (non-strict mode; `core: PASS`
  in the Summary table).
- At least one lifecycle event fired from a real command invocation post-regeneration — **PASS**
  (see above).

**However, this is not the full picture the plan intended to verify.** All 181 events in
`specs/events.jsonl` are exclusively `lifecycle_stage` (`checkpoint: preflight|postflight`) or
`orchestrator_status` — the direct-call channel from `skill-base.sh`/`orchestrator-postflight.sh`
that Phase 1 hardened. Critically:
- **Zero** `artifact`-category events exist anywhere in the file — `events-log-artifact.sh` (the
  `PostToolUse` hook this task deploys) has never fired, in either repo, because its hook
  registration is the Phase 5 gap identified above.
- **Zero** `session_stop`/`subagent_stop` event types exist anywhere in the file —
  `events-log-lifecycle.sh`'s `Stop`/`SubagentStop` hook path (as opposed to the pre-existing
  direct-call path) has never fired, for the same reason.
- The preflight/postflight events that ARE flowing predate this task entirely (earliest observed:
  2026-07-15, before Phases 1-4 landed and well before today's regeneration) — they come from a
  channel that was already partially working, not a channel this task newly enabled.

So Phase 6's literal checklist (jsonl growing, 0 core FAILs, at least one lifecycle event firing)
passes, but the NEW event types/hooks this task's Phase 5 deploy was meant to activate
(PostToolUse artifact events; genuine Stop/SubagentStop session events) have zero observed
firings in either repo, as a direct consequence of the Phase 5 `settings.json` gap. This phase is
marked `[PARTIAL]`, not `[COMPLETED]`, because the specific new capability is unverified — do not
infer full success from the pre-existing channel alone.

**Timing**: gated (was not verifiable at plan-authoring time; re-verified this session)

**Depends on**: 5 (Phase 5 is itself `[PARTIAL]`, so Phase 6's dependency is only partially met)

---

### Phase 7: Fix the merge-source gap for the events hook registrations [COMPLETED]

**Goal**: Fix the actual root cause of the Phase 5 `settings.json` gap at the correct source-store
location, once independent re-verification (a later session, not self-reported) established that
the "merge routine is broken" framing in Phase 5's Root Cause paragraph was wrong.

**Independently verified root cause (three causes, not one)**:
1. **PRIMARY**: `.claude/settings.json` is registered install-once.
   `lua/neotex/plugins/ai/shared/extensions/loader.lua`'s `INSTALL_ONCE_ROOT_FILES` table includes
   `settings.json`, and `M.copy_root_files` skips (`goto continue`) copying any such file when the
   target already exists. Anything added only to `root-files/settings.json` can therefore never
   reach an already-initialized repo — the events hook registrations had been added there and
   nowhere else.
2. **Why the merge didn't save it**: the merge step reads a *different* file entirely.
   `manifest.json`'s `merge_targets.settings.source` points at
   `merge-sources/settings-hooks.json` (target `.claude/settings.json`). Verified before this
   phase's edit: that file's `.hooks` keys were exactly `["PostToolUse","SessionStart","Stop",
   "UserPromptSubmit"]` and `grep -c 'events-log'` on it returned `0`. The merge step ran
   correctly against an input that never declared the events hooks — it was not defective; it had
   nothing to inject. This supersedes Phase 5's "plugin-code defect in the sync mechanism itself"
   framing (see the CORRECTION note inserted into Phase 5 above).
3. **The duplicate (real, still unresolved)**: `lua/neotex/plugins/ai/shared/extensions/merge.lua`'s
   `deep_merge` compares whole matcher objects via `vim.deep_equal` (not individual
   `hooks[].command` strings) and is add-only — it declines to re-add an equal object but never
   removes one. This is confirmed by `manifest.json`'s own `merge_targets.settings._comment`, which
   already documented this behavior. It explains why the pre-existing duplicate
   `claude-stop-notify.sh` Stop-matcher entry survives every regeneration.

**What changed**: added the three missing hook registrations to
`agent-system/extensions/core/merge-sources/settings-hooks.json` — the file the merge step
actually reads — each as its **own dedicated, single-command matcher object** rather than appended
into an existing shared matcher:
- `PostToolUse` → new `"Write|Edit"` matcher object running `events-log-artifact.sh` (matcher
  confirmed against the deployed root-files copy's existing `PostToolUse`/`"Write|Edit"` usage for
  the same command, and against the hook script's own header comment).
- `Stop` → new `"*"` matcher object running `events-log-lifecycle.sh` (second array entry
  alongside the existing `claude-stop-notify.sh` matcher object).
- `SubagentStop` → new top-level key (did not exist in this file before) with a `"*"` matcher
  object running `events-log-lifecycle.sh`.

Each is dedicated and single-command specifically because `deep_merge`'s dedup is object-level: a
dedicated object is idempotent across repeated merges (an identical object is skipped, not
duplicated), whereas appending a command into an existing shared matcher object would make that
object non-equal to its previously-merged self and cause its sibling commands to be re-registered
on every future merge.

**Tasks**:
- [x] Added the `PostToolUse`/`"Write|Edit"` dedicated matcher object (single command:
      `events-log-artifact.sh`) to `settings-hooks.json`. *(completed)*
- [x] Added the `Stop`/`"*"` dedicated matcher object (single command:
      `events-log-lifecycle.sh`) to `settings-hooks.json`. *(completed)*
- [x] Added the new `SubagentStop` key with a `"*"` matcher object (single command:
      `events-log-lifecycle.sh`) to `settings-hooks.json`. *(completed)*
- [x] Verified valid JSON, correct `.hooks` key set, and `events-log` occurrence count.
      *(completed)*
- [x] Ran `check-extension-docs.sh --quiet` against the still-undeployed source and confirmed the
      advisory output now names all three new registrations as source-declared/not-yet-deployed
      (rather than never having been declared at all), and independently corroborates the
      still-live `claude-stop-notify.sh` duplicate. *(completed)*
- [x] Updated this plan (Phase 7, the CORRECTION note in Phase 5, and this Testing & Validation
      entry) and `HANDOFF.md` to reflect the corrected three-cause root cause. *(completed)*

**Timing**: 0.5 hour

**Depends on**: none (an independent source-store edit to the correct file; not blocked by
Phases 1-6). Phase 5 (regeneration) must be **re-run** after this edit is committed for the fix to
reach any deployed `.claude/settings.json` — this phase does not itself deploy anything.

**Files to modify** (source store only):
- `agent-system/extensions/core/merge-sources/settings-hooks.json`

**Verification** (run and observed today; real output, not inferred):
- `jq empty agent-system/extensions/core/merge-sources/settings-hooks.json` → valid JSON.
- `jq -c '.hooks | keys' agent-system/extensions/core/merge-sources/settings-hooks.json` →
  `["PostToolUse","SessionStart","Stop","SubagentStop","UserPromptSubmit"]` (includes the new
  `SubagentStop` key).
- `grep -c 'events-log' agent-system/extensions/core/merge-sources/settings-hooks.json` → `3`
  (was `0` before this phase).
- `jq -c '.hooks.PostToolUse[] | {matcher, count: (.hooks|length)}'` /
  `.hooks.Stop[]` / `.hooks.SubagentStop[]` on the same file → each of the three new objects has
  `count: 1` (single command), confirming the dedicated-object shape.
- `bash .claude/scripts/check-extension-docs.sh --quiet` → exit 0 (`core: PASS`, advisory-only);
  the Core Deploy-Drift Advisory section names all three new registrations as
  source-declares-but-deployed-does-not, plus the pre-existing duplicate
  `claude-stop-notify.sh` line — both expected until Phase 5 is re-run.

**What this phase does NOT claim** (see the plan-level HARD CONSTRAINT re-stated here):
- Does NOT update any deployed `.claude/settings.json` — that requires another `<leader>al`
  "Sync all" regeneration (Phase 5, remains `[PARTIAL]`), which has no headless path and is
  user-owned.
- Does NOT verify `PostToolUse`-artifact or `Stop`/`SubagentStop` event flow — that remains gated
  on Phase 5 (regeneration) and Phase 6 (real usage over time), both of which remain `[PARTIAL]`.
- Does NOT remove the already-deployed duplicate `claude-stop-notify.sh` Stop-matcher entry — the
  merge is add-only; this needs manual removal or a loader-side fix (out of scope, recorded as a
  blocker below).
- Does NOT fix the underlying install-once self-heal defect in `loader.lua`/`merge.lua` — those
  live under `lua/**`, outside this task's binding edit scope (recommend a follow-up task).

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
- [x] No `.claude/**` file modified; no `specs/state.json` / `specs/TODO.md` modified outside the
      normal preflight/postflight status transition; the two pre-existing uncommitted lua edits
      untouched. *(completed: this session's own edits are confined to the plan file, HANDOFF.md,
      the summary, and the two orchestrator artifacts; `.claude/**` was only read and executed
      against, never edited)*
- [x] Phases 5-6 re-verified this session (independently, not via self-report): Phase 5
      `[PARTIAL]` — regeneration ran in both nvim and `~/.dotfiles`, deploying the six new files,
      but `settings.json` hook registration for the new events hooks did not take effect and the
      pre-existing `claude-stop-notify.sh` duplicate was not resolved, in either repo. Phase 6
      `[PARTIAL]` — real preflight/postflight lifecycle events are flowing post-regeneration
      (jsonl growing, `core: PASS` in non-strict `check-extension-docs.sh`), but zero
      `PostToolUse`-artifact or `Stop`/`SubagentStop`-hook-driven events have ever fired, a direct
      consequence of the Phase 5 gap. Task terminus remains `[PARTIAL]`; no full end-to-end
      event-flow claim is made. *(completed: see Phase 5/6 sections above for the full
      criterion-by-criterion evidence)*
- [x] Phase 7: three missing hook registrations added to the correct source-store file
      (`merge-sources/settings-hooks.json`, not `root-files/settings.json`), each as its own
      dedicated single-command matcher object; `jq empty` valid, `.hooks` keys include
      `SubagentStop`, `events-log` occurrence count `0` → `3`, each new object has exactly one
      command, `check-extension-docs.sh --quiet` exits 0 with the advisory now naming all three as
      source-declared. Phase 5/6 status is unchanged by this phase — no deployment or event-flow
      claim is made; regeneration must still be re-run for this fix to take effect. *(completed)*

## Artifacts & Outputs

- `specs/885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md`
  (this plan)
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` (Phase 4)
- `specs/885_enable_and_verify_passive_signal_capture/summaries/01_passive-signal-capture-deploy-summary.md`
  (on implementation)
- Modified source-store files under `agent-system/extensions/core/**` (Phases 1-4, and Phase 7's
  `merge-sources/settings-hooks.json` fix)

## Rollback/Contingency

- All landable edits are text edits to committed source-store files; revert via `git checkout` of
  the specific `agent-system/extensions/core/**` files (NOT a tree-wide reset — the two pre-existing
  uncommitted lua edits must be preserved).
- No deploy happens from this task, so there is nothing to un-deploy; a regeneration performed by
  the user in Phase 5 can itself be re-run from corrected source if an issue is found.
- If Phase 3's additivity check reveals a collision with the concurrent memory-extension manifest
  change, defer/reconcile the manifest-touching portion and keep the core-deploy-status check
  (which needs no manifest change).
