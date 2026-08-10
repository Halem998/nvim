# Research Report: Task #1015

**Task**: 1015 - Re-check settings.local.json deploy merge for content loss before any fix effort
**Started**: 2026-08-10T18:26:00Z
**Completed**: 2026-08-10T19:10:00Z
**Effort**: Medium (code trace + 12-pair empirical sampling in an isolated scratch copy)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/deploy-headless.sh`, `lua/neotex/plugins/ai/shared/extensions/{init,merge,settings_backup,config}.lua`
- Git history of `lua/neotex/plugins/ai/shared/extensions/init.lua`
- `specs/errors.json` entries `err_1786350581208_23mAsn` (this task's source) and `err_1786350581240_JyztWt` (related, separate)
- Empirical: 12 wipe-pairs (24 `--wipe` invocations) run against an isolated scratch copy of the repo, never the live `.claude/` tree
**Artifacts**:
- This report: `specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Reproduction rate: 0 of 12** wipe-pairs (24 `--wipe` runs) showed any dropped block in
  `settings.local.json`, across sequential-continuation runs and six deliberately varied
  pre-existing-state variants (including a pre-scrambled key order and a ~2.5x-bloated file).
  Combined with task 996's prior 0-of-3, the cumulative non-reproduction rate is **0 of 15**
  across two independent re-check rounds.
- Every observed byte-level difference across all 12 pairs was pure JSON key/array **reordering**
  (Lua's `pairs()` iteration order is nondeterministic across process runs) — never a missing
  key, missing array element, or missing block. This is the same class of issue already tracked
  separately (low severity, ordering-only) and is architecturally distinct from content loss.
- **No correlation found** between pre-existing `settings.local.json` state, size, or ordering
  and any loss — every variant tested, including one that pre-seeded a duplicate `PreToolUse`
  matcher block (the exact shape the matcher-merge logic exists to heal), round-tripped
  losslessly.
- **A plausible root cause for the original single observation was identified in code history**:
  commit `1692e33e8` ("task 980 phase 5: correct the regenerate sequence", 2026-08-05) fixed an
  ordering bug in `manager.regenerate` where settings restoration used to happen *after* the
  extension reload loop instead of *before* it — a bug shape that would produce exactly a dropped
  `hooks.PreToolUse` block and dropped `mcpServers` block, matching the original observation. The
  current code (post-fix) restores settings before the reload loop, and this task's sampling is
  consistent with that fix being effective.
- **Recommendation**: downgrade `err_1786350581208_23mAsn` from `high` to `low` (same tier as the
  sibling ordering-only issue) given 0/15 cumulative reproduction, record the sample size and the
  code-history finding, and close pending only the narrow residual noted below. **No merge logic
  was changed** — this task was scoped as verification-only per its instructions.

## Context & Scope

Task 1015 is a deliberate re-check, not a fix task. The originating error
(`err_1786350581208_23mAsn`, severity `high`) records a single historical observation of a
content-lossy `settings.local.json` merge across a `deploy-headless.sh --wipe` pair — a dropped
`hooks.PreToolUse` block and a dropped `mcpServers` block — and a prior re-check (task 996, Phase
1) that ran 3 further wipe-pairs and found 0/3 reproduction, all differences being ordering-only.
This task's job was to run a substantially larger sample (10+), compare both semantically
(`jq -S`) and structurally (explicit key/block presence, not raw diff), check for correlation
with pre-existing file state, and record a stated reproduction rate either way — without touching
merge logic.

**Safety constraint honored**: `deploy-headless.sh --wipe` rewrites a target repo's whole
`.claude/` tree via `rm -rf` + regenerate. All sampling in this task ran against an **isolated
scratch copy** of the repository (`/tmp/.../scratchpad/wipe-test-repo`, outside the live tree),
never the operator's live `~/.config/nvim/.claude/`. This is detailed under Methodology and
verified in the Appendix.

## Findings

### Code Trace: How `--wipe` Handles `settings.local.json`

`deploy-headless.sh --wipe` invokes `manager.wipe()` in
`lua/neotex/plugins/ai/shared/extensions/init.lua`, which runs, in order:

1. `settings_backup.backup()` — snapshots `settings.json`, `settings.local.json`, and every
   `.syncprotect`-listed path to a project-root staging directory (`.claude-settings-backup/`).
   `pcall`-wrapped; refuses the whole wipe (leaving `base_dir` untouched) if the snapshot fails.
2. `vim.fn.delete(target_dir, "rf")` — the destructive `rm -rf .claude`.
3. `manager.regenerate()`, which itself:
   a. **Restores** the staged `settings.json`/`settings.local.json`/protected paths from the
      snapshot — **before** the reload loop (this ordering is load-bearing; see below).
   b. Calls `manager.resync_all()`, which force-reloads every formerly-active extension in
      dependency order. Each extension's `merge_settings()` (in `merge.lua`) deep-merges its
      settings fragment into the now-restored `settings.local.json`, additively: scalars are only
      added if absent (never overwrite), arrays are appended with `vim.deep_equal` dedup, and
      Claude Code hook-event arrays (`PreToolUse`, `Stop`, etc.) get dedicated matcher-aware
      merge logic (`merge_hook_event_array`/`normalize_hook_event_array`) that also heals
      pre-existing duplicate-matcher blocks rather than losing hooks to whole-item comparison.
4. Staging is cleared only after every staged file restores successfully.

The doc comment directly above `manager.regenerate` names an **"ordering fix (the bug this
function used to have)"**: restoring the settings snapshot *after* the reload loop — the
historical behavior — "clobbered any settings-fragment merge the loop's own extension loads had
just performed, silently losing newly registered merge-source hook registrations across every
wipe+regenerate cycle." That is precisely the failure shape described in the original single
observation (a dropped `hooks.PreToolUse` block and a dropped `mcpServers` block).

