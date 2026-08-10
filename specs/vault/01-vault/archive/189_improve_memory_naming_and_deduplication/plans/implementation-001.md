# Implementation Plan: Task #189

- **Task**: 189 - improve_memory_naming_and_deduplication
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This plan implements semantic slug-based naming for memories and enhances the deduplication workflow. The current `MEM-{date}-{unix_ms}-{random_4}` naming convention duplicates information already present in frontmatter metadata and makes manual navigation difficult. The new approach uses semantic slugs (e.g., `telescope-custom-pickers.md`) with standardized metadata fields (`created`, `modified`) while preserving the existing robust overlap detection system.

### Research Integration

Key findings from research-001.md integrated:
- Current ID generation uses redundant date/timestamp in both filename and frontmatter
- Existing overlap scoring (Jaccard similarity with 60%/30% thresholds) is well-designed
- Best practices favor semantic filenames with metadata-based date tracking
- Codebase patterns (specs/ directories) demonstrate preference for semantic slugs with numeric prefixes

## Goals & Non-Goals

**Goals**:
- Replace `MEM-{date}-{unix_ms}-{random}` naming with semantic slugs
- Rename `date` field to `created` and `last_updated` to `modified`
- Remove `id` field from frontmatter (filename becomes identifier)
- Update grep fallback patterns from `MEM-*.md` to `*.md` in 10-Memories/
- Ensure both .claude/ and .opencode/ memory extensions are updated consistently
- Update memory template and README generation patterns

**Non-Goals**:
- Adding semantic embedding-based deduplication (current keyword overlap is sufficient)
- Creating automated migration of existing memories (manual or future task)
- Adding keyword-index.json optimization (optional enhancement for future)
- Modifying the overlap scoring thresholds (already well-calibrated)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Slug collisions | M | L | Append `-2`, `-3` suffix; overlap scoring catches most cases before CREATE |
| Breaking existing memories | M | L | Only new memories use new format; existing memories unchanged |
| Obsidian link breakage | L | L | New memories use `[[slug]]` format; existing links preserved |
| grep fallback compatibility | M | M | Update pattern from `MEM-*.md` to `*.md` in 10-Memories directory |

## Implementation Phases

### Phase 1: Update Memory Template [NOT STARTED]

**Goal**: Update frontmatter template to use new field names and remove id field

**Tasks**:
- [ ] Edit `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md`:
  - Remove `id: MEM-{{date}}-{{sequence}}` field
  - Rename `date:` to `created:`
  - Rename `last_updated:` to `modified:`
  - Keep `title`, `tags`, `topic`, `source` fields unchanged
- [ ] Edit `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` with identical changes
- [ ] Verify `.memory/30-Templates/memory-template.md` (root vault) exists and update if present

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md` - Frontmatter field updates
- `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Same changes
- `.memory/30-Templates/memory-template.md` - Same changes (if exists)

**Verification**:
- Read updated templates and confirm:
  - No `id:` field present
  - `created:` replaces `date:`
  - `modified:` replaces `last_updated:`

---

### Phase 2: Implement Slug Generation Algorithm [NOT STARTED]

**Goal**: Add slug generation logic to SKILL.md and replace ID generation

**Tasks**:
- [ ] Add slug generation algorithm to `.claude/extensions/memory/skills/skill-memory/SKILL.md`:
  ```bash
  generate_slug() {
    local topic="$1"
    local title="$2"
    local base=""

    # Priority 1: Topic path (most specific segment)
    if [ -n "$topic" ]; then
      base=$(echo "$topic" | rev | cut -d'/' -f1 | rev)
    fi

    # Priority 2: First 2-3 words of title
    local title_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9 ]/-/g' | tr ' ' '-' | \
      cut -d'-' -f1-3 | sed 's/-$//')

    # Combine
    if [ -n "$base" ]; then
      slug="${base}-${title_slug}"
    else
      slug="$title_slug"
    fi

    # Sanitize and truncate to 50 chars
    slug=$(echo "$slug" | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50)

    # Handle collision
    local final_slug="$slug"
    local counter=2
    while [ -f ".memory/10-Memories/${final_slug}.md" ]; do
      final_slug="${slug}-${counter}"
      counter=$((counter + 1))
    done

    echo "$final_slug"
  }
  ```
- [ ] Replace ID generation block (lines 313-322) with slug generation call
- [ ] Update CREATE operation template to use `${slug}.md` filename
- [ ] Update UPDATE and EXTEND operations to work with any filename pattern
- [ ] Apply identical changes to `.opencode/extensions/memory/skills/skill-memory/SKILL.md`

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add slug generation, update CREATE
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Grep for "MEM-" pattern in SKILL.md files - should only appear in historical examples
- Confirm generate_slug function exists in both files
- Check CREATE operation references `${slug}.md` not `MEM-${today}-*.md`

---

### Phase 3: Update Grep Fallback Patterns [NOT STARTED]

**Goal**: Update memory search patterns to find all .md files, not just MEM-* prefixed

