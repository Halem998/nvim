# Implementation Plan: Task #768

- **Task**: 768 - Implement `--hard` routing resolution in `command-route-skill.sh`, wire it into commands, and document the composition model
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: Task 767 (core/manifest.json routing_hard — COMPLETED, commit bb42d80cc)
- **Research Inputs**: specs/768_routing_hard_resolution_composition/reports/01_hard-routing-research.md
- **Artifacts**: plans/01_hard-routing-resolution.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`command-route-skill.sh` currently accepts 3 arguments (operation, task_type, default_skill) and has no awareness of an `effort_flag` or of `routing_hard` manifest sections. CLAUDE.md already documents a 4-step `--hard` resolution that does not yet exist in the script — task 768 closes that gap. This plan adds a 4th `effort_flag` argument implementing the full 5-step resolution (non-core extension `routing_hard` exact then compound-key fallback, core `routing_hard` exact then compound-key fallback, then `-hard` append against a deployed `SKILL.md` with a graceful stderr fallback to the standard skill), wires the three command callers to pass the flag, and documents the composition precedence inline and in a context doc. The `-hard` append fallback must never resolve to an undeployed agent: it only activates when `.claude/skills/${skill}-hard/SKILL.md` exists on disk.

### Research Integration

The research report (`01_hard-routing-research.md`) provides the exact current 66-line script body, the precise 5-step resolution algorithm with ready-to-adapt Bash, the command wiring points (`/implement` STAGE 2 calls the script today; `/research` and `/plan` use inline manifest scans), the deployed hard skill/agent inventory, and the verification tuples. Key decisions adopted from research: (1) scan non-core manifests first then core to make "extension overrides core" deterministic regardless of glob order; (2) the script resolves skill names (not agent names) — agent resolution is downstream; (3) the `-hard` fallback gates on `SKILL.md` existence so undeployed agents are unreachable via the fallback path; (4) reconcile the first-match-wins (script) vs last-match-wins (skill-orchestrate-hard) inconsistency by documenting it rather than refactoring orchestrate-hard's separate inline reader.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add a 4th `effort_flag` argument to `command-route-skill.sh` implementing the 5-step hard resolution.
- Guarantee the `-hard` append fallback never resolves to an undeployed agent (gate on `SKILL.md` existence; otherwise stderr note + standard skill).
- Make "extension `routing_hard` overrides core `routing_hard`" deterministic (non-core scanned before core).
- Wire `/implement`, `/research`, and `/plan` to pass `effort_flag` so `--hard` resolves to the correct skill.
- Document the composition precedence via inline script comments and a context doc (NOT in CLAUDE.md — that sync is task 770's job).
- Provide shell-level tests asserting exit codes and `SKILL_NAME` for representative (operation, task_type, effort_flag) tuples.

**Non-Goals**:
- Editing CLAUDE.md or the "Routing Mechanism"/"Hard Mode" documentation sync (task 770).
- Refactoring `skill-orchestrate-hard` Stage 1b to consume `command-route-skill.sh` (it reads agent names inline; left in place — only documented).
- Adding `routing_hard` validation tooling that checks manifest entries against deployed `SKILL.md` files (task-770 concern per research §6).
- Adding new `routing_hard` entries to any manifest (task 767 already landed core entries).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Glob order of `.claude/extensions/*/manifest.json` nondeterministic across OS, breaking "extension overrides core" | M | M | Skip `core/manifest.json` in the non-core pass (`continue`), then check core in a dedicated pass — priority no longer depends on glob order |
| `-hard` append fallback resolves to a skill whose agent is not deployed | H | L | Fallback only activates when `.claude/skills/${candidate}-hard/SKILL.md` exists; all 6 deployed hard skills have matching deployed agents (research §6) |
| New `_route_`-style locals leak into the sourced shell | L | M | Add all new vars (`_effort_flag`, `_hard_skill`, `_ext_hard`, `_candidate_hard`, `_base_type_hard`, `_core_manifest`) to the closing `unset` |
| Centralizing `/research` and `/plan` through the script changes existing standard routing behavior | M | M | Phase 2b is isolated and verified against the same tuples in standard (non-hard) mode to confirm no regression; keep inline scan as the documented fallback shape if equivalence cannot be shown |
| Script is `source`d, so a non-zero internal exit could abort the caller | M | L | Resolution logic must not `exit`; only set `SKILL_NAME`; stderr note uses `echo ... >&2` without failing |
| Inconsistent first-match (script) vs last-match (orchestrate-hard) precedence confuses future authors | L | M | Document the canonical first-match/non-core-first precedence in the context doc and inline comments; note orchestrate-hard's separate path explicitly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement the 5-step hard resolution in `command-route-skill.sh` [COMPLETED]

**Goal**: Extend the script to accept a 4th `effort_flag` argument and resolve the hard skill via the documented 5-step precedence, inserted AFTER the standard routing resolves `SKILL_NAME`.

**Tasks**:
- [ ] Read `.claude/scripts/command-route-skill.sh` to confirm current structure (3 args, Steps 1-3, closing `unset`/`export`).
- [ ] Add `_effort_flag="${4:-}"` immediately after `_route_default_skill="$3"`.
- [ ] After the existing Step 3 line (`SKILL_NAME="${SKILL_NAME:-$_route_default_skill}"`), insert a `Step 4: hard-mode resolution` block guarded by `if [ "$_effort_flag" = "hard" ]; then`.
- [ ] Step 4a — non-core extension `routing_hard[$op][$task_type]` exact match, first hit wins (skip `core/manifest.json` via `continue`, `break` on hit).
- [ ] Step 4b — non-core compound-key fallback: if no hit and task_type contains `:`, retry with `base_type = cut -d: -f1` over non-core manifests.
- [ ] Step 4c — core `routing_hard[$op][$task_type]` exact match (dedicated pass on `.claude/extensions/core/manifest.json`).
- [ ] Step 4d — core compound-key fallback (base_type against core manifest).
- [ ] Step 4e — `-hard` append: `_candidate_hard="${SKILL_NAME}-hard"`; use it only if `[ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]`, else `echo "[route] No hard variant for ${_candidate_hard}; using standard skill" >&2` and leave `SKILL_NAME` unchanged.
- [ ] Apply resolved hard skill: `[ -n "$_hard_skill" ] && SKILL_NAME="$_hard_skill"`.
- [ ] Add `_effort_flag _hard_skill _ext_hard _candidate_hard _base_type_hard _core_manifest` to the closing `unset` line; preserve `export SKILL_NAME`.
- [ ] Use the established `jq -r --arg op ... --arg tt ... '.routing_hard[$op][$tt] // empty'` pattern (no shell interpolation in jq paths); ensure no `exit` calls so sourcing callers are not aborted.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/command-route-skill.sh` — add 4th arg and the Step 4 hard-resolution block (~50 lines), extend `unset`.

**Verification**:
- `bash -n .claude/scripts/command-route-skill.sh` passes (syntax).
- Sourcing with no 4th arg reproduces current standard behavior unchanged (e.g., `source ... "implement" "meta" "skill-implementer"` → `SKILL_NAME=skill-implementer`).
- After sourcing in a subshell, none of the `_route_*`/`_hard_*` temporaries remain set (echo each → empty).
- Manual spot-check: `source ... "implement" "meta" "skill-implementer" "hard"` → `skill-implementer-hard`.

---

### Phase 2: Wire `effort_flag` into command callers [COMPLETED]

**Goal**: Pass `effort_flag` through `command-route-skill.sh` from all three commands so `--hard` resolves to hard skills, centralizing `/research` and `/plan` routing through the script.

This phase has two self-contained sub-parts. Phase 2a (the `/implement` one-line change) is the minimal core fix and must land. Phase 2b (centralizing `/research` and `/plan`) is the intended architecture per research §Decisions 5; if equivalence to the existing inline scan cannot be demonstrated in standard mode, fall back to inlining only the `routing_hard` lookup alongside the existing inline scan and record that decision in the summary.

**Tasks**:
- [ ] Phase 2a — `/implement` STAGE 2: change `source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"` to append `"${EFFORT_FLAG:-}"` as the 4th arg. Confirm the variable name actually used for the parsed effort flag in `commands/implement.md` STAGE 1.5 and match it exactly.
- [ ] Phase 2b — `/research` STAGE 2: replace the inline `.routing.research[$tt]` manifest scan with `source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-researcher" "${effort_flag:-}"` then `skill_name="$SKILL_NAME"`. Confirm the actual variable names (`task_type`, `effort_flag`) in `commands/research.md`.
- [ ] Phase 2b — `/plan` STAGE 2: replace the inline `.routing.plan[$tt]` manifest scan with `source .claude/scripts/command-route-skill.sh "plan" "$task_type" "skill-planner" "${effort_flag:-}"` then `skill_name="$SKILL_NAME"`. Confirm variable names in `commands/plan.md`.
- [ ] Verify each command still passes `effort_flag` to the Skill tool as a downstream prompt hint (unchanged) in addition to the new routing use.
- [ ] Leave `skill-orchestrate-hard` Stage 1b untouched (it reads agent names via its own inline scan and does not call the script).

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/implement.md` — STAGE 2, add 4th arg (1 line).
- `.claude/commands/research.md` — STAGE 2, centralize routing through the script.
- `.claude/commands/plan.md` — STAGE 2, centralize routing through the script.

**Verification**:
- `grep` confirms each command's STAGE 2 now passes a 4th positional arg / calls `command-route-skill.sh` with the effort flag.
- Standard-mode equivalence: for `/research` and `/plan`, the script-resolved `SKILL_NAME` matches the prior inline-scan result for representative task types (general, meta, plus one extension type such as nix/cslib).
- No edits appear in `skill-orchestrate-hard/SKILL.md`.

---

### Phase 3: Document the composition precedence (inline + context doc) [COMPLETED]

**Goal**: Record the canonical `routing_hard` composition precedence in inline script comments and a context doc, without touching CLAUDE.md (task 770 owns that sync).

**Tasks**:
- [ ] Add a header comment block in `command-route-skill.sh` above the Step 4 block stating the precedence order: (1) non-core extension `routing_hard[$op][$type]`, (2) non-core compound-key base-type fallback, (3) core `routing_hard[$op][$type]`, (4) core compound-key fallback, (5) `-hard` append iff `SKILL.md` exists, else standard skill + stderr note.
- [ ] Create `.claude/context/guides/hard-mode-routing.md` (or `.claude/extensions/core/context/routing.md` if that path is the established convention — confirm during implementation) documenting: the 5-step resolution, the "extension overrides core" rule, the first-match/non-core-first precedence, the `SKILL.md`-existence safety gate, and a note that `skill-orchestrate-hard` Stage 1b uses a SEPARATE inline reader (agent names, last-match-wins) that is intentionally not routed through this script.
- [ ] Explicitly note the in-scope/out-of-scope boundary: this doc covers the script/context layer only; the CLAUDE.md "Routing Mechanism" text sync is task 770 and must NOT be edited here.
- [ ] Add the new context doc to `.claude/context/index.json` if that is required for discovery (confirm the index schema and whether guides are indexed).

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/command-route-skill.sh` — inline precedence comment block.
- `.claude/context/guides/hard-mode-routing.md` (or core extension context path) — new composition-model doc.
- `.claude/context/index.json` — optional index entry for the new doc (only if guides are indexed).

**Verification**:
- The inline comment enumerates all 5 steps in precedence order.
- The context doc exists, states "extension routing_hard overrides core", and references the `SKILL.md` safety gate and the orchestrate-hard exception.
- `grep -L "CLAUDE.md"` confirms no CLAUDE.md edits were made (CLAUDE.md untouched in the diff).

---

### Phase 4: Shell-level resolver tests [COMPLETED]

**Goal**: Add an executable test script asserting exit codes and `SKILL_NAME` values for the representative (operation, task_type, effort_flag) tuples, including the extension-override and graceful-fallback cases.

**Tasks**:
- [ ] Create `.claude/tests/test-command-route-skill.sh` (confirm the established test directory/location during implementation; place alongside existing script tests if one exists).
- [ ] Test tuple: `(implement, meta, hard)` → `SKILL_NAME == skill-implementer-hard` (core routing_hard or `-hard` append).
- [ ] Test tuple: `(research, lean4, hard)` → resolves to the extension hard override skill (e.g., `skill-lean-research-hard`) IF the lean/cslib extension declares it; otherwise assert against the actually-deployed extension hard skill for an available extension task type (confirm which extension `routing_hard` entries exist on disk before asserting, since only deployed entries can pass). Verify the extension override wins over core.
- [ ] Test tuple: `(plan, general, hard)` → `SKILL_NAME == skill-planner-hard`.
- [ ] Test tuple: `(implement, <type-with-no-hard-variant>, hard)` → `SKILL_NAME` falls back to the standard skill AND the `[route] No hard variant for ...; using standard skill` note is emitted to stderr.
- [ ] Test standard-mode regression: `(implement, meta, "")` (no/empty 4th arg) → `SKILL_NAME == skill-implementer` (unchanged behavior).
- [ ] For each case assert both the resolver's exit/return status (sourcing succeeds, no abort) and the `SKILL_NAME` value; capture stderr separately to assert the fallback note.
- [ ] Make the test runnable: `bash .claude/tests/test-command-route-skill.sh` prints pass/fail per case and exits non-zero on any failure.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/tests/test-command-route-skill.sh` — new resolver test harness (confirm directory convention).

**Verification**:
- `bash .claude/tests/test-command-route-skill.sh` exits 0 with all listed tuples passing.
- The no-hard-variant case demonstrably emits the stderr note and resolves to the standard skill (not an undeployed `-hard` skill).
- The extension-override case asserts the extension hard skill takes precedence over core for the same (op, type).

---

## Testing & Validation

- [ ] `bash -n .claude/scripts/command-route-skill.sh` — syntax check passes.
- [ ] `bash .claude/tests/test-command-route-skill.sh` — all resolver tuples pass, exit 0.
- [ ] Standard-mode (no/empty effort_flag) resolution is byte-identical to pre-change behavior for general/meta/markdown and at least one extension type.
- [ ] `--hard` resolution for `(implement, meta)`, `(plan, general)` yields the `-hard` skills; extension-override case yields the extension hard skill.
- [ ] Unknown-hard-variant case emits the documented stderr note and falls back to the standard skill (never an undeployed agent).
- [ ] No temporary `_route_*`/`_hard_*` variables leak after sourcing.
- [ ] CLAUDE.md is unchanged in the diff (task 770 owns that sync).
- [ ] `skill-orchestrate-hard/SKILL.md` is unchanged.

## Artifacts & Outputs

- `.claude/scripts/command-route-skill.sh` (modified) — 4th arg + 5-step hard resolution + inline precedence comment.
- `.claude/commands/implement.md`, `.claude/commands/research.md`, `.claude/commands/plan.md` (modified) — effort_flag wiring.
- `.claude/context/guides/hard-mode-routing.md` (new, path TBD-confirmed) — composition-model doc.
- `.claude/context/index.json` (modified, conditional) — index entry for the new doc.
- `.claude/tests/test-command-route-skill.sh` (new, path TBD-confirmed) — resolver test harness.
- `specs/768_routing_hard_resolution_composition/.orchestrator-handoff.json` — orchestrator handoff (written by this planning step).
- `specs/768_routing_hard_resolution_composition/summaries/01_hard-routing-resolution-summary.md` — implementation summary (produced by /implement).

## Rollback/Contingency

- All changes are additive and localized; `git checkout -- .claude/scripts/command-route-skill.sh .claude/commands/implement.md .claude/commands/research.md .claude/commands/plan.md` reverts the wiring and resolver.
- The new context doc and test harness are new files; `git clean`/`rm` removes them with no dependents.
- If Phase 2b centralization regresses `/research` or `/plan` standard routing, revert those two files to inline scans and apply only the `routing_hard` lookup inline (Phase 2b fallback), keeping Phase 2a (`/implement`) and Phase 1.
- Because the script is `source`d, the resolver never calls `exit`; a faulty resolution at worst leaves `SKILL_NAME` at the standard skill, which is the safe default.
