# Research Report: Task #82

**Task**: 82 - wire_deploy_verification_into_deploy_headless
**Started**: 2026-08-24T21:51:35Z
**Completed**: 2026-08-24T21:58:26Z
**Effort**: medium (mechanical wiring + one non-trivial cross-system interaction to resolve)
**Dependencies**: 32 (redeploy_and_remediate_install_once_settings) — status `completed`, not a live blocker
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` (237 lines, read in full)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (564 lines, read in full)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (read in full)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (`### The Inter-Cycle Redeploy Checkpoint` subsection)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage MT-3 step 7 call sites, lines ~1883-1951)
- `agent-system/extensions/core/manifest.json` (confirmed `verify-deploy.sh` is a `core`-provided script)
- Live measurement: `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` timed in this repo
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `deploy-headless.sh:233` currently only *echoes* the verify-deploy command; the fix is
  mechanically small (call `verify-deploy.sh` after a successful deploy, in both the default and
  `--wipe` branches, and propagate a non-zero exit on failure) — but it collides with an existing,
  more sophisticated verification consumer that this task's `file_scope` does **not** include, and
  that collision is the report's central finding.
- `skill-orchestrate`'s Stage MT-3 step 7 (the inter-cycle redeploy checkpoint,
  contract owned by `batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy
  Checkpoint`) already calls `deploy-headless.sh` and `verify-deploy.sh --findings --quiet`
  **separately**, twice (pre- and post-redeploy), specifically so it can distinguish a
  newly-introduced failure (defer remaining tasks) from a pre-existing one (proceed, reported
  loudly — its "branch (c)"). If `deploy-headless.sh` starts hard-failing on *any* verify-deploy
  failure with no baseline awareness of its own, its exit code becomes indistinguishable from a
  genuine deploy failure to that checkpoint's unconditional "branch (a)" — silently destroying
  branch (c) and making the orchestrator defer on every pre-existing (not just newly-introduced)
  condition. `SKILL.md` is out of `file_scope`, so this task cannot fix the consumer side; it can
  only avoid making the collision worse and document it.
- **Live evidence the collision is not hypothetical**: `verify-deploy.sh`'s gate 8 (the shell test
  suite) is failing *right now* in this repo — 3 of 45 discovered test files report failures
  (`test-common-lib.sh`, `test-skill-base-lifecycle.sh`, `test-validate-return-meta.sh`),
  unrelated to task 82's own scope. The instant this task lands, every `deploy-headless.sh`
  invocation will report failure until those are fixed, unless the failure contract accounts for
  pre-existing conditions.
- **Timing**: the shell test suite alone took **117.9s** (`real 1m57.9s`) in a direct, isolated
  timing run — this is the single dominant cost inside the task description's cited ~2.8 min
  total gate wall-clock (≈65-70% of it). The other 11 gates combined cost roughly 50-70s. This
  strongly supports the task description's suggestion to separate "fast gates inline" from "the
  slow suite," especially because the orchestrator's own checkpoint *already* pays the full
  verify-deploy.sh cost twice per critical-path-touching cycle — an unconditional third full
  invocation inside `deploy-headless.sh` would make that checkpoint ~3x as expensive.
- `--dry-run` already exits (line 191) well before reaching the echo/verify site (line 233), in
  both branches — no additional guard is needed there as long as the new call is added inside the
  same trailing block, after the `DEPLOY_COUNT` check succeeds.
- Recommended shape (see Decisions below): add a `--skip-slow` flag to `verify-deploy.sh` that
  skips gate 8 only; have `deploy-headless.sh` call `verify-deploy.sh --skip-slow "$TARGET"`
  inline and exit with a **new, distinct exit code (3)** on failure — never overloading exit 2
  (already documented as "the headless Neovim invocation failed") — so a future SKILL.md change
  can tell "verify failed" apart from "deploy itself failed" without this task having to touch
  SKILL.md.

## Context & Scope

Task 82's stated scope (file_scope): `deploy-headless.sh`, `verify-deploy.sh`,
`regeneration-is-manual-only.md`. It must (a) replace the `echo` at line 233 with a real
invocation, (b) decide and document a failure contract, (c) keep `--dry-run` from invoking
verification, and (d) weigh running fast gates inline vs. deferring the slow test suite. This
report investigates all four, plus the cross-system interaction the task description does not
mention but the code makes unavoidable.

