# Implementation Summary: Task #770

**Completed**: 2026-06-24
**Duration**: ~1.5 hours
**Task**: Re-deploy/propagate corrected core hard pieces to installed projects and sync CLAUDE.md docs

## Overview

Task 770 is the final step in the 767-770 series that added hard-mode agents/skills to the core
extension and corrected the routing algorithm. This task updated the Routing Mechanism documentation
in the core CLAUDE.md merge-source (replacing the outdated 4-step description with the accurate
5-step algorithm), authored a propagation procedure for re-deploying to existing projects like
BimodalLogic, and verified the doc-lint baseline remains at exactly 4 FAILs with no new regressions.

## What Changed

- `.claude/extensions/core/merge-sources/claudemd.md` — Replaced outdated 4-step Routing Mechanism
  with the accurate 5-step algorithm, documenting non-core/core precedence, compound-key fallbacks,
  and the SKILL.md safety gate on the append fallback only.
- `specs/770_redeploy_core_hard_sync_docs/summaries/01_redeploy-core-hard-sync-summary.md` — This
  summary file, which also serves as the propagation procedure document.
- `.claude/context/guides/extension-development.md` — Added a "Deploy Mechanisms" section comparing
  `install-extension.sh` (new projects, symlinks) vs the extension loader Ctrl-l (existing projects,
  overwrite on confirm).

## Decisions

- Edit the merge-source (`core/merge-sources/claudemd.md`), NOT the generated `.claude/CLAUDE.md`.
  CLAUDE.md regeneration is triggered by the user via the extension picker.
- Document the BimodalLogic re-deploy procedure for the user to execute, rather than performing
  the deploy directly. The extension loader's conflict dialog requires interactive user confirmation.
- Place the propagation procedure in the task summary (this file) as the primary artifact, with a
  concise note in `extension-development.md` for durable discoverability.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (meta task, no build)
- Tests: `check-extension-docs.sh` passed with exactly 4 FAILs (baseline unchanged, no new regressions)
- Files verified: Yes

---

## Re-Deploy / Propagation Procedure

### Background: Two Deploy Mechanisms

The Claude Code extension system provides two distinct mechanisms for deploying extension files.
Understanding the difference determines which to use when updating an already-installed project.

#### `install-extension.sh` (New Projects — Symlinks)

- Scans the extension's `agents/` and `skills/` directories on the **filesystem** (NOT the manifest `provides` arrays)
- Creates **symlinks** (relative paths like `../extensions/{name}/agents/...`), not copies
- For files that already exist as non-symlinks: emits a warning and **skips** — no overwrite
- For files that already exist as symlinks: skips (already linked)
- **Best for**: Fresh project setup where no files have been previously deployed

```bash
# Example: install-extension.sh for a new project
bash ~/.config/nvim/.claude/scripts/install-extension.sh core /path/to/new-project/.claude
```

#### Extension Loader / Ctrl-l (Existing Projects — Copies with Overwrite)

- Reads `manifest.provides.agents` and `manifest.provides.skills` arrays
- **Copies** files (not symlinks) to the project's `.claude/` directory
- Before copying: runs `check_conflicts()` — shows user a confirmation dialog listing conflicting files
- If user confirms: **overwrites** existing files (unlike `install-extension.sh` which skips)
- **Best for**: Updating an already-installed project to pick up new or updated files

The Ctrl-l extension loader is the correct mechanism for BimodalLogic, which already has
real-file (non-symlink) copies of earlier core extension files.

---

### BimodalLogic Re-Deploy Procedure

#### What is Missing

As of task 767 (which added hard-mode agents/skills to the core manifest `provides` arrays),
BimodalLogic is missing the following files from its `.claude/` directories:

**Missing agents** (not in `BimodalLogic/.claude/agents/`):
- `planner-hard-agent.md`
- `general-research-hard-agent.md`
- `general-implementation-hard-agent.md`

