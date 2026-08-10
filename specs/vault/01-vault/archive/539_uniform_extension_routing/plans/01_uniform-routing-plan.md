# Implementation Plan: Uniform Extension Routing (Task 539)

**Artifact**: 01
**Status**: `[COMPLETED]`
**Date**: 2026-05-07
**Agent**: planner-agent

---

## Guiding Principle

> **One source of truth: `manifest.json`. Zero hardcoding. Consistent behavior.**

---

## Pre-Implementation Checklist

- [ ] Read research report: `specs/539_uniform_extension_routing/reports/01_uniform-routing-research.md`
- [ ] Verify all 16 extension manifests are readable and valid JSON
- [ ] Confirm bash manifest-discovery code is identical across `implement.md`, `research.md`, `plan.md`
- [ ] Run current validation script to capture baseline errors (expected: 48 discrepancies)

---

## Phase 1: Add Missing Routing Sections to 8 Extension Manifests

**Goal**: Every extension that provides skills must declare how those skills are reached via `/research`, `/plan`, and `/implement`.

**Files to modify** (8 manifests):

| # | File | Language | Skills to Route |
|---|------|----------|-----------------|
| 1 | `.opencode/extensions/epidemiology/manifest.json` | `epidemiology` | research → skill-epidemiology-research, implement → skill-epidemiology-implementation |
| 2 | `.opencode/extensions/filetypes/manifest.json` | `filetypes` | research → skill-filetypes, implement → skill-filetypes |
| 3 | `.opencode/extensions/formal/manifest.json` | `formal` | research → skill-formal-research; compound keys: formal:logic → skill-logic-research, formal:math → skill-math-research, formal:physics → skill-physics-research |
| 4 | `.opencode/extensions/latex/manifest.json` | `latex` | research → skill-latex-research, implement → skill-latex-implementation |
| 5 | `.opencode/extensions/nix/manifest.json` | `nix` | research → skill-nix-research, implement → skill-nix-implementation |
| 6 | `.opencode/extensions/python/manifest.json` | `python` | research → skill-python-research, implement → skill-python-implementation |
| 7 | `.opencode/extensions/web/manifest.json` | `web` | research → skill-web-research, implement → skill-web-implementation |
| 8 | `.opencode/extensions/z3/manifest.json` | `z3` | research → skill-z3-research, implement → skill-z3-implementation |

**Insertion point**: Add a `"routing"` object immediately before `"merge_targets"` in each manifest.

**Template** (e.g., `latex`):
```json
  "routing": {
    "research": {
      "latex": "skill-latex-research"
    },
    "implement": {
      "latex": "skill-latex-implementation"
    }
  },
```

**Special case — `formal`**:
```json
  "routing": {
    "research": {
      "formal": "skill-formal-research",
      "formal:logic": "skill-logic-research",
      "formal:math": "skill-math-research",
      "formal:physics": "skill-physics-research"
    }
  }
```

**Special case — `filetypes`**:
`filetypes` has `language: null`. Use `"filetypes"` as the routing key since that is the extension name and the de-facto task type.
```json
  "routing": {
    "research": {
      "filetypes": "skill-filetypes"
    },
    "implement": {
      "filetypes": "skill-filetypes"
    }
  }
```

**Validation after Phase 1**:
- Run `jq empty` on each modified manifest to confirm valid JSON.
- Run current `validate-routing-tables.sh` and note that missing-entry count should drop from 48 to roughly the orphaned present entries.

---

## Phase 2: Fix Orphaned Entries in Present Manifest

**Goal**: Remove routing entries that point to skills outside the present extension or use non-existent `:assemble` suffixes.

**File**: `.opencode/extensions/present/manifest.json`

**Changes**:

1. **In `plan` routing** — Remove all entries that point to `skill-planner` (a core skill, not in present/skills/):
   - Remove `"present": "skill-planner"`
   - Remove `"present:grant": "skill-planner"`
   - Remove `"present:budget": "skill-planner"`
   - Remove `"present:timeline": "skill-planner"`
   - Remove `"present:funds": "skill-planner"`

   **Rationale**: When no manifest match is found, the command docs already fall back to `skill-planner`. Keeping these entries in the present manifest implies present "owns" planning for its domain, which it does not (it has no plan skills). The fallback logic in the bash discovery code handles this correctly.

   **Resulting `plan` section**:
   ```json
     "plan": {
       "present:slides": "skill-slide-planning",
       "slides": "skill-slide-planning"
     }
   ```

