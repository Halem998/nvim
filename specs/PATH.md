# Implementation Path

*Generated 2026-08-24 from `specs/reviews/review-2026-08-24-refactor-survey.md`.*
*Status refreshed 2026-08-24 after 82, 84, 80, 92, 9 and 79 completed.*
*Refreshed again 2026-08-24 (second pass) after the 0.2 reload landed in both consuming repos.*
*Refreshed 2026-08-25 (third pass): the recommended batch 28, 62, 77, 83 is **complete in full** —
Stage 0 and the head of Stage 1 are closed, Stage 2.1 is closed, and 28 is out of flight.*
*Refreshed 2026-08-25 (fourth pass): the recommended batch **78, 93 is complete in full** — Stage
2.2 is closed and Stage 1.6 is closed, leaving 85 and 86 as the only open items in Stage 1. The
batch ran in **3 cycles of a 10-cycle budget**, zero defers, zero failures.*
*Refreshed 2026-08-25 (fifth pass): **85 is done** (solo run, 1 cycle of a 5-cycle budget). Stage 1
now has **86 as its only open item**. The suite is deterministic again — 10/10 byte-identical
`run-all.sh` runs at 52 passed / 0 failed / 0 skipped — so gate-8 results are trustworthy for the
first time since 2026-08-11, and this file's own gate figures can once more be believed.*
*Refreshed 2026-08-25 (sixth pass): **86, 96 and 99 are done**, closing Stage 1 and Stage 2
entirely. The build-guard chain **97 → 98** and **66** also completed as one batch (9 cycles, zero
defers, zero failures, zero system-defect detections). **Stage 3 is now the critical path and 87
is its head.** Two corrections to this file's own claims, both measured not assumed: `verify-deploy.sh`
defines **14** numbered gates (not 13, and not 24); and it currently reports **2 failing gates, not
zero** — both introduced by the 97/98/66 batch itself. See "Gate reality" below.*

**Goal**: finish the agent-system refactor — token efficiency, performance, and uniformity in
implementation and documentation — and close the cross-repo drift that is currently making
"completed" and "in effect" two different things.

**How to read this**: steps are ordered. A step's dependencies are encoded in `specs/state.json`,
so `generate-task-order.sh` and the wave table in `TODO.md` agree with this file. Where a step is
*not* a task (a manual reload, a decision), it says so.

---

## The one-sentence diagnosis

The mechanisms this refactor needs mostly **already exist and work** — `git-commit-scoped.sh`,
`common_session_id()`, `skill_validate_input()`, `check-deploy-freshness.sh`, five contract lints,
a doc-lint, a line-count fixer. What is missing is **consequence**: adoption stalled at a fraction
of call sites, the staleness detector always exits 0, and `deploy-headless.sh:233` *prints*
`"Verify with: …"` instead of calling it. Every duplication metric grew between 2026-08-11 and
2026-08-24 while the system correctly reported the problem to nobody.

---

## Gate reality (measured 2026-08-25, sixth pass)

Run directly, not inferred: `verify-deploy.sh --skip-slow` **exits 1** with **2 of 14 gates
failing**. Both failures were introduced by the 97/98/66 batch and neither is flake.

| Gate | Finding | Cause | Fix |
|---|---|---|---|
| **3** doc-lint | `Rule R: index-entries.json entry 'project/lean4/operations/multi-instance-optimization.md' line_count mismatch: declared 121, actual 198` | **98** rewrote that anchor (121 → 198 lines) without updating its declaration. `index-entries.json` was outside 98's `file_scope`, and its plan verified only that `manifest.json` needed no edits — nobody checked the line-count declaration. | One number: `agent-system/extensions/lean/index-entries.json:351`, `121` → `198`. |
| **5** manifest parity | `Missing scripts: scripts/lake-build-guard.sh` and `scripts/tests/test-lake-build-guard.sh` | **97** registered both in the core manifest, correctly. They are simply **not deployed** — declared-but-absent from `.claude/`. | A deploy. Nothing to author. |

**Denominator corrections, both verified by counting `say "N. …"` lines directly.** This file
previously carried "24 checks" (inherited, never verified) and then "13 numbered gates" (a
correction that undercounted). The real figure is **14**. Treat 14 as the denominator.

**The prior claim that 86 alone would make deploys exit 0 is now falsified.** 86 is done and
doc-lint is still red — but for a *new* reason authored after 86 landed, not because 86 failed. The
standing rule holds: a green gate is a measurement, not a status inherited from a completed task.

**Latent third, not yet failing.** `long-builds.md` (153 lines, created by **66**) is **not
registered in `index-entries.json` at all**. It does not fail today only because it is undeployed;
Rule S fires the moment it lands. 66's own plan recorded this as an out-of-scope follow-up rather
than absorbing it — the honest call, but it means **the unregistered-context-file class is now four
files, not three** (see the 2026-08-25 observation below). Deploying without registering it first
converts a latent item into a third red gate.

**Operational consequence**: fix the one line, register `long-builds.md`, *then* deploy. Deploying
first clears gate 5 and lights up Rule S for `long-builds.md` in the same motion.

---

## Stage 0 — Get every repo onto one version

**0.1 is DONE** (2026-08-24, commits `a1cddc5d5`..`a064b8b5c`). Measurements taken against
`.claude/` are trustworthy again, for this repo. **0.2 is now DONE as well** (reload run by hand in
both consuming repos), so Stage 0 is closed: all three repos are on one version, verified below.

| # | Step | Task | State |
|---|------|------|-------|
| 0.1 | Run the deploy. Rescoped: its original premise (that `mcp-server-ownership.md` was never deployed) is **false** — that file is present and byte-identical. Its purpose is revalidated by measured script drift instead. Capture `verify-deploy --findings` **before and after**. | **32** | ☑ done |
| 0.2 | Reload the two consuming repos: `<leader>al` in `~/Projects/Logos/Theory` and `~/Projects/BimodalLogic`. | *manual* | ☑ done |

