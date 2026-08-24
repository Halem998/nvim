# Implementation Path

*Generated 2026-08-24 from `specs/reviews/review-2026-08-24-refactor-survey.md`.*

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
`.claude/` are trustworthy again, for this repo. `0.2` remains open, so the two consuming repos
are still on the old tree.

| # | Step | Task | State |
|---|------|------|-------|
| 0.1 | Run the deploy. Rescoped: its original premise (that `mcp-server-ownership.md` was never deployed) is **false** — that file is present and byte-identical. Its purpose is revalidated by measured script drift instead. Capture `verify-deploy --findings` **before and after**. | **32** | ☑ done |
| 0.2 | Reload the two consuming repos: `<leader>al` in `~/Projects/Logos/Theory` and `~/Projects/BimodalLogic`. | *manual* | ☐ **open — your action** |

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

**Current skew** (measured 2026-08-24 — the source-of-truth repo is behind one of its consumers):

| Repo | `skill-base.sh` |
|---|---|
| BimodalLogic | current source |
| `.config/nvim` (here) | **current** (deployed 2026-08-24) |
| Logos/Theory | stale, was identical to nvim's *former* copy — now the sole laggard |

Verified live after the deploy: `skill_orchestrate_mint_dispatch_seq` returns a correct
incrementing value in a fresh shell. Before the deploy it returned empty and aborted under
`set -u` — a failure this very orchestration run hit at its first dispatch and had to work around
inline. The fix is now in effect here, and **not** in Theory until 0.2 runs.

---

## Stage 1 — Restore consequence

Without this stage the rest regresses, exactly as it did since 2026-08-11.

**Now unblocked** by Stage 0: 82, 85 (and, outside this stage, 9, 28, 77, 92). **82 is the head of
the critical path** — 83, 86 and 93 all sit behind it, making it the single highest-leverage task
in the backlog.

| # | Step | Task |
|---|------|------|
| 1.1 | `deploy-headless.sh:233` — change the `echo` to a real call. One line; connects five working lints to the pipeline. | **82** |
| 1.2 | Postflight deploy gate: a meta task touching the source store cannot reach `[COMPLETED]` until a deploy has run. **Requires** a recorded carve-out in `regeneration-is-manual-only.md` — that doc sanctions exactly one automated deploy caller and states it is not precedent. | **83** |
| 1.3 | Fix the duplication gate's scope: `test-common-lib.sh` greps `--include="*.sh"` while **46 of 48** duplicates are `.md`, and its `EXTENSIONS_ROOT` is environment-dependent. Closes `err_1787022038113_c3VPTR` (severity high). | **84** |
| 1.4 | De-flake the shell test suite. Two runs today failed in **different** suites. Until deterministic, no gate result is trustworthy — including this review's own 19/23. | **85** |
| 1.5 | Expand CI from 1 of 9 checks to the full suite, and fix the 16 doc-lint failures so it goes green. | **86** |
| 1.6 | Close cross-repo skew: make it **visible**, not automatic. Regeneration is pull-only by design — do **not** push into consuming repos. | **93** |

> **1.4 caveat**: some gate-8 failures are *not* flake — they are the stale deploy. Re-measure
> after Stage 0 so real staleness is not excused as flake, and flake is not misattributed to
> staleness. That exact mistake was already made once, in the 2026-08-10 capstone.

---

## Stage 2 — Literature plumbing

Your literature workflow is live and currently degraded in a way that produces **no error**.

| # | Step | Task |
|---|------|------|
| 2.1 | Fix the **writer**: ingest writes `doc_id`, briefing reads `.id`. The invisible population is now **0** (was 16 → 38) — repaired out-of-band from the Literature repo — so the backfill half is done and only the writer defect is live. Task 77 gained a **fourth namespace**: `.literature.db`'s `chunks_data.doc_id` disagrees with the index on **49 documents** (32 searchable-but-unbriefed, 17 briefed-but-unsearchable). Normalizing ids without reconciling FTS trades one invisibility for another. | **77** |
| 2.2 | Coverage marker counts only documents that resolved; it is structurally blind to the ones that did not. | **78** |
| 2.3 | Index rebuild traverses with an unguarded recursive `find` — `.backups/` exists on disk today. | **80** |
| 2.4 | Quality gate rejects formal notation: the binder exemption matches only single-character bound variables, so `λxy.Ryx` and `^x.Fx` score as corruption. Must **not** blind the gate to genuine `<sup>`-span collapse. | **92** |

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

> **Sequencing**: **62** (a two-line change) is now a hard dependency of 3.3 in `state.json` — both edit `commands/task.md`.

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
| 5.1 | Finish the MCP-ownership task. **It is not done** — its plan has *eight* phases, not seven, and Phase 8 (verification sweep) is IN PROGRESS with nine unchecked boxes. Re-baseline its doc-lint assertion after Stage 0. | **28** |
| 5.2 | Re-measure the orphan set (**11 files**, not the 4 originally named) against the post-deploy tree. | **9** |
| 5.3 | One-line `jq` empty guard in `subagent-postflight.sh`. Cheapest real fix in the backlog. | **79** |
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
   self-modifying candidates that cycle); the rest defer, in sequence, one per cycle. Currently
   self-modifying: **82** (`verify-deploy.sh`), **85** (`task-lock.sh`), **87**
   (`context/patterns/`, via `system-defect-discrimination.md`), **91**
   (`update-task-status.sh`), and — once unblocked — **83**, **86**, **88**. Batching four of them
   costs four cycles to accomplish one cycle of work.
2. **`file_scope` overlap defers the higher-numbered task.** Confirmed live: **77 + 80** collide on
   `literature-build-index.sh`, so 80 defers behind 77.

> **A masking case worth knowing.** The scan emits the *first* overlapping task it finds, not an
> exhaustive list — so a `cross_batch` **idle** overlap (which admits) can hide an `in_batch`
> overlap (which would defer). Live example: **20, 84 and 85 all declare
> `agent-system/extensions/core/scripts/tests/`** with no `dependencies[]` edges between them.
> Asked to admit 84 + 85, the predicate reports 84's overlap against idle out-of-batch **#20** and
> admits both — the real in-batch 84/85 collision never surfaces. Keep 84 and 85 in separate
> batches by hand, or add a `dependencies[]` edge, until this is filed and fixed.

## Standing rules

1. **Agent-system defects get filed here**, wherever they surface. A fix written into a consuming
   repo's `.claude/` tree is wiped on its next reload. Two were mis-filed elsewhere this week.
2. **Propose, then apply, across repos.** A cross-repo agent committed directly into this tracker
   on 2026-08-24; the content was correct, the authorization was not its to give.
3. **Verify by execution, not by reading.** Four confident claims were falsified today — a
   phase count taken from `grep -c` that never asked how many phases existed, a silent-success
   path disproved by running the script, a JSON-on-stdout defect that was a merged `2>&1`, and an
   id repair that read as correct in both scripts yet broke `--toc` because a third store keyed the
   same document differently. Each was one command from being caught.

---

## Progress

| Stage | Tasks | Done |
|-------|-------|------|
| 0 — one version | 32 + manual reload | **32 ☑** · reload ☐ |
| 1 — consequence | 82, 83, 84, 85, 86, 93 | ☐ |
| 2 — literature | 77, 78, 80, 92 | ☐ |
| 3 — token | 87, 88, 44, 89 (+62) | ☐ |
| 4 — adoption | 90, 48, 50 | ☐ |
| 5 — in flight | 28, 9, 79, 91 | ☐ |
| 6 — Literature repo | *external* | partial — backlog, `.bak` prune and null-id repair done; `metadata.json` and `.backups/` open |
