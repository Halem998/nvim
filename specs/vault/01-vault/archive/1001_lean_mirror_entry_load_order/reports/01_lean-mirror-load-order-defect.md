# Research Report: Task #1001

**Task**: 1001 - Fix lean mirror entry load-order defect; audit duplicated index paths
**Started**: 2026-08-10T06:08:09Z
**Completed**: 2026-08-10T06:30:00Z
**Effort**: ~45 minutes
**Dependencies**: Task 991, Task 992, Task 1000 (completed — establishes the reference pattern)
**Sources/Inputs**: Codebase (index-entries.json across all 19 extensions, merge.lua, check-extension-docs.sh), sibling task 1000's summary/plan, state.json/TODO.md task description
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed by direct code reading (not inference): `M.append_index_entries` in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 528-579) upserts index entries
  **by path**, replacing the whole entry object in place when a later-processed entry's
  `path` matches an existing one (lines 552-559). There is no per-field merge and no union
  logic — whichever entry is processed last for a given path wins entirely, silently
  discarding every other field the earlier entry carried (including `load_when.agents`).
- Confirmed the specific defect: `agent-system/extensions/lean/index-entries.json`'s entry
  for `contracts/adversarial-verification.md` (line 601) declares
  `load_when.agents: ["lean-research-hard-agent"]` only. Core's own entry for the identical
  path (`agent-system/extensions/core/index-entries.json`) declares
  `load_when.agents: ["general-research-hard-agent"]`. In any deploy where lean is loaded and
  processed after core, lean's narrower entry silently replaces core's, and
  `general-research-hard-agent` loses this contract with no error signal anywhere.
- **The defect is one instance of a class, not isolated.** The full duplicated-path audit
  (Findings, "Cross-Extension Duplicated-Path Audit") found two more paths with the exact same
  shape between core and lean — `contracts/reference-grounding.md` and
  `contracts/anti-analysis.md` — plus a distinct, more severe variant entirely internal to
  cslib's own `index-entries.json` (two entries for the same path within one file, colliding
  on every load of cslib alone, independent of any other extension or load order).
- Recommended approach: apply the exact union-valued `load_when.agents` pattern task 1000
  already established and proved for cslib (`general-research-hard-agent` +
  `cslib-research-hard-agent` on `contracts/adversarial-verification.md`) to lean's entry —
  add `general-research-hard-agent` alongside `lean-research-hard-agent`. Verify by
  reconstructing the actual merge (a headless-Neovim script calling
  `merge.append_index_entries` twice, core-then-lean order) rather than reading the JSON and
  asserting correctness — this is exactly what task 1000's summary did and what this task's
  own verification bar demands.
- No check-extension-docs.sh rule, and no other lint script, currently detects a narrower
  `load_when.agents` on a duplicated path — this defect class is invisible to every existing
  automated gate. This is worth recording as a follow-up per WORK item 3, scoped as a
  follow-up, not implemented here.

## Context & Scope

This is a `meta` task whose sole `file_scope` is
`agent-system/extensions/lean/index-entries.json`. The task has three WORK items:

1. Fix lean's `contracts/adversarial-verification.md` entry to a union-valued
   `load_when.agents` (in scope, file_scope-bound).
