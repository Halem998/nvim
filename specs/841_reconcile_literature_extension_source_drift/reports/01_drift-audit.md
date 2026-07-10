# Research Report: Task #841

**Task**: 841 - Reconcile literature extension source drift
**Started**: 2026-07-10T00:00:00Z
**Completed**: 2026-07-10T00:00:00Z
**Effort**: research (audit only, no edits made)
**Dependencies**: None
**Sources/Inputs**: - `diff`, `git log`/`git blame`, `grep -c`, manifest.json inspection, sync-engine source read (`lua/neotex/plugins/ai/shared/extensions/{init,loader}.lua`)
**Artifacts**: - `specs/841_reconcile_literature_extension_source_drift/reports/01_drift-audit.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Drift is real, confirmed, and broader than the task description's two flagged files.** Of 11 scripts + 1 command file present in both `.claude/scripts/` and `.claude/extensions/literature/scripts/`, **6 differ** (`literature-briefing.sh`, `literature-chunk.sh`, `literature-convert.sh`, `literature-ingest.sh`, `literature-schema.sql`, `literature-search.sh`); 5 are identical. `literature.md`/`cite.md` command files are not drifted the same way — `literature.md` is byte-identical, `cite.md` was **never deployed at all** (separate issue, see Appendix).
- **Direction of truth is deployed → extension for every differing file, with no exceptions.** Git history shows the extension-source copy of every drifted file has received exactly one commit since its creation (the task #793 migration commit `0326bcbbb`, "migrate literature scripts into extension source"), while the deployed copy has received multiple subsequent correctness-fix commits from tasks #831, #833, #835, #839. No genuine conflicting extension-only edit was found for any drifted file — safe to backport deployed → extension source with no STOP-and-report cases.
- **The regression risk is confirmed live, not theoretical.** `lua/neotex/plugins/ai/shared/extensions/loader.lua`'s `copy_scripts()` does a byte-for-byte overwrite of `.claude/scripts/<name>` from `.claude/extensions/literature/scripts/<name>` for every filename in `manifest.provides.scripts`, gated only by `.syncprotect`. All 6 drifted scripts (plus `literature-schema.sql`) **are** listed in `.claude/extensions/literature/manifest.json`'s `provides.scripts`, and **none** of them appear in `.syncprotect`. The next "Load"/reload of the `literature` extension via the picker (`M.create` in `init.lua`) will silently overwrite all 6 files with the stale, pre-fix content.
- **`literature-fidelity-audit.sh` should be added to the extension source.** It is task #835/#839's provenance/fidelity *producer* (writes `.provenance_fidelity`/`unadjudicated` markers), while `literature-search.sh` and `literature-briefing.sh` — both already extension-owned — are the *consumers* of those markers. Shipping the consumer logic without the producer tool in the extension is an incomplete capability. It uses the same portable `LITERATURE_DIR` env-var-with-default pattern already used by extension-owned scripts, so there's no portability blocker.
- **Recommended guard: extend `check-extension-docs.sh` with a content-diff check (option a)**, not `.syncprotect` (option b). `.syncprotect` prevents *deployed→never-updated-by-sync*, which is the wrong tool here — these scripts *should* stay sync-able; the actual problem is that hotfixes bypass the extension source. A CI-style diff check that fails when `.claude/scripts/literature-*.sh` differs from its extension-source counterpart catches the drift at the moment it's introduced (next commit/task), rather than freezing today's content in place.
- **A second, independent drift also exists in the opposite direction**: `zotero-attach-chunks.sh`, `zotero-chunk.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-read.sh`, `zotero-search.sh`, `zotero-setup.sh`, `zotero-write.sh`, `cite-extract.sh`, and `test-lit-pipeline.sh` exist **only** in the extension source (never deployed to `.claude/scripts/`), despite being listed in `manifest.provides.scripts`. This is not a regression risk (nothing to revert — they were never installed) but is worth flagging as a related, lower-priority gap; likely because the `literature` extension is not tracked as "loaded" in `.claude/extensions.json` at all (see Appendix), so no reload has run since these were added to the manifest.

## Context & Scope

Scope per task #841 description: audit every file present in both `.claude/scripts/` and `.claude/extensions/literature/scripts/`, plus `.claude/commands/literature.md` and `cite.md` vs their extension-source counterparts; determine direction-of-truth per file; recommend fate of `literature-fidelity-audit.sh`; recommend a guard mechanism; and document the deploy/sync mechanism (to establish whether legitimate path-substitution differences are possible). This is research only — no files were modified. Verification commands and counts below were re-run 2026-07-10 and match the task description's 2026-07-09 baseline.

## Findings

### Drift Manifest (complete)

**Files present in both `.claude/scripts/` and `.claude/extensions/literature/scripts/`:**

| File | Exists both? | Differ? | `unadjudicated` deployed / ext | Nature of diff | Direction of truth | Recommended action |
|---|---|---|---|---|---|---|
| `literature-briefing.sh` | Yes | **Yes** (156 diff lines) | 3 / 0 | Task #833 honest-degraded-rendering + task #835 loud provenance flagging + task #839 `needs_fidelity_marker()` allowlist fix (fail-open bug fix; `provenance_fidelity` grep: 8 deployed / 0 ext) | **Deployed** | Backport deployed → extension source |
| `literature-search.sh` | Yes | **Yes** (680 diff lines) | 2 / 0 | Task #833 fallback ladder + lazy trigram migration + query sanitization; task #835 `--include-unverified` flag, quarantine-from-ranked-output logic (`quarantine` grep: 11 deployed / 0 ext; `include-unverified` grep: 7 deployed / 0 ext); task #839 fail-open widening | **Deployed** | Backport deployed → extension source |
| `literature-schema.sql` | Yes | **Yes** (52 diff lines) | n/a | Task #833: adds `chunks_trigram` FTS5 fallback table + `content` column repair to `chunks_data` (three-table architecture); extension source still has the old two-table architecture | **Deployed** | Backport deployed → extension source |
| `literature-chunk.sh` | Yes | **Yes** (14 diff lines) | n/a | Task #831 phase 1 "BUG 3 fix": `section_stack[:-1]` slice to stop doubled breadcrumbs (`Doc > X > X`) | **Deployed** | Backport deployed → extension source |
| `literature-convert.sh` | Yes | **Yes** (881 diff lines) | n/a | Task #831 phases 2-6: conversion engine tier rewrite, BUG 2/BUG 4 fixes, quality-gate exit 3 contract, forced-fallback + regression test harness | **Deployed** | Backport deployed → extension source |
| `literature-ingest.sh` | Yes | **Yes** (87 diff lines) | n/a | Task #831 phase 5: distinguishes quality-gate rejection (exit 3) from hard failure (exit 1/2) in a separate counter/list; explicit exit-code capture instead of swallowing via `\| tail -1` | **Deployed** | Backport deployed → extension source |
| `literature-build-index.sh` | Yes | No (identical) | n/a | — | n/a (in sync) | None |
| `literature-create-setup-task.sh` | Yes | No (identical) | n/a | — | n/a (in sync) | None |
| `literature-discover.sh` | Yes | No (identical) | n/a | Separate git histories (deployed: task #797 phase 4 "dual-copy re-sync"; ext: task #797 phase 2) but content converged — task #797 already performed a manual resync for this one file | n/a (in sync) | None |
| `literature-lit-flag-resolve.sh` | Yes | No (identical) | n/a | Created by task #775 in both locations simultaneously (shared commit) | n/a (in sync) | None (but see manifest gap below) |
| `literature-normalize-authors.sh` | Yes | No (identical) | n/a | Created by task #801 in both locations simultaneously (shared commit) | n/a (in sync) | None |

**Command files:**

| File | Exists both? | Differ? | Notes | Recommended action |
|---|---|---|---|---|
| `literature.md` (command) | Yes | No (identical) | In sync | None |
| `cite.md` (command) | **No** — extension-source only | n/a | Never deployed to `.claude/commands/`; not a content-drift case, a deployment gap. `git log` shows `cite.md` was added under `.claude/extensions/literature/commands/` by task #718 and has no deployed counterpart at any point in history. `manifest.provides.commands` lists it, so a future extension load/reload would deploy it (this is one-directional — it would newly appear, not overwrite anything). | Out of #841's core scope (no correctness-fix reversion risk); flag as a follow-up: confirm intentional vs. oversight |

**Files present in `.claude/scripts/` only (not in extension source or manifest):**

| File | In extension source? | In manifest `provides.scripts`? | Notes | Recommended action |
|---|---|---|---|---|
| `literature-fidelity-audit.sh` | No | No | Task #835 (core) / #839 (fixes) — provenance/fidelity classifier and stamper for the `~/Projects/Literature` corpus. Consumer logic (`unadjudicated` handling) for its output already lives in the now-drifted `literature-search.sh`/`literature-briefing.sh` | **Add to extension source** (see Decision 1) |
| `literature-audit.sh` | No | No | Task #721 phase 1: one-time **pre-implementation** audit (conversion-tool selection + xref regex recall/precision), dated 2026-06-15, describes tool-selection decisions already made. Distinct tool from `literature-fidelity-audit.sh` (different purpose: dev-time audit vs. re-runnable corpus classifier) | Keep repo-local; it is a historical dev-time artifact, not a runtime pipeline component |
| `literature-retrieve.sh` | Yes — but under `.claude/extensions/**core**/scripts/`, not `literature` | Not in `literature` manifest | DEPRECATED per its own header (superseded by `literature-briefing.sh`, task #758); owned by the `core` extension, byte-identical to deployed copy already | No action — already correctly owned/synced by `core` |
| `literature-briefing-invoke.sh` | No | No | Task #800-801: failure-surfacing wrapper around `literature-briefing.sh` | Candidate for extension inclusion (same rationale class as fidelity-audit, lower priority — not flagged as regression-risk in task description) |
| `literature-pyenv-provision.sh` | No | No | Task #831 phase 2: pinned `uv` venv provisioning with nix-ld shim for `literature-convert.sh` | Tightly coupled to `literature-convert.sh` (which IS extension-owned and drifted) — should likely travel with it into the extension, but out of #841's stated scope |
| `literature-pyenv/` (directory) | No | No | Runtime venv artifact (generated, not source) | No action — not a source file |
| `zotero-resolve-pdf.sh` | No | No | Task #836: read-only doc_id → Zotero PDF resolver | Same category as `literature-fidelity-audit.sh` (repo-local tool never migrated) — candidate for extension inclusion, out of #841's stated scope |

**Files present in extension source only (never deployed):**

| File | Deployed? | In manifest? | Notes |
|---|---|---|---|
| `zotero-attach-chunks.sh`, `zotero-chunk.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-read.sh`, `zotero-search.sh`, `zotero-setup.sh`, `zotero-write.sh`, `cite-extract.sh`, `test-lit-pipeline.sh` | No | Yes — all listed in `manifest.provides.scripts` | Opposite-direction drift: extension source is ahead, deployed copy is simply absent. Not a regression-reversion risk (nothing to overwrite/lose), but confirms the `literature` extension has not gone through a tracked load/reload cycle recently — see Appendix on `.claude/extensions.json` |

### Direction-of-Truth Evidence (git history)

For every differing file, extension-source history stops at the single migration commit; deployed history continues with task-numbered fix commits:

```
literature-search.sh
  deployed:   99aba054 task 839 phase 1.3 | db4ffe2b task 833 phase 3 | 6f1cb44d task 833 phase 1 | bdf54ff3 task 835 phase 3 | dee78818 task 735
  extension:  0326bcbb task 793 phase 1: migrate literature scripts into extension source and declare in manifest  (only commit)

