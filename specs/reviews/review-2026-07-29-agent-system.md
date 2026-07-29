# Agent System Review — 2026-07-29

Systematic review of the agent system deployed via `<leader>al` (source store
`agent-system/extensions/**`, deploy artifact `.claude/**`). Six parallel read-only reviews
covered: deploy pipeline/loader, shell-script layer, skills/commands/agents, extension
manifests, task-state machinery, and the context/docs/rules layer. This document synthesizes
the findings and proposes meta tasks for user review. Nothing has been changed or created.

---

## 1. The headline diagnosis: why the task treadmill exists

Quantified first:

- **820 archived tasks; 81 of the 82 currently-tracked tasks are `meta` type.** The system now
  spends nearly all task throughput maintaining itself.
- All 19 open tasks are repairs to the orchestration machinery (deploy propagation, completion
  gates, lock/commit interactions, schema drift).
- 172 of 820 archived task names contain repair verbs (fix/repair/reconcile/converge/prevent).

The six reviews independently converged on the same five root causes. The open tasks are
symptoms of these; fixing symptoms one at a time is what generates the treadmill.

### Root cause 1 — Duplicated mechanism instead of shared mechanism

The single dominant defect class, found in every subsystem:

| Instance | Evidence |
|---|---|
| **Two deploy engines** writing the same `.claude/` tree | Engine A: `lua/.../shared/extensions/loader.lua` (manifest-driven, 11 near-identical `copy_*` fns). Engine B: `lua/.../picker/operations/sync.lua` (glob+allow-list, core-only, drops all `scripts/lib|lint|tests` entries). They disagree on enumeration, filtering, root-files, and merge re-application. |
| **Five routing implementations** | `command-route-skill.sh` (used by exactly 1 of 48 commands), inline copies in `research.md`/`plan.md` (missing the hard ladder — `/research --hard` never consults `routing_hard`), and two hardcoded tables in orchestrate/orchestrate-hard with **opposite precedence** (first-match vs last-match). |
| **Four handoff schemas** | `handoff-schema.md`, `wrap-up.md`, `validate-handoff.sh:106`, and the union of reader jq paths all disagree; the nominal writer `skill_write_orchestrator_handoff` (`skill-base.sh:585`) has **zero callers** — its own header says so. |
| **Script exists, prose reimplements it** | `archive-task.sh`, `orphan-detection.sh`, `vault-operation.sh` all have zero callers while `skill-todo`/`commands/todo.md` reimplement them in prose (three divergent vault implementations, the script one unsafe and incomplete). `skill-base.sh` has 18 lifecycle functions; 41 skills hand-copy the `.postflight-pending` heredoc instead, in **four already-incompatible shapes**. |
| **Domain skills 62–90% pairwise identical** | `latex↔typst` research skills differ in 29/62 lines, 11 of which are an Error Handling section z3 simply lost. 13 lines are byte-identical across all 10 research skills. |
| **Status vocabulary re-typed ~20 places** | Two conflicting "authoritative" definitions (`status-markers.md` has `revising/revised`, no `pr_ready`; `state-management-schema.md` the reverse). `generate-todo.sh`'s catch-all `*)` arm renders any off-schema status as a plausible marker instead of failing. |
| **~110 unprotected state.json writers** in non-core extensions | founder (~44), present (~22), web, lean, cslib (two via machine-global `/tmp/state.tmp`), epidemiology — all bypass `state-write.sh`'s mutex, most via fixed shared temp paths. |

### Root cause 2 — Verification that silently passes

The system has many validators; the ones guarding the failure-prone seams are broken or blind:

- `validate-context-index.sh:96-115`: the `while read` loop runs in a subshell, so the warning
  counter is discarded — it prints `Warnings: 0 / Validation PASSED` while 58 real
  line-count-mismatch warnings scroll past. (104 of 164 index `line_count` values are wrong.)
- `verify.lua:359` (post-load verify) covers agents/skills/rules/context but has **zero
  references to `scripts`, `hooks`, `root_files`** — exactly the categories with the documented
  propagation defects.
