# Implementation Plan: Task #852

- **Task**: 852 - Investigate 22 Logos INBOX files that notmuch never indexes
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: 827 (completed — parent staleness-detector research), 826/828 (completed — Logos reclone that introduced the anomaly)
- **Research Inputs**: specs/852_investigate_logos_unindexed_files/reports/01_notmuch-unindexed-files-root-cause.md
- **Artifacts**: plans/01_reindex-unindexed-logos-fullscan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: email
- **Lean Intent**: false

## Overview

Research root-caused why 22 Logos INBOX files (`~/Mail/Logos/cur`, delivered 2026-07-06 09:21:13-14
PDT) were never indexed by notmuch: `logos-reclone.sh` step 7 called a raw `notmuch new` (missing
`--no-hooks`), whose own `pre-new` hook (`mbsync gmail logos`) delivered the 22 files and then
failed, racing/short-circuiting notmuch's directory scan and advancing per-directory scan
bookkeeping past the files without ever parsing them. The single untested, most-targeted
remediation is `notmuch new --no-hooks --full-scan` (disables notmuch's mtime scan-skip
optimization). This plan captures a read-only baseline, runs that index-only remediation, verifies
the 22 files become queryable while the mail files on disk stay untouched, and prepares (but does
NOT apply) a `logos-reclone.sh` patch to use `--no-hooks` so the hook-race cannot recur.
Definition of done: the 22 files are queryable in notmuch, no mail file was mutated, and a
recurrence-prevention patch proposal is handed to the user for application in `~/.dotfiles`.

### Research Integration

Key findings integrated from `reports/01_notmuch-unindexed-files-root-cause.md`:
- The 22 anomaly files share a delivery signature (mtime `2026-07-06 09:21:13`/`:14`, filename
  `1783354873.4003086_<N>.hamsa,U=<N>:2,` / `1783354874.4003086_<N>.hamsa,U=<N>:2,`, UIDs 145-305);
  the full Message-ID/From/Subject list is in the report Appendix and drives baseline verification.
- Zero-hit whole-database search (`notmuch search --output=files '*' | grep <token>`) confirmed the
  files are unknown to notmuch under any query — there is no message document to repair, only
  scan bookkeeping to reset.
- Task 827's `touch`-then-`notmuch new --no-hooks` workaround (mtime-forcing only) did NOT clear
  the block, which is why `--full-scan` (documented in `notmuch-new(1)` to disable the scan-skip
  optimization wholesale) is the correct next step and is index-only (no mail mutation).
- `~/.dotfiles` `wrapper-contracts.md` already forbids raw `notmuch new`; `logos-reclone.sh` line 92
  (`run "notmuch new"`) violated that invariant and is the concrete origin event.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no `roadmap_path` provided and no roadmap flag). No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Get the 22 previously-unindexed Logos INBOX files indexed and queryable in notmuch.
- Use the sanctioned, index-only remediation `notmuch new --no-hooks --full-scan` (no hooks, no
  mbsync, no mail mutation).
- Verify success by confirming the 22 files/Message-IDs are queryable after the full-scan.
- Confirm the mail files on disk are untouched (indexing only — content and file set unchanged).
- Prepare a recurrence-prevention patch for `logos-reclone.sh` (switch its reindex step to
  `--no-hooks`) and hand it to the user for application.
- Optionally record the specific hook-race hazard in this repo's `wrapper-contracts.md`.

**Non-Goals**:
- Running `home-manager switch`, committing, or pushing in `~/.dotfiles` — the user applies those.
- Mutating any mail file, running `mbsync`, or running a raw (hooked) `notmuch new`.
- Xapian-level database surgery (`notmuch dump`, Xapian delve) — only escalated as a follow-up if
  `--full-scan` does not close the gap (see Rollback/Contingency).
