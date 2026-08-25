# Implementation Path

*Generated 2026-08-24 from `specs/reviews/review-2026-08-24-refactor-survey.md`.*
*Status refreshed 2026-08-24 after 82, 84, 80, 92, 9 and 79 completed.*
*Refreshed again 2026-08-24 (second pass) after the 0.2 reload landed in both consuming repos.*
*Refreshed 2026-08-25 (third pass): the recommended batch 28, 62, 77, 83 is **complete in full** —
Stage 0 and the head of Stage 1 are closed, Stage 2.1 is closed, and 28 is out of flight.*

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

**Open in this stage**: 85, 86, 93.

| # | Step | Task | State |
|---|------|------|-------|
| 1.1 | `deploy-headless.sh:233` — change the `echo` to a real call. Delivered as more than one line: `verify-deploy.sh` gained `--skip-slow` (skips only gate 8, the ~118s suite) and the deploy now exits **3** for "deploy landed, verification failed", distinct from `1`/`2`. Acceptance was executed, not asserted — an injected `line_count` mismatch produced exit 3 naming the failing gate with no human invocation. | **82** | ☑ done |
| 1.2 | Postflight deploy gate: a meta task touching the source store cannot reach `[COMPLETED]` until a deploy has run. **Requires** a recorded carve-out in `regeneration-is-manual-only.md` — that doc sanctions exactly one automated deploy caller and states it is not precedent. | **83** | ☑ done |
| 1.3 | Fix the duplication gate's scope: `test-common-lib.sh` greps `--include="*.sh"` while **46 of 48** duplicates are `.md`, and its `EXTENSIONS_ROOT` is environment-dependent. Closes `err_1787022038113_c3VPTR` (severity high). | **84** | ☑ done |
| 1.4 | De-flake the shell test suite. Two runs today failed in **different** suites. Until deterministic, no gate result is trustworthy — including this review's own 19/23. | **85** | ☐ solo run |
| 1.5 | Expand CI from 1 of 9 checks to the full suite, and fix the doc-lint failures so it goes green. | **86** | ☐ solo run |
| 1.6 | Close cross-repo skew: make it **visible**, not automatic. Regeneration is pull-only by design — do **not** push into consuming repos. | **93** | ☐ **unblocked — 83 is done** |

> **1.5 now has a measured baseline, courtesy of 1.1.** A full `verify-deploy.sh` run at 82's
> completion reported **2 of 24 checks failing** — gate 3 (doc-lint) and gate 8 (`run-all.sh`) —
> both pre-existing, neither introduced by 82. Those two are exactly 86's and 85's targets. Note
> the consequence: because 1.1 landed, **every deploy from now on exits 3** until those two are
> fixed. That is the mechanism working as designed, but it means deploys are red starting now, and
> 85 + 86 are what turn them green again.

> **1.4 caveat**: some gate-8 failures are *not* flake — they are the stale deploy. Re-measure
> after Stage 0 so real staleness is not excused as flake, and flake is not misattributed to
> staleness. That exact mistake was already made once, in the 2026-08-10 capstone.

---

## Stage 2 — Literature plumbing

Your literature workflow is live and currently degraded in a way that produces **no error**.

| # | Step | Task |
|---|------|------|
| 2.1 | Fix the **writer**: ingest writes `doc_id`, briefing reads `.id`. **Done 2026-08-25.** All ten phases landed, including the fourth-namespace reconciliation: the FTS/index divergence went **49 → 1** (FTS-only 32 → 0, index-only 17 → 1, the survivor being `gabbay_2000`, an unconverted PDF recorded as a known exception). Corpus reconciliation is corpus commit `55dc921c`; `--validate`'s namespace-divergence check is now a **hard failure** gated on that one-item exception list. | **77** ☑ done |
| 2.2 | Coverage marker counts only documents that resolved; it is structurally blind to the ones that did not. | **78** |
| 2.3 | Index rebuild traverses with an unguarded recursive `find` — `.backups/` exists on disk today. | **80** ☑ done (`7f04ede80`) |
| 2.4 | Quality gate rejects formal notation: the binder exemption matches only single-character bound variables, so `λxy.Ryx` and `^x.Fx` score as corruption. Must **not** blind the gate to genuine `<sup>`-span collapse. | **92** ☑ done (`b629bc3a9`) |

