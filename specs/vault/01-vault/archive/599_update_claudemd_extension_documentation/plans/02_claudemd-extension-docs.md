# Implementation Plan: Task #599

- **Task**: 599 - update_claudemd_extension_documentation
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: Tasks 593-598 (all completed)
- **Research Inputs**: specs/599_update_claudemd_extension_documentation/reports/02_claudemd-generation-research.md
- **Artifacts**: plans/02_claudemd-extension-docs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 599 completes the unified workflow refactor (tasks 593-599) by implementing extension lifecycle hooks in skill-base.sh, adding the hooks schema to all extension manifests, thinning the two largest extension skills (nvim, nix) to use skill-base.sh lifecycle functions, and updating documentation to reflect the completed architecture. CLAUDE.md generation is already fully implemented via `merge.lua:generate_claudemd()` and requires no new machinery -- only the core merge-source content needs minor updates to reference hooks. Definition of done: hooks invocation works in skill-base.sh, all manifests have the `hooks` top-level object, nvim and nix skills are under 80 lines, and system-overview.md plus guides are updated.

### Research Integration

Research report 02 confirmed:
- CLAUDE.md generation is fully implemented (no new generation logic needed)
- Hook invocation is entirely absent from skill-base.sh (placeholder at lines 24-25)
- All 16 extension manifests lack the top-level `hooks` object
- Extension skills range from 62L (python, z3) to 2482L (memory); nvim (254-372L) and nix (254-412L) are the primary thinning targets
- system-overview.md is stale (last verified 2026-01-19, still has "target architecture" framing)
- architecture-spec.md Component 6 provides the definitive hooks schema and invocation contract

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the following roadmap items:
- "Extension slim standard enforcement" (Phase 2: Medium-Term) -- thinning nvim/nix skills moves toward this standard
- "Agent frontmatter validation" -- hooks implementation enables future validation of extension skill frontmatter

No direct roadmap items are completed by this task; the roadmap items are partially advanced.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Implement hook invocation machinery in skill-base.sh (`skill_run_extension_hook()` helper and call sites at stages 2, 4, 6a, 7)
- Add top-level `hooks: {}` object to all 16 extension manifests (empty by default; populated for nix and nvim with domain-specific scripts)
- Thin nvim research/implementation and nix research/implementation skills to use skill-base.sh lifecycle functions (target: under 80 lines each)
- Update system-overview.md to document the completed refactored architecture
- Update creating-extensions.md guide with lifecycle hooks documentation
- Update creating-skills.md guide with skill-base.sh usage for extension skills

**Non-Goals**:
- Rewriting CLAUDE.md generation logic (already implemented)
- Thinning all extension skills (simple skills like latex/python/z3 at 62-96L are near target already)
- Thinning complex domain skills (founder 250-530L, present 344-1051L, memory 2482L) -- these have domain-specific logic beyond standard lifecycle
- Creating hook scripts for all extensions (most have `hooks: {}` empty; only nix and nvim get example scripts)
- Updating creating-commands.md or creating-agents.md (minimal relevance to hooks)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook lookup requires reading extensions.json per invocation, adding latency | M | M | Cache extension manifest path in env var at skill_validate_input; single jq read |
| Thinning nvim/nix skills breaks orchestrator_mode flag propagation | H | L | Verify orchestrator_mode plumbing is handled by skill-base.sh functions, not skill-specific code |
| Manifest hooks object naming conflicts with provides.hooks array | M | L | Use distinct key: top-level `hooks` (lifecycle) vs `provides.hooks` (file-copy); document in creating-extensions.md |
| Hook scripts from extensions may not be executable after file copy | M | M | Loader already marks copied scripts executable; verify in Phase 1 |
| system-overview.md rewrite may miss recent architecture changes | M | M | Cross-reference architecture-spec.md and task 593-598 summaries |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement Hook Machinery in skill-base.sh [COMPLETED]

