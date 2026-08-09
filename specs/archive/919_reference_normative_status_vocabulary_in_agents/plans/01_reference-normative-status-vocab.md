# Implementation Plan: Task #919

- **Task**: 919 - reference_normative_status_vocabulary_in_agents
- **Status**: [COMPLETED]
- **Effort**: 2.0 hours
- **Dependencies**: None
- **Research Inputs**: specs/919_reference_normative_status_vocabulary_in_agents/reports/01_reference-normative-status-vocab.md
- **Artifacts**: plans/01_reference-normative-status-vocab.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fifteen extension agent definitions instruct the agent to write `.return-meta.json` but never
point at `context/formats/return-metadata-file.md`, the normative source for the seven-value
status enum. With nothing to point at, agents improvise off-schema values (`"success"` was
observed live from `lean-research-agent`, stranding a task in its in-flight status despite a
valid report artifact). The fix is fifteen mechanically-identical reference insertions, all
targeting the ONE existing normative file — never a copy-paste of the enum table, which is the
exact drift mechanism being corrected.

Two structural shapes exist and are handled separately: 13 files have no `## Context References`
section and need one created between `## Overview` and `## Agent Metadata` (mirroring
`lean-implementation-agent.md`); the 2 `web/` agents already have such a section and need a new
leading bullet added inside it, never a duplicate section.

### Research Integration

Key findings carried into this plan:

- **Structural template is `lean-implementation-agent.md`**, not `planner-agent.md` /
  `general-implementation-agent.md` — the latter two use a core-agent skeleton with no
  `## Agent Metadata` section, so their placement slot does not exist in the 15 targets.
- **Insertion anchor verified uniform**: all 13 non-web targets have `## Overview` at line 9
  followed directly by `## Agent Metadata` (confirmed by heading scan during planning). The
  new section slots between them in every case.
- **Deploy-path form is mandatory**: `@.claude/context/formats/return-metadata-file.md`
  verbatim, never an `agent-system/extensions/...`-relative path. Every existing `@`-reference
  in the source store — including inside sibling extension dirs — uses the deploy-path prefix,
  because the deploy step merges each extension's `context/` tree into `.claude/context/`.
- **No shared touchpoint exists**: no template file is `@`-referenced by all 15 today; each
  agent file is a self-contained prompt. The "prefer a single shared reference" requirement is
  satisfied by all 15 pointing at the same normative file.

**Correction to the research report** (verified during planning, must be honored by the
implementer): the report states that *both* `pr-review-implementation-agent.md` and
`pr-review-research-agent.md` nest `completion_data` inside `metadata`. Only
`pr-review-implementation-agent.md` does (line ~322). `pr-review-research-agent.md` contains no
`completion_data` key at all, which is correct — `completion_data` is required only for
`implemented` status, and that agent terminates at `researched`. Phase 4 therefore edits ONE
file, not two.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- All 15 named agent files under `agent-system/extensions/**` reference
  `@.claude/context/formats/return-metadata-file.md`.
- The reference is placed per the established convention for each file's structural shape
  (new section for 13, new leading bullet for 2).
- The one real schema violation in the edit set (`completion_data` nested inside `metadata` in
  `pr-review-implementation-agent.md`) is corrected, since that file is already being opened
  and the marginal cost is a single JSON-block re-indent.
- Every edit lands in the source store; zero writes to `.claude/**`.

**Non-Goals**:
- **Adding handoff-writing contracts to any of these agents.** Handoffs are written by SKILLS
  when `orchestrator_mode` is true, never by agents. Base-mode research/plan/implement
  dispatches never write a handoff by contractual design and rely on the `.return-meta.json`
  recovery path. Adding handoff writing would move base-mode dispatches OFF the guarded recovery
  path ONTO the unguarded handoff-read path, making the defect strictly MORE reachable. This is
  a hard scope boundary, not a preference.
- **Restating the status enum inline** in any of the 15 files. The reference IS the fix.
- **Authoring worked JSON examples for the 8 zero-example files** (`latex`, `python`, `typst`,
  `z3` — both agents each). See "Deferred, with reasoning" below.
- Any edit under `.claude/**` (gitignored, disposable deploy artifact).
- Any task-number citation in a file outside `specs/**`.

### Deferred, with reasoning (explicit decision, not an oversight)