## Findings

### Codebase Patterns

**`deploy-headless.sh` structure** (`agent-system/extensions/core/scripts/deploy-headless.sh`):
- Everything runs inside a single `main()` function invoked as the file's last statement
  (line 237: `main "$@"`), by deliberate design — see the file's own "SELF-OVERWRITE HAZARD"
  comment (lines 46-58): because this script can be invoked as `bash .claude/scripts/deploy-headless.sh`
  from inside the very repo it targets, and the nvim subprocess it launches overwrites this file
  on disk mid-run, `main` must be **fully parsed before any of it executes**. Any new verification
  call must be added **inside** `main()`, never as new top-level code after `main "$@"` — that
  would reintroduce the exact hazard this structure exists to prevent.
- `--dry-run` returns via `exit 0` at line 191, entirely before the nvim deploy call and before
  the current echo at line 233. Both the default and `--wipe` branches converge on the same
  shared trailing block (lines 228-234) after the `DEPLOY_COUNT`/error checks — this is the single
  correct insertion point for a real verify call, and it automatically inherits the `--dry-run`
  exclusion for free.
- Documented exit codes (lines 65-69): `0` deploy completed, `1` usage error/not-a-repo/no-nvim,
  `2` headless nvim invocation failed or produced no result (or, `--wipe` only, the pre-wipe
  snapshot was refused). **`2` is already claimed** — a new verification-failure exit code must
  not reuse it, or a caller keying off exit 2 (there are none today, but the doc contract exists)
  would conflate "nvim failed" with "verify-deploy failed."
- `TARGET` is resolved to an absolute path (`TARGET="$(cd "$TARGET" && pwd)"`, line 116) before
  the nvim call, but the `cd "$TARGET" && nvim ...` invocation runs inside a `$(...)` subshell
  (lines 203-209) — it does **not** change `main`'s own working directory. A new verify call must
  pass `"$TARGET"` explicitly as `verify-deploy.sh`'s positional arg rather than relying on
  ambient `pwd`.
- Confirmed via `manifest.json:216`, `verify-deploy.sh` is a `core`-provided script, and the
  default (non-`--wipe`) path force-loads `core` before `resync_all` (lines 207-209) — so by the
  time the trailing block runs, `.claude/scripts/verify-deploy.sh` is guaranteed to exist at
  `$TARGET`, even on a from-scratch bootstrap. No chicken-and-egg ordering problem.

**`verify-deploy.sh` structure** (`agent-system/extensions/core/scripts/verify-deploy.sh`):
- 12 gates (gate1-gate12; the file's own header comment, lines 33-43, is stale — it says "eleven
  gates gate0 through gate10," but gate12 (state-writer boundary lint) was added later and the
  code runs through gate12). Exit codes: `0` all passed, `1` one or more checks failed, `2`
  cannot run (missing target / no deploy tree) — the script's own comment (line 29-31) already
  mandates that callers treat exit 2 the same as exit 1, never as a pass.
