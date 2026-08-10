# Implementation Plan: Document the --fable model flag

- **Task**: 804 - Document the --fable model flag alongside --haiku/--sonnet/--opus across the agent system
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 786, 795 (satisfied); coordinated batch with 808/809/810 (locking/gate infra, disjoint file territory)
- **Research Inputs**: specs/804_document_fable_model_flag/reports/01_fable-model-flag-sites.md
- **Artifacts**: plans/02_fable-model-flag-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; artifact-formats.md; plan-format-enforcement.md
- **Type**: meta

## Overview

Add `--fable` (the Fable 5 / `claude-fable-5` model family) as a first-class model flag on
`/research`, `/plan`, and `/implement`, on par with `--haiku`/`--sonnet`/`--opus`, everywhere the
agent system enumerates model flags. The research report established that `--fable` has **zero**
current references and that the single functional wiring gap is `parse-command-args.sh` (plus its
`extensions/core` mirror); everything else is documentation duplicated across three parallel trees
(`.claude/`, `.claude/extensions/core/`, `.opencode/`) plus the CLAUDE.md merge-source. Definition
of done: `--fable` is parsed into `MODEL_FLAG="fable"`, stripped from `FOCUS_PROMPT`, and appears in
every model-flag enumeration site the report inventoried, with all dual/triple-copy pairs kept
byte-identical (or intentionally consistent for `.opencode/`).

### Research Integration

This plan is a direct phased edit list derived from the report's tier inventory (Tiers 1-6) and its
Recommendations 1-6. Key integrated decisions:
- Parser fix is functional and goes first (Recommendation 1).
- CLAUDE.md content is generated: edit `.claude/extensions/core/merge-sources/claudemd.md`, never
  `.claude/CLAUDE.md` directly (Recommendation 2, memory candidate).
- `--fable` is scoped to the **override-flags** surface only in `agent-frontmatter-standard.md`, not
  added as a new frontmatter default tier (Recommendation 3), matching how `haiku` is handled.
- `command-route-skill.sh`, `/orchestrate`, and the `-hard` skill JSON passthrough fields need **no**
  edit (Recommendations 4-5; Decisions section of report).
- `meta-guide.md`'s negative enumeration must also list `--fable` for consistency (Recommendation 6).

### Prior Plan Reference

