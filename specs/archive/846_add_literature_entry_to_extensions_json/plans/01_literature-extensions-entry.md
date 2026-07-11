# Implementation Plan: Task #846

- **Task**: 846 - Add the missing `literature` entry to `.claude/extensions.json`
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: task #844 (deferred this deliberately), task #841 (drift-guard) — both informational, no blocking work remains
- **Research Inputs**: specs/846_add_literature_entry_to_extensions_json/reports/01_literature-extensions-entry.md
- **Artifacts**: plans/01_literature-extensions-entry.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a single `literature` entry to `.claude/extensions.json` so the Neovim extension picker
stops reporting literature as `"inactive"` and offering a surprising "Load" action. The entry
uses the standard 8-field loader schema with `status: "active"` and `version: "2.0.0"`, but with
**empty** `installed_files`/`installed_dirs`/`merged_sections`/`data_skeleton_files` arrays. The
research established that the current literature deployment was never produced by the real loader
(3 artifacts are symlinks, 7 manifest scripts are undeployed), so an empty-ownership entry both
closes the picker's "Load" trap and guarantees a future accidental `unload()`/`reload()` is a
safe no-op instead of deleting real working files. Definition of done: `extensions.json` parses,
the literature entry matches sibling schema exactly, `check-extension-docs.sh` still exits 0, and
no deployed literature script is touched.

### Research Integration

The research report (`reports/01_literature-extensions-entry.md`) supplies the exact entry to add
and the rationale for the empty arrays. Key integrated findings:
- The 8-field schema is produced by `state.lua`'s `M.mark_loaded()`; every sibling entry
  (`core`/`nix`/`memory`/`nvim`) has exactly these 8 keys. Matching key presence/absence — not
  ordering — is what matters (jq re-sorts on next machine write).
- `extensions.json` is consumed exclusively by the Neovim Lua extension picker/loader; Claude
  Code's own command/skill/agent dispatch never reads it. The entry is cosmetic for Claude Code
  but load-bearing for the picker's `is_loaded`/`get_status`/`unload`/`reload` state machine.
- `manifest.json` version is confirmed `"2.0.0"`; using it avoids an `"update-available"` flag.
- `check-extension-docs.sh` never references `extensions.json` (confirmed by grep) and already
  exits 0 with `literature: PASS`, so this edit cannot regress it either way.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add exactly one `literature` entry to `.claude/extensions.json.extensions`, matching the sibling
  8-field schema with `status: "active"`, `version: "2.0.0"`, `source_dir` absolute path, and
  empty `installed_files`/`installed_dirs`/`merged_sections`/`data_skeleton_files`.
- Keep `extensions.json` valid JSON (parses under `jq empty`).
- Leave all deployed literature artifacts (symlinks, real copies, scripts) untouched.

