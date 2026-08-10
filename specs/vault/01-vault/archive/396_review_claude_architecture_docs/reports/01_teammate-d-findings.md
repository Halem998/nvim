# Research Report: Task #396 — Teammate D (Horizons)

**Task**: 396 - Review .claude/ architecture and update all relevant documentation
**Role**: Teammate D — HORIZONS (long-term alignment and strategic direction)
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:30:00Z
**Effort**: Medium (strategic analysis)

---

## Roadmap Context

The project ROADMAP.md currently contains no items — it is a blank slate with placeholder text ("No items yet"). This is actually significant: task 396 is being executed into a documentation vacuum, which means it has an opportunity to establish direction rather than just fill gaps.

Recent git history reveals a period of intense architectural consolidation:
- **Tasks 390-395**: Focused on extension standardization (slim-down standard, OpenCode mirroring, schema enforcement, ROADMAP.md creation)
- **Task 393**: Major 6-phase refactor establishing the current architecture (commands, skills, agents, context system)
- **Task 392**: Present extension standardization (the `present/README.md` that is now the reference model)

The system has grown substantially: 14 extensions, 7+ core agents, 15+ commands. The architecture is maturing. The documentation layer is lagging behind.

---

## Strategic Alignment Analysis

### The Tactical Request vs. The Strategic Opportunity

The stated tactical request is: "Create `filetypes/README.md` following `present/README.md`."

This is correct and necessary. But examined strategically, the real problem is:

> **11 out of 14 extensions lack a README.md.** Only `present`, `founder`, and `memory` have them.

Extensions without README.md:
- epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3

This is not a one-off gap — it is a systemic documentation deficit. The tactical framing (create one README) understates the scope of what would genuinely serve the project.

### The EXTENSION.md / README.md Architecture Tension

There is currently a meaningful architectural split between two document types:

| Document | Purpose | Audience | Size Limit |
|----------|---------|----------|------------|
| `EXTENSION.md` | Runtime routing data injected into CLAUDE.md context | Agents (read at load time) | 60 lines (enforced) |
| `README.md` | Human-readable extension documentation | Developers, users | No limit |

The `extension-slim-standard.md` (recently formalized) explicitly moves rich documentation OUT of EXTENSION.md and INTO context files. README.md is the natural destination for the human-readable layer of that moved content. This makes README.md creation a natural completion of the slim-down work.

**Key insight**: Every extension that was slimmed-down per the standard created a documentation hole. README.md fills that hole.

### Single-Source-of-Truth Analysis

Currently there are at least 4 places where extension information is recorded:
1. `manifest.json` — machine-readable metadata (name, version, provides, routing)
2. `EXTENSION.md` — runtime context snippet (routing + commands)
3. `README.md` — human documentation (3 of 14 have this)
4. `CLAUDE.md` top-level — references extensions generally

This creates drift risk. When an extension gains a new command, at minimum manifest.json, EXTENSION.md, and README.md need updating.

---

## Creative / Unconventional Approaches

### 1. Manifest-Driven README Generation

**Concept**: Generate README.md mechanically from manifest.json + EXTENSION.md.

manifest.json already contains: name, version, description, provides (agents, skills, commands), routing table.
EXTENSION.md already contains: skill-agent mapping table, command table (in standardized format).

A generation script could:
1. Read manifest.json for metadata
2. Parse EXTENSION.md for the two tables
3. Expand commands into usage examples (from command files)
4. Write a standardized README.md

**Strategic value**: Eliminates drift entirely. README becomes a derived artifact, not an authored one. Future extensions automatically get documentation.

**Implementation cost**: Medium. Requires a template system and command-file parsing.

### 2. Doc-Lint Script for Drift Detection

**Concept**: A `.claude/scripts/check-extension-docs.sh` that flags:
- Extensions missing README.md
- README.md command sections out of sync with manifest.json `provides.commands`
- EXTENSION.md command count mismatching manifest count

**Strategic value**: Low ongoing maintenance cost for high documentation quality. Could run as a pre-commit hook or `/review` sub-check.

**Implementation cost**: Low. Pure shell/jq.

### 3. Skills Marketplace Framing

**Concept**: Treat extensions as "skill packages" with standardized metadata beyond the current manifest schema. Add to manifest.json:
- `use_cases`: Array of user-facing use cases ("I want to write a grant proposal")
- `prerequisites`: What the user needs installed
- `maturity`: `stable | beta | experimental`
- `load_hint`: When to suggest loading this extension

This would allow the `<leader>ac` picker to show richer information, and would enable a "recommend extensions" feature based on the current task type.

**Strategic value**: Transforms the extension system from a technical loader into a user-navigable capability catalog.