**The 8 zero-example files get the reference only, no new worked examples.** Rationale: authoring
a correct terminal-status JSON example in each of 8 files is content authoring, not a mechanical
insertion — it multiplies the surface that can drift out of sync with the normative source, which
is the precise failure mode this task exists to correct. The `@`-reference gives those 8 files
access to the canonical `Research Success` / `Implementation Success` examples in
`return-metadata-file.md` (lines ~396-471) without creating 8 new copies to maintain. If a
follow-up decides local examples are still warranted, that is a separate task with its own
consistency-verification design.

**The `pr-review-implementation-agent.md` nesting bug is folded IN, not deferred.** Rationale
for the asymmetry with the paragraph above: it is a *deletion of drift* (moving a key that is
already there to its correct position), not an *addition of a new copy*, the file is already in
the edit set, and leaving a live schema violation in place while adding a pointer to the schema
that contradicts it would be actively confusing to a future reader.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits `.claude/**` instead of `agent-system/extensions/**` | H | M | Every phase's verification includes `git status --porcelain \| grep '^.*\.claude/'` returning empty; phase task lists give full source-store paths |
| Phrasing/placement drift across 15 near-identical edits | M | M | Phases 1-3 specify one verbatim copy-paste block; Phase 5 greps that the exact bullet string appears in all 15 |
| Scope creep into handoff contracts | H | L | Non-Goals states the mechanism by which this makes the defect worse; Phase 5 greps for `orchestrator-handoff` additions in the diff |
| Duplicate `## Context References` section created in the 2 web files | M | M | Phase 3 is a separate phase precisely to isolate the different shape; its verification asserts `grep -c '^## Context References' == 1` |
| Task-number citations leak into agent files | M | L | Phase 5 greps the diff for `task [0-9]` outside `specs/**` |
| Phase 2 and Phase 4 both edit `pr-review-implementation-agent.md` | L | M | Phase 4 declared dependent on Phase 2, so they never run concurrently |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 2 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 touch disjoint file sets
and may be dispatched concurrently with territory boundaries as listed.

### The canonical insertion block (used verbatim by Phases 1 and 2)

Insert exactly this, between the end of the `## Overview` section (after its `**IMPORTANT**: ...`
paragraph where one is present) and the `## Agent Metadata` heading:

```markdown
## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema and the normative
  status vocabulary (always load before writing final metadata)

```

Blank line before `## Agent Metadata` is preserved. Do not alter any other line in the file.

---

### Phase 1: Reference insertion — zero-example tier (8 files) [COMPLETED]

**Goal**: Add the `## Context References` section to the eight agent files that currently have
no JSON examples and no `@`-references of any kind — the most severe instances of the gap.

**Tasks**:
- [x] Insert the canonical block into `latex/agents/latex-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `latex/agents/latex-research-agent.md` *(completed)*
- [x] Insert the canonical block into `python/agents/python-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `python/agents/python-research-agent.md` *(completed)*
- [x] Insert the canonical block into `typst/agents/typst-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `typst/agents/typst-research-agent.md` *(completed)*
- [x] Insert the canonical block into `z3/agents/z3-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `z3/agents/z3-research-agent.md` *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify** (all relative to `agent-system/extensions/`):
- `latex/agents/latex-implementation-agent.md` - new `## Context References` section after Overview
- `latex/agents/latex-research-agent.md` - same
- `python/agents/python-implementation-agent.md` - same
- `python/agents/python-research-agent.md` - same
- `typst/agents/typst-implementation-agent.md` - same
- `typst/agents/typst-research-agent.md` - same
- `z3/agents/z3-implementation-agent.md` - same
- `z3/agents/z3-research-agent.md` - same

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions
for f in latex/agents/latex-implementation-agent.md latex/agents/latex-research-agent.md \
         python/agents/python-implementation-agent.md python/agents/python-research-agent.md \
         typst/agents/typst-implementation-agent.md typst/agents/typst-research-agent.md \
         z3/agents/z3-implementation-agent.md z3/agents/z3-research-agent.md; do
  n=$(grep -c 'return-metadata-file' "$f")
  s=$(grep -c '^## Context References' "$f")
  # expect n>=1 and s==1, and Context References must precede Agent Metadata
  printf '%s refs=%s sections=%s order=%s\n' "$f" "$n" "$s" \
    "$(grep -n '^## \(Context References\|Agent Metadata\)' "$f" | head -2 | cut -d: -f2- | tr '\n' '|')"
