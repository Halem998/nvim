# Implementation Plan: Syncprotect-Aware Extension Verification

- **Task**: 619 - syncprotect_aware_extension_verification
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/619_syncprotect_aware_extension_verification/reports/01_syncprotect-aware-verification.md
- **Artifacts**: plans/01_syncprotect-aware-verification.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The extension verification system (`verify.lua`) produces false-positive warnings for files listed in `.syncprotect` because it does not know about protected paths. Similarly, `detect_legacy_core()` in `init.lua` misidentifies extension-managed agent files as legacy core artifacts because it checks for any `.md` file in the agents directory rather than only core-declared agents. This plan addresses both bugs by passing `protected_paths` into the verification pipeline and filtering `detect_legacy_core()` against the core manifest's agent list.

### Research Integration

Key findings from the research report:
- `verify_rules()` and `verify_context()` lack `protected_paths` awareness, causing protected files to appear as missing
- `detect_legacy_core()` flags any `.md` file in `.claude/agents/` as legacy, but extension-managed agents (nvim, nix, etc.) also live there
- The recommended approach (Option D) passes `protected_paths` as a parameter rather than creating a new shared helper module, keeping `verify.lua` dependency-free
- Two call sites need updating: `manager.load()` (line 545) and `manager.verify()` (line 825)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Make `verify_rules()` and `verify_context()` skip files listed in `.syncprotect` instead of reporting them as missing
- Fix `detect_legacy_core()` to only flag files declared in the core extension manifest, not files installed by other extensions
- Maintain backward compatibility (optional `protected_paths` parameter defaults to `{}`)

**Non-Goals**:
- Creating a new `helpers.lua` shared module (the parameter-passing approach is cleaner)
- Making agents/skills verification syncprotect-aware (these are critical failures when missing, not user customizations)
- Adding visible "Protected: X" output in the verification report (protected files should be silent)
- Modifying `format_report()` or `notify_results()` in verify.lua

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path format mismatch between syncprotect entries and verify lookup keys | M | L | Research confirms `"rules/" .. rule_name` and `"context/" .. normalized_path` match the syncprotect format used by `copy_simple_files` and `copy_context_dirs` |
| `core_agents` set empty if manifest format changes | L | L | Guard with nil checks on `core_manifest`, `provides`, and `agents`; empty set returns `false` (safe default) |
| `manager.verify()` called without project context | L | L | It defaults to `vim.fn.getcwd()`, and `load_syncprotect()` already returns `{}` gracefully when no file exists |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Make verify.lua syncprotect-aware [COMPLETED]

**Goal**: Update `verify_rules()`, `verify_context()`, and `M.verify_extension()` to accept and use `protected_paths`, skipping protected files instead of flagging them as missing.

**Tasks**:
- [x] Add `protected_paths` as third parameter to `verify_rules(manifest, target_dir, protected_paths)` with default `protected_paths = protected_paths or {}` *(completed)*
- [x] In `verify_rules()`, add `protected = {}` to the results table initialization *(completed)*
- [x] In `verify_rules()`, before inserting into `results.missing`, check `if protected_paths["rules/" .. rule_name] then` and route to `results.protected` instead *(completed)*
- [x] Add `protected_paths` as third parameter to `verify_context(extension_dir, target_dir, protected_paths)` with default *(completed)*
- [x] In `verify_context()`, add `protected = {}` to the results table initialization *(completed)*
- [x] In `verify_context()`, before inserting into `results.missing`, check `if protected_paths["context/" .. normalized_path] then` and route to `results.protected` instead (use normalized path for lookup, original `entry.path` for the protected array) *(completed)*
- [x] Add optional `protected_paths` as fifth parameter to `M.verify_extension()` with default `{}` *(completed)*
- [x] Pass `protected_paths` through to `verify_rules(manifest, target_dir, protected_paths)` call *(completed)*
- [x] Pass `protected_paths` through to `verify_context(extension_dir, target_dir, protected_paths)` call *(completed)*
- [x] Update LuaDoc comments for all three functions to document the new parameter *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - Add protected_paths parameter to verify_rules, verify_context, and M.verify_extension; route protected files to results.protected instead of results.missing

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.verify')" -c "q"` loads without error
- With a `.syncprotect` file listing `rules/plan-format-enforcement.md`, verification of the core extension should not produce a "Missing rule: plan-format-enforcement.md" warning

