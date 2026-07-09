# Implementation Plan: Task #834

- **Task**: 834 - Retire the stale per-repo literature copies
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (research verification complete; no ordering constraint against task #832)
- **Research Inputs**: specs/834_retire_stale_per_repo_literature_copies/reports/01_retire-stale-literature-copies.md
- **Artifacts**: plans/01_retire-stale-literature-copies.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; pr-prohibition.md; plan-format-enforcement.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research verified (27-dir sha256 + word-count comparison) that `~/Projects/BimodalLogic/specs/literature/sources/` is fully content-equivalent to the central corpus at `~/Projects/Literature/sources/`, with central being a strict metadata superset, and that `--lit` for BimodalLogic already resolves exclusively against central (never the per-repo `sources/`). This plan executes a **backup-then-verify-then-delete** procedure that removes only `sources/`, leaving `DEPRECATED.md`, `README.md`, and `index.json` intact. The single load-bearing hazard is that `specs/literature/sources/**/*.pdf` (~176 MB) is gitignored and therefore **not git-recoverable**, so a verified tar backup of the PDFs is created and re-hashed against a pre-delete manifest before any deletion occurs. Definition of done: `sources/` deleted, tracked-file deletion committed locally in the BimodalLogic repo (never pushed, no PR), `--lit` re-confirmed working post-delete, verified backup retained per stated lifecycle, and a cslib follow-up recommendation recorded.

### Research Integration

Key findings from `reports/01_retire-stale-literature-copies.md` driving this plan:
- **Zero content loss** across all 27 source dirs; every PDF byte-identical by sha256 (26/27 dirs with PDFs), markdown differences explained by benign dedup of a redundant combined `.md`.
- **Central is a metadata superset** (`project_tags`, `summary`, `zotero_key` added).
- **Sub-index already resolves to central**: `literature-briefing.sh` per-repo mode reads `specs/literature-index.json` and resolves `doc_id`s against `$LITERATURE_DIR/index.json`, reporting `dir:` under central's `sources/`. It never reads the calling repo's own `specs/literature/sources/`. Deletion cannot regress `--lit`. No ordering constraint against #832.
- **Risk asymmetry (single most important fact)**: `.md`/`index.json` under `sources/` are git-tracked (192 paths, ~4.8 MB, recoverable via `git checkout`); the ~176 MB of PDFs are gitignored and unrecoverable via git. A verified pre-delete backup of the PDFs is mandatory.

### Prior Plan Reference

No prior plan. This is the first plan for task 834.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no ROADMAP.md consulted. This task advances the task-710 literature-migration cleanup line by retiring the now-redundant per-repo copy.

## Goals & Non-Goals

**Goals**:
- Record a pre-delete sha256 manifest of everything to be removed and re-verify PDFs byte-identical against central immediately before deleting.
- Create and independently verify a backup of the gitignored PDFs before any deletion.
- Confirm `--lit` resolves via a read-only `literature-briefing.sh` invocation both before and after deletion.
- Delete exactly `~/Projects/BimodalLogic/specs/literature/sources/` and commit the tracked-file deletion locally in the BimodalLogic repo.
- Record (not create) a follow-up-task recommendation for the out-of-scope cslib / cslib-refactor-prop_logic stale copies.

**Non-Goals**:
- Deleting, moving, or modifying anything under `~/Projects/Literature/` (the surviving source of truth; #832 depends on its PDFs).
- Deleting `DEPRECATED.md`, `README.md`, or `index.json` at `~/Projects/BimodalLogic/specs/literature/` — only `sources/` is removed.
- Touching cslib or cslib-refactor-prop_logic (out of scope; flagged only).
- Any `git push`, PR/MR creation, or remote operation (`.claude/rules/pr-prohibition.md`).
- Re-migration or converter-quality remediation (task 831 concern; equally present in both copies, out of scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| PDFs (~176 MB) gitignored and unrecoverable via git | H | L | Pre-delete sha256 manifest (Phase 1) + verified tar backup (Phases 2-3); delete only after backup re-hash matches manifest |
| Drift between research time and delete time (stray manual edit) | H | L | Re-run sha256 comparison against central as the final pre-delete gate (Phase 1); abort on any mismatch |
| Over-deletion beyond `sources/` | H | L | Delete command targets the exact `sources/` path only; Phase 5 asserts sibling files (`DEPRECATED.md`, `README.md`, `index.json`) still present after deletion |
| `--lit` regression for BimodalLogic post-delete | M | L | Read-only `literature-briefing.sh` confirmed pre-delete (Phase 4) and re-confirmed non-empty post-delete (Phase 6) |
| Commit performed in the wrong repo (cross-repo boundary) | M | L | All git commands use `git -C ~/Projects/BimodalLogic`; commit scoped to `specs/literature/sources` only; never operate on `/home/benjamin/.config/nvim` git for this deletion |
| Accidental `git push` / PR | H | L | Phase 7 commits locally only; `.claude/rules/pr-prohibition.md` — no push, no PR under any circumstance |
| Orphaned 176 MB backup left on disk indefinitely | L | M | Backup lifecycle stated explicitly (Rollback/Contingency): retain through a defined post-delete window, then user-confirmed cleanup |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |
| 6 | 7 | 5, 6 |
| 7 | 8 | 7 |

Phases within the same wave can execute in parallel. Phase 1 (pre-delete manifest + re-verification) and Phase 4 (pre-delete `--lit` confirmation) are both read-only and independent, so they form Wave 1. Every destructive step (Phase 5 onward) is gated behind the verified backup chain (1 -> 2 -> 3) and the pre-delete `--lit` confirmation (4).

---

### Phase 1: Record Pre-Delete sha256 Manifest and Re-Verify Against Central [NOT STARTED]

**Goal**: Produce an authoritative pre-delete manifest of every file under `sources/`, and re-confirm (immediately before any destructive action) that all PDFs are byte-identical to their central counterparts. Abort the entire plan on any mismatch.

**Tasks**:
- [ ] Create a working directory for manifests outside the repo: `mkdir -p ~/Projects/task834-verification`
- [ ] Record a full manifest (PDFs + tracked `.md`/`index.json`) with hashes:
  `find ~/Projects/BimodalLogic/specs/literature/sources -type f -exec sha256sum {} \; | sort > ~/Projects/task834-verification/predelete-manifest.txt`
- [ ] Record a PDF-only manifest with paths relative to the `sources/` root (for backup verification in Phase 3):
  `cd ~/Projects/BimodalLogic/specs/literature && find sources -type f -name '*.pdf' -exec sha256sum {} \; | sort > ~/Projects/task834-verification/predelete-pdf-manifest.txt`
- [ ] Re-verify each PDF against central: for every `sources/<dir>/<file>.pdf`, compare its sha256 to `~/Projects/Literature/sources/<dir>/<file>.pdf`. Note the one known relocation: `Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf` lives under `gabbay_1994/` in BimodalLogic but under `sources/gabbay_2000/` in central (per research Finding 1, row 10) — match it against its relocated central path, not a same-named path.
- [ ] If ANY PDF present in both locations has a mismatched hash, STOP: do not proceed to backup or deletion; record the mismatch and report as a blocker.

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- None in-repo. Writes manifests to `~/Projects/task834-verification/` (outside any repo).

**Verification**:
- `~/Projects/task834-verification/predelete-manifest.txt` and `predelete-pdf-manifest.txt` both exist and are non-empty.
- PDF-count in the manifest matches `find ~/Projects/BimodalLogic/specs/literature/sources -name '*.pdf' | wc -l`.
- Every co-present PDF hash matches its central counterpart (zero mismatches). Any mismatch = abort.

---

### Phase 2: Back Up the Gitignored PDFs [NOT STARTED]

**Goal**: Create a single compressed backup of the untracked PDFs — the only content with zero git recoverability — stored outside the repo so it is not itself a second stale copy.

**Tasks**:
- [ ] Create the backup archive (PDFs are captured because the tar includes all of `sources/`; the tracked `.md`/`index.json` come along harmlessly and are separately git-recoverable):
  `tar czf ~/Projects/backup-bimodallogic-literature-sources-$(date +%Y%m%d).tar.gz -C ~/Projects/BimodalLogic/specs/literature sources`
- [ ] Confirm the archive was written to `~/Projects/` (repo-external) and record its path and size.

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None in-repo. Writes `~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz` (outside any repo, NOT inside `specs/literature/`).

**Verification**:
- `ls -lh ~/Projects/backup-bimodallogic-literature-sources-*.tar.gz` shows a file of roughly the expected size (~176 MB of PDFs, compressed).
- `tar tzf <archive>` lists entries under `sources/` (non-empty listing).

---

### Phase 3: Verify the Backup Against the Manifest [NOT STARTED]

**Goal**: Prove the backup is restorable and byte-faithful BEFORE deleting anything — an unverified backup is not a backup. Re-hash the PDFs from the archive contents and compare against the Phase 1 PDF manifest.

**Tasks**:
- [ ] Extract the archive to a scratch location: `mkdir -p ~/Projects/task834-verification/restore-check && tar xzf ~/Projects/backup-bimodallogic-literature-sources-*.tar.gz -C ~/Projects/task834-verification/restore-check`
- [ ] Re-hash the restored PDFs with the same relative-path scheme used in Phase 1:
  `cd ~/Projects/task834-verification/restore-check && find sources -type f -name '*.pdf' -exec sha256sum {} \; | sort > ~/Projects/task834-verification/backup-pdf-manifest.txt`
- [ ] Diff the two PDF manifests: `diff ~/Projects/task834-verification/predelete-pdf-manifest.txt ~/Projects/task834-verification/backup-pdf-manifest.txt` — must be empty (identical hashes AND identical relative paths).
- [ ] If the diff is non-empty, STOP: the backup is not verified; do not delete. Re-create the backup and re-verify, or report a blocker.
- [ ] On success, remove the scratch restore copy to reclaim space: `rm -rf ~/Projects/task834-verification/restore-check`

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- None in-repo. Uses `~/Projects/task834-verification/` scratch space only.

**Verification**:
- `diff predelete-pdf-manifest.txt backup-pdf-manifest.txt` produces no output (exit 0).
- PDF count in `backup-pdf-manifest.txt` equals the count in `predelete-pdf-manifest.txt`.
- Only after this passes is deletion (Phase 5) authorized.

---

### Phase 4: Confirm `--lit` Resolves Pre-Delete (Read-Only Baseline) [NOT STARTED]

**Goal**: Capture a baseline showing `literature-briefing.sh` in BimodalLogic emits a correct, non-empty briefing resolving to central, so the post-delete run (Phase 6) can be compared against it. Read-only; no writes, no deletion dependency.

**Tasks**:
- [ ] Run the per-repo briefing read-only from within BimodalLogic:
  `cd ~/Projects/BimodalLogic && bash .claude/scripts/literature-briefing.sh` (per-repo mode reads `specs/literature-index.json` + `$LITERATURE_DIR/index.json`; it only prints).
- [ ] Save the output to `~/Projects/task834-verification/predelete-briefing.txt`.
- [ ] Confirm the briefing is non-empty, contains both sub-index entries (`rabinovich_2014`, `kamp_1968_tense-logic-linear-order`), and every `dir:` path points under `/home/benjamin/Projects/Literature/sources/` (central) — never under `~/Projects/BimodalLogic/specs/literature/sources/`.

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- None. Read-only invocation; output captured to `~/Projects/task834-verification/predelete-briefing.txt`.

**Verification**:
- `predelete-briefing.txt` is non-empty and contains a `<literature-briefing>` block with 2 entries.
- Zero `dir:` paths reference the per-repo `specs/literature/sources/`.

---

### Phase 5: Delete Exactly `sources/` [NOT STARTED]

**Goal**: Remove `~/Projects/BimodalLogic/specs/literature/sources/` and nothing else, leaving the sibling metadata files intact.

**Tasks**:
- [ ] Delete only the `sources/` subdirectory: `rm -rf ~/Projects/BimodalLogic/specs/literature/sources`
- [ ] Assert the sibling files survive: confirm `~/Projects/BimodalLogic/specs/literature/DEPRECATED.md`, `README.md`, and `index.json` all still exist.
- [ ] Assert `sources/` is gone: `test ! -e ~/Projects/BimodalLogic/specs/literature/sources`.

**Timing**: 5 minutes

**Depends on**: 3, 4

**Files to modify**:
- Deletes `~/Projects/BimodalLogic/specs/literature/sources/` (recursive). Leaves `DEPRECATED.md`, `README.md`, `index.json` at `specs/literature/` untouched.

**Verification**:
- `ls ~/Projects/BimodalLogic/specs/literature/` lists `DEPRECATED.md`, `README.md`, `index.json` and NO `sources` entry.
- `git -C ~/Projects/BimodalLogic status --porcelain specs/literature/sources` shows the 192 tracked files as deletions (` D `), and no untracked-PDF noise (PDFs were never tracked).

---

### Phase 6: Re-Confirm `--lit` Resolves Post-Delete [NOT STARTED]

**Goal**: Prove `--lit` still produces a correct, non-empty briefing for BimodalLogic after `sources/` is gone — the zero-cost regression check.

**Tasks**:
- [ ] Re-run the briefing read-only: `cd ~/Projects/BimodalLogic && bash .claude/scripts/literature-briefing.sh` and save to `~/Projects/task834-verification/postdelete-briefing.txt`.
- [ ] Assert the post-delete briefing is non-empty and still contains both entries resolving to central.
- [ ] Diff against the baseline: `diff ~/Projects/task834-verification/predelete-briefing.txt ~/Projects/task834-verification/postdelete-briefing.txt` — expect no meaningful difference (identical `dir:` resolution to central). Note any timestamp-only differences as benign.

**Timing**: 10 minutes

**Depends on**: 5

**Files to modify**:
- None. Read-only; output captured to `~/Projects/task834-verification/postdelete-briefing.txt`.

**Verification**:
- `postdelete-briefing.txt` is non-empty, contains the 2-entry `<literature-briefing>` block, all `dir:` paths under central.
- If the briefing is empty or errors, STOP and use the rollback procedure (Rollback/Contingency) before committing.

---

### Phase 7: Commit the Tracked-File Deletion in the BimodalLogic Repo (Local Only) [NOT STARTED]

**Goal**: Record the deletion of the 192 tracked `.md`/`index.json` files as a local commit in the BimodalLogic repository — a DIFFERENT git repo from the working repo (`/home/benjamin/.config/nvim`). No push, no PR (`.claude/rules/pr-prohibition.md`).

**Tasks**:
- [ ] Confirm the working tree of the BimodalLogic repo has no unrelated staged changes that would be swept in: `git -C ~/Projects/BimodalLogic status --porcelain specs/literature`.
- [ ] Stage only the deletion path: `git -C ~/Projects/BimodalLogic add -A specs/literature/sources`.
- [ ] Verify staged changes are deletions only, scoped to `specs/literature/sources`: `git -C ~/Projects/BimodalLogic status --porcelain specs/literature/sources`.
- [ ] Commit locally with a descriptive message (include the session id in the body):
  `git -C ~/Projects/BimodalLogic commit -m "Retire stale per-repo literature sources (task 834)" -m "Deletes specs/literature/sources/ (content-equivalent to central ~/Projects/Literature; verified byte-identical by sha256 with a verified PDF backup). DEPRECATED.md, README.md, and index.json retained. --lit resolution confirmed unaffected (resolves to central)."`
- [ ] Do NOT run `git push`. Do NOT create a PR/MR. Do NOT invoke `/merge`. The commit stays local.

**Timing**: 10 minutes

**Depends on**: 5, 6

**Files to modify**:
- Git index/history of `~/Projects/BimodalLogic` only (local commit). No file content changes beyond the already-performed deletion. The working repo `/home/benjamin/.config/nvim` is NOT touched by this commit.

**Verification**:
- `git -C ~/Projects/BimodalLogic log -1 --stat` shows a commit deleting the tracked files under `specs/literature/sources/` and nothing outside that path.
- `git -C ~/Projects/BimodalLogic status --porcelain specs/literature` is clean for the deleted files.
- No `git push` was executed; no PR/MR exists.

---

### Phase 8: Record cslib Follow-Up Recommendation and Backup Lifecycle Note [NOT STARTED]

**Goal**: Preserve the out-of-scope finding (cslib / cslib-refactor-prop_logic exhibit the identical stale-copy pattern) as a concrete follow-up recommendation, and restate the backup lifecycle so the 176 MB archive is not orphaned. This phase records a recommendation; it does NOT create the follow-up task.

**Tasks**:
- [ ] In the implementation summary (and orchestrator handoff), record a follow-up-task recommendation with observed specifics from research Finding 4:
  - `~/Projects/cslib/specs/literature/` — 25 MB, 20 source dirs + 2 top-level PDFs, populated 11-entry sub-index verified live-resolving to central. Same stale-copy situation as BimodalLogic; strong candidate for a near-identical delete-after-verify task.
  - `~/Projects/cslib-refactor-prop_logic/specs/literature/` — 25 MB, 20 dirs, a git worktree of cslib (shares `.git`, branch `refactor/prop_logic`); any decision on cslib's copy should be applied consistently across both worktrees. This is a worktree characteristic, not an independent second problem.
  - Recommend the follow-up be created via `/task` (or `/spawn`) — explicitly NOT created by this plan.
- [ ] State the backup lifecycle in the summary: `~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz` is retained through the post-delete confidence window (recommended: 7 days, or until the user confirms `--lit` and the BimodalLogic history are satisfactory), after which it is deleted with an explicit user-confirmed `rm`. Note that `~/Projects/task834-verification/` scratch manifests may be removed at the same time.

**Timing**: 10 minutes

**Depends on**: 7

**Files to modify**:
- None directly. Content is recorded in the implementation summary and orchestrator handoff during the implement phase.

**Verification**:
- The implementation summary contains the cslib / cslib-refactor-prop_logic follow-up recommendation with the sizes/paths above and an explicit "not created here" note.
- The implementation summary contains the backup archive path and its stated retention/cleanup lifecycle.

---

## Testing & Validation

- [ ] Phase 1: pre-delete manifests exist; every co-present PDF is byte-identical to central (zero mismatches).
- [ ] Phase 3: `diff predelete-pdf-manifest.txt backup-pdf-manifest.txt` is empty (backup verified restorable).
- [ ] Phase 4: pre-delete `literature-briefing.sh` emits a non-empty 2-entry briefing resolving to central.
- [ ] Phase 5: `sources/` is gone; `DEPRECATED.md`, `README.md`, `index.json` remain.
- [ ] Phase 6 (post-delete assertion): `literature-briefing.sh` in BimodalLogic still produces a NON-EMPTY briefing with all `dir:` paths under `~/Projects/Literature/sources/`.
- [ ] Phase 7: a local commit in `~/Projects/BimodalLogic` records only the `specs/literature/sources/` deletions; no push, no PR.
- [ ] Nothing under `~/Projects/Literature/` was modified (verify `git -C ~/Projects/Literature status` unchanged / untouched, and no writes to that tree).

## Artifacts & Outputs

- `specs/834_retire_stale_per_repo_literature_copies/plans/01_retire-stale-literature-copies.md` (this plan)
- `~/Projects/task834-verification/predelete-manifest.txt` — full pre-delete sha256 manifest (repo-external)
- `~/Projects/task834-verification/predelete-pdf-manifest.txt` — PDF-only pre-delete manifest
- `~/Projects/task834-verification/backup-pdf-manifest.txt` — PDF hashes re-derived from the backup
- `~/Projects/task834-verification/predelete-briefing.txt` / `postdelete-briefing.txt` — `--lit` before/after evidence
- `~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz` — verified PDF backup (repo-external; lifecycle per Rollback/Contingency)
- A local commit in `~/Projects/BimodalLogic` deleting `specs/literature/sources/`
- Implementation summary at `specs/834_retire_stale_per_repo_literature_copies/summaries/01_retire-stale-literature-copies-summary.md` (created during /implement), including the cslib follow-up recommendation and backup lifecycle note

## Rollback/Contingency

If anything looks wrong at or after Phase 5 (empty/failed post-delete briefing, discovered mismatch, accidental over-deletion), restore before committing (Phase 7). The two recovery paths are independent and each works even if the other was already discarded:

- **Restore the gitignored PDFs (from the verified backup)**:
  `tar xzf ~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz -C ~/Projects/BimodalLogic/specs/literature/`
  (extracts the `sources/` tree back into place, including the untracked PDFs).

- **Restore the tracked `.md`/`index.json` files (from git)**:
  - Before Phase 7 commit: `git -C ~/Projects/BimodalLogic checkout -- specs/literature/sources`
  - After the Phase 7 commit: `git -C ~/Projects/BimodalLogic revert <commit>` (local revert; no push), or `git -C ~/Projects/BimodalLogic checkout <commit-before-deletion> -- specs/literature/sources`.

- **Backup lifecycle (explicit, to avoid a 176 MB orphan)**: keep `~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz` through a post-delete confidence window — recommended 7 days or until the user confirms `--lit` and the BimodalLogic history are satisfactory. After that window, delete it with an explicit, user-confirmed command:
  `rm ~/Projects/backup-bimodallogic-literature-sources-{DATE}.tar.gz` and, if desired, `rm -rf ~/Projects/task834-verification/`. The implementation must state the archive path and this retention decision in the summary so the backup is never left indefinitely with no owner.

- **Absolute constraint**: no rollback step ever writes to, moves, or deletes anything under `~/Projects/Literature/` — that is the surviving source of truth and task #832 depends on its PDFs.