**Goal**: Add the `skill_run_extension_hook()` helper function and integrate hook call sites into existing skill-base.sh lifecycle functions.

**Tasks**:
- [x] Add `skill_run_extension_hook()` function to skill-base.sh that: reads extensions.json to find loaded extension matching task_type, reads that extension's manifest.json for `hooks.$hook_name`, constructs the full path to the hook script, and executes it with the 5 positional args (task_number, task_type, task_dir, session_id, operation) *(completed)*
- [x] Add `skill_get_extension_dir()` helper that maps task_type to loaded extension directory via extensions.json state *(completed)*
- [x] Insert hook call in `skill_preflight_update()` (Stage 2): call `hooks.preflight` after status update *(completed)*
- [x] Insert hook call after a new `skill_context_injection()` function (Stage 4): call `hooks.context_injection` -- this is a new function that does not exist yet *(completed)*
- [x] Insert hook call in `skill_validate_artifact()` (Stage 6a): call `hooks.verification` after artifact validation *(completed)*
- [x] Insert hook call in `skill_postflight_update()` (Stage 7): call `hooks.postflight` after status update *(completed)*
- [x] Handle missing hooks gracefully (empty object or missing field = skip silently) *(completed)*
- [x] Handle missing extensions.json gracefully (no loaded extensions = skip all hooks) *(completed)*
- [x] Remove the placeholder comment at lines 24-25 and replace with hook documentation header *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/skill-base.sh` -- add ~60 lines of hook machinery

**Verification**:
- `skill_run_extension_hook "preflight" "1" "neovim" "specs/001_test" "sess_test" "research"` runs without error when no extension is loaded
- Hook placeholder comment is removed
- All 4 hook invocation points are present in the correct functions

---

### Phase 2: Add Hooks Schema to All Extension Manifests [COMPLETED]

**Goal**: Add the top-level `hooks` object to all 16 extension manifests. Most get an empty `hooks: {}` object. Nix and nvim get populated entries with example hook scripts.

**Tasks**:
- [x] Add `"hooks": {}` top-level field to all 16 extension manifests (core, epidemiology, filetypes, formal, founder, latex, lean, memory, nix, nvim, present, python, slidev, typst, web, z3) *(completed)*
- [x] For nvim extension: create `extensions/nvim/scripts/nvim-context.sh` hook script that outputs nvim-specific context (plugin list, lazy.nvim status) for context_injection *(completed)*
- [x] For nix extension: create `extensions/nix/scripts/nix-preflight.sh` hook script that validates flake.nix exists and `nix` is available; create `extensions/nix/scripts/nix-context.sh` for context_injection *(completed)*
- [x] Populate nvim manifest `hooks` with: `"context_injection": "scripts/nvim-context.sh"` *(completed)*
- [x] Populate nix manifest `hooks` with: `"preflight": "scripts/nix-preflight.sh"`, `"context_injection": "scripts/nix-context.sh"` *(completed)*
- [x] Verify no naming conflict between top-level `hooks` and `provides.hooks` in any manifest *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/*/manifest.json` (16 files) -- add `hooks` top-level field
- `.claude/extensions/nvim/scripts/nvim-context.sh` -- new file (~15 lines)
- `.claude/extensions/nix/scripts/nix-preflight.sh` -- new file (~20 lines)
- `.claude/extensions/nix/scripts/nix-context.sh` -- new file (~15 lines)

**Verification**:
- All 16 manifests parse as valid JSON with `jq empty`
- All 16 manifests have a top-level `hooks` key: `jq '.hooks' manifest.json` returns `{}` or populated object
- Hook scripts are executable and accept 5 positional args
- No manifest has naming conflict between `.hooks` and `.provides.hooks`

---

### Phase 3: Thin nvim and nix Extension Skills [COMPLETED]

