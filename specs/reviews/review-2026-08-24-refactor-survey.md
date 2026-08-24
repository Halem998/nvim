# Code Review Report — Refactor Survey: Token Efficiency, Performance, Uniformity

**Date**: 2026-08-24
**Scope**: agent system (`agent-system/extensions/**` source store, `.claude/**` deploy, `specs/**` task state)
**Question posed**: *What tasks remain toward refactoring the agent system to be more token efficient, higher performance, and uniform and consistent in both implementation and documentation — revising, removing, or adding tasks and adjusting dependencies as appropriate?*
**Reviewed by**: Claude
**Method**: live gate runs + four parallel audits (coverage, token, uniformity, per-task disposition), every headline claim re-verified directly

---

## Summary

- Surfaces reviewed: 48 commands, 91 skills, 76 agents, 12 rules, 138 scripts, 19 extensions, `specs/state.json` (48 entries), `specs/errors.json` (17), `specs/events.jsonl`
- Critical: 2 · High: 5 · Medium: 6 · Low: 3
- Open tasks audited individually: 35 (plus 13 completed-but-unarchived)

**Headline**: the refactor did not stall for lack of mechanisms — it stalled for lack of *consequence*. Nearly every abstraction the refactor needs already exists and works: `git-commit-scoped.sh`, `common_session_id()`, `skill_validate_input()`, `check-deploy-freshness.sh`, five contract lints, a doc-lint, a line-count fixer. What is missing is anything that makes using them mandatory. Between 2026-08-11 and today every duplication metric grew, both orchestrate skills grew, doc-lint failures went 4 → 16, and the deploy went seven days stale — while the system correctly printed a staleness warning on every single command and nothing acted on it.

The single most important structural fact: **`deploy-headless.sh:233` prints `"Verify with: bash …verify-deploy.sh"` instead of calling it.** One `echo` where a call belongs is what disconnects five working lints from the pipeline.

---

## Movement since 2026-08-11

| Metric | 08-11 | 08-24 | Δ |
|---|---:|---:|---|
| Session-start eager context | 74,136 B (~18.5k tok) | **64,323 B (~16.1k tok)** | improved 13% |
| `verify-deploy.sh` | 21/23 | **19/23** | regressed |
| `check-extension-docs.sh` failures | 4 | **16** | regressed |
| `index-entries.json` stale `line_count` | 3 | **8–9** | regressed |
| Raw `git commit -m` sites | 65 files | **108 files** (0 migrated) | regressed |
| Session-ID one-liner | 43 files | **48 files** | regressed |
| jq #1132 block | 34 files | **36 files** | regressed |
| `skill-orchestrate/SKILL.md` | 175,303 B | **188,284 B** | regressed |
| `skill-orchestrate-hard/SKILL.md` | 107,121 B | **110,490 B** | regressed |
| `/orchestrate` per-invocation | ~82.8k tok | **~83.5k tok** | flat |
| Shell test suite | 36/36 (~2-in-5 flake) | **41/45, still flaky** | regressed |
| Duplicate `project_number: 41` | FAIL | fixed | resolved |
| `specs/reviews/state.json` registry | 3 of 4 registered | **6 of 6** | resolved |
| `specs/errors.json` accuracy | ≥3 falsely unfixed | **accurate** (5 fixed / 12 unfixed) | resolved |

The eager-context win was real and is the refactor's clearest success. It was entirely consumed by skill growth, so `/orchestrate` ended up flat.

---

## Critical Issues

### C1. The deploy is stale, and four tasks marked COMPLETED have no effect on the running system

**Files**: `.claude/scripts/skill-base.sh` + 3 literature scripts vs their `agent-system/extensions/**` sources

Last deploy: **2026-08-17 21:36**. Since then 133 commits landed and exactly 15 source files changed; gates 3 and 5 flag precisely those 15. Deployed `skill-base.sh:958` still reads `dispatch_seq_counter=$((dispatch_seq_counter + 1))` — the exact pre-fix ambient-variable code that **task 65 replaced**; source line 963 reads the corrected `jq -r '(.dispatch_seq_counter // 0) + 1'`. Its test, `test-mint-dispatch-seq.sh`, exists in source and was never deployed.

**Impact**: tasks **65, 69, 70, 71** are correctly completed as source-store work with honest summaries, and are **not live**. That includes task 69's HIGH-severity literature corpus-corruption gate. The gate-8 failures that look like a broken fix are the deployed tree running last week's code. "Completed" has silently stopped meaning "in effect."

