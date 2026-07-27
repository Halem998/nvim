# Implementation Plan: Task #915

- **Task**: 915 - Close the mirror-image completion_data propagation gap in nix, nvim, and epidemiology implementers
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/915_fix_completion_data_propagation_nix_nvim_epi/reports/01_completion-data-propagation-audit.md
- **Artifacts**: plans/01_completion-data-propagation-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three implementer skills (`nix`, `nvim`/`neovim`, `epidemiology`) generate `completion_data` on
the agent side but never read it back out of `.return-meta.json` in their SKILL.md postflight, so
`completion_summary` and `roadmap_items` are silently dropped before reaching `state.json`. This
plan applies the established `core` fix shape — extend the metadata-read step to pull the two
fields, then call the existing shared writer `skill_propagate_completion_summary` from
`scripts/skill-base.sh` — as a purely additive change to each of the three files. Phases 1-3 are
one file each and fully independent; Phase 4 verifies the caller/callee contract across all three
plus the shared function and records the deferred shared-script extraction.

### Research Integration

The audit independently confirmed the defect is present in all three extensions (none is "already
correct"), confirmed no manifest `postflight` hook, extension-local hook script, or
`update-task-status.sh` handling compensates for the gap, and established that `core`'s
shared-function pattern — not `web`'s older inline-duplicated jq sequence — is the shape to
follow. Two starting shapes exist and are treated separately below: `nix`/`nvim` postflight
Stages 5/6 are pure prose with **no bash at all**, while `epidemiology` already has a real bash
metadata-read block that stops short of the two fields and a Stage 7 that is table-only.

Two corrections/refinements to the research report's per-file recommendations were established
while planning and are binding on the implementer:

1. **Status-gate value.** The research report suggested gating epidemiology's new Stage 7 bash on
   `meta_status == "completed"` to match that stage's existing table row. The epi agent file
   actually writes `"status": "implemented"` in its final metadata — the table's `completed` row
   is a pre-existing latent mismatch. Gating solely on `"completed"` would make the entire fix
   dead code. All three phases therefore gate on `"implemented"`, accepting `"completed"` as well
   so the guard is robust to either value. The table-row discrepancy itself is recorded as an
   observation, not silently repaired (see Non-Goals).
2. **Variable binding in nix/nvim.** These two files contain no bash anywhere and never bind
   `task_number`, `project_name`, `padded_num`, or `session_id`. The inserted Stage 5 block must
   therefore be self-contained: it binds `padded_num`/`project_name` itself (mirroring the
   `printf "%03d"` + `jq` idiom already used in `core`'s and `epidemiology`'s Stage 1) rather than
   assuming variables that do not exist in these files.

`skill_propagate_completion_summary` needs no caller-side setup beyond sourcing: `skill-base.sh`
self-defaults `SKILL_REPO_ROOT` at source time, and the function carries its own guards
(non-empty `completion_summary`; `task_type != "meta"` AND non-empty/non-`"[]"` `roadmap_items`).
No guard logic is reimplemented at any call site.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` supplied).

## Goals & Non-Goals

**Goals**:
- Make `completion_data.completion_summary` and `completion_data.roadmap_items` reach
  `state.json` for tasks routed through the `nix`, `nvim`, and `epidemiology` implementer skills.
- Use the shared writer `skill_propagate_completion_summary` at every new call site; do not
  duplicate the write logic or restate the metadata schema in any of the three files.
- Keep every change additive: no stage renumbering, no change to trigger conditions, no change to
  agent-side content, no change to existing prose or headings.

**Non-Goals**:
- Extracting the postflight step into a further shared script/hook that removes the two-line
  source-and-call boilerplate. Deliberately deferred — it would have to touch the already-fixed
  `core`, `core-hard`, `lean`, `lean-hard`, and `web` skills and merits its own design pass.
  Recorded as a follow-up in Phase 4.
- Migrating `web`'s inline-duplicated jq sequence onto the shared function.
- Repairing epidemiology's Stage 7 table row that maps a `completed` meta status (the agent emits
  `implemented`). Changing that table alters status-mapping semantics beyond this fix; it is
  recorded as an observation for a follow-up.
- Editing anything under `.claude/`. That tree is a gitignored, disposable deploy artifact
  regenerated from the source store; all edits and all verification target
  `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gating the new write on a status value the agent never emits, making the fix dead code | H | M | Gate on `"implemented"` with `"completed"` accepted as well; Phase 4 greps each agent file's final-metadata `status` value and asserts the gate accepts it |
| Inserted bash in nix/nvim references variables those files never bind, producing a silently no-op or erroring block | H | M | Stage 5 block is self-contained — binds `padded_num`/`project_name` itself before use; Phase 4 runs `bash -n` on every extracted block |
| Adding bash to nix/nvim changes the files' character (prose-only -> bash-containing) | L | H | Keep additions minimal and modeled directly on `core`'s Stage 6/7 blocks; preserve all existing prose lines and stage headings verbatim |
| Hardcoded `"nix"`/`"neovim"` task_type argument drifts if either skill later serves more task types | L | L | Both skills' Trigger Conditions already hardcode a single task_type; the choice is called out inline in the plan so a future editor is not surprised |
| Writing completion fields on `partial`/`failed` returns | M | M | Every new call site is wrapped in an explicit status gate; Phase 4 confirms no call site is unguarded |
| Editing the deploy artifact instead of the source store | H | L | Every phase's file list is an `agent-system/extensions/**` path; Phase 4 asserts `git status` shows no `.claude/` modifications |
| Task-number citations leaking into files outside `specs/**` | M | L | Comments in inserted text reference `context/formats/return-metadata-file.md` and the function name only; Phase 4 greps the three diffs for task-number patterns |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 each own exactly one file
and share no target, so they are territory-disjoint.

---

### Phase 1: Propagate completion_data in the nix implementer skill [COMPLETED]

**Goal**: `skill-nix-implementation` reads `completion_data` out of `.return-meta.json` and hands
it to the shared writer, so nix-routed tasks land `completion_summary`/`roadmap_items` in
`state.json`.

**Tasks**:
- [x] Anchor on the heading `### Stage 5: Parse Subagent Return` and its existing single prose
      line "Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`." Keep that prose
      line verbatim and add a bash block immediately after it. *(completed)*
- [x] The added block must be self-contained (this file binds no bash variables anywhere): bind
      `padded_num` via `printf "%03d"` and `project_name` via a `jq` lookup against
      `specs/state.json`, then build `metadata_file` from them. Read `status`, `artifact_path`,
      `artifact_type`, `artifact_summary`, plus the two new fields:
      `completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")`
      and `roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")`.
      Guard with the same `[ -f ... ] && jq empty ...` / `else status="failed"` shape `core` and
      `epidemiology` use. *(completed)*
- [x] Add a single comment line pointing at the schema — reference
      `context/formats/return-metadata-file.md` by path. Do NOT restate any field list or schema
      text in this file. *(completed)*
- [x] Anchor on the heading `### Stage 6: Update Task Status (Postflight)` and its existing prose
      line "Update state.json and TODO.md based on result." Keep that line verbatim and append a
      bash block after it that gates on the agent's terminal status and calls the shared writer:
      `source .claude/scripts/skill-base.sh` then
      `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "nix"`.
      *(completed)*
- [x] Gate condition must accept the value the nix agent actually emits: `implemented` (accept
      `completed` too). Do not gate on `completed` alone. *(completed)*
- [x] Use the literal `"nix"` as the fourth argument — this skill never binds a `task_type`
      variable, and introducing one solely for this call is out of scope. Note the literal choice
      in a brief inline comment so a future editor sees it is deliberate. *(completed)*
- [x] Do not reimplement the writer's guards (non-empty summary; `task_type != "meta"` and
      non-empty/non-`"[]"` roadmap items) — they live in `skill-base.sh`. *(completed)*
