# Implementation Plan: Delete Base Lifecycle Skills

- **Task**: 125 - Delete the three base lifecycle skills (skill-researcher, skill-planner, skill-implementer)
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: None outstanding (both preconditions verified landed -- see Overview)
- **Research Inputs**: specs/125_delete_base_lifecycle_skills/reports/01_delete-base-lifecycle-skills.md
- **Artifacts**: plans/01_delete-base-lifecycle-skills.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Delete `skills/skill-researcher/`, `skills/skill-planner/`, and `skills/skill-implementer/` from
the core extension source store, land the two wiring fixes that must accompany the deletion, and
sweep the full textual reference footprint so a repo-wide grep for each name returns zero hits.
Both preconditions the delegation named are verified landed: `/research`, `/plan`, `/implement`
command files are gone and de-registered from `manifest.json`, and `skill-orchestrate` dispatches
agents directly via `command-route-agent.sh` rather than through these skills. This is therefore
pure deletion plus cleanup, not rewiring of any live dispatch path.

### Research Integration

Research (`reports/01_delete-base-lifecycle-skills.md`) established four things this plan is built
on:

1. **Precondition verified.** Command deletion and dispatch-prep rehome are both complete;
   `skill-orchestrate/SKILL.md` inlines the Stage 4a logic and never names these three skills.
2. **Hard blocker found.** `agent-system/extensions/core/scripts/validate-wiring.sh`'s
   `validate_core_system()` hard-requires all three directories via a `[[ -d ... ]]` loop. It
   passes today and flips to `[FAIL] Skill missing: ...` the moment the directories go. It must be
   fixed in the same change (Phase 1).
3. **Second blocker, not in the research report's headline.** `agent-system/extensions/core/manifest.json`
   lists all three in `provides.skills` (lines 66-84). A deploy that copies a listed-but-absent
   skill directory is a second same-change fix (Phase 1). Confirmed live during planning.
4. **Reference footprint is 129 files / ~352 hit lines**, far beyond the delegation's 4-item work
   list. The task's own completion bar ("repo-wide grep returns zero hits") therefore requires a
   staged sweep, which this plan supplies as Phases 4-9.

