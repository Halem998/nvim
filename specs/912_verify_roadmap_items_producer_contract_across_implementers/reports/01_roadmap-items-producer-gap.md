# Research Report: Task #912

**Task**: 912 - Establish whether the roadmap_items producer contract actually runs outside the core implementer
**Started**: 2026-07-26
**Completed**: 2026-07-26
**Effort**: Investigation only (no file edits made)
**Dependencies**: None
**Sources/Inputs**: Codebase read (agent-system source store only; no web search needed)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **A genuine upstream defect is confirmed.** It is not fully explained by the downstream repo's
  28-line-stale deployment, and re-syncing the downstream repo alone would **not** fix the
  observed 0% `roadmap_items` rate.
- **The producer/consumer contract described in CLAUDE.md is actually two links, not one**: (a)
  the *implementation agent* (the subagent spawned by the `SKILL.md`) must generate
  `completion_data.completion_summary` / `.roadmap_items` and write it into
  `.return-meta.json`; (b) the `SKILL.md`'s postflight must read that field back out and write it
  into `state.json`. Both links must hold. The core (`skill-implementer` +
  `general-implementation-agent`) and `web` (`skill-web-implementation` +
  `web-implementation-agent`) pairs have both links intact. **Every other path checked has at
  least one link broken.**
- **Highest-value finding, directly explains the observed evidence**: `lean-implementation-agent.md`
  and `lean-implementation-hard-agent.md` — the agents actually dispatched by
  `skill-lean-implementation` / `skill-lean-implementation-hard` — never instruct the agent to
  generate `completion_data` at all. Their own documented example metadata schemas
  (`lean-implementation-agent.md:200-219`, `lean-implementation-hard-agent.md:384-390`) omit the
  field entirely. Since the confounded downstream repo is lean4-dominated and routes to
  `skill-lean-implementation`, this alone accounts for the 0-out-of-21 result, independent of the
  stale-deployment confound (this is a defect in the **current upstream source**, not a
  downstream-only artifact).
- **Second, independent bug**: `skill-lean-implementation-hard/SKILL.md` reads
  `roadmap_items` from `.completion_data.roadmap_items` into a shell variable (line 290) but then
  never uses it — the write to `state.json` is missing. Even if the agent-side gap above were
  fixed, this SKILL.md would still silently drop the field for hard-mode lean tasks.
- **`skill-implementer-hard/SKILL.md`** never actually generates the field either, because its
  agent (`general-implementation-hard-agent.md`) has the same agent-side gap as lean: no
  `completion_data` instruction anywhere in its "Write Metadata File" stage. The SKILL.md's own
  cross-reference for this step ("Same as `skill-implementer` Stage 7a...") is additionally
  imprecise — `skill-implementer` has no stage literally named "Stage 7a".
- **Related but out-of-file_scope finding**: `nix-implementation-agent.md`,
  `neovim-implementation-agent.md`, and `epi-implement-agent.md` correctly instruct their agents
  to generate `completion_data` (including `roadmap_items`), but their `SKILL.md` orchestrators
  (`skill-nix-implementation`, `skill-neovim-implementation`, `skill-epi-implement`) never read
  or propagate `.completion_data.*` into `state.json` at all — the mirror-image break of the same
  contract. Flagged for a follow-up task since these three files are outside this task's declared
  `file_scope`.
- **The "shared contract" infrastructure the task asks about already exists**:
  `@.claude/context/formats/return-metadata-file.md` documents `completion_data` as a schema,
  explicitly stating `completion_summary` is "mandatory for all `implemented` status returns."
  The defect is not a missing shared file — it's that several agent files either don't reference
  it at all, or reference it but then supply their own concrete "what to write" example that
  silently omits the field, and agents follow the concrete last-mile instruction over the
  abstractly-referenced doc.

## Context & Scope