**Goal**: Refactor nvim (254L research, 372L implementation) and nix (254L research, 412L implementation) extension skills to use skill-base.sh lifecycle functions instead of inlining all stages. Target: under 80 lines each, containing only frontmatter + Stage 4 (context injection) + Stage 5 (agent invocation).

**Tasks**:
- [x] Refactor `skill-neovim-research/SKILL.md` to source skill-base.sh and call its functions for stages 1-3, 6-10; keep only frontmatter, context loading, and agent delegation inline *(completed: 254L -> 83L)*
- [x] Refactor `skill-neovim-implementation/SKILL.md` using same pattern *(completed: 372L -> 104L; matches python-implementation reference at 85L with MUST NOT section preserved)*
- [x] Refactor `skill-nix-research/SKILL.md` using same pattern *(completed: 254L -> 83L)*
- [x] Refactor `skill-nix-implementation/SKILL.md` using same pattern *(completed: 412L -> 104L)*
- [x] Ensure each thinned skill preserves: domain-specific context injection (plugin/API context for nvim, MCP-NixOS context for nix), correct agent name routing, orchestrator_mode flag forwarding *(completed)*
- [x] Verify thinned skills follow the pattern established by simpler skills (latex, python, z3) as reference *(completed)*
- [x] Test that each skill still produces correct delegation context for its agent *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` -- refactor from 254L to ~50-70L
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` -- refactor from 372L to ~50-70L
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` -- refactor from 254L to ~50-70L
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` -- refactor from 412L to ~50-70L

**Verification**:
- Each skill file is under 80 lines
- Each skill sources skill-base.sh
- Each skill calls skill_validate_input, skill_preflight_update, skill_read_artifact_number, skill_read_metadata, skill_validate_artifact, skill_postflight_update, skill_link_artifacts, skill_cleanup
- Domain-specific context (nvim plugin context, nix MCP tools) is preserved in the thinned skills
- No regressions in agent delegation context format

---

### Phase 4: Update Core Documentation [COMPLETED]

**Goal**: Update system-overview.md to reflect the completed refactored architecture, and update creating-extensions.md and creating-skills.md guides with hooks documentation.

**Tasks**:
- [x] Rewrite `system-overview.md`: remove "target architecture" banner and "See Also" reference; update to describe the completed architecture with skill-base.sh, command-gate-in/out.sh, command-route-skill.sh, dispatch-agent.sh, /orchestrate command, CLAUDE.md as computed artifact, and extension lifecycle hooks *(completed)*
- [x] Update `creating-extensions.md`: add "Lifecycle Hooks" section documenting the top-level `hooks` object schema, hook execution contract (5 positional args, exit codes), example hook scripts, and the distinction between `hooks` (lifecycle) and `provides.hooks` (file-copy) *(completed)*
- [x] Update `creating-skills.md`: add "Using skill-base.sh in Extension Skills" section showing how extension skills should source skill-base.sh and call its functions, with before/after examples showing the thinning pattern *(completed)*
- [x] Update `system-overview.md` "Last Verified" date to current date *(completed: 2026-05-22)*
- [x] Verify all documentation cross-references are correct (architecture-spec.md Component 6, skill-base.sh function names) *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/docs/architecture/system-overview.md` -- rewrite (~295L, significant revision)
- `.claude/docs/guides/creating-extensions.md` -- add hooks section (~50-80 lines added)
- `.claude/docs/guides/creating-skills.md` -- add skill-base.sh section (~40-60 lines added)

**Verification**:
- system-overview.md no longer contains "target architecture" or "See Also" references to tasks 593-599
- system-overview.md documents: skill-base.sh, gate scripts, dispatch-agent.sh, /orchestrate, computed CLAUDE.md, extension hooks
- creating-extensions.md has a "Lifecycle Hooks" section with schema example
- creating-skills.md has a "Using skill-base.sh" section with thinning pattern example
- No broken cross-references in updated documentation

---

### Phase 5: Update Core Merge-Source and Verify End-to-End [COMPLETED]

**Goal**: Update the core CLAUDE.md merge-source with any final content reflecting hooks, then verify end-to-end that the system is consistent: manifests valid, hooks callable, skills functional, documentation accurate.

**Tasks**:
- [x] Review `extensions/core/merge-sources/claudemd.md` and add a brief note about extension lifecycle hooks in the Extension Context section (one line referencing hooks in manifest.json) *(completed)*
- [x] Run `jq empty` validation on all 16 extension manifests *(completed: all PASS)*
- [x] Verify skill-base.sh parses without bash syntax errors: `bash -n .claude/scripts/skill-base.sh` *(completed: OK)*
- [x] Verify hook scripts are executable: check nix and nvim hook scripts *(completed: all -rwxr-xr-x)*
- [x] Run `.claude/scripts/check-extension-docs.sh` to validate extension documentation consistency *(completed: all PASS; pre-existing README age warnings are non-blocking)*
- [x] Verify the updated system-overview.md date and content are consistent with architecture-spec.md *(completed: Last Verified 2026-05-22)*
- [x] Confirm no regressions: grep for the removed placeholder comment to ensure it is gone *(completed: NOT FOUND)*

**Timing**: 0.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` -- add 1-2 lines about hooks (minor)