- [x] Confirm no other stage, heading, or prose line in the file was altered. *(completed:
      verified via `git diff` — insertion-only)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md` - add a bash block under
  Stage 5 (metadata read incl. `completion_data`) and a gated bash block under Stage 6 (shared
  writer call). Additive only.

**Verification**:
- `grep -n "completion_summary\|roadmap_items\|skill_propagate_completion_summary\|skill-base.sh"`
  on the file returns hits in both Stage 5 and Stage 6 regions.
- Extract each added fenced bash block and run `bash -n` on it — no syntax errors.
- `git diff` for the file shows only insertions (no deleted or reworded existing lines) and no
  change to any `### Stage` heading text or numbering.
- The file contains no task-number citation (`task 915`, `task N`, `(task ...)`) anywhere.

---

### Phase 2: Propagate completion_data in the neovim implementer skill [NOT STARTED]

**Goal**: `skill-neovim-implementation` reads `completion_data` out of `.return-meta.json` and
hands it to the shared writer, so neovim-routed tasks land
`completion_summary`/`roadmap_items` in `state.json`.

**Tasks**:
- [ ] Apply the identical change described in Phase 1 to this file. The audit found the two files
      share the same postflight shape (Stage 5 and Stage 6 are the same two prose lines, no bash
      anywhere), so the same insertion applies — but re-read the anchors in this file rather than
      assuming byte-identity, and adapt if the surrounding text differs.