**Fix**: run the deploy (task 32, rescoped — see Recommendations), capturing a `verify-deploy` baseline before and after. Note in CHANGE_LOG that 65/69/70/71 became live at that deploy, so a future reader does not misdate them.

### C2. Adoption of the shared mechanisms is at or near zero, and nothing counts

`git-commit-scoped.sh` — the *"single sanctioned implementation of the scoped-commit contract"* — has 25 callers against **108 files / 166 occurrences** of raw `git commit -m`. Cross-referencing the caller list against the 108 returns **empty: zero of them migrated**. Of the 108, only 4 are `.sh` and all 4 are legitimately raw; 82 of the remaining 104 markdown sites sit on executable surfaces (`commands/`, `skills/`, `agents/`) and are genuinely convertible. Concentration: core 40, founder 26, present 12.

This is the same shape across every class (see H3). The mechanism exists, is correct, and adoption stopped — because **nothing anywhere counts the call sites**. `test-git-commit-scoped.sh` tests the script's behavior and has no adoption assertion; `guard-destructive-git.sh` blocks `-a/-am/--all` but never raw `-m`.

---

## High Priority Issues

### H1. Gate taxonomy: only 3 of 15 gates can actually fail anything

Every gate in the repo falls into one of five shapes. Only shape 1 prevents recurrence.

| Shape | Count | Meaning |
|---|---:|---|
| 1 — Blocking & wired | 3 | real gates |
| 2 — Wired but cannot fail | 4 | prints, never blocks |
| 3 — Hard-exit but never auto-run | 7 | silent |
| 4 — In CI, currently red | 1 | the only CI workflow |
| 5 — No gate at all | 13 classes | the recurrence list |

**Shape 1** (the only enforcement): `validate-no-task-references.sh`, `guard-destructive-git.sh`, `validate-handoff-location.sh`. None touches duplication, structure, or documentation truth.

**Shape 2** — `check-deploy-freshness.sh` is the extreme case: it has **zero `exit 1` paths anywhere in the file**, and its one caller at `command-gate-in.sh:120` wraps it in `|| true` anyway. Doubly neutered. It has warned correctly on every command for seven days. Also here: `validate-meta-write.sh`, `validate-plan-write.sh`, `validate-state-sync.sh` (all 0× `exit 2`).

**Shape 3** — five working contract lints plus `verify-deploy.sh` itself are reachable only through an aggregator that `deploy-headless.sh:233` *prints instead of calls*. `command-gate-out.sh` invokes zero checks. `check-runtime-file-tracking.sh` has **no caller anywhere** (manifest declaration and prose references only).

**Shape 4** — `.github/workflows/check-extension-docs.yml` is the repository's only CI workflow, runs 1 of 9 checks, and exits 1 today. A permanently-red gate is functionally a shape-2 gate.

### H2. The largest token lever in the system is dead-branch loading, and no task owns it

A skill's `SKILL.md` loads **in full** on every invocation. Four skills carry large mutually-exclusive branch sections that load unconditionally:

| File | Dead-branch section | Bytes | Share of file | Fires when |
|---|---|---:|---:|---|
| `skill-orchestrate/SKILL.md` | `## Multi-Task Mode` | **103,462** | 55% | `multi_task_mode=true` only |
| `skill-distill/SKILL.md` | `## Auto Distill Complete` | 43,254 | 46% | `--auto` only |
| `skill-literature/SKILL.md` | 7 × `## Mode:` sections | ~65,772 | 78% | exactly one fires |
| `commands/task.md` | 5 non-default modes | 25,883 | 66% | one mode per invocation |

Verified in `skill-orchestrate` Stage 0: *"If `multi_task_mode` is true: skip Stages 1-8 entirely and proceed to Stage MT-1."* The branches are explicitly exclusive, so every single-task `/orchestrate N` loads ~26k tokens it will never execute.

This is **one architectural defect, not four**: mutually-exclusive branch sections loaded unconditionally. A single mode-gated section convention addresses ~79k tokens across four files and serves the uniformity goal simultaneously. Only the `commands/task.md` instance is owned (task 44).

Per-invocation budgets today (eager 64,323 B + command + skill + primary agent):