done
```
- Each of the 8 reports `refs>=1` and `sections=1`.
- The `order` column reads `## Context References|## Agent Metadata|` for each.
- `cd /home/benjamin/.config/nvim && git status --porcelain | grep '\.claude/' ` returns nothing.

---

### Phase 2: Reference insertion — cslib and lean tier (5 files) [COMPLETED]

**Goal**: Add the `## Context References` section to the five remaining files that share the
13-file skeleton but are larger and have partial/interim JSON examples.

**Tasks**:
- [x] Insert the canonical block into `cslib/agents/cslib-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `cslib/agents/cslib-research-agent.md` *(completed)*
- [x] Insert the canonical block into `cslib/agents/pr-review-implementation-agent.md` *(completed)*
- [x] Insert the canonical block into `cslib/agents/pr-review-research-agent.md` *(completed)*
- [x] Insert the canonical block into `lean/agents/lean-research-agent.md` *(completed)*
- [x] Confirm no existing `## Literature Briefing Context` section was displaced (the two cslib
      non-pr agents have one immediately after `## Agent Metadata`; the new section goes BEFORE
      `## Agent Metadata`, leaving it untouched) *(completed: verified both counts still read 1)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify** (all relative to `agent-system/extensions/`):
- `cslib/agents/cslib-implementation-agent.md` - new section between Overview and Agent Metadata
- `cslib/agents/cslib-research-agent.md` - same
- `cslib/agents/pr-review-implementation-agent.md` - same
- `cslib/agents/pr-review-research-agent.md` - same
- `lean/agents/lean-research-agent.md` - same

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions
for f in cslib/agents/cslib-implementation-agent.md cslib/agents/cslib-research-agent.md \
         cslib/agents/pr-review-implementation-agent.md cslib/agents/pr-review-research-agent.md \
         lean/agents/lean-research-agent.md; do
  printf '%s refs=%s sections=%s\n' "$f" \
    "$(grep -c 'return-metadata-file' "$f")" "$(grep -c '^## Context References' "$f")"
done
grep -c '^## Literature Briefing Context' cslib/agents/cslib-implementation-agent.md
grep -c '^## Literature Briefing Context' cslib/agents/cslib-research-agent.md
```
- Each of the 5 reports `refs>=1` and `sections=1`.
- Both Literature Briefing counts still read `1`.
- `cd /home/benjamin/.config/nvim && git status --porcelain | grep '\.claude/'` returns nothing.

---

### Phase 3: Reference insertion — web tier, existing-section shape (2 files) [COMPLETED]

**Goal**: Add a new leading bullet to the `## Context References` section that already exists in
both web agents, without creating a second section and without weakening the "always load"
qualifier.

**Tasks**:
- [x] In `web/agents/web-implementation-agent.md`, immediately after the
      `Load these on-demand using @-references:` line and before the first
      `**Load for ...**:` subgroup, insert a new `**Load Always**:` subgroup containing the
      single bullet:
      `` - `@.claude/context/formats/return-metadata-file.md` - Metadata file schema and the normative status vocabulary (always load before writing final metadata) `` *(completed)*
- [x] Apply the identical insertion in `web/agents/web-research-agent.md` *(completed)*
- [x] Do NOT create a second `## Context References` heading in either file *(completed: verified sections=1 for both)*

**Rationale note for the implementer**: these sections are framed as "on-demand". That framing
describes the OTHER bullets. The `(always load)` qualifier must be carried anyway, matching how
every conforming agent in the codebase marks this specific file. The `**Load Always**:` subgroup
heading exists to make the exception visually explicit rather than burying an always-load bullet
in an on-demand list.

**Timing**: 0.3 hours

**Depends on**: none

**Files to modify** (relative to `agent-system/extensions/`):
- `web/agents/web-implementation-agent.md` - new leading bullet in existing section (~line 67)
- `web/agents/web-research-agent.md` - new leading bullet in existing section (~line 71)

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions
for f in web/agents/web-implementation-agent.md web/agents/web-research-agent.md; do
  printf '%s refs=%s sections=%s\n' "$f" \
    "$(grep -c 'return-metadata-file' "$f")" "$(grep -c '^## Context References' "$f")"
  grep -n -A6 '^## Context References' "$f"
