# Implementation Summary: Task #165

**Completed**: 2026-03-10
**Duration**: ~3 hours

## Changes Made

Expanded the .opencode/ agent system to properly route tasks to extension-specific agents based on language. Previously, commands were hardcoded to use generic `skill-researcher` and `skill-implementer` regardless of task language. Now all 10+ extension languages are routed to their specialized skills and agents.

## Files Modified

### Command Routing
- `.opencode/commands/research.md` - Added language-to-skill routing table covering all extensions (neovim, lean4, z3, nix, python, latex, typst, web, epidemiology, formal/logic/math/physics). Expanded agent verification table to validate correct agent_type in metadata.

- `.opencode/commands/implement.md` - Added equivalent language-to-skill routing table for implementation agents. Expanded agent verification table.

### Orchestration Documentation
- `.opencode/context/core/orchestration/orchestration-core.md` - Expanded Command->Agent Mapping table to include all extension languages. Added comprehensive routing validation for extension languages. Added new "Extension Registration" section documenting the complete process for adding new language extensions.

### Context Index
- `.opencode/context/index.json` - Fixed web entry to reference `web-research-agent` and `web-implementation-agent` instead of generic agents. Added entries for z3 (4 entries), nix (5 entries), and python (3 entries) extensions with correct agent mappings.

### New Utility Script
- `.opencode/scripts/merge-extensions.sh` - Created new utility script for managing extension index entries. Supports `--dry-run` to preview changes and `--verify` to check index completeness. Idempotent - safe to run multiple times.

### README Update
- `.opencode/README.md` - Added reference to extension registration process with link to orchestration-core.md documentation.

## Verification

- All JSON files validated with jq
- merge-extensions.sh script tested with --dry-run and --verify flags
- All referenced skill and agent files verified to exist in extension directories
- Routing tables verified consistent across commands and orchestration documentation

## Summary Statistics

| Extension | Research Skill | Implementation Skill | Research Agent | Implementation Agent |
|-----------|----------------|---------------------|----------------|---------------------|
| neovim | skill-neovim-research | skill-neovim-implementation | neovim-research-agent | neovim-implementation-agent |
| lean4 | skill-lean-research | skill-lean-implementation | lean-research-agent | lean-implementation-agent |
| z3 | skill-z3-research | skill-z3-implementation | z3-research-agent | z3-implementation-agent |
| nix | skill-nix-research | skill-nix-implementation | nix-research-agent | nix-implementation-agent |
| python | skill-python-research | skill-python-implementation | python-research-agent | python-implementation-agent |
| latex | skill-latex-research | skill-latex-implementation | latex-research-agent | latex-implementation-agent |
| typst | skill-typst-research | skill-typst-implementation | typst-research-agent | typst-implementation-agent |
| web | skill-web-research | skill-web-implementation | web-research-agent | web-implementation-agent |
| epidemiology | skill-epidemiology-research | skill-epidemiology-implementation | epidemiology-research-agent | epidemiology-implementation-agent |
| formal/logic/math/physics | skill-formal-research | skill-implementer | formal-research-agent | general-implementation-agent |

## Notes

- The formal extension maps multiple languages (formal, logic, math, physics) to specialized research agents but uses the general implementation agent since formal proofs are often written in Lean4 (separate extension) or documented in LaTeX/Typst (separate extensions).

- Extension index-entries.json files contain many more entries than the main index.json. This is by design - the main index contains a curated subset for orchestration routing, while extension index files provide comprehensive context for specialized agents.

- The merge-extensions.sh script identifies missing entries but does not auto-merge to preserve JSON structure integrity. Manual merging allows for proper formatting and review.
