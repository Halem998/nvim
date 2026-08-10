# Implementation Summary: Uniform Extension Routing

- **Task**: 539 - Uniform extension routing: one source of truth, zero hardcoding
- **Status**: [COMPLETED]
- **Started**: 2026-05-07T12:00:00Z
- **Completed**: 2026-05-07T12:30:00Z
- **Artifacts**: specs/539_uniform_extension_routing/plans/01_uniform-routing-plan.md
- **Dependencies**: Task #538

## Overview

Established `manifest.json` as the single source of truth for extension routing by adding missing routing sections to 8 extensions, fixing orphaned entries in the present manifest, removing hardcoded routing tables from 3 command docs, generalizing Anti-Bypass constraints, retargeting the validation script, and deprecating the `.claude/` command mirrors.

## What Changed

- **8 extension manifests** received new `routing` sections:
  - `epidemiology`, `filetypes`, `formal`, `latex`, `nix`, `python`, `web`, `z3`
  - `filetypes` and `lean` also received compound-key routing for command-specific skills
- **1 extension manifest** fixed orphaned entries:
  - `present`: removed 5 `skill-planner` cross-extension references from plan routing
  - `present`: fixed `:assemble` suffixes on `skill-grant` and `skill-slides` in implement routing
- **3 command docs** had hardcoded "Extension-Based Routing Table" markdown tables removed:
  - `.opencode/commands/implement.md`
  - `.opencode/commands/research.md`
  - `.opencode/commands/plan.md`
  - Fallback comments updated to remove misleading "Using fallback routing" phrase
- **3 command docs** had Anti-Bypass constraints generalized:
  - Replaced enumerated skill lists with manifest-discovery reference language
- **Validation script** retargeted from manifest-vs-table comparison to manifest-integrity checks:
  - Check A: Skill coverage (every skill in `provides.skills` has a routing entry)
  - Check B: Routing integrity (every routing value exists in same manifest's `provides.skills`)
  - Check C: No hardcoded tables (grep command docs)
  - Check D: Valid JSON (all manifests parse)
- **`.claude/commands/README.md`** created with deprecation notice for legacy mirror directory

## Decisions

- Added compound-key routing for command-only skills (`filetypes:deck`, `lean:lake`, `web:tag`) so the integrity check passes without exempting them
- Kept the validation script filename `validate-routing-tables.sh` to avoid breaking historical references
- Did not modify `.claude/commands/*.md` functionally — only added a deprecation README

## Impacts

- `/research`, `/plan`, `/implement` commands now route purely via manifest discovery
- New extensions only need to update their `manifest.json` — no command doc edits required
- Validation script will catch missing routing, orphaned skills, and hardcoded tables

## Follow-ups

- None

## References

- `specs/539_uniform_extension_routing/reports/01_uniform-routing-research.md`
- `specs/539_uniform_extension_routing/plans/01_uniform-routing-plan.md`
- `.opencode/scripts/validate-routing-tables.sh`
