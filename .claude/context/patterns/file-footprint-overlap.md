# File Footprint Overlap Detection

Canonical, single-source definition of the directory-prefix overlap algorithm used to decide
whether two tasks (or two phases within a task) touch the same files and should therefore be
serialized rather than dispatched concurrently.

This document defines the algorithm exactly once. Every consumer references this file by path
and never restates or re-derives the rule.

## Path Normalization

Before comparison, normalize every path string:
- Strip any trailing slash (`"foo/bar/"` becomes `"foo/bar"`).
- Treat paths as repo-relative strings; no filesystem resolution, symlink following, or
  existence check is performed (paths declared in `file_scope` need not exist yet).

## Overlap Rule

Two normalized path entries `pathA` and `pathB` **overlap** if any of the following holds:

1. **Exact match**: `pathA == pathB`.
2. **`pathA` is a directory-prefix ancestor of `pathB`**: `pathB` starts with `pathA + "/"`.
3. **`pathB` is a directory-prefix ancestor of `pathA`**: `pathA` starts with `pathB + "/"`.

This is **directory-prefix matching only** — there is no glob or regex matching. A path entry
that names a directory (with or without a trailing slash, after normalization) is treated as
covering every path beneath it.

### Directory-vs-file example

`.claude/skills/skill-implementer/` (a directory entry) overlaps with
`.claude/skills/skill-implementer/SKILL.md` (a file entry) under rule 2: the file path starts
with the directory path plus `/`. This is the typical case a file-scope entry is meant to catch —
one task declaring the whole skill directory as its scope, another declaring just the one file
inside it.

## Pairwise-Over-a-Set Pseudocode

To detect overlap across a set of tasks (or phases), each carrying a `file_scope` (or
`files_touched`) array, compare every unordered pair:

```
function normalize(path):
  return path.rstrip("/")

function overlaps(pathA, pathB):
  a = normalize(pathA)
  b = normalize(pathB)
  if a == b: return true
  if b.startswith(a + "/"): return true
  if a.startswith(b + "/"): return true
  return false

function has_overlap(scopeA: list[str], scopeB: list[str]) -> bool:
  for pathA in scopeA:
    for pathB in scopeB:
      if overlaps(pathA, pathB):
        return true
  return false

function find_overlapping_pairs(items: list[{id, file_scope}]) -> list[(id, id)]:
  pairs = []
  for i in range(len(items)):
    for j in range(i + 1, len(items)):
      if has_overlap(items[i].file_scope, items[j].file_scope):
        pairs.append((items[i].id, items[j].id))
  return pairs
```

This is an O(n^2) pairwise scan over the items in a single batch (task-creation batch, or the
phase list of a single task) — it is deliberately not a repo-wide scan and does not attempt to
compare across unrelated batches.

## Consumers

This algorithm has two callers, one at the task level and one at the phase level:

- **Task-level**: Multi-Task Creation Standard Component **4a** (File Footprint Capture and
  Overlap Detection) — see
  `.claude/docs/reference/standards/multi-task-creation-standard.md` — runs this algorithm
  pairwise across a batch of proposed tasks' `file_scope` entries and auto-adds a serializing
  `dependencies[]` edge on overlap.
- **Phase-level**: `skill-team-implement/SKILL.md` Stage 5's `infer_from_file_overlap(phase,
  phases)` — runs this algorithm pairwise across a single task's phase list (using each phase's
  declared or inferred file touch-set) to decide whether phases can execute in parallel or must
  be serialized.

Both callers reference this document by path; neither restates the normalization or overlap
rule inline.

## Non-Goals

- No glob or regex matching (e.g. `*.lua`, `**/test_*`) — only literal directory-prefix
  containment.
- No repo-wide scan across all tasks in `state.json` — callers apply this only within the small
  set of items already collected for their operation (a creation batch, or a task's phase list).
- No filesystem validation of declared paths.