**Tasks**:
- [ ] Update grep fallback path in Memory Search section (line ~181-184):
  - Change from: `grep -l -i "$keyword" .memory/10-Memories/MEM-*.md`
  - Change to: `grep -l -i "$keyword" .memory/10-Memories/*.md`
- [ ] Update index regeneration pattern (line ~404-405):
  - Change from: `ls .memory/10-Memories/MEM-*.md`
  - Change to: `find .memory/10-Memories -maxdepth 1 -name "*.md" -type f ! -name "README.md"`
- [ ] Update README regeneration comments to reference `*.md` pattern
- [ ] Apply identical changes to `.opencode/extensions/memory/skills/skill-memory/SKILL.md`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Grep pattern updates
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Grep for "MEM-\*.md" in SKILL.md files - should return no results
- Confirm new patterns use `*.md` with appropriate exclusions for README.md

---

### Phase 4: Update Index and README Generation [NOT STARTED]

**Goal**: Update index maintenance to handle semantic filenames and new metadata fields

**Tasks**:
- [ ] Update Index Maintenance section (line ~376-396):
  - Change README.md listing format from `MEM-YYYY-MM-DD-NNN` to filename-based
  - Update metadata extraction to use `created:` instead of `date:`
  - Update template to use `modified:` instead of `last_updated:`
- [ ] Update example entries in documentation:
  - Change `MEM-2026-03-05-042` references to semantic slug examples
  - Update Search Result Presentation section with new filename format
- [ ] Update `.memory/10-Memories/README.md` structure comment:
  - Change from: `### [MEM-YYYY-MM-DD-NNN](MEM-YYYY-MM-DD-NNN.md)`
  - Change to: `### [{slug}]({slug}.md)`
- [ ] Apply identical changes to `.opencode/extensions/memory/skills/skill-memory/SKILL.md`

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Index maintenance updates
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Grep for "MEM-YYYY" or "MEM-2026" in SKILL.md - should only appear if explicitly documenting old format
- Confirm index extraction uses `created:` field
- Confirm README generation template uses slug-based linking

---

### Phase 5: Synchronize Root Memory Vault [NOT STARTED]

**Goal**: Ensure root .memory/ vault template is consistent with extension templates

**Tasks**:
- [ ] Check if `.memory/30-Templates/memory-template.md` exists at project root
- [ ] If exists, update with same frontmatter changes as Phase 1
- [ ] Verify `.memory/10-Memories/README.md` structure is compatible with new format
- [ ] Update any hardcoded MEM-* references in root vault files

**Timing**: 15 minutes

**Files to modify**:
- `.memory/30-Templates/memory-template.md` - Frontmatter updates (if exists)
- `.memory/10-Memories/README.md` - Header/structure updates (if needed)

**Verification**:
- Confirm all three template locations use identical frontmatter structure
- No MEM-* patterns in root vault configuration files

---

### Phase 6: Documentation and Verification [NOT STARTED]

**Goal**: Update documentation and perform end-to-end verification

**Tasks**:
- [ ] Update examples in SKILL.md to use semantic slugs consistently
- [ ] Update any remaining `id:` field references in documentation
- [ ] Create summary of changes for implementation summary
- [ ] Verify both .claude/ and .opencode/ SKILL.md files are identical (diff check)
- [ ] Verify template files across all three locations are consistent

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Documentation examples
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Run: `diff .claude/extensions/memory/skills/skill-memory/SKILL.md .opencode/extensions/memory/skills/skill-memory/SKILL.md` - expect no differences
- Grep across all memory-related files for "MEM-" patterns - should only appear in explicit migration notes or historical context
- Confirm all frontmatter examples use `created:` and `modified:`

---

## Testing & Validation

- [ ] Template verification: All three template files use `created:`/`modified:` fields, no `id:` field
- [ ] SKILL.md consistency: `.claude/` and `.opencode/` versions are identical
- [ ] Grep patterns: No remaining `MEM-*.md` patterns (except in migration documentation)
- [ ] Slug generation: Function exists and handles collision with `-N` suffix
- [ ] Index maintenance: Uses `*.md` pattern with README.md exclusion
- [ ] Metadata extraction: Uses `created:` field for date extraction

## Artifacts & Outputs

- `specs/189_improve_memory_naming_and_deduplication/plans/implementation-001.md` (this file)
- `specs/189_improve_memory_naming_and_deduplication/summaries/implementation-summary-YYYYMMDD.md` (on completion)
- Modified files:
  - `.claude/extensions/memory/skills/skill-memory/SKILL.md`
  - `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
  - `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md`
  - `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md`
  - `.memory/30-Templates/memory-template.md` (if exists)

## Rollback/Contingency

- All changes are to .claude/ and .opencode/ extension files, not to actual memory content
- If issues arise, revert commits affecting SKILL.md and template files
- Existing memories (if any) are unaffected - they retain their MEM-* filenames
- New memories will use slug-based naming; this is forward-compatible
- Git history preserves all previous versions for reference