done
```
- Both report `refs>=1` and **`sections=1`** (a value of 2 means a duplicate section was created
  and the phase must be redone).
- The printed excerpt shows the new bullet ahead of the pre-existing `**Load for ...**:` groups.
- `cd /home/benjamin/.config/nvim && git status --porcelain | grep '\.claude/'` returns nothing.

---

### Phase 4: Correct nested `completion_data` in pr-review-implementation-agent [COMPLETED]

**Goal**: Move `completion_data` out of `metadata` and up to top level in the worked final-metadata
example, matching the normative schema, so the newly-added reference does not contradict the
example sitting next to it.

**Tasks**:
- [x] In `cslib/agents/pr-review-implementation-agent.md`, locate the final-metadata JSON example
      (`"completion_data"` currently nested inside `"metadata"`, around line 322 pre-edit; the
      line number shifts by the Phase 2 insertion) *(completed: found at line 319/327 pre-edit
      after Phase 2's insertion shift)*
- [x] Close the `metadata` object after `code_changes_applied`, then emit `completion_data` as a
      top-level sibling of `metadata`, preserving the existing `completion_summary` text verbatim
      *(completed)*
- [x] Confirm the resulting block is valid JSON in shape (balanced braces, comma placement) and
      that `memory_candidates` remains a top-level key *(completed: memory_candidates confirmed
      top-level; JSON-SHAPE OK on the isolated Stage 7 block)*
- [x] Verify `cslib/agents/pr-review-research-agent.md` requires no change — it has no
      `completion_data` key, correctly, because it terminates at `researched` status *(completed:
      grep -c confirms 0)*

**Timing**: 0.3 hours

**Depends on**: 2

**Files to modify** (relative to `agent-system/extensions/`):
- `cslib/agents/pr-review-implementation-agent.md` - un-nest `completion_data` in the Stage 7
  metadata example

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions
# completion_data must now be at 2-space indent (top-level), not 4-space (nested)
grep -n '"completion_data"' cslib/agents/pr-review-implementation-agent.md
# extract the fenced json block and check it parses
awk '/^```json/{f=1;next}/^```/{f=0}f' cslib/agents/pr-review-implementation-agent.md \
  | sed 's/{N}/1/g; s/{NNN}_{SLUG}/001_x/g; s/{session_id}/s/g; s/{stream}/a/g; s/{topic}/b/g; s/: N,/: 1,/g' \
  | jq -e . >/dev/null && echo "JSON-SHAPE OK"
grep -c '"completion_data"' cslib/agents/pr-review-research-agent.md   # expect 0
```
- `completion_data` appears at exactly 2-space indentation.
- The `jq -e` check prints `JSON-SHAPE OK` (placeholder substitution is only to make the template
  parseable; if the awk range picks up more than one block, check each block individually).
- The research-agent count is `0`.
- `cd /home/benjamin/.config/nvim && git status --porcelain | grep '\.claude/'` returns nothing.

---

### Phase 5: Cross-cutting verification and scope-boundary audit [COMPLETED]

**Goal**: Prove all 15 files carry the reference, that no forbidden edit was made, and that no
scope boundary was crossed.

**Tasks**:
- [x] Run the all-15 reference check (below); require 15/15 *(completed: referenced: 15/15, no
      MISSING lines)*
- [x] Run the source-store check: confirm no modified path under `.claude/` *(completed:
      `git diff ed4573caf..HEAD -- .claude/` is empty across the full 4-phase task diff)*
- [x] Run the handoff-boundary check: confirm the diff introduced zero new
      `orchestrator-handoff` mentions in any of the 15 files *(completed: handoff boundary OK)*
- [x] Run the no-task-references check on the diff: no `task [0-9]` citation added outside
      `specs/**` *(completed: no-task-refs OK)*
- [x] Run the anti-copy-paste check: confirm no file gained an inline restatement of the status
      enum (no added line containing both `in_progress` and `researched` in a table row)
      *(completed: no enum copy OK)*
- [x] Record the results in the phase notes *(completed: see phase-5-progress.json note field and
      implementation summary)*

**Phase notes**: The plan's Phase 5 verification script's boundary checks (steps 4-6) use a bare
`git diff -- agent-system/extensions`, which is empty by the time Phase 5 runs because each prior
phase was already committed per the Commit-Per-Green-Substep Mandate. Re-ran the same checks
against `git diff ed4573caf..HEAD` (the pre-task-919 base commit) to cover the full task diff;
all four boundary checks (source-store, handoff, task-refs, enum-copy) pass against that wider
diff as well as the (trivially empty) working-tree diff.

