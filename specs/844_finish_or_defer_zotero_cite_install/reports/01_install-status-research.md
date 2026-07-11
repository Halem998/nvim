# Research Report: Task #844

**Task**: 844 - Finish or formally defer the incomplete literature-extension install
**Started**: 2026-07-10
**Completed**: 2026-07-10
**Effort**: research
**Dependencies**: task 841 (drift guard, quarantine rule), task 842 (convert pipeline fix)
**Sources/Inputs**: Codebase (git log, grep, jq), `.claude/extensions/literature/` source tree, deployed `.claude/`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The ten "extension-source-only" scripts and `cite.md` are **not one homogeneous group**. Evidence splits them into three distinct categories with three different correct dispositions: (1) a complete, self-consistent, ready-to-activate feature (`/cite` trio), (2) live-but-optional infrastructure that already degrades gracefully (`zotero-search.sh`), and (3) genuinely deferred/superseded/blocked capability (the remaining seven zotero scripts + `test-lit-pipeline.sh`).
- **`/cite` trio (`cite-extract.sh` + `skill-cite` + `cite.md`)** was built end-to-end across three same-day tasks (716, 717, 718 — all 2026-06-15) with `skill-cite` fully wired to call `cite-extract.sh`, and `cite.md` fully wired to delegate to `skill-cite`. None of the three plans ever mention deployment — this is a scoping gap, not a deliberate deferral. **This is a genuinely unfinished install** (research question option (a)).
- **`zotero-search.sh`** is already referenced by live, deployed code: `skill-literature/SKILL.md` (lines ~1206-1269) resolves it via a 3-path fallback that checks the deployed copy first, then falls back directly to the extension-source copy. It requires no external CLI (reads a CSL-JSON export file directly). It is de facto live already via fallback; deploying it is a low-risk consistency fix, not new functionality.
- **`zotero-index-add.sh` / `zotero-index-remove.sh` are dead code, not unfinished code**: `skill-literature/SKILL.md` reimplements the same "add/remove `specs/literature-index.json` entry" logic inline with `jq` (lines ~2154-2189) rather than shelling out to these scripts. They were superseded during the task-758 consolidation and never pruned.
- **`zotero-read.sh` / `zotero-write.sh` / `zotero-setup.sh`** all depend on the external `zot` CLI (`zotero-cli-cc`), which is **not installed** in this environment (`which zot` → exit 1). They have zero live callers. Activating them now would deploy non-functional-without-external-setup scripts.
- **`zotero-chunk.sh` / `zotero-attach-chunks.sh`** implement a write-back-to-Zotero PDF-chunking/annotation workflow that is architecturally orthogonal to (and superseded by) the current read-only "briefing+tools" design adopted in task 758. No live caller.
- **`test-lit-pipeline.sh`** is a test harness (`# Validate the full --lit pipeline wiring for CSLib tasks`) per the task's own instruction, and must never be deployed as a runtime script — confirmed by its content and by `check-extension-docs.sh`'s comment explicitly grouping it with the intentionally-undeployed zotero scripts.
- **The `literature` extension itself has no entry in `.claude/extensions.json`** at all (unlike `core`, `nix`, `nvim`, `memory`, which all have full `loaded_at`/`installed_files` tracking). This is a pre-existing, broader structural gap outside this task's stated scope, but it is directly relevant context: there is no working "extension sync" mechanism currently tracking this extension's deploy state, so "finishing the install" for `/cite` cannot rely on an automated sync — it requires manual file copies plus manual `CLAUDE.md` table fixes.
- **Overall recommendation: a split decision, not a uniform one.** Finish the install for the `/cite` trio (deploy `cite.md`, `skill-cite`, `cite-extract.sh`; add `skill-cite` to the CLAUDE.md skill-agent-mapping table; the `/cite` command-table row is already present). Deploy `zotero-search.sh` for consistency with its existing live fallback reference (optional but low-risk). Formally document-as-inactive the remaining six zotero scripts (`read`, `write`, `setup`, `chunk`, `attach-chunks`, and prune-candidates `index-add`/`index-remove`) plus `test-lit-pipeline.sh`, updating the literature README's "Zotero Integration" table to state their status explicitly (blocked-on-external-CLI or superseded-by-inline-logic) rather than presenting them as available.

## Context & Scope