- `--quiet` suppresses `[PASS]` narrative lines (via the `say()` wrapper) but never suppresses
  `[FAIL]` lines or the final summary. `--findings` additionally emits normalized `FINDING gateN
  ...` lines after the summary, designed for line-level set-diffing (this is exactly the mechanism
  `skill-orchestrate`'s baseline comparison already consumes — see below).
- Gates 3-4, 6-7, 9, 11-12 are `[SKIP]`-gated on `$TARGET/agent-system/extensions` existing — they
  only run in the source-store repo, not a deploy consumer. Gate 8 (shell test suite) and gate 5
  (verify.lua manifest parity) share the same skip gate. Gate 1 (event/error-store files present)
  and gate 2 (hook registrations in settings.json) run unconditionally, in every target. Gate 10
  (state schema validation) additionally requires `specs/state.json` to exist.
- **No existing flag selects a subset of gates.** Adding fast/slow selectivity requires new work
  in `verify-deploy.sh` itself (in scope per `file_scope`), most naturally a new flag (e.g.
  `--skip-slow`) gating gate 8's block (lines ~392-412 in the read copy) the same way the
  source-store-vs-deploy-consumer checks already gate their own blocks.

**Live timing measurement** (this repo, this session):
```
time bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet
real  1m57.946s   user 1m45.929s   sys 0m49.460s
```
Output: `42 passed, 3 failed, 0 skipped, 45 total`. The 3 failing suites
(`test-common-lib.sh` — a single-source assertion; `test-skill-base-lifecycle.sh`;
`test-validate-return-meta.sh` — a `--fix` roundtrip case) are **pre-existing and unrelated to
task 82's scope**. This means `verify-deploy.sh`'s gate 8, and therefore the whole script, is
failing in this repo *right now*, independent of anything this task changes.

**`check-runtime-file-tracking.sh`** — mentioned in the task description as another orphaned
check ("has no caller anywhere in the repo") — is confirmed orphaned (only a manifest declaration
at `manifest.json:98` and doc references; grep for callers in scripts/hooks turns up nothing) but
is **not** one of `verify-deploy.sh`'s 12 gates and is **not** in this task's `file_scope`. It is
background evidence for the task's framing ("checks sit disconnected"), not an action item here.

### The Cross-System Interaction (central finding)

`skill-orchestrate`'s Stage MT-3 step 7 (`SKILL.md` lines ~1883-1951) already wires
`deploy-headless.sh` and `verify-deploy.sh` together, but as **two independent calls it
orchestrates itself**, not as one call delegating to the other:

```
PRE_RAW=$(bash .claude/scripts/verify-deploy.sh --findings --quiet)   # baseline, before redeploy
bash .claude/scripts/deploy-headless.sh                               # the redeploy itself
POST_RAW=$(bash .claude/scripts/verify-deploy.sh --findings --quiet)  # baseline, after redeploy
```

The documented failure contract (`batch-orchestration-guardrails.md`, `### The Inter-Cycle
Redeploy Checkpoint`, "Failure contract" subsection) has three branches:
- **(a)** `deploy-headless.sh` itself fails (non-zero exit) → defer all remaining tasks,
  **unconditionally, with no baseline consultation whatsoever**.
- **(b)** `verify-deploy.sh` fails post-redeploy with at least one *newly introduced* finding
  vs. the pre-redeploy baseline → defer.
- **(c)** `verify-deploy.sh` fails post-redeploy but every finding was *already present* in the
  pre-redeploy baseline → **proceed to the next cycle**, reported loudly as a known pre-existing
  condition. The document is explicit that this third state exists specifically so a pre-existing
  failure does not silently block indefinitely, and that "a baseline must never become a mechanism
  for quietly swallowing failures" cuts the other way too — it must not manufacture new blocking
  either.

If `deploy-headless.sh` is changed to exit non-zero whenever the deployed tree fails *any*
verify-deploy gate — which is what the task's ACCEPTANCE section asks for ("a deploy that leaves
the tree failing any verify-deploy gate reports that fact in its own output, non-zero") — then
every call site in Stage MT-3 step 7 hits **branch (a)**, unconditionally, on *every* cycle for as
long as any gate is red (which, per the live measurement above, is true today). Branch (c)'s
entire purpose — tolerating a known pre-existing failure and proceeding — becomes unreachable for
any cycle that touches a critical path, because `deploy-headless.sh`'s own exit code no longer
distinguishes "verify-deploy is newly broken" from "verify-deploy was already broken." This is a
real behavior regression to an existing, carefully-designed, already-shipped mechanism, not a
hypothetical edge case — and it is currently *live* (see the 3 failing test suites above).

`SKILL.md` and `batch-orchestration-guardrails.md` are **not** in task 82's `file_scope`, so this
task cannot itself teach the orchestrator's step 7 to reconcile the two. What it *can* do is avoid
foreclosing that reconciliation:

- Give the new verification-failure exit path in `deploy-headless.sh` a **distinct exit code**
  (not `2`, which is already "nvim invocation failed") — e.g. `3`. A future, separately-scoped
  task can then teach Stage MT-3 step 7 to treat exit 3 specifically as "deploy succeeded but
  verify-deploy failed" and route it through the *same* baseline-comparison logic branch (b)/(c)
  already use, rather than the unconditional branch (a) — cheaply, because the discriminator
  (a distinct exit code) already exists once this task lands.
- Document the interaction explicitly in `regeneration-is-manual-only.md` (in `file_scope`) so a
  future reader of either file finds the cross-reference, mirroring that document's own existing
  pattern of narrating what a change does and does not license (see its `## Automated Exception`
  section, which already carries this exact "narrow, don't silently rewrite" style).
- Flag, for whoever plans/implements this task, that landing it as specified will make Stage MT-3
  step 7 defer more eagerly than before until a follow-up task closes the gap above — this is a
  real, disclosed trade-off, not a silent regression, provided it's written down.

### Failure Contract Design Options

The task description frames this as "does a failing verify fail the deploy, or warn loudly and
exit non-zero?" — phrased as if these were alternatives, but the ACCEPTANCE section already
resolves it: the deploy must "report that fact in its own output, non-zero." So the open design
question is not *whether* to fail, but *which exit code* and *what exactly counts as failure*:

| Option | Description | Trade-off |
|---|---|---|
| **A. Overload exit 2** | Reuse the existing "nvim invocation failed" code | Rejected — conflates two distinguishable failure modes; a caller (including a future SKILL.md fix per the finding above) cannot tell "the deploy didn't happen" from "the deploy happened but the tree fails verification." |
| **B. New exit code (recommended)** | e.g. exit `3` for "deploy succeeded, verify-deploy failed" | Preserves today's exit-code semantics for existing callers (nothing currently branches on 2 vs. 3, so this is purely additive) and gives a future reconciliation task a clean discriminator. Requires updating the exit-codes doc comment (lines 65-69). |
| **C. Warn-only, always exit 0** | Print the verify-deploy failure but never fail the deploy's own exit code | Rejected — directly contradicts the ACCEPTANCE section, and reproduces exactly the "reachable only by a human" problem the task exists to fix (an agent or CI step checking `$?` alone would see success). |

### Fast-Gates-Inline vs. Deferring the Slow Suite

| Option | Description | Trade-off |
|---|---|---|
| **A. Always run the full 12-gate `verify-deploy.sh` inline** | Simplest; no new flag needed | Adds ~2.8 min to every `deploy-headless.sh` invocation. Given Stage MT-3 step 7 already pays this cost twice per critical-path cycle, this makes that checkpoint ~3x as expensive (≈8.4 min) — directly working against the task description's own concern ("a slow deploy is a deploy that gets skipped"). |
| **B. Skip gate 8 (the shell test suite) inline; document that the full suite is still available via a plain `verify-deploy.sh` run** (recommended) | Add a `--skip-slow` flag to `verify-deploy.sh` (gating gate 8's block the same way the existing source-store-vs-deploy-consumer skip pattern already does); `deploy-headless.sh` calls `verify-deploy.sh --skip-slow "$TARGET"` | Keeps the inline cost to roughly 50-70s (measured: 12-gate total ≈2.8min minus gate 8's measured 117.9s), while still catching 11 of 12 gates automatically — including the exact "doc-lint failures 4→16" and "index-entries line_count drift" regressions the task's own motivating incident named, both of which are doc-lint (gate 3), not the test suite. The shell test suite remains reachable, just not gating the fast common-case deploy path. |
| **C. Run the full suite, but asynchronously/in background** | Deploy exits before verification completes | Rejected — cannot satisfy the ACCEPTANCE section's synchronous "non-zero" requirement; a background process can't retroactively change an already-exited process's exit code without additional polling machinery not asked for here. |

Option B is the report's recommendation: it directly answers the task description's own framing
("Consider running only the fast gates inline and deferring the 100s test suite"), is backed by
the live timing measurement, and is proportionate to the orchestrator double-invocation concern
identified above.

## Decisions

These are research recommendations for the planning phase, not commitments — planning should
weigh them but is not bound by them:

1. Insert the real `verify-deploy.sh` call inside `main()`, in the shared trailing block after
   the `DEPLOY_COUNT` success check (after line 232, replacing/augmenting line 233), so both the
   default and `--wipe` branches get it and `--dry-run` is excluded for free by existing control
   flow. Do not move any code to top-level (self-overwrite hazard).
2. Pass `"$TARGET"` explicitly to `verify-deploy.sh` — do not rely on ambient `pwd`.
3. Add a `--skip-slow` flag to `verify-deploy.sh` that skips gate 8 only, and have
   `deploy-headless.sh`'s inline call use it. Leave a plain `verify-deploy.sh` invocation
   (no flag) as the full, human-run gate — matching the existing echo's original intent — still
   reachable via the same message deploy-headless.sh already prints (adjusted to mention the
   fast-vs-full distinction).
4. On verify-deploy.sh failure, `deploy-headless.sh` exits with a new, distinct code (recommend
   `3`), never overloading exit `2`. Update the exit-codes doc comment (lines 65-69).
5. Document, in `regeneration-is-manual-only.md`, the Stage MT-3 step 7 interaction found above:
   that this change makes `deploy-headless.sh`'s own exit code no longer distinguish "deploy
   failed" from "deploy succeeded but tree fails verification," and that until a follow-up task
   teaches the orchestrator's checkpoint to special-case the new exit code through its existing
   baseline logic, every critical-path-touching cycle will defer more eagerly (branch (a)) than
   before whenever any verify-deploy gate is already red. This should be flagged loudly to
   whoever plans/implements this task, since `SKILL.md` is out of `file_scope` here.
6. Before/alongside landing this task, note that `verify-deploy.sh` gate 8 is *currently* red in
   this repo (3 pre-existing, unrelated test failures) — landing task 82 as specified will make
   every deploy-headless.sh run report failure until those are fixed, which is arguably correct
   (surfacing a truth that was previously invisible) but should not surprise whoever lands it.

## Risks & Mitigations

- **Risk**: naive "always fail on any verify-deploy finding" regresses Stage MT-3 step 7's
  pre-existing-failure tolerance (branch (c)), causing the orchestrator to defer far more often
  than today. **Mitigation**: distinct exit code (Decision 4) plus explicit documentation
  (Decision 5), so the gap is disclosed and cheaply closeable by a follow-up task rather than
  silently discovered in production.
- **Risk**: running the full 12-gate suite inline triples the orchestrator's already-paid
  verify-deploy cost per critical-path cycle. **Mitigation**: `--skip-slow` (Decision 3),
  backed by the 117.9s live measurement showing gate 8 is the dominant cost.
- **Risk**: landing this fix while gate 8 is already red (live, confirmed) makes every deploy
  report failure immediately. **Mitigation**: call this out explicitly (Decision 6) rather than
  treating it as a surprise; it is the intended behavior, not a bug in this task's own change.
- **Risk**: adding code at the wrong place in `deploy-headless.sh` (e.g., outside `main()`, or
  before the `DEPLOY_COUNT` check) could reintroduce the self-overwrite hazard the file's own
  header comment (lines 46-58) exists to prevent. **Mitigation**: Decision 1's explicit insertion
  point, inside `main()`, after the existing success checks.

## Context Extension Recommendations

None. `regeneration-is-manual-only.md` and `batch-orchestration-guardrails.md` already document
the relevant mechanisms in detail; this task's own file_scope includes the one file
(`regeneration-is-manual-only.md`) that needs a new subsection recording the interaction above,
which is Decision 5, not a gap in existing context architecture.

## Appendix

**Commands run**:
```
jq/python3 queries against specs/state.json for project_number 82 and 32
wc -l / diff on .claude/scripts/deploy-headless.sh vs agent-system/extensions/core/scripts/deploy-headless.sh (identical)
cat -n on both deploy-headless.sh and verify-deploy.sh (full read)
grep -n "Inter-Cycle Redeploy Checkpoint" -A 80 batch-orchestration-guardrails.md
grep -n "deploy-headless.sh\|verify-deploy.sh" skill-orchestrate/SKILL.md
grep -n "verify-deploy" manifest.json
time bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet
grep -n "check-runtime-file-tracking" -r agent-system/extensions/core/
```

**Key file:line references**:
- `agent-system/extensions/core/scripts/deploy-headless.sh:46-58` (self-overwrite hazard)
- `agent-system/extensions/core/scripts/deploy-headless.sh:65-69` (exit code doc)
- `agent-system/extensions/core/scripts/deploy-headless.sh:176-192` (`--dry-run` early exit)
- `agent-system/extensions/core/scripts/deploy-headless.sh:228-234` (shared trailing block, insertion point)
- `agent-system/extensions/core/scripts/verify-deploy.sh:26-43` (usage/exit codes/findings-mode header)
- `agent-system/extensions/core/scripts/verify-deploy.sh:392-412` (gate 8, shell test suite)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md:398-516` (Inter-Cycle Redeploy Checkpoint, full contract)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1883-1951` (the two separate call sites)