**Timing**: 0.4 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**: none (verification only)

**Verification**:
```bash
cd /home/benjamin/.config/nvim/agent-system/extensions
FILES="cslib/agents/cslib-implementation-agent.md cslib/agents/cslib-research-agent.md
cslib/agents/pr-review-implementation-agent.md cslib/agents/pr-review-research-agent.md
latex/agents/latex-implementation-agent.md latex/agents/latex-research-agent.md
lean/agents/lean-research-agent.md
python/agents/python-implementation-agent.md python/agents/python-research-agent.md
typst/agents/typst-implementation-agent.md typst/agents/typst-research-agent.md
web/agents/web-implementation-agent.md web/agents/web-research-agent.md
z3/agents/z3-implementation-agent.md z3/agents/z3-research-agent.md"

# 1. all 15 reference the normative file
ok=0; for f in $FILES; do grep -q 'return-metadata-file' "$f" && ok=$((ok+1)) || echo "MISSING: $f"; done
echo "referenced: $ok/15"

# 2. no duplicate Context References sections
for f in $FILES; do c=$(grep -c '^## Context References' "$f"); [ "$c" = 1 ] || echo "BAD SECTION COUNT ($c): $f"; done

# 3. source-store rule: nothing under .claude/ modified
cd /home/benjamin/.config/nvim
git status --porcelain | grep '\.claude/' && echo "VIOLATION: .claude touched" || echo "source-store OK"

# 4. scope boundary: no handoff contracts added
git diff -- agent-system/extensions | grep '^+' | grep -i 'orchestrator-handoff' && echo "VIOLATION: handoff added" || echo "handoff boundary OK"

# 5. no task-number citations added outside specs/**
git diff -- agent-system/extensions | grep '^+' | grep -Ei '\btasks? [0-9]+' && echo "VIOLATION: task refs" || echo "no-task-refs OK"

# 6. no inline enum copy-paste
git diff -- agent-system/extensions | grep '^+' | grep 'in_progress' | grep 'researched' && echo "VIOLATION: enum copied inline" || echo "no enum copy OK"
```
- `referenced: 15/15` with no `MISSING:` lines.
- No `BAD SECTION COUNT` lines.
- All four boundary checks print their `... OK` branch.

---

## Testing & Validation

- [x] All 15 named files under `agent-system/extensions/**` contain the literal string
      `return-metadata-file`
- [x] Every one of the 15 has exactly one `## Context References` heading
- [x] For the 13 non-web files, `## Context References` precedes `## Agent Metadata`
- [x] For the 2 web files, the new bullet sits inside the pre-existing section, ahead of the
      on-demand subgroups, and carries the `(always load ...)` qualifier
- [x] `pr-review-implementation-agent.md`'s final-metadata example has `completion_data` as a
      top-level sibling of `metadata`
- [x] `git status --porcelain` shows zero modifications under `.claude/`
- [x] The diff adds no `orchestrator-handoff` reference to any agent file
- [x] The diff adds no task-number citation to any file outside `specs/**`
- [x] The diff adds no inline restatement of the status enum table

## Artifacts & Outputs

- 15 modified agent definition files under `agent-system/extensions/{cslib,latex,lean,python,typst,web,z3}/agents/`
- One corrected JSON example in `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md`
- Implementation summary at `specs/919_reference_normative_status_vocabulary_in_agents/summaries/01_reference-normative-status-vocab-summary.md`
- No new files created; no context file added (the normative source already exists)

## Rollback/Contingency

Every edit is a purely additive insertion into a markdown prompt file, except the Phase 4
brace/indent move. Rollback is `git checkout -- agent-system/extensions/<path>` per file, or
`git revert` of the phase commit. No generated artifact, no schema, and no script depends on
these insertions, so a partial rollback leaves the system in a consistent (merely
still-defective) state.

If Phase 4's JSON-shape check cannot be made to pass, revert Phase 4 alone and complete the task
with Phases 1-3 and 5 — the reference insertion is independently valuable and Phase 4 is the
folded-in extra. Record the deferral in the summary so a follow-up can pick it up.

If the deploy step is run and any `.claude/**` file appears modified in `git status`, that is
expected only if `.claude/` is not in fact gitignored in this checkout; confirm before treating
it as a violation, but never author an edit there.
