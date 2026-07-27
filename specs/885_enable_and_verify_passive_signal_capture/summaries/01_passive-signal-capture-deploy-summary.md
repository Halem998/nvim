# Implementation Summary: Task #885

**Task**: 885 - Enable and verify passive signal capture
**Status**: [PARTIAL]
**Started**: 2026-07-15
**Completed**: 2026-07-27 (Phases 1-4: 2026-07-15; Phases 5-6 re-verification: 2026-07-27;
Phase 7 root-cause fix: 2026-07-27)
**Duration**: ~1 session (Phases 1-4) + ~1 session (Phases 5-6 independent re-verification) +
~1 session (Phase 7 fix)
**Artifacts**: reports/01_enable-verify-passive-signal-capture.md;
plans/01_passive-signal-capture-deploy.md;
summaries/01_passive-signal-capture-deploy-summary.md; HANDOFF.md
**Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md;
no-task-references-in-deliverables.md

## Overview

Landed all four regeneration-independent deliverables from the plan (source-store edits under
`agent-system/extensions/core/**`, each verified by actually running the modified script and
observing the result). The task's own research settled that there is no headless/CI path to
trigger the `<leader>al` regeneration required to deploy these changes or to verify live event
flow, so Phases 5-6 were originally handed off as `[BLOCKED]`.

