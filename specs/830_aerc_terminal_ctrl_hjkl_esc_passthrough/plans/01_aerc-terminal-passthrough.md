# Implementation Plan: Task #830

- **Task**: 830 - Special-case the aerc terminal so `<C-h/j/k/l>` and `<Esc>` reach aerc instead of Neovim
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/830_aerc_terminal_ctrl_hjkl_esc_passthrough/reports/01_aerc-terminal-passthrough-research.md
- **Artifacts**: plans/01_aerc-terminal-passthrough.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; .claude/rules/neovim-lua.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Special-case the aerc terminal in `_G.set_terminal_keymaps()` (`lua/neotex/config/keymaps.lua:116-158`) so that `<C-h/j/k/l>` and `<Esc>` are left unmapped in aerc terminal buffers and reach the aerc process instead of being intercepted by Neovim's window-navigation / exit-terminal-mode bindings. The change is a single additive `is_aerc` boolean (detected via `bufname:match("aerc")`, mirroring the existing `is_claude` idiom) plus two strictly-gated conditional edits. It is a small, single-file change with no impact on Claude Code, OpenCode, or generic terminals. Definition of done: aerc terminals pass `<C-hjkl>`/`<Esc>` through to the aerc pty, all other terminal types keep their current behavior, and `keymaps.lua` loads cleanly under `nvim --headless`.

### Research Integration

