# Teammate A Findings: Extension README and Manifest Audit

Systematic audit of all 16 extensions in `.claude/extensions/`. Each extension was checked for README completeness, manifest accuracy, routing_exempt correctness, and consistency between README and CLAUDE.md/EXTENSION.md.

---

## Key Findings

- **1 automated check failure**: `founder` - `/consult` command is in manifest but not mentioned in README.md
- **1 significant content drift**: `memory` README describes an outdated manual `--remember` model, while `EXTENSION.md` and `CLAUDE.md` describe the current auto-retrieval model with `--clean` to suppress
- **1 incomplete README**: `present` README is thin (88 lines) - missing Architecture, Skill-Agent Mapping, Language Routing, Workflow, and Output Artifacts sections that all comparable complex extensions include
- **1 missing `routing_exempt` flag**: `slidev` has no `task_type`, no `routing`, no `skills` - passes check script (zero skills means no routing check), but should declare `routing_exempt: true` for consistency with core's infrastructure-only pattern
- **`founder` README is stale in multiple ways**: says "eight commands" but manifest has 10; architecture tree omits 3 agent files and 2 command files that exist on disk
- **All 16 README.md, manifest.json, EXTENSION.md files exist** - no missing required files
- **All manifest-declared files exist on disk** - no broken file references detected by check script
- **15/16 extensions pass automated lint** - only founder fails

---

## Per-Extension Audit

### core (v1.0.0)

- **README**: 178 lines. Complete: all 14 commands, 8 agents, 16 skills, 6 rules documented. Explains `routing_exempt: true` and "Intentionally Omitted Sections" rationale clearly.
- **manifest.json**: Valid. `routing_exempt: true` correctly set. No routing block (intentional).
- **routing_exempt**: YES. Correct -- core is infrastructure, not a domain extension.
- **Script**: PASS (routing check skipped per exempt flag)
- **Issues**: None

---

### epidemiology (v2.0.0)

- **README**: 70 lines. Compact but complete: command, routing table, skill-agent mapping, MCP server note, file inventory, references.
- **manifest.json**: Valid. Routing block present. Dependency on core declared.
- **routing_exempt**: Absent. Correct -- has skills and routing.
- **Script**: PASS
- **Issues**: None

---

### filetypes (v2.2.0)

- **README**: 225 lines. Thorough: overview, MCP setup (SuperDoc, openpyxl with scoping caveat), 4 commands, architecture, skill-agent mapping, language routing table, workflow, output artifacts, key patterns, tool dependencies, references.
- **manifest.json**: Valid. 6 task type routing entries. 2 MCP servers declared.
- **routing_exempt**: Absent. Correct -- has skills and routing.
- **Script**: PASS
- **Issues**: None

---

### formal (v1.0.0)

- **README**: 158 lines. Thorough: overview, installation, commands (none), architecture, skill-agent mapping, language routing (keyword triggers per domain), workflow, research-only pattern explanation, output artifacts, key patterns, context references.
- **manifest.json**: Valid. 4 research skills, no implementation skills (intentional, documented). Routing block present.
- **routing_exempt**: Absent. Correct -- has skills and routing.
- **Script**: PASS
- **Issues**: None

---

### founder (v3.0.0)

- **README**: 408 lines. Extensive -- but has accuracy gaps.
- **manifest.json**: Valid. 10 commands, 15 skills. Routing block present.
- **routing_exempt**: Absent. Correct -- has skills and routing.
- **Script**: FAIL
- **Issues (3)**:
  1. **FAIL (script-detected)**: `/consult` command is in manifest `provides.commands` but entirely absent from README. The command file exists at `commands/consult.md`. It is a standalone Socratic consultation tool with `--legal` mode.
  2. **Stale count + overview table**: README says "eight commands" (line 7) and overview table lists 9 rows (meeting was added but consult was not). Manifest has 10 commands.
  3. **Stale architecture section**: Commands directory listing shows only 8 entries (market through sheet), missing `meeting.md` and `consult.md`. Agents directory listing omits `financial-analysis-agent.md`, `meeting-agent.md`, and `legal-analysis-agent.md` (all 3 exist on disk and are in manifest).