Investigated whether the `roadmap_items` producer/consumer contract (CLAUDE.md: "/implement is
the producer that populates `completion_summary` and optional `roadmap_items`; /todo is the
consumer") actually executes end-to-end for implementers beyond the core one, per the three
ordered questions in the task description. All reads were against the source store
(`agent-system/extensions/**`), never the deployed `.claude/` tree, per the source-store rule.

## Findings

### Question 1: Does core `skill-implementer/SKILL.md` actually populate `roadmap_items`?

**Confirmed reachable and correct**, with one important nuance: `skill-implementer/SKILL.md`
itself does not *generate* `roadmap_items` — it only *propagates* a field that the dispatched
subagent (`general-implementation-agent`) must have already written.

- `general-implementation-agent.md:439-463` instructs the agent: "Before writing metadata,
  prepare the `completion_data` object" — `completion_summary` required, `roadmap_items`
  optional ("Array of explicit ROADMAP.md item texts this task addresses"). Line 494 confirms
  this is written into `.return-meta.json`.
- `skill-implementer/SKILL.md:342-368` (Stage 6) reads it back out:
  `roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")`.
- `skill-implementer/SKILL.md:484-492` (Stage 7, Step 3) writes it to `state.json`, guarded by
  `[ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]` — i.e.
  skipped for meta tasks and skipped when the agent supplied nothing. This is reachable
  unconditionally whenever `status == "implemented"` reaches Stage 7 (Step 3 runs after the
  `postflight_rc` phase-check branch, not inside it).

Both links of the contract are intact for the plain core path. This is the one path in the whole
system verified fully correct without qualification.

### Question 2: Do per-extension implementers populate it, or silently skip it?

The task's preliminary grep (scoped to `skills/*/SKILL.md` files only) found the literal string
`roadmap_items` in core `skill-implementer`, `skill-lean-implementation`,
`skill-lean-implementation-hard`, and `skill-web-implementation`. A broader grep across
`agent-system/` (including `agents/*.md`, not just `skills/`) changes the picture substantially,
because most of the actual generation logic lives in the **agent** file, not the **skill** file.
Independently reproduced:

```
grep -rl "roadmap_items" agent-system/
→ core/agents/general-implementation-agent.md
→ core/commands/todo.md
→ core/context/formats/return-metadata-file.md, patterns/early-metadata-pattern.md,
  reference/state-management-schema.md
→ core/merge-sources/claudemd.md
→ core/scripts/orchestrator-postflight.sh, roadmap-integration.sh, roadmap-sync.sh
→ core/skills/skill-implementer/SKILL.md, core/skills/skill-todo/SKILL.md
→ epidemiology/agents/epi-implement-agent.md
→ lean/skills/skill-lean-implementation-hard/SKILL.md, skill-lean-implementation/SKILL.md
→ nix/agents/nix-implementation-agent.md
→ nvim/agents/neovim-implementation-agent.md
→ web/agents/web-implementation-agent.md, web/skills/skill-web-implementation/SKILL.md
```

Cross-referencing agent-side generation against skill-side propagation for every implementer
that mentions the field anywhere gives four distinct states:

| Extension | Agent generates `completion_data.roadmap_items`? | SKILL.md propagates it to `state.json`? | Net result |
|---|---|---|---|
| **core** (general) | Yes (`general-implementation-agent.md:439-463`) | Yes (`skill-implementer/SKILL.md:484-492`) | **Works** |
| **web** | Yes (`web-implementation-agent.md:336-401`) | Yes (`skill-web-implementation/SKILL.md:259-264`) | **Works** |
| **core --hard** | **No.** `general-implementation-hard-agent.md` Stage 7 (line 346-350) lists only `phases_completed`, `phases_total`, `modified_files`, `memory_candidates` — zero mentions of `completion_data`/`completion_summary`/`roadmap_items` anywhere in the file. | Vague/unverifiable: `skill-implementer-hard/SKILL.md:354-356` Stage 7a says "Same as `skill-implementer` Stage 7a" — but `skill-implementer` has no stage named "Stage 7a" (its equivalent is Stage 7 Steps 2-4). Moot since there is nothing to propagate. | **Broken (agent-side)** |
| **lean** (non-hard) | **No.** `lean-implementation-agent.md` has no "Context References" section and never references `return-metadata-file.md`. Its own documented metadata example (`Recording Verification Results`, lines 200-219) shows `status`, `verification`, `artifacts`, `metadata` — no `completion_data`. | Yes — correct propagation logic exists (`skill-lean-implementation/SKILL.md:199,208-211`), but has nothing to read since the agent never writes the field. | **Broken (agent-side)** |
| **lean --hard** | **No.** `lean-implementation-hard-agent.md` *does* reference `return-metadata-file.md` (line 27) but its own Stage 8 "Write Metadata File" (lines 384-390) explicitly enumerates `sorry_inventory`, `verification`, `memory_candidates` — `completion_data` is not mentioned. | **No — dead-code bug.** `skill-lean-implementation-hard/SKILL.md:289-296` extracts `roadmap_items` into a shell variable at line 290 but the write block immediately below (lines 292-296) only writes `completion_summary`; the `$roadmap_items` variable is never used again in the file. | **Broken (both sides independently)** |
| **nix** | Yes (`nix-implementation-agent.md:348-385`) | **No.** `skill-nix-implementation/SKILL.md` Stage 6 says only "Update state.json and TODO.md based on result" with no inline jq and no `completion_summary`/`roadmap_items` reference anywhere in the file; `update-task-status.sh` (the script it implicitly delegates to) also has zero references to either field. | **Broken (skill-side)** — *outside file_scope* |
| **neovim** | Yes (`neovim-implementation-agent.md:313-380`) | **No** — same thin-Stage-6 pattern as nix, verified no `completion_summary`/`roadmap_items` anywhere in `skill-neovim-implementation/SKILL.md`. | **Broken (skill-side)** — *outside file_scope* |
| **epidemiology** | Yes (`epi-implement-agent.md:438-441`, full example with `completion_summary` + `roadmap_items`) | **No.** `skill-epi-implement/SKILL.md` Stage 7 (lines 198-208) is a bare status-mapping table (`completed`→`completed`/`implementing`→`implementing`/`failed`→keep) with zero jq writes for either field. | **Broken (skill-side)** — *outside file_scope* |
| **core/skill-todo** (consumer) | N/A | Reads `roadmap_items` from `state.json` for matching against `ROADMAP.md` — established by the task framing as byte-identical between upstream and the confounded deployment, not re-verified in depth here since it's the consumer, not the producer. | **Presumed correct per task framing** |

**Answer to the task's core question**: this is *not* "a core-only-in-practice implementation
with 16 extension implementers silently omitting the step." It is worse and more specific than
that framing suggests: even the **lean** path — which the preliminary grep suggested had the
field wired up, and which is the exact path the confounded downstream repo routes through — is
broken on the agent-generation side in both its standard and hard-mode variants. Meanwhile core,
web, nix, neovim, and epidemiology are a mix of fully-working and skill-side-broken, with no
extension implementer checked showing the inverse failure mode (skill propagates correctly, but
agent under-generates only when it "should" for some conditional reason) — every break is a flat
omission of a piece of the contract, not a nuanced conditional gap.

### Does this explain the 21-task, 0% observation?

Yes, with high confidence, independent of the stale-deployment confound. The confound (deployed
`skill-implementer` 28 lines behind upstream) only affects the **core** path, which the
downstream repo does not primarily use (it is lean4-dominated). The **lean** path's
agent-side gap is present in the current, unmodified upstream source I read directly from
`agent-system/extensions/lean/agents/*.md` — this is not something a re-sync of the downstream
deployment could fix, because the defect already exists upstream. A re-sync would only fix the
unrelated, already-established `roadmap-integration.sh`/`todo.md` findings; it would not move the
`roadmap_items` rate off zero for lean-routed tasks.

### Root cause

The shared schema file `@.claude/context/formats/return-metadata-file.md` (lines 145-159) already
documents `completion_data` fully, including that `completion_summary` is mandatory for all
`implemented` returns and `roadmap_items` is optional for non-meta tasks — i.e., the "factor into
a shared contract" infrastructure the task asked about already exists. The defect is that three
agent files fail to actually apply it in their own concrete instructions:

1. `lean-implementation-agent.md` — never references the shared schema file at all (no Context
   References section).
2. `lean-implementation-hard-agent.md` — references the shared schema file, but its own Stage 8
   instructions give a competing, incomplete enumeration of fields that omits `completion_data`.
3. `general-implementation-hard-agent.md` — same pattern as (2): references the shared schema
   file generally (line 24) but Stage 7's concrete field list omits `completion_data`.

In all three cases, the concrete last-mile "what to write" instruction the agent actually follows
does not mention the field, even though an abstractly-referenced shared doc says it's mandatory.
This is consistent with how `general-implementation-agent.md` and `web-implementation-agent.md`
avoid the bug: both inline a concrete `completion_data` instruction and worked example directly
in their own Stage 7, rather than relying on the reader to cross-reference an external file for a
"mandatory" requirement.

## Decisions

- **No file edits made in this research pass.** Per the task's own framing, this confirms a real
  gap rather than manufacturing a fix for a non-existent one — but unlike the framing's fallback
  option, "no upstream defect, needs a re-sync" is explicitly **not** the right closure here.
- The task's declared `file_scope` (five `SKILL.md` files) does not include the files where the
  root-cause fix actually needs to land (`lean-implementation-agent.md`,
  `lean-implementation-hard-agent.md`, `general-implementation-hard-agent.md` — all `agents/*.md`,
  not `skills/*/SKILL.md`). This is flagged explicitly below rather than silently expanded.

## Recommendations

**Fixable within the declared `file_scope`** (mechanical, low-risk, no agent-file changes needed):

1. `skill-lean-implementation-hard/SKILL.md` (lines ~287-297): add the missing write using the
   already-extracted `$roadmap_items` variable, mirroring the pattern already present in
   `skill-lean-implementation/SKILL.md:208-211` (including the `task_type != meta` guard, kept
   for defensive consistency with the sibling file even though lean tasks are not expected to be
   meta-typed in practice).
2. `skill-implementer-hard/SKILL.md` (Stage 7a, lines 354-356): replace the imprecise
   cross-reference ("Same as `skill-implementer` Stage 7a...") with an accurate one (`skill-implementer`
   Stage 7 Steps 2-4) or inline the concrete jq steps directly, matching the explicit style used
   by the other four `SKILL.md` files in scope. This makes the propagation path auditable, though
   it remains a no-op until the agent-side fix below lands.

**Requires touching files outside the declared `file_scope`** — the fix that actually matters for
the observed 0% rate. Recommend a **follow-up task** (or an explicit `file_scope` expansion on
this one) covering:

3. `agent-system/extensions/lean/agents/lean-implementation-agent.md` — add a "Write Metadata
   File" stage instruction requiring `completion_data` per
   `@.claude/context/formats/return-metadata-file.md` (mandatory `completion_summary`; optional
   `roadmap_items`), and add the missing Context References entry for that shared file.
4. `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — add the same
   `completion_data` requirement to Stage 8's field list (currently: `sorry_inventory`,
   `verification`, `memory_candidates`).
5. `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — add the same
   `completion_data` requirement to Stage 7's field list (currently: `phases_completed`,
   `phases_total`, `modified_files`, `memory_candidates`).