- Resolving the 5 secondary very-recent unindexed files (2026-07-11 / 2026-07-13); those are
  ordinary staleness and clear on the next routine `email-reindex` (noted, not remediated here).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--full-scan` still fails to index the 22 files (deeper Xapian directory-record inconsistency) | H | L | Phase 3 checks explicitly; if unresolved, do NOT escalate inline — record outcome and recommend a follow-up Xapian-level task (Rollback/Contingency) |
| Accidentally running a hooked `notmuch new` (triggers `mbsync gmail logos`, repeats the race) | H | L | Every command in this plan uses `--no-hooks` explicitly; Phase 2 command is fixed verbatim and reviewed before running |
| Live `logos-reclone.sh` not present in `~/.dotfiles` (only the backup copy exists) | L | M | Phase 4 first locates the live script; if absent, produce the patch against the backup copy as a reference artifact and note it for whenever a reclone script is next authored |
| Mail files inadvertently modified | H | L | Phase 1 records on-disk file count + a checksum/mtime snapshot; Phase 3 re-checks them unchanged |
| Cross-repo change applied by agent instead of user | M | L | Plan produces a diff/patch text only; no `~/.dotfiles` write, no rebuild, no commit/push |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture read-only baseline of the 22 unindexed files [COMPLETED]

**Goal**: Establish the pre-remediation before-state so success is objectively measurable, without
mutating anything.

**Tasks**:
- [x] Extract the 22 target filenames + Message-IDs from the research report Appendix into a
      working list (e.g. `/tmp/852-targets.txt`). *(completed: 22 filenames extracted via grep on Appendix, all 22 confirmed)*
- [x] Reproduce the on-disk-vs-indexed diff to confirm the 22 are still unindexed:
      `find ~/Mail/Logos/cur ~/Mail/Logos/new -maxdepth 1 -type f | sort > /tmp/852-ondisk.txt`;
      `notmuch search --output=files 'path:Logos/cur or path:Logos/new' | grep -E '/Logos/(cur|new)/' | sort -u > /tmp/852-indexed.txt`;
      `comm -23 /tmp/852-ondisk.txt /tmp/852-indexed.txt`. *(completed: 27 missing files — the 22 targets + 5 secondary staleness files, matching plan expectation)*
- [x] For 5+ representative target tokens, confirm zero whole-DB hits:
      `notmuch search --output=files '*' 2>/dev/null | grep '4003086_145'` (repeat for `_159`,
      `_163`, `_189`, `_305`) — expect no output. *(completed: all 5 tokens returned zero hits)*
- [x] Record baseline counts: `notmuch count '*'` (total messages) and the on-disk Logos file count. *(completed: 65253 total messages; 340 on-disk Logos files)*
- [x] Snapshot mail-file integrity for later comparison: capture size+mtime (and optionally a
      sha256) of the 22 target files, e.g. `stat -c '%n %s %Y' <each target> > /tmp/852-mail-before.txt`. *(completed: size+mtime+sha256 captured for all 22)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- None (read-only). Working scratch files under `/tmp` only.

**Verification**:
- The `comm -23` diff still lists the 22 target files as unindexed.
- All representative-token whole-DB greps return zero hits.
- Baseline total-message count and mail-file snapshot are recorded.

---

### Phase 2: Execute the index-only full-scan remediation [COMPLETED]

**Goal**: Run the one untested, sanctioned remediation to index the 22 files — index-only, hook-free.

**Tasks**:
- [x] Confirm the command reads exactly `notmuch new --no-hooks --full-scan` (verify `--no-hooks`
      is present so the `pre-new` `mbsync gmail logos` hook does NOT fire). *(completed)*
- [x] Run `notmuch new --no-hooks --full-scan` and capture full stdout/stderr to a log
      (e.g. `/tmp/852-fullscan.log`). *(completed: exit 0; log preserved in scratchpad)*
- [x] Note the reported counts (added/removed messages) from the command output. *(completed: notmuch count '*' rose 65253 -> 65258 (+5); the 5 secondary staleness files cleared, but the 22 primary anomaly files did NOT get indexed — see Phase 3 verification and Rollback/Contingency)*

**Timing**: 15 minutes (scan of full mail_root with mtime optimization disabled may take a few minutes)

**Depends on**: 1

**Files to modify**:
- notmuch database (index only — adds message documents for the 22 files). No mail files, no
  repository files. This is the sanctioned `email-reindex`-class mutation.

**Verification**:
- Command exits 0 and the log shows no `pre-new`/`mbsync` activity (hook was skipped).
- Output reports new messages added (expected: at least the 22, plus possibly the 5 secondary
  staleness files).

---

### Phase 3: Verify remediation and confirm mail files untouched [COMPLETED]

**Goal**: Prove the 22 files are now queryable and that only the index — not the mail — changed.

**Tasks**:
- [x] Re-run the whole-DB token greps from Phase 1 (`4003086_145`, `_159`, `_163`, `_189`, `_305`,
      and the rest of the 22): each must now return a hit. *(deviation: altered — re-ran all 22 tokens, not just the 5 sample; ALL 22 still return zero hits, i.e. `--full-scan` did NOT resolve the anomaly)*
- [x] Confirm via Message-ID: for a sample of the 22, `notmuch count 'id:<message-id>'` returns 1. *(completed: sampled 3 Message-IDs, all return 0, confirming no message document exists)*
- [x] Re-run the `comm -23` on-disk-vs-indexed diff: the 22 target files must no longer appear as
      unindexed. *(deviation: altered — diff after remediation still lists exactly these same 22 files (the 5 secondary staleness files did clear, count 27->22))*
- [x] Confirm total-message count increased by the expected number vs the Phase 1 baseline. *(completed: 65253 -> 65258, +5 — matches only the 5 secondary staleness files, not the 22)*
- [x] Confirm mail files untouched: re-capture size+mtime (and sha256 if taken) of the 22 targets
      and diff against `/tmp/852-mail-before.txt` — expect no differences; on-disk Logos file count
      unchanged. *(deviation: altered — on-disk file count unchanged (340/340) and all 22 files byte-identical by sha256, but one file (`..._145...`) shows an unexplained mtime/ctime metadata touch to the current session window; see Rollback/Contingency and implementation summary for full disclosure — content integrity is proven via sha256, no data loss)*

**Timing**: 20 minutes

**Depends on**: 2

**Files to modify**:
- None (read-only verification).

**Verification**:
- All 22 target files are queryable (token grep + `id:` lookups return hits).
- On-disk-vs-indexed diff no longer lists the 22.
- Mail-file snapshot is byte-identical to the Phase 1 baseline (indexing only, no mail mutation).
- If any of the 22 remain unindexed after `--full-scan`, stop and follow Rollback/Contingency
  (record outcome, recommend Xapian-level follow-up) rather than attempting deeper surgery inline.

---

### Phase 4: Prepare logos-reclone.sh recurrence-prevention patch (propose, do not apply) [COMPLETED]

**Goal**: Produce a concrete patch that makes `logos-reclone.sh` use `notmuch new --no-hooks` at its
reindex step, so the hook-race cannot recur — as a proposal for the user to apply in `~/.dotfiles`.

**Tasks**:
- [x] Locate the live reclone script under `~/.dotfiles` (e.g.
      `find ~/.dotfiles -name 'logos-reclone.sh'`). If not present, use the preserved backup at
      `~/Mail/.logos-backup-20260706/reclone/logos-reclone.sh` as the reference source and note the
      live script's absence. *(completed: no live script found anywhere under ~/.dotfiles by name or by grep for "notmuch new"; used the preserved backup copy as reference)*
- [x] Identify the offending line (research: line 92, `run "notmuch new"`) and compose the minimal
      diff changing it to `run "notmuch new --no-hooks"` (with `mbsync` invoked explicitly and
      separately, sequentially, if a pull is actually needed at that step). *(completed: line 92 confirmed verbatim; mbsync already runs separately at step 6/line 88, so no additional mbsync call needed)*
- [x] Write the proposed patch/diff and apply instructions into the task summary (or a patch file
      under `specs/852_investigate_logos_unindexed_files/`), clearly marked "user applies in
      ~/.dotfiles; then home-manager switch". *(completed: written to specs/852_investigate_logos_unindexed_files/logos-reclone-no-hooks.patch)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- None in `~/.dotfiles` (proposal only). Patch text captured as a task artifact in this repo.

**Verification**:
- The proposed diff changes the raw `notmuch new` invocation to `notmuch new --no-hooks` (matching
  the `wrapper-contracts.md` invariant), and is annotated as user-applied (no agent rebuild/commit/push).
- The patch is self-contained enough that applying it prevents the specific hook-triggered `mbsync`
  race identified in the research report.

---

### Phase 5: Document the hook-race hazard and record outcomes [NOT STARTED]

**Goal**: Capture the specific failure mode in-repo (so a future accidental hooked `notmuch new` is
diagnosed fast) and finalize the task record.

**Tasks**:
- [ ] Add a short "known hazard" note to
      `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (Index Freshness
      section) documenting: raw `notmuch new` -> `pre-new` `mbsync` delivers mail -> hook fails ->
      files delivered mid-scan can stay permanently unindexed; remediation is
      `notmuch new --no-hooks --full-scan`. (This file is in THIS repo — in-repo edit, allowed.)