The research report (`reports/01_aerc-terminal-passthrough-research.md`) establishes the exact implementation shape:
- aerc is launched via toggleterm.nvim (`mail.lua` `cmd = "aerc"`), whose `Terminal:__spawn()` bakes the cmd into the `termopen()` string, producing a bufname of the form `term://{cwd}//{pid}:aerc;#toggleterm#<id>` — so `bufname:match("aerc")` reliably matches, and the `is_opencode` `vim.b.snacks_terminal` idiom is NOT applicable (toggleterm only stores an opaque `toggle_number` in `vim.b`).
- Precise gate points: the `<Esc>` guard at line 132 (`if not is_claude then`) and the `<C-hjkl>` -> `wincmd` `else` branch at lines 146-151.
- The `is_aerc` branch for `<C-hjkl>` must be an empty `elseif` (no `buf_map` calls) placed between the `is_opencode` branch and the generic `else` — NOT an early return, which would incorrectly skip the unconditional `<M-*>` resize binds at lines 153-157.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` provided, `roadmap_flag` not set). Per the research report, this task is a hard prerequisite for cross-repo `.dotfiles` task 105 Recommendation B (aerc keybinding alignment); that dependency is informational only and out of scope here.

## Goals & Non-Goals

**Goals**:
- Add an `is_aerc` local computed from the already-fetched `bufname`, using `bufname:match("aerc")`.
- Exempt aerc terminals from the `<Esc>` remaps by extending the line-132 guard to `if not is_claude and not is_aerc then`.
- Leave `<C-h/j/k/l>` unmapped for aerc terminals via an intentionally-empty `elseif is_aerc then` branch, so those keys pass through to the aerc pty.
- Preserve the unconditional `<M-Left>/<M-Right>/<M-h>/<M-l>` resize binds and `winfixbuf` for aerc terminals.

**Non-Goals**:
- No change to Claude Code, OpenCode, or generic `:terminal` `<C-hjkl>`/`<Esc>` behavior.
- No aerc-side keybindings (that is `.dotfiles` task 105's scope).
- No change to the `<M-*>` resize binds or `winfixbuf` locking behavior.
- No new detection idiom beyond mirroring `is_claude`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future terminal cwd/cmd bufname accidentally contains the substring `"aerc"`, matching `is_aerc` | L | L | Accepts the identical, already-tolerated theoretical risk of the existing `is_claude` `bufname:match("claude")` idiom; no such path/tool currently exists in this config (confirmed by research grep). |
| Regression to Claude Code / OpenCode / generic `<C-hjkl>`/`<Esc>` behavior | H | L | `is_aerc` is a new boolean, `false` for all existing terminal types; the `<Esc>` guard change is a strict narrowing and the `<C-hjkl>` change adds a new `elseif` branch that only fires for aerc. Verified explicitly in manual testing (Phase 1 verification). |
| Using an early `return` in the `is_aerc` branch would drop the `<M-*>` resize binds | M | L | Plan mandates an empty `elseif` branch (not early return); resize binds at lines 153-157 remain unconditional and after the `if/elseif/else` block. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Special-case aerc in set_terminal_keymaps() [COMPLETED]

**Goal**: Add `is_aerc` detection and strictly gate `<Esc>` and `<C-hjkl>` so aerc terminals pass those keys through, leaving all other terminal types unchanged.

**Tasks**:
- [x] In `lua/neotex/config/keymaps.lua`, after the `is_opencode` detection block (after line 128, before the `-- Terminal navigation` comment at line 130), add:
  `local is_aerc = bufname:match("aerc") ~= nil`
- [x] Change the `<Esc>` guard at line 132 from `if not is_claude then` to `if not is_claude and not is_aerc then`.
- [x] Restructure the `<C-hjkl>` conditional (lines 140-151) from `if is_opencode then ... else ... end` to a 3-way branch by inserting `elseif is_aerc then` (with an explanatory comment and NO `buf_map` calls) between the `is_opencode` branch and the generic `else`. Do NOT use `return` / early-exit.
- [x] Confirm the `<M-*>` resize binds (lines 153-157) and `winfixbuf` (line 118) remain unconditional and untouched.

**Timing**: ~20 minutes (edit + headless load check), plus manual verification.

**Depends on**: none

**Files to modify**:
- `lua/neotex/config/keymaps.lua` — add `is_aerc` local (~1 line); extend `<Esc>` guard condition (line 132); add empty `elseif is_aerc then` branch to the `<C-hjkl>` conditional (~2-3 lines incl. comment). Net diff ~5 lines.

**Verification**:
- Headless load check (see Testing & Validation) passes with no Lua errors.
- Code review confirms: `is_aerc` computed from `bufname` (already available at line 121); `<Esc>` guard is `not is_claude and not is_aerc`; `<C-hjkl>` has an empty `elseif is_aerc then` branch and no early return; resize binds unchanged.

## Testing & Validation

- [ ] **Headless load check**: `nvim --headless -c "luafile lua/neotex/config/keymaps.lua" -c "qa"` (or `nvim --headless "+lua require('neotex.config.keymaps')" +qa`) completes with no Lua syntax/runtime errors.
- [ ] **Manual — aerc**: Open aerc via `<leader>me`; confirm `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` are received by aerc (folder/message navigation, not Neovim window navigation) and `<Esc>` reaches aerc (closes aerc menus / returns to aerc's own mode) rather than exiting terminal mode.
- [ ] **Manual — Claude Code (regression)**: Open a Claude Code terminal; confirm `<C-hjkl>` still navigate Neovim windows and `<Esc>` still behaves as before (Claude Code keeps its internal-normal-mode exemption; unchanged).
- [ ] **Manual — generic `:terminal` (regression)**: Open a plain `:terminal`; confirm `<C-hjkl>` still navigate windows and `<Esc>` still exits terminal mode.
- [ ] **Manual — resize (aerc)**: In the aerc terminal, confirm `<M-h>/<M-l>/<M-Left>/<M-Right>` resize bindings still work (proves the empty `elseif` did not early-return past them).

## Artifacts & Outputs

- `lua/neotex/config/keymaps.lua` (modified — `set_terminal_keymaps()` special-cases aerc)
- `plans/01_aerc-terminal-passthrough.md` (this plan)
- `summaries/01_aerc-terminal-passthrough-summary.md` (produced at implementation time)

## Rollback/Contingency

The change is confined to a single function in one file. To revert, run `git checkout -- lua/neotex/config/keymaps.lua` (before commit) or `git revert` the implementation commit (after commit). Because `is_aerc` is additive and `false` for every non-aerc terminal, reverting fully restores prior behavior with no residual state.
