# Implementation Summary: Task #834

**Completed**: 2026-07-09
**Duration**: ~45 minutes

## Overview

Retired the stale per-repo literature copy at `~/Projects/BimodalLogic/specs/literature/sources/` after a per-file sha256 re-verification against the central corpus (`~/Projects/Literature/sources/`) found zero divergence across all 31 PDFs, and after creating and independently re-hash-verifying a full backup of the gitignored PDFs. Deletion was committed locally in the BimodalLogic repo (no push, no PR). A repo-wide sweep of `~/Projects/` for other stale `specs/literature/` copies was also performed, surfacing the two candidates already known from research (cslib, cslib-refactor-prop_logic) plus two additional out-of-scope items not previously catalogued; none of these were touched.

## What Changed

- `~/Projects/BimodalLogic/specs/literature/sources/` — **Deleted** (rm -rf), after full verification. `DEPRECATED.md`, `README.md`, and `index.json` at `~/Projects/BimodalLogic/specs/literature/` were left in place untouched.
- BimodalLogic repo: local commit `60cef7179` — "Retire stale per-repo literature sources (task 834)" — 192 files changed, 160292 deletions, scoped exclusively to `specs/literature/sources/`. Not pushed; no PR/MR created.
- `~/Projects/backup-bimodallogic-literature-sources-20260709.tar.gz` — Created (166 MB, repo-external), independently re-hash-verified against the pre-delete PDF manifest before any deletion occurred.
- `specs/834_retire_stale_per_repo_literature_copies/plans/01_retire-stale-literature-copies.md` — All 8 phase headings marked `[COMPLETED]`, all task checklist items checked off with completion notes, Testing & Validation section checked off, overall Status set to `[COMPLETED]`.
- `specs/834_retire_stale_per_repo_literature_copies/progress/phase-{1..8}-progress.json` — Created, all objectives `done`.
- No files under `~/Projects/Literature/` (central store) were modified — only read operations (`sha256sum`, `ls`) were performed against it.

## Equivalence Verification Evidence

**Phase 1 — pre-delete manifest + central re-verification** (this is the load-bearing safety gate):
- Full manifest: 195 files hashed (`~/Projects/task834-verification/predelete-manifest.txt`).
- PDF-only manifest: 31 PDFs (`~/Projects/task834-verification/predelete-pdf-manifest.txt`), count matches `find ... -name '*.pdf' | wc -l` = 31.
- Per-file sha256 comparison against central, one row per PDF, with the known relocation handled explicitly (`Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf` lives under BimodalLogic's `gabbay_1994/` but matched against central's `sources/gabbay_2000/`):
  - **MATCH = 31, MISMATCH = 0, MISSING = 0** (full per-file report retained at `~/Projects/task834-verification/central-comparison-report.txt`).
- This is a complete, total equivalence result — no partial or "mostly equivalent" outcome, satisfying the safety constraint to only proceed to deletion when equivalence is total.

**Phases 2-3 — backup creation and independent re-verification**:
- Backup archive: `~/Projects/backup-bimodallogic-literature-sources-20260709.tar.gz`, 166 MB, 223 tar entries (dirs + 195 files).
- Backup re-hash: extracted to a scratch location, re-hashed all 31 PDFs, diffed against the Phase 1 PDF manifest — **`diff` produced no output (exit 0)**, confirming the backup is byte-identical and path-identical to the pre-delete state. Scratch restore copy removed after verification.

**Phases 4 and 6 — `--lit` regression check (before and after deletion)**:
- Pre-delete: `literature-briefing.sh` (run from within BimodalLogic) emitted a non-empty briefing with 2 entries (`rabinovich_2014`, `kamp_1968_tense-logic-linear-order`), both `dir:` paths resolving under `/home/benjamin/Projects/Literature/sources/` (central) — never under the per-repo `specs/literature/sources/`.
- Post-delete: re-ran the same command — output was **byte-identical to the pre-delete baseline** (`diff` produced no output). No regression.

**Deletion scope assertion (Phase 5)**:
- `~/Projects/BimodalLogic/specs/literature/` after deletion contains exactly `DEPRECATED.md`, `README.md`, `index.json` — no `sources` entry.
- `git -C ~/Projects/BimodalLogic status --porcelain specs/literature/sources` showed exactly 192 tracked-file deletions (` D`), matching the expected tracked-file count from the plan.

**Central store integrity**:
- Only read operations (`sha256sum`, `ls`) were ever performed against `~/Projects/Literature/`. The repo does show pre-existing unrelated dirty state (`M .literature.db`, `M index.json`, a few untracked new source directories) — this predates task 834 and was not caused by this task; nothing under `~/Projects/Literature/` was written to, moved, or deleted by this implementation.

## Additional Finding: Git Recoverability Was Better Than Assumed

The plan's risk model assumed only the 192 `.md`/`index.json` files were git-tracked and all 31 PDFs were gitignored-and-unrecoverable. On staging the deletion, it was observed that **28 of the 31 PDFs were actually already git-tracked** (added to the BimodalLogic repo before its `.gitignore` rule for `specs/literature/sources/**/*.pdf` took effect — `git check-ignore` confirms git honors already-tracked files as an exception to a later-added ignore rule). Only 3 PDFs were genuinely untracked. This does not change the procedure (the verified backup already covers all 31 PDFs regardless of git-tracked status), but it means the actual git-recoverability margin was wider than the plan's risk table stated. Worth noting for future similar cleanups: check `git ls-files` before assuming a `.gitignore` pattern makes files unrecoverable.