No prior plan. `plans/` contained no earlier version at planning time; this is the first plan for
task 804 (numbered `02` to follow the research report's `01` round per the orchestrator dispatch).

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context and `roadmap_flag` was not set; no ROADMAP.md
phases added. This task advances the "documented, first-class model flags" surface of the agent
system.

## Goals & Non-Goals

**Goals**:
- Wire `--fable` into `parse-command-args.sh` (and its core mirror) so `MODEL_FLAG="fable"` is set
  and `--fable` is stripped from `FOCUS_PROMPT`.
- Document `--fable` in every model-flag enumeration site identified in the report (command markdown,
  CLAUDE.md merge-source, agent-frontmatter-standard, skill prose, guides/architecture docs,
  meta-guide negative enumeration).
- Keep all byte-identical mirror pairs identical after edits; keep `.opencode/` copy consistent.

**Non-Goals**:
- No changes to `task-lock.sh` or any gate/locking scripts (owned by batch tasks 808/809/810).
- No changes to `command-route-skill.sh` (does not touch model flags).
- No `--fable` support added to `/orchestrate` or `/orchestrate --hard` (out of scope per report).
- No new frontmatter default tier `model: fable`; `--fable` is an invocation-time override only.
- No new sync/generation script for the command/skill mirror trees (a candidate for later
  audit tasks 811-814, not this task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Mirror pairs drift when edited independently | M | M | Each phase edits both copies together and runs `diff` to confirm byte-identity before completing |
| An undiscovered sync/generation script overwrites hand edits | M | L | Phase 1 and Phase 4 re-check for a "Load Core"/merge/generation script before hand-editing; if found, use it |
| Editing `.claude/CLAUDE.md` directly (gets regenerated away) | M | L | All CLAUDE.md content edits land in the merge-source `claudemd.md`; Phase 4 regenerates only via the documented mechanism |
| `--fable` precedence when combined with another model flag | L | L | Append `--fable` branch last -> last-match-wins per agent-frontmatter-standard line 104; documented, acceptable |
| Scope creep into batch 808/809/810 territory | M | L | Non-Goals explicitly exclude lock/gate files; verification grep in Phase 8 confirms only model-flag files changed |
| `.opencode/` copy treated as out of scope and left stale | L | M | Phase 3 explicitly includes the OpenCode copy for design coherence (same flag surface, claimed-active runtime) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7 | 1 |
| 3 | 8 | 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Wave-2 phases each own a disjoint set of files
(no shared file between any two phases), so they satisfy territory-contract isolation and may run
concurrently. Phase 1 is sequenced first as the functional anchor so Phase 8 can verify the full
parse-to-doc chain.

### Phase 1: Wire --fable into the parser [COMPLETED]

- **Goal:** Add the functional `--fable` -> `MODEL_FLAG="fable"` branch and `FOCUS_PROMPT` strip to
  both parser copies; this is the only behavior change in the task.
- **Tasks:**
  - [x] Re-check `.claude/scripts/` for a sync/generation script that would auto-propagate one parser
    copy to the other; if none, treat both as manual edit targets. *(completed: no sync/generation script found; both copies edited manually)*
  - [x] In `.claude/scripts/parse-command-args.sh`: after the `--opus` MODEL_FLAG check (report lines
    ~91-99), add a fourth branch `if [[ "$remaining" =~ --fable ]]; then MODEL_FLAG="fable"; fi`
    appended last (preserves existing last-match-wins precedence). *(completed)*
  - [x] In the same file: after the `sed 's/--opus//g'` strip (report lines ~117-130), add
    `| sed 's/--fable//g'` so `--fable` is removed from `FOCUS_PROMPT`. *(completed)*
  - [x] Update the header comment (report line 17) `MODEL_FLAG — "haiku", "sonnet", "opus", or ""` to
    include `"fable"`. *(completed)*
  - [x] Apply the identical three edits to `.claude/extensions/core/scripts/parse-command-args.sh`. *(completed)*
  - [x] Run `diff` between the two files to confirm they remain byte-identical. *(completed: diff produced no output)*
- **Timing:** 0.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/scripts/parse-command-args.sh` - add fourth model-flag branch, sed strip, header comment
  - `.claude/extensions/core/scripts/parse-command-args.sh` - identical edits (mirror)
- **Verification:**
  - `bash .claude/scripts/parse-command-args.sh "/research 42 --fable"` (or the script's actual
    invocation form) exports `MODEL_FLAG=fable` and a `FOCUS_PROMPT` with `--fable` removed.
  - `diff .claude/scripts/parse-command-args.sh .claude/extensions/core/scripts/parse-command-args.sh`
    produces no output.

### Phase 2: Command markdown (Claude-Code copies + core mirror) [COMPLETED]

- **Goal:** Add `--fable` to argument-hints, Options tables, Extract-Model-Flags steps, focus-prompt
  strip lines, and model-resolution mappings in the three command files and their byte-identical core
  mirror.
- **Tasks:**
  - [x] In `.claude/commands/research.md`: argument-hint (line 4), Options-table rows (36-38),
    "Extract Model Flags" step bullets + fallback (293-300), focus-prompt strip line (319),
    model-resolution mapping + null fallback (408-411) — add a `--fable`/`fable` entry in each. *(completed)*
  - [x] In `.claude/commands/plan.md`: mirror the same additions at lines 4, 31-33, 301-305, 413-416. *(completed: plan.md has no explicit "Remove --haiku..." strip line to mirror; other four sites updated)*
  - [x] In `.claude/commands/implement.md`: argument-hint (line 4) and Options table (26-28) only —
    it has no explicit Extract-Model-Flags step (relies on the sourced parser from Phase 1). *(completed)*
  - [x] Apply the identical edits to `.claude/extensions/core/commands/{research,plan,implement}.md`. *(completed)*
  - [x] `diff` each Claude-Code file against its core mirror to confirm byte-identity. *(completed: all three pairs identical)*
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md`
  - `.claude/extensions/core/commands/research.md`, `.../plan.md`, `.../implement.md`
- **Verification:**
  - `diff .claude/commands/{research,plan,implement}.md .claude/extensions/core/commands/{research,plan,implement}.md`
    produces no output.
  - `grep -c -- '--fable' .claude/commands/research.md` returns a count matching the number of
    `--opus` occurrences in the same file.

### Phase 3: OpenCode command copies [COMPLETED]

- **Goal:** Add `--fable` to the third, near-identical `.opencode/commands/` copy for design
  coherence (same flag surface, claimed-active runtime).
- **Tasks:**
  - [x] In `.opencode/commands/research.md`: argument-hint (line 4), Options table (37-39),
    Extract-Model-Flags step (295-300, +313), model-resolution block (423-426) — add `--fable`,
    preserving this copy's own fallback wording ("use agent default, currently opus..."). *(completed)*
  - [x] In `.opencode/commands/plan.md`: lines 4, 32-34, 303-308, 431-434. *(completed: this copy has no explicit "Remove --haiku..." strip line to mirror)*
  - [x] In `.opencode/commands/implement.md`: lines 4, 31-33, 336-341 (this copy DOES have an explicit
    Extract-Model-Flags step, unlike the Claude-Code copy), 466-469. *(completed)*
  - [x] Do not force byte-identity with the Claude-Code copies (they are intentionally not identical);
    only ensure the `--fable` flag surface is consistently present. *(completed: verified via grep count parity with --opus)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.opencode/commands/research.md`, `.opencode/commands/plan.md`, `.opencode/commands/implement.md`
- **Verification:**
  - `grep -rl -- '--fable' .opencode/commands/` lists all three files.
  - Each file's `--fable` occurrence count matches its `--opus` count.

### Phase 4: CLAUDE.md merge-source + regeneration [COMPLETED]

- **Goal:** Add `--fable` to the CLAUDE.md content via its generation source, never the generated
  file, then regenerate.
- **Tasks:**
  - [x] Edit `.claude/extensions/core/merge-sources/claudemd.md` at the three sites (report lines
    93-95 Command Reference usage strings for `/research`,`/plan`,`/implement`; line 227 "Model
    Enforcement" paragraph; line 282 Hard-Mode composability bullet) to add `--fable`. *(completed)*
  - [x] Do NOT edit `.claude/CLAUDE.md` directly. *(completed: not touched)*
  - [x] Locate and run the documented CLAUDE.md regeneration mechanism (extension loader / merge
    step) to regenerate `.claude/CLAUDE.md` from merge-sources. If no runnable regeneration script
    exists in this environment, note in the summary that `.claude/CLAUDE.md` will be regenerated on
    the next extension load and leave the generated file untouched. *(deviation: no runnable regeneration script found in .claude/scripts/ — "Load Core" is an interactive picker action, not a CLI script callable from this session; .claude/CLAUDE.md left untouched, will regenerate on next extension load per plan's documented fallback)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/core/merge-sources/claudemd.md` - three model-flag sites
  - `.claude/CLAUDE.md` - only if regenerated via the documented mechanism (never hand-edited)
- **Verification:**
  - `grep -c -- '--fable' .claude/extensions/core/merge-sources/claudemd.md` >= 3.
  - If regenerated: the corresponding sites in `.claude/CLAUDE.md` show `--fable`.

### Phase 5: agent-frontmatter-standard.md + core mirror [COMPLETED]

- **Goal:** Add `--fable` to the model-override documentation (override-flags surface only, not the
  default-tier tables).
- **Tasks:**
  - [x] In `.claude/docs/reference/standards/agent-frontmatter-standard.md`: add `--fable` to the
    override-flags prose (line 55), add a 4th `--fable` row to the "Model flags" table (98-100), and
    add a `--fable` example to the "Examples" block (106-114). *(completed)*
  - [x] Do NOT add a `fable` row to the "Tiered Model Policy"/"Values" default tables (lines ~63,
    83-104 effort area) — `--fable` is an override value, matching how `haiku` is handled. *(completed: left untouched)*
  - [x] Apply identical edits to
    `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`. *(completed)*
  - [x] `diff` the two files to confirm byte-identity. *(completed: identical)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/docs/reference/standards/agent-frontmatter-standard.md`
  - `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- **Verification:**
  - `diff` of the two files produces no output.
  - The "Model flags" table has four rows (haiku, sonnet, opus, fable); the default-tier tables are
    unchanged.

### Phase 6: Skill SKILL.md prose enumerations + core mirrors [COMPLETED]

- **Goal:** Add `fable` to the prose model lists in the skill files that hard-code
  `(haiku, sonnet, opus)`.
- **Tasks:**
  - [x] Add `fable` to the prose model list in `.claude/skills/skill-researcher/SKILL.md` (line 284),
    `skill-planner/SKILL.md` (307), `skill-implementer/SKILL.md` (277). *(completed)*
  - [x] Add `fable` to the `model_flag` table-row description in `skill-team-research/SKILL.md` (43),
    `skill-team-plan/SKILL.md` (41), `skill-team-implement/SKILL.md` (42). *(completed)*
  - [x] Apply identical edits to the `.claude/extensions/core/skills/skill-*` mirrors of the same six
    files; confirm the mirror sync relationship first, then `diff` each pair. *(completed: all six pairs identical)*
  - [x] Do NOT edit the `-hard` skill SKILL.md files or cslib hard variants — they carry only a
    generic `model_flag` passthrough placeholder with no haiku/sonnet/opus literal list (no edit
    needed per report Decisions). *(completed: left untouched)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`
  - `.claude/skills/skill-team-research/SKILL.md`, `skill-team-plan/SKILL.md`, `skill-team-implement/SKILL.md`
  - The `.claude/extensions/core/skills/` mirrors of all six files
- **Verification:**
  - `diff` of each `.claude/skills/...` file against its `.claude/extensions/core/skills/...` mirror
    produces no output.
  - `grep -rl 'fable' .claude/skills/skill-{researcher,planner,implementer}/SKILL.md` lists all three.

### Phase 7: Guides, architecture docs, and meta-guide negative enumeration [COMPLETED]

- **Goal:** Complete the prose-mention sweep and the negative enumeration so no reader infers
  `--fable` is unsupported by omission.
- **Tasks:**
  - [x] `.claude/docs/guides/creating-commands.md` (line 87): add `--fable` to the model-selectors
    list; apply identical edit to `.claude/extensions/core/docs/guides/creating-commands.md`. *(completed)*
  - [x] `.claude/docs/architecture/architecture-spec.md` (line 79): add `"fable"` to the documented
    `MODEL_FLAG` value comment; apply identical edit to the core-extension mirror. *(completed)*
  - [x] `.claude/context/meta/meta-guide.md` (line 237): add `--fable` to the **negative** enumeration
    ("`/meta` does not support ... `--haiku`, `--sonnet`, `--opus`") so it reads as also excluding
    `--fable`; apply identical edit to `.claude/extensions/core/context/meta/meta-guide.md`. *(completed)*
  - [ ] Optional/low-priority: `research-flow-example.md` (line 65) trace shows empty `MODEL_FLAG=`;
    leave as-is unless adding a `--fable` example improves clarity (does not enumerate values). *(deviation: skipped — plan marks this optional/low-priority since it does not enumerate values; left as-is)*
  - [x] `diff` each edited file against its core mirror. *(completed: all three pairs identical)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/docs/guides/creating-commands.md` + `.claude/extensions/core/docs/guides/creating-commands.md`
  - `.claude/docs/architecture/architecture-spec.md` + `.claude/extensions/core/docs/architecture/architecture-spec.md`
  - `.claude/context/meta/meta-guide.md` + `.claude/extensions/core/context/meta/meta-guide.md`
- **Verification:**
  - `diff` of each edited file against its mirror produces no output.
  - meta-guide.md line 237 lists `--fable` within the negative enumeration alongside the other flags.

### Phase 8: Full-system verification pass [COMPLETED]

- **Goal:** Confirm complete, consistent coverage and no out-of-territory changes.
- **Tasks:**
  - [x] Run a repo-wide grep for `--fable`/`fable` across `.claude/`, `.opencode/`, and CLAUDE.md;
    confirm every site the report inventoried (Tiers 1-6) now includes it and no expected site was
    missed. *(completed: all 30 target files confirmed present in grep output; one unrelated
    false-positive substring match in plan-format.md "diffable" noted and ignored)*
  - [x] Re-run all mirror-pair `diff`s from Phases 1-7 in one pass to confirm byte-identity is intact. *(completed: all 14 mirror pairs identical)*
  - [x] Confirm NO changes to `task-lock.sh`, gate scripts, `command-route-skill.sh`, `/orchestrate`
    skills, or `-hard` skill JSON passthrough fields (`git status`/`git diff --stat` scoped review). *(completed: these files appear in `git diff --stat` only because task 808 is concurrently editing them per the coordinated-batch note; none were touched by this task's edits — verified against the full list of files this task modified)*
  - [x] Confirm `.claude/CLAUDE.md` was changed only via regeneration (or intentionally left for next
    load), never hand-edited. *(completed: left untouched; not hand-edited)*
- **Timing:** 0.5 hours
- **Depends on:** 2, 3, 4, 5, 6, 7
- **Files to modify:** none (verification only)
- **Verification:**
  - `git diff --stat` shows only the files enumerated in Phases 1-7 (plus regenerated CLAUDE.md if
    applicable); no lock/gate/route files appear.
  - `grep -rn -- '--fable' .claude/ .opencode/ CLAUDE.md` shows coverage at every inventoried site.

## Testing & Validation

- [x] Parser exports `MODEL_FLAG=fable` for a `--fable` invocation and strips `--fable` from `FOCUS_PROMPT`. *(verified: sourced parser test produced MODEL_FLAG=fable, FOCUS_PROMPT stripped)*
- [x] All byte-identical mirror pairs (`parse-command-args.sh`, command markdown, agent-frontmatter-standard,
      skill files, guides, architecture-spec, meta-guide) pass `diff` with no output. *(verified: all 14 pairs identical)*
- [x] `.opencode/commands/` copies each contain `--fable` at every model-flag site. *(verified: grep counts match --opus counts in all three files)*
- [x] CLAUDE.md content changed only through the merge-source + regeneration path. *(verified: claudemd.md edited; .claude/CLAUDE.md left untouched, no regeneration script available)*
- [x] `git diff --stat` confirms no lock/gate/route files touched (batch 808/809/810 territory intact). *(verified: lock/gate/route files appearing in git diff --stat are from concurrent task 808, not this task's edits)*
- [x] Repo-wide grep shows `--fable` present at every site the report inventoried, absent nowhere expected. *(verified: all 30 target files confirmed)*

## Artifacts & Outputs

- plans/02_fable-model-flag-plan.md (this plan)
- summaries/02_fable-model-flag-summary.md (produced by /implement)
- Modified: both `parse-command-args.sh` copies; command markdown (Claude-Code + core mirror + OpenCode);
  `claudemd.md` merge-source (+ regenerated CLAUDE.md); agent-frontmatter-standard.md (+ mirror);
  six skill SKILL.md files (+ mirrors); creating-commands.md, architecture-spec.md, meta-guide.md (+ mirrors)

## Rollback/Contingency

- All changes are additive edits to documentation and one parser (no deletions, no schema changes),
  so `git checkout -- <file>` on the enumerated files, or `git revert` of the task commit, fully
  reverts with no cascading effects.
- The parser change is the only behavioral change; reverting it restores the prior three-flag
  behavior since `--fable` simply falls through to the empty-`MODEL_FLAG` default (agent frontmatter
  default) if unwired — no crash, graceful degradation.
- If a CLAUDE.md regeneration script is unavailable, leave `.claude/CLAUDE.md` untouched (it
  regenerates from the corrected merge-source on next extension load) rather than hand-editing it.