**This bug was fixed in commit `1692e33e8`** ("task 980 phase 5: correct the regenerate
sequence", 2026-08-05), which moved the restore step to before the reload loop. The code running
today (and exercised by this task's sampling) is the post-fix version. This gives a concrete,
falsifiable hypothesis for the original observation: it is plausibly a symptom of the pre-fix
ordering bug, encountered on a checkout predating (or otherwise not benefiting from)
`1692e33e8`, rather than an unexplained intermittent defect in the current code.

### Methodology (Empirical Sampling)

All sampling ran against an isolated scratch copy, constructed as follows:
- `cp -a .claude` (the live deploy tree, including a realistic `settings.local.json` with a
  `PreToolUse` hook, two `mcpServers` entries, `permissions.allow/deny`, `enabledMcpjsonServers`,
  etc.) plus `.claude-extensions.json` (project-root extension-selection manifest) and
  `.syncprotect`, copied into a scratch directory under the session's scratchpad.
- `git init` in the scratch directory only (a fresh, history-less repo — `deploy-headless.sh`
  only requires a valid `.git` dir to pass its "is this a git repo" guard).
- Confirmed this is safe because `global_extensions_dir` (the source of extension manifests read
  during reload) defaults to `~/.config/nvim/agent-system/extensions` **unconditionally**,
  independent of the target repo — so the scratch target never needed a copy of `agent-system/`
  or `lua/`, and every wipe against it reads the live source store read-only while writing
  exclusively under the scratch target's own `.claude/`.

12 wipe-pairs (24 total `--wipe` invocations, each ~0.8s) were run:
- **5 sequential-continuation pairs** — no reset between pairs, each pair's output feeding the
  next, mirroring repeated real-world redeploys over time.
- **7 reset-and-vary pairs** — `.claude/` reset to the pristine baseline before each pair, then
  one of six pre-existing-state variants applied to `settings.local.json` before the pair's first
  wipe: `baseline` (x2, control), `extra_permissions` (added two allow entries), `reordered_keys`
  (top-level and nested keys rewritten in reverse-alphabetical order), `large_content` (200 extra
  `permissions.allow` entries, ~2.5x baseline size), `minimal` (stripped to only `hooks` and
  `mcpServers`), `duplicate_hook_matcher` (pre-seeded a second `PreToolUse` block with the same
  `Bash` matcher, deliberately exercising the matcher-merge/normalize code path).

Each pair was compared three ways:
1. **Semantic** — `jq -S` (recursively sorted keys) then hashed; equal hashes mean
   value-for-value identical content regardless of ordering.
2. **Structural** — an explicit presence check on `hooks.PreToolUse`, `hooks.Stop`, `mcpServers`,
   `permissions.allow`, `permissions.deny`, `enabledMcpjsonServers`: flags a key/block that was
   non-empty in run 1 and either absent or emptied in run 2. This detector was validated with a
   **positive control** (synthetically deleting `hooks.PreToolUse` and `mcpServers` from a copy)
   before trusting its "0 dropped" results — it correctly flagged both in the control test.
3. **Raw byte diff** (for spot-checking) — confirmed on several pairs that all differences were
   pure key-order/array-order permutation, never a missing line.

### Results

| Metric | Result |
|---|---|
| Wipe-pairs run | 12 (24 `--wipe` invocations) |
| Semantic equality (`jq -S` hash match) | 12 / 12 |
| Structural drops detected (validated detector) | 0 / 12 |
| Pairs with byte-level reordering only | 12 / 12 (every pair) |
| Correlation with pre-existing size/order/state | None found across 6 variants |

Cumulative with task 996's prior round: **0 of 15** wipe-pairs across two independent re-check
efforts have reproduced the original single observation.

### External Resources

Not applicable — this is a pure codebase/empirical verification task; no external
documentation was needed.

## Decisions

- **No merge logic was changed.** Per the task's explicit instruction, this was a
  verification-only pass; the ordering-fix already present in the code (commit `1692e33e8`) was
  read and cited as a plausible explanation, not modified or re-verified beyond code reading.
- **Sampling was run exclusively against an isolated scratch copy**, never the live
  `~/.config/nvim/.claude/` tree, per the task's safety note. See Appendix for the live-tree
  integrity check performed after sampling.
- **Recommend severity downgrade** of `err_1786350581208_23mAsn` from `high` to `low` (matching
  the sibling ordering-only entry `err_1786350581240_JyztWt`), with the 0/15 cumulative
  reproduction rate and this task's 12-pair sample recorded in the downgrade rationale, and the
  ticket closed. This report does not itself edit `specs/errors.json`; that update is left to the
  orchestrating command/postflight step per this agent's role boundary (research only).

## Risks & Mitigations

- **Residual risk not exercised by this sampling: concurrent access.** `deploy-headless.sh`'s
  `specs/.deploy-lock` mutex is explicitly documented as fail-open/non-blocking — a concurrent
  `--wipe` (or a concurrent hand-edit of `settings.local.json`) racing an in-flight wipe "could
  corrupt the `.claude/` tree" per the script's own comments. All 12 pairs in this task ran
  strictly serially in a single process against an idle scratch target, so this sampling cannot
  rule out a genuinely concurrency-triggered loss. If the original single observation occurred
  under concurrent agent activity (plausible in this repo's multi-agent orchestration model),
  that remains an untested, narrower hypothesis distinct from "the merge logic loses content on
  a plain repeated wipe," which this task's 0/15 result does rule out with reasonable confidence.
- **Ordering non-determinism remains real** (all 12 pairs exhibited it) but is tracked separately
  as `err_1786350581240_JyztWt` (low severity, cosmetic) and is out of scope for this task's
  content-loss question.
- **Mitigation for the residual concurrency hypothesis**: no action taken here (verification-only
  scope). If it recurs, the useful next re-check would specifically interleave a `--wipe` with a
  concurrent second `--wipe` or a concurrent settings edit against the same target, which this
  task's serial sampling deliberately did not attempt.

## Context Extension Recommendations

None — this is a `meta` task type; the existing `source-store-deploy-boundary.md` rule and the
`init.lua`/`merge.lua`/`settings_backup.lua` code comments already document the relevant
mechanism thoroughly. No new context file gap was identified.

## Appendix

### Search Queries / Commands Used

- Code trace: `Read` on `deploy-headless.sh`, `init.lua`, `merge.lua`, `settings_backup.lua`,
  `config.lua`; `git log -p --follow -- lua/neotex/plugins/ai/shared/extensions/init.lua | grep -n "Ordering fix" -A2 -B30` to locate and date the ordering-fix commit.
- Sampling harness: a bash script (`run-wipe-pairs.sh`, written to the session scratchpad, not
  committed to the repo) drove the 12 wipe-pairs against the scratch target, comparing each pair
  via `jq -S` hashing and an explicit structural presence check.
- Positive-control validation of the structural detector: synthetic deletion of `hooks.PreToolUse`
  and `mcpServers` from a copy, confirmed both were flagged.

### Live-Tree Integrity Verification (post-sampling)

Performed after all 24 wipe invocations completed, to confirm the live deploy tree was never
touched by this task's sampling:
- `.claude/settings.local.json` size/mtime/checksum in the live tree were unchanged from before
  sampling began.
- `specs/.deploy-lock` does not exist in the live tree (no deploy-lock mutex was ever acquired
  against the live target — confirming no `--wipe` ran against it).
- Live git `HEAD` and `git status --short` matched the pre-task baseline.

**Self-correction note (transparency)**: during scratch-environment setup, a shell `cd` into the
not-yet-created scratch directory silently failed (the prior command that would have created it
was blocked by a `git add -A` guard hook before any of its steps ran), causing a subsequent `git
add`/`git commit` to execute against the live repository's working directory instead of the
intended scratch target. This produced one spurious commit on the live `master` branch
(`.claude-extensions.json` reordering only — no data loss, no content change beyond key order).
It was immediately detected and reverted via `git reset --soft HEAD~1` followed by
`git restore --staged .claude-extensions.json`, fully restoring the live repository to its
pre-task state (verified above). All subsequent scratch-setup and sampling commands used
explicit absolute paths and `git -C <path>` to avoid depending on shell `cd` state, and no
further incidents occurred across the 24 wipe invocations.