Research explicitly deferred one design call to the plan: what to do with the ~15 extension
manifests whose `routing.{plan,implement,research}` blocks still name these skills as literal
values. **Decision (Phase 2): prune only the dangling key-value pairs whose value is one of the
three deleted skills**, removing an enclosing `routing.{op}` object only when it becomes empty.
This is the minimal correct fix -- a routing entry naming a nonexistent skill is a dangling
pointer -- and it is lint-safe: `lint-routing-wiring.sh` Check A validates
`routing.{op} -> routing_agents.{op}`, so removing `routing` keys can never create a Check A
failure, and Check B only inspects `routing_agents*` values. Entries pointing at surviving
domain skills (e.g. `epidemiology`'s `routing.research.epi = "skill-epi-research"`) are untouched.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied and no roadmap flag set; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Remove the three skill directories in full from the core source store.
- Land both accompanying wiring fixes (`validate-wiring.sh` core-skills loop, core
  `manifest.json` `provides.skills`) so nothing reports a false failure post-deletion.
- Prune dangling manifest routing entries and the one live literal-default router argument
  (`epidemiology/commands/epi.md`).
- Update both stale tables in `merge-sources/claudemd.md` (Skill-to-Agent Mapping *and*
  Task-Type-Based Routing -- the delegation named only the first).
- Sweep all remaining textual references across `agent-system/**` so a repo-wide grep for each
  name returns zero hits outside this task's own `specs/` artifacts and `specs/vault/**`.

**Non-Goals**:
- Deleting or altering the `-hard` variants (`skill-researcher-hard`, `skill-planner-hard`,
  `skill-implementer-hard`) -- they stay, and references that mention "the base three and their
  `-hard` variants" are rewritten to name only the survivors.
- Rewriting `specs/vault/**` archived history (frozen; exempted by the `specs/**` carve-out).
- Retargeting pruned routing entries to new domain skills, or redesigning what `routing` means.
- Any change to `command-route-skill.sh`'s routing ladder beyond its header comment.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deletion lands before the wiring fixes, leaving `validate-wiring.sh` failing | H | M | Phase 1 is a hard predecessor of Phase 3; Phase 3's verification re-runs the script |
| Deploy breaks because `provides.skills` still names absent directories | H | M | Phase 1 removes the three entries; Phase 3 verification runs a deploy check |
| Pruning a `routing` entry that has a live consumer | H | L | Only entries valued at the three deleted skills are pruned; `lint-routing-wiring.sh` run before and after each manifest phase |
| Blind sed-style substitution mangles prose that legitimately describes the `-hard` variants or historical behavior | M | H | Each sweep phase edits by reading the hit line and rewriting it, never by bulk regex replace; `-hard` names are word-boundary-excluded from every grep |
| The 129-file / 352-line footprint is an undercount (new references land concurrently) | M | M | Phase 10 re-derives the inventory from scratch rather than trusting the plan's numbers |
| An edit introduces a task-number reference outside `specs/**` | M | L | `no-task-references-in-deliverables.md` applies to every phase; Phase 10 runs `check-task-references.sh` |
| Edits land in `.claude/**` (deploy artifact) instead of `agent-system/extensions/**` | H | M | Every phase's file list is source-store-rooted; `source-store-deploy-boundary.md` applies throughout |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5, 6, 7, 8, 9 | 3 |
| 4 | 10 | 4, 5, 6, 7, 8, 9 |

Phases within the same wave can execute in parallel. Wave 3's six phases own disjoint file
territories (listed per phase) and are parallel-safe.

---

### Phase 1: Make the Wiring Tolerate the Absence [COMPLETED]

**Goal**: Remove both hard requirements that the three skill directories exist, so Phase 3's
deletion leaves nothing reporting a false failure.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/validate-wiring.sh`, `validate_core_system()`:
      change the core-skills loop from `for skill in skill-researcher skill-implementer
      skill-planner skill-meta; do` to `for skill in skill-meta; do`, and update the surrounding
      `log_info "Checking core skills..."` context if the singular reads oddly. *(completed)*
- [x] In `agent-system/extensions/core/manifest.json`, remove the three `provides.skills` array
      entries `"skill-implementer"`, `"skill-planner"`, `"skill-researcher"` (the `-hard` variants
      stay). *(completed)*
- [x] Confirm `jq . agent-system/extensions/core/manifest.json` still parses. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-wiring.sh` - drop the three names from the
  core-skills existence loop
- `agent-system/extensions/core/manifest.json` - drop the three `provides.skills` entries

**Verification**:
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` exits 0 and no longer prints
  `Skill exists: skill-researcher` / `skill-implementer` / `skill-planner`.
- `jq -e '.provides.skills | index("skill-researcher") == null and index("skill-planner") == null
  and index("skill-implementer") == null' agent-system/extensions/core/manifest.json` is true.

---

### Phase 2: Prune Dangling Manifest Routing and the Live Router Default [COMPLETED]

**Goal**: Remove every manifest `routing.{op}.{type}` entry whose value is one of the three
deleted skills, and replace the one live literal-default router argument.

**Tasks**:
- [x] For each extension manifest, delete only the key-value pairs whose value is
      `"skill-researcher"`, `"skill-planner"`, or `"skill-implementer"`. Delete the enclosing
      `routing.{op}` object only if it becomes empty; leave `routing_agents*` and `routing_hard`
      untouched. *(completed: 15 manifests, including email whose routing.research.email pointed
      at skill-researcher)*
- [x] In `agent-system/extensions/epidemiology/commands/epi.md`, change the Step 2 router call's
      literal default argument from `"skill-researcher"` to `"skill-epi-research"` (the value the
      epidemiology manifest's own `routing.research.epi` already resolves to), and update the
      surrounding prose that names `implement.md` as the shape being mirrored, since that command
      no longer exists. *(completed)*
- [x] Re-run `jq .` over every touched manifest to confirm valid JSON. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: 15 extension manifests are expected to carry such entries (`cslib`, `email`,
`epidemiology`, `filetypes`, `formal`, `latex`, `lean`, `memory`, `nix`, `nvim`, `present`,
`python`, `typst`, `web`, `z3`), totalling ~40 key-value pairs. Confirm at implementation time
with `grep -rn --include=manifest.json -E '"skill-(researcher|planner|implementer)"'
agent-system/extensions/` before editing and again after; the post-edit run must return zero.

**Files to modify**:
- `agent-system/extensions/{cslib,email,epidemiology,filetypes,formal,latex,lean,memory,nix,nvim,present,python,typst,web,z3}/manifest.json`
- `agent-system/extensions/epidemiology/commands/epi.md`

**Verification**:
- `grep -rn --include=manifest.json -E '"skill-(researcher|planner|implementer)"' agent-system/extensions/`
  returns zero (excluding `-hard` names, which are distinct tokens).
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` reports 0 failed
  (baseline before this phase: 323 passed, 0 failed -- record the post-edit pass count in the
  progress file rather than asserting it must be unchanged).
- Every touched manifest parses under `jq .`.

---

### Phase 3: Delete the Three Skill Directories [COMPLETED]

**Goal**: Remove the three skill directories in full from the source store.

**Tasks**:
- [x] `git rm -r agent-system/extensions/core/skills/skill-researcher/` *(completed)*
- [x] `git rm -r agent-system/extensions/core/skills/skill-planner/` *(completed)*
- [x] `git rm -r agent-system/extensions/core/skills/skill-implementer/` *(completed)*
- [x] Confirm no other file remains inside those directories (untracked strays). *(completed: each
      directory held exactly one SKILL.md at 424/508/726 lines, matching the scope hypothesis; no
      strays)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: exactly three directories, each containing a single `SKILL.md` of 424 / 508 /
726 lines respectively (re-measured by research). Confirm with
`wc -l agent-system/extensions/core/skills/skill-{researcher,planner,implementer}/SKILL.md` and
`find` over the three directories immediately before deletion; a stray additional file means the
scope estimate was wrong and must be reported, not silently deleted.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-researcher/` - deleted
- `agent-system/extensions/core/skills/skill-planner/` - deleted
- `agent-system/extensions/core/skills/skill-implementer/` - deleted

**Verification**:
- The three directories do not exist.
- `bash agent-system/extensions/core/scripts/validate-wiring.sh` exits 0 with no
  `Skill missing:` lines.
- `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` reports 0 failed.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and
  `lint-contract-compliance.sh` exit as they did before the phase.

---

### Phase 4: Update the CLAUDE.md Merge Sources [COMPLETED]

**Goal**: Remove the three skills from both stale tables in the core merge source, plus the
literature extension's merge source.

**Tasks**:
- [x] In `agent-system/extensions/core/merge-sources/claudemd.md`, remove the three rows from the
      Skill-to-Agent Mapping table (`skill-researcher | general-research-agent`,
      `skill-planner | planner-agent`, `skill-implementer | general-implementation-agent`).
      *(completed)*
- [x] In the same file, fix the Task-Type-Based Routing table's `general` / `meta` / `markdown`
      rows, whose "Research Skill" and "Implementation Skill" columns name the deleted skills.
      These task types now route via `skill-orchestrate`'s direct agent dispatch; state that
      rather than naming a skill that no longer exists. *(completed: replaced with a
      Research/Plan/Implementation Agent table plus an explanatory sentence)*
- [x] Sweep the remaining hits in that file (research counted 9 total; actual count was 6: the
      3 Skill-to-Agent rows plus the 3 routing-table rows above -- no separate `--lit` Stage 4a
      pointer exists in the core merge source). *(completed)*
- [x] Do the same for `agent-system/extensions/literature/merge-sources/claudemd.md`.
      *(deviation: altered — the file's Stage 4a pointer sentence named
      "`skill-researcher`, `skill-planner`, `skill-implementer`, and their `-hard` variants" as
      importers of `lit-stage4a-flow.md`. Repo-wide grep confirms zero references anywhere to
      `skill-researcher-hard`/`skill-planner-hard`/`skill-implementer-hard` -- no such `-hard`
      variants exist in the source tree (apparently removed by a separate, unrelated prior task),
      so "name only the surviving `-hard` variants" was not an available option. Rewrote the
      sentence to name the actual current importers instead: `skill-orchestrate` and every domain
      research/implementation skill, verified via `grep -rl lit-stage4a-flow`)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 9 hit lines in the core merge source and 1 in the literature merge source.
Confirm with `grep -cE '\bskill-(researcher|planner|implementer)\b'` on each file before editing;
the post-edit count must be zero for both.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - both tables plus remaining prose hits
- `agent-system/extensions/literature/merge-sources/claudemd.md` - Stage 4a skill enumeration

**Verification**:
- `grep -nE '\bskill-(researcher|planner|implementer)\b'` returns zero on both files (word-boundary
  match leaves `-hard` names intact).
- Both markdown tables still have matching column counts on every row.

---

### Phase 5: Sweep core/context/patterns, architecture, checkpoints [COMPLETED]

**Goal**: Clear references in the highest-density core context files.

**Tasks**:
- [x] Rewrite each hit line by reading its surrounding claim first. Three rewrite shapes recur:
      (a) an enumeration of "the base three and their `-hard` variants" becomes an enumeration of
      the `-hard` variants alone; (b) a claim about `/research`, `/plan`, `/implement` dispatch
      becomes a claim about `skill-orchestrate`'s direct agent dispatch; (c) a worked example
      using a deleted skill name is retargeted to a surviving skill. *(deviation: altered — shape
      (a) does not apply anywhere in this territory; repo-wide grep confirms zero
      `skill-researcher-hard`/`skill-planner-hard`/`skill-implementer-hard` references exist
      anywhere in the source tree, so no rewrite ever enumerated "the base three and their
      `-hard` variants" — every hit used shape (b) or (c) instead, or named a functional owner
      that had genuinely moved (e.g. Stage 5a/5c ownership, the split-commit shape) which required
      a fourth shape: retarget the claim to its new true owner, `skill-orchestrate`)*
- [x] `context/patterns/`: `skill-lifecycle.md` (17 hits), `task-lock.md`, `multi-task-operations.md`,
      `lit-stage4a-flow.md`, `checkpoint-execution.md`, `context-protective-lead.md`,
      `file-footprint-overlap.md`, `skill-postflight-flow.md`, `skill-preflight-flow.md`,
      `subagent-continuation-loop.md`, `thin-wrapper-skill.md`. *(completed)*
- [x] `context/architecture/`: `system-overview.md` (14 hits), `component-checklist.md`,
      `context-layers.md`. *(completed)*
- [x] `context/checkpoints/README.md` *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 15 files in this territory. Confirm with
`grep -rlE '\bskill-(researcher|planner|implementer)\b' agent-system/extensions/core/context/{patterns,architecture,checkpoints}`
before and after; post-edit must be empty.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/*.md` (11 files listed above)
- `agent-system/extensions/core/context/architecture/*.md` (3 files listed above)
- `agent-system/extensions/core/context/checkpoints/README.md`

**Verification**:
- Zero hits in the three directories under the word-boundary grep.
- No cross-reference in an edited file now points at a section that the edit removed.

---

### Phase 6: Sweep the remainder of core/context [COMPLETED]

**Goal**: Clear references in the remaining core context subtrees.

**Tasks**:
- [x] `context/contracts/`: `phase-closure.md`, `pre-edit-gate.md` (`anti-analysis.md`,
      `recovery.md`, `wrap-up.md` had zero hits -- already clean). *(completed)*
- [x] `context/guides/`: `extension-development.md`, `manifest-routing-schema.md`
      (`hard-mode-routing.md` had zero hits -- already clean) -- note these describe the routing
      ladder, so an edit here must stay truthful about `command-route-skill.sh` still existing and
      still serving domain skills. *(completed)*
- [x] `context/formats/`: `errors-format.md` (`plan-format.md` had zero hits -- already clean).
      *(completed)*
- [x] `context/meta/`: `domain-patterns.md`, `meta-guide.md`. *(completed)*
- [x] `context/standards/`: `git-staging-scope.md`, `orchestrator-runtime-files.md`,
      `postflight-tool-restrictions.md`. *(completed)*
- [x] `context/templates/`: `command-template.md`, `subagent-template.md`,
      `thin-wrapper-skill.md`. *(completed)*
- [x] `context/reference/skill-agent-mapping.md`, `context/routing.md`,
      `context/schemas/errors-schema.json` (JSON -- confirm it still parses after the edit).
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 21 files in this territory. Confirm with a word-boundary
`grep -rlE` over `agent-system/extensions/core/context/` minus the Phase 5 subdirectories, before
and after; post-edit must be empty.

**Files to modify**:
- `agent-system/extensions/core/context/{contracts,guides,formats,meta,standards,templates,reference,schemas}/*` and `context/routing.md` (21 files listed above)

**Verification**:
- Zero hits across `agent-system/extensions/core/context/` (combined with Phase 5's territory).
- `jq . agent-system/extensions/core/context/schemas/errors-schema.json` parses.

---

### Phase 7: Sweep core/docs, README, and commands/orchestrate.md [COMPLETED]

**Goal**: Clear references in core documentation and the one remaining core command file.

**Tasks**:
- [x] `docs/guides/`: `adding-domains.md`, `component-selection.md`, `creating-agents.md`,
      `creating-skills.md`. *(completed)*
- [x] `docs/architecture/`: `system-overview.md` (`handoff-schema.md` had zero hits -- already
      clean). *(completed)*
- [x] `docs/examples/research-flow-example.md` (10 hits) -- this walks through a `/research`
      invocation that no longer exists; rewrite it against `/orchestrate --research` or retire the
      example, whichever leaves a truthful document. *(completed: rewrote against
      `/orchestrate --research` + `skill-orchestrate`'s direct-dispatch mechanism, grounding
      every stage name and delegation-context field against skill-orchestrate/SKILL.md's actual
      single-task Stage 1/1b/2/3/3.5/5/7/8 implementation rather than inventing detail)*
- [x] `docs/fork-patterns.md`. *(completed)*
- [x] `agent-system/extensions/core/README.md`. *(completed)*
- [x] `agent-system/extensions/core/commands/orchestrate.md`. *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 9 files in this territory. Confirm with a word-boundary `grep -rlE` over
`agent-system/extensions/core/{docs,README.md,commands}` before and after; post-edit must be empty.

**Files to modify**:
- `agent-system/extensions/core/docs/**` (8 files listed above)
- `agent-system/extensions/core/README.md`
- `agent-system/extensions/core/commands/orchestrate.md`

**Verification**:
- Zero hits across the three paths.
- Any internal link an edit touched still resolves to an existing file.

---

### Phase 8: Sweep core scripts, hooks, agents, and surviving skills [COMPLETED]

**Goal**: Clear references in executable and contract-bearing core files.

**Tasks**:
- [x] `hooks/validate-plan-write.sh` -- its error message tells an agent to delegate to a now-deleted
      skill; retarget to `planner-agent` / `skill-orchestrate`. *(completed)*
- [x] `scripts/`: `command-route-skill.sh` (header comment example), `skill-base.sh`,
      `orchestrator-postflight.sh`, `orchestrate-stage5-postflight.sh`,
      `lint/lint-task-lookup-adoption.sh` (`lint/lint-contract-compliance.sh` had zero hits --
      already clean). *(completed)*
- [x] `scripts/tests/`: `test-postflight-marker-schema.sh` (fixture string values;
      `test-resume-scan-nonconformance.sh` and `test-routing-resolution.sh` had zero hits --
      already clean). Fixture strings are opaque to the assertions, so substituting a surviving
      skill name must not change any expected result -- ran the touched test to confirm: 10
      passed, 0 failed. *(completed)*
- [x] `agents/`: `general-research-agent.md`, `general-implementation-agent.md`
      (`general-research-hard-agent.md`, `general-implementation-hard-agent.md`,
      `planner-hard-agent.md` do not exist -- confirmed via repo-wide grep that no
      `skill-researcher-hard`/`skill-planner-hard`/`skill-implementer-hard` or their agent
      counterparts exist anywhere in the source tree; removed by an earlier, unrelated task).
      *(completed)*
- [x] `skills/`: `skill-orchestrate/SKILL.md` (including the "reproduces skill-researcher/
      skill-planner/skill-implementer's own Stage 4a verbatim" comment),
      `skill-status-sync/SKILL.md`, `skill-git-workflow/SKILL.md`
      (`skill-orchestrate-hard/SKILL.md`, `skill-researcher-hard/SKILL.md`,
      `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md` do not exist -- same
      finding as above). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 21 files in this territory (1 hook, 6 scripts, 3 test scripts, 5 agents,
7 skills). Confirm with a word-boundary `grep -rlE` over
`agent-system/extensions/core/{hooks,scripts,agents,skills}` before and after; post-edit must be
empty.

**Files to modify**:
- `agent-system/extensions/core/{hooks,scripts,agents,skills}/**` (21 files listed above)

**Verification**:
- Zero hits across the four paths.
- `bash -n` passes on every touched shell script.
- Each touched script under `scripts/tests/` runs to the same pass/fail result as before the edit.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and
  `lint-contract-compliance.sh` exit as they did before the phase.

---

### Phase 9: Sweep non-core extensions [COMPLETED]

**Goal**: Clear the remaining references across every non-core extension.

**Tasks**:
- [x] Extension skills that describe the "Stage 4a verbatim" pattern: `python`, `web`, `latex`,
      `epidemiology`, `z3`, `nvim`, `nix`, `typst`, `email` (17 files sharing the exact "exactly
      as `skill-X` does" sentence, batch-verified identical before a targeted `sed` substitution
      to `skill-orchestrate`, plus epidemiology's 2 additional "same as skill-X" marker-operation
      sentences) -- `lean` and `present` had zero hits in this exact pattern (their hits were
      elsewhere, handled below); the six `founder/skills/skill-*` files had a different
      "(use skill-researcher)" pointer pattern, retargeted to `/orchestrate --research`.
      *(completed)*
- [x] Extension READMEs and EXTENSION.md files: `cslib`, `formal`, `epidemiology`, `email`,
      `present`. *(completed)*
- [x] `literature/`: `scripts/literature-briefing.sh`, `scripts/test-lit-pipeline.sh`,
      `context/guides/literature-organization.md`,
      `context/project/literature/patterns/adhoc-navigation-directive.md`. Section D of
      `test-lit-pipeline.sh` iterated a `skills=("skill-researcher" "skill-implementer")` array
      that would now fail (files not found) -- reduced to `skills=("skill-orchestrate")` and
      re-ran the test: 8 passed, 0 failed. *(completed)*
- [x] `present/commands/`: `funds.md`, `grant.md`, `timeline.md`;
      `present/context/project/present/domain/grant-workflow.md`. *(completed)*
- [x] `lean/context/project/lean4/domain/hard-mode.md`,
      `nvim/context/project/neovim/guides/tts-stt-integration.md`. *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: ~43 non-core files remain after Phase 2 removed the 15 manifests and
`epi.md` from this set. Confirm with
`grep -rlE '\bskill-(researcher|planner|implementer)\b' agent-system/extensions/ | grep -v '/core/'`
before and after; post-edit must be empty.

**Files to modify**:
- `agent-system/extensions/{cslib,email,epidemiology,filetypes,formal,founder,latex,lean,literature,memory,nix,nvim,present,python,typst,web,z3}/**` (non-manifest files, ~43 total)

**Verification**:
- Zero hits under `agent-system/extensions/` excluding `core/`.
- `bash -n` passes on the two touched literature shell scripts, and
  `literature/scripts/test-lit-pipeline.sh` runs to the same result as before the edit.

---

### Phase 10: Final Verification and Deploy Check [NOT STARTED]

**Goal**: Prove the zero-hit bar repo-wide, prove nothing regressed, and regenerate the deploy.

**Tasks**:
- [ ] Re-derive the reference inventory from scratch (do not trust this plan's counts):
      `grep -rnE '\bskill-(researcher|planner|implementer)\b' agent-system/ docs/ lua/ *.md`
      excluding `specs/`.
- [ ] Confirm zero hits outside `specs/125_delete_base_lifecycle_skills/` and `specs/vault/**`.
      Any residual hit is either fixed here or recorded as a Reasoned Exclusion with evidence.
- [ ] Run the full gate set: `validate-wiring.sh`, `lint-routing-wiring.sh`,
      `lint-agent-contracts.sh`, `lint-contract-compliance.sh`, and every script under
      `scripts/tests/` touched in Phase 8.
- [ ] Run `check-task-references.sh` to confirm no task-number reference was introduced outside
      `specs/**`.
- [ ] Regenerate the deploy (`deploy-headless.sh`) and confirm `.claude/skills/` no longer
      contains the three directories and that the deploy reports no missing-source warnings.

**Timing**: 0.75 hours

**Depends on**: 4, 5, 6, 7, 8, 9

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the pre-work inventory was 129 files / ~352 hit lines across
`agent-system/`. The re-derived post-work count must be 0. A nonzero residual means a phase's
territory list was incomplete -- enumerate the residual files explicitly rather than reporting the
sweep as done.

**Files to modify**:
- None expected; any residual-hit fix is recorded in the implementation summary.

**Verification**:
- Word-boundary repo-wide grep returns zero hits outside this task's `specs/` artifacts and
  `specs/vault/**`.
- All five lint/validate scripts exit 0.
- `.claude/skills/skill-{researcher,planner,implementer}/` absent after redeploy.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/validate-wiring.sh` exits 0 with no
      `Skill missing:` lines.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` reports 0 failed.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` exits 0.
- [ ] Every touched script under `scripts/tests/` and `literature/scripts/` runs to its
      pre-change result.
- [ ] `jq .` parses every touched `manifest.json` and `errors-schema.json`.
- [ ] `bash -n` passes on every touched shell script.
- [ ] `check-task-references.sh` reports no violation.
- [ ] Word-boundary repo-wide grep for each of the three names returns zero hits outside
      `specs/125_delete_base_lifecycle_skills/` and `specs/vault/**`.
- [ ] Redeploy leaves `.claude/skills/` without the three directories and emits no
      missing-source warning.

## Artifacts & Outputs

- `specs/125_delete_base_lifecycle_skills/plans/01_delete-base-lifecycle-skills.md` (this file)
- `specs/125_delete_base_lifecycle_skills/summaries/01_delete-base-lifecycle-skills-summary.md`
- Three deleted directories under `agent-system/extensions/core/skills/`
- ~127 edited files across `agent-system/extensions/**` (source store only; never `.claude/**`)

## Rollback/Contingency

Every phase commits separately, so rollback is `git revert` of the offending phase commit. Phase 3
(the deletion) is the only irreversible-feeling step, and it is a tracked `git rm` -- the
directories are recoverable from history at any time.

If Phase 10 finds a residual reference class that a wave-3 phase's territory list missed, fix it
in place and note it in the summary rather than reverting; the sweep phases are additive and do
not depend on each other.

If any lint or test regresses after Phase 3, the correct response is to fix forward (the wiring
fix in Phase 1 was incomplete) rather than restoring the skill directories -- restoring them would
re-introduce the dead files the task exists to remove.
