# Handoff: Manual Regeneration + Dotfiles Telemetry/Retention

This document is the durable, user-executable handoff for the passive-signal-capture deploy
(`enable_and_verify_passive_signal_capture`). Phases 1-4 (observable-failure fix, nullable `cwd`
schema field, core deploy-drift ADVISORY gate, and this document) landed and are committed.

**UPDATE (independently re-verified in a later session, not self-reported)**: the original Phase 5
blocker — "a human must perform the interactive `<leader>al` regeneration; no headless path
exists" — has cleared. A "Sync all" regeneration was run in both this repo and `~/.dotfiles`,
deploying the six new event files (`events-append.sh`, `events-query.sh`,
`events-log-artifact.sh`, `events-log-lifecycle.sh`, `events-schema.json`, `events-format.md`) to
both trees. **However, running this document's own Part A success criteria against the live
regenerated trees revealed the regeneration was incomplete**: `.claude/settings.json` was NOT
updated with the new hook command entries for `events-log-artifact.sh` (PostToolUse) or
`events-log-lifecycle.sh` (Stop, SubagentStop), and the pre-existing duplicate
`claude-stop-notify.sh` Stop-matcher entry was NOT resolved — in either repo.

**RESOLVED (verified live after a SECOND regeneration).** Once the merge-source fix below landed,
the user re-ran `<leader>al` "Sync all" in both repos. Verified directly in both trees: all six
event files present, and `.claude/settings.json` now registers all three hooks — `PostToolUse`
(`Write|Edit` -> `events-log-artifact.sh`), `Stop` (`*` -> `events-log-lifecycle.sh`), and the new
`SubagentStop` key (`*` -> `events-log-lifecycle.sh`). `check-extension-docs.sh --quiet` returns
`PASS: all extensions OK` (exit 0), and `STRICT_CORE_DEPLOY=1 ... | grep -c 'events-'` returns
**0** (was 9). **Part A below is satisfied except for the duplicate**, which no regeneration can
ever fix — see follow-up 1.

Live event flow is still not observed: hook registrations load at session start, and
`.claude/settings.json` was rewritten at `2026-07-27T10:46:01Z` while the newest line in
`specs/events.jsonl` is `2026-07-27T10:18:47Z`. **A new session is required.** Both hooks were
nevertheless executed directly against a sandboxed deploy-shaped tree (never the real store) and
emit correctly: `artifact_write`, `subagent_stop`, and `session_stop`, each with `task`
correlation and the `cwd` field populated. So the wiring is proven; only real post-restart usage
remains.

**CORRECTION (earlier session): the original "merge routine is broken" diagnosis above was WRONG.**
A closer, independently-verified read of the loader/merge code establishes a different, more
precise three-cause root cause — and this session fixed the part of it that is fixable at the
source-store level:

1. **PRIMARY — `settings.json` is install-once, not merge-only.**
   `lua/neotex/plugins/ai/shared/extensions/loader.lua` declares `settings.json` (and
   `settings.local.json`) in `INSTALL_ONCE_ROOT_FILES`, and `M.copy_root_files` skips
   (`goto continue`) copying any such file once the target already exists. Anything added only to
   `agent-system/extensions/core/root-files/settings.json` — which is where the events hook
   registrations had actually been added — can therefore never reach an already-initialized repo
   through that path.