---

### latex (v1.0.0)

- **README**: 57 lines. Compact but adequate for a simple extension: overview, installation, commands (none), skill-agent mapping, language routing, VimTeX keymaps, document structure conventions, rules applied, references.
- **manifest.json**: Valid. 1 routing entry. 1 rule file.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### lean (v1.0.0)

- **README**: 192 lines. Thorough: overview, installation, MCP setup (lean-lsp with capability table), 2 commands (/lake, /lean), architecture, skill-agent mapping, language routing, workflow, output artifacts, key patterns (lake build verification, proof search hierarchy, Mathlib conventions), tool dependencies, references.
- **manifest.json**: Valid. 3 routing entries. MCP server declared. settings-fragment.json present.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### memory (v1.0.0)

- **README**: 291 lines. Extensive: 3 commands (/learn, /distill, and --remember flag), writing modes, storage details, MCP config, troubleshooting, best practices.
- **manifest.json**: Valid. MCP server declared.
- **routing_exempt**: Absent. Correct -- has skills and routing.
- **Script**: PASS
- **Issues (1 -- accuracy)**:
  - **README contradicts CLAUDE.md and EXTENSION.md on retrieval model**. README line 25: *"Memories are NOT automatically injected into every session. The vault is passive. You must pass `--remember` explicitly."* README line 71: `/research N --remember`. EXTENSION.md (line 27-29): *"Memory retrieval is automatic: when the memory extension is loaded, `/research`, `/plan`, and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories."* CLAUDE.md says the same. `memory-retrieve.sh` exists at `.claude/scripts/memory-retrieve.sh` confirming the script is in place. The README appears to document an older manual design that was superseded by automatic preflight injection.

---

### nix (v1.0.0)

- **README**: 186 lines. Thorough: overview, installation, MCP setup (mcp-nixos with call syntax examples), commands (none), architecture, skill-agent mapping, language routing, workflow, output artifacts, key patterns (flake workflow, module pattern, package validation), rules applied, context references, references.
- **manifest.json**: Valid. 1 routing entry. MCP server declared. settings-fragment.json present.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### nvim (v1.0.0)

- **README**: 197 lines. Thorough: overview, installation (notes auto-load for this repo), commands (none), architecture, skill-agent mapping, language routing, workflow, output artifacts, key patterns (plugin specs, keymaps, options, autocommands, pcall, module namespaces), rules applied, test protocols, context references, references.
- **manifest.json**: Valid. 1 routing entry.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### present (v1.0.0)

- **README**: 88 lines. Covers overview table (5 features), 5 commands with syntax examples, and a "Related Files" section pointing to EXTENSION.md.
- **manifest.json**: Valid. 6 routing keys. Dependency on slidev declared. MCP server (superdoc) declared.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues (1 -- completeness)**:
  - README is significantly below the complexity-appropriate standard. The `EXTENSION.md` contains the Skill-Agent table, Language Routing table, Talk Modes table, and Talk Library description -- but EXTENSION.md is a CLAUDE.md merge fragment, not user documentation. Comparable complex extensions (lean: 192 lines, nix: 186 lines, web: 168 lines) all include architecture diagrams, skill-agent tables, and workflow diagrams directly in README.md. The extension-readme-template.md classifies present as a "complex extension" requiring all optional sections. The content exists in EXTENSION.md but is in the wrong file for developer discoverability.

---

### python (v1.0.0)

- **README**: 59 lines. Adequate for a simple extension: overview, installation, commands (none), skill-agent mapping, language routing, testing commands, code quality commands, references.
- **manifest.json**: Valid. 1 routing entry.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### slidev (v1.0.0)

- **README**: 85 lines. Well-written: purpose, resource catalog (6 animations, 9 CSS presets with names), directory structure, dependency declaration pattern, consuming extensions.
- **manifest.json**: Valid. No routing block. No task_type. No skills (zero agents, zero commands, zero skills).
- **routing_exempt**: ABSENT -- but check script passes because it only triggers routing block check when `provides.skills` length > 0.
- **Script**: PASS
- **Issues (1 -- minor consistency)**:
  - `routing_exempt: true` should be added. Slidev is never loaded directly in the picker -- it is auto-loaded as a dependency of `founder` and `present`. The core extension uses `routing_exempt: true` to document its infrastructure-only status. Slidev is analogously infrastructure-only. Without the flag, the manifest is technically ambiguous about intent. Harmless in practice but inconsistent.