**Measured at execution, correcting this file's own earlier figures**: the drift was **44 commits
and 16 files** under `agent-system/`, not "133 commits / 15 files". The deploy resolved **29 of 45**
baseline findings, including every script-drift finding and all nine persisted-counter test
failures. Post-deploy `comm -13` against the baseline returned 3 lines, **0 of them functional
regressions**: 2 were the same pre-existing gate8 failure re-emitted under a fresh randomized
`mktemp -d` path (that check embeds its tmp path in its own finding text, so it can never produce
a stable string for set comparison), and 1 was a latent **source-store** gap — `literature/
index-entries.json` has no entry for `shared-module-extraction-for-gate-checks.md` — made visible
for the first time because the file itself had never been deployed before. Same defect class as the
`return-meta-artifacts-template.md` Rule S finding this file's Stage 5 already treats as
out-of-scope input.

**The install-once remediation landed**: the deployed `.claude/settings.json` now carries no
`mcp__lean-lsp__*` grant (permission array 24 → 23 elements, valid JSON), and the source copy was
never touched.

> **A premise in 0.1 was falsified by execution.** Both the task and its plan predicted the
> hand-edit would trip the source-store-boundary advisory hook, and required that the reasoning be
> recorded rather than ignored. **The hook never fired.** `validate-meta-write.sh`'s `is_meta_path`
> list covers `commands/*`, `skills/*`, `agents/*`, `rules/*`, `context/*`, `extensions/*`,
> `scripts/*`, `hooks/*`, `*/CLAUDE.md` — a **root-level** file such as `settings.json` matches
> none of them. This is a coverage gap in the advisory layer aimed precisely at the file class that
> needs it most: install-once files are the one part of `.claude/` a redeploy cannot restore. Not
> yet filed as a task.

**Verified safe**: every deployed script in both consuming repos either matches current source or
matches a *historical* source revision exactly (Theory's `archive-task.sh` matches the 2026-07-16
revision byte-for-byte). There are **no hand-edits to lose**. Only `context/repo/project-overview.md`
is syncprotected in each, and it survives reload.

**What 0.1 makes live for the first time**: the persisted dispatch-counter fix and three literature
fixes, one of them a HIGH-severity corpus-corruption gate. Note in `CHANGE_LOG.md` which
previously-completed tasks became live here, so a future reader does not misdate them.

**Current skew: none.** Re-measured 2026-08-24 after the 0.2 reload, by comparison rather than by
assertion — for each of the three deployed trees, every `.claude/scripts/*.sh` also present in this
repo's deployed tree was byte-compared:

| Repo | `skill-base.sh` | Deployed scripts vs. here |
|---|---|---|
| `.config/nvim` (here) | `819aa8b0…` | — (reference) |
| BimodalLogic | `819aa8b0…` | **110 compared, 0 differing** |
| Logos/Theory | `819aa8b0…` | **110 compared, 0 differing** |

All four copies (source store + three deploys) of `skill-base.sh` share one checksum. The
`Only in …` entries a naive `diff -rq` reports are extension-set differences (each repo loads a
different extension mix), not drift.

Verified live after the deploy: `skill_orchestrate_mint_dispatch_seq` returns a correct
incrementing value in a fresh shell. Before the deploy it returned empty and aborted under
`set -u` — a failure this very orchestration run hit at its first dispatch and had to work around
inline. With 0.2 done, that fix is now in effect in **all three** repos, not just here.

---

## Stage 1 — Restore consequence

Without this stage the rest regresses, exactly as it did since 2026-08-11.

**82 is done** (2026-08-24, commits `02ed59dda`, `55955bb65`). **84 is also done** (`58bf87d23`).
**83 is now done as well**, which closes the head of the critical path and unblocks **93** — the
postflight deploy gate is live and has already been exercised in anger (see the 2026-08-25 note
below, where it correctly refused a completion and the sanctioned redeploy trigger handled it).

**This stage is now closed.** 86 completed 2026-08-25, joining 82, 83, 84, 85 and 93. Nothing in
Stage 1 remains open.

> **Closed ≠ green.** 86 expanded CI to the full suite and fixed the doc-lint failures *that
> existed when it ran*. `verify-deploy` is red again as of the sixth pass, from two findings
> authored **after** 86 landed — see "Gate reality" above. That is the mechanism working, not 86
> regressing: the gate now catches things the day they are introduced, which is the whole point of
> the stage.

| # | Step | Task | State |
|---|------|------|-------|
| 1.1 | `deploy-headless.sh:233` — change the `echo` to a real call. Delivered as more than one line: `verify-deploy.sh` gained `--skip-slow` (skips only gate 8, the ~118s suite) and the deploy now exits **3** for "deploy landed, verification failed", distinct from `1`/`2`. Acceptance was executed, not asserted — an injected `line_count` mismatch produced exit 3 naming the failing gate with no human invocation. | **82** | ☑ done |
| 1.2 | Postflight deploy gate: a meta task touching the source store cannot reach `[COMPLETED]` until a deploy has run. **Requires** a recorded carve-out in `regeneration-is-manual-only.md` — that doc sanctions exactly one automated deploy caller and states it is not precedent. | **83** | ☑ done |
| 1.3 | Fix the duplication gate's scope: `test-common-lib.sh` greps `--include="*.sh"` while **46 of 48** duplicates are `.md`, and its `EXTENSIONS_ROOT` is environment-dependent. Closes `err_1787022038113_c3VPTR` (severity high). | **84** | ☑ done |
| 1.4 | De-flake the shell test suite. Two runs today failed in **different** suites. Until deterministic, no gate result is trustworthy — including this review's own 19/23. **Root cause was not the hypothesised lock contention** — research overturned that, finding no defect in `task-lock.sh` or `run-all.sh`; the flake was two stale test fixtures reaching into the live `specs/` tree. Fixed by isolating them into scratch fixture repos. Acceptance measured, not asserted: **10/10 byte-identical runs** (52 passed / 0 failed / 0 skipped), HEAD stable throughout, staleness confounder separated by a source-vs-deployed diff **before** measuring. | **85** | ☑ done (`ce00e7174`) |
| 1.5 | Expand CI from 1 of 9 checks to the full suite, and fix the doc-lint failures so it goes green. | **86** | ☑ done |
| 1.6 | Close cross-repo skew: make it **visible**, not automatic. Regeneration is pull-only by design — do **not** push into consuming repos. Delivered as a git-tracked registry of **8** consumer repos (the delegation named 3), a `check-consumer-freshness.sh` fleet report with `--discover`, a post-deploy stale-consumer report wired into `deploy-headless.sh`'s trailing block without touching its 0/1/2/3 exit contract, and a non-blocking tier-1 escalation at 5 consecutive ignored runs. Verified live against all 8 consumers and two real deploys, not fixtures alone. | **93** | ☑ done (`50313f14b`) |

