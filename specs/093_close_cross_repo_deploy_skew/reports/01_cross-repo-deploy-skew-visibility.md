# Research Report: Task #93

**Task**: 93 - close_cross_repo_deploy_skew
**Started**: 2026-08-25T04:03:00Z
**Completed**: 2026-08-25T04:30:00Z
**Effort**: 4-6h (estimated)
**Dependencies**: None (source_git_head stamping and check-deploy-freshness.sh/deploy-freshness-lib.sh already exist and are reused, not modified)
**Sources/Inputs**: Codebase (`check-deploy-freshness.sh`, `deploy-freshness-lib.sh`, `deploy-headless.sh`, `command-gate-in.sh`, `update-task-status.sh`), `context/patterns/regeneration-is-manual-only.md`, `context/standards/orchestrator-runtime-files.md`, live filesystem measurement of `.claude-extensions.json` across every discoverable repo on this machine, prior task report `specs/018_detect_stale_claude_deploy_trees/reports/01_stale-deploy-detection.md`, `specs/PATH.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **No new comparison algorithm is needed.** `scripts/lib/deploy-freshness-lib.sh`'s existing
  `deploy_freshness_status <repo_root> <extension_name>` already implements the exact comparison
  this task needs, and it already works when called against an arbitrary repo path from this
  repo — because the value it compares (`source_dir`) is an absolute path back into *this* repo's
  `agent-system/extensions/*`, not a path relative to the consumer. What is missing is purely an
  **enumeration + reporting layer**: something that knows which repos to check and prints a
  cross-repo table, wrapping the existing per-repo/per-extension primitive rather than
  reimplementing it.
- **There is no registry of "known consuming repos" anywhere in the source store today.** The
  only way to discover a consumer is a filesystem scan for `.claude-extensions.json` files whose
  `core.source_dir` matches this repo. Measured live: **8 real consumers** exist right now —
  `~/.dotfiles`, `~/Projects/{BimodalLogic,ModelChecker,PersonalWebsite,cslib}`,
  `~/Projects/Logos/{Theory,Hardware}`, `~/Philosophy/Papers/PossibleWorlds` — spread across
  three unrelated root directories (`~/.dotfiles`, `~/Projects/**`, `~/Philosophy/Papers/**`), so
  no single shallow scan root covers all of them.
- **The task's own framing narrative is itself evidence for a registry, not just a scanner.**
  `specs/PATH.md`'s Stage 0.2 recorded "the reload run by hand in both consuming repos" as if
  that closed the gap — but only 2 of the 8 real consumers were reloaded. The operator's mental
  model of "which repos consume this" was already stale relative to reality, which is exactly the
  failure mode a durable, explicit registry (checked into git, diffable in `git log`) closes and
  a best-effort scan alone does not.
- **Recommended design** (detailed below): (1) a small git-tracked registry file naming known
  consumer repo paths; (2) a new reporting script that reuses `deploy_freshness_status` per
  registered repo × per extension that repo records; (3) a `--discover` mode on that script that
  scans common roots and flags any *unregistered* consumer, so new repos don't silently fall
  outside the registry forever; (4) a call from `deploy-headless.sh`'s existing trailing block
  naming which known consumers are now stale after a deploy lands; (5) a bounded, non-blocking
  escalation on `check-deploy-freshness.sh`'s per-repo WARN via a small consecutive-ignore
  counter, staying strictly advisory to avoid inverting the deliberate pull-only architecture.

## Context & Scope

The postflight deploy gate (`update-task-status.sh`'s TIER 2, `context/patterns/
regeneration-is-manual-only.md`'s "Automated Exception: The Postflight Completion-Deploy Gate")
makes "completed" mean "in effect" only inside *this* repo. Consuming repos pull independently and
freeze at whatever they last reloaded (`regeneration-is-manual-only.md`'s "Regeneration:
Interactive by Default, Headless When Driven Deliberately" — deliberate, not a defect). Detection
of a single repo's own staleness already exists and works (tier 1: `check-deploy-freshness.sh`,
always-silent-unless-stale, always exit 0; tier 2: `update-task-status.sh`'s blocking postflight
backstop for *this* repo's own commits). What does not exist is any visibility, **from this repo**,
into the fleet of repos that depend on it. Scope, per the task delegation: make skew visible and
actionable, not eliminated — never have this repo push into a consumer.

## Findings

### Codebase Patterns

**`deploy_freshness_status(repo_root, extension_name)` (`agent-system/extensions/core/scripts/
lib/deploy-freshness-lib.sh`) already generalizes to any repo path.** Its internal helper reads
`<repo_root>/.claude-extensions.json`, pulls that extension's recorded `source_dir` (an absolute
path — always pointing back into *this* repo, e.g.
`/home/benjamin/.config/nvim/agent-system/extensions/core`) and `source_git_head`, then
recomputes the current path-scoped revision via `git -C <repo_toplevel-of-source_dir> log -1
--format=%H -- <source_dir>` and compares. Nothing in this computation depends on the caller's
own cwd or repo identity — it was designed for two *local* tiers (`check-deploy-freshness.sh`
checking `$(pwd)`, and `update-task-status.sh` checking `$PROJECT_ROOT`) but is already
repo-root-parametric. Verified directly: calling it with `repo_root` set to
`~/Projects/BimodalLogic` or `~/Projects/Logos/Theory` from inside this repo's shell correctly
reads their `.claude-extensions.json` and recomputes against this repo's own git history.

**Measured staleness, live, 2026-08-25** (`core` extension only, most consumers track several
extensions):

| Repo | recorded `core.source_git_head` | current local HEAD (path-scoped) |
|---|---|---|
| `~/.config/nvim` (this repo) | `eb64e1db9…` | `eb64e1db9…` (fresh, by construction) |
| `~/Projects/BimodalLogic` | `02ed59dda…` | STALE |
| `~/Projects/Logos/Theory` | `02ed59dda…` | STALE |
| `~/Projects/Logos/Hardware` | (not sampled this pass — same `source_dir`, same registry candidate) | — |
| `~/Projects/ModelChecker`, `~/Projects/PersonalWebsite`, `~/Projects/cslib`, `~/.dotfiles`, `~/Philosophy/Papers/PossibleWorlds` | (present, `source_dir` confirmed pointing here; per-field staleness not individually re-sampled this pass — task delegation's own STALE claim for BimodalLogic/nvim/Theory was independently reproduced) | — |

This directly reproduces the task delegation's measured claim (nvim's own tree was stale
2026-08-17 through this research pass; both BimodalLogic and Theory recorded an older `core`
revision, `02ed59dda…`, than this repo's own current `core` revision at the time of the
delegation).

**No registry exists.** `grep` across `agent-system/extensions/core/` for `known_consumers`,
`consuming_repos`, `consumer_repos`, `registry`, `KNOWN_ROOTS`, `SCAN_ROOTS`, `PROJECT_ROOTS`
found nothing that lists sibling repo paths. The only artifact that comes close is
`.claude-extensions.json` itself — but that file lives *in each consumer*, recording where its
extensions came from; there is no mirror-image file in the source repo recording who consumes it.
`context/patterns/regeneration-is-manual-only.md`'s own "Detecting When You're Stale" section
states the check is "single-machine: `source_dir` is an absolute, machine-local path" as a known
limitation of tier 1/2 — a cross-repo reporting command inherits that same single-machine scope
by construction (it can only ever see repos on the machine it runs on), which is consistent with
the acceptance criterion ("from this repo, one command...") and not a new limitation to solve.

**`deploy-headless.sh`'s existing trailing block is the natural hook for acceptance criterion
(b).** Its `main()` already ends every non-dry-run invocation with an inline
`verify-deploy.sh --skip-slow` call and a clear exit-code contract (0/1/2/3, see the script's
header). A consumer-staleness report is a same-shape addition: after either successful branch
(exit 0 or 3 — both mean "the tree WAS modified"), call the new reporting script and print which
known consumers are now behind the revision just deployed. This composes cleanly with the
existing `SELF-OVERWRITE HAZARD` structural constraint (`main()` fully parsed before any of it
runs) as long as the new call is added inside `main()`, not appended after it.

**`command-gate-in.sh`'s CHECKPOINT 1 call site (`command-gate-in.sh:119-120`) is the exact model
for how a non-blocking check is wired in** — `bash .claude/scripts/check-deploy-freshness.sh
2>&1 || true`, guarded on the script's own existence. Any new escalation behavior on the tier-1
per-repo warning belongs inside `check-deploy-freshness.sh` itself (or a sibling it sources),
reusing this identical calling convention, so it inherits the same always-non-blocking guarantee
without command-gate-in.sh needing to know anything changed.

**No existing "consecutive-ignored-warning" counter pattern exists to imitate.** Searched for
`consecutive` across the scripts likeliest to have one (`skill-base.sh`, `generate-todo.sh`,
`orchestrate-triage-classify.sh`) and found none that tracks repeated-ignore counts for a
warning; the closest structural analogue is the hard-mode churn counter
(`.orchestrator-churn-state.json`, per-target counters, see
`context/standards/orchestrator-runtime-files.md`), which is a different mechanism (per-orchestration-cycle,
ephemeral, reaped at loop termination) but establishes the precedent that a small per-target JSON
counter file is this codebase's existing idiom for "how many times in a row has X happened,"
rather than inventing a new state shape.

### External Resources

Not applicable — self-contained internal tooling task, no external documentation consulted.

### Recommendations

**1. Registry file (new).** Add a small, git-tracked JSON file in the source store — e.g.
`agent-system/extensions/core/context/reference/known-consumer-repos.json` (sibling to the
existing `orchestrator-critical-paths.json`, which is the same shape of small hand-maintained
reference data) — listing each known consumer as `{"path": "/home/benjamin/Projects/...",
"note": "optional label"}`. Deliberately **not** deployed into `.claude/` (it is source-repo-only
metadata; consumers never need to see who their siblings are), and deliberately **not**
auto-derived at read time on every check — explicit registration is the point: it survives a
consumer being temporarily unreachable (renamed, on another disk, not yet cloned on this
machine) without silently dropping out of the audit, unlike a scan.

**2. New reporting script (new): `check-consumer-freshness.sh`.** Deploys under
`.claude/scripts/` like its siblings. Sources `deploy-freshness-lib.sh` (no changes needed to
that file). For each registered repo, if `.claude-extensions.json` is present there, enumerate
*that repo's own* recorded extensions (so the registry only needs a path, never a duplicated
per-extension list) and call `deploy_freshness_status(repo_path, ext_name)` for each. Print a
table: repo, extension, status. Unlike tier 1's deliberate total silence on "cannot verify," this
command is **explicitly invoked** by a human auditing the fleet, so it should surface every
registered entry's status including "not found on disk" / "no `.claude-extensions.json` yet" /
`CANNOTVERIFY` rather than silently omitting them — the whole point of an opt-in audit command is
completeness, unlike the ambient, every-command tier-1 check which must stay silent to avoid
"unknown" reading as either "confirmed fresh" or an alarm. This satisfies acceptance criterion
(a): "from this repo, one command reports the deployed revision of every known consuming repo and
flags those behind source."

For richer detail than a bare STALE/FRESH flag, the path-scoped commit-count-behind is cheap to
add: `git -C <source_dir's repo toplevel> log --format=%H -- <source_dir>` (already computed
inside the lib for the head-of-history value) can locate the recorded head's position in that
same path-scoped history to report "N commits behind" rather than a bare boolean, reusing data
the lib already touches rather than adding a second git call class.

**3. `--discover` mode on the same script.** A best-effort scan across a short, explicit list of
root directories (`~`, `~/.dotfiles`, `~/Projects`, `~/Projects/Logos`, `~/Philosophy/Papers` —
covering the 8 measured consumers today, extendable) for `.claude-extensions.json` files whose
some-extension `source_dir` matches this repo, diffed against the registry, printing any
consumer found on disk but **not** in the registry. This is the reconciliation step that keeps
the explicit registry from silently going stale itself (mirroring, one meta-level up, exactly
the staleness problem this task is about) — run manually/occasionally, not on every invocation,
since it is the expensive path the registry exists to avoid paying routinely.

**4. Wire into `deploy-headless.sh`.** Inside `main()`'s existing trailing block (after the
`verify-deploy.sh --skip-slow` call, regardless of whether it returns the exit-0 or exit-3
branch — both mean the tree was modified), call `check-consumer-freshness.sh` and print "the
following known consumer repos are now stale relative to the revision just deployed: …". This is
purely additive reporting — it must not change `deploy-headless.sh`'s existing exit-code
contract (0/1/2/3) and must not attempt to redeploy into any named consumer, preserving the
task's explicit non-goal. This satisfies acceptance criterion (b).

**5. Escalation for ignored per-repo warnings (open decision, framed for `/plan`).** The task
asks to *decide* whether tier 1's per-repo WARN should escalate after N consecutive ignored runs
(a week of a warning nobody acts on is not functioning as a warning). Recommendation: **yes, but
visibility-only, never blocking** — inverting tier 1 into a blocking gate would duplicate tier 2
(which already exists, is evidence-gated, and is scoped to *this* repo's own commits) and would
contradict `regeneration-is-manual-only.md`'s explicit, twice-justified pull-only design for
every *other* repo. Concretely: `check-deploy-freshness.sh` (or a sibling it sources) increments
a small per-repo counter (an ephemeral runtime file inside the checked repo itself, e.g.
`specs/.freshness-warn-streak.json`, in the same class as `.orchestrator-churn-state.json` per
`context/standards/orchestrator-runtime-files.md`'s table — ephemeral, no freshness-check trust
implications, reset to 0 on a FRESH result) each time it fires a WARN, and once a threshold is
crossed, upgrades the WARN's presentation (e.g., a multi-line banner naming how many consecutive
commands have ignored it) while remaining exit-0 and non-blocking. `/plan` should pick the exact
threshold and storage key name; a **count of consecutive command invocations**, not wall-clock
days, is recommended since the mechanism already only fires on a command invocation and adding a
day-based check would introduce a new timestamp-diffing dependency for no clearer signal (a
week of an actively-used repo and a week of an idle one are very different "N ignored commands"
counts, which is arguably the more honest measure of "how many chances did the operator have to
notice").

## Decisions

- **Reuse `deploy_freshness_status` unmodified.** It already generalizes to arbitrary repo paths;
  no change to `deploy-freshness-lib.sh` is needed or recommended.
- **A durable, git-tracked registry, not a routine filesystem scan, is the primary enumeration
  mechanism.** A scan remains valuable as an occasional `--discover` reconciliation pass, not as
  the thing every invocation of the new report pays for.
- **The reporting command must be explicit and complete (no silent-unless-conclusive collapsing),
  unlike tier 1**, since it is opt-in and its entire value is a full fleet view.
- **No push, ever.** Every recommendation above only reads consumer repos' own
  `.claude-extensions.json` and reports; none proposes redeploying into a consumer. This
  preserves `regeneration-is-manual-only.md`'s explicit architectural decision, which the task
  delegation itself calls out as a do-not-invert constraint.
- **Escalation is visibility-only.** A blocking escalation was considered and rejected in this
  research pass: tier 2 already provides the blocking backstop for this repo's own commits, and a
  cross-repo blocking mechanism has no enforcement lever anyway (this repo cannot compel a
  consumer's own commands to run).

## Risks & Mitigations

- **Declared `file_scope` for this task lists only `check-deploy-freshness.sh`,
  `deploy-headless.sh`, and `regeneration-is-manual-only.md`, but the recommended design needs
  two NEW files** (the registry JSON and `check-consumer-freshness.sh`) plus edits to the three
  declared files. Flagging explicitly for `/plan`: the file_scope will need widening to include
  the new script and registry paths (both under `agent-system/extensions/core/`, consistent with
  the source-store rule), and the doc update belongs in `regeneration-is-manual-only.md`'s
  existing "Detecting When You're Stale" section (extending the two-tier model to a documented
  third piece: the source-side fleet report) plus a pointer in its "Related Documentation" list.
- **Registry staleness is a smaller, bounded version of the same problem this task solves.** A
  forgotten new consumer stays invisible to the primary (non-`--discover`) report path. Mitigated
  by the `--discover` reconciliation mode above; not eliminated, since full elimination would
  require an unbounded routine filesystem scan the task's own framing (cheap, actionable command)
  argues against.
- **Multi-machine consumers are out of scope by design**, inherited from tier 1/2's own
  documented "single-machine" limitation (`source_dir` is an absolute, machine-local path) — not
  a new gap introduced by this design, and not something `/plan` needs to solve.
- **`deploy-headless.sh`'s exit-code contract (0/1/2/3) must not change.** The new consumer report
  is additive output inside the existing success/exit-3 branches; if `check-consumer-freshness.sh`
  itself fails for some reason, it must degrade the same way `check-deploy-freshness.sh` does
  (never propagate a failure into `deploy-headless.sh`'s own exit code), preserving the "verify
  actually landed" semantics exit 3 exists to protect (see
  `regeneration-is-manual-only.md`'s `### deploy-headless.sh's Inline Verification and Exit Code
  3` subsection — the Stage MT-3 step 7 exit-3 ambiguity noted there is unrelated to this task
  and should not be conflated with it).

## Context Extension Recommendations

- **Topic**: cross-repo fleet staleness reporting (the source-side counterpart to the existing
  two-tier single-repo model).
- **Gap**: `context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're Stale"
  section documents tiers 1 and 2 (both scoped to a repo checking *itself*) but has no section
  for a source-repo-initiated fleet view.
- **Recommendation**: once implemented, add a "Tier 3 (fleet-report, source-repo-only, opt-in)"
  subsection to that same file, naming the registry file's path, the new script, and its relation
  to tiers 1/2 — following that document's own established pattern of additive, clearly-labeled
  sections rather than rewriting the existing two-tier description.

## Appendix

- Live measurements taken via `jq` against `.claude-extensions.json` in: this repo,
  `~/Projects/BimodalLogic`, `~/Projects/Logos/{Theory,Hardware}`, `~/Projects/{ModelChecker,
  PersonalWebsite,cslib}`, `~/.dotfiles`, `~/Philosophy/Papers/PossibleWorlds`.
- Consumer discovery performed via `find /home -maxdepth 6 -name .claude-extensions.json`
  cross-checked against `find / -xdev -maxdepth 6 -name .claude-extensions.json` for this pass;
  both agree on the 8-repo set (excluding this repo itself and an unrelated `/tmp` scratch test
  fixture).
- Prior art consulted: `specs/018_detect_stale_claude_deploy_trees/reports/
  01_stale-deploy-detection.md` (root-caused the underlying staleness and designed tiers 1/2,
  finding 5 consumers at that time: `.dotfiles`, `PersonalWebsite`, `cslib`, `BimodalLogic`,
  `ModelChecker` — 3 more have since appeared: `Logos/Theory`, `Logos/Hardware`,
  `Philosophy/Papers/PossibleWorlds`, itself supporting evidence that a scan-only approach misses
  repos that appear between scans while a registry addition is a deliberate, visible act).
