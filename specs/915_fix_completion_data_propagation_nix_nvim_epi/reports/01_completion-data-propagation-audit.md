# Research Report: Task #915

**Task**: 915 - fix completion data propagation in nix, nvim, and epidemiology extensions
**Started**: 2026-07-27T18:00:00Z
**Completed**: 2026-07-27T18:30:00Z
**Effort**: small (3 files, ~10-15 line additions each)
**Dependencies**: None
**Sources/Inputs**: Codebase inspection (agent-system/extensions/**)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, return-metadata-file.md

## Executive Summary

- Independently verified, per extension: all three (`nix`, `nvim`/`neovim`, `epidemiology`) have
  the exact mirror-image defect described in the delegation context. Agent side is correct in
  all three; SKILL.md postflight side never reads or propagates `completion_data` in any of the
  three. No finding of "already correct" for any extension — all three need the fix.
- `nix` and `nvim`/`neovim`'s `SKILL.md` postflight stages are markedly thinner than
  `epidemiology`'s: Stage 5/6 are one-line prose ("Update state.json and TODO.md based on
  result.") with **no bash at all**, whereas `epidemiology` already has a concrete bash block for
  reading `status`/`artifact_path`/`artifact_type`/`artifact_summary` but stops short of reading
  `completion_summary`/`roadmap_items`.
- No lifecycle hook, shared script, or other indirection compensates for the gap in any of the
  three — confirmed via manifest.json `hooks` fields (none declare a `postflight` hook) and via
  grep across each extension for `postflight`/`hook` files.
- Recommended fix: in each `SKILL.md`, add the same two-part shape core and lean/lean-hard/web
  already use — extend the metadata-read block to also read `completion_data.completion_summary`
  / `completion_data.roadmap_items`, then call the existing shared writer
  `skill_propagate_completion_summary` from `agent-system/extensions/core/scripts/skill-base.sh`
  (deployed at `.claude/scripts/skill-base.sh`) rather than duplicating the jq write logic inline.
  `nix`/`nvim` need the bash block added (currently absent); `epidemiology` needs its existing
  block extended.
- Recommend treating "extract postflight into one fully shared script all implementers call" as
  its own follow-up task, not in scope here — see Decisions section for rationale.

## Context & Scope

Prior investigation (out of scope for this task, referenced only) established and repaired a
producer/consumer contract break for `completion_summary`/`roadmap_items` propagation from agent
`.return-meta.json` into `state.json`, across `core`, `core-hard`, `lean`, `lean-hard`, and `web`.
That investigation flagged — but explicitly left unverified and unfixed — a suspected
mirror-image break in three further extensions: `nix`, `nvim`/`neovim`, and `epidemiology`. This
task's scope is to (1) independently verify the break exists per-extension (not assume it from
the prior survey), and (2) apply the established fix shape if verification confirms it,
matching the precedent in the already-correct `core`/`web` skills.

All edits must target `agent-system/extensions/**` (the source store), never `.claude/**` (the
gitignored, disposable deploy artifact).

## Findings

### Codebase Patterns

**The producer side (agent files) — confirmed correct in all three, independently:**

- `agent-system/extensions/nix/agents/nix-implementation-agent.md`: has a section beginning
  "**CRITICAL**: Before writing metadata, prepare the `completion_data` object." with worked
  example under a `completion_data` key containing `completion_summary` and (optionally)
  `roadmap_items`.
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`: same shape — a
  "**CRITICAL**: Before writing metadata, prepare the `completion_data` object." section, an
  example `completion_data` block (`"Configured telescope.nvim with fzf-native sorter..."`), plus
  a closing note: "**Note**: Include `completion_data` when status is `implemented`. The
  `roadmap_items` field is optional."
- `agent-system/extensions/epidemiology/agents/epi-implement-agent.md`: writes a
  `completion_data` object with `completion_summary` (templated on `study_design`/R script count)
  and `roadmap_items` (defaults to `[]`).

**The consumer side (SKILL.md postflight) — confirmed broken in all three, independently:**

- `agent-system/extensions/nix/skills/skill-nix-implementation/SKILL.md`: "### Stage 5: Parse
  Subagent Return" is a single prose line ("Read the metadata file from
  `specs/{N}_{SLUG}/.return-meta.json`."). "### Stage 6: Update Task Status (Postflight)" is a
  single prose line ("Update state.json and TODO.md based on result."). Neither stage — nor any
  other part of the file — mentions `completion_data`, `completion_summary`, `roadmap_items`, or
  the shared writer function. No bash appears in either stage at all.
- `agent-system/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`: byte-for-byte the
  same shape and the same gap as the nix skill (Stage 5/6 are the identical two prose lines, no
  bash, no `completion_data` handling anywhere in the file).
- `agent-system/extensions/epidemiology/skills/skill-epi-implement/SKILL.md`: "### Stage 6: Read
  Metadata File" has a real bash block that reads `meta_status`, `artifact_path`,
  `artifact_type`, `artifact_summary` from `$metadata_file` — but never reads
  `.completion_data.completion_summary` or `.completion_data.roadmap_items`. "### Stage 7: Update
  Task Status (Postflight)" is a markdown table only (`meta_status` -> final `state.json`/TODO.md
  status) with no bash at all — no call site exists for writing `completion_summary` or
  `roadmap_items` into `state.json` anywhere in the file. `task_type` is already a bash variable
  in this file (`task_type=$(echo "$task_data" | jq -r '.task_type // ""')` at Stage 1), unlike
  nix/nvim.

**No compensating indirection found:**

- None of the three extensions' `manifest.json` declares a `postflight` lifecycle hook (`nix`:
  `preflight` + `context_injection` only; `nvim`: `context_injection` only; `epidemiology`: empty
  `hooks: {}`).
- No extension-local script or hook file matching `*hook*`/`*postflight*` exists under
  `nix/`, `epidemiology/`, or the skill-relevant parts of `nvim/` (the one `nvim/context/.../hooks`
  directory hit is Neovim autocommand-hook documentation, unrelated to skill lifecycle hooks).
- None of the three `SKILL.md` files source `.claude/scripts/skill-base.sh` or call
  `skill_propagate_completion_summary` anywhere.
- `agent-system/extensions/core/scripts/update-task-status.sh` (the shared status-update script
  these skills could in principle call) does not itself read or write `completion_data`,
  `completion_summary`, or `roadmap_items` — confirmed via grep, zero matches. So even a skill
  that called this script would still need the same additional read-and-propagate step; there is
  no shortcut through that script.

### The Established Fix Shape (from core/web precedent)

Two live variants of the "correct" shape exist side by side in already-fixed skills, and they are
not identical:

1. **`core/skills/skill-implementer/SKILL.md`** (current, consolidated pattern): reads
   `completion_summary`/`roadmap_items` from the metadata file in Stage 6, then in the Stage 7
   postflight calls the single shared writer:
   ```bash
   source .claude/scripts/skill-base.sh
   skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"
   ```
   `skill_propagate_completion_summary` (defined in
   `agent-system/extensions/core/scripts/skill-base.sh`) is documented in its own header comment
   as "replacing what were previously three independently-maintained copies (skill-implementer,
   skill-implementer-hard, and the orphaned orchestrator-postflight.sh Stage 7b)" — i.e. this
   function is itself the outcome of an earlier consolidation pass driven by the same
   duplication concern raised for this task.

2. **`web/skills/skill-web-implementation/SKILL.md`** (older, pre-consolidation pattern): reads
   the same two fields, then writes them with an inline five-step jq sequence duplicated directly
   in the file (status update, `completion_summary` write, `roadmap_items` write, artifact-array
   filter, artifact-array append) — i.e. `web` has not yet been migrated onto
   `skill_propagate_completion_summary` and still duplicates the write logic core no longer does.

Both are "correct" in the narrow sense that `completion_data` does reach `state.json` in both —
but only the `core` variant satisfies this task's explicit instruction to add "a short postflight
read-and-write step referencing that schema... NOT duplicating the schema into each file." The
`web` variant is exactly the duplication pattern the task instructs against, and is legacy from
before `skill_propagate_completion_summary` existed rather than a second endorsed pattern.

**Recommendation**: fix `nix`, `nvim`, and `epidemiology` using the `core` shape (shared-function
call), not the `web` shape (inline duplication).

### Recommendations (per-file fix plan)

**`nix/skills/skill-nix-implementation/SKILL.md`** and
**`nvim/skills/skill-neovim-implementation/SKILL.md`** (identical shape, same fix twice):

- Anchor: "### Stage 5: Parse Subagent Return" / "Read the metadata file from
  `specs/{N}_{SLUG}/.return-meta.json`." — replace the one-line prose with a bash block reading
  `status`, `artifact_path`/`type`/`summary`, and (new) `completion_summary`/`roadmap_items` from
  `$metadata_file`, mirroring core's Stage 6 bash block.
- Anchor: "### Stage 6: Update Task Status (Postflight)" / "Update state.json and TODO.md based
  on result." — after the existing status-update call, add:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "nix"
  ```
  (literal `"nix"` / `"neovim"` in place of a `$task_type` variable — unlike core/web/epi, these
  two skills are single-task-type wrappers and never define a `task_type` bash variable anywhere
  in the file; introducing one solely for this call would be unnecessary scope. Using the literal
  is also self-documenting given the guard's `task_type != "meta"` semantics can never trigger for
  either value.)

**`epidemiology/skills/skill-epi-implement/SKILL.md`**:

- Anchor: inside the existing "### Stage 6: Read Metadata File" bash block, immediately after the
  `artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")` line and before the
  `else` — add:
  ```bash
      completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
      roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
  ```
- Anchor: "### Stage 7: Update Task Status (Postflight)" — this stage is currently table-only
  with no bash; add a bash block after the table (gated on `meta_status == "completed"`, matching
  the table's own "completed" row) that sources `skill-base.sh` and calls
  `skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"`
  — `$task_type` already exists as a bash variable from Stage 1 in this file, so no literal
  substitution is needed here (unlike nix/nvim).

All three fixes are pure additions to existing postflight stages; no restructuring of stage
numbering, trigger conditions, or agent-side content is required or in scope.

## Decisions

- **Verification-first outcome**: all three extensions confirmed broken exactly as characterized
  in the delegation context; none is "already correct." No fix was skipped.
- **Fix shape chosen**: use `skill_propagate_completion_summary` (the `core` shared-function
  pattern), not the inline duplicated jq sequence (the older `web` pattern), per the task's
  explicit "NOT duplicating the schema into each file" instruction.
- **Shared-script extraction (standing recommendation from prior work)**: NOT undertaken in this
  task. Recommend recording it as its own follow-up task instead. Rationale:
  - The function-level extraction this task's fix shape depends on
    (`skill_propagate_completion_summary` in `skill-base.sh`) already *is* the shared
    implementation — it already eliminates the jq-write duplication across every caller that uses
    it. What remains "duplicated" per-file after this task's fix is only the two-line
    source-and-call boilerplate (`source .claude/scripts/skill-base.sh` +
    `skill_propagate_completion_summary ...`), not the write logic itself.
  - A further step (a single script/hook that every implementer skill invokes without even that
    two-line boilerplate — e.g. a postflight lifecycle hook) would need to also touch the
    already-fixed `core`, `core-hard`, `lean`, `lean-hard`, and `web` skills to stay consistent,
    which is materially larger in scope and risk than this task's three-file, additive fix, and
    would benefit from its own design pass (e.g. should it be a `manifest.json`-declared
    `postflight` hook per the existing lifecycle-hook mechanism, given none of the six
    implementer skills currently use one for this purpose?).
  - Keeping this task scoped to the three confirmed-broken files avoids conflating a correctness
    fix (data silently dropped today) with a larger refactor (reducing 6+ files' boilerplate by
    one further script), which is safer to land and easier to verify independently.

## Risks & Mitigations

- **Risk**: `nix`/`nvim` currently have zero bash in Stages 5/6; adding bash blocks changes the
  file's character noticeably (prose-only -> bash-containing). Mitigation: keep the added bash
  minimal and modeled directly on core's Stage 6/7 blocks rather than inventing new structure;
  preserve all existing prose/stage headings unchanged.
- **Risk**: hardcoding `"nix"`/`"neovim"` as the `task_type` argument to
  `skill_propagate_completion_summary` could drift if either skill is ever made to serve more
  than one task type. Mitigation: noted explicitly in the fix plan above so a future implementer
  is not surprised; low risk since both skills' Trigger Conditions sections already hardcode a
  single task_type string.
- **Risk**: epidemiology's Stage 7 currently has no bash at all (table-only); inserting a bash
  block must be gated correctly to only run when `meta_status == "completed"`, matching the
  existing table's semantics, to avoid writing completion fields for `partial`/`failed` returns.

## Context Extension Recommendations

- **Topic**: shared postflight completion-data propagation.
- **Gap**: `return-metadata-file.md` documents the schema and names
  `skill_propagate_completion_summary` as "one of six call sites that converge on that single
  function" (per core's own comment), but there is no context file enumerating which of the
  known implementer skills (`core`, `core-hard`, `lean`, `lean-hard`, `web`, plus — once this task
  lands — `nix`, `nvim`, `epidemiology`) currently call it vs. still duplicate the write inline
  (`web`) vs. previously omitted it entirely (`nix`/`nvim`/`epidemiology` before this fix).
- **Recommendation**: after this task and any follow-up `web`-migration/shared-script-extraction
  task land, consider adding a short "Known callers" list to `return-metadata-file.md`'s
  `completion_data` section so a future extension author can see the converged pattern at a
  glance rather than rediscovering it by grepping every implementer skill.

## Appendix

### Search queries / greps used

- `grep -n "completion_summary\|completion_data\|roadmap_items\|skill_propagate_completion_summary" <file>`
  across `core/skills/skill-implementer/SKILL.md`, `web/skills/skill-web-implementation/SKILL.md`,
  `nix/skills/skill-nix-implementation/SKILL.md`,
  `nvim/skills/skill-neovim-implementation/SKILL.md`,
  `epidemiology/skills/skill-epi-implement/SKILL.md`.
- `grep -n "completion_data\|completion_summary\|roadmap_items" <agent file>` against
  `nix/agents/nix-implementation-agent.md`, `nvim/agents/neovim-implementation-agent.md`,
  `epidemiology/agents/epi-implement-agent.md`.
- `find nix -iname '*hook*' -o -iname '*postflight*'` (and same for `nvim`, `epidemiology`);
  `jq '.hooks' */manifest.json` for `nix`, `nvim`, `epidemiology`.
- `grep -n "completion_data\|completion_summary\|roadmap_items" core/scripts/update-task-status.sh`
  (zero matches — confirms the shared status script has no completion-data handling of its own).

### References

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — canonical
  `completion_data` schema.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_propagate_completion_summary`
  definition (its header comment documents it as replacing three prior independently-maintained
  copies).