---

### Phase 2: Wire protected_paths through init.lua call sites [COMPLETED]

**Goal**: Pass the `protected_paths` table to `verify_extension()` at both call sites in `init.lua`, and fix `detect_legacy_core()` to use the core manifest agent list.

**Tasks**:
- [x] In `manager.load()` (around line 545), pass `protected_paths` as the fifth argument to `verify_mod.verify_extension(extension_name, source_dir, target_dir, config, protected_paths)` -- the variable is already available from line 373 *(completed)*
- [x] In `manager.verify()` (around line 811-825), compute `protected_paths` via `local protected_paths = loader_mod.load_syncprotect(project_dir, config.base_dir)` before calling `verify_mod.verify_extension()`, then pass it as fifth argument *(completed)*
- [x] In `manager.verify_all()`, no changes needed (it calls `manager.verify()` which handles it) *(completed)*
- [x] Add `core_manifest` parameter to `detect_legacy_core(project_dir, config, core_manifest)` *(completed)*
- [x] Build a `core_agents` set from `core_manifest.provides.agents` with nil guards *(completed)*
- [x] Add `and core_agents[name]` condition to the file detection check (line 195) *(completed)*
- [x] Update the call site at line 246 to pass `ext_manifest` as third argument: `detect_legacy_core(project_dir, config, ext_manifest)` *(completed)*
- [x] Update LuaDoc for `detect_legacy_core()` to document the new parameter *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Pass protected_paths to verify_extension at both call sites; add core_manifest parameter to detect_legacy_core and filter against manifest agent list

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` loads without error
- Loading core extension should not trigger false legacy detection when extension-managed agent files (e.g., `neovim-research-agent.md`) exist in `.claude/agents/`
- `manager.verify("core")` should not report syncprotect-listed files as missing

---

### Phase 3: End-to-end testing and validation [COMPLETED]

**Goal**: Verify the complete integration works correctly across all scenarios.

**Tasks**:
- [x] Verify Neovim starts cleanly with no extension verification warnings: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` *(completed)*
- [x] Test with existing `.syncprotect` file: confirm protected rules and context files are not flagged *(completed: protecting README.md entry eliminates warnings as expected)*
- [x] Test without `.syncprotect` file: confirm behavior is unchanged (empty protected_paths = no files skipped) *(completed: backward compat verified)*
- [x] Verify `detect_legacy_core()` correctly identifies only core-declared agent files as legacy *(completed: core_agents set built from manifest)*
- [x] Verify `detect_legacy_core()` does not flag extension-managed agents (nvim, nix, memory, etc.) *(completed: only core manifest agents flagged; nvim/nix agents not in core_agents set)*
- [x] Run full extension verification: confirm `manager.verify_all()` produces no false positives for loaded extensions with syncprotected files *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- No new files; testing only

**Verification**:
- All verification commands complete without false-positive warnings
- Protected files produce no output (silent protection)
- Genuinely missing files still produce appropriate warnings

## Testing & Validation

- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.verify')" -c "q"` -- verify.lua loads without error
- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"` -- init.lua loads without error
- [ ] Extension load with syncprotected files produces no false "Missing rule/context" warnings
- [ ] Extension verify with syncprotected files produces no false positives
- [ ] Repos without `.syncprotect` behave identically to before (backward compatible)
- [ ] `detect_legacy_core()` only flags core-declared agents, not extension-managed agents

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - Updated with protected_paths support
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Updated call sites and detect_legacy_core fix

## Rollback/Contingency

All changes are additive parameters with safe defaults. Reverting is a simple `git checkout` of both files. Since `protected_paths` defaults to `{}` in all functions, any caller that does not pass the parameter will see unchanged behavior.
