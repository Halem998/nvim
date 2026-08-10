# Research Report: Uniform Extension Routing (Task 539)

**Research Agent**: general-research-agent  
**Artifact**: 01  
**Date**: 2026-05-07  
**Status**: researched

---

## Executive Summary

The extension routing system currently has **three sources of truth** that drift out of sync:

1. **Extension `manifest.json` files** — Some have `routing` sections, most do not.
2. **Command doc markdown tables** — Hardcoded "Extension-Based Routing Tables" in `implement.md`, `research.md`, and `plan.md`.
3. **Bash manifest-discovery code** — The actual runtime mechanism that reads `manifest.json` dynamically.

This research confirms that:
- **8 extensions have skills but no routing section** (silent fallback to generic agents).
- **5 extensions have routing sections** (founder, lean, nvim, present, typst).
- **1 extension has orphaned routing entries** pointing to non-existent skills (`present` extension → `skill-planner`, `skill-grant:assemble`, `skill-slides:assemble`).
- **3 command docs contain hardcoded routing tables** that are documentation-only and redundant with the bash discovery code.
- **Anti-Bypass constraints list skills by hand** — 3 command docs enumerate 8–11 specific skill names each.
- **`.claude/commands/` mirrors are divergent/legacy** — They use old paths (`.claude/extensions/`), lack manifest-discovery improvements, and have shorter Anti-Bypass skill lists.

**Key finding**: The bash manifest-discovery code is the *only* runtime routing mechanism. The markdown tables are pure documentation that creates maintenance burden. Removing them and making `manifest.json` the sole source of truth is safe and correct.

---

## 1. Extension Manifest Audit

### 1.1 Complete Extension Inventory (16 extensions)

| # | Extension | `language` | `routing_exempt` | Skills Count | Has Routing | Routing Commands |
|---|-----------|-----------|------------------|--------------|-------------|------------------|
| 1 | `core` | — | `true` | 17 | ❌ (exempt) | — |
| 2 | `epidemiology` | `epidemiology` | — | 2 | ❌ | — |
| 3 | `filetypes` | `null` | — | 4 | ❌ | — |
| 4 | `formal` | `formal` | — | 4 | ❌ | — |
| 5 | `founder` | `founder` | — | 15 | ✅ | research, plan, implement |
| 6 | `latex` | `latex` | — | 2 | ❌ | — |
| 7 | `lean` | `lean4` | — | 4 | ✅ | research, implement |
| 8 | `memory` | `null` | — | 1 | ❌ | — |
| 9 | `nix` | `nix` | — | 2 | ❌ | — |
| 10 | `nvim` | `neovim` | — | 2 | ✅ | research, implement |
| 11 | `present` | `present` | — | 7 | ✅ | research, plan, implement, critique |
| 12 | `python` | `python` | — | 2 | ❌ | — |
| 13 | `slidev` | — | — | 0 | ❌ | — |
| 14 | `typst` | `typst` | — | 2 | ✅ | research, implement |
| 15 | `web` | `web` | — | 3 | ❌ | — |
| 16 | `z3` | `z3` | — | 2 | ❌ | — |

### 1.2 Extensions Missing Routing (8 extensions)

These extensions declare skills in `provides.skills` but have **no `routing` section**. When `/research`, `/plan`, or `/implement` is invoked for tasks with matching `task_type`, they silently fall back to generic agents (`skill-researcher`, `skill-planner`, `skill-implementer`).

| Extension | Language | Skills | Missing For |
|-----------|----------|--------|-------------|
| `epidemiology` | `epidemiology` | skill-epidemiology-research, skill-epidemiology-implementation | research, implement |
| `filetypes` | `null` | skill-filetypes, skill-spreadsheet, skill-presentation, skill-deck | research, plan, implement |
| `formal` | `formal` | skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research | research |
| `latex` | `latex` | skill-latex-research, skill-latex-implementation | research, implement |
| `nix` | `nix` | skill-nix-research, skill-nix-implementation | research, implement |
| `python` | `python` | skill-python-research, skill-python-implementation | research, implement |
| `web` | `web` | skill-web-research, skill-web-implementation, skill-tag | research, implement |
| `z3` | `z3` | skill-z3-research, skill-z3-implementation | research, implement |

