# Research Report: Task #734 — Detailed Change Specification

**Task**: 734 — Optimize CSLib build cache strategy
**Started**: 2026-06-16T00:00:00Z
**Completed**: 2026-06-16T00:30:00Z
**Effort**: ~30 min (file reading + exact-text derivation)
**Dependencies**: Report 01 (01_build-cache-research.md)
**Sources/Inputs**:
- `specs/734_optimize_cslib_build_cache_strategy/reports/01_build-cache-research.md`
- `.claude/extensions/cslib/agents/cslib-implementation-agent.md` (502 lines)
- `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` (107 lines)
- `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` (333 lines)
- `.claude/extensions/cslib/rules/cslib.md` (149 lines)
**Artifacts**:
- `specs/734_optimize_cslib_build_cache_strategy/reports/02_detailed-change-spec.md` (this file)
**Standards**: report-format.md, artifact-formats.md

---

## Executive Summary

- Three files require edits; the hard-mode skill is **not** a parallel-change target (it delegates to `cslib-implementation-hard-agent`, not `cslib-implementation-agent`, and has no CI pipeline section).
- Change 1 (agent CI pipeline) is the highest-impact fix: insert `lake exe cache get` as Step 0 before the existing "Scoped build" block at line 196 of `cslib-implementation-agent.md`.
- Change 2 (skill preflight) inserts a new `### Stage 2b: Preflight Cache Warming` section between Stage 2 and Stage 3 in `skill-cslib-implementation/SKILL.md`; no parallel change is needed for the hard-mode skill since it adds its own cache-warming section independently.
- Change 3 (rules CI order) adds `0. \`lake exe cache get\`` as the first list item in `cslib.md` under "CSLib CI Verification Order".
- Changes 4 and 5 from Report 01 (deferred CI for PR tasks; agent-init cache step) are lower priority — Change 4 in particular requires careful scoping to avoid breaking the PR-description mode detection logic.
- The `MUST NOT` bullet in `skill-cslib-implementation-hard/SKILL.md` explicitly states that changes to `skill-cslib-implementation` postflight should be mirrored there; however, the _preflight_ cache warming (Change 2) is a new preflight addition with no equivalent in the hard-mode skill, so it should be added there too as a separate Stage 2b block.

---

## Context & Scope

This report translates the 6 proposed changes from Report 01 into implementer-ready
`old_string` / `new_string` pairs. Every pair can be applied verbatim as an Edit tool
call. Line numbers from the current file state are provided for navigation; the actual
match is done by exact string, not by line number.

Files:
| File | Absolute Path | Length |
|------|--------------|--------|
| cslib-implementation-agent.md | `.claude/extensions/cslib/agents/cslib-implementation-agent.md` | 502 lines |
| skill-cslib-implementation/SKILL.md | `.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md` | 107 lines |
| skill-cslib-implementation-hard/SKILL.md | `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` | 333 lines |
| cslib.md | `.claude/extensions/cslib/rules/cslib.md` | 149 lines |

---

## Findings

### 1. cslib-implementation-agent.md — CI Pipeline Section (Lines 194-243)

**Current state** (lines 194-243):

```
---

### CSLib CI Pipeline (Ordered -- Run All Steps)

1. **Scoped build**:
   ```bash
   lake build Module.Name
   ```
   Builds only the modified module. Fast, catches most compilation errors.

2. **Check Init imports**:
   ...
```

The pipeline has 7 numbered steps (1-7) and two additional checks (8-10 under "Additional Verification Checks"). Step 0 (`lake exe cache get`) is completely absent.

**Also**: the MUST DO list at line 470 references "all 7 steps" — this count needs updating to 8 steps when Step 0 is added.

**Also**: the PR Description Mode section at lines 169-191 already contains the correct detection
logic. No change needed there.

---

### 2. skill-cslib-implementation/SKILL.md — Preflight Stages (Lines 18-50)

**Current state**: The execution flow jumps directly from Stage 2 (preflight status update) to Stage 3 (prepare delegation context). There is no cache warming between them.

Stage 2 ends at line 22 with a single sentence:
```
Update status to "implementing" BEFORE invoking subagent.
```