2. Audit and enumerate every duplicated index path across all extensions where the same
   load-order defect shape exists, even if only the lean instance is fixed (research/audit —
   this report is where the enumeration is recorded, per the task's phrasing "report the
   set").
3. Consider whether the loader itself deserves a warning on this collision shape, and record
   as a follow-up if so (explicitly NOT to be implemented in this task — "record it as a
   follow-up rather than widening this task").

Task 1000, already completed, established and proved the union-valued pattern this task must
apply. Its summary (`specs/1000_cslib_adversarial_verification_mirror/summaries/01_cslib-h4-contract-mirror-summary.md`)
explicitly recorded lean's single-agent entry for `contracts/adversarial-verification.md` as
"explicitly out of this task's file scope per the plan's Non-Goals" — i.e., this task is the
designated follow-up that closes that recorded gap.

## Findings

### Codebase Patterns

**The upsert-by-path mechanism (verified by reading, not assumed)**

`lua/neotex/plugins/ai/shared/extensions/merge.lua`, `M.append_index_entries`
(lines 528-579):

```lua
for _, entry in ipairs(entries) do
  local normalized_path = normalize_index_path(entry.path)
  entry.path = normalized_path

  local replaced = false
  for idx, existing in ipairs(index.entries) do
    if existing.path == normalized_path then
      index.entries[idx] = entry   -- WHOLE ENTRY replaced, not merged
      replaced = true
      break
    end
  end
  if not replaced then
    table.insert(index.entries, entry)
  end
  table.insert(added_paths, normalized_path)
end
```

Call site: `lua/neotex/plugins/ai/shared/extensions/init.lua`, `process_merge_targets`
(lines 104-121) reads one extension's whole `index-entries.json` `entries` array and passes it
in a single call to `append_index_entries`. Two consequences follow directly from this, both
confirmed by reading the code (no assumption):

1. **Cross-extension collision**: when extension B is loaded after extension A and both
   declare an entry for the same `path`, B's entry (processed in B's own call, made after A's
   call in extension-load order) replaces A's entry in the target `.claude/index.json`
   wholesale. This is the mechanism task 1000's summary already proved via a scratch
   headless-Neovim simulation for the cslib/core pair, and is the mechanism this task's
   verification bar requires reconstructing for the lean/core pair.
2. **Same-extension collision**: if a *single* extension's own `index-entries.json` contains
   two entries with the same `path` in its own array, the loop above processes them in array
   order within the *same* call — the second entry silently replaces the first, with no
   cross-extension involvement and no dependency on load order between extensions at all. This
   fires on every deploy that loads the offending extension alone. Found once, in cslib (see
   audit below) — flagged as a distinct, arguably more severe variant of the same underlying
   "last writer wins, whole-entry replace" defect.

**`.claude-extensions.json` state (this repo's live deploy)**: only `core`, `email`, `memory`,
`nix`, and `nvim` are currently loaded (`jq -r '.extensions | keys[]' .claude-extensions.json`).
Neither `lean` nor `cslib` is loaded here, confirming the task description's "dormant, not
currently biting" status for both the lean defect and the cslib internal-duplicate defect
found during the audit.

**Existing core entry for the shared path** (`agent-system/extensions/core/index-entries.json`):

```json
{
  "path": "contracts/adversarial-verification.md",
  "load_when": { "agents": ["general-research-hard-agent"], "commands": [], "task_types": [] },
  ...
}
```

**Existing lean entry for the shared path** (`agent-system/extensions/lean/index-entries.json`,
line 601):

```json
{
  "path": "contracts/adversarial-verification.md",
  "line_count": 93,
  "load_when": { "agents": ["lean-research-hard-agent"], "task_types": ["lean4"] },
  ...
}
```

Union needed: `load_when.agents: ["lean-research-hard-agent", "general-research-hard-agent"]`
(order does not appear to be semantically significant anywhere the loader or downstream
consumers were checked, but matching task 1000's cslib precedent's convention of listing the
domain-specific agent first is a reasonable default — cslib's actual committed entry lists
`general-research-hard-agent` first then `cslib-research-hard-agent`, so precedent is mixed;
either order is safe).

### Cross-Extension Duplicated-Path Audit

Enumerated every `path` value across all 19 extensions' `index-entries.json` files
(`agent-system/extensions/*/index-entries.json`, 478 total entries) and found paths declared by
more than one extension, or more than once within the same extension:

| Path | Extensions declaring it | Same defect shape? | In this task's file_scope? |
|------|--------------------------|---------------------|------------------------------|
| `contracts/adversarial-verification.md` | core, cslib, lean | **Yes — the task's named target.** core: `["general-research-hard-agent"]`. cslib (already fixed by task 1000): union `["general-research-hard-agent", "cslib-research-hard-agent"]`. lean: `["lean-research-hard-agent"]` only — narrower than the union of core+lean. | Yes — WORK item 1 |
| `contracts/reference-grounding.md` | core, lean | **Yes, identical shape.** core: `["general-research-hard-agent", "planner-hard-agent"]`. lean: `["lean-research-hard-agent", "lean-implementation-hard-agent"]` — no overlap, narrower than the union of both if lean is processed after core (drops `general-research-hard-agent` and `planner-hard-agent`'s reach). | No — outside `agent-system/extensions/lean/index-entries.json` is in scope, but fixing this specific entry was not named in WORK item 1, which named only the adversarial-verification.md entry. Flagged per WORK item 2's enumeration mandate. |
| `contracts/anti-analysis.md` | core, lean | **Yes, identical shape.** core: `["general-implementation-hard-agent", "general-research-hard-agent"]`. lean: `["lean-research-hard-agent", "lean-implementation-hard-agent"]` — same no-overlap, narrower-than-union pattern. | No — same as above. |
| `project/cslib/standards/ci-pipeline.md` | cslib (twice, within its own file) | **Related but distinct mechanism** — not a cross-extension load-order collision at all. Two entries in cslib's *own* `index-entries.json` array both declare this path: one with `load_when.agents: ["cslib-implementation-agent"]` (`task_types: ["cslib", "pr"]`), the other with `load_when.agents: ["cslib-implementation-hard-agent"]` (`task_types: ["cslib"]`). Per the `append_index_entries` loop, whichever entry appears **later in cslib's own array** wins and the earlier one's agent hook is silently dropped — on every deploy that loads cslib, regardless of what else is loaded or in what order. This is arguably worse than the cross-extension case because it requires no other extension's involvement at all. | No — not the lean extension. Flagged per WORK item 2. |

No other duplicated paths were found across the remaining 15 extensions' index files (email,
epidemiology, filetypes, formal, founder, latex, literature, memory, nix, nvim, present,
python, slidev, typst, web, z3) — each of those extensions' declared paths are unique across
the whole corpus.

**Internal-duplicate check**: also checked every extension's own `index-entries.json` for
same-file path duplicates (`jq -r '.entries[]?.path' file | sort | uniq -d]` per extension).
Only cslib has one (`project/cslib/standards/ci-pipeline.md`, above); no other extension,
including lean, core, or any of the 15 with no cross-extension duplicates, has an internal
duplicate.

### Rule Coverage Gap (relevant to WORK item 3)

Checked `agent-system/extensions/core/scripts/check-extension-docs.sh` for any existing rule
that would catch this defect class. Rule R (source-file existence, line 600 onward) and Rule T
(forbidden `load_when` keys, line 669 onward) are the only rules touching `load_when` or
`index-entries.json` structure at all. Neither rule cross-references paths across different
extensions' index files, and neither compares `load_when.agents` breadth against any other
entry declaring the same path (whether in the same file or a different extension's file). This
confirms the task description's framing: this defect class is currently invisible to every
automated gate in the repository — the only reason task 1000's cslib fix and the lean defect
named in this task were caught at all was manual review during a prior decomposition task, not
tooling.

### External Resources

Not applicable — this is a self-contained internal deploy-mechanism defect; no external
documentation informs the fix. All investigation was code-reading of this repository's own
Lua merge logic and JSON index files.

### Recommendations

1. **The fix (WORK item 1, in file_scope)**: edit
   `agent-system/extensions/lean/index-entries.json`'s `contracts/adversarial-verification.md`
   entry's `load_when.agents` array from `["lean-research-hard-agent"]` to
   `["lean-research-hard-agent", "general-research-hard-agent"]` (or either order — see note
   above). No other field of that entry needs to change: `line_count` (93) is untouched by this
   edit and stays accurate for Rule R since no content file changes; `task_types` stays
   `["lean4"]` — the union pattern extends `agents` only, matching task 1000's cslib precedent,
   which also left `task_types`/`commands` untouched and widened only `agents`.
2. **Verification must reconstruct the actual merge**, not just read the JSON. Task 1000's
   summary set the precedent: a disposable headless-Neovim script calling
   `neotex.plugins.ai.shared.extensions.merge.append_index_entries` against a scratch index
   file, applying core's entry first then lean's second (the realistic core-then-extension
   processing order), and asserting the single surviving entry for
   `contracts/adversarial-verification.md` contains **both**
   `general-research-hard-agent` and `lean-research-hard-agent` in its `load_when.agents`.
   Delete the scratch script and scratch index file afterward, exactly as task 1000 did.
3. **The audit table above satisfies WORK item 2.** The plan/implementation phase should carry
   this table (or an equivalent restatement) into the task's summary, since the task
   description explicitly requires "The duplicated-path audit from item 2 is recorded in the
   task summary." The `contracts/reference-grounding.md`, `contracts/anti-analysis.md`, and
   cslib `ci-pipeline.md` findings are correctly left unfixed by this task (file_scope is lean's
   index file only, and WORK item 1 names only the adversarial-verification.md entry) — they
   should be recorded as candidates for separate follow-up tasks, not fixed here.
4. **WORK item 3 (the loader-warning question)**: recommend recording, as a follow-up
   candidate rather than implementing here, a lint rule addition to
   `check-extension-docs.sh` (or a new dedicated check) that: (a) flags any path declared by
   more than one extension's `index-entries.json` where the `load_when.agents` sets differ and
   neither is a superset of the other (the cross-extension shape), and (b) flags any path
   declared more than once **within a single extension's own** `index-entries.json` array (the
   cslib-internal shape) unconditionally, since that shape has no legitimate use — a single
   extension should never need two entries for the same path. This is a natural extension of
   the existing Rule R/Rule T family in the same script and would have caught all four findings
   in the audit table automatically. Not implemented in this research pass per the task's
   explicit instruction to record rather than widen scope.

## Decisions

- Followed task 1000's already-established and proven pattern (union-valued `load_when.agents`,
  verified via actual merge reconstruction rather than static JSON inspection) rather than
  designing a new approach — the task description explicitly requires this ("Apply the same
  pattern the sibling cslib task establishes; this task is sequenced after it so there is one
  pattern, not two").
- Scoped the fix strictly to the one entry named in WORK item 1
  (`contracts/adversarial-verification.md`). The two sibling defects found in the audit
  (`contracts/reference-grounding.md`, `contracts/anti-analysis.md`) share the identical shape
  and could trivially be fixed in the same edit, but WORK item 1's text names only the
  adversarial-verification.md entry, and file_scope for this task is a single file the plan
  should treat conservatively — recommend a human/orchestrator decision at planning time on
  whether to widen the fix to all three lean/core pairs in one pass or spawn a follow-up task,
  rather than this research report unilaterally deciding scope expansion.
- Treated the cslib-internal `ci-pipeline.md` duplicate as a distinct finding worth flagging
  (per WORK item 2's "enumerate every duplicated path... even if this task only fixes the lean
  instance") but explicitly out of scope for any fix here, since it lives entirely outside
  `agent-system/extensions/lean/**`.

## Risks & Mitigations

- **Risk**: editing `load_when.agents` without re-verifying `line_count` could introduce a
  Rule R violation if the edit is combined (by a future editor) with an unrelated content
  change to the mirrored `.md` file. **Mitigation**: this task's fix touches only the JSON
  `load_when.agents` array; no change to
  `agent-system/extensions/lean/context/contracts/adversarial-verification.md` content or line
  count is needed or should be made.
- **Risk**: verifying via merge reconstruction requires a disposable Lua script and a scratch
  index file; if left behind, it could contaminate the working tree or be mistaken for a
  deliverable. **Mitigation**: task 1000's summary explicitly deleted both after use — repeat
  that discipline.
- **Risk**: `check-extension-docs.sh`'s overall exit code may be non-zero due to an unrelated,
  pre-existing FAIL from another in-flight task (as task 1000's summary documented for the
  `check-extension-docs.sh` deployed-vs-source-store drift finding). **Mitigation**: the
  verification bar should be read as "lean's own PASS/relevant rule output," not the script's
  global exit code, consistent with how task 1000 interpreted its own analogous verification
  bar.

## Context Extension Recommendations

- **Topic**: cross-extension `index-entries.json` duplicate-path defects and the
  upsert-by-path merge semantics that make them possible.
- **Gap**: no context file currently documents this defect class or the
  `append_index_entries` upsert-by-path mechanism as a named pattern; it exists only as
  scattered task-history knowledge (task 1000's summary, this task's description and now this
  report). A future contributor adding a new extension's `index-entries.json` mirror entry has
  no discoverable guidance steering them toward union-valued `load_when.agents` for any path
  also declared elsewhere.
- **Recommendation**: after this task and any follow-up fixes for
  `contracts/reference-grounding.md` / `contracts/anti-analysis.md` land, consider adding a
  short guide (e.g. `context/guides/index-entry-mirror-pattern.md` under core) documenting: the
  upsert-by-path mechanism, the union-valued-`load_when.agents` mirror-entry convention, and a
  pointer to run the duplicate-path audit query (`jq` one-liner over all
  `agent-system/extensions/*/index-entries.json` files) before adding any new extension-local
  copy of a path core (or another extension) already declares. This is a recommendation only,
  not a task created by this research pass (context-gap task creation is disabled per this
  agent's Stage 4.5 instructions).

## Appendix

### Search Queries / Commands Used

```bash
# Cross-extension duplicate-path detection
for f in agent-system/extensions/*/index-entries.json; do
  ext=$(echo "$f" | cut -d/ -f3)
  jq -r --arg ext "$ext" '.entries[]? | [$ext, .path] | @tsv' "$f"
done > /tmp/all_entries.tsv
cut -f2 /tmp/all_entries.tsv | sort | uniq -c | sort -rn | awk '$1>1'

# Per-extension internal duplicate-path detection
for f in agent-system/extensions/*/index-entries.json; do
  jq -r '.entries[]?.path' "$f" | sort | uniq -d
done

# Live deploy state
jq -r '.extensions | keys[]' .claude-extensions.json
```

### References

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`M.append_index_entries`, lines 528-579)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (`process_merge_targets`, lines 104-121)
- `agent-system/extensions/lean/index-entries.json` (line 601, the target entry)
- `agent-system/extensions/core/index-entries.json` (`contracts/adversarial-verification.md`,
  `contracts/reference-grounding.md`, `contracts/anti-analysis.md` entries)
- `agent-system/extensions/cslib/index-entries.json` (both the fixed union entry and the
  internal `ci-pipeline.md` duplicate)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R, Rule T)
- `specs/1000_cslib_adversarial_verification_mirror/summaries/01_cslib-h4-contract-mirror-summary.md`
  (the established, proven pattern this task applies)
- `.claude-extensions.json` (confirms neither lean nor cslib is loaded in this repo's live
  deploy, i.e. both defects found are currently dormant here)
