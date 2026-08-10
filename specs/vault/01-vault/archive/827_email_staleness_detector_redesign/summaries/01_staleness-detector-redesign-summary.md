# Implementation Summary: Task #827

**Completed**: 2026-07-13
**Duration**: ~45 minutes

## Overview

Redesigned the `/email` staleness detector from an unreachable strict-equality freshness gate
(on-disk maildir FILE count vs a deduped notmuch MESSAGE count) into a reachable, internally
consistent file-vs-file comparison with a bounded tolerance and an informational reindex-ran
marker. All seven plan phases completed: the new semantics were defined once in the authoritative
design doc, propagated to the cross-repo Nix implementation and every enumerated in-repo doc/skill
site, verified live to reach `[ok]` for both Gmail and Logos on the current mailbox, and the two
independent out-of-scope anomalies were handed off as follow-up recommendations.

## What Changed

- `.claude/extensions/email/context/project/email/domain/staleness-detection.md` — rewrote
  "Ground truth vs. index" to state the file-vs-file model; added a subsection documenting the
  `notmuch(1)` `--output=files` cross-folder/cross-account duplicate-inclusion quirk (man-page
  behavior + verified numbers: `folder:Gmail --output=files`=238 vs 128 real files;
  `folder:Logos`=403 with 84 outside `Logos/{cur,new}`); defined the tolerance rule
  `Δ = |on-disk − indexed-files|`, `T = max(5, ceil(0.10 × on-disk))`; defined the reindex-ran
  marker; fixed the canonical freshness-line format string; updated the end-to-end flow diagram
  and live-example numbers (both accounts now `[ok]`).
- `~/.dotfiles/modules/home/email/agent-tools/census.nix` (cross-repo, **written only, not
  built/committed**) — replaced the freshness block with the new (a) path-prefix post-filtered
  file-vs-file count, (b) bounded-tolerance comparison, (c) reindex-marker read, emitting the new
  canonical `printf` line. Nix `''${...}` interpolation escaping preserved.
- `~/.dotfiles/modules/home/email/mbsync.nix` (cross-repo, **written only, not built/committed**)
  — added the reindex-ran marker write (`mkdir -p .../email-agent && date -Iseconds >
  .../email-agent/last-reindex`) to the `email-reindex` definition, after `notmuch new
  --no-hooks`. Cross-checked `email-freeze`/`email-thaw` messaging — no old-semantics wording
  found, no changes needed there.
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (§13) — updated
  the frozen-fact "Freshness disclosure" restatement to the new file-vs-file + tolerance +
  marker + canonical line format; replaced the `on-disk == notmuch-indexed` pass condition with
  `Δ ≤ T`; added the one-line note that `email-reindex` now also writes the marker.
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — updated the Stage 1 "Census +
  Staleness Gate" section to parse the new line and apply the tolerance pass condition; described
  `reindex=<ISO|never>` marker semantics and the autonomous-mode `reindex=never` (STOP) vs
  `reindex=<ISO>` (report persistent residual, don't loop) branching; updated the "Staleness
  Remediation" section to match; kept the "line absent" unverified-coverage fallback wording.
- `.claude/extensions/email/EXTENSION.md`, `README.md`, `commands/email.md` (two sites),
  `index-entries.json` — updated summary/description wording from "on-disk vs notmuch-indexed"
  equality language to file-vs-file + bounded-tolerance language; corrected stale `line_count`
  fields for `staleness-detection.md` (72→134) and `wrapper-contracts.md` (322→335).
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — re-verified per
  plan; no equality-semantics wording found, no change needed.

## Decisions

- Task creation for the two Phase-7 follow-ups was NOT performed via `/task`/`/spawn` (see Plan
  Deviations) — the plan's own Phase 7 spec ("Files to modify: none... task creation is a
  follow-up action") anticipates recording recommendations rather than mandatory live task
  creation, and `/task`'s interactive confirmation gate isn't available to this agent.
- No cross-repo build/VCS operation was run at any point (`home-manager switch`,
  `nixos-rebuild`, `nix flake check`, `git commit`/`push` in `~/.dotfiles`) — per the hard
  constraint, the census.nix/mbsync.nix edits were written via `Edit` only and are left for the
  user to review, rebuild, and commit/push in `~/.dotfiles` at their discretion.
- Live verification used the plan's standalone read-only shell snippet (evaluating the new
  comparison directly against `himalaya`/`notmuch`) rather than the installed `email-census`,
  because the installed binary won't reflect the census.nix edit until the user runs
  `home-manager switch`.