**Missing skills** (not in `BimodalLogic/.claude/skills/`):
- `skill-orchestrate-hard`

Note: `skill-planner-hard`, `skill-researcher-hard`, and `skill-implementer-hard` are present
in BimodalLogic's `skills/` directory but are not tracked in `extensions.json`'s core
`installed_files` list (they arrived via a prior manual deploy). The Ctrl-l update will
refresh these as well (conflict dialog will list them; confirming is expected and correct).

#### Step-by-Step User Procedure

**USER ACTION REQUIRED** — Agents cannot perform this procedure on external projects.
The extension loader handles conflict resolution interactively.

1. Open a Claude Code session in the BimodalLogic project directory:
   ```bash
   cd ~/Projects/BimodalLogic
   claude
   ```

2. Open the extension picker (Ctrl-e or the extension menu)

3. Select the **core** extension from the list

4. Press **Ctrl-l** ("Load Core") to trigger an extension re-sync

5. A conflict dialog will appear listing files that already exist in BimodalLogic's `.claude/`.
   **Confirm the overwrite** — this is expected and correct. The dialog appears because BimodalLogic
   has existing copies of standard core agents and skills. Confirming will:
   - Copy the 3 missing hard agents (`planner-hard-agent.md`, `general-research-hard-agent.md`,
     `general-implementation-hard-agent.md`) to `.claude/agents/`
   - Copy `skill-orchestrate-hard` to `.claude/skills/`
   - Update any existing agent/skill files to match the current core versions

6. After the Ctrl-l completes, verify the missing files now exist:
   ```bash
   ls .claude/agents/ | grep hard
   # Expected: general-implementation-hard-agent.md
   #           general-research-hard-agent.md
   #           planner-hard-agent.md

   ls .claude/skills/ | grep hard
   # Expected: skill-implementer-hard
   #           skill-orchestrate-hard
   #           skill-planner-hard
   #           skill-researcher-hard
   ```

---

### CLAUDE.md Regeneration

After editing `core/merge-sources/claudemd.md` (Phase 1 of task 770, completed above), the
deployed `.claude/CLAUDE.md` in any project will NOT automatically update — it must be
regenerated by the user via the extension picker.

**How CLAUDE.md is generated**: `generate_claudemd()` in the extension loader (editor-internal)
concatenates the header template + each loaded extension's merge-source + each extension's
`EXTENSION.md`. It runs on every load/unload operation triggered by the extension picker.

**There is no standalone bash script** for this; regeneration requires the editor's extension
loader.

#### CLAUDE.md Regeneration Procedure

**USER ACTION REQUIRED** — This is a user action; the agent does not modify CLAUDE.md.

In any project where the core extension is installed (e.g., BimodalLogic, nvim):

1. Open the extension picker
2. Unload the core extension
3. Reload the core extension (or use Ctrl-l to re-sync)

The generated `.claude/CLAUDE.md` will be updated. The diff should be limited to the
`## Hard Mode` → `### Routing Mechanism` subsection (the 4-step list replaced by the
5-step algorithm). No other sections should change.

**Verification** (after regeneration):
```bash
git diff .claude/CLAUDE.md
# Should show only the Routing Mechanism section changing from 4-step to 5-step
```

---

### Notes

- The BimodalLogic re-deploy and CLAUDE.md regeneration are user actions that cannot be
  automated by agents (conflict resolution is interactive; the extension loader is editor-internal).
- The 4 doc-lint FAILs (2 core pre-existing + 2 lean legitimate) are the accepted baseline;
  they were not introduced by task 770 and are documented in `reports/01_redeploy-core-hard-sync.md`.
- If running `install-extension.sh` instead of Ctrl-l: it will create symlinks for the 3 new
  hard agents and `skill-orchestrate-hard` (they don't exist yet in BimodalLogic), but will
  skip/warn for the existing standard agents and skills. This is less desirable because symlinks
  behave differently from copies in some editor contexts.