- [ ] Anchor on `### Stage 5: Parse Subagent Return` and its existing prose line; keep it verbatim
      and add the self-contained metadata-read bash block after it (binding `padded_num` /
      `project_name` / `metadata_file`, reading `status`, the three artifact fields, and the two
      `completion_data` fields).
- [ ] Anchor on `### Stage 6: Update Task Status (Postflight)` and its existing prose line; keep
      it verbatim and append the gated `source .claude/scripts/skill-base.sh` +
      `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "neovim"`
      block.
- [ ] Use the literal `"neovim"` (not `"nvim"`) as the fourth argument — match this skill's
      declared task_type string in its Trigger Conditions section; verify that string before
      writing it rather than assuming.
- [ ] Gate on `implemented` (accepting `completed`), matching the value the neovim agent's final
      metadata actually emits.
- [ ] Add the same single schema-pointer comment referencing
      `context/formats/return-metadata-file.md`; do not restate the schema.

**Timing**: 0.35 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The audit reports this file's postflight Stages 5/6 are the same shape as
nix's, making this "the same fix twice". Confirm at implementation time by reading both anchors in
this file directly — if the surrounding prose or stage numbering differs, adapt the insertion to
this file rather than copying nix's diff blind. Likewise confirm the task_type literal against
this skill's own Trigger Conditions text before hardcoding `"neovim"`.

**Files to modify**:
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - add a bash block
  under Stage 5 and a gated bash block under Stage 6. Additive only.

**Verification**:
- `grep -n "completion_summary\|roadmap_items\|skill_propagate_completion_summary\|skill-base.sh"`
  returns hits in both stage regions.
- Each added fenced bash block passes `bash -n`.
- The fourth argument literal matches the task_type string asserted in this file's Trigger
  Conditions section.
- `git diff` shows insertions only; no heading text or numbering changed.
- No task-number citation anywhere in the file.

---

### Phase 3: Propagate completion_data in the epidemiology implementer skill [NOT STARTED]

**Goal**: `skill-epi-implement` extends its existing metadata-read block to include
`completion_data` and gains a Stage 7 call site for the shared writer, so epi-routed tasks land
`completion_summary`/`roadmap_items` in `state.json`.

**Tasks**:
- [ ] Anchor inside the existing `### Stage 6: Read Metadata File` bash block, on the line
      `artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")` and the `else`
      that follows it. Insert between them, at the same indentation as the surrounding
      assignments:
      `completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")`
      and `roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")`.
- [ ] Do not restructure the existing block, its `if`/`else` guard, or its `meta_status="failed"`
      fallback.
- [ ] Anchor on `### Stage 7: Update Task Status (Postflight)`. This stage is currently a
      markdown table with no bash. Keep the existing MUST NOT note and the table verbatim, and add
      a bash block after the table.
- [ ] The added block gates on `meta_status` and calls the shared writer with the in-scope
      variable — this file binds `task_type` in Stage 1, so pass `"$task_type"` (no literal
      substitution here, unlike Phases 1-2):
      `source .claude/scripts/skill-base.sh` then
      `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"`.
- [ ] **Gate on `implemented`, accepting `completed`.** The epi agent's final metadata emits
      `"status": "implemented"`; this stage's existing table lists a `completed` row. Gating on
      `completed` alone would make the block unreachable. Do not edit the table to resolve the
      mismatch — record it for Phase 4 instead.
- [ ] Confirm the new block sits before Stage 8 (Link Artifacts) and does not disturb Stage 8's
      artifact-linking or Stage 9's git staging logic.