2. **In `implement` routing** — Fix `:assemble` suffixes:
   - Change `"present:grant": "skill-grant:assemble"` → `"present:grant": "skill-grant"`
   - Change `"present:slides": "skill-slides:assemble"` → `"present:slides": "skill-slides"`

   **Rationale**: No skill directories use colon-suffix naming. The skills `skill-grant` and `skill-slides` exist in `present/skills/`. If these skills internally support an "assemble" mode, that should be handled by skill logic or arguments, not by routing table naming.

**Validation after Phase 2**:
- Verify all `routing.*.*` values exist in `provides.skills`.
- Run `validate-routing-tables.sh`; orphaned count should drop to 0.

---

## Phase 3: Remove Hardcoded Routing Tables from Command Docs

**Goal**: Eliminate the documentation-only markdown tables that duplicate manifest data.

**Files to modify** (3 files):
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

**Changes per file**:

1. **Locate** the section starting with:
   ```markdown
   **Extension-Based Routing Table**:
   ```

2. **Remove** the entire table:
   - The `**Extension-Based Routing Table**:` heading
   - The blank line after it
   - The table header row(s)
   - The separator row `|---|---|`
   - Every data row (`|...|...|`)
   - The blank line after the table

3. **Keep** the paragraphs immediately before and after the table:
   - Keep the bash manifest-discovery code block ending in `skill_name=${skill_name:-"skill-XXX"}`.
   - Keep the `**Extension Skills Location**:` paragraph.
   - Keep the `**Skill Selection Logic**:` block.
   - Keep the `**Delegation Chain Note**:` section.

4. **Update** the `**Extension Skills Location**:` paragraph to read:
   > Extension skills are located in `.opencode/extensions/{ext}/skills/`. OpenCode discovers these skills dynamically by reading `routing` entries from each extension's `manifest.json`. The bash discovery code above is the authoritative runtime mechanism; no hardcoded tables are used.

5. **Update fallback comment** — Replace:
   ```markdown
   if [ "$manifest_count" -eq 0 ]; then
     echo "[WARN] No extension manifests found in $manifest_dir. Using fallback routing."
   fi
   ```
   with:
   ```markdown
   if [ "$manifest_count" -eq 0 ]; then
     echo "[WARN] No extension manifests found in $manifest_dir."
   fi
   ```
   Remove the phrase "Using fallback routing" because it implies an alternative routing mechanism exists. The default skill assignment (`skill_name=${skill_name:-"skill-XXX"}`) is the clean default when no manifest matches.

**Line ranges to remove** (approximate, verify during implementation):

| File | Approx. Start | Approx. End |
|------|---------------|-------------|
| `implement.md` | `**Extension-Based Routing Table**:` | blank line after `general, meta` row |
| `research.md` | `**Extension-Based Routing Table**:` | blank line after `general, meta` row |
| `plan.md` | `**Extension-Based Routing Table**:` | blank line after `general, meta` row |

**Validation after Phase 3**:
- Grep each file for "Extension-Based Routing Table" — should return 0 matches.
- Confirm bash manifest-discovery code is still present and syntactically intact.
- Confirm Skill Selection Logic and Delegation Chain Note sections are intact.

---

## Phase 4: Generalize Anti-Bypass Constraints

**Goal**: Replace hand-listed skill names with a manifest-discovery reference that is future-proof.

**Files to modify** (3 files):
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

**Current Anti-Bypass lines to replace**:

| File | Current Line (approx.) |
|------|------------------------|
| `implement.md` | `skill-implementer, skill-lean-implementation, skill-neovim-implementation, skill-nix-implementation, skill-typst-implementation, skill-founder-implement, skill-deck-implement, or skill-team-implement` |
| `research.md` | `skill-researcher, skill-lean-research, skill-neovim-research, skill-nix-research, skill-typst-research, skill-market, skill-analyze, skill-strategy, skill-deck-research, or skill-team-research` |
| `plan.md` | `skill-planner, skill-founder-plan, skill-deck-plan, skill-slide-planning, or skill-team-plan` |

**New standardized text** (identical across all three files, except for artifact type and default skill name):

```markdown
**PROHIBITION**: You MUST NOT write {artifact-type} artifacts directly using Write or Edit tools. All {artifact-type} files MUST be created by invoking the appropriate skill via the Skill tool. The correct skill is determined by manifest discovery in `.opencode/extensions/*/manifest.json` — query `.routing.{command}[<task_type>]` from the matching extension manifest, falling back to the default skill (`skill-{command}er` or `skill-team-{command}`) if no extension match is found.
```

Where:
- `{artifact-type}` = "implementation summary", "research report", or "plan"
- `{command}` = "implement", "research", or "plan"
- `{command}er` = "implementer", "researcher", or "planner"

**Validation after Phase 4**:
- Grep each file for the old enumerated skill lists — should return 0 matches.
- Confirm the new text appears exactly once per file.

---

## Phase 5: Retarget Validation Script

**Goal**: Replace manifest-vs-command-doc comparison with manifest-integrity checks.

**File**: `.opencode/scripts/validate-routing-tables.sh`

**Changes**:

1. **Remove** Steps 2, 3, and 4 (command doc table extraction, missing check, orphan check).
2. **Keep** Step 1 (manifest task type extraction) as the foundation.
3. **Add** new checks:

**New Check A — Skill Coverage**:
```bash
# Every skill in provides.skills must have at least one routing entry
# (unless extension has routing_exempt: true or is utility)
```
- Loop over all manifests.
- Skip if `routing_exempt: true`.
- Skip `memory` extension (utility, no routing needed).
- Skip `slidev` extension (dependency-only, no skills).
- For each skill in `provides.skills`, verify it appears as a value in at least one `routing.*` object.

**New Check B — Routing Integrity**:
```bash
# Every routing.*.* value must exist in the same manifest's provides.skills
# (or be explicitly documented as cross-extension)
```
- For each manifest, collect `provides.skills` into a set.
- For each `routing.*.*` value, check if it is in the set.
- Allow-list known cross-extension references (currently none after Phase 2; if any are added later, document them here).

**New Check C — No Hardcoded Tables**:
```bash
# Grep command docs for "Extension-Based Routing Table"
for cmd in implement research plan; do
  if grep -q "Extension-Based Routing Table" "$COMMANDS_DIR/${cmd}.md"; then
    echo "FAIL: Hardcoded table found in ${cmd}.md"
    ERRORS=$((ERRORS + 1))
  fi
done
```

**New Check D — Valid JSON**:
```bash
for manifest in "$MANIFEST_DIR"/*/manifest.json; do
  if ! jq empty "$manifest" 2>/dev/null; then
    echo "FAIL: Invalid JSON in $manifest"
    ERRORS=$((ERRORS + 1))
  fi
done
```

**Rename**: Consider renaming the script to `validate-extension-routing.sh` to reflect its new purpose. If renamed, update any references in CI or documentation.

**Validation after Phase 5**:
- Run the updated script — expect 0 errors.
- Confirm old manifest-vs-table comparison logic is fully removed.

---

## Phase 6: Address .claude Mirrors

**Goal**: Add deprecation notice to `.claude/commands/` mirror files so users know they are not the active source of truth.

**Decision**: Do NOT modify `.claude/commands/implement.md`, `research.md`, or `plan.md` to match `.opencode/commands/` — they are legacy copies and any functional changes risk divergence. Instead, add a deprecation notice.

**File to create**: `.claude/commands/README.md`

**Content**:
```markdown
# .claude/commands/ — Legacy Mirror Directory

**Status**: DEPRECATED

These command files are legacy copies from an earlier version of the system. The active command definitions are in `.opencode/commands/`.

## Differences from Active Commands