| Command | ~tokens before work begins |
|---|---:|
| `/orchestrate` | **83.5k** |
| `/orchestrate --hard` | 61.2k |
| `/literature` | 46.2k |
| `/distill` | 42.4k |
| `/todo` | 39.5k |
| `/implement` | 39.4k |

`--hard` is now *cheaper* than standard `/orchestrate`.

### H3. Duplication is an adoption gap, not a missing-abstraction gap — and the biggest class was never named

| Class | Files | ~dup bytes | Canonical home | Adopters |
|---|---:|---:|---|---:|
| **Task-lookup jq block** | **111** | **~62,000** | `skill_validate_input()` (`skill-base.sh:185`) | **6** |
| Raw `git commit -m` | 108 | — | `git-commit-scoped.sh` | 25 (0 overlap) |
| Stage 5b self-execution prose | 51 | ~24,000 | `skill-self-execution-fallback.md` | 25 |
| "postflight MUST-execute" prose | 55 | ~14,000 | `standards/postflight-tool-restrictions.md` | — |
| Context-Pointers / subagent-return | 54 | ~13,800 | `formats/subagent-return.md` | — |
| Return-meta parse block | 40 | ~13,500 | `return-meta-artifacts-lib.sh` | 5 |
| Stage 2+3 preflight pointer | 41 | ~13,200 | `skill-preflight-flow.md` | — |
| Stage-0 early-metadata template | 39 | ~11,400 | `formats/return-metadata-file.md` | — |
| Test-harness pass/fail boilerplate | 37 | ~9,000 | none | — |
| Session-ID one-liner | 48 | — | `common_session_id()` | 10 |
| jq #1132 block | 36 | ~8,000 | `jq-escaping-workarounds.md` | — |
| `printf "%03d"` padding | 85 | ~5,900 | none | — |

**~225 KB of measured duplication.** The task-lookup jq block alone (111 files vs 6 callers) exceeds the three previously-named classes combined. Six of these classes already have a canonical home — someone did the extraction and nothing held the line.

### H4. The one duplication gate that exists has the wrong scope, and has been green while its class grew

`test-common-lib.sh:230-234` asserts single-source for the session-ID generator. It greps `--include="*.sh"`. **46 of the 48 duplicates are `.md`.** The gate has reported PASS while the class grew 43 → 48. Compounding it, `errors.json` entry `err_1787022038113_c3VPTR` (severity **high**, unfixed) records that the same gate's `EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"` resolves to the repo root in deployed mode, making it environment-dependent even for the 2 `.sh` files it can see. Verified still present in both source and deploy.

This is the template for what every other class needs — and a demonstration that a gate with the wrong scope is worse than no gate, because it reports safety.

### H5. Dependency arrays are fictional and are serializing the backlog

Tasks 48 and 50 each carry **18 dependencies, 10 of which are already completed or archived**. Task 48 (migrate raw `git commit -m` call sites) nominally depends on task 39 (Zotero metadata) and task 43 (email safety context) — neither has any bearing on it. These arrays encode "do this last"; the wave scheduler reads them as hard edges, which is what pushes the on-theme work into waves 4–5.

Clearing dead edges on tasks 9, 13, 14, 20, 22, 29, 31, 39, 42, 44, 48, 50, 53, 64, 73, 79, 80 collapses the backlog from five serialized waves to roughly two. The only genuine chains that survive: `74 → {75,76}`, `29 → 30`, `77 → 78`, `48 → 50`, and `32 → 9`.

---

## Medium Priority Issues

### M1. Task 28 is finished but still marked `implementing`, blocking five tasks
All 7 plan phases read `[COMPLETED]` with 17 progress files; the dead `mcpServers` blocks are gone and the attribution error is corrected. Only postflight never ran — no `summaries/` directory, no status transition. It is listed as a blocker by tasks 29, 32, 44, 48 and 50 while being done.

### M2. `line_count` drift recurred and grew, with a mechanical fixer sitting unused
3 stale entries at 08-11, **8–9 today** across `core` and `literature`. `generate-context-line-counts.sh --write` corrects them mechanically. Nothing in postflight runs it, so the class regenerates after every context edit. `errors.json` `err_1787021593485_Bd0KIX` tracks this and is genuinely unfixed.

### M3. Task creation writes a schema-forbidden field, unowned
Tasks 53, 66, 74, 75, 76 carry a `priority` field that `state-schema.json` forbids via `additionalProperties: false`. `commands/task.md` never writes it — an agent is hand-composing state entries and nothing catches it at write time; the failure surfaces only at `verify-deploy` gate 10. No existing task covers this.

