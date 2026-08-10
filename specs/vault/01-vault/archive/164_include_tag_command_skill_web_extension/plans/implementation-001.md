# Implementation Plan: Task #164

- **Date**: 2026-03-09
- **Feature**: Port /tag command and skill-tag from Logos Website into the web extension
- **Status**: [COMPLETED]
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)
- **Task**: 164 - include_tag_command_skill_web_extension
- **Effort**: 1-2 hours
- **Type**: meta
- **Lean Intent**: false

## Overview

Port the `/tag` command and `skill-tag` from `/home/benjamin/Projects/Logos/Website/.claude/` into the web extension at `.claude/extensions/web/`. The source files implement semantic version tagging with CI/CD deployment triggers. The main work involves copying the files, generalizing project-specific hardcoded references (Logos URLs, Cloudflare project names), updating the extension manifest and documentation, and verifying the integration.

### Research Integration

Research report identified:
- Source: 264-line command file + 571-line skill file
- Target: web extension currently has no commands (empty commands array in manifest)
- Other extensions (lean, filetypes) provide the pattern: commands go in `{extension}/commands/` directory
- Three project-specific references need generalization: `logos-labs` project name, `logos-labs.ai` URL, GitLab CI reference
- Referenced context files (cicd-pipeline-guide.md, cloudflare-deploy-guide.md) already exist in the web extension
- No new agent needed (direct execution skill with user-only enforcement)

## Goals & Non-Goals

**Goals**:
- Port /tag command and skill-tag into the web extension
- Generalize project-specific hardcoded references
- Update manifest.json and EXTENSION.md
- Document the deployment_versions state.json schema extension

**Non-Goals**:
- Making the tag command configurable via extension config (future enhancement)
- Adding CI/CD provider auto-detection
- Creating an agent for tag operations (intentionally user-only)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hardcoded URLs remain in skill | L | L | Search-and-replace pass with verification |
| state.json schema conflict with deployment_versions | L | L | Section is additive, no existing fields affected |
| Git push in skill affects production | M | L | Preserved --dry-run, --force, user-only enforcement |

## Implementation Phases

### Phase 1: Create commands directory and port tag command [COMPLETED]

**Goal**: Create the commands directory in the web extension and port the /tag command file with generalized references.

**Tasks**:
- [ ] Create `.claude/extensions/web/commands/` directory
- [ ] Copy `tag.md` from source project
- [ ] Replace `logos-labs` project name references with generic placeholder text
- [ ] Replace `https://logos-labs.ai/` with generic "Live site" reference
- [ ] Replace GitLab-specific CI references with generic CI/CD references
- [ ] Verify context file paths (`.claude/context/project/web/tools/`) resolve correctly within extension structure

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/web/commands/tag.md` - Create (adapted from source)

**Verification**:
- File exists at correct path
- No `logos-labs` references remain
- Context file paths reference extension-relative paths correctly

---

### Phase 2: Port skill-tag with generalized references [COMPLETED]

**Goal**: Port the skill-tag SKILL.md into the web extension with project-specific references generalized.

**Tasks**:
- [ ] Create `.claude/extensions/web/skills/skill-tag/` directory
- [ ] Copy `SKILL.md` from source project
- [ ] Replace Cloudflare verification command (`pnpm exec wrangler pages deployment list --project-name=logos-labs`) with a generic pattern that references the project's CI/CD context file
- [ ] Replace `https://logos-labs.ai/` site URL with generic reference
- [ ] Replace GitLab CI reference with generic CI/CD provider reference
- [ ] Keep all git tag operations, semver logic, state.json tracking, and AskUserQuestion confirmation as-is
- [ ] Preserve frontmatter fields: `name: skill-tag`, `allowed-tools: Bash, AskUserQuestion, Read`, `user-only: true`

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/web/skills/skill-tag/SKILL.md` - Create (adapted from source)

**Verification**:
- File exists with correct frontmatter
- No `logos-labs` references remain
- All 8 execution steps preserved
- `user-only: true` frontmatter field present

---

### Phase 3: Update manifest.json and EXTENSION.md [COMPLETED]

**Goal**: Register the new command and skill in the extension's configuration files.

**Tasks**:
- [ ] Add `"tag.md"` to `manifest.json` `provides.commands` array
- [ ] Add `"skill-tag"` to `manifest.json` `provides.skills` array
- [ ] Add `/tag` command entry to EXTENSION.md with syntax, description, and user-only note
- [ ] Add `skill-tag` to EXTENSION.md skill mapping table with `(direct execution)` note (no agent)
- [ ] Add deployment section to EXTENSION.md documenting the `deployment_versions` state.json schema

**Timing**: 0.25 hours

**Files to modify**:
- `.claude/extensions/web/manifest.json` - Update commands and skills arrays
- `.claude/extensions/web/EXTENSION.md` - Add command reference and deployment section

**Verification**:
- `manifest.json` is valid JSON
- `manifest.json` lists both `tag.md` in commands and `skill-tag` in skills
- EXTENSION.md includes /tag command documentation
- EXTENSION.md documents deployment_versions schema

---

### Phase 4: Verification and testing [COMPLETED]

**Goal**: Verify the integration is correct and consistent.

**Tasks**:
- [ ] Verify no project-specific references remain via grep for `logos-labs`, `logos_labs`, `GitLab` across all new/modified files
- [ ] Verify manifest.json parses as valid JSON
- [ ] Verify all internal file path references in tag.md and SKILL.md point to files that exist in the extension
- [ ] Verify context files referenced in Related Documentation section exist: `.claude/context/project/web/tools/cicd-pipeline-guide.md`, `.claude/context/project/web/tools/cloudflare-deploy-guide.md`
- [ ] Verify the skill frontmatter matches expected format (name, allowed-tools, user-only)

**Timing**: 0.25 hours

**Files to modify**:
- None (verification only)

**Verification**:
- All grep searches return no results for project-specific strings
- All referenced files exist
- manifest.json validates

## Testing & Validation

- [ ] `grep -r "logos-labs" .claude/extensions/web/commands/ .claude/extensions/web/skills/skill-tag/` returns no matches
- [ ] `jq . .claude/extensions/web/manifest.json` parses without error
- [ ] Referenced context files exist at expected paths
- [ ] Skill frontmatter contains `user-only: true`
- [ ] EXTENSION.md documents the /tag command and deployment_versions schema

## Artifacts & Outputs

- `.claude/extensions/web/commands/tag.md` - Adapted /tag command documentation
- `.claude/extensions/web/skills/skill-tag/SKILL.md` - Adapted tag skill with generalized references
- `.claude/extensions/web/manifest.json` - Updated with new command and skill
- `.claude/extensions/web/EXTENSION.md` - Updated with deployment documentation

## Rollback/Contingency

Remove the added files and revert manifest.json/EXTENSION.md changes:
```bash
rm -rf .claude/extensions/web/commands/tag.md
rm -rf .claude/extensions/web/skills/skill-tag/
git checkout .claude/extensions/web/manifest.json .claude/extensions/web/EXTENSION.md
```