- `.claude/commands/` uses old extension paths (`.claude/extensions/`)
- `.claude/commands/` lacks manifest-discovery improvements (compound key fallback, manifest count warnings)
- `.claude/commands/` has shorter Anti-Bypass skill lists
- `.claude/commands/` uses `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` instead of `OPENCODE_EXPERIMENTAL_AGENT_TEAMS`

## Action Required

If you are using OpenCode, use `.opencode/commands/` instead. This directory may be removed or converted to symlinks in a future task.
```

**Validation after Phase 6**:
- Verify README.md exists and is readable.
- Confirm no functional changes were made to `.claude/commands/*.md`.

---

## Phase 7: Test and Verify End-to-End

**Goal**: Confirm the entire routing system works with manifest.json as the sole source of truth.

**Test checklist**:

- [ ] Run updated validation script → 0 errors, 0 orphans
- [ ] Run `jq empty` on all 16 manifests → all valid JSON
- [ ] Simulate `/research 539` (task type `meta`) → routes to `skill-researcher` (default, no manifest match)
- [ ] Simulate `/implement 539` (task type `meta`) → routes to `skill-implementer` (default)
- [ ] Simulate `/plan 539` (task type `meta`) → routes to `skill-planner` (default)
- [ ] Simulate a task with `task_type: latex` → routes to `skill-latex-research` / `skill-latex-implementation`
- [ ] Simulate a task with `task_type: present:slides` → routes to `skill-slides` (research), `skill-slide-planning` (plan), `skill-slides` (implement)
- [ ] Simulate a task with `task_type: formal:logic` → routes to `skill-logic-research`
- [ ] Confirm compound key fallback works: `task_type: founder:market` → `skill-market` (research), `skill-founder-plan` (plan), `skill-founder-implement` (implement)
- [ ] Grep all modified command docs for "Extension-Based Routing Table" → 0 matches
- [ ] Grep all modified command docs for old enumerated Anti-Bypass lists → 0 matches

**Manual review**:
- Read each modified manifest to confirm routing section is well-formed.
- Read each modified command doc to confirm narrative flow is still coherent after table removal.

---

## Rollback Plan

If any phase introduces a regression:

1. **Manifests**: All changes are additive (new `routing` keys) or fix broken entries. No deletions of valid data. Rollback = revert the specific manifest file.
2. **Command docs**: Table removals are safe (tables were documentation-only). If flow is broken, re-read the surrounding sections and reword. The bash code is unchanged.
3. **Validation script**: Keep a copy of the old script until Phase 7 passes, then delete.
4. **Git**: Commit after each phase with message `task 539: phase {N}: {description}`.

---

## Commit Sequence

| Phase | Commit Message |
|-------|----------------|
| 1 | `task 539: phase 1: add missing routing to 8 extension manifests` |
| 2 | `task 539: phase 2: fix orphaned entries in present manifest` |
| 3 | `task 539: phase 3: remove hardcoded routing tables from command docs` |
| 4 | `task 539: phase 4: generalize anti-bypass constraints` |
| 5 | `task 539: phase 5: retarget validation script` |
| 6 | `task 539: phase 6: add deprecation notice for .claude mirrors` |
| 7 | `task 539: phase 7: verify end-to-end routing` |

---

## Success Criteria

- [ ] All extensions with skills have complete `routing` sections
- [ ] No hardcoded routing tables exist in command docs
- [ ] Anti-Bypass constraints reference manifest discovery, not hardcoded skill lists
- [ ] Validation script passes with zero errors
- [ ] Manifest discovery alone determines routing — no silent fallback to generic agents
- [ ] `.claude/commands/` has a deprecation notice
- [ ] All 16 manifests are valid JSON

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Removing tables breaks human comprehension | Low | Low | Bash code remains; narrative flow preserved |
| Adding routing changes behavior for existing tasks | Medium | Medium | This is the **intended** fix — tasks will now route to correct agents |
| `:assemble` suffix was load-bearing | Low | High | Verify present skills internally first; if broken, it was already broken |
| `.claude/` mirror confusion | High | Low | Deprecation notice added; no functional changes to mirrors |

---

*End of Plan*