- [ ] Record the remediation outcome (count of files indexed, whether all 22 cleared) and the
      Phase 4 patch proposal in the implementation summary.
- [ ] Note the 5 secondary staleness files as expected-to-clear on next routine `email-reindex`
      (no action taken here).

**Timing**: 15 minutes

**Depends on**: 3, 4

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` - add hazard note.
- `specs/852_investigate_logos_unindexed_files/summaries/01_...-summary.md` - outcomes + patch handoff.

**Verification**:
- Hazard note is present and references both the failure mode and the `--full-scan` remediation.
- Summary records the indexed-file count, mail-untouched confirmation, and the user-applied patch.

## Testing & Validation

- [ ] Phase 1 baseline confirms the 22 files are unindexed (zero whole-DB hits) before remediation.
- [ ] `notmuch new --no-hooks --full-scan` runs without triggering any hook/`mbsync` (log clean).
- [ ] All 22 target files are queryable after the full-scan (token grep + `id:` lookups return hits).
- [ ] On-disk-vs-indexed diff no longer lists the 22 files.
- [ ] Mail-file snapshot is unchanged between Phase 1 and Phase 3 (indexing only, no mail mutation).
- [ ] `logos-reclone.sh` patch proposal switches the reindex step to `--no-hooks` and is handed to
      the user (no agent apply/rebuild/commit/push in `~/.dotfiles`).

## Artifacts & Outputs

- `specs/852_investigate_logos_unindexed_files/plans/01_reindex-unindexed-logos-fullscan.md` (this plan)
- `specs/852_investigate_logos_unindexed_files/summaries/01_reindex-unindexed-logos-fullscan-summary.md`
  (implementation summary: outcomes, indexed-file count, mail-untouched confirmation, patch proposal)
- Proposed `logos-reclone.sh` patch/diff (captured in the summary or a patch file; user applies)
- Hazard note added to `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md`
- notmuch database: 22 files newly indexed (index-only mutation)

## Rollback/Contingency

- The remediation is index-only and additive (`notmuch new` creates message documents; it does not
  delete mail). There is nothing destructive to roll back — mail files are never modified.
- If `notmuch new --no-hooks --full-scan` does NOT index all 22 files (Phase 3 fails), do not
  attempt Xapian-level surgery inline. Record the exact residual set and recommend a follow-up task
  to inspect the Xapian directory records directly (`notmuch dump`, Xapian delve), per the research
  report's escalation note. Leave the task honestly reflecting partial remediation.
- The `logos-reclone.sh` patch is a proposal only; if the user declines to apply it, the recurrence
  risk is documented (hazard note + summary) but no repository or `~/.dotfiles` state is left
  inconsistent.

**OUTCOME (this contingency triggered)**: `notmuch new --no-hooks --full-scan` ran cleanly
(exit 0, no hook/mbsync activity, `notmuch count '*'` 65253 -> 65258) but did **not** index any of
the 22 primary anomaly files — all 22 remain zero-hit on whole-DB token search and via `id:` lookup
after the scan. Only the 5 secondary staleness files cleared. Per this section, no Xapian-level
surgery was attempted inline. The residual set (all 22, unchanged from the original list) is
recorded in `progress/phase-3-progress.json` and in the implementation summary, with a follow-up
task recommended to inspect the Xapian directory-scan bookkeeping directly (`notmuch dump`, Xapian
delve) — see summary for the specific recommendation. Additionally, one target file
(`1783354873.4003086_145.hamsa,U=145:2,`) was found with an mtime/ctime metadata touch to the
current session window (content byte-identical via sha256, no data loss, no attributable write
command from this session, no competing process found running) — disclosed as an unresolved
residual anomaly, not remediated further.
