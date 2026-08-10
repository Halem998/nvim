# Implementation Plan: Refactor cslib specs/literature/ to sources/ Structure

- **Task**: 737 - Refactor cslib specs/literature/ to sources/ structure and remove blackburn_2001
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_cslib-refactor-research.md
- **Artifacts**: plans/01_cslib-refactor-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Refactor ~/Projects/cslib/specs/literature/ to use a `sources/` subdirectory structure matching the centralized Literature/ repository. This involves creating individual directories for 11 loose markdown files, moving 6 content subdirectories into `sources/`, relocating chagrov_1997.djvu, deleting blackburn_2001/, and updating index.json paths. All operations are shell commands.

### Research Integration

Research identified 11 loose markdown files, 7 subdirectories (1 to remove), 1 DJVU source file, and an index.json with 76 flat-path entries. The blackburn_2001/ directory should be removed entirely (matches Literature/ repo cleanup).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances Phase 2 "Literature centralization" follow-up work -- the centralized Literature/ repo (task 710) is complete; this task brings cslib's local specs/literature/ into alignment with the sources/ directory convention.

## Goals & Non-Goals

**Goals**:
- All content files under `sources/{id}/` subdirectories
- blackburn_2001/ removed completely
- chagrov_1997.djvu co-located with its content directory
- index.json paths updated with `sources/` prefix, blackburn_2001 entries removed
- README.md path references updated

**Non-Goals**:
- Adding new literature entries
- Converting any source files (DJVU to markdown)
- Modifying file content (only paths change)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Incorrect index.json path transformation | M | L | Verify with jq query before and after |
| Missing files after move | M | L | Run `find` to verify all files are under sources/ |
| Git history loss | L | L | Git tracks renames; single commit captures all moves |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Filesystem Restructuring [NOT STARTED]

**Goal**: Create sources/ directory structure, move all content, delete blackburn_2001/

**Tasks**:
- [ ] Create `sources/` directory under `~/Projects/cslib/specs/literature/`
- [ ] Create individual directories for 11 loose markdown files:
  ```bash
  cd ~/Projects/cslib/specs/literature
  for f in bentzen_2023.md burgess_1982_i.md burgess_1982_ii.md burgess_1984.md from_2022.md gabbay_1994_ch10.md henkin_1949.md johansson_1937.md post_1921.md reynolds_1992.md trufas_2024.md; do
    id="${f%.md}"
    mkdir -p "sources/$id"
    mv "$f" "sources/$id/"
  done
  ```
- [ ] Move 6 content subdirectories into `sources/`:
  ```bash
  for d in chagrov_1997 church_1956 gentzen_1935 hughes_1996 mendelson_2016 zakharyaschev_2001; do
    mv "$d" "sources/"
  done
  ```
- [ ] Move chagrov_1997.djvu into its content directory:
  ```bash
  mv chagrov_1997.djvu sources/chagrov_1997/
  ```
- [ ] Remove blackburn_2001/ entirely:
  ```bash
  rm -rf blackburn_2001
  ```
- [ ] Verify all content is under sources/:
  ```bash
  find sources/ -type f | wc -l
  ls -la  # should only show sources/, index.json, README.md
  ```

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `~/Projects/cslib/specs/literature/` - directory restructuring

**Verification**:
- `ls ~/Projects/cslib/specs/literature/` shows only `sources/`, `index.json`, `README.md`
- All 11 loose files are in their own `sources/{id}/` directories
- 6 subdirectories are under `sources/`
- chagrov_1997.djvu is at `sources/chagrov_1997/chagrov_1997.djvu`
- blackburn_2001/ does not exist

---

### Phase 2: Index and Metadata Updates [NOT STARTED]

**Goal**: Update index.json paths and remove blackburn_2001 entries; update README.md

**Tasks**:
- [ ] Count blackburn_2001 entries in index.json before removal:
  ```bash
  jq '[.[] | select(.id | startswith("blackburn_2001"))] | length' index.json
  ```
- [ ] Remove all blackburn_2001 entries and prefix remaining paths with `sources/`:
  ```bash
  jq '[.[] | select(.id | startswith("blackburn_2001") | not) | .path = "sources/" + .path]' index.json > index.json.tmp && mv index.json.tmp index.json
  ```
- [ ] Verify index.json: all paths start with `sources/`, no blackburn entries:
  ```bash
  jq '[.[] | select(.path | startswith("sources/") | not)] | length' index.json  # should be 0
  jq '[.[] | select(.id | startswith("blackburn_2001"))] | length' index.json  # should be 0
  ```
- [ ] Update README.md if it references old paths (inspect and edit as needed)
- [ ] Verify all index paths resolve to actual files:
  ```bash
  jq -r '.[].path' index.json | while read p; do
    [ -f "$p" ] || echo "MISSING: $p"
  done
  ```

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `~/Projects/cslib/specs/literature/index.json` - path prefix update, entry removal
- `~/Projects/cslib/specs/literature/README.md` - path reference updates

**Verification**:
- `jq length index.json` returns count less than 76 (blackburn entries removed)
- All remaining paths start with `sources/`
- All paths in index.json resolve to existing files
- No blackburn_2001 references in README.md

## Testing & Validation

- [ ] `ls ~/Projects/cslib/specs/literature/` shows only sources/, index.json, README.md
- [ ] `find sources/ -name "*.md" | wc -l` matches expected count
- [ ] All index.json paths resolve to existing files
- [ ] No blackburn_2001 references anywhere in the directory
- [ ] `git diff --stat` shows renames detected properly

## Artifacts & Outputs

- plans/01_cslib-refactor-plan.md (this file)
- summaries/01_cslib-refactor-summary.md (after implementation)

## Rollback/Contingency

All operations are git-tracked. To revert:
```bash
cd ~/Projects/cslib
git checkout -- specs/literature/
```