2. **Why the merge step didn't save it either: it reads a different file.**
   `manifest.json`'s `merge_targets.settings.source` points at
   `merge-sources/settings-hooks.json` (target `.claude/settings.json`), a separate file from
   `root-files/settings.json`. Verified before this session's fix: that file's `.hooks` keys were
   exactly `["PostToolUse","SessionStart","Stop","UserPromptSubmit"]` and
   `grep -c 'events-log'` on it returned `0`. **The merge step was not defective — it ran
   correctly against a source that never declared the events hooks in the first place.** The
   mtime-advancing-without-new-content symptom is fully explained by this: merging correctly
   against empty-of-events-hooks input produces exactly that symptom. This session added the
   three missing registrations directly to `merge-sources/settings-hooks.json` (see "What This
   Session Fixed" below) — the file the merge step actually reads.
3. **The duplicate `claude-stop-notify.sh` entry — real, but a separate, still-unresolved issue.**
   `lua/neotex/plugins/ai/shared/extensions/merge.lua`'s `deep_merge` dedups at whole-matcher-
   *object* granularity via `vim.deep_equal` (not per-command), and is add-only — it declines to
   re-add an object equal to one already present, but never removes an existing one. This is
   documented in `manifest.json`'s own `merge_targets.settings._comment`. It explains why the
   pre-existing duplicate survives every regeneration, and is unrelated to cause 1/2 above.

**What this session fixed** (source-store only, `agent-system/extensions/core/**`): added the
three missing hook registrations to `merge-sources/settings-hooks.json` — `PostToolUse` →
`events-log-artifact.sh`, `Stop` → `events-log-lifecycle.sh`, and a new `SubagentStop` key →
`events-log-lifecycle.sh` — each as its own dedicated, single-command matcher object (not appended
into an existing shared matcher), so each stays idempotent under `deep_merge`'s object-level dedup
across repeated future merges. Verified: `jq empty` valid, `.hooks` keys now include
`SubagentStop`, `grep -c 'events-log'` is `3` (was `0`), each new matcher object has exactly one
command, and `check-extension-docs.sh --quiet` (exit 0, advisory-only) now names all three as
source-declared/not-yet-deployed instead of never-declared. See the plan's Phase 7 for the full
verification transcript.

**What this session did NOT fix (still genuinely gated or out of scope)**:
- **Deployment.** Editing the merge source does not touch any already-deployed
  `.claude/settings.json`. That still requires another `<leader>al` "Sync all" regeneration
  (Phase 5 below), which has no headless path and is user-owned. Phase 5 and Phase 6 both remain
  `[PARTIAL]` — no event-flow claim is made by this session.
- **The duplicate `claude-stop-notify.sh` entry** in the already-deployed `.claude/settings.json`.
  The merge is add-only; no future merge can remove it. This needs either a manual one-time
  removal in each already-synced repo, or a loader/merge-side fix that adds real dedup/replace
  semantics — recorded as a blocker below, not attempted here.
- **The underlying "install-once files can never self-heal a missed addition" defect** in
  `loader.lua`'s `copy_root_files` / `merge.lua`'s `deep_merge`. Both live under `lua/**`, outside
  this task's binding edit scope (`agent-system/extensions/**` and `specs/**` only). Recommend a
  follow-up task to add either a version-stamped re-copy mechanism for install-once files, or
  true per-command (rather than per-object) merge dedup with removal support.

**Consequence for Phase 6**: real preflight/postflight lifecycle events ARE flowing in
`specs/events.jsonl` post-regeneration (from the pre-existing `skill-base.sh`/
`orchestrator-postflight.sh` direct-call channel, hardened by Phase 1) — but zero
`PostToolUse`-artifact events and zero genuine `Stop`/`SubagentStop`-hook-driven session events
have ever fired, in either repo, because of the `settings.json` gap above. Phase 6 is therefore
`[PARTIAL]`, not `[COMPLETED]`.

**What genuinely remains**:
1. Re-run the `<leader>al` "Sync all" regeneration in both repos now that the corrected
   `merge-sources/settings-hooks.json` is committed.
2. Re-run this document's Part A success criteria to confirm `jq '.hooks.Stop, .hooks.SubagentStop,
   .hooks.PostToolUse' .claude/settings.json` shows the events hook entries. The pre-existing
   duplicate `claude-stop-notify.sh` entry will NOT resolve on its own — it needs the separate
   manual/loader-side fix described above.
3. Only then can PostToolUse-artifact and Stop/SubagentStop-session event flow be verified
   (Part C / Phase 6).
4. Separately: file a follow-up task for the install-once self-heal defect in
   `loader.lua`/`merge.lua` (outside `agent-system/extensions/**`, so outside every task in this
   family's edit scope so far).

## Part A: Manual `<leader>al` Regeneration (Phase 5) — original procedure, for reference

**Why this cannot be automated**: see
`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` for the full
technical explanation. In short: `execute_sync` (the actual sync worker) is a module-local
closure with no exported entry point, and it is gated behind an unconditional `vim.fn.confirm()`
call. There is no headless/CI path -- a human must drive the interactive picker.

### Exact Procedure (repeat per repo)

1. Open Neovim with cwd at the target repo root. Do this in **nvim** first, then **at least one
   other repo** -- `~/.dotfiles` is confirmed (by the research this task is based on) to have the
   identical undeployed gap.
2. Press `<leader>al` (normal mode).
3. Select the **"Load All"** entry (the `is_load_all` special row) and press Enter.
4. At the `vim.fn.confirm()` dialog, choose **"Sync all (replace existing)"** (button 1,
   `&Sync all`).
   - **Do NOT** accept the default (Cancel).
   - **Do NOT** choose "Add new only" -- that skips re-copying already-stale files like
     `skill-base.sh`, `orchestrator-postflight.sh`, and `settings.json`, which is exactly the
     class of file this task fixed and needs redeployed.
5. Repeat steps 1-4 in `~/.dotfiles` (or another repo confirmed to have the same gap).

### Success Criteria (independently verifiable -- do not trust self-report)

Run these checks in each regenerated repo after step 4:

```bash
# 1. Events scripts exist
ls .claude/scripts/events-append.sh .claude/scripts/events-query.sh

# 2. Events hooks exist
ls .claude/hooks/events-log-artifact.sh .claude/hooks/events-log-lifecycle.sh

# 3. Schema/format docs exist
ls .claude/context/schemas/events-schema.json .claude/context/formats/events-format.md

# 4. Hook registrations are present in the deployed settings.json
jq '.hooks.Stop, .hooks.SubagentStop, .hooks.PostToolUse' .claude/settings.json
# -- should show the events hook command entries now that merge-sources/settings-hooks.json
#    declares them (Phase 7). The pre-existing duplicate claude-stop-notify.sh Stop-matcher entry
#    (confirmed live during Phase 3 verification) will NOT resolve from this regeneration alone --
#    the merge is add-only (see the CORRECTION note above); it needs a separate manual removal or
#    loader-side fix, tracked as a follow-up.

# 5. Doc-lint gate: core's FAILs should resolve, and the ADVISORY section should shrink
bash .claude/scripts/check-extension-docs.sh --quiet
# -- before regeneration: FAIL: 5 issue(s) found, plus a large "Core Deploy-Drift Advisory"
#    section (41 items as of this task's Phase 3 verification).
# -- after regeneration: the 5 pre-existing FAILs (skill-base.sh, orchestrator-postflight.sh,
#    check-extension-docs.sh, memory-harvest.sh, parse-command-args.sh content drift) should
#    resolve to 0, and the events-related advisory lines should disappear from the ADVISORY
#    section (some advisory lines for genuinely-unused extension scripts, e.g. zotero/literature
#    scripts this repo doesn't use, are EXPECTED to remain -- that is correct, not a bug).

# 6. Optional: confirm STRICT_CORE_DEPLOY=1 mode now returns a clean exit for the events files
#    specifically (it may still fail on legitimately-unused optional scripts):
STRICT_CORE_DEPLOY=1 bash .claude/scripts/check-extension-docs.sh --quiet 2>&1 | grep -c 'events-'
# -- should be 0 after a full "Sync all" regeneration.
```

`Lib: 0 | Tests: 0` (or similar zero-count self-load notices) appearing during regeneration is
**expected and already flagged elsewhere** -- not a new failure introduced by this task.

## Part B: Dotfiles Telemetry + Retention (scope 3/4 -- NOT edited by this task)

**This task deliberately did not edit `~/.dotfiles`.** The correct home for both settings is
`~/.dotfiles/config/claude/settings.json` (Home-Manager-managed, user-level, applies across every
repo -- not just this one). Apply this as a manual user step, or as a separate `~/.dotfiles`-repo
task, then run `home-manager switch`.

```json
"cleanupPeriodDays": 365,
"env": {
  "...": "existing keys unchanged",
  "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
  "OTEL_METRICS_EXPORTER": "console",
  "OTEL_LOGS_EXPORTER": "console"
}
```

**Never set `cleanupPeriodDays: 0`.** Per `anthropics/claude-code` issue #23710, `0` silently
**disables** transcript persistence entirely, contradicting what the docs imply -- it would
destroy the very 30-day transcript window this task exists to preserve. The documented default is
30 days; `365` is the recommended widened value.

The console exporter is chosen deliberately to avoid requiring collector infrastructure;
upgrading to an OTLP exporter is a reasonable follow-up, not a blocker for this handoff.

Do **not** add these settings to `agent-system/extensions/core/root-files/settings.json` in this
repo -- despite that file being in this task's `file_scope`, its `env` block is project-scoped
only and would miss cross-repo and ad-hoc invocations, which defeats the purpose of both settings.

## Part C: End-to-End Event-Flow Verification (Phase 6 -- [PARTIAL], re-verified)

**UPDATE (independently re-verified in a later session)**: Part A's regeneration ran, and real
usage has accumulated since. Re-checking against the live `specs/events.jsonl` (181 lines, ~61KB):

- `specs/events.jsonl` HAS grown with real lines from real `/plan`/`/implement` invocations
  post-regeneration -- **confirmed** (e.g. task 908's full plan/implement lifecycle, and this
  task's own preflight event, both timestamped after the regeneration).
- `check-extension-docs.sh` reports 0 FAILs for `core` in non-strict mode -- **confirmed**
  (`core: PASS`).
- At least one lifecycle event (preflight/postflight) has fired from a real command invocation
  post-regeneration -- **confirmed**.

**But this is not full end-to-end verification.** Every one of the 181 events is
`lifecycle_stage` (preflight/postflight) or `orchestrator_status` -- the pre-existing direct-call
channel, flowing since before this task started (earliest observed timestamp: 2026-07-15). **Zero**
`artifact`-category events and **zero** `session_stop`/`subagent_stop` event types exist anywhere
in the file. The specific new hooks this task's Phase 5 deploy was meant to activate
(`events-log-artifact.sh` via `PostToolUse`; `events-log-lifecycle.sh` via `Stop`/`SubagentStop`)
have never fired, in either repo -- because their `settings.json` registrations are the Part A gap
described above. Phase 6 is `[PARTIAL]`: do not infer full success from the pre-existing channel
alone. Once the `settings.json` merge defect is fixed and re-regenerated, re-run these same checks
and additionally confirm at least one `artifact`-category event and one `session_stop`/
`subagent_stop` event appear in `specs/events.jsonl`.

## Summary of What This Task Already Landed (for context)

- **Phase 1**: Replaced the `|| true` silent-fail idiom at all 10 verified `events-append.sh` call
  sites with an observable-but-non-fatal signal (stderr WARNING + `.claude/tmp/` sentinel marker),
  always returning 0 to the caller. Caught and fixed a real `set -e` correctness bug in the
  process.
- **Phase 2**: Added a nullable `cwd` field to `events-schema.json` (NOT `cc_session_id` --
  that belongs to an unfrozen sibling design) and threaded `--cwd` through `events-append.sh` and
  both events hooks; `events-query.sh` derives `repo` at query time as `basename(cwd)`.
- **Phase 3**: Extended `check-extension-docs.sh` with an ADVISORY (not hard-FAIL) lane surfacing
  core-extension never-deployed scripts/hooks and `settings.json` hook-registration gaps --
  ADVISORY rather than FAIL specifically so this doc-lint gate does not brick for every caller
  until the manual regeneration in Part A happens. An opt-in `STRICT_CORE_DEPLOY=1` env var
  promotes these to real failures for post-regeneration verification (see Part A, step 6).
- **Phase 4**: This document, plus
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`.
- **Phase 7** (later session): fixed the actual root cause of the Phase 5 `settings.json` gap --
  added the three missing hook registrations (`PostToolUse`/`events-log-artifact.sh`,
  `Stop`/`events-log-lifecycle.sh`, `SubagentStop`/`events-log-lifecycle.sh`) to
  `merge-sources/settings-hooks.json`, the file the merge step actually reads, each as its own
  dedicated single-command matcher object for idempotency under `deep_merge`'s object-level dedup.
  Corrected the prior "merge routine is broken" framing -- see the CORRECTION note above and the
  plan's Phase 7 for the full three-cause diagnosis and verification transcript. Does not deploy
  anything by itself; Part A's regeneration must still be re-run.

All of the above are source-store edits under `agent-system/extensions/core/**`, verified by
running the modified scripts (not merely reading them) against present/absent/failing-helper
harnesses and, for Phase 3, against the live still-stale `.claude/` tree. None of it claims that
live event flow works today -- that claim can only be made after Parts A and C above.
