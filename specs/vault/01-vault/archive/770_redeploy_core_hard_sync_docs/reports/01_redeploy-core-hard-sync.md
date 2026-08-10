# Research Report: Task #770

**Task**: 770 - Re-deploy/propagate the corrected core hard pieces and sync CLAUDE.md docs
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T00:30:00Z
**Effort**: 1 hour
**Dependencies**: Tasks 767, 768, 769 (all completed)
**Sources/Inputs**:
- `.claude/scripts/install-extension.sh` (full text)
- `.claude/extensions/core/manifest.json` (provides, routing_hard, routing_exempt)
- `.claude/extensions/core/agents/` and `.claude/extensions/core/skills/` (filesystem)
- `.claude/agents/` and `.claude/skills/` (deployed in nvim repo)
- `/home/benjamin/Projects/BimodalLogic/.claude/agents/` and `.claude/skills/`
- `/home/benjamin/Projects/BimodalLogic/.claude/extensions.json`
- `.claude/scripts/command-route-skill.sh` (actual 5-step implementation)
- `.claude/extensions/core/merge-sources/claudemd.md` (lines 285-297, Routing Mechanism)
- `.claude/docs/architecture/extension-system.md` (load/copy mechanism)
- `.claude/context/guides/hard-mode-routing.md` (768's new guide)
- `bash .claude/scripts/check-extension-docs.sh` (live run)
**Artifacts**:
- `specs/770_redeploy_core_hard_sync_docs/reports/01_redeploy-core-hard-sync.md`
**Standards**: report-format.md

---

## Executive Summary

- The `install-extension.sh` script deploys via **filesystem scan** (not manifest `provides` arrays) and creates **symlinks** — so with task 767's agents/skills already physically present in `core/agents/` and `core/skills/`, a fresh `install-extension.sh core` run on any project WOULD deploy all 3 hard agents and 4 hard skills via symlinks, for any agent/skill not already present.
- The **extension loader** (used by BimodalLogic via Ctrl-l / "Load Core") reads `manifest.provides` arrays and **copies** files. With task 767's additions to `provides.agents` and `provides.skills`, a Ctrl-l re-sync from the extension picker in BimodalLogic will copy the 3 missing hard agents and `skill-orchestrate-hard` (showing a conflict dialog for files that already exist as earlier copies).
- The `CLAUDE.md` merge-source (`core/merge-sources/claudemd.md`) Routing Mechanism section documents a **4-step** algorithm that collapses all manifest lookups into one step and omits: the non-core/core priority split, compound-key fallback for hard mode, and the SKILL.md safety gate detail. It needs to be updated to the **5-step** (4a–4e) algorithm that command-route-skill.sh actually implements.
- The doc-lint baseline is **4 FAILs** (2 pre-existing core issues + 2 lean routing_hard violations). No new regressions introduced by tasks 767-769.
- BimodalLogic is reachable from this environment (`~/Projects/BimodalLogic`) but task 770 should **document the procedure** for the user to run (Ctrl-l in BimodalLogic's extension picker), not perform the deploy directly. Rationale: the extension loader handles conflict resolution interactively.

---

## Context & Scope

Task 770 is the final step in a 4-task series:
- **767**: Added 3 hard agents + 4 hard skills to core manifest `provides` + `routing_hard`
- **768**: Implemented 5-step hard routing in `command-route-skill.sh`; added `hard-mode-routing.md` guide
- **769**: Extended `check-extension-docs.sh` with consistency checks; documented 4 expected FAILs
- **770**: Propagate hard pieces to installed projects; sync CLAUDE.md docs; confirm doc-lint baseline

---

## Findings

### 1. install-extension.sh Deploy Mechanism

**Source**: `/home/benjamin/.config/nvim/.claude/scripts/install-extension.sh`

The script uses three functions:

```bash
install_agents() {
  # Scans $EXT_DIR/agents/*.md on FILESYSTEM (NOT manifest provides)
  for agent in "$agents_dir"/*.md; do
    if [ -L "$target" ]; then log_info "Skill symlink already exists"
    elif [ -f "$target" ]; then log_warn "Agent file exists (not a symlink)"  # NO overwrite
    else ln -s "$rel_path" "$target"  # Creates symlink
    fi
  done
}

install_skills() {
  # Scans $EXT_DIR/skills/skill-* directories on FILESYSTEM
  # Same pattern: symlink if new, warn if non-symlink exists, skip if symlink
}
```

**Critical finding**: `install-extension.sh` does NOT read `manifest.json` `provides` arrays. It scans the extension's `agents/` and `skills/` directories directly. It creates **symlinks** (relative paths like `../extensions/$EXT_NAME/agents/...`), not copies.

**Gap for existing installed projects**: If an agent file already exists as a **non-symlink** (e.g., copied by the extension loader previously), `install-extension.sh` emits `log_warn "Agent file exists (not a symlink)"` and **skips it** — no overwrite. So running `install-extension.sh` on BimodalLogic for new files works; existing files are left alone.

**With task 767's changes** (hard agents/skills now physically present in core extension dirs), a fresh `install-extension.sh /path/to/core` would:
- Create symlinks for the 3 new hard agents (they don't exist in target yet)
- Create symlink for `skill-orchestrate-hard` (doesn't exist in target)
- Warn and skip the 3 hard skills that already exist as real dirs in BimodalLogic
- Warn and skip all 8 standard agents that exist as real files in BimodalLogic

**Conclusion**: `install-extension.sh` works for NEW deployments. For BimodalLogic's specific case (existing real-file copies), the extension loader (Ctrl-l) is the correct mechanism because it can overwrite on user confirmation.

### 2. Extension Loader (Ctrl-l) Deploy Mechanism

**Source**: `.claude/docs/architecture/extension-system.md`

The extension loader (merge.lua, editor-internal) uses a different mechanism:
- Reads `manifest.provides.agents` array → calls `copy_simple_files()` → copies `.md` files
- Reads `manifest.provides.skills` array → calls `copy_skill_dirs()` → copies skill directories
- Before copying: runs `check_conflicts()` — shows user a confirmation dialog listing conflicting files
- If user confirms: **overwrites** existing files (unlike `install-extension.sh` which skips)

**With task 767's manifest changes**, the extension loader will:
1. See 3 new hard agents in `provides.agents`: `general-research-hard-agent.md`, `general-implementation-hard-agent.md`, `planner-hard-agent.md`
2. See `skill-orchestrate-hard` as new in `provides.skills`
3. Detect conflicts for any files that already exist (existing agent copies, existing skill dirs)
4. Present conflict dialog → user confirms → copy all files

**Procedure for BimodalLogic re-deploy**:
In BimodalLogic's Claude Code session → extension picker → select "core" → Ctrl-l ("Load Core") → confirm overwrite dialog → done.

This will copy all 3 missing hard agents and `skill-orchestrate-hard`, and update any existing agent/skill files to match the current core versions.

### 3. Current BimodalLogic State

Confirmed by direct inspection of `/home/benjamin/Projects/BimodalLogic/.claude/`:

**Missing from BimodalLogic** (not in `agents/`):
- `planner-hard-agent.md`
- `general-research-hard-agent.md`
- `general-implementation-hard-agent.md`

**Missing from BimodalLogic** (not in `skills/`):
- `skill-orchestrate-hard`

**Present but untracked** (not in `extensions.json` core `installed_files`):
- `skill-planner-hard`, `skill-researcher-hard`, `skill-implementer-hard` — real dirs, not in core's installed_files list, arrived via some prior manual deploy

**BimodalLogic `extensions.json`**: The core extension's `installed_files` list was captured before task 767 added hard agents/skills to `provides`. It does not include any hard agent/skill entries under core (only lean's hard agents are tracked under the lean extension).

### 4. CLAUDE.md Merge-Source: Current vs Required Content

**File**: `.claude/extensions/core/merge-sources/claudemd.md`, lines 285–297

**CURRENT content** (4-step algorithm):
```markdown
### Routing Mechanism

`--hard` is resolved by `command-route-skill.sh` as a 4th `effort_flag` argument:
1. Check `routing_hard.$operation.$task_type` in extension manifests
2. If not found: construct candidate by appending `-hard` to the resolved skill name
3. If candidate skill exists (`.claude/skills/${skill}-hard/SKILL.md`): use it
4. If not: fall back to standard skill with stderr note `[route] No hard variant for $skill; using standard skill`
```

**GAPS vs actual 5-step implementation**:
1. Step 1 collapses all manifest lookups into one pass — omits the **non-core/core split** (Steps 4a-4c) and the **compound-key fallback for hard mode** (Steps 4b, 4d)
2. The "extension overrides core" precedence rule is not mentioned
3. The SKILL.md existence safety gate applies only to the *append fallback* (Step 4e) — the current doc implies it applies to all cases
4. Current doc implies steps 2 and 3 are always attempted — but Steps 4a-4d all short-circuit before reaching the append fallback (Step 4e)

**REQUIRED content** (5-step algorithm, to match actual implementation):
```markdown
### Routing Mechanism

`--hard` is resolved by `command-route-skill.sh` as a 4th `effort_flag` argument, using a
5-step precedence (first match wins):

1. **Non-core extension `routing_hard` exact match** — scan non-core extension manifests for
   `routing_hard[$op][$task_type]`; first hit wins.
2. **Non-core extension `routing_hard` compound-key fallback** — if `task_type` contains `:`
   and no hit yet, try `routing_hard[$op][$base_type]` in non-core manifests.
3. **Core extension `routing_hard` exact match** — scan the core manifest (identified by
   `routing_exempt: true`) for `routing_hard[$op][$task_type]`.
4. **Core extension `routing_hard` compound-key fallback** — if `task_type` contains `:` and
   no hit yet, try `routing_hard[$op][$base_type]` in the core manifest.
5. **`-hard` append fallback** — construct `${SKILL_NAME}-hard`; use it only if
   `.claude/skills/${candidate}-hard/SKILL.md` exists on disk; otherwise emit a stderr note
   and leave `SKILL_NAME` unchanged (safe default = standard skill).

Non-core extensions (Steps 1-2) are scanned before core (Steps 3-4), so a non-core
`routing_hard` entry for the same `($op, $task_type)` pair unconditionally overrides core.
The SKILL.md existence safety gate applies only to Step 5; manifest-declared entries
(Steps 1-4) are trusted to point to deployed skills.
```

### 5. CLAUDE.md Regeneration Mechanism

**How CLAUDE.md is generated**: Via `generate_claudemd()` in `merge.lua` (editor-internal). It is triggered by the extension picker on every load/unload. It concatenates:
1. The header from `.claude/templates/claudemd-header.md`
2. The file at each extension's `manifest.merge_targets.claudemd.source` path (for core: `merge-sources/claudemd.md`)
3. Each loaded extension's `EXTENSION.md`

**Core's source**: `manifest.merge_targets.claudemd.source = "merge-sources/claudemd.md"` — confirmed in manifest.

**Edit target**: Edits to the Routing Mechanism section go to:
`/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`
NOT to `.claude/CLAUDE.md` directly (it says "Do not edit directly" and is fully regenerated).

**Regeneration**: After editing `merge-sources/claudemd.md`, the user triggers regeneration by using the extension picker to unload then reload core (or re-sync via Ctrl-l). There is **no standalone bash script** for this; it requires the editor's extension loader.

**Diff verification**: After editing `merge-sources/claudemd.md` and regenerating, `git diff .claude/CLAUDE.md` should show changes limited to the `## Hard Mode` → `### Routing Mechanism` subsection only (lines ~285-297 in the merge-source; the generated CLAUDE.md adds a header and extension sections but the routing section maps 1:1).

### 6. Doc-Lint Baseline (4 Expected FAILs)

Live run of `bash .claude/scripts/check-extension-docs.sh` confirms **exactly 4 FAILs**:

| Extension | FAIL | Reason | Pre-existing? |
|-----------|------|--------|---------------|
| core | `manifest script entry missing on disk: scripts/dispatch-agent.sh` | Script declared in manifest but file doesn't exist | Yes (pre-existing) |
| core | `command /zulip listed in manifest but not mentioned in README.md` | README not updated when /zulip was added | Yes (pre-existing) |
| lean | `routing_hard target declared but not deployed (and extension not installed): skill-lean-research-hard` | lean not installed in nvim | Yes (legitimate) |
| lean | `routing_hard target declared but not deployed (and extension not installed): skill-lean-implementation-hard` | lean not installed in nvim | Yes (legitimate) |

**Verification criterion for task 770**: After implementation, `bash .claude/scripts/check-extension-docs.sh` must still exit with **exactly 4 FAILs** — same 4 as above. Zero new FAILs introduced by the CLAUDE.md routing section update.

---

## Decisions

1. **Do not directly deploy to BimodalLogic**: Document the procedure (Ctrl-l in BimodalLogic's extension picker) rather than copying files. Interactive conflict resolution is required.
2. **Edit merge-source, not CLAUDE.md**: All routing section changes go to `core/merge-sources/claudemd.md`. CLAUDE.md regenerates via the extension loader.
3. **No bash regeneration script**: CLAUDE.md regeneration requires the editor extension loader. Plan must note the user must trigger it via the extension picker after editing the merge-source.
4. **5-step algorithm in CLAUDE.md**: Replace the current 4-step description with the accurate 5-step (4a-4e) description that matches `command-route-skill.sh` and `hard-mode-routing.md`.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Editing CLAUDE.md directly instead of merge-source | Implementation must edit `core/merge-sources/claudemd.md` only |
| CLAUDE.md regeneration changes more than routing section | Verify with `git diff .claude/CLAUDE.md` limited to routing subsection |
| doc-lint regressions from routing update | Run check-extension-docs.sh before and after; assert still 4 FAILs |
| install-extension.sh skipping existing BimodalLogic files | Document limitation; Ctrl-l is the correct update path |
| Extension loader conflict dialog confusing user | Document that confirming the overwrite is expected/correct |

---

## Context Extension Recommendations

- **Topic**: `install-extension.sh` vs extension loader deploy mechanisms
- **Gap**: No documentation distinguishes when to use `install-extension.sh` (new projects, symlink semantics) vs Ctrl-l (existing projects with copy-deployed files)
- **Recommendation**: Add a note to `.claude/context/guides/extension-development.md` comparing the two deploy mechanisms and their appropriate use cases.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/scripts/install-extension.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json`
- `/home/benjamin/.config/nvim/.claude/extensions/core/agents/` (directory listing)
- `/home/benjamin/.config/nvim/.claude/extensions/core/skills/` (directory listing)
- `/home/benjamin/.config/nvim/.claude/agents/` (listing + symlink status of hard agents)
- `/home/benjamin/.config/nvim/.claude/skills/` (listing of hard skills)
- `/home/benjamin/Projects/BimodalLogic/.claude/agents/` (listing)
- `/home/benjamin/Projects/BimodalLogic/.claude/skills/` (listing)
- `/home/benjamin/Projects/BimodalLogic/.claude/extensions.json`
- `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md` (lines 285-297)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/extension-system.md`
- `/home/benjamin/.config/nvim/.claude/context/guides/hard-mode-routing.md`

### Commands Run
- `bash .claude/scripts/check-extension-docs.sh` (live doc-lint run)
- `ls -la .claude/agents/ | grep hard` (symlink status)
- `ls -la .claude/skills/ | grep hard`
- `jq '.provides.agents,.provides.skills,.routing_hard,.routing_exempt' core/manifest.json`
- `jq '.extensions.core.installed_files[]' BimodalLogic/.claude/extensions.json | grep hard`
