# Research Report: Task #238

**Task**: 238 - fix_founder_implement_typst_output
**Started**: 2026-03-18
**Completed**: 2026-03-18
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration of `.claude/extensions/founder/`
- Analysis of founder-implement-agent.md, skill-founder-implement/SKILL.md
- Review of task 237 implementation summary and plan
- Examination of typst templates created in task 237
**Artifacts**:
- `specs/238_fix_founder_implement_typst_output/reports/01_founder-typst-fix.md` (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 237 successfully added typst templates and documentation for Phase 5 to founder-implement-agent
- However, the agent still generates markdown files (.md) in practice because Phase 5 execution requires the agent to actively generate typst content using the templates
- The issue is NOT missing templates or configuration - it's that the agent must actually invoke typst compilation during Phase 5
- Fix requires ensuring Phase 5 is actually executed (not just documented) and that the founder/ directory is created with .typ/.pdf output

## Context & Scope

The user reports that `/implement` on founder tasks creates `.md` files (e.g., `market-sizing-v3-20260318.md`) instead of `.typ` files. Task 237 was supposed to add typst output capabilities to the founder extension.

**Investigation Goal**: Determine why founder tasks produce markdown instead of typst output despite task 237's claimed implementation.

## Findings

### Task 237 Implementation Analysis

Task 237 made the following changes (verified in codebase):

**Files Created** (verified to exist):
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` (480 lines)
- `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ` (207 lines)
- `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ`

**Files Modified** (verified):
- `founder-implement-agent.md` - Has Phase 5: Typst Document Generation documented
- `founder-plan-agent.md` - Generates plans with Phase 5 included
- `manifest.json` - Correctly routes `founder` language to `skill-founder-implement`
- `index-entries.json` - Has entries for typst templates

### Root Cause Analysis

The issue is **NOT** with templates or configuration. The templates exist and the agent documentation includes Phase 5.

**The actual problem**: Phase 5 execution is documented but may not be executing in practice.

Examining `founder-implement-agent.md` Phase 5 (lines 235-337), the agent specification describes:

1. Checking typst availability
2. Selecting the appropriate typst template
3. Generating typst content from gathered context
4. Writing .typ file to `founder/{report-type}-{slug}.typ`
5. Compiling to PDF using `typst compile`

**Potential Failure Points**:

#### 1. Output Path Confusion

The agent specifies two output paths:
- **Phase 4 (Markdown)**: `strategy/{report-type}-{slug}.md`
- **Phase 5 (Typst)**: `founder/{report-type}-{slug}.typ` and `.pdf`

If Phase 4 is completing but Phase 5 is not executing, the user would see only markdown output.

#### 2. Phase 5 Not Being Reached

The agent may be stopping after Phase 4 because:
- All phases marked [COMPLETED] before Phase 5 runs
- Phase 5 error handling causes silent skip
- Typst not installed, triggering skip with warning

#### 3. Template Import Path Issues

The typst templates use relative imports:
```typst
#import "strategy-template.typ": *
```

When compiled from `founder/` directory, these imports would fail because `strategy-template.typ` is in `.claude/extensions/founder/context/project/founder/templates/typst/`, not in `founder/`.

**This is the most likely cause**. The compilation step in the agent uses:
```bash
cd "$template_dir"
typst compile "$(pwd)/$typst_file" "founder/${report-type}-{slug}.pdf"
```

But this path mixing is incorrect - `typst_file` should be an absolute path or the template should be copied to the output directory.

#### 4. founder/ Directory Not Created

No `founder/` directory exists in the repository (verified via `ls` and `Glob`), suggesting Phase 5 has never successfully completed.

### Template Structure Analysis

The typst templates are well-designed and follow proper Typst patterns:

**strategy-template.typ** (base):
- Professional page setup with headers/footers
- Typography rules for headings
- Reusable components: `metric-callout`, `highlight-box`, `strategy-table`, `market-circles`, etc.

**market-sizing.typ** (report-specific):
- Imports `strategy-template.typ`
- Defines `market-sizing-doc()` wrapper function with all parameters
- Expects content to be passed as function arguments, not generated

**Key Insight**: The templates are designed to be called with data parameters, e.g.:
```typst
#show: market-sizing-doc.with(
  project: "Project Name",
  tam-value: "$50B",
  ...
)
```

The agent must generate this wrapper call with all the gathered context data - it cannot simply "convert" markdown to typst.

### Output Location Verification

Current state:
- `strategy/` directory: Does NOT exist
- `founder/` directory: Does NOT exist

This means no founder implementation has successfully generated any output yet, or outputs are being placed elsewhere.

### Skill-to-Agent Flow Verification

The routing is correct:
1. `/implement` command routes `language: founder` to `skill-founder-implement`
2. `skill-founder-implement` invokes `founder-implement-agent`
3. The agent is supposed to execute Phases 1-5

## Diagnosis

**Primary Issue**: Phase 5 is documented but not properly executing. The typst content generation and compilation step either:
1. Fails silently due to import path issues
2. Is skipped because typst is not installed
3. Never reaches execution because phase completion markers are being set prematurely

**Secondary Issue**: The template import paths assume execution from the template directory, but the generated `.typ` file is written to `founder/` at the repository root. The import statement `#import "strategy-template.typ": *` would fail from that location.