**Preferred shape for 3-5**: a short, standardized instruction line pointing at the *existing*
shared schema doc (e.g. "Include `completion_data` per `return-metadata-file.md`
— `completion_summary` mandatory, `roadmap_items` optional for non-meta tasks"), not a duplicated
inline schema. The shared contract file already exists and is already correct; the fix is making
every agent's local "what to write" instructions actually honor it, the same way
`general-implementation-agent.md` and `web-implementation-agent.md` already do. Full duplication
of the schema into each of the ~14 implementer agent files (as the task's own framing warned
against) is not needed and would only increase drift risk.

**Separately flagged, not part of this task's scope**: a mirror-image bug affecting `nix`,
`neovim`, and `epidemiology` (agent generates `completion_data` correctly; `SKILL.md` never
propagates it to `state.json`). Recommend a distinct follow-up task, since these three files are
outside the declared `file_scope` and the fix shape (SKILL.md postflight jq, not agent
instructions) differs from 3-5 above.

**Coordination note honored**: none of the fixes above touch
`agent-system/extensions/core/merge-sources/claudemd.md`; no sequencing conflict with the
terminal-status-taxonomy work is created by this research.

## Risks & Mitigations

- **Risk**: expanding `file_scope` to agent files mid-task could conflict with the task's stated
  scope discipline. **Mitigation**: recommend a follow-up task rather than silently expanding
  scope; the two in-scope fixes (items 1-2 above) can land independently and are harmless no-ops
  until the agent-side fix follows.
- **Risk**: the `task_type != meta` guard added to item 1 could be seen as unnecessary since lean
  tasks are not meta-typed. **Mitigation**: kept for consistency with the sibling SKILL.md's
  established pattern; it is a no-op guard for lean's actual task_type population, not a
  functional risk.

## Appendix

### Search queries / commands used

- `find agent-system/extensions -maxdepth 1 -type d`
- `grep -n "roadmap_items" agent-system/extensions/core/skills/skill-implementer/SKILL.md`
- `grep -rln "roadmap_items"` / `grep -rln "completion_data"` across `agent-system/`
- Targeted `grep -n` for `roadmap_items|completion_data|completion_summary` against every
  `agents/*-implementation*-agent.md` and matching `skills/*/SKILL.md` file for core, lean, web,
  nix, neovim, epidemiology
- `Read` of the full Stage 6/7 (or equivalent) postflight sections in `skill-implementer/SKILL.md`,
  `skill-implementer-hard/SKILL.md`, `skill-lean-implementation/SKILL.md`,
  `skill-lean-implementation-hard/SKILL.md`, `skill-nix-implementation/SKILL.md`,
  `skill-neovim-implementation/SKILL.md`, `skill-epi-implement/SKILL.md`
- `Read` of the metadata-write sections/examples in `general-implementation-agent.md`,
  `general-implementation-hard-agent.md`, `lean-implementation-agent.md`,
  `lean-implementation-hard-agent.md`, `web-implementation-agent.md`,
  `nix-implementation-agent.md`, `neovim-implementation-agent.md`, `epi-implement-agent.md`
- `grep -n "completion_data" agent-system/extensions/core/context/formats/return-metadata-file.md`
  to confirm the shared schema doc's existing content