> **1.5 now has a measured baseline, courtesy of 1.1.** A full `verify-deploy.sh` run at 82's
> completion reported **2 of 24 checks failing** — gate 3 (doc-lint) and gate 8 (`run-all.sh`) —
> both pre-existing, neither introduced by 82. Those two are exactly 86's and 85's targets. Note
> the consequence: because 1.1 landed, **every deploy from now on exits 3** until those two are
> fixed. That is the mechanism working as designed, but it means deploys are red starting now, and
> 85 + 86 are what turn them green again.
>
> **Re-measured 2026-08-25, after 85 landed: 1 of 13 numbered gates failing.** Gate 8 now passes;
> **doc-lint (gate 3) is the only red gate left**. So 86 is not merely the next step in this stage —
> it is the single remaining thing standing between the repo and a green `verify-deploy`, and
> therefore between every future deploy and an exit code of 0 instead of 3.
>
> *Denominator correction*: `verify-deploy.sh` defines **13** numbered gates, counted directly from
> its own `say "N. …"` lines. The "24" used in the paragraph above is inherited from an earlier
> revision of this file and was never verified here; it presumably counts sub-checks rather than
> gates. Treat 13 as the gate denominator until someone reconciles where 24 came from.
>
> **Both figures above are superseded — struck 2026-08-25, sixth pass.** The gate count is **14**,
> not 13 and not 24, counted the same way and re-counted. And "1 failing" was true only until 86
> landed and the 97/98/66 batch was authored on top of it; the current reading is **2 failing**,
> with different causes than the one named here. **See "Gate reality" near the top of this file for
> the live figures** — the paragraph above is retained only to show what the numbers were and why
> they moved.

> **1.4 caveat — discharged 2026-08-25.** The re-measure was done as instructed: every source-store
> file the fix touched, plus `run-all.sh` itself, was byte-compared against its deployed `.claude/`
> counterpart **before** the measurement block, all identical. So the 10/10 result is a statement
> about flake with staleness excluded, not the two confounded. The separately-flagged `literature`
> extension staleness was traced to a gitignored Python venv and an intentionally-undeployed
> `deprecated/` folder — neither referenced by any literature suite, so it does not contaminate the
> figure. The 2026-08-10 misattribution was not repeated.

---

## Stage 2 — Literature plumbing

Your literature workflow is live and currently degraded in a way that produces **no error**.

| # | Step | Task |
|---|------|------|
| 2.1 | Fix the **writer**: ingest writes `doc_id`, briefing reads `.id`. **Done 2026-08-25.** All ten phases landed, including the fourth-namespace reconciliation: the FTS/index divergence went **49 → 1** (FTS-only 32 → 0, index-only 17 → 1, the survivor being `gabbay_2000`, an unconverted PDF recorded as a known exception). Corpus reconciliation is corpus commit `55dc921c`; `--validate`'s namespace-divergence check is now a **hard failure** gated on that one-item exception list. | **77** ☑ done |
| 2.2 | Coverage marker counts only documents that resolved; it is structurally blind to the ones that did not. **Done 2026-08-25.** Research found a **second, worse** silent-exit site alongside the known one: on *total* resolution failure the script did a bare `exit 0` emitting no marker at all, so the simplest regression fixture would have had nothing to assert against. Both fixed. The skip-rate signal was **folded into the existing `sparse` disjunction** (new `LITERATURE_SKIP_RATE_THRESHOLD`, default 50%) rather than added as a new flag — which is what let both existing marker consumers keep working with **zero edits to either file**. | **78** ☑ done (`be33ac673`) |
| 2.3 | Index rebuild traverses with an unguarded recursive `find` — `.backups/` exists on disk today. | **80** ☑ done (`7f04ede80`) |
| 2.4 | Quality gate rejects formal notation: the binder exemption matches only single-character bound variables, so `λxy.Ryx` and `^x.Fx` score as corruption. Must **not** blind the gate to genuine `<sup>`-span collapse. | **92** ☑ done (`b629bc3a9`) |

**This stage is now closed.** **96 completed 2026-08-25**, joining 77, 78, 80 and 92. The
78-then-96 ordering the collision note below required was satisfied by sequencing, as designed.

| # | Step | Task |
|---|------|------|
| 2.5 | Surface the sub-index vs global-index coverage delta under `--lit` — meaningful only once 78's marker reported resolution failures at all. | **96** ☑ done |

> **Why 2.1 mattered concretely** (historical, 2026-08-24): a `--lit` round in Theory silently
> missed 7 of 25 ingested sources, **including both of your own manuscripts**, despite the work
> resting on the semantics they develop. Both now resolve; a Theory briefing run resolves **37 of
> 37** sub-index entries with zero skip warnings. The data was repaired, the writer was not.

> **The trap 2.1 must avoid**: the obvious fix — rename ingest-written ids to the curated long
> form — was tried by hand and **broke search**. `--toc` returned `[]` for a document whose
> briefing entry had just started resolving, because FTS keys on the bare id. Code reading did not
> show this; running the command did. Keep the id FTS holds and add the parent entry under it.

> **Duplicate closed**: Theory's tracker held its own task for 2.1; abandoned 2026-08-24
> (`d18782f1`) as filed in the wrong repo.

