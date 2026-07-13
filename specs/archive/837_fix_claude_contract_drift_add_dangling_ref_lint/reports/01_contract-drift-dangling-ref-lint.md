# Research Report: Task #837

**Task**: 837 - fix_claude_contract_drift_add_dangling_ref_lint
**Started**: 2026-07-12T18:00:00Z
**Completed**: 2026-07-12T18:08:00Z
**Effort**: research
**Dependencies**: None (independent of #831-#836)
**Sources/Inputs**: Codebase exploration across `~/.config/nvim/.claude/`, `~/Projects/BimodalLogic/.claude/`, `~/Projects/cslib/.claude/`, `~/Projects/Logos/Hardware/.claude/`; `sync.lua`, `loader.lua`, `manifest.lua`; `check-extension-docs.sh`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task's diagnosis is correct but the mechanism is more specific than "files got out of sync by copy-paste": **`.claude/context/contracts/` is architecturally invisible to the extension sync pipeline for the `core` extension.** `core/manifest.json`'s `provides.context` array omits `"contracts"` entirely, and there is no `.claude/extensions/core/context/contracts/` source directory in nvim (the canonical/global sync source — `global_dir` defaults to `~/.config/nvim`, confirmed in `shared/extensions/config.lua`). Nvim's 8 core contracts live only in the **deployed** layer (`.claude/context/contracts/`), added directly there, never migrated into the `core` extension source, and therefore never propagate to any child project via "Load Core."
- By contrast, the `lean` extension **does** correctly declare `"contracts"` in `provides.context` and ships its own `context/contracts/` (4 files: `adversarial-verification.md`, `anti-analysis.md`, `context-hygiene.md`, `reference-grounding.md`) which propagates via `loader.lua`'s `copy_context_dirs()`. This explains BimodalLogic's and Logos/Hardware's contracts sets exactly — they are the `lean` extension's 4 files, not a degraded subset of core's 8.
- `context-hygiene.md` is explicitly Lean4/CSLib-domain-scoped by its own header ("This is a NEW standalone contract for the Lean4/CSLib formal domains... does not override a core baseline file") — it belongs in the `lean` extension and should **not** be promoted to core. Core's canonical set should remain its 8 general-purpose contracts.
- `check-extension-docs.sh` has two concrete gaps that let this drift go undetected: (1) `check_manifest_entries()` validates `provides.agents/skills/commands/rules/scripts` against disk but has **no case for `provides.context`** — so a manifest can claim `"contracts"` is provided when the directory doesn't exist on disk (confirmed live in `cslib`'s own local copy of the `lean` extension source: manifest says `contracts` but `.claude/extensions/lean/context/contracts/` doesn't exist there); (2) the script only scans `.claude/extensions/*/`, never the **deployed** `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, `.claude/rules/*.md` for dangling `.claude/context/contracts/*.md` or `@.claude/...` references against the *current project's* filesystem — which is exactly the BimodalLogic defect (`skill-orchestrate-hard/SKILL.md` references 6 contracts, 5 absent).
- `check-extension-docs.sh` is never invoked automatically. It exists only as a manual command (`bash .claude/scripts/check-extension-docs.sh`, allowlisted in `settings.local.json`). Nothing in `sync.lua` (`execute_sync`, `M.load_all_globally`) or `loader.lua` calls it. The only automated post-sync check is `audit_synced_content()`, which is a **grep-string pattern audit** (`.sync-exclude` patterns), not a structural/referential-integrity check — a different mechanism entirely.

## Context & Scope

Investigated: (1) actual contract file contents across nvim, BimodalLogic, cslib, and other child projects; (2) which contracts each project's `skill-orchestrate-hard/SKILL.md` references; (3) how `check-extension-docs.sh` currently validates references; (4) how the sync/"Load Core" path works, to find the correct wiring point.

File scope for this task per the task description: `.claude/scripts/check-extension-docs.sh` and `.claude/context/contracts/`.

## Findings

### Codebase Patterns

**Contract inventory (confirmed by direct listing)**:

| Project | `.claude/context/contracts/` contents | Origin |
|---|---|---|
| `~/.config/nvim` (canonical/global) | adversarial-verification, anti-analysis, convergence, orchestrator-discipline, recovery, reference-grounding, territory, wrap-up (8) | Manually added to deployed layer; NOT in any extension source |
| `~/Projects/BimodalLogic` | adversarial-verification, anti-analysis, context-hygiene, reference-grounding (4) | `lean` extension's `provides.context` |
| `~/Projects/Logos/Hardware` | adversarial-verification, anti-analysis, context-hygiene, reference-grounding (4) | `lean` extension's `provides.context` (identical to BimodalLogic — confirms extension origin, not independent drift) |
| `~/Projects/cslib` | anti-analysis, reference-grounding (2) | `lean` extension, but stale copy (see below) |

**`skill-orchestrate-hard/SKILL.md` contract references** (`grep -n "contracts/"`):

- nvim and BimodalLogic: byte-identical reference sets — 6 distinct contracts referenced: `convergence.md`, `territory.md`, `anti-analysis.md`, `wrap-up.md`, `recovery.md`, `orchestrator-discipline.md`. In nvim all 6 exist; in BimodalLogic only `anti-analysis.md` exists (coincidentally supplied by the `lean` extension) — **5 dangling references** (`convergence`, `territory`, `wrap-up`, `recovery`, `orchestrator-discipline`), matching the task description exactly.
- cslib: an **older** version of `SKILL.md` referencing only 4 contracts (`convergence.md`, `territory.md`, `anti-analysis.md`, `wrap-up.md` — no `recovery`/`orchestrator-discipline` references at all), of which only `anti-analysis.md` exists on disk. This is a second, independent drift signal: cslib hasn't run "Load Core" recently enough to pick up either the newer `SKILL.md` or the newer contract set.

**Root cause — core extension does not own `contracts/`**:

- `core/manifest.json`'s `provides.context` array: `README.md, routing.md, validation.md, index.schema.json, architecture, checkpoints, formats, guides, meta, orchestration, patterns, processes, reference, repo, schemas, standards, templates, troubleshooting, workflows` — **no `contracts` entry**.
- `.claude/extensions/core/context/contracts/` does not exist anywhere (confirmed absent in nvim, the canonical source).
- `.claude/extensions/lean/manifest.json`'s `provides.context` **does** include `"contracts"`, and nvim's `.claude/extensions/lean/context/contracts/` holds the 4 files listed above.
- `loader.lua:242` `copy_context_dirs(manifest, source_dir, target_dir, protected_paths)` reads `manifest.provides.context` and copies each declared subdir from extension source to `.claude/context/<subdir>` on extension load/reload — this is the only mechanism that ever populates `.claude/context/contracts/` for a project. Because core never declares `contracts`, core's 8 files never flow through this path to any child project. They exist in nvim purely because someone added them directly to the deployed directory.
- `sync.lua:835` `M.scan_all_artifacts()` (the "Load Core" full-sync path) builds an **allow-list** for the `context` category from `core_provides` (`manifest.get_core_provides()` / `manifest.build_allow_list()`), filtered by top-level context subdirectory name (`sync.lua` ~915-935, `filter_category == "context"` branch: matches `rel_path:match("^([^/]+)")` against `allowed[top_dir]`). Since `"contracts"` isn't in `core`'s provides list, even a full "Load Core" run would not pull core's contracts into any child project's `.claude/context/contracts/`.

**Secondary drift layer — stale local extension-source copies**:

- cslib's own `.claude/extensions/lean/manifest.json` *does* declare `provides.context: ["project/lean4", "contracts"]`, but cslib's local `.claude/extensions/lean/context/contracts/` **does not exist on disk** — the extension-source snapshot embedded in cslib is itself stale relative to nvim's current `lean` extension (which does have `context/contracts/` with 4 files). `check-extension-docs.sh`'s `check_manifest_entries()` has no branch for the `context` category (it only handles `agents`, `skills`, `commands`, `rules`, `scripts` — see lines ~62-107), so this manifest/disk mismatch is currently undetected even by a full run of the existing script.

**`check-extension-docs.sh` current scope** (`.claude/scripts/check-extension-docs.sh`, canonical source `.claude/extensions/core/scripts/check-extension-docs.sh`):

- Iterates only `.claude/extensions/*/` (never `.claude/skills/`, `.claude/agents/`, `.claude/rules/`, or `.claude/context/` at the deployed/top level).
- Per-extension checks: required files (`manifest.json`, `EXTENSION.md`, `README.md`); `check_manifest_entries` (agents/skills/commands/rules/scripts existence, **no context check**); `check_deployed_script_drift` (deployed vs extension-source content diff for `provides.scripts`); `check_routing_block`; `check_undeclared_skills`; `check_routing_consistency` (Rules B/C — routing/routing_hard target resolvability + deployment); `check_deployed_skill_agents` (Rule D — deployed skill's `subagent_type` must resolve to `.claude/agents/<name>.md`); `check_readme_vs_manifest`; `check_referenced_scripts_declared` (Rule E — reverse-direction: script *mentioned* in an extension's own docs must be declared in `provides.scripts`).
- None of these rules scan file content for `.claude/context/contracts/*.md` or generic `@.claude/...` path references and verify the referenced path exists in the *consuming* project's filesystem. Rule D is the closest existing precedent (content-scan a deployed file, extract a reference, verify target exists) and is the natural pattern to extend.
- Never invoked automatically: not called from `sync.lua`, `loader.lua`, any hook, or CI. Only appears in `settings.local.json` permission allowlist entries and docs. `audit_synced_content()` in `sync.lua` (~line 742) is the only automatic post-sync check and is a distinct grep-pattern-count mechanism (`.sync-exclude` audit patterns), not a referential-integrity linter.

### External Resources

Not applicable — this is a pure codebase-structural investigation; no external documentation consulted.

### Recommendations

1. **Register `contracts` as a core-owned context category.** Add `"contracts"` to `core/manifest.json`'s `provides.context`, and migrate nvim's 8 deployed `.claude/context/contracts/*.md` files into `.claude/extensions/core/context/contracts/` as the new canonical source. This makes core contracts flow through the same `copy_context_dirs()` / "Load Core" allow-list pipeline as every other core artifact, instead of being manually propagated (or not) per project.
2. **Do not adopt `context-hygiene.md` into core.** Its own header states it is Lean4/CSLib-domain-specific and does not override a core baseline. It correctly belongs in the `lean` extension. Reconcile by leaving it there.
3. **Extend `check-extension-docs.sh` with two new checks** (or a sibling script, per the task's stated option):
   - a. `provides.context` disk-existence validation inside `check_manifest_entries()` (or a new `check_context_entries()`), mirroring the existing agents/skills/commands/rules/scripts pattern but checking `ext_path/context/<entry>` as file-or-directory. This closes the cslib stale-extension-source gap.
   - b. A new project-wide (not per-extension) check that scans deployed `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, `.claude/rules/*.md` (and optionally `.claude/commands/*.md`) for `.claude/context/contracts/[a-z-]+\.md`-shaped references (and more generally `@?\.claude/[\w./-]+\.md` paths) and FAILs loudly when the referenced path does not exist under the *current* project's `.claude/` root. This is the check that would have caught BimodalLogic's 5 dangling references and cslib's older-but-still-broken 4.
4. **Wire into the sync path.** `execute_sync()` in `sync.lua` (or a thin wrapper around the "Load Core" picker action) should invoke the new/extended `check-extension-docs.sh` after a full sync completes and surface FAIL output prominently (not just exit code) — this satisfies the LOUD-FAILURE requirement: a missing contract must produce a visible failure message at load time, not a silent no-op. `.syncprotect` itself needs no schema change; it only affects which paths sync *skips*, which is orthogonal to validating referential integrity of what *did* sync.
5. **Sweep other child projects** beyond BimodalLogic/cslib: `Logos/Hardware` shares BimodalLogic's exact 4-contract signature (same `lean`-extension origin, so likely same 5-dangling-reference defect if it also has `skill-orchestrate-hard` deployed — worth checking during planning/implementation). `~/Projects/ModelChecker`, `~/Projects/Logos/{ModelChecker,Website,Vision,Theory}`, `~/Projects/protocol`, `~/Projects/ModelBuilder`, `~/Projects/theorem_proving_in_lean4`, `~/Projects/ProofChecker.bak`, `~/Projects/Repos/provability-fabric` all have `.claude/` and were not individually inspected in this pass — the new validator, once built, is the right tool to sweep them systematically rather than manual enumeration here.

## Decisions

- Confirmed the task's factual claims about nvim health (8/8 contracts present, all 6 `skill-orchestrate-hard` references resolve) and BimodalLogic's defect (6 referenced, 5 missing) by direct file inspection.
- Identified the root cause as a **manifest/pipeline gap** (`core` never declares `contracts` in `provides.context`), not merely inconsistent manual copying — this should anchor the implementation plan's Phase 1 (fix the source-of-truth registration) before Phase 2 (build the validator) and Phase 3 (reconcile existing child-project drift).
- Recommend `context-hygiene.md` stays lean-extension-scoped; do not merge into core's canonical contract set.

## Risks & Mitigations

- **Risk**: Migrating core's 8 contracts into `extensions/core/context/contracts/` changes the source-of-truth path; anything that currently hardcodes `.claude/context/contracts/...` (deployed-layer paths, which is the correct reference form for consuming skills) is unaffected, but the *export*/sync scripts and `index.json`/`index-entries.json` entries need their `subdomain: "contracts"` entries checked for consistency with the new source location. Mitigation: verify `core/index-entries.json` merge behavior during planning; this report did not find an existing `"contracts"` entry in `core/index-entries.json`, which is itself worth reconciling.
- **Risk**: A blanket dangling-`@.claude/...`-reference scan across all deployed `.claude/skills|agents|rules` could produce false positives for legitimately extension-conditional references (e.g., a skill that references a path only present when a specific extension is loaded, guarded by conditional logic in the skill body). Mitigation: scope the new check initially to `.claude/context/contracts/*.md` references specifically (the concrete, narrow bug), with generic `@.claude/...` path-checking as a stretch goal flagged separately rather than blocking on solving the general case.
- **Risk**: Wiring a hard-FAIL validator into the sync path could block legitimate partial syncs (e.g., a project intentionally not loading the `lean` extension and thus correctly lacking `context-hygiene.md`, which nothing in core ever references anyway). Mitigation: the validator must be reference-driven (what does content in *this* project actually cite) rather than presence-driven (do all possible contracts exist), which is what Recommendation 3b already specifies.

## Context Extension Recommendations

- **Topic**: Context-category (`provides.context`) validation is entirely absent from `check-extension-docs.sh`'s manifest-entry checking, unlike every other provides category.
- **Gap**: No documented convention states that new top-level `.claude/context/<subdir>/` categories intended for cross-project distribution MUST be registered in `core/manifest.json`'s (or the owning extension's) `provides.context` array to participate in sync. This is implicit in code (`loader.lua:242`, `sync.lua` allow-list logic) but undocumented in `.claude/docs/guides/creating-extensions.md`.
- **Recommendation**: After this task's implementation, add a short section to `creating-extensions.md` documenting the `provides.context` contract and its role in `copy_context_dirs()`/allow-list sync, using `contracts/` as the worked example of what happens when it's omitted.

## Appendix

**Search/inspection commands used** (representative, not exhaustive):
- `ls .claude/context/contracts/` across nvim, BimodalLogic, cslib, Logos/Hardware
- `grep -n "contracts/" skill-orchestrate-hard/SKILL.md` across nvim, BimodalLogic, cslib
- `find ~/Projects ~/.config -maxdepth 3 -type d -name ".claude"` (project enumeration)
- `jq '.provides' core/manifest.json`, `jq '.provides.context' lean/manifest.json`
- `Read check-extension-docs.sh` (full file, canonical + extension-source copy confirmed identical)
- `grep -n "provides.context\|copy_context_dirs" loader.lua`
- `sed -n` excerpts of `sync.lua` `M.scan_all_artifacts`, `audit_synced_content`
- `Read context-hygiene.md` (BimodalLogic copy) to determine domain-scoping intent