literature-briefing.sh
  deployed:   99aba054 task 839 phase 1.3 | 2259e212 task 833 phase 4 | bd476d78 task 835 phase 4 | 50397d71 task 799 | ff5da8bd task 775 phase 1
  extension:  ff5da8bd task 775 phase 1 (shared) | 40621162 task 793 phase 2 | 1cd66a47 fix: manifest scripts/context   (no post-793 fix commits)

literature-schema.sql
  deployed:   487e5b86 task 833 phase 2: add chunks_trigram and repair schema drift | 3796c7bd task 721 phase 2
  extension:  0326bcbb task 793 phase 1 (only commit)

literature-chunk.sh
  deployed:   fc3f7924 task 831 phase 1: fix BUG 3 breadcrumb doubling | 99ae5cdf task 721 phase 3
  extension:  0326bcbb task 793 phase 1 (only commit)

literature-convert.sh / literature-ingest.sh
  deployed:   b4b4fbbd/19850817/f29d58c5 task 831 phases 3-6 | 3796c7bd/7e5c42b0 task 721
  extension:  0326bcbb task 793 phase 1 (only commit)
```

No extension-source-only edit was found for any of these 6 files post-migration — there is no case requiring the "STOP and report conflict" branch from the task description. All backports are clean deployed → extension-source copies.

### Regression-Risk Confirmation (sync mechanism)

`manifest.provides.scripts` in `.claude/extensions/literature/manifest.json` lists all 6 drifted scripts plus `literature-schema.sql` verbatim:

```
'literature-briefing.sh', ... 'literature-discover.sh', 'literature-ingest.sh', 'literature-search.sh',
'literature-build-index.sh', 'literature-convert.sh', 'literature-chunk.sh', 'literature-normalize-authors.sh',
'literature-schema.sql'
```

`.syncprotect` (project root) currently contains only:
```
context/repo/project-overview.md
output/implementation-001.md
```
— confirming the task description's claim that none of the literature scripts are protected.

`lua/neotex/plugins/ai/shared/extensions/loader.lua`'s `copy_scripts(manifest, source_dir, target_dir, protected_paths)`:
- Iterates `manifest.provides.scripts`, source = `<extension>/scripts/<name>`, target = `.claude/scripts/<name>`.
- Calls `copy_file()`, which performs a **byte-for-byte overwrite** (no templating, no path substitution) unless `protected_paths["scripts/<name>"]` is set from `.syncprotect`.
- `copy_scripts` is invoked from `M.create()` in `lua/neotex/plugins/ai/shared/extensions/init.lua` — this is the **extension load/reload** path (triggered via the picker's "Load extension" action for `literature`), which is a distinct code path from the "Load Core Agent System" operation (`picker/operations/sync.lua`, which only handles the `core` extension's artifacts pulled from a separate global source repo).
- Confirms: no legitimate path-substitution differences exist between deployed and extension-source script content — `copy_file` is a plain copy. Any diff found by `diff` today is genuine drift, not a sync-time transformation artifact.

**This confirms the regression is live**: the next time anyone triggers a load/reload of the `literature` extension, `copy_scripts` will silently overwrite all 6 drifted `.claude/scripts/literature-*.sh`/`.sql` files with the stale extension-source content, reverting tasks #831, #833, #835, and #839's fixes in one operation.

### Appendix note: `literature` extension is not tracked as loaded

`.claude/extensions.json` (`extensions` key) lists only `core`, `nix`, `memory`, `nvim` as loaded — **no `literature` entry exists**, despite `.claude/scripts/literature-*.sh`, `.claude/commands/literature.md`, and `.claude/skills/skill-literature` all being present and in active use. This means the deployed literature files were installed by some means outside the currently-tracked load/reload bookkeeping (most plausibly: task #793's migration ran the copy in the opposite direction, extracting already-deployed scripts *into* the newly created extension source, without ever recording a `literature` load event). Practical implication: the picker would currently offer to "Load" (not "Reload") the `literature` extension, and doing so would still run the full overwrite described above (the copy engine does not consult `extensions.json` to decide whether to overwrite existing files — it only uses it for UI state and warns "N existing files will be overwritten"). This also explains why the zotero-\*/cite-extract/test-lit-pipeline files were never deployed: nothing has triggered a load/reload since they were added to the manifest.

## Decisions

1. **`literature-fidelity-audit.sh` fate: ADD to extension source.** Justification: `literature-search.sh` and `literature-briefing.sh` are both extension-owned and both consume the `provenance_fidelity`/`unadjudicated` markers this script produces (`unadjudicated`, `--include-unverified`, quarantine logic). Shipping consumers without the producer leaves the extension's fidelity-flagging feature incomplete for any other repo that loads it. The script already uses the portable `LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"` pattern matching extension-owned scripts — no portability blocker. Add the file to `.claude/extensions/literature/scripts/literature-fidelity-audit.sh` and register `'literature-fidelity-audit.sh'` in `manifest.provides.scripts`.