## Recommended Fix

### Fix 1: Template Import Path Resolution (Required)

The generated `.typ` file must use absolute paths or the templates must be copied. Two options:

**Option A: Generate with absolute imports**

In `founder-implement-agent.md` Phase 5, when generating the typst content, use absolute import paths:

```typst
#import "/home/user/.config/nvim/.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ": *
```

**Option B: Generate self-contained typst file**

Include the necessary template content directly in the generated file (inline the functions used).

**Recommendation**: Option B is more portable - generate a self-contained `.typ` file that includes all needed styles and functions.

### Fix 2: Verify Typst Installation (Required)

Add explicit check and user guidance:

```bash
if ! command -v typst &> /dev/null; then
  echo "ERROR: typst is not installed. Install with: nix profile install nixpkgs#typst"
  echo "Phase 5 skipped - markdown report available at strategy/${report-type}-${slug}.md"
  # Mark phase [PARTIAL] not [COMPLETED]
  return
fi
```

### Fix 3: Create Output Directory (Required)

Before writing typst file:

```bash
mkdir -p "founder"
```

### Fix 4: Fix Compilation Command (Required)

Current (broken):
```bash
cd "$template_dir"
typst compile "$(pwd)/$typst_file" "founder/${report-type}-${slug}.pdf"
```

Fixed:
```bash
# From project root
typst compile "founder/${report_type}-${slug}.typ" "founder/${report_type}-${slug}.pdf" --root "."
```

Or with explicit font/package paths if needed.

### Fix 5: Add Explicit Phase 5 Execution Check

Add verification that Phase 5 actually runs and produces output:

```bash
# After Phase 5 completion
if [ ! -f "founder/${report_type}-${slug}.pdf" ]; then
  echo "ERROR: PDF not generated"
  # Mark phase [PARTIAL]
fi
```

## Files to Modify

| File | Change Required |
|------|-----------------|
| `.claude/extensions/founder/agents/founder-implement-agent.md` | Fix Phase 5 execution: import paths, directory creation, compilation command, verification |
| `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` | Ensure Phase 5 output verification in postflight |

## Decisions

1. **Self-contained typst**: Generate typst files that include needed styles inline (no relative imports)
2. **Explicit directory creation**: Create `founder/` directory before writing output
3. **Better error messages**: Provide clear guidance when typst is not installed
4. **Verification step**: Add explicit PDF existence check after compilation

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Typst not installed | Medium | High | Clear error message with installation instructions |
| Large inline templates | Low | Low | Only inline necessary functions, not entire strategy-template |
| Compilation failures | Low | Medium | Keep .typ file for debugging, mark phase [PARTIAL] |

## Next Steps

1. Create implementation plan that fixes Phase 5 execution in founder-implement-agent
2. Test with actual `/market`, `/plan`, `/implement` workflow
3. Verify PDF output appears in `founder/` directory

## Appendix

### Files Examined

| File | Lines | Purpose |
|------|-------|---------|
| manifest.json | 65 | Extension routing - verified correct |
| founder-implement-agent.md | 590 | Phase 5 specification - documented but execution issues |
| skill-founder-implement/SKILL.md | 284 | Skill wrapper - postflight needs verification |
| strategy-template.typ | 480 | Base typst template - well-designed |
| market-sizing.typ | 207 | Report template - proper function wrapper pattern |
| 237 summary | 97 | Previous task summary - claimed success |
| 237 plan | 236 | Implementation plan - all phases marked COMPLETED |

### Verification Commands

```bash
# Check if typst is installed
command -v typst

# Check founder directory
ls -la founder/ 2>/dev/null || echo "Does not exist"

# Check strategy directory
ls -la strategy/ 2>/dev/null || echo "Does not exist"

# List typst templates
ls .claude/extensions/founder/context/project/founder/templates/typst/
```
