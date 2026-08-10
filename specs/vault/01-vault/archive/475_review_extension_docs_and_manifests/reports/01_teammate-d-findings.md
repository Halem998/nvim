# Teammate D Findings: Strategic Horizons — Task 475

## Key Findings

### 1. Routing_Exempt Flag Scope Is Narrower Than Task Description Implies

The task description says `routing_exempt` should "avoid loading any files that should not be
loaded by the `<leader>ac` picker in neovim." This framing is misleading based on actual code.

`routing_exempt` is **only used in `check-extension-docs.sh`** to skip the routing block
validation check for extensions like `core` that intentionally have no routing block. It has no
effect on the Neovim extension picker (`<leader>ac`). The picker (`shared/extensions/manifest.lua`
`list_extensions()`) lists all subdirectories with valid `manifest.json` — no filtering by any
flag occurs.

This is not a bug but a misstatement in the task description. The `routing_exempt` flag already
has the correct narrow purpose: validator exemption. Expanding it to filter the picker would be a
scope expansion with its own implications (e.g., the `core` extension would then be hidden from
the picker, which may or may not be desirable — currently it can be loaded/unloaded for migration
purposes).

**Strategic implication**: The implementation team should clarify what `routing_exempt` is
actually for in the extension-development.md guide, rather than trying to make it do picker
filtering. If picker filtering is truly wanted (e.g., to hide `core` from the picker), that is a
separate feature with a clearer name like `picker_hidden: true`.

### 2. Only One Active Lint Failure: founder/README.md Missing `/consult`

Running `check-extension-docs.sh` shows **one failure**: `founder` extension has a `consult.md`
command in its manifest but `/consult` is not mentioned in `README.md`. This is a drift issue —
`consult.md` was added after the README was last updated. This is the only actionable lint
failure in the current state.

All 16 extensions have README.md and manifest.json. The `slidev` resource-only extension (no
task_type, no routing) correctly passes validation.

### 3. The Roadmap's Most Relevant Phase-1 Items Are Directly Actionable

The roadmap's Phase 1 documentation items are well-scoped and this task can directly advance
them:

| Roadmap Item | How Task 475 Advances It |
|---|---|
| Manifest-driven README generation | Could prototype `generate-extension-readme.sh` |
| CI enforcement of doc-lint | `check-extension-docs.sh` already exists; just needs GH Actions YAML |
| Extension slim standard enforcement | Could add routing_exempt lint to the existing script |
| Agent frontmatter validation | Script already validates agents; could add frontmatter check |

### 4. Strategic Gap: `routing_exempt` Not Documented in Extension Development Guide

`extension-development.md` documents the manifest format with a table of fields but **does not
include `routing_exempt`**. This creates a "shadow standard" — new extension authors won't know
it exists or when to use it. The field was added in task 474 without updating the guide.

This is the most important documentation gap: the guide that future extension authors read has no
knowledge of a flag that already affects the validator they will encounter.

### 5. EXTENSION.md Slim Standard Is Not Being Enforced — And Two Extensions Already Violate It

`docs/reference/standards/extension-slim-standard.md` defines a 60-line maximum for
EXTENSION.md files. Current sizes range from 12 to 64 lines. **Two extensions currently exceed
the limit**:

| Extension | EXTENSION.md Lines | Over Limit By |
|-----------|-------------------|---------------|
| `nix` | 62 | 2 |
| `present` | 64 | 4 |

Additional issues:
- The slim standard itself is not validated by `check-extension-docs.sh`
- No mention of the standard appears in the extension development guide
- Existing tools and checks don't enforce it

This is a "documented but orphaned" standard — it exists in docs but has no enforcement pathway.
Both violations are minor (2-4 lines over) and fixable with minimal content trimming.

### 6. `marketplace.json` Roadmap Item Has No Groundwork Yet

