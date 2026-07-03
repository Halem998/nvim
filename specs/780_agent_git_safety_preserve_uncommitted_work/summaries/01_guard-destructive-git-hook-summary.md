# Implementation Summary: Task #780

**Completed**: 2026-07-03
**Duration**: ~5 hours (5 phases)

## Overview

Implemented the full "no destructive git on uncommitted work" safety mechanism: a
snapshot helper (`git-snapshot.sh`), a PreToolUse Bash hook
(`guard-destructive-git.sh`) that blocks destructive git commands on a dirty tree,
and a `git-workflow.md` rule extension documenting the policy. All three artifacts
were dual-deployed (`.claude/` + `.claude/extensions/core/`) and wired into both
`settings.json` copies and the core manifest so the change cannot be silently
reverted by a future sync, as previously happened to `block-pr-submission.sh`.

## What Changed

- `.claude/scripts/git-snapshot.sh` — new helper. Clean-tree no-op; default mode
  writes a durable `working-progress-{ts}.patch` under the task dir (captured to a
  scratch `mktemp` file first, then moved into place *after* the stash step — doing
  it before would let `git stash push -u` sweep the newly-written patch file itself)
  plus a `git stash push -u` belt-and-suspenders backup; `--branch` mode creates a
  WIP commit on a `wip-snapshot-{ts}` scratch branch and returns to the original
  branch. Writes/refreshes the `.git-snapshot-marker` freshness marker.
- `.claude/hooks/guard-destructive-git.sh` — new PreToolUse Bash hook, modeled on
  `block-pr-submission.sh`. Reads `tool_input.command` from stdin JSON; exits 0 on
  empty command or clean tree; matches anchored `grep -qE` patterns for
  `git reset --hard`, `git checkout -- <path>`, `git restore <path>` (without
  `--staged`), `git clean` with both `-f` and `-d` (any order/clustering), 
  `git stash drop`/`clear`, and forced `checkout`/`switch` (`-f`/`--force`); does
  NOT match `git stash` (push), `stash pop`/`apply`, or `git restore --staged`. On
  a dirty-tree match, checks `find specs -maxdepth 3 -name .git-snapshot-marker`
  for the freshest (<=120s) marker, consumes (deletes) it and exits 0 if fresh,
  otherwise exits 2 with a stderr message naming `git-snapshot.sh` as the remedy.
- `.claude/rules/git-workflow.md` — replaced the blanket "Never Run: git reset
  --hard" line with a "No Destructive Git on Uncommitted Work" section: the six
  forbidden command classes, the clean-tree/fresh-snapshot exemption, the
  `/todo` safety-commit exemption note, and a cross-reference to the hook.
- `.claude/extensions/core/hooks/guard-destructive-git.sh` — byte-identical
  extension-source copy of the hook.
- `.claude/extensions/core/scripts/git-snapshot.sh` — byte-identical
  extension-source copy of the helper.
- `.claude/extensions/core/rules/git-workflow.md` — byte-identical
  extension-source copy of the rule.
- `.claude/extensions/core/manifest.json` — added `guard-destructive-git.sh` to
  `provides.hooks` and `git-snapshot.sh` to `provides.scripts`.
- `.claude/settings.json` and `.claude/extensions/core/root-files/settings.json` —
  appended a `PreToolUse` `"matcher": "Bash"` entry invoking
  `bash .claude/hooks/guard-destructive-git.sh`, preserving the existing `Write`
  matcher entry.
- `.gitignore` — added `**/.git-snapshot-marker`.

## Decisions

- **Patch-write ordering in `git-snapshot.sh`**: the diff is captured to a scratch
  `mktemp` file (outside the repo) and moved into the task directory only *after*
  the stash/branch step. Writing it directly under the task dir first would make
  it an untracked file that `git stash push -u` immediately sweeps away (and can
  delete an otherwise-empty task directory), breaking the subsequent marker write.
  Discovered and fixed via smoke testing in a disposable `/tmp` repo.
- **`git stash push -u`** (untracked-inclusive): added beyond the plan's literal
  wording to ensure untracked new files are captured by the belt-and-suspenders
  stash backup, not just the tracked-file diff.
- **`git clean -f`+`-d` detection**: implemented as flag-order/clustering-agnostic
  (matches `-fd`, `-df`, `-f -d`, `-xfd`, `--force -d`, etc.) rather than a fixed
  literal string, per the plan's explicit requirement.

## Plan Deviations

- **Task 4 (settings.json registration)** altered: the plan's literal command text
  was `bash .claude/hooks/guard-destructive-git.sh 2>/dev/null || echo '{}'`,
  matching the convention used by other *advisory* (permissionDecision-JSON) hooks
  already in `settings.json`. This convention is incompatible with an exit-code +
  stderr **blocking** hook: in bash, `cmd 2>/dev/null || echo '{}'` always yields
  exit 0 for the composite command (since the `echo` fallback succeeds), which
  would silently discard both the hook's deliberate `exit 2` block signal and its
  stderr corrective message — turning the entire safety mechanism into a
  permanent no-op. Registered instead as plain
  `bash .claude/hooks/guard-destructive-git.sh` (no redirection, no fallback),
  which preserves both the exit code and stderr, matching the blocking mechanism
  `block-pr-submission.sh`'s own header comment describes. This was verified
  necessary by reasoning through bash `||` semantics and is the single most
  important correctness fix in this implementation — a literal reading of the
  plan text would have shipped a hook that never actually blocks anything.

No other deviations; all other plan steps were followed as written.

## Verification

- Build: N/A (bash scripts + markdown + JSON config)
- Tests: Passed — full scenario matrix (14+ block/allow cases, marker
  fresh/stale/consumption semantics, `/todo` safety-commit flow, dual-copy
  diff/jq integrity checks) run in disposable `/tmp` git repos; see phase 2 and
  phase 5 progress files for the itemized list.
- Files verified: Yes — all `diff` checks between deployed and extension-source
  copies are empty; both `settings.json` copies confirmed via `jq`; both manifest
  `provides` lists confirmed via `jq`; `.gitignore` confirmed via `grep`.
- **Live registration confirmed**: mid-implementation, a Bash tool call in this
  very session was intercepted and blocked by the newly-registered
  `guard-destructive-git.sh` hook when a test script literally contained
  `git clean -qfd`, since this repository's actual working tree is genuinely
  dirty with uncommitted work from other parallel agents. This is definitive
  end-to-end proof of enforcement, not merely structural presence in
  `settings.json`.
- No destructive git command was run against this repository's actual working
  tree at any point during implementation or verification; all destructive-command
  testing used disposable `/tmp` git repos or crafted JSON piped directly to the
  hook script.

## Notes

- The hook's clean-tree-first check auto-exempts the sanctioned `/todo`
  safety-commit + `git reset --hard`/`git clean -fd` rollback flow
  (`.claude/context/standards/git-safety.md`), since the safety commit makes the
  tree clean before the destructive step runs. Verified explicitly in Phase 5.
- Restoring `block-pr-submission.sh`'s own broken wiring was out of scope
  (plan non-goal) and was not touched.
- `merge-sources/settings-hooks.json` (the WezTerm-lifecycle-only deep-merge
  fragment used for propagating hooks into *other* repos during "Load Core") was
  intentionally left untouched — it is scoped narrowly to SessionStart/Stop/
  UserPromptSubmit and is out of scope for this task per the plan's explicit
  Phase 4 file list and the territory constraint for this dispatch.
