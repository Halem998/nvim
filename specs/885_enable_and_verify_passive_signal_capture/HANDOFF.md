# Handoff: Manual Regeneration + Dotfiles Telemetry/Retention

This document is the durable, user-executable handoff for the two genuinely gated remainders of
task 885 (`enable_and_verify_passive_signal_capture`). Everything else the task could land today
(Phases 1-4: observable-failure fix, nullable `cwd` schema field, core deploy-drift ADVISORY gate,
and this document) is committed. **Phases 5 and 6 below are [BLOCKED] and require action outside
this session.**

## Part A: Manual `<leader>al` Regeneration (Phase 5)

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
# -- should show the events hook command entries; the pre-existing duplicate
#    claude-stop-notify.sh Stop-matcher entry (confirmed live during Phase 3 verification)
#    should be resolved to a single registration after regeneration.

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

## Part C: End-to-End Event-Flow Verification (Phase 6 -- doubly gated, [BLOCKED])

Once Part A's regeneration is done, event flow is **still not verified** -- it is gated a second
time on accumulated real usage:

- `specs/events.jsonl` must be observed to actually **grow** with real lines from real
  `/research`, `/plan`, or `/implement` invocations post-regeneration -- not merely that the file
  exists.
- `check-extension-docs.sh` should report 0 FAILs for `core` (see Part A's success criteria).
- At least one lifecycle event (preflight/postflight/Stop) must be observed to have actually fired
  from a real command invocation, post-regeneration.

**Do not infer success from the source-code changes alone.** This task's implementation phases
(1-4) are all source-store edits, individually verified by running the modified scripts in a
sandboxed, deploy-shaped tree -- but that is verification of the CODE, not of live event flow in
a regenerated, real-world repo. Only accumulated real usage after Part A can verify the latter.

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

All of the above are source-store edits under `agent-system/extensions/core/**`, verified by
running the modified scripts (not merely reading them) against present/absent/failing-helper
harnesses and, for Phase 3, against the live still-stale `.claude/` tree. None of it claims that
live event flow works today -- that claim can only be made after Parts A and C above.