**Implementation cost**: Medium. Schema change + picker update.

### 4. README as Thin Pointers, Context as Canonical Layer

**Concept** (inverse of current pattern): Instead of writing rich README.md files, use README.md as a 10-line pointer document that says "See context/project/{ext}/domain/ for documentation." The context files become canonical, and README.md is just a navigation aid.

**Assessment**: This is elegant but reduces discoverability for human users who don't know the context system. Not recommended as primary strategy, but context files should be linked from README.md.

### 5. Extension Authoring Guide as Primary Output

**Concept**: The most strategic output of task 396 is not N README files — it's a definitive "how to create a new extension" guide that synthesizes the current standards (manifest.json schema, EXTENSION.md slim standard, README.md template, index-entries.json format) into a single guided workflow.

Currently `creating-extensions.md` exists but may not fully reflect the current standards. A comprehensive update to that guide, plus a README template, would scale beyond task 396.

---

## Adjacent Opportunities

### 1. README Template for Extensions

Create `.claude/templates/extension-readme-template.md` based on `present/README.md`. This makes all future extension READMEs consistent and reduces the cost of creating them.

### 2. Context Documentation Audit

Several extensions (formal, z3, lean) deal with complex domains. Their context files may have drifted from the current context architecture (`domain/`, `patterns/`, `tools/` structure). A brief audit during README creation would catch these.

### 3. Extension Index / Capability Matrix

A single `extensions/README.md` (at the extensions directory level) listing all 14 extensions with their descriptions, task types, and key commands would serve as a capability index. Currently there is no such overview document.

### 4. Completing the Slim-Down Standard Migration

The `extension-slim-standard.md` targets ~68% reduction in total EXTENSION.md size (from ~1,111 lines to ~350 lines). It's unclear how many extensions have completed this migration. Task 396 could audit completion status and flag remaining work.

### 5. ROADMAP.md Population

Since the ROADMAP.md is empty, task 396's completion could naturally include populating it with the documentation health items this task reveals. This establishes a documentation-as-infrastructure roadmap item set.

---

## Recommended Strategic Framing

The tactical request (create `filetypes/README.md`) is a valid immediate deliverable. But the strategic version of this task is:

> **Establish documentation standards and templates so that the extension system is self-documenting going forward.**

Concretely, this means:

1. **Immediate**: Create `filetypes/README.md` following `present/README.md` pattern
2. **Systematic**: Create README.md for all 11 missing extensions (or identify which ones are lowest priority)
3. **Template**: Create `.claude/templates/extension-readme-template.md` to prevent future gaps
4. **Tooling**: Create a doc-lint script that flags missing or stale documentation
5. **Guide Update**: Update `creating-extensions.md` to require README.md as a standard deliverable

This reframes the task from "documentation cleanup" to "documentation infrastructure" — a different category of work with compounding returns.

### Priority Ordering

If only subset of work can be done:

| Priority | Work Item | Strategic Value | Cost |
|----------|-----------|-----------------|------|
| 1 | `filetypes/README.md` | Directly requested, unblocks users | Low |
| 2 | README template | Prevents all future gaps | Very low |
| 3 | README for high-traffic extensions (nvim, python, latex, lean) | Most likely to be referenced | Medium |
| 4 | Doc-lint script | Ongoing quality assurance | Low |
| 5 | Update `creating-extensions.md` | Future extension authoring | Low |
| 6 | README for remaining 7 extensions | Complete coverage | Medium |
| 7 | Manifest-driven generation script | Eliminates drift | High |

---

## Confidence Level

**High** on:
- The 11-extension README gap is real and the data is confirmed
- The EXTENSION.md / README.md tension is an architectural fact
- The strategic reframing (documentation infrastructure) is sound

**Medium** on:
- Whether manifest-driven generation is the right investment at this stage (depends on extension growth trajectory)
- Whether the slim-down standard migration is complete across all extensions

**Low on**:
- Which extensions are highest priority for README creation beyond filetypes (depends on user activity, which is not visible in git history)

---

## Appendix: Data Points

### Extensions with README.md
- `present/README.md` — 86 lines (reference model, command-focused)
- `founder/README.md` — 389 lines (comprehensive, includes examples)
- `memory/README.md` — 288 lines (two-command focus, very clear UX)

### Extensions without README.md
epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3

### Key Standards Files Consulted
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/extension-slim-standard.md`
- `/home/benjamin/.config/nvim/.claude/docs/guides/creating-extensions.md`
- `/home/benjamin/.config/nvim/.claude/extensions/present/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/filetypes/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/filetypes/EXTENSION.md`