- `check-extension-docs.sh` has content-drift rules only for scripts (F) and rules (I). Two
  stale deployed `SKILL.md` files (2293→2212 and 1422→1365 lines) and one missing test script
  are live and invisible to it right now.
- `literature`'s `keyword_overrides` has the wrong JSON shape; the consuming jq crashes with
  exit 5, swallowed by `2>/dev/null` — **the feature has never worked**, was diagnosed as P0 in
  archived report `specs/archive/814_.../01_improvement-roadmap.md:65`, and never fixed.
- `verify-deploy.sh` has no baseline/delta notion (open task 966's finding, confirmed).

### Root cause 3 — The error-tracking / self-healing layer is fiction

- `specs/errors.json` **does not exist**, despite being the documented backbone
  (CLAUDE.md Quick Reference, `rules/error-handling.md`, `commands/errors.md`, skill error
  paths). Three mutually inconsistent schemas are documented for it; readers guard with
  `[ -f ]` and silently degrade. There is no schema file and no append script (contrast
  `events.jsonl`, which has both).
- `context/repo/self-healing-implementation-details.md` is a 440-line spec for
  `ensure_state_json()` — a function that was **never implemented** and whose design
  (reconstruct state.json by parsing TODO.md) inverts the canonical data-flow direction; its
  companion `state-template.json` is a stale v1.0.0 schema no current reader understands.

### Root cause 4 — Dead machinery accumulates and is still documented as live

- 16 core scripts referenced only by the manifest (including the entire vault feature — which is
  also the worst remaining state.json corruption hazard).
- `manager.regenerate` and `settings_backup.backup` (Lua): zero callers. The picker UI path that
  every remediation doc tells the user to run ("Load Core / Sync all") **no longer exists** —
  the `is_load_all` entry has consumers but no producer.
- `dispatch-agent.sh` described as *current* architecture in `docs/architecture/system-overview.md:7`
  and `architecture-spec.md` (599 lines) — the script doesn't exist; `docs/fork-patterns.md:55`
  admits it's old. `dispatch-agent-spec.md` is cited 4× and doesn't exist.
- 8+ other doc-referenced scripts don't exist; two rules files are deployed but wired to nothing;
  two EXTENSION.md files are unreachable by the merge machinery.
- A 3MB PowerPoint template is 76% of the `present` extension, referenced by nothing, re-copied
  on every load.

### Root cause 5 — Always-on context bloat and index rot

- `.claude/CLAUDE.md` contains its **entire body twice** (891 duplicated lines ≈ 13k tokens in
  every session prompt): `generate_claudemd()` (`merge.lua:549-660`) writes without section
  markers; `reinject_loaded_extensions()` (`sync.lua:220-258`) then looks for markers, doesn't
  find them, and appends a full second copy. ~10-line fix.
- 3,243 lines of authored core context (incl. the largest file, `patterns/task-lock.md`, 1,103
  lines) are deployed but **absent from the index** — unreachable by any agent.
- Per-agent context budgets: 11 violations, 0 passes — meta-builder-agent loads 115k tokens
  against a 15k cap, because `task_types: ["meta"]` is a 77-entry catch-all.
- `load_when.languages` is queried by nothing, yet is the only task-type hook for 11 of 19
  extensions — and consequently `--lit`/`--clean`/memory injection silently do nothing for all
  non-core domains (nvim, nix, python, typst, z3, latex, web, email, epi): `memory-retrieve.sh`
  call sites exist only in core and cslib skills.

### One measured concurrency bug worth calling out on its own

`state-write.sh --regen-todo` runs `generate-todo.sh` **inside** the state mutex; measured wall
time 5.5s. The waiter acquire budget is 5.0s (`task-lock.sh:543`) and the stale-reclaim window
is 10s. So parallel multi-task dispatch already aborts deterministically on preflight, and as
state.json grows the holder will cross 10s and a waiter will **reclaim the mutex from a live
holder** — a genuine lost-update. `orchestrator-postflight.sh` already knows to extend its
window (`POSTFLIGHT_SCOPE_STALE_SEC=30`); `state-write.sh` doesn't.

---

## 2. Assessment against the stated goals

- **Uniform**: No. Two skeletons for skills (one prescribed by `skill-lifecycle.md`, used by
  zero skills), 4 postflight-marker shapes, 3 tool-restriction frontmatter spellings, 2 agent
  templates, 5 routers, 2 deploy engines.
- **Efficient**: The always-on prompt carries ~1,700 removable lines (891 CLAUDE.md duplication
  + 162 literature section for an unloaded extension + Tier-1 overload + rule narrative);
  agents load 2–8× their context budgets.
- **Robust**: The safety-critical cores (`state-write.sh`, `task-lock.sh`, `events-append.sh`,
  `deploy-root-guard.sh`, the exemption-taxonomy library) are genuinely well-engineered. The
  fragility lives in the seams: duplicated mechanisms drifting, validators that lie, and prose
  reimplementations of scripts.
- **Self-healing**: Currently fiction (errors.json absent, ensure_state_json never built,
  orphan-detection dead). The ingredients exist — events.jsonl has the schema+append+flock
  pattern to copy.
- **Fast**: 5.5s TODO regen inside a mutex on every status flip; ~10 jq subprocesses per task
  per regen, each re-parsing a 550KB file; 13k wasted tokens per prompt.

What is worth preserving explicitly (per the no-feature-drop requirement): the wrapper-only
email safety architecture, the exemption-taxonomy shared-library pattern, `lit-stage4a-flow.md`
(the one shared-import success — the model to replicate), the checkpoint/gate lifecycle itself,
the mutex/lock primitives, hard mode's behavioral contracts, and the literature extension's
directive-token discipline.

---

## 3. Proposed meta tasks (for user review — none created)

Grouped into waves. Wave 1 items are small, independent, and high-leverage; Wave 2 items are
the structural consolidations that retire whole defect classes (and subsume several open
tasks); Wave 3 is cleanup that becomes cheap after Wave 2.

### Wave 1 — Small fixes with outsized payoff (each ≤ a day)

**T1. Fix generated CLAUDE.md double-body.** Pick one ownership regime: either
`generate_claudemd()` emits `<!-- SECTION: id -->` markers, or `reinject_loaded_extensions()`
stops calling `inject_section` for the claudemd key. Also dedupe the doubled
`claude-stop-notify.sh` Stop-hook registration. *~13k tokens off every prompt; ~10-line Lua fix.*

**T2. Fix the state-mutex timing.** Move `generate-todo.sh` out of the critical section (write
state under mutex, regen after release with a generation counter), or at minimum pass an
explicit `stale_sec` ≥ 30 from `state-write.sh` and raise the acquire budget. Add the
regression guard: assert TODO-regen wall time < 40% of the staleness window.
*Unblocks parallel multi-task dispatch; prevents future lost-updates.*

**T3. Manifest quick-fix batch.** (a) Reshape `literature/manifest.json` `keyword_overrides` to
the documented `{task_type: {keywords: [...]}}` form; (b) `epidemiology/settings-fragment.json`
`mcp_servers` → `mcpServers`; (c) drop the unjustified `literature → filetypes` dependency;
(d) delete the unreferenced 3MB `UCSF_ZSFG_Template_16x9.pptx`; (e) resolve or delete the 4
orphaned manifest `mcp_servers` blocks and the 20 empty `mcp_servers:{}`/`hooks:{}` stubs.

**T4. Fix the validators that lie.** (a) `validate-context-index.sh` subshell bug (process
substitution) so warnings actually count; (b) add an index-orphan gate (deployed context file ∌
index entry); (c) make line_count machine-computed, not hand-typed — a tiny generator that
rewrites `line_count` in `index-entries.json` from `wc -l`, run at deploy time.

**T5. Bootstrap the error lane for real.** Create `specs/errors.json`, pick ONE schema, add
`context/schemas/errors-schema.json` + `scripts/errors-append.sh` mirroring the proven
events.jsonl pattern (draft-07 schema, validated append, flock), and rewrite the three
conflicting doc blocks to point at the schema. *This is the prerequisite for open tasks
951–954; consider merging 954+955 into this.*

### Wave 2 — Structural consolidations (retire the defect classes)

**T6. One deploy engine.** Keep engine A (manifest-driven loader): add `force`-resync to
`manager.load` (delete the "already loaded" hard-abort), rewire `deploy-headless.sh` to
`manager.regenerate` (or unload-all/load-all), fix `regenerate`'s settings-restore-after-merge
ordering bug, give `.syncprotect` backup/restore (not just skip-on-overwrite) semantics, wire a
`[Regenerate]` picker entry, and retire engine B (`sync.load_all_globally`) + the dead
`is_load_all` branch. Collapse the 11 `copy_*` functions into one table-driven copier (fixes
the symlink-guard and perms inconsistencies by construction). Extend `verify.lua` to
declared-vs-deployed + content-hash parity for **every** `provides.*` category.
*Subsumes open tasks 970 and 958, and removes the standing-failure surface that motivated 966.
Also corrects the mis-diagnosis recorded in `no-task-references-in-deliverables.md:145-149`
(engine B never calls copy_scripts for anyone — it isn't an already-loaded skip) and the stale
`lua/neotex/shared/extensions/init.lua` path.*

**T7. One router.** Make `research.md` and `plan.md` call `command-route-skill.sh` (as
`implement.md` already does); replace the orchestrate/orchestrate-hard hardcoded tables and the
`sed 's/^skill-//'` agent-name derivation with manifest-declared agent routing; retire
`skill-orchestrator` (byte-identical to its own `.archived` twin, one consumer); key the core
manifest on `.name == "core"` instead of the non-unique `routing_exempt`.
*Fixes: `/research --hard` and `/plan --hard` silently ignoring `routing_hard`; `/orchestrate`
on email/memory/filetypes tasks dispatching to nonexistent agents; `epi` silently routing to
general agents.*

**T8. One handoff contract.** Single schema file; make `validate-handoff.sh` enforce it
(currently enforces a fourth variant); either wire `skill_write_orchestrator_handoff` as the
one writer or delete it and make `.return-meta.json` the single return channel with the
recovery bridge removed. Reconcile the two engines' incompatible `.blockers` reads.
*Subsumes open tasks 947 and 949 (core half), and simplifies 968's fix.*

**T9. Extract the shared skill skeleton.** Replicate the `lit-stage4a-flow.md` pattern
(shared block + @-import, drift-history documented in its header) for: Stage 2/3 preflight +
postflight-marker, Stage 7a propagation, Stage 8 artifact linking, Stage 8a TTS, Stage 9
cleanup — and make skills call the existing `skill-base.sh` functions instead of 41 inline
copies. Restore the missing `## MUST NOT (Postflight Boundary)` section to the three `-hard`
skills and add a section-presence check to `lint-postflight-boundary.sh`. Route the three team
skills through `update-task-status.sh` (they currently hand-roll and leave Task Order stale).
Then collapse the 12 domain `skill-*-{research,implementation}` files onto the shared skeleton
(~470 duplicated lines; nix/nvim and latex/typst pairs first) — which also gives every domain
the Stage 4a block, making `--lit`/`--clean`/memory injection work outside core for free.

**T10. One state schema + one status vocabulary.** Draft-07 JSON schema for `state.json` +
`validate-state.sh` (catches the live stray-`updated` fields and missing titles today); make
the status enum THE single source both prose docs cite; delete the permissive `*)` arm in
`generate-todo.sh`; fix `command-structure.md`'s fabricated vocabulary/paths (8 sites, not 2).
Extend `state-write.sh` to archive/vault targets (open task 969) and then convert the ~110
non-core extension ad-hoc writers to it, with a repo lint (`grep mv .* state.json` outside
state-write.sh) so the class can't reoccur. *Subsumes 950, extends 969.*

### Wave 3 — Cleanup (cheap after Wave 2)

**T11. Dead-code quarantine sweep.** Mirror literature's `scripts/deprecated/` +
README-with-rationale pattern for core: the 16 orphan scripts (triage: `install-*`/`migrate-*`
are legit one-shot tools, need only a doc note; vault/orphan/roadmap-sync/rename-session are
dead), the two dead rules (`pr-prohibition.md` is enforced by nothing — decide: wire it into
the @-import list or drop it), `manager.regenerate`/`settings_backup` (wired by T6 instead),
the two dead EXTENSION.md files, `skill-orchestrator/SKILL.md.archived`.

**T12. Docs truth sweep.** Retire `architecture-spec.md` + fix `system-overview.md` (the
dispatch-agent fiction, ~600 lines); purge the 8 dead-script references (the `always:true`
`jq-escaping-workarounds.md` ones matter most); fold the two docs READMEs; consolidate the four
validation docs (~1,290 lines → ~700); move the 162-line Literature section out of core's
claudemd fragment into the literature extension; trim `no-task-references-in-deliverables.md`
to its ~60-line constraint (narratives → a decision record under specs/); rewrite
`skill-lifecycle.md` to the Stage-N skeleton skills actually use; update all "Load Core / Sync
all" remediation prose to whatever T6 lands.

**T13. Context budget enforcement.** Demote `jq-escaping-workarounds.md` and
`context-discovery.md` from `always:true`; stop double-loading `project-overview.md`; break up
the 77-entry `task_types:["meta"]` catch-all with real agent/command hooks; migrate the 11
`languages`-only extensions to `task_types`; reconcile the three index-schema authorities
(schema file, slim-standard, README example) and add an index-entries schema check to
`check-extension-docs.sh`.

**T14. Script hygiene + test runner.** `lib/common.sh` (repo-root resolution, session-ID,
timestamps, logging — retires ~110 duplicated lines and a live session-ID divergence); settle
`set -euo pipefail` (45 files missing `-e`, concentrated in the highest-risk scripts);
`scripts/tests/run-all.sh` wired into deploy verification so the 12 existing suites actually
run; then add suites for the top uncovered scripts (`skill-base.sh`, `update-task-status.sh`,
`generate-todo.sh`).

**T15. Agent contract normalization.** Shared `## Critical Requirements` include carrying the
no-task-references bullet (the real gap is 73 agents, not 3 — planner/meta-builder/reviser are
the highest-value targets); one frontmatter spelling for tool restriction; `model:` on the 15
agents missing it; one agent template (currently two).

### Interaction with the 19 open tasks

| Open task | Effect of this plan |
|---|---|
| 970, 958 | **Subsumed by T6** (fix the engine split once, not per-symptom) |
| 966 | Still valid; sequence after T6 (T6 shrinks the standing-failure surface it guards) |
| 947, 949 | **Subsumed by T8** |
| 950 | **Subsumed by T10** |
| 954, 955 | **Subsumed by T5** |
| 969 | Extended by T10 |
| 951–953 (defect discrimination/recording/surfacing) | Unblocked by T5; keep as-is |
| 948, 959–965, 967, 968 | Independent; keep as-is (967 and 965 are small and ready) |

### Suggested sequencing

1. **T1, T2, T3, T4** — immediate, independent, no conflicts with open tasks.
2. **T5, T6** — T6 before any new verify gates (966's constraint); T5 before 951–953.
3. **T7, T8, T9, T10** — the consolidation core; each one retires a class of future tasks.
4. **T11–T15** — cleanup, largely mechanical once 2–3 land.

### A process suggestion (the actual self-healing)

The treadmill won't stop by fixing defects alone. Two policy changes would attack the
generative mechanism:

- **"Shared mechanism or it doesn't ship"**: any block that would appear in ≥3 skills/agents
  must be an @-imported shared file or a `skill-base.sh`/`lib/` function (the
  `lit-stage4a-flow.md` precedent, generalized). A lint for near-duplicate blocks across
  skills would enforce it mechanically.
- **"Every gate needs a test and a baseline"**: no new verify gate lands without (a) a test in
  the runner, and (b) delta semantics against a baseline (966's principle, applied globally) —
  so a new gate can never convert a pre-existing wart into a batch-stopping standing failure.

---

*Full subsystem reports available on request; all findings above carry file:line evidence from
the read-only review agents.*