### M4. The shell test suite is still non-deterministic, and it invalidates every other gate
The `verify-deploy` run and a standalone run failed in **different suites** (mint-dispatch-seq vs. validate-return-meta). 41/45 passing, 100s wall clock. This is the residual "verification that silently passes" surface and it is why the 19/23 number itself carries an error bar. It is currently buried as item 1 of task 50's 6-item bundle.

### M5. Gate-suite wall clock is the reason nobody runs it
`check-extension-docs.sh` **46s** (was 38.5s), `check-task-references.sh` 12s, five lints ~10s, test suite 100s — **~2.8 minutes total**. A three-minute gate suite that must be invoked manually does not get invoked, which is the proximate cause of C1 and M2.

### M6. Taxonomy and roadmap drift
`active_topics` declares 16, **6 are used, 10 are orphans** (used-but-undeclared is now 0 — half of the 08-11 finding self-healed). `specs/ROADMAP.md` is unmodified since 2026-07-12; **none of its 11 items maps to any of the 48 in-flight tasks**, its success metric says "all 14 extensions" against 19, and it references task numbers from a pre-renumber era. Two of its open Phase-1 items — "CI enforcement of doc-lint" and "Agent frontmatter validation" — are precisely the gaps H1 identifies.

---

## Low Priority Issues

### L1. `/zulip` still undocumented — four months, unchanged
`/zulip`, `skill-zulip`, and `literature-agent` are deployed and absent from `.claude/CLAUDE.md`. Drift is one-directional: CLAUDE.md under-documents and never over-documents (no phantom entries). Unfixed since the 08-11 review because nothing checks it — a 3-line lint would close it permanently.

### L2. Command skeleton conformance is undeclarable, so unlintable
CLAUDE.md asserts *"All commands use checkpoint-based execution: GATE IN → DELEGATE → GATE OUT → COMMIT."* **27 of 47 conform.** Several non-conformers (`tag`, `merge`, `refresh`) are legitimately non-lifecycle utilities — but that distinction exists nowhere in frontmatter or manifest, so the claim cannot be linted even in principle. Fixing this requires first introducing a lifecycle-command marker.

### L3. Thin-wrapper Pattern B has 4 adopters of 76, two of them core
`patterns/thin-wrapper-skill.md` documents Pattern B as the "Extension skill pattern"; its four adopters are `skill-project-overview`, `skill-todo`, `skill-slide-critic`, `skill-slide-planning` — half of them core. Either the pattern is wrong or the docs are.

---

## Corrections to the 2026-08-11 review

Two of that review's figures did not reproduce under any method and should not be carried forward:

- **"~73% of the orchestrate skills is fenced bash"** — actual, counting all fences: **30.7%** (standard) and **64.3%** (hard).
- **"≥28,421 B byte-identical between the twin skills"** — contiguous identical runs ≥8 lines total only **8,168 B**; the rest is scattered boilerplate. **Twin-dedup is a weak lever**, not the strong one it was presented as.

Byte *sizes* were verified against git history and are solid. The practical consequence: the recommended fix for `/orchestrate` should be **mode-gating (H2)**, not twin-dedup. Also corrected: `errors.json` is no longer stale — all three unfixed entries spot-checked are genuinely still broken, so H5 from 08-11 is closed.

---

## Code Quality Metrics

| Metric | Value | Status |
|---|---|---|
| `verify-deploy.sh --findings` | **19/23** | Fail — gates 3, 5, 8, 10 |
| `validate-state.sh --deep` | 14 pass / 8 warn / 2 fail | Fail — `priority` field, TODO.md desync |
| `check-extension-docs.sh` | 16 issues | Fail — 3 of 20 extensions |
| `generate-context-line-counts.sh --check` | 9 of 490 mismatched | Fail |
| `lint-routing-wiring.sh` | 323 checks | Pass |
| `lint-agent-contracts.sh` | 106 checks | Pass |
| `lint-state-writer-boundary.sh` | 1029 files, 0 violations | Pass |
| `lint-postflight-boundary.sh` / `lint-contract-compliance.sh` | — | Pass |
| `check-task-references.sh` | 0 across 4 trees | Pass |
| `tests/run-all.sh` | 41/45, 100s, non-deterministic | Fail |
| Deploy freshness | core + literature stale ~7 days | Fail (non-blocking) |
| Agent frontmatter minimality | 76/76 conform, 0 obsolete fields | Pass (unenforced) |
| Session-start eager context | 64,323 B (~16.1k tok) | Improved 13% |
| Open `errors.json` | 12 unfixed / 17 | Accurate |

