# Research Report: Task #838

**Task**: 838 - fix_planner_return_meta_clobber
**Started**: 2026-07-12T18:00:00Z
**Completed**: 2026-07-12T18:10:00Z
**Effort**: small (single missing stage in one file, plus doc clarifications)
**Dependencies**: None (independent per task description)
**Sources/Inputs**: Codebase (.claude/context/formats/return-metadata-file.md, .claude/skills/*, .claude/scripts/*, .claude/agents/*)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The bug is real but the framing in the task description ("planner overwrites .return-meta.json wholesale") is slightly imprecise: `.return-meta.json` is *by design* a per-phase scratch file — every lifecycle skill (`skill-researcher`, `skill-planner`, `skill-implementer`, and their `-hard` variants) creates it fresh at Stage 0/Stage 5b and deletes it unconditionally in its final Cleanup stage. Accumulation of `memory_candidates` is *supposed* to happen by each skill's postflight reading the field out of `.return-meta.json` and appending it into `state.json` (`active_projects[].memory_candidates`) **before** the scratch file is deleted.
- **The actual defect**: `skill-planner/SKILL.md` (the non-`--hard` planner skill used by plain `/plan N`) is the *only* core lifecycle skill missing this extraction+append step. Its postflight goes straight from "Stage 7: Update Task Status" to "Stage 8: Link Artifacts" — it never reads `.memory_candidates` from the metadata file at all — and then Stage 10 unconditionally `rm -f`s `.return-meta.json`. Any `memory_candidates` the planner-agent subagent emitted (per its own Stage 6b instructions, which explicitly say to include `memory_candidates` in its metadata write) are silently discarded.
- **Corroborating proof of drift**: `skill-planner-hard/SKILL.md` Stage 7a literally says "Same as `skill-planner` Stage 7a pattern" — but `skill-planner` (base) has no Stage 7a. This is a dangling reference confirming the base skill once had (or was always meant to have, mirroring its siblings) this stage and it is missing.
- `skill-researcher`, `skill-researcher-hard`, `skill-implementer`, `skill-implementer-hard`, and `skill-planner-hard` all correctly implement the read-then-append pattern. `skill-planner` is the sole outlier.
- **Secondary gap (same family, larger scope)**: the three team skills (`skill-team-research`, `skill-team-plan`, `skill-team-implement`) never read or propagate `memory_candidates` at all — not from a prior phase's file, and not from teammates' own outputs before synthesis. This is a distinct, broader hole in the same contract but is not what task #831 hit (team mode wasn't in play) and is offered here as an optional wider fix, not the primary defect.
- `.claude/scripts/orchestrator-postflight.sh` (which *does* implement `memory_candidates` propagation correctly, with append semantics) is dead code from the perspective of the plain lifecycle: it is referenced only in prose/comments across the codebase ("canonical authority", "single shared execution site") but is never actually invoked by `skill-researcher`, `skill-planner`, or `skill-implementer` — those skills each carry their own inline duplicate of the postflight stages. This is a pre-existing architecture (not something to "fix" as part of clobber remediation) but worth noting since it means fixing `skill-planner`'s inline stages, not the shared script, is what actually matters.
- Recommended fix: add a `memory_candidates` read to `skill-planner/SKILL.md` Stage 6, and insert a new "Stage 7a: Propagate Memory Candidates" between the existing Stage 7 and Stage 8, using the exact append-semantics jq pattern already used verbatim in `skill-researcher/SKILL.md` (lines 433-446) and `skill-implementer/SKILL.md` (lines ~542-546). No schema change to `return-metadata-file.md` is strictly required — the contract already documents `memory_candidates` and the append-semantics note — but the contract could be tightened to explicitly state that `.return-meta.json` is a single-phase scratch file and that **all** lifecycle skills MUST implement the read+append pattern for `memory_candidates` (and any future accumulate-type field), closing the loophole that let `skill-planner` silently diverge with no test catching it.

## Context & Scope

Task 838 (`meta`) targets a data-loss bug: when `/plan N` runs after `/research N`, the planner
phase's postflight is claimed to destroy `memory_candidates` emitted during research. File scope
for the fix is `.claude/context/formats/return-metadata-file.md` and `.claude/skills/`. This
report investigates (a) the current documented contract, (b) how each lifecycle skill actually
reads/writes `.return-meta.json` in postflight, (c) exactly which code path clobbers data, and
(d) the correct merge strategy — i.e., which fields are meant to accumulate across phases vs.
which are legitimately phase-owned and safe to overwrite each phase.

## Findings

### The contract (`return-metadata-file.md`)

- `.return-meta.json` lives at `specs/{NNN}_{SLUG}/.return-meta.json` and is documented as a
  request/response handoff file between a subagent and its wrapping skill.
- The "Cleanup" section explicitly instructs: "After postflight, delete the metadata file" via
  `rm -f`. This confirms the file is intentionally single-phase/ephemeral, not a cross-phase
  accumulator — the design already anticipates deletion after every phase.
- `memory_candidates` is documented (0-3 items) with an explicit note: "Skill postflight
  propagates candidates to state.json task entries with append semantics." This is a stated
  requirement that the current contract text does not enforce or link to a specific
  implementation site — it's aspirational prose with no consistency check against the actual
  skill files.
- No field in the schema is documented as "the .return-meta.json file itself must be merged
  across phases" — the schema's own examples (Research Success, Planning Success, Implementation
  Success) each show a complete, self-contained, single-phase document. The correct mental model
  the contract already implies is: **scratch file per phase, with explicit extraction of
  accumulate-type fields into `state.json` as the merge mechanism** — not JSON-file-level merging.

### How each skill actually reads/writes the file (grep across `.claude/skills/`)

| Skill | Reads `memory_candidates` in Stage 6? | Has a propagate-to-state.json stage? | Cleanup deletes file? |
|---|---|---|---|
| `skill-researcher` | Yes (`SKILL.md:385`) | Yes — Stage 7a (`SKILL.md:433-446`), append semantics via `// [] + $new_candidates` | Yes, Stage 9 |
| `skill-researcher-hard` | Yes (`SKILL.md:289`) | Yes — Stage 7a (`SKILL.md:326`), "Same as skill-researcher Stage 7a" | Yes, Stage 9 |
| `skill-implementer` | Yes (`SKILL.md:434`) | Yes — inline block (`SKILL.md:542-546`), same append pattern | Yes, Stage 10 |
| `skill-implementer-hard` | Yes (`SKILL.md:364`) | Yes — Stage 7a (`SKILL.md:401`) | Yes, Stage 9 |
| `skill-planner-hard` | Yes (`SKILL.md:303`) | Yes — Stage 7a (`SKILL.md:473`), text says "Same as `skill-planner` Stage 7a pattern" | Yes, Stage 9 |
| **`skill-planner` (base)** | **No** — Stage 6 (`SKILL.md:397-413`) only reads `status`, `artifact_path`, `artifact_type`, `artifact_summary` | **No** — postflight jumps from Stage 7 (Update Task Status, `SKILL.md:434-444`) directly to Stage 8 (Link Artifacts, `SKILL.md:448-468`); no Stage 7a exists | Yes, unconditionally, Stage 10 (`SKILL.md:513-521`) |
| `skill-team-research` | No | No | Yes (Stage 13) |
| `skill-team-plan` | No | No | Yes (Stage 13) |
| `skill-team-implement` | No | No | Yes (Stage 15) |

This is the exact, concrete defect: **`skill-planner/SKILL.md` never extracts `memory_candidates`
from the metadata file before its Stage 10 unconditionally deletes it.** Since the planner-agent
subagent (`.claude/agents/planner-agent.md` Stage 6b: "Include `memory_candidates` array (from
Stage 5a) at the top level of the JSON output") is instructed to emit candidates into that same
file, any candidates it emits are written, never read by the wrapping skill, and then destroyed
by `rm -f` — a genuine, silent, unrecoverable data-loss path.

The `skill-planner-hard/SKILL.md:475` line ("Same as `skill-planner` Stage 7a pattern") is a
dangling reference to a stage that does not exist in the base skill, corroborating that the base
skill is the outlier/regression rather than the hard variant being ahead of a deliberately
simpler design.

### Why the task's literal framing ("research candidates destroyed by planner overwrite") is plausible even though `skill-researcher` itself correctly propagates

`skill-researcher`'s own Stage 7a is correct — research's candidates should already be safely
appended into `state.json` by the time research's own Cleanup stage deletes
`.return-meta.json`, *before* `/plan` ever starts. So a literal file-level "planner clobbers
research's leftover JSON" scenario would require research's own propagation or cleanup to have
been skipped (e.g., a partial/failed research run, or a self-execution-fallback path). The
simpler and more robust explanation consistent with the task's outcome (candidates lost
regardless of provenance) is that **any** `memory_candidates` present when `skill-planner`'s
postflight runs — whether newly emitted by the planner-agent itself, or (in edge cases) leftover
from an interrupted prior phase — are unconditionally discarded because `skill-planner` is the
one skill in the core chain with no extraction/append logic. This matches the task's stated
generalization: "This affects EVERY task where research emits memory_candidates and a later
phase rewrites the file" — the rewriting phase (planner) is the one with the missing merge logic,
regardless of exactly whose candidates end up in the file at that moment.

### `orchestrator-postflight.sh` is not actually wired in

`.claude/scripts/orchestrator-postflight.sh` implements `memory_candidates` propagation
correctly (Stage 7c, `orchestrator-postflight.sh:252-269`, same append-via-python3 pattern) and
its own header comment claims "skill-researcher/SKILL.md calls this for Stages 6-9" and
"skill-planner/SKILL.md calls this for Stages 6-10". A repo-wide grep for actual invocations
(`bash .claude/scripts/orchestrator-postflight.sh` or similar) found **zero** call sites in any
`SKILL.md`. Every reference to the script outside its own file is prose citing it as a "canonical
authority" (e.g. `.claude/context/standards/git-staging-scope.md`) or a code comment
acknowledging both an inline path and the script exist "in the codebase" — never an actual
invocation. Each lifecycle skill instead carries its own hand-duplicated inline copy of the
postflight stages. This means:
- Fixing `orchestrator-postflight.sh` alone would NOT fix the live bug — it is unreachable code
  as far as the current `/plan` flow is concerned.
- The task's file scope (`.claude/skills/`) correctly targets the actual fix site.
- This duplication-without-a-single-source-of-truth is itself a latent risk (this exact class of
  bug — one copy fixed, siblings not — is how `skill-planner` diverged from
  `skill-researcher`/`skill-implementer`/`skill-planner-hard` in the first place) but restructuring
  the four skills to actually call the shared script is a larger refactor outside this task's
  scope; noted as a Context Extension Recommendation below.

### Merge strategy: accumulate vs. phase-owned fields

Given `.return-meta.json` is correctly a per-phase scratch file (not a cross-phase document to be
JSON-merged), the "merge" belongs at the `state.json` extraction step, field by field:

**Accumulate (append semantics, must survive across phases in `state.json`)**:
- `memory_candidates` — append array; already documented with `// []` fallback for
  backward-compat reads. This is the field task #838 is about.
- `artifacts` — accumulates by *type*, not raw append: each skill's Stage 8 does a two-step jq
  (filter out existing entries where `.type` matches the current phase's artifact type, then add
  the new one). This is already correct in every lifecycle skill including `skill-planner`
  (`SKILL.md:448-468`) — `skill-planner` fixes artifacts correctly, it's specifically
  `memory_candidates` it drops. Worth confirming any fix does not disturb this working pattern.
- `modified_files` (implement-only, self-reported touched-file list) — was documented as
  accumulating from each phase's progress-file `files_touched` field for git-staging-scope
  purposes. Note: at the time of this research, an *unrelated, uncommitted* local working-tree
  change removes this field from `return-metadata-file.md` (`git diff` shows a straight
  reversion, unstaged, on top of `.claude/skills/skill-{implementer,planner,researcher}-hard`
  literature-briefing script-name fixes) — this appears unrelated to task 838 and should not be
  treated as authoritative; flagged here only so the implementer doesn't confuse it with an
  838-related change.

**Phase-owned (legitimately overwritten fresh each phase, no merge needed)**:
- `status` — always reflects the current phase's own outcome (`researched`/`planned`/`implemented`/etc.).
- `next_steps`, `partial_progress`, `started_at`, `completion_data`, `errors` — each describes
  the current phase's own execution; state.json's own `status`/`completion_summary`/etc. fields
  already get set fresh by `update-task-status.sh` per phase, so there's nothing to merge.
- `metadata` (`session_id`, `agent_type`, `duration_seconds`, `delegation_depth`,
  `delegation_path`, and per-agent-type extras like `findings_count`/`phases_completed`) —
  intrinsically phase-specific (different `agent_type` and `session_id` every phase); overwriting
  is correct.

So the "fix" is narrow and field-specific: it is **not** "stop overwriting `.return-meta.json`"
(the file legitimately gets recreated every phase) — it is "make `skill-planner`'s postflight
extract `memory_candidates` (the one accumulate-type field it currently ignores) into
`state.json` before the scratch file is deleted," bringing it in line with its four siblings.

### Recommendations (implementation-facing, for `/plan 838`)

1. **Primary fix** — `.claude/skills/skill-planner/SKILL.md`:
   - Stage 6 (`SKILL.md:397-413`): add
     `memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")` alongside the
     existing `status`/`artifact_path`/`artifact_type`/`artifact_summary` reads.
   - Insert a new "Stage 7a: Propagate Memory Candidates" immediately after the current Stage 7
     (`SKILL.md:434-444`) and before Stage 8 (`SKILL.md:448`), using the identical append-semantics
     jq block from `skill-researcher/SKILL.md:438-446` (guard on
     `[ "$memory_candidates" != "[]" ]`, then
     `.active_projects[] | select(...).memory_candidates = (existing // [] + $new_candidates)`).
   - Renumber subsequent stages (old Stage 8→8, but note the doc currently has "Stage 8", "Stage
     8a", "Stage 9" (Git Commit), "Stage 10" (Cleanup), "Stage 11" (Return); inserting 7a keeps
     numbering clean without renumbering later stages, matching how `skill-researcher` and
     `skill-implementer` both use letter-suffixed stage numbers for this exact purpose).
2. **Consistency fix** — remove or correct the dangling `skill-planner-hard/SKILL.md:475`
   reference ("Same as `skill-planner` Stage 7a pattern") once the base skill actually has that
   stage (it becomes accurate rather than dangling).
3. **Contract clarification** (optional, in `.claude/context/formats/return-metadata-file.md`) —
   add a short "Merge Semantics" subsection under `memory_candidates` (or as a new top-level
   section) stating explicitly: `.return-meta.json` is a single-phase scratch file that MUST be
   fully read and its accumulate-type fields (currently: `memory_candidates`) extracted into
   `state.json` by every lifecycle skill's postflight before the file is deleted; enumerate which
   fields are accumulate vs. phase-owned (per the table above) so future skills/extensions don't
   repeat the `skill-planner` omission.
4. **Optional wider scope** — extend the same read+append `memory_candidates` stage to
   `skill-team-plan`, `skill-team-research`, and `skill-team-implement` (currently none of the
   three propagate memory candidates at all, from any teammate or synthesis output). This is a
   separate, larger gap not implicated in the #831 incident (team mode) — recommend scoping as a
   follow-up task rather than folding into 838's fix, to keep 838's diff small and matched to the
   concrete, confirmed defect.

## Decisions

- Treat `skill-planner/SKILL.md`'s missing Stage 6 read + Stage 7a propagate as the sole
  confirmed, in-scope defect to fix for task 838. It is the only code path in the core
  research→plan→implement chain that is missing this pattern, it directly matches the task's
  "planner phase drops memory_candidates" description, and it has a ready-made, already-proven
  correct implementation to copy verbatim from three sibling skills.
- Do not attempt to change `.return-meta.json` into a cross-phase-merged document. The scratch-file
  design (write fresh, read once, delete) is sound; the bug is a missing read, not a wrong
  overwrite semantics at the file level.
- Do not fix `.claude/scripts/orchestrator-postflight.sh` as part of this task — it is unreachable
  from the current skills and out of the literal clobber bug's path; note its dead-code status as
  a separate follow-up concern rather than conflating it with the fix.

## Risks & Mitigations

- **Risk**: Copy-pasting the append-semantics jq block into `skill-planner/SKILL.md` without
  updating the task_number interpolation could reintroduce a jq Issue #1132 escaping bug.
  **Mitigation**: copy verbatim from `skill-researcher/SKILL.md:438-446`, which already uses the
  `--argjson` pattern correctly; do not hand-retype it.
- **Risk**: Renumbering stages could break other docs/scripts that reference `skill-planner`
  Stage numbers by number (e.g. `skill-planner-hard`'s dangling reference, or any test fixtures).
  **Mitigation**: insert as "Stage 7a" (letter suffix), not a renumbered "Stage 8", exactly
  mirroring how `skill-researcher` already handles this (Stage 7 → 7a → 8), so no existing stage
  numbers shift.
- **Risk**: Fixing only `skill-planner` leaves the team-mode gap unaddressed, so a future
  `--team` incident could reproduce a similar loss.
  **Mitigation**: documented as an explicit "Optional wider scope" recommendation above rather
  than silently left out.

## Context Extension Recommendations

- **Topic**: Postflight-stage parity across sibling lifecycle skills (researcher/planner/implementer × base/hard × team).
- **Gap**: No automated check currently verifies that skills sharing a lifecycle contract (e.g.
  all must propagate `memory_candidates`) actually implement the same required stages. This is
  exactly the class of drift task #837 in `state.json` calls "the same silent-degradation failure
  mode" for contract references, just applied to skill postflight stages instead of `.claude/context/contracts/*.md` references.
- **Recommendation**: consider a follow-up meta task to extend
  `.claude/scripts/check-extension-docs.sh` (or a new sibling validator) to assert that every
  `skill-{researcher,planner,implementer}[-hard]/SKILL.md` postflight section contains a
  `memory_candidates` read + append stage, failing loudly if one is missing — the same
  "LOUD-FAILURE requirement" pattern already used for #837's contract-drift validator.

## Appendix

### Search queries / commands used

- `grep -rln "return-meta" .claude/skills .claude/scripts`
- `grep -n "^### Stage\|memory_candidates" .claude/skills/skill-{researcher,researcher-hard,planner,planner-hard,implementer,implementer-hard}/SKILL.md`
- `grep -rn "orchestrator-postflight.sh" .claude/ --include="*.md" --include="*.sh"`
- `grep -n "memory_candidates\|return-meta" .claude/skills/skill-team-{research,plan,implement}/SKILL.md`
- Read `.claude/context/formats/return-metadata-file.md` (full), `.claude/agents/planner-agent.md` (Stage 6b), `.claude/agents/general-research-agent.md` (Stage 7)
- `git diff --stat` / `git diff` to distinguish pre-existing unrelated uncommitted local changes from task-relevant state
- `jq` lookups against `specs/state.json` to confirm task #831 is archived (`specs/archive/831_fix_literature_conversion_pipeline_correctness`) and to read task #838's own description verbatim

### Key file:line references

- `.claude/skills/skill-planner/SKILL.md:397-413` (Stage 6, missing `memory_candidates` read)
- `.claude/skills/skill-planner/SKILL.md:434-468` (Stage 7 → Stage 8, no Stage 7a between them)
- `.claude/skills/skill-planner/SKILL.md:513-521` (Stage 10, unconditional `rm -f .return-meta.json`)
- `.claude/skills/skill-planner-hard/SKILL.md:473-476` (dangling "Same as skill-planner Stage 7a" reference)
- `.claude/skills/skill-researcher/SKILL.md:385, 433-446` (correct reference implementation)
- `.claude/skills/skill-implementer/SKILL.md:434, 542-546` (correct reference implementation)
- `.claude/scripts/orchestrator-postflight.sh:252-269` (correct but unreachable/unused implementation)
- `.claude/context/formats/return-metadata-file.md:159-192` (`memory_candidates` schema + append-semantics note, no explicit per-skill enforcement)
