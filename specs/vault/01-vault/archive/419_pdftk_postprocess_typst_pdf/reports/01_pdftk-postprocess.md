# Research: pdftk Post-Processing for Typst PDFs

## Problem

Typst-generated PDFs lack explicit permission flags. Some PDF viewers (Apple Preview, Adobe Reader, etc.) interpret the absence of permission metadata as restrictive, blocking users from adding annotations, notes, or highlights. This affects PDFs shared with collaborators who use these viewers.

## Analysis

### Current Compilation Flow

**Interactive (Neovim ftplugin)** - `after/ftplugin/typst.lua`:
- `typst_compile()` (line 208) - One-shot compilation via `process.start()`, PDF written to same directory as source
- `typst_watch()` (line 277) - Continuous compilation, detects success via "compiled successfully" in stdout
- Both use the process manager (`neotex.util.process`) for async execution

**Agent-driven** - `.claude/extensions/typst/agents/typst-implementation-agent.md`:
- Uses `typst compile document.typ` via Bash tool
- No post-processing step documented

### pdftk Verification

- **Installed**: `/run/current-system/sw/bin/pdftk` (v3.3.3, pdftk-java)
- **Command**: `pdftk input.pdf output tmp.pdf allow AllFeatures && mv tmp.pdf input.pdf`
- **AllFeatures** grants: Printing, DegradedPrinting, ModifyContents, Assembly, CopyContents, ScreenReaders, ModifyAnnotations, FillIn, AllFeatures
- **Tested**: Successfully processes typst output (6286 bytes in, 6067 bytes out)
- **In-place update**: Use temp file + mv to avoid corruption if interrupted

### Typst PDF Structure

Typst 0.14.2 produces PDFs without an `/Encrypt` dictionary. The `allow AllFeatures` flag from pdftk adds an explicit permissions structure that viewers recognize as "all operations permitted." This is a metadata addition, not encryption -- it signals intent to viewers.

## Scope of Changes

### 1. `after/ftplugin/typst.lua` (primary)

**Add helper function** `_pdftk_unlock(pdf_path, callback)`:
- Check `vim.fn.executable("pdftk")` (skip gracefully if missing)
- Run `pdftk <pdf> output <tmp> allow AllFeatures && mv <tmp> <pdf>` via `vim.fn.jobstart`
- Async execution with optional callback for chaining
- Notify on success/failure

**Hook into `typst_compile()`** (line 238, `on_exit` callback):
- After `exit_code == 0`, derive PDF path and call `_pdftk_unlock`
- Notification: "Compilation successful, unlocking PDF..." then "PDF unlocked"

**Hook into `typst_watch()`** (line 305, `on_stdout` callback):
- After detecting "compiled successfully", derive PDF path and call `_pdftk_unlock`
- Use debounce or guard flag to avoid overlapping pdftk runs during rapid recompilation

### 2. `.claude/extensions/typst/agents/typst-implementation-agent.md` (secondary)

**Update compilation instructions** in Stages 4-5:
- Add pdftk post-processing step after `typst compile`
- Update bash example:
  ```bash
  typst compile document.typ && pdftk document.pdf output document_tmp.pdf allow AllFeatures && mv document_tmp.pdf document.pdf
  ```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | AllFeatures (not just Annotating) | Covers all viewer restrictions, no downside for unencrypted PDFs |
| Failure mode | Silent skip + warning | pdftk absence shouldn't block compilation |
| Watch debounce | Guard flag | Prevents concurrent pdftk runs on rapid recompile |
| Temp file | `{pdf}.tmp` in same dir | Atomic via `mv`, avoids cross-filesystem issues |

## Implementation Estimate

Small change -- ~30 lines of Lua for the helper + hooks, plus a few lines of markdown edits in the agent doc.