## Live Verification Results (2026-07-13, current mailbox)

```
Gmail  on-disk=128 indexed-files=128 divergence=0  tol=13 [ok]
Logos  on-disk=341 indexed-files=319 divergence=22 tol=35 [ok]
```

Both accounts reach `[ok]` under the new gate — matching the plan's expected numbers exactly.
The reindex-marker path (`~/.local/state/email-agent/last-reindex`) does not yet exist on this
machine; it will be created by the next `email-reindex` run once the cross-repo edit is deployed.

**User action required to deploy**: run `home-manager switch --flake .#<user>` in `~/.dotfiles`
to activate the `census.nix`/`mbsync.nix` changes, then re-verify with a live `email-census
--account <acct>` run for both accounts. Until that rebuild happens, the currently-installed
`email-census` binary still runs the OLD equality-gate logic — only the read-only standalone
snippet above reflects the new logic today.

## Plan Deviations

- **Task 7.1 / 7.2** altered: the two follow-up recommendations (below) were recorded in this
  summary rather than created as live `/task`/`/spawn` task entries in `state.json`/`TODO.md`.
  Reason: `/task` requires an interactive `AskUserQuestion` confirmation gate not available to
  this non-interactive implementation agent, and the plan's Phase 7 "Files to modify: none"
  clause already anticipates a recommendation-only completion path.

## Follow-Up Recommendations (Phase 7 — NOT fixed in this task)

### 1. 22 unindexed Logos files (independent anomaly, Finding 3)

22 files physically present in `~/Mail/Logos/cur` since 2026-07-06 (coinciding with the
task-826/828 maildir reclone + UID-collision repair) are completely absent from the notmuch
index — confirmed via `notmuch count 'id:<message-id>'` returning 0 for their extracted
Message-IDs. Diagnostic dead-ends already ruled out, so a future investigator should NOT repeat
them:
- Two sanctioned `email-reindex` (`notmuch new --no-hooks`) runs, including one after forcing
  `Logos/cur`'s directory mtime forward, both reported "No new mail" / unchanged message count.
- `new.ignore` patterns in notmuch config ruled out as the cause.
- Hardlink/inode-based deduplication ruled out.
- File mtimes (2026-07-06) line up with the task-826/828 reclone + UID-collision repair, which is
  the leading hypothesis for root cause but was not investigated further here (out of scope).

Recommended action: create a follow-up task (via `/spawn 827` or `/task`) scoped to root-causing
and fixing this notmuch indexing gap. This task's tolerance-based gate (`T ≈ 35` for Logos today)
makes the anomaly non-blocking in the interim, but the threshold should be tightened once this
follow-up resolves it (per staleness-detection.md's tolerance-rationale note).

### 2. `--account` positional-argument bug (Finding 5)

`email-census` (and all five wrapper binaries) silently discards a positional account argument —
only `--account <val>` is honored, e.g. `email-census gmail` silently defaults to gmail regardless
of the positional arg's actual value. Root cause is in the shared, frozen
`~/.dotfiles/modules/home/email/agent-tools/lib.nix` `mkPreamble` arg-parsing loop, which all six
operator helpers (five wrapper binaries + `email-census`) share.

Recommended action: create a follow-up task (via `/spawn 827` or `/task`) to fix the positional-arg
parsing in `mkPreamble`. Deliberately deferred from this task to preserve scope discipline around
the frozen, widely-shared preamble — a fix there has blast radius across all six operator helpers
and deserves its own dedicated verification pass, not a drive-by edit inside a freshness-gate
redesign task.

## Verification

- Build: N/A (Nix files written, not built — cross-repo build/VCS operations explicitly out of
  scope per hard constraint)
- Tests: N/A (no automated test suite for this doc/skill/Nix content; live read-only verification
  performed instead — see "Live Verification Results" above)
- Files verified: Yes — all edited files read back / grepped to confirm expected content

## Notes

- All seven plan phases are `[COMPLETED]`; the plan's top-level Status is `[COMPLETED]`.
- The cross-repo `census.nix`/`mbsync.nix` edits remain uncommitted in `~/.dotfiles` (a separate
  git repository) — the user should review, `home-manager switch`, and commit/push there at their
  own discretion. No `home-manager switch`, `nixos-rebuild`, `nix flake` rebuild, or `git
  commit`/`push` was run in `~/.dotfiles` by this agent.
- No mail was mutated at any point; all verification used read-only `himalaya envelope list` and
  `notmuch search --output=files` / `notmuch count` calls.
