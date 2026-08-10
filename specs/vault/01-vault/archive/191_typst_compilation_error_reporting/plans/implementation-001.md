# Implementation Plan: Task #191

- **Task**: 191 - Fix typst compilation error reporting
- **Status**: [COMPLETE]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Modify the `typst_compile()` function in `after/ftplugin/typst.lua` to capture stderr output and populate the quickfix list with parsed compilation errors. The current implementation ignores stderr, showing only a generic "Compilation failed" notification. This plan adds `--diagnostic-format short` flag, implements `on_stderr` callback for error capture, parses the short format output into quickfix items, and auto-opens quickfix on errors.

### Research Integration

- Research confirmed typst uses `--diagnostic-format short` for parseable `file:line:col: level: message` output
- Errors go to stderr and typst stops at first error
- `vim.fn.setqflist()` with direct items is recommended over errorformat parsing
- `vim.schedule()` is required in job callbacks for safe Neovim API calls

## Goals & Non-Goals

**Goals**:
- Capture typst compilation errors from stderr
- Parse errors into structured quickfix items
- Auto-open quickfix list when errors exist
- Clear quickfix on successful compilation
- Add new keymap `<leader>lq` to show quickfix

**Non-Goals**:
- Modifying LSP diagnostics behavior (separate system)
- Supporting multiple simultaneous errors (typst limitation)
- Implementing watch mode error capture (different use case)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typst output format changes | Medium | Low | Use `--diagnostic-format short` which is stable CLI flag |
| Path handling issues | Low | Medium | Test with absolute and relative file paths in errors |
| Async callback safety | Low | Low | Use `vim.schedule()` for all Neovim API calls in callbacks |

## Implementation Phases

### Phase 1: Modify typst_compile() for Error Capture [COMPLETED]

**Goal**: Update `typst_compile()` to capture stderr and populate quickfix

**Tasks**:
- [ ] Add `--diagnostic-format short` flag to compilation command
- [ ] Add `stderr_buffered = true` option to jobstart
- [ ] Implement `on_stderr` callback to collect stderr lines
- [ ] Add error parsing function for short format (`file:line:col: level: message`)
- [ ] Populate quickfix with parsed items using `vim.fn.setqflist()`
- [ ] Auto-open quickfix on errors with `vim.cmd("copen")`
- [ ] Clear quickfix on successful compilation
- [ ] Wrap all API calls in `vim.schedule()`

**Timing**: 45 minutes

**Files to modify**:
- `after/ftplugin/typst.lua` - Update `typst_compile()` function (lines 182-206)

**Verification**:
- Compile a typst file with intentional error
- Verify error appears in quickfix with correct file, line, column
- Verify `:copen` shows "Typst Errors" title
- Verify successful compilation clears quickfix

---

### Phase 2: Add Quickfix Keymap [COMPLETED]

**Goal**: Add `<leader>lq` keymap to open quickfix for compilation errors

**Tasks**:
- [ ] Create `show_compilation_errors()` function that opens quickfix
- [ ] Add which-key registration for `<leader>lq`
- [ ] Keep existing `<leader>le` for LSP diagnostics (unchanged)

**Timing**: 15 minutes

**Files to modify**:
- `after/ftplugin/typst.lua` - Add new function and which-key binding

**Verification**:
- Press `<leader>lq` to open quickfix
- Verify which-key shows both `<leader>le` (LSP) and `<leader>lq` (compile errors)

---

### Phase 3: Testing and Edge Cases [COMPLETED]

**Goal**: Verify error handling works correctly across different scenarios

**Tasks**:
- [ ] Test with single-file typst project
- [ ] Test with multi-file project (chapter file with main file)
- [ ] Test with relative vs absolute paths in error output
- [ ] Test error type mapping (error -> E, warning -> W)
- [ ] Test quickfix navigation (`:cn`, `:cp`)
- [ ] Verify clean compilation clears previous errors

**Timing**: 30 minutes

**Files to modify**:
- None (testing phase)

**Verification**:
- All test scenarios pass
- Quickfix entries navigate to correct file/line/column

## Testing & Validation

- [ ] Create test typst file with intentional syntax error (undefined variable)
- [ ] Run `<leader>lr` and verify error appears in quickfix
- [ ] Navigate to error location using quickfix
- [ ] Fix error and recompile, verify quickfix clears
- [ ] Test `<leader>lq` opens quickfix independently
- [ ] Test in multi-file project with chapter file

## Artifacts & Outputs

- `after/ftplugin/typst.lua` - Modified with error capture and quickfix integration
- `specs/191_typst_compilation_error_reporting/summaries/implementation-summary-YYYYMMDD.md` - Implementation summary

## Rollback/Contingency

If the changes cause issues:
1. Revert `typst_compile()` to original simple implementation
2. Remove `<leader>lq` keymap
3. Keep `<leader>le` for LSP diagnostics as fallback

The changes are isolated to `typst_compile()` and a new keymap, so rollback is straightforward.