Task 844 asks: for each of the 10 extension-source-only scripts and `cite.md`, determine — based on git history, live-code references, manifest declarations, and external-dependency analysis — whether it is (a) an intended-but-unfinished feature or (b) intentionally inactive/experimental work. The instruction explicitly warns against reflexively recommending "deploy everything."

Research covered: `git log --follow` on each artifact; `grep` across all deployed `.claude/{skills,commands,agents,rules,CLAUDE.md,context}` for references; `.claude/extensions.json` structure; the literature extension's `manifest.json` `provides.scripts`/`provides.commands`; the literature `README.md`'s documented Zotero-integration status; external-dependency check (`zot` CLI availability); and cross-referencing task 758's implementation summary (which explicitly touched the zotero scripts and explicitly excluded `/cite`).

## Findings

### Codebase Patterns

**Manifest declares everything, tells you nothing about priority.** `.claude/extensions/literature/manifest.json`'s `provides.scripts` lists all 10 target scripts plus 15 others, and `provides.commands` lists `literature.md` and `cite.md`. Declaration in the manifest only means "this extension owns this file" — it is not evidence of active/intended-now status. `provides.skills` also lists both `skill-literature` (deployed) and `skill-cite` (not deployed).

**`.claude/extensions.json` tracks `core`, `nix`, `memory`, `nvim` — not `literature`.** `jq -r '.extensions | keys'` returns `["core", "memory", "nix", "nvim"]`. There is no `"literature"` key at all, meaning by the project's own installed-extension bookkeeping this extension was never "loaded" through the normal picker/sync flow, even though `.claude/commands/literature.md`, `.claude/skills/skill-literature/`, `.claude/agents/literature-agent.md`, and most `literature-*.sh` scripts (16 of them) plus 4 zotero-adjacent scripts (`zotero-export-status.sh`, `zotero-generate-export.sh`, `zotero-resolve-pdf.sh`, `zotero-resolve-sqlite-path.sh`) *are* present in the deployed tree. This confirms the literature extension has always been partially, manually deployed — the 10 scripts + `cite.md` in question are simply the remainder of that partial deployment, not a unique anomaly.

**Git history splits the 11 artifacts into two provenance groups:**

| Group | Artifacts | Origin |
|---|---|---|
| Zotero-suite (8 of 8 present pre-task-758) | `zotero-attach-chunks.sh`, `zotero-chunk.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-read.sh`, `zotero-setup.sh`, `zotero-write.sh` | Added by task 758 phase 2 (2026-06-23), commit `6a20ee309`, as a straight `git mv` of files from a **previously-active, standalone `zotero` extension** (which itself had a deployed agent `.claude/agents/zotero-agent.md` and deployed script `.claude/scripts/zotero-retrieve.sh`, both deleted in the same commit) into `.claude/extensions/literature/scripts/`. |
| `zotero-search.sh` | task 711 (2026-06-14), predates the task-758 consolidation | Purpose-built for the literature extension's Tier-2 (local Zotero) source-discovery step. |
| `/cite` trio | `cite-extract.sh` (task 716), `skill-cite` (task 717), `cite.md` (task 718) — all 2026-06-15 | Built together, same day, as a self-contained new feature. |
| `test-lit-pipeline.sh` | Added 2026-06-23, same day as task 758 (commit `1cd66a47f`, "fix: add missing provides.context and scripts to literature extension manifest") | A manifest-hygiene fix, not a feature task. |

**Task 758's own implementation summary is direct evidence for the zotero group's disposition.** `specs/archive/758_unified_literature_system/summaries/09_unified-literature-summary.md` states: *"The `zotero-retrieve.sh` and `zotero-search-index.sh` removed: Both superseded by `literature-briefing.sh` + `literature-search.sh` FTS5 approach"* and *"The `/cite` command and `skill-cite` were untouched throughout as planned."* This confirms:
1. Task 758 already pruned the zotero scripts that were clearly obsolete (2 scripts deleted).
2. Task 758 consciously decided **not** to touch `/cite` — it was aware of `/cite`'s existence and treated leaving it alone as in-scope-exclusion, not oversight, at the task-758 level. (The *original* non-deployment, from tasks 716/718, is a separate, earlier scoping gap — see below.)
3. The remaining 7 zotero-*.sh scripts (read/write/setup/chunk/attach-chunks/index-add/index-remove) were kept — but kept as source-tree artifacts of the merge, not necessarily as "still wanted" runtime scripts. No task since 758 has revisited them.