**Non-Goals**:
- Deploying the 7 missing zotero scripts, populating `.claude/context/index.json`, generating the
  `## Literature Extension` CLAUDE.md merge section, or normalizing symlinks into real copies —
  these require the real extension-loader flow and are out of scope (per research recommendation
  and task #844's README).
- Adding a `filetypes` entry (the undeclared cascade dependency) — out of scope.
- Any change to `loader.lua` or other Lua loader modules — read for consumption semantics only;
  the task instruction is "Do not change loader behavior".
- Hand-enumerating any file manifest for the literature entry (would risk a future
  `unload()`/`reload()` deleting real files).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Malformed JSON (loader-owned file; a broken entry is worse than a missing one) | H | L | Edit, then validate with `jq empty`; re-read the entry and diff key set against a sibling before finalizing |
| Hand-written non-empty `installed_files`/`merged_sections` could claim ownership of files the loader never created, enabling a future `unload()` to delete real (symlinked) working files | H | L | Use empty arrays/object exactly as the research prescribes |
| `version` mismatch vs. `manifest.json` flags `"update-available"` and invites a `reload()` | M | L | Use `"2.0.0"`, re-confirmed against `manifest.json` in Phase 1 |
| Accidental clobber/re-sync of deployed literature scripts | H | L | Pure JSON-file addition; no interaction with `loader.lua`'s copy engine; verify no literature file under `.claude/{scripts,agents,commands,skills}` changed (git status scope check) |
| `check-extension-docs.sh` regression | M | L | Run it in Phase 2; research confirmed it never reads `extensions.json` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the literature entry [COMPLETED]

**Goal**: Insert the `literature` entry into `.claude/extensions.json.extensions` matching the
sibling 8-field schema, with empty ownership arrays and `status: "active"`.

**Tasks**:
- [x] Re-confirm `version` in `.claude/extensions/literature/manifest.json` is `"2.0.0"` and
  `source_dir` is `/home/benjamin/.config/nvim/.claude/extensions/literature`. *(completed)*
- [x] Capture a current ISO8601 UTC timestamp for `loaded_at` (e.g. `date -u +%Y-%m-%dT%H:%M:%SZ`).
  *(completed: 2026-07-11T01:07:35Z)*
- [x] Add the entry using a `jq` write (preferred over hand-editing to preserve valid JSON), or a
  precise `Edit`. Target shape:
  ```json
  "literature": {
    "version": "2.0.0",
    "loaded_at": "<ISO8601 UTC at implementation time>",
    "source_dir": "/home/benjamin/.config/nvim/.claude/extensions/literature",
    "installed_files": [],
    "installed_dirs": [],
    "merged_sections": {},
    "data_skeleton_files": [],
    "status": "active"
  }
  ```
  *(completed via `jq` write)*
- [x] Confirm the top-level structure `{ "version": "1.0.0", "extensions": { ... } }` is preserved
  and the 4 existing entries (`core`, `memory`, `nix`, `nvim`) are unchanged. *(completed: structure
  preserved; note — the `core` entry's `installed_files`/`installed_dirs`/`loaded_at` differed from
  git HEAD's committed version at implementation time due to unrelated pre-existing uncommitted
  drift in the working tree from concurrent sibling-task orchestration (tasks 843-848 batch), not
  introduced by this task. See Plan Deviations in the implementation summary.)*

**Timing**: ~15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions.json` — add one `literature` key under `.extensions`; no other change.

**Verification**:
- `jq -e '.extensions.literature' .claude/extensions.json` returns the new object.
- The literature entry's key set equals a sibling's key set (8 keys: version, loaded_at,
  source_dir, installed_files, installed_dirs, merged_sections, data_skeleton_files, status).

### Phase 2: Validate and confirm no regressions [COMPLETED]

**Goal**: Prove the file is well-formed, schema-matching, and that nothing else changed.

**Tasks**:
- [x] `jq empty .claude/extensions.json` (exit 0 = parses). *(completed)*
- [x] Verify sibling schema match:
  `diff <(jq -S '.extensions.nvim | keys' .claude/extensions.json) <(jq -S '.extensions.literature | keys' .claude/extensions.json)` yields no differences. *(completed: no diff)*
- [x] Verify values: `status == "active"`, `version == "2.0.0"`, all four ownership fields empty
  (`installed_files == []`, `installed_dirs == []`, `merged_sections == {}`,
  `data_skeleton_files == []`). *(completed)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh`; confirm exit 0 and `literature: PASS`.
  *(completed: exit 0, `literature PASS`)*
- [x] `git status --porcelain` shows `.claude/extensions.json` as the only literature-related
  change; confirm no file under `.claude/{scripts,agents,commands,skills}/` or the literature
  symlinks was modified. *(completed: no literature symlink or deployed file changed; the 5
  literature source-dir files showing as modified in `git status` — `.claude/extensions/literature/{EXTENSION.md,README.md,agents/literature-agent.md,skills/skill-literature/SKILL.md}` — are pre-existing
  concurrent changes from sibling task 847, not touched by this task)*

**Timing**: ~10 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- All four checks above pass; no unexpected files in `git status`.

## Testing & Validation

- [ ] `.claude/extensions.json` parses (`jq empty` exits 0).
- [ ] `literature` entry key set matches a sibling entry exactly (8 keys).
- [ ] `status == "active"`, `version == "2.0.0"`, ownership fields all empty.
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with `literature: PASS`.
- [ ] No deployed literature script/agent/command/skill (including the 3 symlinks) is modified;
  `git status` shows only `.claude/extensions.json` changed by this task.

## Artifacts & Outputs

- `.claude/extensions.json` — updated with the `literature` entry.
- `specs/846_add_literature_entry_to_extensions_json/plans/01_literature-extensions-entry.md` — this plan.
- `specs/846_add_literature_entry_to_extensions_json/summaries/01_literature-extensions-entry-summary.md` — implementation summary (produced at /implement time).

## Rollback/Contingency

The change is a single additive JSON key. To revert: `git checkout .claude/extensions.json` (or
remove the `literature` key via `jq 'del(.extensions.literature)'`). Because the entry declares
no file ownership and the plan touches no other file, rollback carries no risk to deployed
literature artifacts.