> **How 2.1 actually resolved, and the trap it confirmed.** The fix took the path this file
> predicted: **keep the bare id FTS holds and add the parent entry under it**, never rename. 17
> unpaired FTS-only ids got new parent entries; the 15 that were already bridged by a curated
> entry were deliberately left alone, because renaming them is the exact operation known to break
> `--toc`. Two duplicate chunk directories (`proofs_and_types`, `van_doorn_2015_propositional_calculus_coq`)
> were **quarantined, not deleted** — dot-prefixed, which `literature-build-index.sh` prunes by
> design, so the move is reversible.
>
> **The blocker that held this task dissolved under measurement, not argument.** It had been
> marked BLOCKED on "duplicate adjudication requires content judgment on citation-grade data".
> `cmp` showed both pairs were **byte-identical** (176/176 and 20/20 files) — there was no fidelity
> choice to make, and the loser in each pair was identifiable purely by provenance (the ingest
> directory carries the stub writer's own bare-slug `metadata.json` pointing at a PDF that lives in
> the other directory). One command retired a block that had stopped the task twice. Standing
> rule 3, again.

> **2.2 and 2.3 collided and were not batched — resolved by sequencing.** #96's `file_scope` is
> the wildcard `agent-system/extensions/literature/scripts/**` plus `context/**`, which swallows
> #78's two paths whole. The prescribed order (**78 first, 96 after**) was followed: 78 landed
> 2026-08-25, so 96 is now free to run and inherits a corrected marker to measure its coverage
> delta against — exactly the reason the order mattered.

---

## Stage 3 — Token efficiency

**This is now the critical path.** Stages 0, 1 and 2 are closed; **87 is the head of everything
that remains**, and it is unblocked as of 86's completion.

The measured payoff. `/orchestrate` currently costs **~83.5k tokens before any work begins**.

| # | Step | Task | Saving |
|---|------|------|--------|
| 3.1 | Establish the mode-gated section convention **plus a lint**. Without the lint this regresses like every other extracted-then-readopted class here. | **87** | — |
| 3.2 | `skill-orchestrate`'s `## Multi-Task Mode` — **103,462 B, 55% of the file**, loaded on every single-task run that explicitly skips it. | **88** | ~26k tok/invocation |
| 3.3 | `commands/task.md` — 5 non-default modes, 25,883 B of 39,403 B. Plan already corrects the earlier mis-targeting. | **44** | ~6k tok/invocation |
| 3.4 | `skill-literature` (7 mode sections, ~65,772 B) and `skill-distill` (`## Auto Distill Complete`, 43,254 B). | **89** | ~24.8k tok combined |

> **Do not pursue twin-dedup** between `skill-orchestrate` and its `-hard` variant. The
> 2026-08-11 review's "≥28,421 B byte-identical" figure did not reproduce — contiguous identical
> runs total only 8,168 B. Weak lever, and a distraction from 3.2.

> **Sequencing**: **62** is a hard dependency of 3.3 in `state.json` — both edit `commands/task.md`. **62 is now done**, so **44 is unblocked** and already sits at `[PLANNED]`.
>
> **Superseded 2026-08-25 (sixth pass): 44 is blocked again, deliberately.** Its `dependencies[]`
> is now `[62, 88]` — the PATH-ordered chain re-inserted 88 ahead of it, so 44 sits behind
> 87 → 88 rather than being independently runnable. Its `[PLANNED]` status is real and its plan is
> still good; it simply is not eligible until 88 lands. Do not dispatch it expecting it to run.

> **Fence-interior heading trap**: naive `^## ` splitting matches headings inside fenced blocks and
> silently truncates. Task 44's plan documents this and mandates bottom-up extraction. Reuse it.

---

## Stage 4 — Adoption

Each item prevents one class from regrowing. Build the lint **before** migrating.

| # | Step | Task |
|---|------|------|
| 4.1 | Task-lookup jq block — **111 files, ~62 KB**, against 6 callers of `skill_validate_input()`. Largest class in the repo; exceeds the three previously-named classes combined. | **90** |
| 4.2 | Migrate raw `git commit -m` to `git-commit-scoped.sh`: **108 files, 166 occurrences, 0 migrated**. 82 are convertible; the 4 `.sh` sites are legitimately raw. | **48** |
| 4.3 | Hygiene residue: session-ID 48 files, jq-1132 36 files, `@.claude/docs` refs 6 → 15, quarantine `literature-retrieve.sh`, prune 10 orphan topics, rewrite `ROADMAP.md`. | **50** |

---

## Stage 5 — In-flight and unblocked

| # | Step | Task |
|---|------|------|
| 5.1 | Finish the MCP-ownership task. | **28** ☑ done |
| 5.2 | Re-measure the orphan set (**11 files**, not the 4 originally named) against the post-deploy tree. | **9** ☑ done (`662d67b95`) |
| 5.3 | One-line `jq` empty guard in `subagent-postflight.sh`. Cheapest real fix in the backlog. | **79** ☑ done (`5c8de5857`) |
| 5.4 | Diagnose non-conforming plan Status lines. The `$` anchor at line 69 means `[IMPLEMENTING] (resumed; …)` can never be stamped — confirmed `rc=1`. The original silent-success framing was **false** and has been struck. | **91** |

---

## Batch serialization edges (added 2026-08-25)

`dependencies[]` now encodes a single PATH-ordered chain across the remaining Stage 3/4/5 tasks, so
the whole set can be handed to one `/orchestrate` invocation and will serialize itself.

**Updated 2026-08-25 (sixth pass): 86 is done and off the head. The chain is now eight tasks:**

```
87 -> 88 -> 44 -> 89 -> 90 -> 48 -> 50 -> 91
```

Verified against `state.json` this pass: 87←[86 ☑], 88←[87], 44←[62 ☑, 88], 89←[44, 87],
90←[84 ☑, 89], 48←[90], 50←[48], 91←[50]. **87 is the only member currently eligible**; the other
seven are correctly blocked behind it.

This is a **total order** (max parallelism 1), which is deliberate and costs almost nothing here:
eight of the nine touch a path in `orchestrator-critical-paths.json`, and the self-modification
admission gate already admits only one such candidate per cycle. The edges buy determinism and
PATH-order fidelity rather than trading away real concurrency.

**Collisions the chain resolves** (each would otherwise defer at admission time):