**Neither `716_create_cite_extract_script`'s plan nor `718_create_cite_command_file`'s plan mentions deployment at all** (`grep -iE 'deploy|scope'` returns nothing in either plan file). Both tasks' `.orchestrator-handoff.json` show `status: "implemented"` with a single artifact each, both paths rooted at `.claude/extensions/literature/...` — i.e., "success" was defined purely as "file created in extension source," with no deploy step ever specified. This is a scoping gap in the original task design, not a documented decision to keep `/cite` inactive.

### Live-Reference Cross-Check (grep across deployed `.claude/`)

| Artifact | Referenced by live/deployed code? | Detail |
|---|---|---|
| `zotero-search.sh` | **Yes** | `skill-literature/SKILL.md` lines 1206-1269: resolves path via ordered fallback `.claude/scripts/zotero-search.sh` → `$(dirname "$0")/../../scripts/zotero-search.sh` → `.claude/extensions/literature/scripts/zotero-search.sh`; degrades to "index-only search" if none found. Currently resolves via the third (extension-source) path. |
| `zotero-index-add.sh` | **No — superseded** | `skill-literature/SKILL.md` implements the same add-entry logic inline via `jq` (line ~2154-2170: checks for existing `doc_id`, appends, echoes confirmation) instead of calling this script. |
| `zotero-index-remove.sh` | **No — superseded** | Same pattern: `skill-literature/SKILL.md` line ~2180-2189 implements remove-entry inline via `jq` before/after count comparison. |
| `zotero-read.sh` | No | Zero references outside extension source. |
| `zotero-write.sh` | No | Zero references outside extension source. |
| `zotero-setup.sh` | No | Zero references outside extension source. |
| `zotero-chunk.sh` | No | Zero references outside extension source. |
| `zotero-attach-chunks.sh` | No | Zero references outside extension source. |
| `cite-extract.sh` | No (but is called by `skill-cite`, which is itself undeployed) | `skill-cite/SKILL.md` (undeployed) calls `"$script_dir/cite-extract.sh" --format=json` and documents exit codes 0/1/2. This is a complete, coherent internal call chain — just not reachable because `skill-cite` isn't deployed. |
| `cite.md` | No | Not present at `.claude/commands/cite.md`. `CLAUDE.md`'s **Command Reference** table (line 124-125) documents `/cite N` and `/cite N --gaps` as if live. `CLAUDE.md`'s **Skill-to-Agent Mapping** table does **not** list `skill-cite` at all — a live documentation inconsistency between the two tables in the same file. |
| `test-lit-pipeline.sh` | No | Zero references outside extension source; `check-extension-docs.sh` comment explicitly names it as intentionally-absent. |

### External-Dependency Check

`which zot` → exit code 1 (not installed). Reading each zotero script's use of the `zot` CLI:

| Script | Depends on external `zot` CLI? |
|---|---|
| `zotero-read.sh` | Yes ("Read-only operations against Zotero via zot CLI") |
| `zotero-write.sh` | Yes ("Write operations via Zotero Web API through zot") |
| `zotero-setup.sh` | Yes (`--validate`/`--status` sub-commands; `--detect`/`--configure` are exempt per its own usage docs) |
| `zotero-index-add.sh` | Partial (validation path) |
| `zotero-search.sh` | **No** — reads `zotero-library.json` (Better BibTeX CSL-JSON export) directly, no `zot` binary needed |
| `zotero-chunk.sh`, `zotero-attach-chunks.sh`, `zotero-index-remove.sh` | No direct `zot` invocation found, but functionally part of the read/write/attach pipeline that assumes a configured Zotero environment |

This means even a full "finish the install" for the read/write/setup/chunk/attach-chunks cluster would ship non-functional-by-default scripts requiring the user to separately install and configure `zotero-cli-cc` — a meaningful "is deploying this even meaningful right now" consideration per the task's own framing.

### External Resources

None consulted — this is a purely internal codebase-provenance question; no external documentation applies.

## Per-Artifact Recommendation Table