Stage 3 begins at line 26 with:
```
### Stage 3: Prepare Delegation Context
```

There is no Stage 2b.

---

### 3. skill-cslib-implementation-hard/SKILL.md — Parallel Cache Warming

The hard-mode skill has `### Stage 2: Preflight Status Update` at line 79 and jumps to
`### Stage 3: Create Postflight Marker` at line 87. It also needs a Stage 2b inserted
between them.

The maintenance note at line 20 states:
> **Maintenance note**: changes to `skill-cslib-implementation` postflight should be mirrored here.

This says "postflight" — but the intent is clearly that the skills stay in sync. Since
preflight cache warming is a safety measure that benefits all cslib implementation tasks,
adding it here avoids the case where `--hard` mode skips the warm-up.

---

### 4. cslib.md — CI Verification Order (Lines 76-86)

**Current state** (lines 76-87):

```
### CSLib CI Verification Order

Run in this order before submitting a PR:

1. `lake build` -- syntax linters (runs during build)
2. `lake exe checkInitImports` -- all files import `Cslib.Init`
3. `lake lint` -- environment linters (or use `#lint` command in editor)
4. `lake exe lint-style` -- text linters (or `--fix` to auto-fix)
5. `lake test` -- run `CslibTests/`
6. `lake exe mk_all --module` -- update `Cslib.lean` barrel import (only when adding new files)
7. `lake shake --add-public --keep-implied --keep-prefix` -- import minimization (or `--fix`)
```

The list runs 1-7; `lake exe cache get` as Step 0 is absent.

---

## Decisions

1. **Change 4 (deferred CI for PR tasks) is excluded from this specification.** The current
   PR-description mode detection logic in `cslib-implementation-agent.md` (lines 169-191) is
   correct for pure PR-description tasks. Expanding it to cover PR-revision tasks that modify
   Lean files introduces risk (agent might return "implemented" without verifying compilation of
   Lean changes). This is left as a follow-up discussion item, not an immediate edit.

2. **Change 5 (agent-init cache step) is folded into Change 1.** Adding a separate Stage 0b
   for cache warming would duplicate logic that is already covered by inserting Step 0 into the
   CI pipeline. The implementer should add the cache step once (in the CI pipeline section) rather
   than in two places in the same agent file.

3. **Change 6 (main-branch pre-build) is excluded.** Report 01 marked it P3 and flagged it as
   fragile. Out of scope for this implementation.

4. **skill-cslib-implementation-hard/SKILL.md does receive a parallel Stage 2b**, despite the
   maintenance note saying only "postflight" changes are mirrored. The preflight warm-up is
   equally important for hard-mode runs.

---

## Recommendations (Implementer Instructions)

Apply changes in this order. Each change is a self-contained Edit tool call.

---

### Edit A — cslib-implementation-agent.md: Add Step 0 to CI Pipeline

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md`

**Anchor** (lines 192-199 — unique in file):

```
old_string: "---\n\n### CSLib CI Pipeline (Ordered -- Run All Steps)\n\n1. **Scoped build**:\n   ```bash\n   lake build Module.Name\n   ```\n   Builds only the modified module. Fast, catches most compilation errors."
```

**Replacement**:

```
new_string: "---\n\n### CSLib CI Pipeline (Ordered -- Run All Steps)\n\n0. **Mathlib cache fetch** (one-time, always first):\n   ```bash\n   cd /home/benjamin/Projects/cslib && lake exe cache get\n   ```\n   Downloads pre-built Mathlib `.olean` files. On cache hit (~1-2 min), subsequent\n   builds only compile CSLib modules (~2-5 min). On cache miss, this is a no-op\n   and `lake build` falls back to full compilation. Skip only if cache is already\n   confirmed warm for this branch.\n\n1. **Scoped build**:\n   ```bash\n   lake build Module.Name\n   ```\n   Builds only the modified module. Fast, catches most compilation errors."
```

**Exact old text** (copy-paste ready):
```
---

### CSLib CI Pipeline (Ordered -- Run All Steps)

1. **Scoped build**:
   ```bash
   lake build Module.Name
   ```
   Builds only the modified module. Fast, catches most compilation errors.
```