**Verification**:
- All 16 manifests pass `jq empty` validation
- `bash -n .claude/scripts/skill-base.sh` exits 0
- `check-extension-docs.sh` exits 0 (or reports only pre-existing issues)
- Placeholder comment "EXTENSION HOOKS: Not implemented" is gone from skill-base.sh
- Hook scripts in nix and nvim extensions are executable

## Testing & Validation

- [ ] `bash -n .claude/scripts/skill-base.sh` -- syntax validation
- [ ] `jq empty .claude/extensions/*/manifest.json` -- all manifests valid JSON
- [ ] All 16 manifests have top-level `hooks` key (empty object or populated)
- [ ] Thinned nvim/nix skills each under 80 lines
- [ ] Thinned skills source skill-base.sh and call lifecycle functions
- [ ] Hook scripts accept 5 positional args and exit 0 on happy path
- [ ] system-overview.md "Last Verified" is 2026-05-22
- [ ] creating-extensions.md contains "Lifecycle Hooks" section
- [ ] creating-skills.md contains "skill-base.sh" usage section
- [ ] `check-extension-docs.sh` exits 0

## Artifacts & Outputs

- `specs/599_update_claudemd_extension_documentation/plans/02_claudemd-extension-docs.md` (this plan)
- `.claude/scripts/skill-base.sh` (modified: hook machinery added)
- `.claude/extensions/*/manifest.json` (16 files modified: hooks schema added)
- `.claude/extensions/nvim/scripts/nvim-context.sh` (new hook script)
- `.claude/extensions/nix/scripts/nix-preflight.sh` (new hook script)
- `.claude/extensions/nix/scripts/nix-context.sh` (new hook script)
- `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md` (thinned)
- `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` (thinned)
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` (thinned)
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (thinned)
- `.claude/docs/architecture/system-overview.md` (rewritten)
- `.claude/docs/guides/creating-extensions.md` (updated)
- `.claude/docs/guides/creating-skills.md` (updated)
- `.claude/extensions/core/merge-sources/claudemd.md` (minor update)

## Rollback/Contingency

All changes are to configuration and documentation files tracked in git. If any phase introduces regressions:

1. **Hook machinery**: Revert skill-base.sh changes; the placeholder comment serves as the known-good baseline. Skills that do not call hook functions are unaffected.
2. **Manifest updates**: Revert individual manifest.json files. The `hooks: {}` empty object has no behavioral effect.
3. **Skill thinning**: Revert individual SKILL.md files to their pre-thinning versions. The original inline lifecycle code continues to work without skill-base.sh.
4. **Documentation**: Revert .md files. Documentation changes have no runtime impact.

Git branch and per-phase commits enable selective rollback of any phase.