- [ ] Add the same single schema-pointer comment referencing
      `context/formats/return-metadata-file.md`.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` - two assignment
  lines added inside the existing Stage 6 bash block; one new gated bash block appended to
  Stage 7. Additive only.

**Verification**:
- The Stage 6 block now reads both `completion_data` fields, with the existing `if`/`else` guard
  and `meta_status="failed"` fallback intact.
- Stage 7 contains a bash block whose gate accepts `implemented`.
- Each touched/added fenced bash block passes `bash -n`.
- `git diff` shows insertions only; the Stage 7 table and the MUST NOT note are unchanged, and no
  stage heading or numbering changed.
- No task-number citation anywhere in the file.

---

### Phase 4: Verify the caller/callee contract across all three and record follow-ups [NOT STARTED]

**Goal**: Confirm all three call sites are correct, guarded, consistent with the shared writer's
signature, and confined to the source store — and record the two deliberately deferred items.

**Tasks**:
- [ ] For each of the three edited SKILL.md files, confirm the call site's argument order and
      count match `skill_propagate_completion_summary`'s signature in
      `agent-system/extensions/core/scripts/skill-base.sh`
      (`task_number`, `completion_summary`, `roadmap_items`, `task_type` — four positional args).
- [ ] Confirm each of the three call sites is inside a status gate; no unguarded call exists.
- [ ] Cross-check each gate against the terminal `status` value in the corresponding agent file
      (`nix/agents/nix-implementation-agent.md`,
      `nvim/agents/neovim-implementation-agent.md`,
      `epidemiology/agents/epi-implement-agent.md`) — the gate must accept what the agent emits.
- [ ] Confirm no file duplicates the writer's guard logic or restates the metadata schema; each
      references `context/formats/return-metadata-file.md` by path instead.
- [ ] Run `bash -n` over every bash block added or modified across the three files.
- [ ] Confirm `git status --short` shows modifications only under `agent-system/extensions/**`
      and the task's own `specs/915_*/` directory — zero `.claude/` modifications.
- [ ] Grep the three diffs for task-number citation patterns; confirm none.
- [ ] Record in the implementation summary: (a) the deferred shared-script/postflight-hook
      extraction, with the audit's rationale (it would need to touch `core`, `core-hard`, `lean`,
      `lean-hard`, and `web`, and warrants its own design pass on whether it should be a
      manifest-declared `postflight` lifecycle hook); (b) the epidemiology Stage 7 table row that
      maps a `completed` meta status the agent never emits, left unrepaired here; (c) the
      `return-metadata-file.md` "Known callers" documentation gap flagged by the audit.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly three edited SKILL.md files and three
corresponding agent files. Confirm by enumerating the actual modified set from `git status
--short` at implementation time rather than trusting the count — if a fourth file was touched,
reconcile it against the plan's declared scope before proceeding.

**Files to modify**:
- None (verification only). Findings are recorded in the task's implementation summary artifact
  under `specs/915_fix_completion_data_propagation_nix_nvim_epi/summaries/`.

**Verification**:
- All three call sites match the shared function's four-argument signature.
- All three gates accept the terminal status their paired agent file emits.
- Every added/modified bash block passes `bash -n`.
- `git status --short` shows no `.claude/` path.
- No task-number citation in any changed file outside `specs/**`.
- The summary artifact records all three follow-up items.

---

## Testing & Validation

- [ ] Every added or modified fenced bash block in the three SKILL.md files passes `bash -n`.
- [ ] Each of the three files contains exactly one `skill_propagate_completion_summary` call,
      inside a status gate, with four positional arguments in the documented order.
- [ ] Each of the three files reads both `.completion_data.completion_summary` (via `jq -r`, with
      `// ""`) and `.completion_data.roadmap_items` (via `jq -c`, with `// []`).
- [ ] No file duplicates the guard logic that lives in `skill_propagate_completion_summary`, and
      no file restates the `.return-meta.json` schema.
- [ ] `git diff` across the three files is insertion-only: no existing prose line, stage heading,
      stage number, table, or trigger condition is altered or removed.
- [ ] No modifications anywhere under `.claude/`.
- [ ] No task-number citations in any changed file outside `specs/**`.

## Artifacts & Outputs

- Modified: `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md`
- Modified: `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- Modified: `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md`
- New: implementation summary under
  `specs/915_fix_completion_data_propagation_nix_nvim_epi/summaries/`, recording the three
  follow-up items from Phase 4.

## Rollback/Contingency

Every change is a pure insertion into a markdown file with no build or migration step, so
reverting is a `git checkout` of the three paths (or a revert of the phase commits). Because each
phase owns exactly one file and the phases are territory-disjoint, a single problematic phase can
be reverted without disturbing the other two. If the shared writer's signature turns out to differ
from what Phase 4 asserts, revert the call-site blocks only and keep the metadata-read additions —
those are inert on their own and drop nothing that is not already being dropped today.