---

## Root-cause closure (against 2026-07-29)

| Root cause | Status |
|---|---|
| 1. Duplicated mechanism instead of shared mechanism | **Worse.** Mechanisms exist for 6 classes; adoption is 6/111, 25/108, 10/48. C2/H3 |
| 2. Verification that silently passes | **Worse in a new way.** Validators now alarm correctly, but 12 of 15 gates cannot fail or never run. H1 |
| 3. Error-tracking layer is fiction | **Closed.** Ledger is accurate; all sampled unfixed entries genuinely unfixed |
| 4. Dead machinery documented as live | **Mostly closed.** L1 residue only |
| 5. Task treadmill | **Still running.** Gates regressed 21/23 → 19/23 between reviews |

---

## Recommendations

Ordered by regressions prevented per unit of work. Group A is hours.

**Group A — restore consequence (do first; without it everything below regresses again)**
1. `deploy-headless.sh:233` — change the `echo` to an actual `verify-deploy.sh` call. One line; connects five working lints to the pipeline.
2. Run the deploy. Makes tasks 65/69/70/71 live and every subsequent measurement trustworthy.
3. Fix gate-8 scope in `test-common-lib.sh`: add `*.md` to `--include` and fix `EXTENSIONS_ROOT`. Closes a high-severity ledger entry and immediately surfaces 46 hidden duplicates.
4. Expand CI from 1 script to all 9, and fix the 16 issues so it goes green.
5. Close out task 28 (bookkeeping) — unblocks 29, 32, 44, 48, 50.

**Group B — the token levers (one architectural fix, four files)**
6. Establish a mode-gated section convention, then apply it to `skill-orchestrate`'s `## Multi-Task Mode` (103 KB), `skill-distill`'s `## Auto Distill Complete` (43 KB), `skill-literature`'s 7 mode sections (66 KB), and `commands/task.md`'s 5 non-default modes (26 KB). ~79k tokens across invocations.
7. Extract the ≥20-line bash blocks from the orchestrate pair to `scripts/` (~26k tokens). Do **not** pursue twin-dedup — it is only ~8 KB.

**Group C — adoption lints (each prevents one class from regressing)**
8. Adoption lint for `git-commit-scoped.sh` over `.md` on executable surfaces, then migrate the 82 convertible sites (task 48).
9. Adoption lint for `skill_validate_input()` — largest class by bytes (111 files, ~62 KB), zero gate.
10. CLAUDE.md coverage lint (3 lines; closes `/zulip` permanently).
11. Write-time schema validation in `state-write.sh` rejecting unknown keys, plus strip `priority` from the 5 offending entries.

**Group D — trustworthiness and hygiene**
12. De-flake the test suite (split out of task 50 as its own task) — until it is deterministic, no acceptance gate can be trusted in either direction.
13. Wire `generate-context-line-counts.sh --write` into postflight so `line_count` drift cannot recur.
14. Reduce gate-suite wall clock, `check-extension-docs.sh` (46s) first.
15. Prune the 10 orphan topics; rewrite `specs/ROADMAP.md` to describe work actually in flight.

**Decide, do not defer**: `check-deploy-freshness.sh` either gets a `--strict` mode that `command-gate-in.sh` honors, or it is accepted as informational and stops being counted as a gate. Seven days of ignored warnings means it is currently the latter regardless of intent.

**Out of scope but keep** (real defects, off-theme — track independently, do not fold into the refactor waves): 39 (Zotero), 45 (`<leader>al`), 66 (Lean livelock), 74/75/76 (LaTeX build guard), 77/78/80 (literature index).

---

*Evidence: live runs of `verify-deploy.sh --findings`, `validate-state.sh --deep`, `check-extension-docs.sh`, `generate-context-line-counts.sh --check`, all five contract lints, `check-deploy-freshness.sh`, and two independent `tests/run-all.sh` runs; byte and section measurement of the deployed tree and source store; source-vs-deploy `cmp` across 114 scripts; per-task verification against live code; cross-reference against the 07-29, 08-10 and 08-11 reviews.*