**Note on `filetypes`**: This extension has `language: null` and provides 4 skills. Its commands (`convert.md`, `table.md`, `slides.md`, `deck.md`) are direct commands, not routed via `/research|plan|implement`. However, if tasks are tagged with `task_type: filetypes`, routing would be useful.

**Note on `formal`**: Has 4 research skills but no routing. A single `formal` → `skill-formal-research` default makes sense, with compound keys (`formal:logic`, `formal:math`, `formal:physics`) for specialization.

### 1.3 Extensions With Routing (5 extensions)

| Extension | Routing Coverage | Routing Entries | Status |
|-----------|-----------------|-----------------|--------|
| `lean` | research, implement | `lean`→skill-lean-research, `lean4`→skill-lean-research, `lean`→skill-lean-implementation, `lean4`→skill-lean-implementation | ✅ Valid |
| `nvim` | research, implement | `neovim`→skill-neovim-research, `neovim`→skill-neovim-implementation | ✅ Valid |
| `typst` | research, implement | `typst`→skill-typst-research, `typst`→skill-typst-implementation | ✅ Valid |
| `founder` | research, plan, implement | 33 entries covering `founder`, `founder:market`, `founder:analyze`, … `founder:consult` | ✅ Valid |
| `present` | research, plan, implement, critique | 17 entries | ⚠️ **Has orphans** |

### 1.4 Orphaned Routing Entries

The `present` extension has **7 orphaned routing entries** pointing to skills that do not exist in its `skills/` directory:

| Routing Key | Task Type | Skill Referenced | Problem |
|-------------|-----------|------------------|---------|
| `present.routing.plan.present` | `present` | `skill-planner` | Not in present/skills/ (it's in core) |
| `present.routing.plan.present:budget` | `present:budget` | `skill-planner` | Not in present/skills/ |
| `present.routing.plan.present:funds` | `present:funds` | `skill-planner` | Not in present/skills/ |
| `present.routing.plan.present:grant` | `present:grant` | `skill-planner` | Not in present/skills/ |
| `present.routing.plan.present:timeline` | `present:timeline` | `skill-planner` | Not in present/skills/ |
| `present.routing.implement.present:grant` | `present:grant` | `skill-grant:assemble` | Not in present/skills/ (colon suffix?) |
| `present.routing.implement.present:slides` | `present:slides` | `skill-slides:assemble` | Not in present/skills/ (colon suffix?) |

**Analysis**:
- `skill-planner` is a **core skill** (in `core/skills/skill-planner/`). The present extension's plan routing for `present` and `present:*` keys defaults to `skill-planner`. This is technically a valid fallback, but it violates the "routing entry must point to a skill in the same manifest" principle. If cross-extension routing is allowed, this needs to be documented. If not, these entries should be removed and the fallback logic in commands should handle them.
- `skill-grant:assemble` and `skill-slides:assemble` appear to be **sub-mode references** (skill name + colon + mode). No skill directory uses this naming convention. These are broken.

### 1.5 Extensions Without Skills (no routing needed)

| Extension | Note |
|-----------|------|
| `slidev` | Dependency-only extension. Provides context (`project/slidev`) but zero skills/agents. No routing needed. |
| `memory` | Utility extension. `skill-memory` is invoked directly by `/learn` and `/distill` commands, not by `/research|plan|implement`. No routing needed. |
| `core` | `routing_exempt: true`. Base agents/skills are always available. |

---

## 2. Command Doc Audit

### 2.1 Files With Hardcoded Routing Tables

Only **3 command docs** contain "Extension-Based Routing Table" sections:

| Command Doc | Line # | Table Entries |
|-------------|--------|---------------|
| `.opencode/commands/implement.md` | 419 | 11 rows |
| `.opencode/commands/research.md` | 380 | 12 rows |
| `.opencode/commands/plan.md` | 384 | 11 rows |

### 2.2 Current Command Doc Structure

Each of the 3 command docs follows this pattern:

1. **Header** (YAML frontmatter with `description`, `allowed-tools`, `argument-hint`)
2. **Command execution mode banner**
3. **Arguments / Options** tables
4. **Anti-Bypass Constraint** (lists specific skills by name)
5. **Execution** → STAGE 0: Parse task numbers
6. **Multi-task dispatch** (batch logic)
7. **CHECKPOINT 1: GATE IN**
8. **STAGE 1.5: PARSE FLAGS**
9. **STAGE 2: DELEGATE** → Contains:
   - Team mode routing logic
   **- Bash manifest-discovery code (the real runtime mechanism)**
   **- "Extension-Based Routing Table" markdown table (documentation-only)**
   - Skill selection logic
   - Skill invocation templates
10. **CHECKPOINT 2: GATE OUT**
11. **CHECKPOINT 3: COMMIT**
12. **Output / Error Handling**

### 2.3 Bash Manifest-Discovery Code (The Real Mechanism)

All 3 command docs contain near-identical bash code that:

1. Derives `project_root` via `git rev-parse --show-toplevel`
2. Sets `manifest_dir="$project_root/.opencode/extensions"`
3. Loops over `*/manifest.json` files
4. Runs `jq '.routing.{command}[$task_type] // empty'` to find the matching skill
5. Falls back to base type (split on `:`) if compound key not found
6. Warns if no manifests found
7. Falls back to default skill (`skill-implementer`, `skill-researcher`, `skill-planner`)

This code is **authoritative at runtime**. The markdown tables are never parsed by any tool.

### 2.4 Can the Tables Be Removed Without Breaking Functionality?

**Yes, absolutely.**

Evidence:
- The bash discovery code runs independently of the markdown tables.
- No script or tool parses the markdown tables during command execution.
- The validation script (`validate-routing-tables.sh`) compares manifest entries against command doc table entries, but this is a *consistency check*, not a functional dependency.
- The `.claude/commands/` mirror files have **even shorter** Anti-Bypass skill lists and no manifest-discovery improvements, yet the system still functions (the `.opencode/commands/` files are the ones actually loaded).

**Conclusion**: The tables are documentation debt. Removing them eliminates a source of drift with zero functional impact.

### 2.5 Should There Be a Single Auto-Generated Routing Reference?

**Recommendation**: Not in the command docs.

Options evaluated:

| Option | Pros | Cons |
|--------|------|------|
| A. Keep hardcoded tables in command docs | Human-readable during command execution | Drift, maintenance burden, already proven to fail (Task 538 found 48 discrepancies) |
| B. Remove tables entirely from command docs | Zero maintenance, single source of truth | Less convenient for humans reading the doc |
| C. Auto-generate `.opencode/context/routing-index.md` | Single reference doc, can be updated by CI | Adds build step, may still drift if CI breaks |
| D. Generate tables into command docs at load time | Tables stay in docs, always fresh | Complex, requires preprocessor, overkill |

**Recommended approach**: **B** for now, with **C** as a future optional enhancement. The bash discovery code is self-documenting enough for agents. A standalone `routing-index.md` reference file could be generated by a script for human convenience, but it's not required for the routing system to work.

---

## 3. Anti-Bypass Constraint Patterns

### 3.1 Current Anti-Bypass Skill Lists

Three command docs enumerate specific skills by name in their Anti-Bypass constraints:

**implement.md** (line 42):
> `skill-implementer, skill-lean-implementation, skill-neovim-implementation, skill-nix-implementation, skill-typst-implementation, skill-founder-implement, skill-deck-implement, or skill-team-implement`

**research.md** (line 48):
> `skill-researcher, skill-lean-research, skill-neovim-research, skill-nix-research, skill-typst-research, skill-market, skill-analyze, skill-strategy, skill-deck-research, or skill-team-research`

**plan.md** (line 44):
> `skill-planner, skill-founder-plan, skill-deck-plan, skill-slide-planning, or skill-team-plan`

### 3.2 Problems with Hand-Listed Skills

1. **Incomplete**: The lists miss skills for `epidemiology`, `formal`, `latex`, `python`, `z3`, `web`, `filetypes` — because those extensions currently have no routing (so they fall back to generic agents). Once routing is added, the lists will be wrong.
2. **Rot-prone**: Every new extension requires updating 3 command docs.
3. **Redundant**: The manifest-discovery code already determines the correct skill at runtime.

### 3.3 Generalized Anti-Bypass Formulation

Replace the enumerated lists with a manifest-discovery reference:

> **PROHIBITION**: You MUST NOT write {artifact-type} artifacts directly using Write or Edit tools. All {artifact-type} files MUST be created by invoking the appropriate skill via the Skill tool. The correct skill is determined by manifest discovery in `.opencode/extensions/*/manifest.json` — query `.routing.{command}[<task_type>]` from the matching extension manifest, falling back to the default skill (`skill-{command}er` or `skill-team-{command}`) if no extension match is found.

This formulation:
- References **no hardcoded skill names**.
- Points to the **manifest as the source of truth**.
- Is **future-proof** — new extensions automatically work.
- Can be **identical across all 3 command docs** except for the artifact type and default skill name.

---

## 4. `.claude/` Mirror Audit

### 4.1 Mirror Status

The `.claude/commands/` directory contains files with the same names as `.opencode/commands/`, but they are **divergent and legacy**:

| Aspect | `.opencode/commands/` | `.claude/commands/` |
|--------|----------------------|---------------------|
| Manifest discovery path | `$project_root/.opencode/extensions` | `.claude/extensions` (relative, no `$project_root`) |
| Manifest count warning | Yes (`manifest_count`) | No |
| Compound key fallback | Yes (split on `:`, re-loop) | No |
| Anti-Bypass skill lists | Long, specific | Short, generic (e.g., only `skill-implementer or skill-team-implement`) |
| Execution mode banner | Present | Absent |
| Environment variable | `OPENCODE_EXPERIMENTAL_AGENT_TEAMS` | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` |
| YAML frontmatter | Same | Same + `model: opus` line |

### 4.2 Propagation Question

**Are `.claude/commands/` auto-generated or manual?**

- The `.claude/commands/` files appear to be **manual copies** from an earlier version of the system.
- They lack the manifest-discovery improvements added in Tasks 537 and 538.
- They use the old `.claude/extensions/` path structure.
- **Changes to `.opencode/commands/` will NOT propagate** automatically.

**Recommendation**: The `.claude/commands/` directory should be deprecated or removed as part of the migration to the OpenCode namespace. If it must be kept, it should be auto-generated from `.opencode/commands/` via a sync script, or symlinked. This is out of scope for Task 539 but should be noted as technical debt.

---

## 5. Validation Script Analysis

### 5.1 Current Script Behavior

`.opencode/scripts/validate-routing-tables.sh`:

1. Extracts all `routing.*.*` entries from all `manifest.json` files.
2. Extracts all table rows from the "Extension-Based Routing Table" sections in `implement.md`, `research.md`, `plan.md`.
3. Reports **MISSING** entries: manifest has routing, but command doc table lacks it.
4. Reports **ORPHAN** entries: command doc table has entry, but no manifest declares it.
5. Skips generic fallbacks (`general`, `meta`, `founder:{sub-type}`, etc.).

### 5.2 Why the Script Found Discrepancies

The script found 48 discrepancies because:
- 8 extensions have skills but **no routing section** → command docs had no table entries for them (or had stale ones).
- The `present` extension has **orphaned entries** pointing to `skill-planner` and `skill-*:assemble` → not in manifests.
- Command docs had **manually added** entries for some extensions that were never added to manifests.

### 5.3 What the Script Should Do After Task 539

Once hardcoded tables are removed, the validation script should be **retargeted**:

1. **Skill Coverage Check**: Every skill in `provides.skills` must have at least one `routing` entry (unless `routing_exempt: true` or utility extension).
2. **Routing Integrity Check**: Every `routing.*.*` entry must point to a skill that exists in the same extension's `skills/` directory (or explicitly documented cross-extension routing).
3. **No Hardcoded Tables Check**: Grep command docs for "Extension-Based Routing Table" — fail if found.
4. **Manifest Validity**: All `manifest.json` files must be valid JSON.
5. **Remove** the old manifest-vs-command-doc comparison logic.

---

## 6. Recommendations for Implementation Phase

### 6.1 Phase 1: Add Missing Routing to Manifests (8 files)

For each extension in Section 1.2, add a `routing` object mapping the extension's `language` to the appropriate skill.

**Example template** (for `latex`):
```json
"routing": {
  "research": {
    "latex": "skill-latex-research"
  },
  "implement": {
    "latex": "skill-latex-implementation"
  }
}
```

**Special cases**:
- `formal`: Should map `formal` → `skill-formal-research` for research. Could add compound keys (`formal:logic` → `skill-logic-research`, etc.) for specialization.
- `filetypes`: Has `language: null`. Could map `filetypes` → `skill-filetypes` for research/implement, or leave as-is since it's command-driven.
- `web`: Has `skill-tag` which is also in core. The `skill-tag` in `web/` may be a domain-specific override. Ensure routing uses the web version if task type is `web`.

### 6.2 Phase 2: Fix Present Extension Orphans (1 file)

In `.opencode/extensions/present/manifest.json`:

- **Plan routing**: Remove `present` → `skill-planner` and `present:*` → `skill-planner` entries. These should fall back to the default `skill-planner` via command doc fallback logic.
- **Implement routing**: Fix `present:grant` → `skill-grant:assemble` to `skill-grant` (verify if `skill-grant` supports assembly mode internally).
- **Implement routing**: Fix `present:slides` → `skill-slides:assemble` to `skill-slides` (same verification).
- Alternative: If `:assemble` is a real sub-mode convention, document it and ensure the skill loader supports it. Otherwise, remove the suffix.

### 6.3 Phase 3: Remove Hardcoded Tables from Command Docs (3 files)

In `.opencode/commands/implement.md`, `research.md`, `plan.md`:

1. **Remove** the entire "Extension-Based Routing Table" markdown table section (table header, separator rows, all rows, trailing paragraph).
2. **Keep** the bash manifest-discovery code block immediately preceding the table.
3. **Keep** the "Skill Selection Logic" pseudo-code block immediately following the table.
4. **Update** the "Extension Skills Location" paragraph to say:
   > Extension skills are located in `.opencode/extensions/{ext}/skills/`. OpenCode discovers these skills dynamically by reading `routing` entries from each extension's `manifest.json`.

### 6.4 Phase 4: Generalize Anti-Bypass Constraints (3 files)

Replace the enumerated skill lists with the generalized manifest-discovery formulation from Section 3.3.

### 6.5 Phase 5: Update Validation Script (1 file)

Retarget `.opencode/scripts/validate-routing-tables.sh` as described in Section 5.3.

### 6.6 Phase 6: Address `.claude/` Mirrors (decision needed)

Options:
1. **Remove** `.claude/commands/` entirely (if `.opencode/` is the sole system).
2. **Symlink** `.claude/commands/` → `.opencode/commands/` (if both must exist).
3. **Add deprecation notice** to `.claude/commands/README.md` stating these files are no longer maintained.

**Recommendation**: Option 3 for Task 539 (minimal risk), with a follow-up task to decide between 1 and 2.

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Removing tables breaks human comprehension | Low | Low | The bash code remains; add a one-line comment referencing manifest discovery. |
| Adding routing to manifests changes behavior for existing tasks | Medium | Medium | Tasks with matching `task_type` will now route to extension-specific agents instead of generic ones. This is the **intended** behavior fix. |
| Present extension `:assemble` suffix is load-bearing | Low | High | Verify present skills internally before changing routing. If broken, it's already broken (skill dirs don't exist). |
| `.claude/` mirrors cause confusion | High | Low | Add deprecation notice; out of scope for functional changes. |

---

## Appendix A: Raw Routing Entry Inventory

### Founder Extension Routing (33 entries, all valid)

```
research.founder -> skill-market
research.founder:market -> skill-market
research.founder:analyze -> skill-analyze
research.founder:strategy -> skill-strategy
research.founder:legal -> skill-legal
research.founder:project -> skill-project
research.founder:sheet -> skill-founder-spreadsheet
research.founder:finance -> skill-finance
research.founder:financial-analysis -> skill-financial-analysis
research.founder:deck -> skill-deck-research
research.founder:meeting -> skill-meeting
research.founder:consult -> skill-consult

plan.founder -> skill-founder-plan
plan.founder:market -> skill-founder-plan
plan.founder:analyze -> skill-founder-plan
plan.founder:strategy -> skill-founder-plan
plan.founder:legal -> skill-founder-plan
plan.founder:project -> skill-founder-plan
plan.founder:sheet -> skill-founder-plan
plan.founder:finance -> skill-founder-plan
plan.founder:financial-analysis -> skill-founder-plan
plan.founder:deck -> skill-deck-plan
plan.founder:meeting -> skill-founder-plan
plan.founder:consult -> skill-founder-plan

implement.founder -> skill-founder-implement
implement.founder:market -> skill-founder-implement
implement.founder:analyze -> skill-founder-implement
implement.founder:strategy -> skill-founder-implement
implement.founder:legal -> skill-founder-implement
implement.founder:project -> skill-founder-implement
implement.founder:sheet -> skill-founder-implement
implement.founder:finance -> skill-founder-implement
implement.founder:financial-analysis -> skill-founder-implement
implement.founder:deck -> skill-deck-implement
implement.founder:meeting -> skill-founder-implement
implement.founder:consult -> skill-founder-implement
```

### Present Extension Routing (17 entries, 7 orphaned)

```
research.present -> skill-grant
research.present:grant -> skill-grant
research.present:budget -> skill-budget
research.present:timeline -> skill-timeline
research.present:funds -> skill-funds
research.present:slides -> skill-slides

plan.present -> skill-planner          [ORPHAN: skill-planner not in present/skills/]
plan.present:grant -> skill-planner    [ORPHAN]
plan.present:budget -> skill-planner   [ORPHAN]
plan.present:timeline -> skill-planner [ORPHAN]
plan.present:funds -> skill-planner    [ORPHAN]
plan.present:slides -> skill-slide-planning
plan.slides -> skill-slide-planning

implement.present -> skill-grant
implement.present:grant -> skill-grant:assemble  [ORPHAN: skill-grant:assemble not found]
implement.present:budget -> skill-budget
implement.present:timeline -> skill-timeline
implement.present:funds -> skill-funds
implement.present:slides -> skill-slides:assemble [ORPHAN: skill-slides:assemble not found]

critique.present:slides -> skill-slide-critic
```

### Lean Extension Routing (4 entries, all valid)

```
research.lean -> skill-lean-research
research.lean4 -> skill-lean-research
implement.lean -> skill-lean-implementation
implement.lean4 -> skill-lean-implementation
```

### Nvim Extension Routing (2 entries, all valid)

```
research.neovim -> skill-neovim-research
implement.neovim -> skill-neovim-implementation
```

### Typst Extension Routing (2 entries, all valid)

```
research.typst -> skill-typst-research
implement.typst -> skill-typst-implementation
```

---

## Appendix B: Skills Directory Verification

All skills referenced by valid routing entries exist:

| Extension | Skill | Directory Exists |
|-----------|-------|------------------|
| core | all 17 | ✅ |
| epidemiology | skill-epidemiology-research, skill-epidemiology-implementation | ✅ |
| filetypes | skill-filetypes, skill-spreadsheet, skill-presentation, skill-deck | ✅ |
| formal | skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research | ✅ |
| founder | all 15 | ✅ |
| latex | skill-latex-research, skill-latex-implementation | ✅ |
| lean | skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version | ✅ |
| memory | skill-memory | ✅ |
| nix | skill-nix-research, skill-nix-implementation | ✅ |
| nvim | skill-neovim-research, skill-neovim-implementation | ✅ |
| present | skill-grant, skill-budget, skill-timeline, skill-funds, skill-slides, skill-slide-planning, skill-slide-critic | ✅ |
| python | skill-python-research, skill-python-implementation | ✅ |
| typst | skill-typst-research, skill-typst-implementation | ✅ |
| web | skill-web-research, skill-web-implementation, skill-tag | ✅ |
| z3 | skill-z3-research, skill-z3-implementation | ✅ |

---

*End of Research Report*