## `~/Projects/` Sweep for Other Stale Copies (Report Only — Nothing Deleted Beyond BimodalLogic)

Per the explicit task constraint, only `~/Projects/BimodalLogic/specs/literature/sources/` was deleted. The following other stale-copy candidates were found and are reported for a follow-up decision, not acted on:

1. **`~/Projects/cslib/specs/literature/`** — 25 MB, `sources/` with 19 source dirs, `specs/literature-index.json` sub-index present and populated, **no `DEPRECATED.md`** (not yet retired). Same stale-copy pattern as BimodalLogic pre-cleanup; strong candidate for a near-identical delete-after-verify follow-up task.
2. **`~/Projects/cslib-refactor-prop_logic/specs/literature/`** — 25 MB, 19 source dirs. This is a git worktree of cslib (shares `.git`, branch `refactor/prop_logic`) — a worktree characteristic, not an independent second problem. Any decision applied to cslib's copy should be applied consistently to this worktree too.
3. **`~/Projects/Logos/Hardware/specs/literature/`** (newly found, not in the original research) — 68 MB, a flat-file PDF corpus (49 PDFs + 1 HTML directly under `specs/literature/`, no `sources/` subdirectory structure), with a `SOURCES.md` file rather than `DEPRECATED.md`. This is a **different convention entirely** — not the central-store-plus-sub-index pattern used by BimodalLogic/cslib — and needs separate triage before any retirement decision (unclear whether these documents even exist in the central corpus).
4. **BimodalLogic agent-worktree copies** (newly found) — three `.claude/worktrees/agent-*/specs/literature/` directories (`agent-a55505307ae3d4932`, `agent-a83818cfb35228c46`, `agent-a6741c7a21a3a3530`), each 1.7 MB, containing only `.md` files (no PDFs, no `sources/` subdirectory — an older flat single-file-per-source format). These are stale agent-worktree snapshots, likely cleanable via normal Claude Code worktree lifecycle/cleanup rather than a literature-specific task.

**Recommendation**: create the cslib / cslib-refactor-prop_logic follow-up via `/task` (or `/spawn`) — explicitly not created by this task. The Logos/Hardware and BimodalLogic-worktree findings are flagged for awareness but likely warrant separate handling (different convention / different lifecycle) rather than being folded into the same follow-up task.

## Backup Lifecycle

- **Archive**: `~/Projects/backup-bimodallogic-literature-sources-20260709.tar.gz` (166 MB, repo-external, verified restorable — see Equivalence Verification Evidence above).
- **Retention**: keep through a post-delete confidence window — recommended 7 days from 2026-07-09 (i.e. through roughly 2026-07-16), or until the user confirms `--lit` and the BimodalLogic git history remain satisfactory, whichever is later.
- **Cleanup** (after the window, user-confirmed only): `rm ~/Projects/backup-bimodallogic-literature-sources-20260709.tar.gz` and, if desired, `rm -rf ~/Projects/task834-verification/` (scratch manifests: `predelete-manifest.txt`, `predelete-pdf-manifest.txt`, `backup-pdf-manifest.txt`, `central-comparison-report.txt`, `predelete-briefing.txt`, `postdelete-briefing.txt`).
- No automated deletion of the backup or scratch manifests was performed by this task — both are left in place pending the user-confirmed window above.

## Decisions

- Followed the plan's backup-then-verify-then-delete procedure exactly, treating "equivalence must be total, not partial" as a hard gate before any deletion (per the CRITICAL SAFETY CONSTRAINT in the delegation context).
- Extended the sweep beyond the plan's Phase 8 (which only restated the already-known cslib/cslib-refactor-prop_logic findings) to actually search `~/Projects/` for `specs/literature` and `specs/literature/sources` patterns, per the task description's explicit "Sweep ~/Projects/ for other stale specs/literature/ copies" instruction — this surfaced the two additional findings (Logos/Hardware, BimodalLogic agent-worktrees) noted above.

## Plan Deviations

- None (implementation followed plan). The additional sweep findings (Logos/Hardware, BimodalLogic agent-worktrees) are an extension consistent with the task description's explicit sweep instruction, not a deviation from the plan's Phase 8 tasks — Phase 8's own checklist items were completed as written, with the extra findings folded into the same recorded recommendation.

## Verification

- Build: N/A (no code build for this task)
- Tests: N/A (verification was per-file sha256 checksum comparison and read-only `--lit` briefing diffs, both passed — see Equivalence Verification Evidence)
- Files verified: Yes — `sources/` deletion confirmed, sibling files confirmed present, local commit confirmed scoped correctly, central store confirmed untouched

## Notes

- All work outside the `/home/benjamin/.config/nvim` repo (the BimodalLogic deletion, backup, and local commit) was performed directly via `bash`/`git -C` against `~/Projects/BimodalLogic` and `~/Projects/Literature`; the working repo `/home/benjamin/.config/nvim` itself only received the plan/progress/summary artifact updates and their commits.
- No `git push`, PR, or MR was created or attempted at any point, per `.claude/rules/pr-prohibition.md` and the plan's explicit non-goals.
