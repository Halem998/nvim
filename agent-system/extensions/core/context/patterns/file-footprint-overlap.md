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

This algorithm has four callers, at the task, phase, lock-acquisition, and batch-admission
levels:

- **Task-level**: Multi-Task Creation Standard Component **4a** (File Footprint Capture and
  Overlap Detection) — see
  `.claude/docs/reference/standards/multi-task-creation-standard.md` — runs this algorithm
  pairwise across a batch of proposed tasks' `file_scope` entries and auto-adds a serializing
  `dependencies[]` edge on overlap.
- **Phase-level**: `skill-team-implement/SKILL.md` Stage 5's `infer_from_file_overlap(phase,
  phases)` — runs this algorithm pairwise across a single task's phase list (using each phase's
  declared or inferred file touch-set) to decide whether phases can execute in parallel or must
  be serialized.
- **Lock-acquisition-level** (task 809): `.claude/scripts/task-lock.sh`'s `cmd_acquire`, via the
  `scopes_overlap()` jq transcription of this file's pseudocode, checks the acquiring task's
  `file_scope` against every OTHER currently-held lock's `file_scope` repo-wide (see
  `task-lock.md`'s "Cross-Task `file_scope` Overlap Check"). Unlike the two callers above, this
  is a live, repo-wide scan at acquire time rather than a one-shot pairwise pass over a fixed
  batch — see the Non-Goals note below on scan scope.
- **Batch-admission-level**: `.claude/scripts/orchestrate-batch-admit.sh` checks each candidate
  task's `file_scope` against every non-terminal task in `specs/state.json` — one read, no
  filesystem scan — closing the gap the task-level and phase-level callers leave open for tasks
  created in *separate* batches with no `dependencies[]` edge between them, and that the
  lock-acquisition-level caller leaves open for a non-terminal, unlocked, out-of-batch task (it
  only sees currently-held locks). Consumers: `commands/orchestrate.md` Step 3 (pre-computed wave
  schedule) and `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 (per-cycle eligibility
  gate). See `docs/architecture/batch-admit-schema.md` for the verdict schema this caller emits.

All four callers reference this document by path; none restates the normalization or overlap
rule inline.

## Non-Goals

- No glob or regex matching (e.g. `*.lua`, `**/test_*`) — only literal directory-prefix
  containment.
- No filesystem validation of declared paths.
- No opinion on scan scope: this document defines the overlap PREDICATE only
  (`overlaps(pathA, pathB)` and its pairwise-set application), not how widely a caller applies
  it. The task-level and phase-level callers apply it within a small, already-collected batch (a
  creation batch, or a task's phase list); the lock-acquisition-level caller (task 809) applies
  it repo-wide, scanning every currently-held lock in `specs/` at acquire time; the
  batch-admission-level caller applies it repo-wide via a single `specs/state.json` read,
  comparing against every non-terminal task regardless of lock or batch membership. All three
  scan-scope shapes are in scope for this algorithm — each caller chooses its own scan scope, and
  this document is not extended or forked to accommodate the difference.