**Phases 5-6 update (this session)**: an external regeneration occurred (both this repo and
`~/.dotfiles`), clearing the original "no human has run it yet" blocker. Independently
re-verifying against the plan's own stated success criteria (not trusting the regeneration having
happened, and not trusting any prior self-report) found the regeneration is **incomplete**: the
six new files deployed correctly, but `.claude/settings.json`'s hook registrations for the new
events hooks did not take effect, and a pre-existing duplicate hook entry was not resolved, in
either repo. As a direct consequence, Phase 6's new event types (PostToolUse artifact events;
genuine Stop/SubagentStop session events) have never fired, though the pre-existing
preflight/postflight lifecycle channel is confirmed flowing. The task remains `[PARTIAL]`; the
new, precise remainder is a `settings.json`-merge defect in the nvim-config sync plugin (outside
this task's edit scope) plus a second regeneration once that is fixed. See "Phases 5-6
Re-Verification" below for the full evidence.

**Phase 7 update (this session, corrects the paragraph above)**: the "`settings.json`-merge
defect" diagnosis was WRONG. Independent re-verification established the real, three-cause root
cause and this session fixed the fixable part of it at the source-store level: the events hook
registrations had been added only to the install-once `root-files/settings.json`, never to
`merge-sources/settings-hooks.json` — the file `manifest.json` actually wires the merge step to
read. The merge step itself was working correctly against an empty-of-events-hooks source; it was
never defective. This session added the three missing registrations to the correct file. The task
still terminates `[PARTIAL]` this run — a fresh `<leader>al` regeneration is still required to
deploy the fix, and the separate, already-known duplicate `claude-stop-notify.sh` entry is still
unresolved (add-only merge). See "Phase 7: Root-Cause Correction and Fix" below.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — Replaced 4 `bash ... || true` silent-fail
  sites with a duplicated `_events_append_observable` wrapper (present/missing/failed distinction,
  always returns 0).
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — Same wrapper pattern at its
  2 event-append call sites; fixed an `if`-guard bug so a present-but-failing helper no longer
  aborts the script under `set -euo pipefail`.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — Same wrapper at its 2 call sites;
  removed an early `[ -x "$EVENTS_APPEND" ] || exit_success` bypass that used to short-circuit
  before the wrapper could ever signal a missing helper. Also threads `--cwd` from hook stdin.
- `agent-system/extensions/core/hooks/events-log-artifact.sh` — Same wrapper at its 2 call sites;
  removed the equivalent early bypass; threads `--cwd` from hook stdin.
- `agent-system/extensions/core/context/schemas/events-schema.json` — Added a nullable `cwd`
  string field (not `cc_session_id`, which belongs to an unfrozen sibling design).
- `agent-system/extensions/core/scripts/events-append.sh` — Added `--cwd PATH`; writes `null` when
  absent (backward compatible).
- `agent-system/extensions/core/scripts/events-query.sh` — Derives `repo` at query time as
  `basename(cwd)` (never stored); added `--repo` filter and `by_repo` summary-counts aggregate;
  tolerant of `cwd: null`.
- `agent-system/extensions/core/context/formats/events-format.md` — Documents the `cwd` field and
  the cross-repo-federation derivation contract.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — New ADVISORY lane (`advisory()`
  helper, `DEPLOY_DRIFT_ADVISORIES` counter, dedicated always-visible summary section) surfacing
  core-extension never-deployed `provides.scripts`/`provides.hooks` entries and
  `root-files/settings.json` hook-registration gaps/duplicates. Opt-in `STRICT_CORE_DEPLOY=1`
  promotes these to real failures.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — New file
  documenting the no-headless-regeneration constraint for future reference.
- `agent-system/extensions/core/index-entries.json` — Registered the new pattern file.
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md` — New durable, user-executable
  handoff: exact `<leader>al` regeneration procedure + success criteria, and the dotfiles
  telemetry/retention snippet (not applied to this repo). Updated this session with the corrected
  three-cause root cause (see Phase 7 below).
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (Phase 7, this session) — Added
  three missing hook registrations (`PostToolUse`/`events-log-artifact.sh`,
  `Stop`/`events-log-lifecycle.sh`, new `SubagentStop` key/`events-log-lifecycle.sh`) as dedicated
  single-command matcher objects — the actual file the merge step reads, distinct from
  `root-files/settings.json` where these had been added before but could never reach an
  already-initialized repo.

## Decisions

- **Shared wrapper duplicated inline, not sourced from a new file**: the 4 call-site files span
  sourced (`skill-base.sh`) and standalone (`orchestrator-postflight.sh`, 2 hooks) execution
  contexts with no existing shared-sourcing convention, and a new shared script would need a
  `manifest.json` registration outside this task's edit-target scope. Took the plan's own
  documented fallback.
- **`repo` derived as `basename(cwd)` via pure jq, not a per-row `git rev-parse --show-toplevel`
  shell-out**: keeps `events-query.sh` consistent with its existing native-jq streaming-filter
  design; the plan itself flagged the git-toplevel approach as an example ("e.g."), not a
  requirement.
- **Phase 3's "not deployed = FAIL for core" design point was altered to ADVISORY, not FAIL**, per
  a binding orchestrator guardrail issued after the plan was written: the pre-existing core
  deploy drift this check surfaces is real right now and can only be resolved by a user-driven
  regeneration, so a hard FAIL would have bricked the doc-lint gate for every caller — including a
  concurrently running sibling session validating an unrelated memory-extension manifest change
  through this same script — until that regeneration happens. An opt-in `STRICT_CORE_DEPLOY=1`
  lane preserves the original hard-FAIL behavior for callers who want it (e.g. a future
  post-regeneration verification run).

## Plan Deviations

- **Task 1.1** (shared wrapper location) altered: duplicated inline in each of the 4 call-site
  files instead of a single sourced shared script — see Decisions above.
- **Task 2.5** (`repo` derivation) altered: `basename(cwd)` via jq instead of a git-toplevel
  shell-out — see Decisions above.
- **Task 3.1** (core "not deployed" severity) altered: implemented as an ADVISORY lane instead of
  a hard FAIL, per the binding orchestrator concurrency guardrail — see Decisions above and
  `check_core_deploy_advisory`'s in-file rationale comment.
- **Task 4.1** (source-store note) additionally registered the new pattern file in
  `index-entries.json` — not explicitly listed in the plan's file list, but a minimal, low-risk
  companion edit for discoverability, consistent with this repo's existing convention.

Full per-phase deviation entries with reasons: see `progress/phase-{1,2,3,4}-progress.json`.

## Verification

- **Phase 1**: Sandboxed present/absent/failing-helper harness run against all 4 modified files,
  both as direct wrapper calls and full end-to-end stage/hook runs (`skill_context_injection`,
  both `events-log-lifecycle.sh` paths, both `events-log-artifact.sh` branches). Caught and fixed
  a real `set -e` correctness bug where a present-but-failing helper would abort the enclosing
  script before the wrapper could capture its exit code and return 0.
- **Phase 2**: `events-append.sh` run with and without `--cwd`; emitted JSONL lines inspected and
  manually validated against the updated schema (cwd present/nullable, `cc_session_id` absent).
  `events-query.sh` run over a 3-row fixture (populated `cwd` x2, `null` x1): confirmed correct
  `repo` derivation, `--repo` filtering, `by_repo` aggregation, and zero errors on `cwd: null`
  rows. Both hooks confirmed end-to-end to thread `cwd` from stdin into the emitted event line.
- **Phase 3**: Ran the git-committed (pre-edit) `check-extension-docs.sh` via `git show HEAD:...`
  as the literal "before" baseline against the live tree (`REPO_ROOT=$(pwd) ... --quiet`): `exit=1`,
  `FAIL: 5 issue(s) found`, events files silently absent from output. Ran the edited script the
  same way: byte-identical verdict (`exit=1`, `FAIL: 5 issue(s) found`) plus a new, always-visible
  41-item ADVISORY section (including a live-confirmed instance of the duplicate
  `claude-stop-notify.sh` Stop-matcher artifact the research predicted). Full-output `diff`
  confirmed the ADVISORY section was the ONLY delta. `[memory]` extension output confirmed
  byte-identical before/after (additivity with the concurrent sibling task). `STRICT_CORE_DEPLOY=1`
  confirmed to promote the same 41 advisories to real failures (`FAIL: 46`).
- **Phase 4**: `grep -nE 'task [0-9]|tasks [0-9]'` returns no matches on the source-store note.
  `HANDOFF.md` confirmed to contain the keystroke sequence and dotfiles snippet verbatim.
- Build: N/A (bash/JSON/Markdown only)
- Tests: N/A (no test suite for this file set; verification was run-and-observe per the plan's
  own requirement)
- Files verified: Yes — every file listed in "What Changed" was read back or its behavior
  explicitly run and observed, not merely assumed correct after editing.

## Impacts

- **Event capture is still not live.** No deployed `.claude/settings.json` registers the
  artifact or lifecycle hooks yet, in this repo or `~/.dotfiles`. Until a fresh `<leader>al`
  "Sync all" regeneration runs, zero PostToolUse-artifact and zero `Stop`/`SubagentStop`
  session events will fire. The preflight/postflight direct-call channel is unaffected and
  continues to flow.
- **Source store is now correct.** `merge-sources/settings-hooks.json` declares all three
  registrations, so the next regeneration in any repo will deploy them. This changes the
  remaining work from "unfixable at source" to "one regeneration away".
- **A latent deploy defect is now documented.** Additions to install-once root files
  (`settings.json`, `settings.local.json`) can never reach an already-initialized repo. Any
  future work that adds settings must target the merge source, not the root file.
- **One residual cannot self-heal.** The duplicate `claude-stop-notify.sh` Stop-matcher entry
  in already-deployed trees survives every future merge, since the merge is add-only.

## Follow-ups

1. **User-owned**: run the `<leader>al` "Sync all (replace existing)" regeneration in this repo
   and `~/.dotfiles`, then re-run HANDOFF.md Part A's success criteria. No headless path exists.
2. **New task recommended**: fix the install-once self-heal gap and the add-only, object-level
   dedup in `lua/neotex/plugins/ai/shared/extensions/loader.lua` and
   `lua/neotex/plugins/ai/claude/extensions/merge.lua`. Outside this task's
   `agent-system/extensions/**` edit scope.
3. **Manual cleanup**: remove the duplicate `claude-stop-notify.sh` Stop-matcher entry from
   already-deployed trees; no merge can do this.
4. **Separate repo**: apply the telemetry/retention settings in `~/.dotfiles` (see Part B).

## References

- `specs/885_enable_and_verify_passive_signal_capture/reports/01_enable-verify-passive-signal-capture.md`
- `specs/885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md`
- `specs/885_enable_and_verify_passive_signal_capture/HANDOFF.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (the merge source the deploy
  step actually reads)
- `agent-system/extensions/core/manifest.json` — `merge_targets.settings`, whose `_comment`
  documents the add-only, object-granularity dedup behavior
- Claude Code transcript retention: `anthropics/claude-code` issue #23710

## Notes

- The dotfiles telemetry/retention settings (scope 3/4) were deliberately NOT applied to this
  repo — see HANDOFF.md Part B for the exact snippet and rationale (`cleanupPeriodDays: 365`,
  never `0`, per `anthropics/claude-code` issue #23710).

## Phases 5-6 Re-Verification (this session)

Independently re-checked every criterion the plan itself states for Phase 5 and Phase 6, against
the live `.claude/` trees in this repo and `~/.dotfiles`, rather than trusting that a regeneration
had happened or any prior self-report.

**Phase 5 — `[PARTIAL]`** (was `[BLOCKED]`; the blocker cleared, but the outcome is incomplete):
- Six deployed files (`events-append.sh`, `events-query.sh`, `events-log-artifact.sh`,
  `events-log-lifecycle.sh`, `events-schema.json`, `events-format.md`) — **exist in both repos**,
  all with the same mtime (`2026-07-27 02:57:10` in nvim), confirming a real regeneration ran.
- `jq '.hooks.Stop, .hooks.SubagentStop, .hooks.PostToolUse' .claude/settings.json` — **FAILS** in
  both repos: no `events-log-artifact.sh` or `events-log-lifecycle.sh` command entries appear
  anywhere in `.claude/settings.json`'s `Stop`/`SubagentStop`/`PostToolUse` arrays, despite the
  source-store `agent-system/extensions/core/root-files/settings.json` declaring all three. The
  pre-existing duplicate `claude-stop-notify.sh` Stop-matcher entry is also still present twice in
  both repos (`grep -c claude-stop-notify .claude/settings.json` → `2`).
- `check-extension-docs.sh --quiet` — `core`'s FAILs resolved to 0 (`core: PASS`), but the
  ADVISORY section still lists 4 events-related `settings.json` lines (2 missing-registration for
  PostToolUse/Stop, 1 for SubagentStop, 1 duplicate-registration) — these did NOT disappear as the
  plan requires. `STRICT_CORE_DEPLOY=1 ... | grep -c 'events-'` returns `9`, not `0`.
- **Root cause identified** (not fixed — outside this task's `agent-system/extensions/**` edit
  scope): unlike the plain-copy files, `.claude/settings.json` is deployed via a merge routine
  (`M.merge_settings` in `lua/neotex/plugins/ai/claude/extensions/merge.lua`, delegating to a
  shared merge helper) rather than overwritten wholesale. That merge advanced the file's mtime
  without injecting the new hook fragment entries or deduplicating the pre-existing duplicate —
  a defect in the sync plugin itself, flagged as a follow-up in HANDOFF.md.

**Phase 6 — `[PARTIAL]`** (was `[BLOCKED]`; partially verified now that regeneration + real usage
have both occurred):
- `specs/events.jsonl` (181 lines, ~61KB) has grown with real `lifecycle_stage`
  preflight/postflight events from real command invocations timestamped after the Phase 5
  regeneration (e.g. task 908's full plan/implement cycle; this task's own preflight event) —
  **confirmed**.
- `check-extension-docs.sh` reports 0 FAILs for `core` in non-strict mode — **confirmed**.
- At least one lifecycle event fired from a real invocation post-regeneration — **confirmed**.
- However: **zero** `artifact`-category events and **zero** `session_stop`/`subagent_stop` event
  types exist anywhere in `specs/events.jsonl` — `events-log-artifact.sh` and the
  `Stop`/`SubagentStop`-hook path of `events-log-lifecycle.sh` have never fired, in either repo,
  the direct consequence of the Phase 5 `settings.json` gap. The events that ARE flowing come from
  the pre-existing `skill-base.sh`/`orchestrator-postflight.sh` direct-call channel (earliest
  observed timestamp: 2026-07-15, predating this task's Phase 1-4 landing) — not a new capability
  this task activated.

**What genuinely remains** (see HANDOFF.md for the full detail): fix the `settings.json` merge
defect in the sync plugin (new, unscoped work — recommend a follow-up task), re-run `<leader>al`
"Sync all" in both repos, then re-check for `artifact`-category and `session_stop`/`subagent_stop`
events in `specs/events.jsonl`.

**NOTE (superseded by Phase 7 below)**: the "Root cause identified" bullet under Phase 5 above
("a defect in the sync plugin itself") was the WRONG diagnosis. There was no merge-routine defect
to fix. See Phase 7 for the corrected three-cause account and the fix actually applied.

## Phase 7: Root-Cause Correction and Fix (this session)

**Independently re-verified, corrected root cause** (supersedes the "settings.json merge defect"
diagnosis in the Phase 5 re-verification section above):

1. **PRIMARY**: `.claude/settings.json` is registered install-once in
   `lua/neotex/plugins/ai/shared/extensions/loader.lua`'s `INSTALL_ONCE_ROOT_FILES` table; its
   `M.copy_root_files` skips (`goto continue`) copying any such file once the target already
   exists. The events hook registrations had been added only to
   `agent-system/extensions/core/root-files/settings.json` (the install-once file) — so they could
   never reach an already-initialized repo via that path, regardless of any merge behavior.
2. **Why the merge didn't save it**: the merge step reads a *different* file —
   `manifest.json`'s `merge_targets.settings.source` points at
   `merge-sources/settings-hooks.json`. Verified before this session's fix: `grep -c 'events-log'`
   on that file returned `0`; its `.hooks` keys were exactly `["PostToolUse","SessionStart","Stop",
   "UserPromptSubmit"]`. The merge step was never defective — it correctly merged a source that
   never declared the events hooks. This fully explains the "mtime advanced without new content"
   symptom observed during Phase 5 re-verification without requiring a plugin-code bug.
3. **The duplicate `claude-stop-notify.sh` entry remains real and separate**:
   `lua/neotex/plugins/ai/shared/extensions/merge.lua`'s `deep_merge` dedups at whole-matcher-
   *object* granularity via `vim.deep_equal`, is add-only, and never removes an existing entry —
   confirmed by `manifest.json`'s own `merge_targets.settings._comment`. This is unrelated to
   causes 1-2 and is NOT fixed by this session's edit.

**Fix applied** (source-store only, `agent-system/extensions/core/merge-sources/settings-hooks.json`):
added three hook registrations, each as its own dedicated single-command matcher object (not
appended into the existing shared `PostToolUse`/`"Write|Edit"` or `Stop`/`"*"` matcher objects), so
each is idempotent under `deep_merge`'s object-level dedup on every future merge:
- `PostToolUse` → new matcher object, `"Write|Edit"`, single command `events-log-artifact.sh`.
- `Stop` → new matcher object, `"*"`, single command `events-log-lifecycle.sh` (second array entry
  alongside the pre-existing `claude-stop-notify.sh` object).
- `SubagentStop` → new top-level key (previously absent from this file), `"*"` matcher, single
  command `events-log-lifecycle.sh`.

**Verification (actually run, real output)**:
```
$ jq empty agent-system/extensions/core/merge-sources/settings-hooks.json && echo VALID
VALID
$ jq -c '.hooks | keys' agent-system/extensions/core/merge-sources/settings-hooks.json
["PostToolUse","SessionStart","Stop","SubagentStop","UserPromptSubmit"]
$ grep -c 'events-log' agent-system/extensions/core/merge-sources/settings-hooks.json
3
$ jq -c '.hooks.PostToolUse[] | {matcher, count: (.hooks|length)}' ...settings-hooks.json
{"matcher":"Write|Edit","count":2}
{"matcher":"Write|Edit","count":1}
$ jq -c '.hooks.Stop[] | {matcher, count: (.hooks|length)}' ...settings-hooks.json
{"matcher":"*","count":1}
{"matcher":"*","count":1}
$ jq -c '.hooks.SubagentStop[] | {matcher, count: (.hooks|length)}' ...settings-hooks.json
{"matcher":"*","count":1}
$ bash .claude/scripts/check-extension-docs.sh --quiet ; echo "exit: $?"
... (core section)
  ADVISORY: settings.json hook registration missing for event 'PostToolUse': events-log-artifact.sh (...)
  ADVISORY: settings.json hook registration missing for event 'Stop': events-log-lifecycle.sh (...)
  ADVISORY: settings.json duplicate hook registration for event 'Stop': claude-stop-notify.sh (...)
  ADVISORY: settings.json hook registration missing for event 'SubagentStop': events-log-lifecycle.sh (...)
...
core            PASS
...
PASS: all extensions OK
exit: 0
```
The doc-lint gate itself independently corroborates the fix: it now names all three new
registrations as source-declared-but-not-yet-deployed (previously they were declared nowhere and
so never appeared at all), and separately corroborates the still-unresolved duplicate.

**What this does NOT claim**: no deployment occurred and no event-flow verification was performed
or is claimed. Phase 5 and Phase 6 remain `[PARTIAL]` unchanged by this phase — a fresh
`<leader>al` "Sync all" regeneration is still required for this fix to reach any deployed
`.claude/settings.json`, and even after that, the duplicate `claude-stop-notify.sh` entry will
persist until a separate, out-of-scope fix (manual removal or loader/merge-side dedup with
removal support) lands. The underlying install-once self-heal defect in
`loader.lua`/`merge.lua` is also NOT fixed — both files live under `lua/**`, outside this task's
binding edit scope (`agent-system/extensions/**` and `specs/**` only); recommend a follow-up task.

**Plan deviation**: none. This phase was not anticipated by the original 6-phase plan (it responds
to a diagnosis made during Phase 5/6 re-verification); it was added as a new Phase 7, following the
existing phase-numbering convention, rather than retrofitted into an earlier phase.