| Artifact | Added by | Referenced by live code? | Declared in manifest? | Recommendation |
|---|---|---|---|---|
| `cite-extract.sh` | task 716 (2026-06-15) | No directly; yes transitively via undeployed `skill-cite` | Yes | **ACTIVATE** — deploy as part of the `/cite` trio |
| `skill-cite` (SKILL.md) | task 717 (2026-06-15) | No (undeployed); complete and calls `cite-extract.sh` correctly | Yes | **ACTIVATE** — deploy as part of the `/cite` trio |
| `cite.md` | task 718 (2026-06-15) | No (undeployed); delegates correctly to `skill-cite` | Yes | **ACTIVATE** — deploy as part of the `/cite` trio; also add `skill-cite` row to CLAUDE.md's Skill-to-Agent Mapping table (currently missing, inconsistent with the Command Reference table which already documents `/cite`) |
| `zotero-search.sh` | task 711 (2026-06-14) | **Yes** — live fallback reference in `skill-literature/SKILL.md` | Yes | **ACTIVATE** (low-risk consistency deploy — already effectively live via source-path fallback; no external dependency) |
| `zotero-index-add.sh` | task 758 migration (originally pre-758 zotero ext.) | No — superseded by inline `jq` logic in `skill-literature/SKILL.md` | Yes | **DEFER-AND-DOCUMENT** — flag as dead/duplicate code; candidate for a future manifest-pruning task, not activation |
| `zotero-index-remove.sh` | task 758 migration | No — superseded by inline `jq` logic | Yes | **DEFER-AND-DOCUMENT** — same as above |
| `zotero-read.sh` | task 758 migration | No | Yes | **DEFER-AND-DOCUMENT** — blocked on external `zot` CLI (not installed); no live caller |
| `zotero-write.sh` | task 758 migration | No | Yes | **DEFER-AND-DOCUMENT** — blocked on external `zot` CLI; no live caller |
| `zotero-setup.sh` | task 758 migration | No | Yes | **DEFER-AND-DOCUMENT** — setup wizard for the read/write/index-add cluster; defer alongside them |
| `zotero-chunk.sh` | task 758 migration | No | Yes | **DEFER-AND-DOCUMENT** — implements a write-back-to-Zotero chunking workflow architecturally superseded by the read-only briefing+tools design adopted in task 758 |
| `zotero-attach-chunks.sh` | task 758 migration | No | Yes | **DEFER-AND-DOCUMENT** — same rationale as `zotero-chunk.sh`; the two form a pair |
| `test-lit-pipeline.sh` | task 758-day manifest fix (2026-06-23) | No | Yes | **DEFER-AND-DOCUMENT, handled separately** — this is a test harness (`# Validate the full --lit pipeline wiring for CSLib tasks`), never a runtime script; keep quarantined in extension source, confirmed correctly excluded by `check-extension-docs.sh`'s drift guard |

## Decisions

- **This task's scope is split, not uniform.** The `/cite` trio should be treated as a genuine "finish the install" job (small: 3 file copies + 1 CLAUDE.md table edit). The zotero suite (minus `zotero-search.sh`) should be treated as a "formally document as inactive" job (README/manifest annotation, no file copies of non-functional-without-external-setup scripts).
- `zotero-search.sh` is a defensible middle case: recommend activating it (deploy to `.claude/scripts/`) purely for consistency, since it is already load-bearing via source-path fallback and has zero external dependency — but this is optional/low-priority relative to `/cite`, since the fallback already works.
- `zotero-index-add.sh` / `zotero-index-remove.sh` should **not** be activated even though they're low-risk — activating superseded/duplicate logic would create two divergent implementations of the same operation (inline `jq` in `skill-literature/SKILL.md` vs. the standalone scripts). The correct fix is documentation (mark superseded) now, and prune in a future cleanup task.
- `.claude/extensions.json` having no `"literature"` entry is real and relevant context but is explicitly **out of this task's stated scope** (the task is about the zotero/cite surface specifically, not the whole extension's installed-tracking gap). The planner should decide whether task 844 also registers the extension in `extensions.json`, or whether that's deferred to a separate follow-up task — flagging this rather than deciding it here.
- Whatever direction is chosen for the zotero cluster, `check-extension-docs.sh`'s existing drift guard (task 841) already tolerates "manifest declares it, deployed copy absent" as a non-failure (`info "script not deployed, skipping drift check"`), so choosing DEFER-AND-DOCUMENT for those 6-7 scripts requires **no** code change to stay green — only README/manifest wording changes for honesty. Choosing ACTIVATE for `/cite` + `zotero-search.sh` requires the deploy step itself plus (for `/cite`) the CLAUDE.md skill-mapping-table fix to stay internally consistent.