---

### typst (v1.0.0)

- **README**: 57 lines. Adequate for a simple extension: overview, installation, commands (none), skill-agent mapping, language routing, Typst vs LaTeX comparison table, common operations, references.
- **manifest.json**: Valid. 1 routing entry.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### web (v1.0.0)

- **README**: 168 lines. Thorough: overview, installation, architecture, skill-agent mapping, language routing, workflow (includes /tag deployment note), output artifacts, key patterns (Astro component structure, Tailwind v4 CSS-first config, build/check enforcement), rules applied, context references, references.
- **manifest.json**: Valid. 1 routing entry.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

### z3 (v1.0.0)

- **README**: 58 lines. Adequate for a simple extension: overview, installation, commands (none), skill-agent mapping, language routing, key patterns (solver, BitVec, incremental, simplify, optimize), common operations code example, references.
- **manifest.json**: Valid. 1 routing entry.
- **routing_exempt**: Absent. Correct.
- **Script**: PASS
- **Issues**: None

---

## Summary Table

| Extension | README Lines | Script | routing_exempt | Issues |
|-----------|-------------|--------|----------------|--------|
| core | 178 | PASS | YES (correct) | None |
| epidemiology | 70 | PASS | absent (correct) | None |
| filetypes | 225 | PASS | absent (correct) | None |
| formal | 158 | PASS | absent (correct) | None |
| founder | 408 | FAIL | absent (correct) | /consult undocumented; says "8 commands" has 10; arch tree missing 5 files |
| latex | 57 | PASS | absent (correct) | None |
| lean | 192 | PASS | absent (correct) | None |
| memory | 291 | PASS | absent (correct) | README says manual --remember; CLAUDE.md says automatic with --clean |
| nix | 186 | PASS | absent (correct) | None |
| nvim | 197 | PASS | absent (correct) | None |
| present | 88 | PASS | absent (correct) | Thin: missing arch/skill-agent/workflow/output sections |
| python | 59 | PASS | absent (correct) | None |
| slidev | 85 | PASS | ABSENT (minor) | routing_exempt not declared; harmless but inconsistent |
| typst | 57 | PASS | absent (correct) | None |
| web | 168 | PASS | absent (correct) | None |
| z3 | 58 | PASS | absent (correct) | None |

---

## Recommended Approach

**P1 -- Fix script failure (founder /consult)**

Add a `### /consult` section with syntax and description. Update overview table to include `/consult`. Fix "eight commands" to "ten commands". Add `meeting.md`, `consult.md` to the architecture commands listing. Add the 3 missing agents to the architecture agents listing.

**P2 -- Fix content accuracy (memory auto-retrieval)**

The README describes a `--remember` flag model that contradicts CLAUDE.md and EXTENSION.md. Determine ground truth (auto-retrieval per EXTENSION.md is likely authoritative since it matches the existing `memory-retrieve.sh` script). Update the README to describe automatic retrieval with `--clean` for suppression. Remove or reframe all `--remember` references.

**P3 -- Improve completeness (present README)**

Expand from 88 to ~160-180 lines by adding: architecture directory tree, Skill-Agent Mapping table (moving content from EXTENSION.md), Language Routing table, Workflow diagram, Output Artifacts table. The content exists in EXTENSION.md and just needs to be mirrored in README.md.

**P4 -- Minor consistency (slidev manifest)**

Add `"routing_exempt": true` to `slidev/manifest.json` to document intent and match core's pattern.

---

## Confidence Level

**High**

All 16 extension directories read directly. Issues are based on concrete discrepancies between manifest entries, README text, and CLAUDE.md/EXTENSION.md. The automated script was cross-checked against manual inspection. The memory auto-retrieval issue is based on three independent sources (README says manual, EXTENSION.md says automatic, script file exists confirming the mechanism) -- the README is clearly the stale one.
