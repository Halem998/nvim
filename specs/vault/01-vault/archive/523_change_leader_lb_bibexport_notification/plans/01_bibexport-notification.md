# Implementation Plan: Task #523

- **Task**: 523 - change_leader_lb_bibexport_notification
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/523_change_leader_lb_bibexport_notification/reports/01_bibexport-notification-research.md
- **Artifacts**: plans/01_bibexport-notification.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Replace the `<leader>lb` keymap's `run_bibexport()` implementation in `after/ftplugin/tex.lua` to run `bibexport` asynchronously via `vim.fn.jobstart()` and display a notification on completion instead of opening a terminal buffer. The notification pattern must match `<leader>Tr` and `<leader>Ts` template copy functions: `require('neotex.util.notifications').editor()` with `categories.USER_ACTION`.

### Research Integration

Research report `01_bibexport-notification-research.md` confirms:
- Current implementation opens a terminal buffer with `vim.cmd('terminal ' .. cmd)`
- Target pattern uses `require('neotex.util.notifications').editor()` with `categories.USER_ACTION` and a context table
- Codebase exclusively uses `vim.fn.jobstart()` for async (not `vim.system()`)
- Must wrap callback bodies in `vim.schedule()` for safe Neovim API access

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items specifically targeted. This is a small UX improvement.

## Goals & Non-Goals

**Goals**:
- Replace terminal buffer with async `vim.fn.jobstart()` for `bibexport`
- Show success notification via `notify.editor()` with `categories.USER_ACTION`
- Show error notification with stderr capture via `categories.ERROR`
- Match the exact notification pattern of `<leader>Tr` and `<leader>Ts`

**Non-Goals**:
- Refactor other `<leader>l*` keymaps
- Add new features to bibexport behavior
- Change the keymap binding itself

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `bibexport` not in `$PATH` | Job fails immediately | Low | Let stderr capture + error notification handle it |
| `.aux` file missing | Silent failure | Medium | Pre-check `.aux` existence and fail fast with error notification |
| Large stderr output | Notification too long | Low | Truncate stderr to last 5 lines in error message |
| Callback crashes Neovim API | High | Low | Wrap all `on_exit` callback bodies in `vim.schedule()` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite run_bibexport() [COMPLETED]
- **Completed**: 2026-05-04

**Goal**: Replace terminal-based `run_bibexport()` with async jobstart and notification

**Tasks**:
- [x] **Task 1.1**: Pre-check `.aux` file exists; if not, send error notification and return early
- [x] **Task 1.2**: Build `bibexport` command and launch via `vim.fn.jobstart()` with `cwd = filedir`
- [x] **Task 1.3**: Capture stderr lines in `on_stderr` callback
- [x] **Task 1.4**: On `on_exit`, wrap body in `vim.schedule()`: if exit code 0, send `notify.editor('Bibexport complete', categories.USER_ACTION, { file = output_path })`; else send error notification with stderr or exit code
- [x] **Task 1.5**: Verify keymap still calls `run_bibexport()` unchanged

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `after/ftplugin/tex.lua` - Replace `run_bibexport()` body (lines 77-86) with async implementation

**Verification**:
- Open a `.tex` file and press `<leader>lb` with a valid `.aux` file present; expect a notification (not a terminal buffer)
- Test with missing `.aux`; expect error notification

## Testing & Validation

- [ ] Open a `.tex` file with `build/<name>.aux` present and run `<leader>lb`; verify notification appears with success message
- [ ] Open a `.tex` file without `.aux` and run `<leader>lb`; verify error notification appears immediately
- [ ] Verify no terminal buffer is created (check `:ls!` for terminal buffers)

## Artifacts & Outputs

- `after/ftplugin/tex.lua` - Modified `run_bibexport()` function

## Rollback/Contingency

- Revert `after/ftplugin/tex.lua` lines 77-86 to original `vim.cmd('terminal ' .. cmd)` implementation