| Pair | Overlapping scope |
|---|---|
| 48, 50 vs. everything | both declare the bare `agent-system/extensions/` prefix |
| 87 vs. 90 | `core/scripts/lint/` |
| 44 vs. 87, 88, 91 | 44's `core/context/` is a prefix of the others' `context/` paths |
| 88 vs. 87 | `core/context/patterns/` |

**89 is the one genuine parallelism candidate** — its scope is confined to the `literature` and
`memory` extensions, so it is neither self-modifying (both sit outside the `core` scope_root) nor
collides with anything except the two blanket-scope tasks. Pull its chain edge if a future batch
wants one parallel lane.

**Cost of a total order, stated plainly**: a task that lands in `failed_tasks` marks every
downstream task blocked. One failure at 86 strands the other eight. That is the trade for
determinism; batch in smaller groups if that risk is unwanted.

---

## Stage 6 — Outside this repo

Not tasks here. `~/Projects/Literature/` is tracked separately. The commit backlog described
here is **cleared** — the working tree is clean as of 2026-08-24.

- **Done**: the re-converted `schultz-spivak-vasilakopoulou` directory (a genuine upgrade: 45
  chunks/103 KB → 99 chunks/1.05 MB with source PDF and clean prose, **not** data loss),
  `FIND_SOURCES.md`, and the index additions are committed. The 123-change backlog is gone.
