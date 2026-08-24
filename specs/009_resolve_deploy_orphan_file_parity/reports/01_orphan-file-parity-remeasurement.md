# Research Report: Task #9

**Task**: 9 - resolve_deploy_orphan_file_parity
**Started**: 2026-08-24T22:00:00Z
**Completed**: 2026-08-24T22:40:00Z
**Effort**: ~1h
**Dependencies**: task 32 (deploy) - completed; task 18 (staleness detection) - completed
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/verify-deploy.sh`, `lua/neotex/plugins/ai/shared/extensions/verify.lua`, `agent-system/extensions/core/scripts/install-extension.sh`, `agent-system/extensions/core/scripts/deploy-headless.sh`, `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/context/orchestration/`, `agent-system/extensions/core/docs/architecture/`
- Live measurement: a genuine clean scratch regenerate (git clone + `deploy-headless.sh` into scratch), diffed against the live `.claude/` tree
- Git history: commits `0e6245fd0` and `89eac9896` (task 986, 2026-08-09)
- `specs/errors.json` entries `err_1786349061556_LuKGif`, `err_1786350581273_TAWj0I`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The load-bearing staleness caveat is now satisfied.** Both dependency tasks (32: deploy, 18:
  staleness detection) are `completed`. Task 32's deploy landed cleanly (16/16 files reconciled
  byte-identical) and `check-deploy-freshness.sh` confirms the current `.claude/` tree is fresh
  (exit 0, no warning) as of this measurement.
- **Fresh re-measurement finds exactly 4 orphan files, not 11.** The task description's
  2026-08-24 "REVISED" scope correction — claiming the entire `context/orchestration/` directory
  (10 files) plus `docs/architecture/architecture-spec.md` are orphaned, and that `docs/README.md`
  is "no longer" one — is **factually wrong** when checked against a genuinely clean scratch
  regenerate. The revision itself appears to have been produced by an unreliable method (see
  below), not by an actual scratch-vs-live diff.
- **The true orphan set matches the ORIGINAL (pre-revision) 4-file description and the errors.json
  evidence exactly**: `context/orchestration/orchestration-validation.md`,
  `context/orchestration/subagent-validation.md`, `docs/architecture/architecture-spec.md`,
  `docs/README.md`.
- **Root cause is now fully confirmed with a git-history smoking gun**, not just inferred from
  mechanism: commits `0e6245fd0` and `89eac9896` (2026-08-09, "task 986" per their own commit
  messages — cited here only as a commit hash/session pointer, not as a live dependency) deleted
  these exact four files from the source store as part of a deliberate consolidation, and updated
  `index-entries.json` to remove the corresponding index rows. The deploy tree captured these
  files just before that consolidation landed (their deployed mtimes are `Aug 9 20:12`, minutes
  before the `20:39`/`20:47` deletion commits) and has never been cleaned since, because the
  default (non-destructive) resync/merge path never deletes anything.
- **Recommendation for planning**: resolve the 4 real orphans (delete the 4 stale deployed files
  and the 2 stale `context/index.json` entries), and separately decide direction (a) vs (b) for
  the mechanical gap. Do not act on the REVISED 11-file scope; supersede it with this
  measurement.

## Context & Scope

Task 9 asks to resolve a declared-vs-deployed parity gap: `provides.*` categories are verified
only in the declared→deployed direction (missing/hash-mismatch), never the reverse
(deployed-but-no-longer-declared). The task's own description carries a load-bearing staleness
caveat: an earlier orphan-file count was measured against a deploy tree later shown to be 7 days
and 133 commits stale, so that count could be an artifact of staleness rather than genuine
parity drift, and re-measurement was required before treating any count as evidence. A 2026-08-24
"REVISED" edit to the task description asserted a corrected count of 11 files without describing
its measurement method.

This research re-measures the orphan set from scratch, using the same "clean scratch regenerate"
technique the task calls for, confirms the dependency preconditions are met, and adjudicates
between the ORIGINAL 4-file claim, the REVISED 11-file claim, and the errors.json evidence.

## Findings

### Dependency preconditions are satisfied

- Task 32 (`redeploy_and_remediate_install_once_settings`) status is `completed`. Its summary:
  "Deployed the agent-system source store to .claude/ (16 files, making the mint-dispatch-seq
  persisted-counter fix and three literature hardening fixes live)... proved baseline-relatively
  via verify-deploy.sh that the deploy introduced zero net functional regressions." This deploy
  used the default (non-destructive) resync mode, not `--wipe`.
- Task 18 (`detect_stale_claude_deploy_trees`) status is `completed`. Its detection mechanism
  (`check-deploy-freshness.sh`) is live and wired into gate-in.
- Running `bash .claude/scripts/check-deploy-freshness.sh` against the current tree exits `0`
  with no warning output — the tree is fresh as of this research.

The staleness caveat's precondition ("do not start before [the deploy task]") is therefore
cleared. This report's measurement is against the current, freshly-deployed tree.

### Methodology: genuine clean scratch regenerate

Mirroring the technique already used for the errors.json evidence (task 996's Phase 1 diff) and
recorded as reusable technique by task 18:

1. `git clone --no-local` this repo into a scratch directory (inherits the same
   `.claude-extensions.json` active-extension set, but starts with **no** `.claude/` at all).
2. `bash .claude/scripts/deploy-headless.sh <scratch>` — default resync mode bootstraps `core`
   and resyncs the other 5 currently-active extensions into the scratch tree from the current
   source store.
3. `diff <(find .claude -type f | sort) <(find <scratch>/.claude -type f | sort)` — lines only on
   the live side are orphan candidates (present in the deployed tree, absent from a fresh
   regenerate of the same active-extension set).

Raw live-only lines included expected non-manifest noise, filtered out because none of it is a
`provides.*`-declared deploy artifact:
- `tmp/workflow-active-*` — runtime session-lock files, not deploy content.
- `scripts/literature-pyenv/venv/**` — an **uncommitted** local Python venv sitting in the source
  store working tree (matches the `??` untracked entry already visible in `git status`); a
  scratch `git clone` only clones committed content, so this is a working-tree artifact, not a
  deploy orphan.
- `context/repo/project-overview.md` — declared in `core/manifest.json` (`project-overview.md`
  leaf) **and** explicitly listed in `.syncprotect`, so it is correctly excluded from overwrite
  during sync; not an orphan.
- `RESUME.md`, `scripts/__pycache__/*.pyc` — runtime artifacts with no manifest entry anywhere;
  out of scope for this task.

### The real orphan set: 4 files, matching the ORIGINAL description exactly

After filtering, the live-only diff reduces to exactly:

| File | Deployed mtime | Also a ghost `context/index.json` entry? |
|---|---|---|
| `.claude/context/orchestration/orchestration-validation.md` | Aug 9 20:12 | Yes — line 711 (`path: "orchestration/orchestration-validation.md"`) |
| `.claude/context/orchestration/subagent-validation.md` | Aug 9 20:12 | Yes — line 835 (`path: "orchestration/subagent-validation.md"`) |
| `.claude/docs/architecture/architecture-spec.md` | (Aug 9, same cycle) | No — plain directory-copy artifact, not index-tracked |
| `.claude/docs/README.md` | Aug 9 20:12 | No — plain artifact, not index-tracked |

All four carry the same stale `Aug 9 20:12` deploy timestamp, in contrast to their correctly
current siblings in the same directories, which were freshly rewritten at `Aug 24 14:21`/`14:54`
by task 32's redeploy (byte-identical, confirmed by diffing live vs. scratch for every other file
in `context/orchestration/` and `docs/architecture/`).

This is an **exact match** to the ORIGINAL (pre-revision) task description and to
`err_1786350581273_TAWj0I`'s recorded evidence (same 4 paths, same "confirmed via task 996 Phase
1 comm -23 diff" method this report independently reproduced).

### The REVISED 2026-08-24 "11-file" scope correction is incorrect

The revision claims the entire `context/orchestration/` directory (10 files: `architecture.md`,
`delegation.md`, `orchestration-core.md`, `orchestration-reference.md`,
`orchestration-validation.md`, `orchestrator.md`, `postflight-pattern.md`, `preflight-pattern.md`,
`sessions.md`, `subagent-validation.md`) plus `docs/architecture/architecture-spec.md` has "no
source-store owner," and that `docs/README.md` is no longer orphaned.

Both claims are false against a fresh scratch regenerate:

- `agent-system/extensions/core/context/orchestration/` in the current source store contains
  exactly 10 files: `architecture.md`, `delegation.md`, `orchestration-core.md`,
  `orchestration-reference.md`, `orchestrator.md`, `postflight-pattern.md`,
  `preflight-pattern.md`, `sessions.md`, `state-management.md`, `validation.md`. Eight of these
  ARE named in the revised orphan list and yet DO deploy byte-identically into the scratch tree —
  they have valid source-store owners. (`state-management.md` and `validation.md`, present in
  source and correctly deployed, were not even named by the revision, which further suggests the
  revision was based on eyeballing a live directory listing rather than a real declared-vs-deployed
  diff.)
- `docs/README.md` is unambiguously still present in the live tree (`.claude/docs/README.md`,
  11032 bytes) and unambiguously absent from the scratch regenerate — it is not "dropped from the
  set," it is one of the 4 real orphans.

The revision should be treated as superseded by this measurement, not acted on as written.

### Root cause: confirmed by git history, not just mechanism

The mechanical reason was already correctly diagnosed in the task description and this research
confirms it by direct code inspection without needing to re-derive it:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua`'s `M.verify_extension` result shape
  (`verification.errors`) is populated only from "Missing …" (declared-not-deployed) and "Content
  differs from source" (hash-mismatch) cases — no code path records a deployed-but-undeclared
  file.
- `agent-system/extensions/core/scripts/install-extension.sh`'s `merge_index_entries()`
  (lines 179-230) does `.entries += (...)` unconditionally — purely additive, no stale-entry
  removal, for either schema variant it handles.
- `install-extension.sh` is a still-live, distinct deploy mode ("symlink installer," documented
  in `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md`),
  separate from the `manager.lua`-driven copy engine `deploy-headless.sh` uses by default — both
  mechanisms share the same additive-only defect independently.

New in this research — a direct git-history confirmation of *why these specific 4 files* are
orphaned, beyond the general mechanism: commit `0e6245fd0` ("...purge dead script references")
deleted `architecture-spec.md` (599 lines describing a never-implemented component) from the
source store, and commit `89eac9896` ("...consolidate validation docs and fold docs/README.md")
merged `subagent-validation.md` + `orchestration-validation.md` into `orchestration/validation.md`
(explicitly updating source `index-entries.json` to remove the 2 entries) and folded
`docs/README.md` into `docs-README.md`. Both commits are dated 2026-08-09, minutes before the
`Aug 9 20:12` mtime baked into the still-deployed orphan copies. The source-store side did
everything correctly, including its own index cleanup; the deploy tree simply has never been
regenerated destructively (`--wipe`) since, so the additive-only copy/merge mechanism preserved
these 4 stale files and the 2 stale `context/index.json` rows indefinitely.

### Decisions

- Treat this report's 4-file measurement as authoritative, superseding both the ORIGINAL
  description's un-re-verified count and the REVISED description's incorrect 11-file count.
- The staleness-caveat precondition (deploy first, task 18 first) is satisfied; planning may
  proceed without further sequencing delay.

## Risks & Mitigations

- **Risk**: a planner reads only the REVISED task description and drafts a plan against the
  wrong 11-file/8-legitimate-file set, deleting files that are in fact correctly declared and
  deployed (`architecture.md`, `delegation.md`, etc.), which would break real content.
  **Mitigation**: this report documents the exact scratch-regenerate methodology and per-file
  verification table so the planner can re-verify quickly rather than trust either prior claim.
- **Risk**: re-running this measurement later without a fresh deploy could reintroduce the same
  staleness trap this task was originally burned by. **Mitigation**: `check-deploy-freshness.sh`
  is now a cheap, already-wired precondition check — run it (or accept a WARN from ordinary
  command gate-in) before trusting any future orphan count.
- **Risk**: direction (a) (mechanical orphan detection in `verify.lua`/`verify-deploy.sh`) and
  direction (b) (document one-directional-by-design) are still an open decision this report does
  not resolve, per the task's own instruction to decide ONE direction during implementation, not
  research.

## Context Extension Recommendations

- **Topic**: deploy-tree orphan/parity verification.
- **Gap**: no existing context file documents the "clean scratch regenerate" measurement
  technique (git clone + `deploy-headless.sh` into scratch + filtered diff) as the correct way to
  distinguish real orphans from runtime noise (`tmp/workflow-active-*`, uncommitted venvs,
  syncprotected files). It currently lives only in ad hoc task history (task 996, task 18's
  memory candidates, and now this report).
- **Recommendation**: whichever direction (a)/(b) is implemented for this task should also fold
  this measurement recipe into a durable context file (e.g. a new
  `context/patterns/orphan-file-measurement.md` or an addition to the deploy-engine
  documentation), so a future orphan-count claim can be verified the same way rather than
  reintroducing the same "was this measured against a stale/dirty tree?" ambiguity this task
  itself was burned by twice.

## Appendix

- Commands run: `git clone --no-local <repo> <scratch>`; `bash .claude/scripts/deploy-headless.sh
  <scratch>`; `bash .claude/scripts/check-deploy-freshness.sh`; `diff <(find .claude -type f |
  sort) <(find <scratch>/.claude -type f | sort)`; targeted `find`/`ls -la`/`grep` on
  `context/orchestration/`, `docs/architecture/`, `context/index.json`, and
  `install-extension.sh`; `git log --diff-filter=D --summary -- '**/architecture-spec.md'
  '**/docs/README.md'`.
- Git commits cited: `0e6245fd06f976c90298eb7da202e57ea90c4133`,
  `89eac9896b0b70d24c051c3d81f92e0ab064673a` (both 2026-08-09).
- errors.json entries cross-checked: `err_1786349061556_LuKGif` (deploy_ghost_index_entries),
  `err_1786350581273_TAWj0I` (deploy_orphan_files_undercounted).