2. **Guard mechanism: extend `check-extension-docs.sh` (option a), not `.syncprotect` (option b).** `.syncprotect` freezes today's deployed content and prevents *any* future sync from touching it — including legitimate future extension-source improvements that should propagate. That is the wrong invariant: the actual failure mode is that tasks edited the deployed copy and forgot to also edit the extension source, not that sync itself is unwelcome. A content-diff check added to `.claude/scripts/check-extension-docs.sh` (which already iterates `.claude/extensions/*/` checking manifest/README consistency) that additionally diffs every `manifest.provides.scripts` entry's deployed copy (`.claude/scripts/<name>`) against its extension-source copy (`<ext>/scripts/<name>`) and fails non-zero on any difference would catch drift at the commit where it's introduced — forcing the author to either update both copies in the same task or explicitly suppress with a documented reason. This is consistent with the existing doc-lint's exit-code contract (0 = pass, 1 = fail) and its "manifest entries referencing nonexistent files" check style. Option (c), a pre-sync verification step, is a reasonable secondary/defense-in-depth addition (warn immediately before an overwrite happens) but doesn't prevent the drift from accumulating between hotfixes the way a CI-style check does; recommend it as optional follow-up, not primary guard.

## Risks & Mitigations

- **Risk**: Backporting `literature-schema.sql`'s `chunks_trigram` addition into the extension source could be misread as an instruction to also run it against a live, already-populated corpus DB (the file's own header warns it is a clean-rebuild/DROP script, not a migration). **Mitigation**: implementation must only edit the extension-source *file*, never execute the deployed schema file against `~/Projects/Literature/.literature.db`.
- **Risk**: `literature-convert.sh`'s diff is large (881 lines) — highest chance of a subtle transcription error during backport. **Mitigation**: implementation should copy the deployed file's content into the extension-source path verbatim (not hand-edit / re-derive), then re-run `diff` to confirm byte-identical result, satisfying the task's stated verification bar directly.
- **Risk**: Adding `literature-fidelity-audit.sh` to the extension changes `manifest.provides.scripts`, which is also the exact mechanism the guard check will diff against — sequencing matters (add file + manifest entry, then verify guard treats it as in-sync, not as a new violation).
- **Risk**: `literature-fidelity-audit.sh --dry-run` byte-identical-output verification (required by task #841's own acceptance criteria) must be captured **before** any edits as a baseline, since this task only adds/moves the file into the extension source and must not touch the deployed copy's behavior at all.

## Context Extension Recommendations

- **Topic**: Extension source / deployed-copy consistency guarantee.
- **Gap**: No existing context file documents the invariant "if a script is listed in `manifest.provides.scripts`, its extension-source and deployed copies must be kept in sync outside of scheduled loads/reloads" or the fact that `copy_scripts` performs a byte-for-byte overwrite with no path substitution.
- **Recommendation**: Once task #841's guard is implemented, add a short section to `.claude/docs/guides/creating-extensions.md` (or wherever extension authoring guidance lives) documenting this invariant and pointing at the new `check-extension-docs.sh` diff check, so future literature-style hotfixes edit both copies (or run the extension's own installer) instead of only the deployed one.

## Appendix

### Search / verification commands used

```bash
diff .claude/scripts/<f> .claude/extensions/literature/scripts/<f>
grep -c unadjudicated .claude/scripts/literature-{search,briefing}.sh
grep -c unadjudicated .claude/extensions/literature/scripts/literature-{search,briefing}.sh
grep -c -E "include-unverified|quarantine|provenance_fidelity|needs_fidelity_marker" <both copies>
git log --oneline -- .claude/scripts/<f>
git log --oneline -- .claude/extensions/literature/scripts/<f>
comm -23 <(ls .claude/scripts | grep -iE '^literature|^zotero|^cite' | sort) <(ls .claude/extensions/literature/scripts | sort)
comm -13 <(ls .claude/scripts | grep -iE '^literature|^zotero|^cite' | sort) <(ls .claude/extensions/literature/scripts | sort)
python3 -c "import json; print(json.load(open('.claude/extensions/literature/manifest.json'))['provides']['scripts'])"
grep -n "syncprotect|protected_paths" lua/neotex/plugins/ai/shared/extensions/{init,loader}.lua
```

### File paths referenced

- `.claude/scripts/literature-{search,briefing,chunk,convert,ingest}.sh`, `literature-schema.sql`, `literature-fidelity-audit.sh`, `literature-audit.sh`, `literature-retrieve.sh`, `literature-briefing-invoke.sh`, `literature-pyenv-provision.sh`, `zotero-resolve-pdf.sh`
- `.claude/extensions/literature/scripts/*` (source of truth)
- `.claude/extensions/literature/manifest.json` (`provides.scripts`, `provides.commands`)
- `.claude/commands/literature.md`, `.claude/extensions/literature/commands/{literature,cite}.md`
- `.claude/scripts/check-extension-docs.sh` (existing doc-lint, extension point for guard)
- `.syncprotect` (project root)
- `.claude/extensions.json`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (`copy_scripts`, `copy_file`, `load_syncprotect`)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (`M.create`, extension load/reload orchestration)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (separate "Load Core" cross-repo sync, not the mechanism responsible for this drift)