**Open in this stage**: **78** (now unblocked), then **96** behind it — see the collision note below.

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

> **2.2 and 2.3 collide and must not be batched.** #96's `file_scope` is the wildcard
> `agent-system/extensions/literature/scripts/**` plus `context/**`, which swallows #78's two
> paths whole. Run **78 first, 96 after** — 96 surfaces a coverage delta that 78's marker fix is
> what makes meaningful in the first place.

---

## Stage 3 — Token efficiency

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
   invocation. Currently self-modifying among **open** tasks (83 has since completed and is dropped
   from this list): **85** (`task-lock.sh`), **86** (`verify-deploy.sh`), **87**
   (`context/patterns/`, via `system-defect-discrimination.md`), **90** (`skill-base.sh`), **91**
   (`update-task-status.sh`), **100** (`orchestrate-batch-admit.sh`), **48** (its
   `agent-system/extensions/` catch-all scope covers every critical path). Batching
   four of them still costs four cycles to accomplish one cycle of work — so pair **at most one**
   with non-self-modifying siblings.

   > **`--dry-run` misreports this, and the misreport is the more alarming of the two.**
   > `orchestrate-dry-run-report.sh:361` **hardcodes its own reason string** — "deferred out of
   > this invocation — re-run it alone (orchestrator-critical work runs solo only)" — discarding
   > the admission script's actual verdict text and asserting the opposite of it. It then omits
   > those tasks from its own `Recommended split`. `commands/orchestrate.md` claims the report
   > "uses the SAME read-only admission analysis the live path uses", so the two are supposed to
   > agree and do not. Read the report's `Excluded` block as *"will be sequenced into a later
   > cycle"*, not *"will not run"*. **Not yet filed as a task.**
2. **`file_scope` overlap defers the higher-numbered task.** The **77 + 80** collision on
   `literature-build-index.sh` is retired — both are done. Still live: **20 + 85** on
   `scripts/tests/`; **78 + 96**, where 96's `literature/scripts/**` wildcard swallows 78 whole
   (measured 2026-08-25); **44 + 93** at `core/context/`, where 93 is the one that defers; and
   **48/50**, whose bare `agent-system/extensions/` scope overlaps essentially every other task in
   the backlog. Treat **48 and 50 as solo-only**.

> **A masking case worth knowing.** The scan emits the *first* overlapping task it finds, not an
> exhaustive list — so a `cross_batch` **idle** overlap (which admits) can hide an `in_batch`
> overlap (which would defer). The original example (84 masking 20/85) is retired — 84 is done —
> but the defect is not: **20 and 85 still both declare
> `agent-system/extensions/core/scripts/tests/`** with no `dependencies[]` edge, and today's
> dry-runs show both **20** and **77** reporting idle overlaps against out-of-batch **#48** while
> their own in-batch relationships go unmentioned. Keep 20 and 85 in separate batches by hand, or
> add a `dependencies[]` edge, until this is filed and fixed.

## Next batch (recommended 2026-08-25, verified by execution)

The previous recommendation — `/orchestrate 28, 62, 77, 83` — is **complete in full**. All four
landed, and each unblocked what it was supposed to: 83 → 93, 77 → 78 and 96, 62 → 44, 28 closed.

Re-verified today with `orchestrate-dry-run-report.sh 78 93`: **both admitted, zero exclusions,
one wave**, and — unlike the previous batch — **no self-modifying task is involved at all**, so
the designated-candidate slot is not consumed and nothing defers.

```
/orchestrate 78, 93
```