**Exact new text** (copy-paste ready):
```
---

### CSLib CI Pipeline (Ordered -- Run All Steps)

0. **Mathlib cache fetch** (one-time, always first):
   ```bash
   cd /home/benjamin/Projects/cslib && lake exe cache get
   ```
   Downloads pre-built Mathlib `.olean` files. On cache hit (~1-2 min), subsequent
   builds only compile CSLib modules (~2-5 min). On cache miss, this is a no-op
   and `lake build` falls back to full compilation. Skip only if cache is already
   confirmed warm for this branch.

1. **Scoped build**:
   ```bash
   lake build Module.Name
   ```
   Builds only the modified module. Fast, catches most compilation errors.
```

---

### Edit B — cslib-implementation-agent.md: Update Step Count in MUST DO List

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md`

This is the MUST DO list item at line 470 that mentions "all 7 steps":

**Exact old text**:
```
7. **Run the full CSLib CI pipeline** (all 7 steps) before returning implemented status -- EXCEPT in PR description mode (`task_type=pr`), where CI is deferred to the `/pr` command
```

**Exact new text**:
```
7. **Run the full CSLib CI pipeline** (all 8 steps, including Step 0 cache fetch) before returning implemented status -- EXCEPT in PR description mode (`task_type=pr`), where CI is deferred to the `/pr` command
```

---

### Edit C — skill-cslib-implementation/SKILL.md: Add Stage 2b Cache Warming

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`

**Exact old text** (lines 21-28):
```
### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 3: Prepare Delegation Context
```

**Exact new text**:
```
### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

### Stage 2b: Preflight Cache Warming

Ensure Mathlib cache is warm before delegating to the agent:

```bash
cd /home/benjamin/Projects/cslib && lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
```

This is non-blocking. Cache fetch failure does not prevent delegation. On a cache hit, this
completes in ~1-2 minutes and prevents 30-45 minute Mathlib rebuilds during CI verification.

### Stage 3: Prepare Delegation Context
```

---

### Edit D — skill-cslib-implementation-hard/SKILL.md: Add Stage 2b Cache Warming

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`

**Exact old text** (lines 79-87):
```
### Stage 2: Preflight Status Update

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 3: Create Postflight Marker
```

**Exact new text**:
```
### Stage 2: Preflight Status Update

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 2b: Preflight Cache Warming

Ensure Mathlib cache is warm before delegating to the agent:

```bash
cd /home/benjamin/Projects/cslib && lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
```

This is non-blocking. Cache fetch failure does not prevent delegation. On a cache hit, this
completes in ~1-2 minutes and prevents 30-45 minute Mathlib rebuilds during CI verification.

---

### Stage 3: Create Postflight Marker
```

---

### Edit E — cslib.md: Add Step 0 to CI Verification Order

**File**: `/home/benjamin/.config/nvim/.claude/extensions/cslib/rules/cslib.md`

**Exact old text** (lines 77-86):
```
### CSLib CI Verification Order

Run in this order before submitting a PR:

1. `lake build` -- syntax linters (runs during build)
2. `lake exe checkInitImports` -- all files import `Cslib.Init`
3. `lake lint` -- environment linters (or use `#lint` command in editor)
4. `lake exe lint-style` -- text linters (or `--fix` to auto-fix)
5. `lake test` -- run `CslibTests/`
6. `lake exe mk_all --module` -- update `Cslib.lean` barrel import (only when adding new files)
7. `lake shake --add-public --keep-implied --keep-prefix` -- import minimization (or `--fix`)
```

**Exact new text**:
```
### CSLib CI Verification Order

Run in this order before submitting a PR:

0. `lake exe cache get` -- fetch Mathlib .olean cache (once per branch; prevents 30-45 min rebuild)
1. `lake build` -- syntax linters (runs during build)
2. `lake exe checkInitImports` -- all files import `Cslib.Init`
3. `lake lint` -- environment linters (or use `#lint` command in editor)
4. `lake exe lint-style` -- text linters (or `--fix` to auto-fix)
5. `lake test` -- run `CslibTests/`
6. `lake exe mk_all --module` -- update `Cslib.lean` barrel import (only when adding new files)
7. `lake shake --add-public --keep-implied --keep-prefix` -- import minimization (or `--fix`)
```

---

## Routing Verification

**Question from focus prompt**: Do PR-type implementation tasks go through `cslib-implementation-agent`? Where does the CI pipeline actually run?

**Answer** (from manifest + skill inspection):

```
/implement N (task_type=pr, no sources field)
  -> manifest: implement.pr -> skill-pr-review-implementation
    -> skill-pr-review-implementation reads state.json for sources
       IF sources absent/empty -> dispatches cslib-implementation-agent (legacy path)
       IF sources present      -> dispatches pr-review-implementation-agent (review path)
```

For the legacy path (PR description tasks with no sources), `cslib-implementation-agent` runs —
but its `PR Description Mode` detection (lines 169-191) **skips the CI pipeline entirely**:
> "Skip the CSLib CI Pipeline entirely (branch creation and CI are handled by the /pr command)"

So the CI pipeline (with or without cache warming) **only runs for cslib-type tasks** (task_type=cslib),
not for pr-type tasks routed to the legacy path. This means:
- **Edits A and B** (CI pipeline in agent): affect cslib tasks only — the PR description mode
  block guards the pipeline and prevents it from running for pr tasks. No change needed to that logic.
- **Edits C and D** (skill preflight): the cache warming runs unconditionally before delegation,
  regardless of task_type. For PR description tasks, the cache warm-up runs but is harmless
  (the agent immediately skips CI). This is acceptable since it only costs 1-2 min on a cache hit.

**Optional optimization**: For pr-type tasks routed to the legacy path, the cache warm-up in
Stage 2b of the skill is wasteful (the agent skips CI anyway). The implementer may add a guard:

```bash
# In Stage 2b of skill-cslib-implementation/SKILL.md:
if [ "$task_type" != "pr" ]; then
  cd /home/benjamin/Projects/cslib && lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
fi
```

This is a **nice-to-have**, not required. The default (unconditional warm-up) is safe and simpler.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `lake exe cache get` fails (network issue, stale token) | Low | Non-fatal; falls through to existing behavior |
| Cache fetch adds 1-2 min to tasks that don't need it (PR description) | Low | Acceptable cost; optionally guard with `task_type != pr` check |
| Step numbering confusion (Step 0 vs 1-indexed expectations) | Low | Use "Step 0" explicitly; matches `ci-pipeline.md` convention already |
| Hard-mode skill gets out of sync with base skill | Medium | Mitigated by Edit D which adds Stage 2b in parallel |
| `cd /home/benjamin/Projects/cslib` hardcodes project path | Low | Path is already hardcoded throughout the agent; consistent with existing style |

---

## Context Extension Recommendations

None — the relevant context files (`build-cache-strategy.md`, `ci-pipeline.md`) already document
the correct behavior. These edits bring the agent and skill instructions into alignment with the
already-correct documentation.

---

## Appendix

### File Locations (absolute paths)

- `/home/benjamin/.config/nvim/.claude/extensions/cslib/agents/cslib-implementation-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/cslib/rules/cslib.md`

### Key Line Numbers (for navigation; Edit tool uses string matching)

| Edit | File | Anchor Line(s) |
|------|------|----------------|
| A (CI pipeline Step 0) | cslib-implementation-agent.md | 192-199 |
| B (MUST DO step count) | cslib-implementation-agent.md | 470 |
| C (skill Stage 2b) | skill-cslib-implementation/SKILL.md | 21-26 |
| D (hard-skill Stage 2b) | skill-cslib-implementation-hard/SKILL.md | 79-87 |
| E (rules Step 0) | cslib.md | 77-86 |

### Change Priority Summary

| Edit | Impact | Effort | Priority |
|------|--------|--------|---------|
| A: CI pipeline Step 0 | Eliminates 30-45 min Mathlib rebuild | Trivial | P0 |
| C: Skill Stage 2b cache warm | Warms cache before agent starts | Trivial | P0 |
| D: Hard-skill Stage 2b | Mirrors C for --hard runs | Trivial | P0 |
| E: Rules Step 0 | Correctness alignment | Trivial | P1 |
| B: Step count update | Accuracy in MUST DO list | Trivial | P1 |