## Risks & Mitigations

- **Risk**: Deploying `/cite` without also fixing the missing `skill-cite` row in CLAUDE.md's Skill-to-Agent Mapping table leaves a fresh internal inconsistency (Command Reference documents `/cite`, mapping table doesn't route it). **Mitigation**: the implementation plan for this task must include the CLAUDE.md table edit alongside the three file deploys.
- **Risk**: Deploying the `zot`-CLI-dependent zotero scripts (`read`/`write`/`setup`/partially `index-add`) without also documenting the `zot` CLI as a required external dependency would ship dead-on-arrival scripts that silently fail for any user without `zotero-cli-cc` installed. **Mitigation**: the chosen recommendation is DEFER for exactly this cluster — do not deploy until either (a) a future task adds real callers plus explicit external-dependency documentation, or (b) the `zot` CLI is confirmed as a project-wide prerequisite.
- **Risk**: Deploying `zotero-index-add.sh`/`zotero-index-remove.sh` "for completeness" would create a second, divergent code path for sub-index add/remove alongside the already-live inline `jq` logic in `skill-literature/SKILL.md`, inviting future drift between the two. **Mitigation**: DEFER, and note in the README that these are superseded — a future cleanup task should consider deleting them (quarantine-never-delete permitting) rather than activating them.
- **Risk**: Any change must keep `check-extension-docs.sh`'s literature section at PASS. Current state (`bash .claude/scripts/check-extension-docs.sh`) already shows `literature PASS` with `info: script not deployed, skipping drift check` notes for `zotero-search.sh`, `cite-extract.sh`, `zotero-read.sh`, etc. **Mitigation**: any deploy chosen (the `/cite` trio, optionally `zotero-search.sh`) must be verified to keep this drift check green post-deploy (it should, since the guard only flags *content mismatch* between deployed and source copies, not presence/absence).

## Context Extension Recommendations

- **Topic**: Literature extension's `extensions.json` tracking gap.
- **Gap**: `.claude/extensions.json` has no entry for the `literature` extension despite substantial partial deployment (20+ files). This is undocumented anywhere in current context files.
- **Recommendation**: A future meta task should either (a) register `literature` in `extensions.json` retroactively with `installed_files`/`installed_dirs` reflecting the actual current partial deployment, or (b) document in `.claude/extensions/literature/README.md` that this extension is deployed via a manual/non-standard process and is intentionally exempt from `extensions.json` tracking. Not resolving this leaves any future "sync"-based extension tooling blind to the literature extension's true install state.

## Appendix

### Commands/queries used
- `jq '.extensions | keys' .claude/extensions.json`
- `jq '.provides' .claude/extensions/literature/manifest.json`
- `git log --follow --diff-filter=A --format='%h %ad %s' -- "*/extensions/literature/scripts/<file>"` for each of the 10 scripts and `cite.md`
- `git show --stat 6a20ee309` (task 758 phase 2 commit)
- `grep -rln -iE 'zotero-<name>|cite-extract|/cite|cite.md' .claude/{commands,skills,agents,rules,CLAUDE.md,context}`
- `which zot`; per-script `grep` for `zot` CLI invocation patterns
- `bash .claude/scripts/check-extension-docs.sh` (confirmed current PASS state and drift-guard skip notes)

### Key files read
- `specs/archive/758_unified_literature_system/summaries/09_unified-literature-summary.md`
- `specs/archive/716_create_cite_extract_script/plans/01_cite-extract-plan.md` and `.orchestrator-handoff.json`
- `specs/archive/718_create_cite_command_file/plans/01_cite-command-plan.md` and `.orchestrator-handoff.json`
- `.claude/extensions/literature/README.md`, `manifest.json`
- `.claude/skills/skill-literature/SKILL.md` (lines ~1206-1270, ~2120-2230)
- `.claude/extensions/literature/skills/skill-cite/SKILL.md`
- `.claude/extensions/literature/commands/cite.md`
- `.claude/scripts/check-extension-docs.sh` (lines ~117-149)
