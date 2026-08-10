# Implementation Plan: Add /zulip command and skill-zulip to core extension

- **Task**: 740 - Add /zulip command and skill-zulip to core extension
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/740_zulip_core_extension/reports/01_zulip-core-extension.md
- **Artifacts**: plans/01_zulip-core-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Promote the `/zulip` command and `skill-zulip` from the top-level `.claude/` directory into the core extension so they are installed automatically in child projects via the extension loader. This requires copying two source artifacts into the extension directory tree and declaring them in the core extension manifest.

### Research Integration

Research report (01_zulip-core-extension.md) confirmed: source files are `.claude/commands/zulip.md` (50 lines) and `.claude/skills/skill-zulip/SKILL.md` (227 lines). No external script dependencies exist. The manifest needs two array insertions. No context index or CLAUDE.md merge-source changes are needed. EXTENSION.md counts should be updated for accuracy.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Copy zulip command and skill into the core extension directory
- Declare both in the core extension manifest so `install-extension.sh` installs them
- Update EXTENSION.md counts for accuracy

**Non-Goals**:
- Modifying zulip command or skill behavior
- Adding context index entries for skill-zulip
- Adding CLAUDE.md merge-source sections for the zulip command

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Manifest JSON syntax error after edit | M | L | Validate with `jq .` after editing |
| Alphabetical insertion in wrong position | L | L | Research report specifies exact insertion points |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Copy artifacts into extension directory [COMPLETED]

**Goal**: Place the zulip command and skill files in the core extension tree.

**Tasks**:
- [x] Copy `.claude/commands/zulip.md` to `.claude/extensions/core/commands/zulip.md` *(completed)*
- [x] Create directory `.claude/extensions/core/skills/skill-zulip/` *(completed)*
- [x] Copy `.claude/skills/skill-zulip/SKILL.md` to `.claude/extensions/core/skills/skill-zulip/SKILL.md` *(completed)*

**Timing**: 5 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/commands/zulip.md` - new file (copy from `.claude/commands/zulip.md`)
- `.claude/extensions/core/skills/skill-zulip/SKILL.md` - new file (copy from `.claude/skills/skill-zulip/SKILL.md`)

**Verification**:
- Both files exist in extension directory with identical content to source
- `diff .claude/commands/zulip.md .claude/extensions/core/commands/zulip.md` returns no differences
- `diff .claude/skills/skill-zulip/SKILL.md .claude/extensions/core/skills/skill-zulip/SKILL.md` returns no differences

---

### Phase 2: Update manifest and EXTENSION.md [COMPLETED]

**Goal**: Declare the new command and skill in the core extension manifest and update documentation counts.

**Tasks**:
- [x] Add `"zulip.md"` to `provides.commands` array in `.claude/extensions/core/manifest.json` (insert alphabetically after `"todo.md"`) *(completed)*
- [x] Add `"skill-zulip"` to `provides.skills` array in `.claude/extensions/core/manifest.json` (insert alphabetically after `"skill-todo"`) *(completed)*
- [x] Validate manifest JSON with `jq . .claude/extensions/core/manifest.json` *(completed)*
- [x] Update command count in `.claude/extensions/core/EXTENSION.md` (14 -> 17 commands) *(completed: updated to actual count of 17)*
- [x] Update skill count in `.claude/extensions/core/EXTENSION.md` (16 -> 19 skills) *(completed: updated to actual count of 19)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/manifest.json` - add entries to `provides.commands` and `provides.skills` arrays
- `.claude/extensions/core/EXTENSION.md` - update command and skill counts in prose

**Verification**:
- `jq '.provides.commands | index("zulip.md")' .claude/extensions/core/manifest.json` returns a number (not null)
- `jq '.provides.skills | index("skill-zulip")' .claude/extensions/core/manifest.json` returns a number (not null)
- `jq . .claude/extensions/core/manifest.json` succeeds without parse errors

## Testing & Validation

- [ ] Manifest JSON is valid (no parse errors from `jq .`)
- [ ] `zulip.md` appears in `provides.commands` array
- [ ] `skill-zulip` appears in `provides.skills` array
- [ ] Extension command file is byte-identical to source: `diff .claude/commands/zulip.md .claude/extensions/core/commands/zulip.md`
- [ ] Extension skill file is byte-identical to source: `diff .claude/skills/skill-zulip/SKILL.md .claude/extensions/core/skills/skill-zulip/SKILL.md`

## Artifacts & Outputs

- `specs/740_zulip_core_extension/plans/01_zulip-core-extension.md` (this plan)
- `.claude/extensions/core/commands/zulip.md` (new file)
- `.claude/extensions/core/skills/skill-zulip/SKILL.md` (new file)
- `.claude/extensions/core/manifest.json` (modified)
- `.claude/extensions/core/EXTENSION.md` (modified)

## Rollback/Contingency

Remove the copied files and revert manifest/EXTENSION.md changes:
```bash
rm -f .claude/extensions/core/commands/zulip.md
rm -rf .claude/extensions/core/skills/skill-zulip/
git checkout .claude/extensions/core/manifest.json .claude/extensions/core/EXTENSION.md
```