| Task | Why it is in this batch | Unblocks |
|------|-------------------------|----------|
| **78** | Stage 2.2, the coverage marker that is structurally blind to resolution failures. Now unblocked by 77, and it is the paired second assertion 77's own regression requirement names — 77 proved an ingested doc *appears*; 78 proves an unresolvable one is *reported*. Until both exist, the silent-degradation half can regress freely. | 96 |
| **93** | Stage 1.6, unblocked by 83 today. Closes the cross-repo skew loop that Stage 0 opened by hand. Scope is core deploy scripts — wholly disjoint from 78's literature scripts. | — |

**Two advisories the dry-run emitted, both benign**: #78 shows an idle overlap against out-of-batch
**#48** (whose bare `agent-system/extensions/` scope overlaps essentially everything), and #93
against **#44** at `core/context/`. Neither blocks; both are the known coarse-scope advisory class.

**Do not add 96** — its `literature/scripts/**` wildcard swallows 78's scope entirely. **Do not add
44** — its coarse `core/context/` collides with 93 at `regeneration-is-manual-only.md`, and 93
being the higher number is the one that would defer.

**Then, solo, in this order** — each names an orchestrator-critical path, so each takes the
designated-candidate slot and batching them together only buys cycles:

1. **85** — de-flake the suite. Before 86, not after: a green CI built on a flaky suite certifies
   nothing, and 82's exit-3 wiring means gate 8's flake now fails deploys.
2. **86** — expand CI and fix doc-lint. Together with 85 this is what makes deploys exit 0 again.
   **Its target set grew today** — see the new observations below.
3. **87** — the mode-gating convention **plus its lint**; unblocks 88 (~26k tok/invocation) and 89
   (~24.8k), the largest measured payoff in the file.
4. **91**, then **90**, then **48** → **50**.

**Non-self-modifying and safe to slot in** whenever a batch has room: **96** (after 78), **44**
(after 93 clears, or alongside 78), **99**, **20**.

**Nothing is left in Stage 0.** The `<leader>al` reload is done and verified in both consuming
repos; all three deployed trees are byte-identical on every shared script.

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

### Filed since the last refresh, not yet placed in a stage

**96** (surface the sub-index vs global-index coverage delta under `--lit`; **now unblocked, 77 is
done** — belongs in Stage 2 behind **78**, not merely behind 77, because their scopes collide), **99** (handoff `artifacts[]` shape), **100** (aggregator
`file_scope` blind spot — the too-narrow-scope mirror of the completed coarse-declaration work;
self-modifying), **94** (`--lit` through the three team skills), and **97 → 98** (shared Lean
build concurrency/memory guard, then its lean-extension wiring). None are on the critical path;
place them on the next full refresh.

### Still unfiled, carried forward

- `validate-meta-write.sh`'s `is_meta_path` misses **root-level** `.claude/` files such as
  `settings.json` — the install-once class a redeploy cannot restore (recorded in Stage 0).
- Both dry-run report defects above.
- All four 2026-08-25 observations above: the `blockers` schema mismatch, the redeploy-ordering
  deadlock, the unregistered-context-file class, and the source-store virtualenv.

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

*Updated 2026-08-25.*

| Stage | Tasks | Done |
|-------|-------|------|
| 0 — one version | 32 + manual reload | **32 ☑ · reload ☑** — stage closed |
| 1 — consequence | 82, 83, 84, 85, 86, 93 | **82 ☑ 83 ☑ 84 ☑** · 85, 86, 93 ☐ |
| 2 — literature | 77, 78, 80, 92 (+96) | **77 ☑ 80 ☑ 92 ☑** · 78, 96 ☐ |
| 3 — token | 87, 88, 44, 89 (+62) | **62 ☑** · 44 planned · 87, 88, 89 ☐ |
| 4 — adoption | 90, 48, 50 | ☐ |
| 5 — in flight | 28, 9, 79, 91 | **9 ☑ 28 ☑ 79 ☑** · 91 ☐ |
| 6 — Literature repo | *external* | partial — backlog, `.bak` prune, null-id repair and the FTS/index reconciliation (`55dc921c`) done; `metadata.json` and `.backups/` open |

**Critical path now**: Stage 1's remaining three (85 → 86 → 93) are what stop deploys exiting 3.
85 and 86 are solo-only; 93 is batchable and is in today's recommended pair.
