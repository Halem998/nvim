# Research Report: Task #125

**Task**: 125 - Delete the three base lifecycle skills (skill-researcher, skill-planner, skill-implementer)
**Started**: 2026-09-02T02:47:55Z
**Completed**: 2026-09-02T03:05:00Z
**Effort**: N/A (research only; status is `blocked`)
**Dependencies**: None declared
**Sources/Inputs**: Live repository tree (`agent-system/extensions/**`, `.claude/**` deployed mirror), `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Precondition (command deletion + dispatch-bypass) verified true.** `commands/research.md`,
  `commands/plan.md`, `commands/implement.md` are gone from
  `agent-system/extensions/core/commands/` and de-registered from `manifest.json`.
  `skill-orchestrate/SKILL.md` dispatches phases directly via `command-route-agent.sh` to
  `general-research-agent`/`planner-agent`/`general-implementation-agent` (and the hard variants
  via `skill-orchestrate-hard`), never touching `skill-researcher`/`skill-planner`/
  `skill-implementer` by name. The "dispatch-prep rehome" half is also verified: `skill-orchestrate`
  now inlines its own copy of the memory-retrieval / `--lit` dispatch-prep logic (explicitly noted
  in `skill-orchestrate/SKILL.md` as reproducing "`skill-researcher`/`skill-planner`/
  `skill-implementer`'s own Stage 4a verbatim").
- **Genuine blocker found — same class as the sibling `-hard` deletion task.**
  `agent-system/extensions/core/scripts/validate-wiring.sh` (registered as a deployed script in
  `manifest.json:226`) hard-requires all three directories to exist via a `[[ -d ... ]]` existence
  check in `validate_core_system()`. Running the deployed copy against the live tree today
  (`.claude/scripts/validate-wiring.sh`) confirms it currently PASSES (`Skill exists:
  skill-researcher` / `skill-implementer` / `skill-planner`) and would flip to `Skill missing: ...`
  FAIL immediately on deletion, with no companion fix in this batch.
- **Reference footprint is far larger than the task's own scope list.** A live repo-wide grep
  (excluding this task's own `specs/125_.../` artifacts and archived `specs/vault/**` history)
  finds **72 files** under `agent-system/` referencing `skill-researcher` outside its own
  directory, **72** for `skill-planner`, **74** for `skill-implementer` — not just the "3 SKILL.md
  files + 3 mapping-table rows" the delegation scoped. These include a second stale table in
  `merge-sources/claudemd.md` (the Task-Type-Based Routing table, lines 75-77) beyond the
  Skill-to-Agent Mapping table (lines 146-148) named in the brief, ~15 extension manifests whose
  `routing.{research,plan,implement}` blocks still name these three skills as literal values, one
  live command (`epi.md`) that still sources `command-route-skill.sh` with `skill-researcher` as a
  literal default argument, and dozens of docs/guides/context files.
- **Recommendation**: do not delete yet. `validate-wiring.sh` needs a companion fix (drop the
  three names from its `for skill in ...` loop, or replace with an intentional decision about what
  "core skills" now means) landed in the same change, and the reference-cleanup scope should be
  re-estimated against the full ~72-74-file footprint per skill, not the 4-item list in the
  delegation. The manifest `routing` (non-`_agents`, non-`_hard`) blocks are very likely dead code
  today (see Findings) but that is a design call for the plan, not something research should
  silently narrow or resolve.

## Context & Scope

Verify two preconditions for deleting `skills/skill-researcher/`, `skills/skill-planner/`,
`skills/skill-implementer/` (SKILL.md + directory, each in full) from the core extension source
store, plus the Skill-to-Agent Mapping table rows in `merge-sources/claudemd.md`:

1. The command-deletion half (`/research`, `/plan`, `/implement` command files removed) — asserted
   already landed earlier in this orchestration batch.
2. The dispatch-prep rehome half — asserted but not yet independently verified.

And, per the brief's explicit CRITICAL instruction, check for the same blocker class that stopped
a sibling `-hard` skill deletion task: lint/test scripts hard-requiring the files, live manifest
routing resolution, or other live dispatch/reference.

## Findings

### Precondition 1 — command deletion (verified true)

```
$ ls agent-system/extensions/core/commands/research.md agent-system/extensions/core/commands/plan.md agent-system/extensions/core/commands/implement.md
ls: cannot access '...research.md': No such file or directory
ls: cannot access '...plan.md': No such file or directory
ls: cannot access '...implement.md': No such file or directory
```

`grep -n 'research\.md\|plan\.md\|implement\.md' agent-system/extensions/core/manifest.json`
returns zero hits — the commands are fully de-registered, not just file-deleted.

### Precondition 2 — dispatch-prep rehome (verified true)

`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:159-167` sources
`command-route-agent.sh` directly for all three phases:

```
source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-agent" "$effort_flag"
source .claude/scripts/command-route-agent.sh "plan" "$TASK_TYPE" "planner-agent" "$effort_flag"
source .claude/scripts/command-route-agent.sh "implement" "$TASK_TYPE" "general-implementation-agent" "$effort_flag"
```

No live invocation of `command-route-skill.sh` (the skill-name router, as opposed to the
agent-name router) exists in either `skill-orchestrate/SKILL.md` or `skill-orchestrate-hard/SKILL.md`.
The dispatch-prep block at `skill-orchestrate/SKILL.md:818-838` (description/effort-flag alias,
empty-description warning, memory retrieval) is inlined there directly, with an explicit comment
noting it "reproduces `skill-researcher`/`skill-planner`/`skill-implementer`'s own Stage 4a
verbatim" — i.e., the rehome copied the logic rather than continuing to depend on those skill
files at runtime. That comment itself is a textual reference that would need updating/removing to
satisfy a zero-grep-hits bar, but it is not a functional dependency.

### Blocker — `validate-wiring.sh` hard-requires all three directories to exist

`agent-system/extensions/core/scripts/validate-wiring.sh:176`, inside `validate_core_system()`:

```bash
    # Check core skills exist
    log_info "Checking core skills..."
    for skill in skill-researcher skill-implementer skill-planner skill-meta; do
        if [[ -d "$system_dir/skills/$skill" ]]; then
            log_pass "Skill exists: $skill"
        else
            log_fail "Skill missing: $skill"
        fi
    done
```

This script is registered as a deployed script in `agent-system/extensions/core/manifest.json:226`
(`provides.scripts`). Running the currently-deployed copy against the live tree confirms it is
live and passing today:

```
$ bash .claude/scripts/validate-wiring.sh 2>&1 | grep -i "skill-researcher\|skill-planner\|skill-implementer\|Skill exists\|Skill missing"
[PASS] Skill exists: skill-researcher
[PASS] Skill exists: skill-implementer
[PASS] Skill exists: skill-planner
[PASS] Skill exists: skill-meta
```

Deleting the three directories without a companion edit to this loop would immediately flip these
four assertions to `[FAIL] Skill missing: ...`. This is the same defect shape (Check A/C/E-style
hard-require) that blocked the sibling `-hard` deletion task. `validate-wiring.sh` is not wired
into `deploy-headless.sh` as an automatic gate (`grep -n validate-wiring
agent-system/extensions/core/scripts/deploy-headless.sh` is empty), so it would not silently break
an automated pipeline run — but it is a shipped, documented wiring-validation script that would
report false failures the next time anyone runs it, which is exactly the kind of regression a
deletion task must not leave behind.

By contrast, checked and ruled out as NOT hard blockers:
- `lint-contract-compliance.sh` and `lint-agent-contracts.sh`: only reference the `-hard` variants
  (`skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`), never the base three.
- `lint-routing-wiring.sh` (Check A/B/C): validates that `routing.{op}` keys have
  `routing_agents.{op}` counterparts, and that `routing_agents`/`routing_agents_hard` *values* name
  an existing agent file — it never validates that `routing`/`routing_hard` *values* (skill names
  like `"skill-planner"`) name an existing skill file. Ran it live: `323 passed, 0 failed` today,
  and it would still pass 0-failed after deletion, because it doesn't check skill-file existence at
  all.
- `test-routing-resolution.sh`: exercises `command-route-agent.sh` / `skill-orchestrate`'s
  agent-name resolution only; it has zero references to the base three skill names.
- `test-postflight-marker-schema.sh` uses `"skill-researcher"` / `"skill-planner"` only as opaque
  fixture string values for a JSON-schema round-trip test — no existence check, not a blocker
  (though it would still be a grep hit).
- `validate-plan-write.sh`'s hook error message names all three skills as delegation guidance text
  — stale-content risk (would tell an agent to delegate to a deleted skill), not an existence-check
  failure.

### Manifest routing blocks: still contain the names, but appear to be dead code

A plain (non-`_hard`, non-`_agents`) `"routing"` key naming `skill-researcher`/`skill-planner`/
`skill-implementer` as literal values still exists in ~15 extension manifests for their own
domain task types, e.g.:

- `agent-system/extensions/nvim/manifest.json`: `routing.plan.neovim = "skill-planner"`
- `agent-system/extensions/email/manifest.json`: `routing.research.email = "skill-researcher"`,
  `routing.plan.email = "skill-planner"`
- `agent-system/extensions/formal/manifest.json`: `routing.plan.formal* = "skill-planner"`,
  `routing.implement.formal* = "skill-implementer"`
- Also: `cslib`, `latex`, `filetypes`, `epidemiology`, `typst`, `memory`, `python`, `lean`, `nix`,
  `present`, `z3`, `web`.

The `agent-system/extensions/core/manifest.json` itself has **no** plain `"routing"` key at all
today (only `routing_hard`, `routing_agents`, `routing_agents_hard`) — it appears to have already
been dropped in a prior task. `command-route-skill.sh` (the only consumer of the plain `"routing"`
key) is sourced live in exactly one place outside docs/templates in the whole repo:
`agent-system/extensions/epidemiology/commands/epi.md:369`, which is a still-registered, still-live
command (`provides.commands: ["epi.md"]`):

```
source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-researcher" "${effort_flag:-}"
```

However, `epi.md` validates `task_type` starts with `"epi"` before this call (line 358), and the
epidemiology manifest's own `routing.research` block maps `epi`/`epi:study`/`epidemiology`
unconditionally to `skill-epi-research` — so under the five-step routing ladder (non-core exact
match wins before the default argument is ever used), this literal `"skill-researcher"` default
would never actually be selected in a normal `/epi` invocation. It is textually present and
functionally inert. No `/plan`- or `/implement`-shaped live command anywhere in the repo sources
`command-route-skill.sh` with `"plan"`/`"implement"` operations, so the ~15 extensions'
`routing.plan.*`/`routing.implement.*` → `skill-planner`/`skill-implementer` entries have no live
caller left at all (their only historical caller, the core `/plan`/`/implement` commands, is
deleted; `skill-orchestrate` never used the skill-name router). This makes those manifest blocks
appear to be dead weight, but resolving *what to do about them* (strip the whole `routing` key,
retarget each entry to a domain-specific skill, etc.) is a plan-level decision, not something this
report resolves.

### Full reference footprint (live, excluding `specs/**`)

Repo-wide grep, `agent-system/` only (word-boundary matched, `-hard` variants excluded, each
skill's own directory excluded):

| Skill | Files referencing it elsewhere in `agent-system/` |
|---|---|
| `skill-researcher` | 72 |
| `skill-planner` | 72 |
| `skill-implementer` | 74 |

Representative categories found in the file list (not exhaustive — see the live grep for the full
72-74-file lists per name):
- Domain research/plan/implement skills across other extensions (`skill-python-research`,
  `skill-web-research`, `skill-latex-research`, `skill-epi-research`, `skill-z3-research`,
  `skill-neovim-research`, `skill-nix-research`, `skill-typst-research`, `founder/skills/*`) —
  mostly prose references to the same "Stage 4a verbatim" pattern noted above.
- `merge-sources/claudemd.md` — **two** tables, not one: the Task-Type-Based Routing table
  (lines 75-77, `general`/`meta`/`markdown` rows naming `skill-researcher`/`skill-implementer`
  as the routing skill) in addition to the Skill-to-Agent Mapping table (lines 146-148) the
  delegation explicitly named.
- `context/reference/skill-agent-mapping.md`, `context/routing.md`, `context/guides/
  manifest-routing-schema.md`, `context/guides/hard-mode-routing.md`, `context/patterns/
  lit-stage4a-flow.md`, `context/patterns/skill-lifecycle.md`, and roughly a dozen more
  context/docs files.
- `docs/examples/research-flow-example.md`, `docs/templates/command-template.md`, `docs/guides/
  creating-commands.md`, `docs/guides/creating-skills.md`, `docs/guides/creating-agents.md`,
  `docs/guides/adding-domains.md`, `docs/guides/component-selection.md`, `docs/fork-patterns.md`,
  `docs/architecture/handoff-schema.md`, `docs/architecture/system-overview.md`.
- `literature` extension: `merge-sources/claudemd.md`, `scripts/literature-briefing.sh`,
  `scripts/test-lit-pipeline.sh`, `context/guides/literature-organization.md`,
  `context/project/literature/patterns/adhoc-navigation-directive.md`.
- Live scripts with prose (not existence-check) references: `skill-base.sh`,
  `orchestrator-postflight.sh`, `orchestrate-stage5-postflight.sh`.

`specs/vault/**` (archived, completed-task history) also contains hundreds of hits, but these are
frozen historical artifacts exempted by `no-task-references-in-deliverables.md`'s `specs/**`
carve-out and by convention are not edited retroactively; they are excluded from the actionable
count above.

### Territory check

No overlap with task 90's declared territory (`scripts/lint/`, `skill-base.sh` adoption-lint
work) was found in the files this report's checks touched — `validate-wiring.sh` is a distinct
script from `scripts/lint/*`, and no edits were made (research only).

## Decisions

- None — this task did not proceed to any edit. Reporting `blocked` per the brief's explicit
  instruction not to proceed past a genuine precondition failure.

## Risks & Mitigations

- **Risk**: deleting the three skill directories now, without a companion fix to
  `validate-wiring.sh`, ships a script that will falsely report `Skill missing: skill-researcher`
  / `skill-implementer` / `skill-planner` the next time anyone runs it.
  **Mitigation**: a future dispatch for this task (or a follow-up) must update
  `validate_core_system()`'s `for skill in ...` loop before or in the same change as the directory
  deletions — either drop the three names outright, or make an explicit decision about what "core
  skills" validate-wiring should assert going forward.
- **Risk**: treating the delegation's 4-item work list ("3 SKILL.md files + 3 mapping-table rows")
  as the full scope will leave the task's own stated completion bar ("repo-wide grep ... zero
  hits") unmet, since 72-74 files per skill name reference them outside their own directories.
  **Mitigation**: re-plan with the fuller reference inventory above as the actual scope, or
  explicitly narrow the "zero hits" bar in a revised task description if a smaller, staged
  cleanup is preferred.

## Context Extension Recommendations

- None — this is a task-specific blocker, not a documented-pattern gap.

## Appendix

### Commands/searches used

```
ls agent-system/extensions/core/commands/{research,plan,implement}.md
grep -n 'research\.md\|plan\.md\|implement\.md' agent-system/extensions/core/manifest.json
grep -rn 'skill-researcher\|skill-planner\|skill-implementer' agent-system/extensions/core/skills/skill-orchestrate*/SKILL.md
grep -n 'skill-researcher\|skill-planner\|skill-implementer' agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh
bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh   # 323 passed, 0 failed
bash .claude/scripts/validate-wiring.sh                                 # confirms live pass today
grep -rln 'source .*command-route-skill.sh' agent-system/
grep -rlE 'skill-researcher\b|skill-planner\b|skill-implementer\b' agent-system/  # 72/72/74-file inventory
wc -l agent-system/extensions/core/skills/skill-{researcher,planner,implementer}/SKILL.md  # 424 / 508 / 726
```

### Verified live line counts (re-measured, matches delegation estimate)

```
  424 skills/skill-researcher/SKILL.md
  508 skills/skill-planner/SKILL.md
  726 skills/skill-implementer/SKILL.md
```