The roadmap calls for adding `marketplace.json` to each extension. No extension has this file
yet. This task could either:
- Lay the groundwork (add a note in the template, document the schema)
- Skip it (it's a Phase 1 item but orthogonal to doc review)

The risk of laying groundwork now without a clear schema is creating partial or inconsistent
files. Better to address it as a dedicated task after the schema is defined.

---

## Roadmap Alignment Assessment

**High alignment.** Task 475 directly advances the roadmap's "Documentation Infrastructure"
cluster:

- The doc-lint script already exists — the remaining gap is CI integration and lint completeness
- The extension README template is finalized (from task 474) — consistency review now is timely
- The `routing_exempt` gap in `extension-development.md` is a near-term risk (next extension
  author will be confused)

The task is well-timed: the ecosystem has stabilized (16 extensions, all with READMEs), making
a consistency sweep highly effective now before more extensions are added.

**Adjacent roadmap advancement**: Task 475 could simultaneously:
1. Add `routing_exempt` documentation to `extension-development.md`
2. Add EXTENSION.md size validation to `check-extension-docs.sh`
3. Fix the founder README drift (the only current lint failure)
4. Document `slidev` pattern for resource-only extensions more explicitly

---

## Adjacent Opportunities

### A. Harden `check-extension-docs.sh` (High Value, Low Cost)

The script currently validates:
- File presence (README, EXTENSION.md, manifest.json)
- Manifest entry-to-file references
- Routing block presence for extensions with skills
- README mentions all manifest commands

Missing validations that would catch future drift:
- **EXTENSION.md size**: Warn if > 60 lines (enforces slim standard)
- **routing_exempt documentation**: Validate it's only used on extensions without task_type
- **Agent frontmatter fields**: Check that agents have `name` and `description` (Phase 1 roadmap)
- **Marketplace.json**: Could add future check once schema defined

Adding these would make the script more defensive without significant complexity.

### B. Update extension-development.md (High Value, Low Cost)

Add `routing_exempt` to the manifest field table, with explanation of when to use it. This is a
one-paragraph addition that prevents future confusion.

### C. Prototype generate-extension-readme.sh (Medium Value, Medium Cost)

The roadmap calls for this. Given that:
- The template exists at `templates/extension-readme-template.md`
- All manifests are structured JSON
- The section applicability matrix is in the template comments

A script that reads `manifest.json` and generates a starter README with pre-filled tables would
reduce the cost of adding new extensions. However, this is a prototype effort (not 100%
automation) — the output would still need human editing. This is at the boundary of task 475's
scope.

### D. GitHub Actions CI Integration (Low Cost, High Leverage)

The roadmap explicitly calls for CI enforcement of doc-lint. Adding a workflow that runs
`check-extension-docs.sh` on every push is a 10-line YAML file. This task is the natural
moment to add it since we're already reviewing docs and hardening the script.

However, this adds a file outside `.claude/` (at `.github/workflows/`), which may be out of
scope for a docs-review task. Worth flagging to the implementation team.

---

## Creative/Unconventional Approaches

### Auto-Generate README Sections from Manifest Data

Instead of manually reviewing each README for completeness, a script could:
1. Parse each extension's `manifest.json`
2. Generate expected README section headers and table entries
3. Diff against actual README to find gaps

This "expected vs actual" diff approach catches drift mechanically. For example:
- If manifest has 10 commands, README should have 10 `/cmd` references → auto-checkable
- If manifest declares `mcp_servers`, README should have a "MCP Tool Setup" section → auto-checkable
- If extension has `rules[]`, README should have a "Rules Applied" section → auto-checkable

This is more sophisticated than `check-extension-docs.sh` today but builds on the same pattern.
It could be a future enhancement to the script.

### Cross-Extension Consistency Scoring

Rather than binary pass/fail, a scoring script could rate each extension:
- Does it have all required sections for its complexity tier?
- Are section names consistent with the template?
- Are table formats uniform?

This would produce a "quality score" per extension and highlight the ones needing most work —
more actionable than a simple lint pass/fail.

---

## Strategic Recommendations

### Priority 1 (Must Do in This Task)

1. **Fix founder README** — Add `/consult` to the commands table. This is the only active lint
   failure. Fix it immediately so `check-extension-docs.sh` exits 0.

2. **Document `routing_exempt` in extension-development.md** — Add to the manifest field table
   with a note: "Use when extension intentionally omits a routing block (e.g., resource-only
   extensions or the core system extension)."

3. **Clarify `routing_exempt` scope in task description** — The implementation team should
   understand this flag is for validator exemption, not picker filtering. If picker filtering is
   wanted, it's a separate feature.

### Priority 2 (High Value, Fits in This Task)

4. **Consistency review against template** — Sweep all 16 README files for missing required
   sections. Focus on complex extensions (founder 408 lines, memory 291 lines, filetypes 225
   lines, lean 192 lines) — simple extensions (latex, typst, z3, python, ~57-59 lines) already
   look well-structured.

5. **Add `routing_exempt: true` to `slidev` manifest** — `slidev` is a resource-only extension
   with no `task_type` and no routing. It passes validation today (no routing block check triggers
   because it has no skills either). But it is semantically identical to `core` and should carry
   the same annotation. Adding `routing_exempt: true` documents intent and ensures consistent
   treatment of all infrastructure-only extensions. Then document this pattern explicitly in
   `extension-development.md` for future resource-only extension authors.

### Priority 3 (Could Expand Scope if Time Allows)

6. **Add EXTENSION.md size check to `check-extension-docs.sh`** — Enforces the slim standard
   without requiring humans to remember it. Simultaneously trim `nix` and `present` by 2-4 lines
   to bring them into compliance.

7. **Prototype generate-extension-readme.sh** — Aligns with roadmap's Phase 1 item. Even a
   partial prototype (just filling in the Overview and Skill-Agent Mapping tables from manifest
   data) would be valuable.

8. **GitHub Actions CI YAML** — If the team decides to add it, now is the right moment.

---

## Confidence Level

**High** for findings 1-5 (direct code reading, lint script execution, manifest inspection).

**Medium** for strategic recommendations 6-8 (scope judgment calls; depends on team bandwidth
and task scoping decisions made by the lead).

The `routing_exempt`/picker scope question (finding 1) is the most important ambiguity to resolve
before implementation begins, as it affects whether additional manifest changes are needed.