- **Done** from BimodalLogic: 69 dirs consolidated under `sources/`, 38 null-id entries repaired
  (including both Jónsson & Tarski volumes, needed by that repo's open work), `.literature.db`
  gitignored, FTS 22502 → 22661 chunks with no drop. All 399 index entries now carry `.id`.
- **Done**: the 26 `index.json.bak*` files are pruned — none remain.
- **Still open**: `metadata.json` is missing far more widely than one directory — only **90 of
  206** `sources/` directories have one. `.backups/` is **95 MB** across four directories and holds
  14 `chunks.json.bak` files; the corpus is clean only because of manual `.bak` renames (2.3).

---

## Co-dispatch batching

Two admission rules govern what can be orchestrated *together*, and both are cheap to get wrong.
Verified against `orchestrate-batch-admit.sh` on 2026-08-24, not assumed:

1. **One self-modifying task per cycle.** A task whose `file_scope` names an orchestrator-critical
   path is admitted only as the *designated candidate* (lowest task number among the
   self-modifying candidates that cycle); the rest defer, in sequence, one per cycle. Re-verified
   2026-08-24 against `orchestrate-batch-admit.sh:581` — the verdict is explicitly *"an ORDERING
   CONSTRAINT, not an exclusion"*; deferred candidates resolve in later cycles of the **same**
   invocation. Batching four of them still costs four cycles to accomplish one cycle of work — so
   pair **at most one** with non-self-modifying siblings.

   **Re-measured 2026-08-25 (sixth pass) by running the admission script against every unblocked
   task individually**, rather than carrying the previous list forward. 85, 86 and 93 have
   completed and are dropped. The list is **much longer than previously recorded** — the earlier
   list named 7 and was drawn only from tasks then on the critical path:

   | Self-modifying (designated-candidate slot) | Free to batch |
   |---|---|
   | **13**, **14**, **42**, **53**, **68**, **73**, **81**, **87**, **100** | **20**, **27**, **72**, **74**, **94** |

   Plus **48** and **50**, whose bare `agent-system/extensions/` scope covers every critical path —
   still solo-only for the separate reason in rule 2. The practical consequence is unchanged but
   sharper: **most of the remaining backlog is self-modifying**, so a batch is one of the nine plus
   as many of the five free tasks as scope allows.

   > **`--dry-run` misreports this, and the misreport is the more alarming of the two.**
   > `orchestrate-dry-run-report.sh:361` **hardcodes its own reason string** — "deferred out of
   > this invocation — re-run it alone (orchestrator-critical work runs solo only)" — discarding
   > the admission script's actual verdict text and asserting the opposite of it. It then omits
   > those tasks from its own `Recommended split`. `commands/orchestrate.md` claims the report
   > "uses the SAME read-only admission analysis the live path uses", so the two are supposed to
   > agree and do not. Read the report's `Excluded` block as *"will be sequenced into a later
   > cycle"*, not *"will not run"*. **Not yet filed as a task.**
2. **`file_scope` overlap defers the higher-numbered task.** The **77 + 80** collision on
   `literature-build-index.sh` is retired — both are done. The **78 + 96** collision is retired by
   *sequencing*, not by scope change: 78 is done, so 96 now runs without contending for those
   paths. The **44 + 93** collision is retired — 93 is done. Still live: **20 + 85** on
   `scripts/tests/`; **44 + {96, 99}** at `core/context/`, where 44's coarse scope makes the two
   *higher*-numbered siblings defer (so run 44 solo, not alongside them); and **48/50**, whose bare
   `agent-system/extensions/` scope overlaps essentially every other task in the backlog. Treat
   **48 and 50 as solo-only**.

   **Refreshed 2026-08-25 (sixth pass).** Retired by completion: **20 + 85** (85 done — 20 is now
   free to batch), **44 + {96, 99}** (both done). **48/50 remain solo-only**, unchanged.
   Newly measured and live: **72 + 94** collide at
   `core/skills/skill-team-research/SKILL.md` with no `dependencies[]` edge, so 94 (higher) defers.
   Run **72 before 94**, or add the edge. This was found only by running the admission script over
   the candidate set — it is not visible from either task's title.

> **A masking case worth knowing.** The scan emits the *first* overlapping task it finds, not an
> exhaustive list — so a `cross_batch` **idle** overlap (which admits) can hide an `in_batch`
> overlap (which would defer). The original example (84 masking 20/85) is retired — 84 is done —
> but the defect is not: **20 and 85 still both declare
> `agent-system/extensions/core/scripts/tests/`** with no `dependencies[]` edge, and today's
> dry-runs show both **20** and **77** reporting idle overlaps against out-of-batch **#48** while
> their own in-batch relationships go unmentioned. Keep 20 and 85 in separate batches by hand, or
> add a `dependencies[]` edge, until this is filed and fixed.

## Next batch (recommended 2026-08-25, sixth pass, verified by execution)

The previous recommendation — `/orchestrate 85, 96, 99` — is **complete in full**, and **86** and
the **97 → 98** / **66** build-guard set landed alongside it. Stages 0, 1 and 2 are all closed.
Stage 3 is the critical path and **87 is its head**.

```
/orchestrate 87, 74, 20, 72, 27
```

Verified today by running `orchestrate-batch-admit.sh` directly — **all five admit, one wave, zero
defers** — and, because the scan reports only the *first* overlap it finds, re-run **pairwise**
across all ten pairs to rule out an `in_batch` collision masked by a `cross_batch` advisory. **All
ten pairs are clean.** Dependencies confirmed satisfied: 87←86 ☑; 74, 20, 72, 27 have none.

| Task | Why it is in this batch | Notes |
|------|-------------------------|-------|
| **87** | Stage 3.1, **head of the entire remaining chain**. The mode-gating convention plus its lint; unblocks 88 (~26k tok/invocation) and 89 (~24.8k) — the largest measured payoff in this file. Nothing else in Stages 3-5 can start until it lands. | **The one self-modifying task** (`context/patterns/`) — takes the designated-candidate slot uncontested |
| **74** | Shared LaTeX build-conflict guard. The direct sibling of the just-completed **97**, and 97's own research noted no `latex-build-guard.sh` exists yet, so 97 set a family precedent this task is the second member of. Unblocks **75** and **76**. | Non-self-modifying; latex-side scope |
| **20** | Metrics sync measures a stale git index, inflating `build_errors` with phantom paths. **Freed this pass**: its long-standing `scripts/tests/` collision was with 85, which is now done. | Non-self-modifying |
| **72** | Teammate return-meta write conflict in team mode. **Must precede 94** — see the newly-measured 72 + 94 collision in rule 2 above. | Non-self-modifying |
| **27** | Remove the dead `.opencode` command router and its self-referential test scripts. Pure deletion; no collisions with anything in the batch. | Non-self-modifying |

**Why five and not three.** Batching rule 1 permits at most one self-modifying task alongside
non-self-modifying siblings. 87 is the only one here, so it is admitted as designated candidate and
**nothing defers**. The other four are genuinely independent lanes — this is the widest clean batch
the current backlog allows.

**Do not add 94** — it collides with 72 at `skill-team-research/SKILL.md` and, being the higher
number, is the one that defers. Run it in the *next* batch, after 72 lands.
**Do not add 44** — its `dependencies[]` is now `[62, 88]`, so it is blocked behind 88 regardless of
its `[PLANNED]` status. It is not eligible.
**Do not add 88, 89, 90, 48, 50 or 91** — all blocked behind 87 in the PATH chain.
**Do not add a second self-modifying task** (13, 14, 42, 53, 68, 73, 81, 100) — each would contend
with 87 for the designated slot and cost a cycle to buy nothing.

**Before or after this batch, two one-line repairs** (see "Gate reality" at the top — both are
regressions from the 97/98/66 run, and together they are what stand between the repo and a green
`verify-deploy`):

1. `agent-system/extensions/lean/index-entries.json:351` — `line_count` `121` → `198`.
2. Register `long-builds.md` (153 lines) in that same file, **then** deploy. Deploying first
   clears gate 5 and immediately lights up Rule S for the unregistered anchor.

Neither is a task and neither needs one; both are smaller than the overhead of filing them.

**Then, solo, in PATH order** — each names an orchestrator-critical path, so each takes the
designated-candidate slot and batching them together only buys cycles:

1. **88** — mode-gate `skill-orchestrate`'s `## Multi-Task Mode` (103,462 B, 55% of the file).
   The single largest token win in the backlog.
2. **44**, then **89**, then **90** → **48** → **50** → **91**.

**Non-self-modifying and safe to slot in** whenever a later batch has room: **94** (after 72),
**45**, **46**, **51**. The self-modifying singles — **13**, **14**, **42**, **53**, **68**,
**73**, **81**, **100** — are each a solo or designated-slot run; **53** is worth pulling forward
(see the observation below, where this run reproduced its defect nine times).

**Stage 0 remains closed**, but its "current skew: none" line is still only as good as its
measurement date. `check-consumer-freshness.sh` last flagged BimodalLogic, ModelChecker, Theory and
PossibleWorlds as behind. **Re-run it before trusting any Stage 0 claim** — and note that the two
undeployed guard scripts in "Gate reality" mean this repo is itself now ahead of its own `.claude/`.

### Two stranded tasks, noticed 2026-08-25

**22** and **31** both sit at `[RESEARCHING]` with no active session. That status no longer causes
a skip — eligibility is no longer status-gated, and a stale lock is reclaimed on dispatch — so
either is safe to re-dispatch whenever wanted. Flagged only so they are not mistaken for in-flight
work.

### Two observations from the 2026-08-24 re-run (both still unfiled)

1. **The dry-run misreport has a second instance, in the same file.** The note emitted for 83 reads
   *"admitted only because this invocation carries a single candidate (solo run); alongside any
   sibling it would instead be excluded and deferred to a solo re-run"* — emitted on an invocation
   carrying **four** candidates, in which 83 was in fact admitted alongside three siblings. Same
   defect class as the hardcoded exclusion string at `orchestrate-dry-run-report.sh:361`: report
   prose asserting the opposite of the verdict it is reporting. **Still not filed as a task**, now
   with two instances.
2. **The lock-contention check silently degrades.** Today's report shows
   `lock contention: SKIPPED (degraded: task-lock.sh check exit 3 for: 62 77 83)`. Exit 3 is
   `task-lock.sh check`'s *usage* error (`task-lock.sh:1588`, `[ "$#" -lt 1 ]`) — the caller passed
   no task number. That is not a lock verdict at all; a caller-side argument bug is being surfaced
   as a degraded-check notice, and the admission run proceeds with one of its checks silently not
   run. **Not filed as a task.**

### Four new observations from the 2026-08-25 run (none filed)

1. **The `blockers` field is written by the system but rejected by its own schema.** Marking a task
   blocked writes a `blockers[]` array into that task's `state.json` entry, and
   `validate-state.sh --deep` then reports `Unknown entry field: blockers` as a **FAIL-level**
   gate-10 finding. Writer and schema disagree. Observed on 77, cleared only by deleting the array
   once the blockers were genuinely resolved — but any blocked task reintroduces it, and gate 10
   fails for as long as one exists. Either add `blockers` to `state-schema.json` or stop writing
   it. **Adds a recurring failure to 86's target set.**

2. **Redeploy-then-commit deadlocks the new deploy gate; commit-then-redeploy does not.** 83's gate
   compares `.claude-extensions.json`'s recorded `source_git_head` against
   `git log -1 -- <source_dir>`. An agent that redeploys *before* committing makes its own commit
   newer than the recorded head, so the extension reads STALE and the completion transition is
   refused — through no fault of the work. Worse, the sanctioned redeploy trigger then re-runs the
   deploy, finds the newly-deployed files produce **new** lint findings, and takes branch (b),
   refusing to auto-complete. Observed end-to-end on 77 today. **The operational rule is: commit
   the source-store change first, deploy second.** Worth stating in
   `regeneration-is-manual-only.md` alongside 83's carve-out.

3. **Deploying a long-unregistered context file converts latent debt into a live gate failure.**
   `corpus-directory-conventions.md` (from 80) and `shared-module-extraction-for-gate-checks.md`
   (from 69) were added to the literature source store but never registered in that extension's
   `index-entries.json`. They were invisible until a redeploy pushed them into `.claude/`, at which
   point Rule S fails for each. This is the same class Stage 0 already flagged for
   `shared-module-extraction-for-gate-checks.md` and `return-meta-artifacts-template.md` — the
   class is now **three files and growing, one per contributing task**. **86's doc-lint target set
   includes these; they are not flake and will not clear themselves.**

4. **A 240 MB virtualenv sits untracked in the source store.**
   `agent-system/extensions/literature/scripts/literature-pyenv/` is provisioned by
   `literature-pyenv-provision.sh` and is **not** gitignored — `.gitignore:55` excuses only the
   *deployed* copy (`.claude/scripts/literature-pyenv/`, via the blanket `/.claude/` rule). It
   shows permanently in `git status` and is the main reason a full `verify-deploy` run takes
   ~3 minutes. Harmless to correctness, but a one-line `.gitignore` entry removes a standing
   distraction and speeds every gate run. **Not filed.**

### Three observations from the 78 + 93 batch run (2026-08-25, none filed)

1. **`orchestrator-critical-paths.json` does not cover the deploy scripts.** Task 93 edited
   `deploy-headless.sh` and `check-deploy-freshness.sh` and was **not** flagged self-modifying,
   because the critical-path list names `verify-deploy.sh` but neither of those two. The overlap
   predicate is directory-prefix, so sibling files in `core/scripts/` do not match. The result was
   convenient here — 93 batched freely — but it means a task can rewrite the deploy driver the
   orchestrator itself calls without taking the designated-candidate slot, and the inter-cycle
   redeploy checkpoint likewise never fired for it. Either the omission is deliberate and should
   say so in that file, or the list is incomplete. **Not filed.**

2. **A research agent wrote `report_path` instead of `artifacts[]`.** 93's research handoff carried
   its report under a top-level `report_path` key with an **empty** `artifacts` array; postflight
   had to fall back to `.return-meta.json` to link the artifact at all. This is precisely the
   defect **99** exists to fix, now with a reproduced instance in this repo's own history rather
   than an argued one. Folded into the batch recommendation above as 99's justification.

3. **The consumer fleet has already drifted again since the 2026-08-24 reload.** 93's own new
   `check-consumer-freshness.sh`, run live at completion, flags **BimodalLogic, ModelChecker,
   Theory and PossibleWorlds** as behind source, with the remainder `CANNOTVERIFY` because their
   recorded `source_git_head` predates the stamping fix. Stage 0's "current skew: none" line is
   true only as of its own measurement date — the whole point of 93 is that this is now a
   one-command question instead of a manual audit. **Re-run it before trusting any Stage 0 claim.**

### Four observations from the 97 + 98 + 66 batch run (2026-08-25, none filed)

1. **A completed task can author a gate failure that its own acceptance sweep cannot see.** 98's
   Phase 5 walked all 12 ACCEPTANCE conditions, confirmed its diff was a subset of `file_scope`,
   and passed — while leaving `verify-deploy` gate 3 red, because the file it broke
   (`lean/index-entries.json`) was **outside** that `file_scope` by construction. `file_scope`
   bounds what a task may edit; it does not bound what a task may *break*. A content edit that
   changes a file's line count has an obligation in a second file that no scope declaration
   expresses. **The general shape**: rewriting any registered context file silently incurs a
   `line_count` debt. Worth a lint — declared vs. actual across every `index-entries.json` — which
   would have caught this at authoring time rather than at the next deploy. **Not filed.**

2. **The unregistered-context-file class reached four, and this run added the fourth.** 66's
   `long-builds.md` joins `corpus-directory-conventions.md`,
   `shared-module-extraction-for-gate-checks.md` and `return-meta-artifacts-template.md`. The
   pattern is now unmistakable and self-reproducing: **one new file per contributing task**, each
   invisible until a deploy makes it fail Rule S. 66's plan recorded it as a follow-up rather than
   absorbing it — correct scope discipline, and exactly why the class keeps growing. This will not
   stop until registration is enforced at authoring time.

3. **"Expected handoff absence" fired nine times in one batch, every time correctly.** Every
   research and plan dispatch in this run wrote no `.orchestrator-handoff.json` — as the schema
   requires, since only the hard-mode implement agent writes one — and each time the orchestrator
   fell through to `.return-meta.json` recovery and reported `recovered=true`. The recovery path is
   sound and the batch had **zero system-defect detections**. But the first research agent flagged
   its own non-write as a "deliberate deviation" needing orchestrator adjustment, which it was not.
   **This is precisely what 53 (`suppress_expected_handoff_absence_defect`) exists to fix**, now
   with nine reproduced instances in one invocation rather than an argued case. **Worth pulling 53
   forward** — it is self-modifying, so it needs a designated slot, but it is cheap and the
   evidence is no longer hypothetical.

4. **A task with `path: null` and no directory on disk dispatches fine — after someone creates the
   directory.** 66 had `"path": null` in `state.json` and no `specs/066_*` directory; the
   orchestrator's MT path has no `mkdir -p` equivalent to the single-task engine's
   `orchestrate-loop-guard-init.sh`, so the directory had to be created by hand before dispatch.
   Single-task and multi-task `/orchestrate` differ here, and only the single-task engine is
   self-healing. **Not filed.**

### Filed since the last refresh, not yet placed in a stage

**Retired this pass** — **96** is now Stage 2.5 ☑, **99** ☑, and **97 → 98** ☑ (with **66**, which
was never listed here at all despite running in the same batch — worth noting that this section is
maintained by hand and drifts).

**Still unplaced**: **100** (aggregator `file_scope` blind spot — the too-narrow-scope mirror of
the completed coarse-declaration work; self-modifying) and **94** (`--lit` through the three team
skills; **must run after 72**, see rule 2). Neither is on the critical path.

**Never placed, and now the bulk of the backlog**: **13**, **14**, **20**, **27**, **29** → **30**,
**42** → **64**, **43**, **45**, **46**, **51**, **53**, **68**, **72**, **73**, **74** → **75**/**76**,
**81**. Seventeen tasks, none in any stage, most filed as defect observations from prior runs. The
staged Stages 3-5 chain is eight tasks; **the unstaged remainder is now more than twice that.**
A full re-survey is overdue — this file's stage structure describes a shrinking minority of open
work.

### Still unfiled, carried forward

- `validate-meta-write.sh`'s `is_meta_path` misses **root-level** `.claude/` files such as
  `settings.json` — the install-once class a redeploy cannot restore (recorded in Stage 0).
- Both dry-run report defects above.
- All four earlier 2026-08-25 observations: the `blockers` schema mismatch, the redeploy-ordering
  deadlock, the unregistered-context-file class, and the source-store virtualenv. **The virtualenv
  is still open** — verified 2026-08-25 with `git check-ignore -v`, which reports it NOT ignored;
  93 touched the root `.gitignore` only to register its own streak file, not this. It still shows
  permanently in `git status` and still slows every full gate run.
- All three observations from the 78 + 93 batch run above: the critical-paths coverage gap, the
  `report_path`-instead-of-`artifacts[]` instance, and the re-drifted consumer fleet.
- All four observations from the 97 + 98 + 66 batch run above: the out-of-`file_scope` gate
  breakage, the fourth unregistered context file, the nine expected-handoff-absence firings
  (**53 already exists for this one** — it needs scheduling, not filing), and the MT-mode missing
  task directory.
- **The two "Gate reality" repairs at the top of this file.** Both are one-line, neither is a task,
  and both block a green `verify-deploy`.
- **The `mcp__lean-lsp__lean_build` gap**, recorded by 66 in `long-builds.md` as a known caveat: a
  second build path that `run_in_background` cannot wrap, so the background-build mandate has a
  hole in it by construction. Documented, not fixed.
- **Files outside 66's `file_scope` that still carry pre-mandate `lake build` guidance** —
  `README.md`, `lean-implementation-flow.md`, `commands/lake.md`. 66 enumerated exactly nine files
  and held to them; the mandate is therefore correct but not yet universal in the lean extension.

---

## Standing rules

1. **Agent-system defects get filed here**, wherever they surface. A fix written into a consuming
   repo's `.claude/` tree is wiped on its next reload. Two were mis-filed elsewhere this week.
2. **Propose, then apply, across repos.** A cross-repo agent committed directly into this tracker
   on 2026-08-24; the content was correct, the authorization was not its to give.
3. **Verify by execution, not by reading.** Confirmed twice more on 2026-08-25: a task blocked on
   "requires human content judgment" was released by a single `cmp` showing the two candidate
   directories were byte-identical, and a "stale deploy" diagnosis that looked like file drift was
   actually a recorded-git-head comparison — the file-content theory would have sent the fix in
   entirely the wrong direction. Four confident claims were falsified on 2026-08-24 — a
   phase count taken from `grep -c` that never asked how many phases existed, a silent-success
   path disproved by running the script, a JSON-on-stdout defect that was a merged `2>&1`, and an
   id repair that read as correct in both scripts yet broke `--toc` because a third store keyed the
   same document differently. Each was one command from being caught.

---

## Progress

*Updated 2026-08-25 (sixth pass).*

| Stage | Tasks | Done |
|-------|-------|------|
| 0 — one version | 32 + manual reload | **32 ☑ · reload ☑** — stage closed |
| 1 — consequence | 82, 83, 84, 85, 86, 93 | **all six ☑** — **stage closed** |
| 2 — literature | 77, 78, 80, 92, 96 | **all five ☑** — **stage closed** |
| 3 — token | 87, 88, 44, 89 (+62) | **62 ☑** · 44 planned but blocked behind 88 · **87, 88, 89 ☐** |
| 4 — adoption | 90, 48, 50 | ☐ |
| 5 — in flight | 28, 9, 79, 91 | **9 ☑ 28 ☑ 79 ☑** · 91 ☐ |
| *unstaged* | 17 tasks (13, 14, 20, 27, 29→30, 42→64, 43, 45, 46, 51, 53, 68, 72, 73, 74→75/76, 81, 94, 100) | ☐ — **larger than the staged remainder**; re-survey overdue |
| 6 — Literature repo | *external* | partial — backlog, `.bak` prune, null-id repair and the FTS/index reconciliation (`55dc921c`) done; `metadata.json` and `.backups/` open |

**Critical path now**: **Stage 3**, headed by **87**. Stages 0, 1 and 2 are all closed, so nothing
upstream gates it — 87 → 88 is the largest measured token win in the file (~26k/invocation from 88
alone), and seven of the eight chained tasks are blocked behind 87 today.

**What stops deploys exiting non-zero is no longer a task at all.** The two red gates are a
one-line `line_count` correction and an undeployed pair of scripts — see "Gate reality" at the top.
Both are repairs, not work items, and both are regressions from the batch that just ran rather than
anything the stages were tracking.
