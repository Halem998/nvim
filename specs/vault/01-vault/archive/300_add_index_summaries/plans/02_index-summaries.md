# Plan: Add Missing Summaries to index.json Entries

**Task**: 300
**Date**: 2026-03-26
**Status**: Ready for implementation

## Overview

Add summary fields to 67 `project/` entries in the Website `.claude/context/index.json` that currently have `null` summaries.

## Approach

Single-phase implementation using jq to update all 67 entries in one pass.

### Phase 1: Generate and Apply Summaries [NOT STARTED]

1. Read each file's header (already done during planning)
2. Build a jq mapping of path -> summary for all 67 entries
3. Apply the mapping to index.json in a single jq transformation
4. Verify zero null summaries remain in project/ entries

## Summary Mapping

All 67 summaries drafted from file headers, following conventions:
- Noun-phrase style, 27-112 characters, no trailing period
- Describes what the file contains, not what it does

| Path | Summary |
|------|---------|
| project/filetypes/domain/conversion-tables.md | Document conversion tool mappings and fallback chains |
| project/memory/learn-usage.md | Guide for /learn command and memory vault operations |
| project/memory/memory-setup.md | MCP server setup for memory vault in Claude Code |
| project/memory/memory-troubleshooting.md | Common memory system issues and solutions |
| project/memory/domain/memory-reference.md | Memory extension MCP integration reference |
| project/memory/knowledge-capture-usage.md | Example workflows for knowledge capture commands |
| project/python/standards/code-style.md | Python code formatting and style guidelines |
| project/python/patterns/testing-patterns.md | Pytest testing patterns and conventions |
| project/python/domain/model-checker-api.md | ModelChecker package structure and API reference |
| project/python/domain/theory-lib-patterns.md | Semantic theory library structure and conventions |
| project/python/patterns/semantic-evaluation.md | Tree-walking evaluation patterns for Python interpreters |
| project/python/README.md | Overview of Python context for ModelChecker development |
| project/web/domain/web-reference.md | Astro, Tailwind, TypeScript, and Cloudflare reference |
| project/latex/patterns/document-structure.md | LaTeX document class and structure patterns |
| project/latex/patterns/theorem-environments.md | LaTeX theorem, lemma, and proof environment setup |
| project/latex/patterns/cross-references.md | LaTeX label conventions and cross-reference patterns |
| project/latex/standards/document-structure.md | Standards for main document layout and organization |
| project/latex/standards/latex-style-guide.md | LaTeX formatting and document class conventions |
| project/latex/standards/notation-conventions.md | Custom notation package and macro conventions |
| project/latex/standards/custom-macros.md | Patterns for creating and using custom LaTeX macros |
| project/latex/templates/subfile-template.md | Boilerplate template for LaTeX subfiles |
| project/latex/tools/compilation-guide.md | LaTeX build commands and compilation workflow |
| project/latex/README.md | Overview of LaTeX document development context |
| project/lean4/tools/blocked-mcp-tools.md | Reference for blocked Lean MCP tools and alternatives |
| project/lean4/patterns/mcp-fallback-table.md | Lean MCP tool fallback and recovery strategies |
| project/nix/README.md | Overview of NixOS and Home Manager context |
| project/nix/domain/nix-language.md | Core Nix expression language syntax reference |
| project/nix/domain/flakes.md | Nix flakes for reproducible configurations |
| project/nix/domain/nixos-modules.md | NixOS module system structure and options |
| project/nix/domain/home-manager.md | Home Manager user-level configuration reference |
| project/nix/patterns/module-patterns.md | Common NixOS and Home Manager module patterns |
| project/nix/patterns/overlay-patterns.md | Nixpkgs overlay customization patterns |
| project/nix/patterns/derivation-patterns.md | Nix package building with mkDerivation |
| project/nix/standards/nix-style-guide.md | Nix formatting, naming, and best practices |
| project/nix/tools/nixos-rebuild-guide.md | NixOS system configuration build commands |
| project/nix/tools/home-manager-guide.md | Home Manager environment and dotfile management |
| project/typst/patterns/theorem-environments.md | Typst theorem environment setup with thmbox package |
| project/typst/patterns/cross-references.md | Typst label system and cross-reference patterns |
| project/typst/patterns/fletcher-diagrams.md | Fletcher diagram patterns for flowcharts and arrows |
| project/typst/patterns/rule-environments.md | Custom environments for typing and inference rules |
| project/typst/patterns/bibliography.md | Typst bibliography and citation patterns |
| project/typst/patterns/document-structure.md | Patterns for organizing Typst documents |
| project/typst/patterns/math-typesetting.md | Mathematical notation and formatting in Typst |
| project/typst/patterns/styling-patterns.md | Common styling techniques for Typst documents |
| project/typst/patterns/tables-and-figures.md | Table and figure creation patterns in Typst |
| project/typst/standards/document-structure.md | Project directory layout and document organization |
| project/typst/standards/notation-conventions.md | Two-tier notation architecture for Typst documents |
| project/typst/standards/textbook-standards.md | Consistency and rigor standards for Typst textbooks |
| project/typst/standards/typst-style-guide.md | Typst document setup and formatting conventions |
| project/typst/standards/type-theory-foundations.md | Dependent type theory treatment standards for Typst |
| project/typst/standards/compilation-standards.md | Standards for compiling Typst documents |
| project/typst/standards/package-usage.md | Guidelines for using packages in Typst documents |
| project/typst/templates/chapter-template.md | Template for creating new Typst chapters |
| project/typst/templates/article-template.md | Template for academic articles in Typst |
| project/typst/templates/presentation-template.md | Template for presentations using Polylux |
| project/typst/templates/report-template.md | Template for technical reports in Typst |
| project/typst/templates/thesis-template.md | Template for thesis and dissertation documents |
| project/typst/tools/compilation-guide.md | Typst compilation and build commands |
| project/typst/README.md | Overview of Typst document development context |
| project/typst/typst-overview.md | Introduction to Typst typesetting system |
| project/typst/typst-packages.md | Overview of key Typst packages used in the project |
| project/typst/typst-vs-latex.md | Syntax and feature comparison between Typst and LaTeX |
| project/z3/domain/z3-api.md | Z3 Python API types and installation reference |
| project/z3/domain/smt-patterns.md | SMT-LIB patterns, Z3 tactics, and debugging techniques |
| project/z3/patterns/constraint-generation.md | Z3 constraint patterns for equality and range checks |
| project/z3/patterns/bitvector-operations.md | BitVector patterns for state representation in Z3 |
| project/z3/README.md | Overview of Z3 SMT solver development context |

## Verification

After applying, count entries where `path` starts with `project/` and `summary` is null. Expected: 0.
