# Regeneration: Interactive by Default, Headless When Driven Deliberately

## Overview

The `<leader>al` picker's `[Reload All]` (non-destructive force-resync) and `[Regenerate]`
(destructive wipe + rebuild) entries are the primary interactive mechanism that deploys the
extension source store (`agent-system/extensions/**`) into a consuming repo's gitignored
`.claude/` tree. Every deployed file under `.claude/` has a source under
`agent-system/extensions/**`; nothing under `.claude/` is hand-authored. Both entries -- and the
headless path below -- are backed by the same single manifest-driven engine
(`neotex.plugins.ai.shared.extensions`'s `manager.resync_all`/`manager.wipe`); there is no second,
independent sync mechanism to keep in sync with this one.

**CORRECTION.** An earlier revision of this document asserted that regeneration had *no*
headless, scripted, or CI equivalent, and instructed future work not to retread the question.
**That assertion was wrong, and it was load-bearing** -- it propagated into research findings,
implementation plans, and user-facing handoffs, each of which concluded that deployment could
only ever be a manual, user-owned step. A headless path exists, is straightforward, and is now
implemented as `scripts/deploy-headless.sh`.

## The Headless Path (verified)

`scripts/deploy-headless.sh` calls the manifest-driven engine's `manager` functions directly with
an explicit `confirm = false` option, rather than stubbing `vim.fn.confirm()` in front of an
interactive-only entry point (the technique this section originally documented, back when the
only bulk-sync engine was the picker-only, confirm-dialog-gated `load_all_globally`). That engine
has since been retired: the picker's `[Reload All]`/`[Regenerate]` entries and this script are
both direct `manager` callers now, with no confirm-stubbing indirection involved on either path.

```bash
# Default: bootstrap-safe, non-destructive force-resync of every active extension
bash scripts/deploy-headless.sh [TARGET_REPO]

# Full destructive wipe + rebuild (snapshot -> rm -rf .claude -> regenerate -> restore)
bash scripts/deploy-headless.sh --wipe [TARGET_REPO]
```

This was verified against a from-scratch scratch git repository: a fresh (no prior `.claude/`)
default-mode deploy correctly reconstructs the full tree, including subdirectory-declared
`provides.scripts`/`provides.hooks` entries -- the exact class of entry the retired engine
silently dropped on both a fresh deploy and a resync alike (see
`scripts/tests/test-deploy-propagation.sh`, whose Assertions A and B guard against a regression
of this exact defect). `--wipe` was verified to survive `settings.local.json` and every
`.syncprotect`-listed path **semantically** across the deletion -- value-for-value identical
under `jq -S`, with key/array reordering observed at the byte level in every sampled pair. See
`### Round-Trip Fidelity of settings.local.json (measured)` below for the full measurement.

Use `scripts/deploy-headless.sh` rather than open-coding an equivalent `manager` call -- it
resolves the repo root, refuses to run outside a git repository, holds the `specs/.deploy-lock`
mutex, and reports the artifact/extension count it deployed.

## When to Prefer Which

- **The interactive picker's `[Reload All]`/`[Regenerate]` entries** remain the right default for
  a human at a terminal. `[Regenerate]` (the destructive path) is gated behind a `vim.fn.confirm`
  yes/no dialog -- a genuine safeguard, since it deletes and rebuilds `.claude/` from scratch.
  `[Reload All]` (non-destructive) is gated behind its own submenu choice
  ("Reload All"/"Unload All"/"Step Through"/"Cancel") rather than a yes/no dialog, matching its
  lower-risk, non-destructive intent while still requiring an explicit selection.
- **`scripts/deploy-headless.sh`** is for scripted, CI, and agent-driven contexts where no human
  is present to answer a dialog. Its `--wipe` flag deliberately bypasses the interactive
  confirmation `[Regenerate]` would otherwise show, so it must be invoked explicitly and never as
  a silent side effect of an unrelated operation.

## Automated Exception: The Inter-Cycle Self-Modification Checkpoint

The sentence directly above -- `scripts/deploy-headless.sh` "must be invoked explicitly and never
as a silent side effect of an unrelated operation" -- is left byte-for-byte intact by this
subsection. It is not edited, weakened, or reworded here, matching this document's own
established correction-as-addition pattern (see the `**CORRECTION.**` block above): a constraint
that is no longer fully true is narrowed by a labeled, additive exception, never quietly rewritten
in place.

**The exact and only sanctioned automated call site**: `skill-orchestrate`'s Stage MT-3 step 7 --
the inter-cycle redeploy checkpoint. No other automated caller is sanctioned by this subsection.

**Why this is not a side effect of an unrelated operation**: the fix that triggers the checkpoint
is precisely the fix the checkpoint exists to make live. A dispatched task's commit at Stage MT-4
step 5.5 touching an orchestrator-critical path is the operation the redeploy is *for*, not an
operation the redeploy is merely alongside. The operation is not unrelated -- it is the operation
being corrected.

**Why this is not silent**: the checkpoint logs on fire (naming the matched critical paths it
detected), on success (naming the deployed artifact count and the `verify-deploy` pass), and on
failure (naming the failing gate and its exit code). An operator reading the run's output can
always distinguish "the checkpoint did not fire" from "it fired and passed" from "it fired and
failed."

**Why this is bounded**: the checkpoint is evidence-gated on actual `modified_files` overlapping a
declared critical path -- never an unconditional "always between cycles" trigger. It fires at most
once per critical path per invocation, via the idempotence guard. Any failure of either gate defers
the remainder of the invocation rather than proceeding past an unverified deploy.

**What this carve-out explicitly does NOT license**: no other automated caller may invoke
`scripts/deploy-headless.sh` without its own equivalent exception recorded in this same section. A
future reader must not read this subsection as general precedent for scripted deploys elsewhere in
the system -- it licenses exactly the one call site named above, nothing broader.

The full trigger, failure contract, sequencing, and idempotence-guard contract is recorded once,
authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s
`### The Inter-Cycle Redeploy Checkpoint` subsection. It is cross-referenced here, not restated.

## Automated Exception: The Postflight Completion-Deploy Gate

Additive to the deliberate-invocation sentence above, in the same shape as the Inter-Cycle
Self-Modification Checkpoint exception immediately above -- neither of those two constraints is
edited, weakened, or reworded here. This is the second and, as of this writing, LAST exception
this section records.

**The exact and only sanctioned automated call sites**: `scripts/command-gate-out.sh`'s
`rc == 6` branch (the single-task `/implement` completion path -- a point with no concurrency,
since it runs once per task after that task's own dispatch has already returned), and
`commands/implement.md` Step 4's batch-refusal trigger (the multi-task `/implement` completion
path -- already serial, since it runs once, after all of Step 3's parallel dispatches have
returned). No other automated caller is sanctioned by this subsection.

An explicit non-exception, named so a later pass does not go looking for one:
`skill-orchestrate`'s Stage MT-3 step 7 is UNTOUCHED by this mechanism and needs no new exception
here -- it remains covered exclusively by the Inter-Cycle Self-Modification Checkpoint exception
above. A task refused by the postflight completion-deploy gate under `/orchestrate` defers loudly
(via the `deploy_pending` marker `skill_postflight_update` records into its `.return-meta.json`)
rather than being redeployed by a THIRD trigger site; widening Stage MT-3 step 7's own predicate
is the proper fix for that residual and is named as follow-up work in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight Completion-Deploy
Gate` subsection, not attempted here.

**Why this is not a side effect of an unrelated operation**: exactly as the exception above
argues for its own single call site, the fix that triggers each of these two redeploys is
precisely the fix each redeploy exists to make live -- a task whose OWN commit touched
`agent-system/extensions/**` is the operation these two sites correct, not an operation they run
alongside.

**Why this is not silent**: each call site logs on fire (naming the refusing task number and,
for the single-task path, the specific matched `agent-system/extensions/**` path(s)), on success
(naming the deployed extension count and the verify-deploy outcome), and on failure (naming the
failing branch -- (a) deploy did not land, (b) a new finding, or (c) pre-existing findings only --
and the relevant exit code). An operator reading either call site's output can always distinguish
"the gate did not fire" from "it fired and the redeploy succeeded" from "it fired and the redeploy
failed."

**Why this is bounded**: both sites are evidence-gated on the SAME check-only backstop inside
`scripts/update-task-status.sh` observing an actual `modified_files`-to-`agent-system/extensions/**`
overlap AND provable staleness -- never an unconditional "always redeploy" trigger. Each site
fires at most once per its own invocation (a gate-out call for the single-task path; a Step 4 run
for the multi-task batch path) and re-attempts the refused transition(s) at most once after a
successful redeploy; a second refusal after that redeploy is a real signal, surfaced loudly, never
retried again within the same invocation.

**What this carve-out explicitly does NOT license**: identical in force to the exception above --
no other automated caller may invoke `scripts/deploy-headless.sh` without its own equivalent
exception recorded in this same section. This subsection licenses exactly the two call sites named
above, nothing broader, and is **not precedent**: a future automated caller, including any future
widening of `skill-orchestrate`'s own trigger, still needs its own exception recorded here.

The full trigger predicate, the check-only contract, the conclusiveness convention, exit 6's
ordering-constraint semantics, and the shared (a)/(b)/(c) baseline contract are recorded once,
authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight
Completion-Deploy Gate` subsection. It is cross-referenced here, not restated.

### `deploy-headless.sh`'s Inline Verification and Exit Code 3

Narrow, don't silently rewrite: the correction below is additive to this subsection's own
contract above, the same way this subsection was additive to the deliberate-invocation sentence
it narrows. Prior to this correction, `deploy-headless.sh` ended every non-dry-run invocation by
*echoing* `verify-deploy.sh`'s invocation command rather than running it -- reachable only by a
human typing the command by hand. `deploy-headless.sh` now runs
`verify-deploy.sh --skip-slow "$TARGET"` inline, in `main()`'s shared trailing block, on every
non-dry-run deploy (both the default resync branch and `--wipe`), with its output streamed
directly to the caller.

**The exit-code contract.** A non-dry-run `deploy-headless.sh` now exits `3` -- distinct from `1`
(usage error) and `2` (the headless nvim invocation failed, or `--wipe`'s pre-wipe snapshot was
refused) -- when the deploy itself landed but the inline verification run reported one or more
failures. Exit 3 means the tree WAS modified, unlike 1 and 2. `--dry-run` never reaches
verification at all: it returns 0 at its own earlier branch, before the trailing block that calls
`verify-deploy.sh` runs.

**The fast/full gate split.** The inline call passes `--skip-slow`, a `verify-deploy.sh` flag
that skips gate 8 (the shell test suite runner, `tests/run-all.sh`) only -- every other gate still
runs. Gate 8 alone was measured at 117.9s of the script's ~2.8min total run, so `--skip-slow`
drops the inline cost to roughly 50-70s. The full gate set, including gate 8, remains available on
demand by running `verify-deploy.sh` with no flag -- `deploy-headless.sh`'s exit-3 failure message
names that exact command.

**The Stage MT-3 step 7 collision.** `skill-orchestrate/SKILL.md`'s deploy-failure branch is
written as "Non-zero exit (1 or 2) -> defer unconditionally ... with NO baseline consultation
whatsoever". Exit 3 sits outside that parenthetical enumeration but inside the leading "Non-zero
exit" phrase, so the step's behavior on exit 3 is currently ambiguous, and the most likely reading
routes it through the unconditional-defer branch -- bypassing the pre/post `--findings` baseline
comparison the checkpoint's other branches exist to consult. The consequence: a pre-existing
failure that baseline comparison is designed to tolerate would instead defer every remaining task,
every cycle. A distinct exit code was chosen specifically so a follow-up task can route exit 3
through the existing baseline-comparison branches with a small, targeted edit rather than a
redesign; that follow-up is not done by this correction. It would touch
`skills/skill-orchestrate/SKILL.md` and `context/patterns/batch-orchestration-guardrails.md`,
neither of which this correction modifies.

**The live consequence, disclosed rather than discovered in production.** As of this correction,
doc-lint (gate 3, a *fast* gate -- `--skip-slow` does not hide it) reports pre-existing issues in
this repo's own source store, and gate 8 (deferred inline, but not by a full `verify-deploy.sh`
run) has pre-existing failing suites. Both predate this correction and are unrelated to it. The
practical effect: every `deploy-headless.sh` invocation exits 3 until those pre-existing failures
are fixed. That is the intended behavior -- surfacing a previously-invisible condition is the
whole point of wiring verification in -- not a regression introduced here. The sanctioned interim
response, until the pre-existing failures are fixed, is to inspect the named failure and fix it;
reverting the inline call is not the sanctioned response merely because it now reports truthfully.

## What This Means for Automation

- **Source-store edits still do not deploy themselves.** Edits under
  `agent-system/extensions/**` are the durable, version-controlled truth; the deployed `.claude/`
  tree reflects them only after a regeneration -- interactive or headless -- actually runs.
- **A stale deployed tree remains an expected state**, and doc-lint's core deploy-drift lane
  (`check-extension-docs.sh`) surfaces it. What has changed is the remedy: drift is now
  resolvable by a script, not only by a human at a keyboard.
- **Verifying deployed behavior still takes two gates**: the regeneration, then real usage for
  anything hook-driven. Inspecting source-store code alone never establishes either. Use
  `scripts/verify-deploy.sh` for the first gate; the second requires actual command invocations.

## Detecting When You're Stale

The staleness described throughout this document was never a loader defect. `loader.lua`'s
`copy_category` force-overwrites every declared file on every load; `installed_files` is
write-only bookkeeping that no code path ever consults as a copy gate; `manager.resync_all` calls
`manager.load(force = true)` with zero diffing. Regeneration is deliberately pull-only by design
-- a consuming repo's `.claude/` tree freezes at its last manual reload with no ambient signal
when the source store moves on. What follows is the detection half that closes that silence,
without touching the copy engine at all.

**The write side.** `state.lua`'s `mark_loaded` (the single writer of every
`.claude-extensions.json` entry, called from `init.lua`'s `manager.load`) stamps a
`source_git_head` field alongside the pre-existing `source_dir` field on every load. The value is
the path-scoped source-store revision -- `git -C <source_dir> rev-parse --show-toplevel`, then
`git log -1 --format=%H -- <source_dir>` against that toplevel -- never the source-store repo's
whole `HEAD`. Path-scoping is deliberate: it prevents unrelated churn elsewhere in the source
store from firing a false warning for an extension whose own files haven't moved.

**The read side.** `scripts/check-deploy-freshness.sh` is a small, standalone, always-`exit 0`
script invoked non-blockingly from `command-gate-in.sh`'s `gate_in` (CHECKPOINT 1, the one path
every ordinary command already crosses), guarded on the deployed checker's own existence so a
tree too stale to carry it yet is a silent no-op. For each extension entry carrying both fields,
it recomputes the same path-scoped revision and, on mismatch, prints one WARN line to stderr
naming the stale extension and the regeneration remedy (`deploy-headless.sh`, or the picker's
`[Reload All]`/`[Regenerate]`), plus a pointer to `verify-deploy.sh --findings` for per-file
detail. It never blocks, aborts, retries, or auto-redeploys anything.

**Why silence, not a "cannot verify" notice, is correct.** The checker prints nothing at all --
not even a summary line -- in every case where staleness cannot be established: a missing
`source_git_head` (every deploy from before this fix), a `source_dir` that no longer exists or
sits outside any git repository, or a recomputed revision that comes back empty. "Unknown" must
never read as either "confirmed fresh" or an alarm; a notice for the unverifiable case would
train users to distinguish two silences by memory, which is worse than one silence.

**Limitations, by design.** The signal is commit-granular, not per-file: a deploy taken from a
dirty source-store working tree stays technically "fresh" by this check even after that dirty
edit is later committed and its `HEAD` moves on, until the next reload restamps it. It is also
single-machine: `source_dir` is an absolute, machine-local path, so a relocated checkout or a
foreign machine's source store falls into the same "cannot verify, stay silent" branch as a
missing field. Neither limitation is a defect to fix here -- `verify-deploy.sh`'s eleven
content-diffing gates remain the deep-dive companion for per-file drift; this check is the
preflight-cheap companion that tells a user regeneration is worth running at all.

**A now-two-tier staleness model.** `check-deploy-freshness.sh` is TIER 1: silent, advisory,
CHECKPOINT-1-only (its one sanctioned advisory caller, `command-gate-in.sh`), ALWAYS exits 0,
and is never a gate -- everything described in this section above. TIER 2 is the postflight
completion-deploy gate inside `scripts/update-task-status.sh` (the "## Automated Exception: The
Postflight Completion-Deploy Gate" subsection above): BLOCKING, evidence-gated on a task's own
`modified_files` actually overlapping `agent-system/extensions/**`, and reachable only at
postflight/`implement` time. Both tiers share ONE comparison algorithm, factored into
`scripts/lib/deploy-freshness-lib.sh` -- tier 1 sources its `deploy_freshness_stale_names`
function, tier 2 sources its `deploy_freshness_status` function -- so "is the deploy stale" is
computed exactly once, not reimplemented per tier. Tier 1's always-exit-0 contract must never be
mistaken for a gate; tier 2 is the gate.

## Merge Semantics That Regeneration Cannot Fix

Two deploy behaviors are structural and survive any number of regenerations:

- **Install-once root files.** `settings.json` and `settings.local.json` are listed in
  `INSTALL_ONCE_ROOT_FILES`; the `root_files` category's descriptor-driven copier
  (`loader.lua`'s `M.copy_category`, keyed by `CATEGORY_DESCRIPTORS.root_files.install_once`)
  skips them entirely once the target exists. Anything added only to `root-files/settings.json`
  can therefore never reach an already-initialized repo. Additions intended for existing repos
  belong in `merge-sources/settings-hooks.json`, which is what the merge step actually reads.
- **Add-only, object-granularity dedup.** The merge compares whole matcher objects via
  `vim.deep_equal` and only declines to add -- it never removes. A duplicate command entry
  already present in a deployed tree survives every future merge and requires manual removal.
  Fresh trees are unaffected: a first-time deploy produces exactly one entry.

The practical consequence for authors: register each new hook as its **own dedicated
single-command matcher object**. That shape is idempotent across re-merges, whereas appending a
command into an existing shared matcher makes that object non-equal to the source and causes its
siblings to be registered twice.

### Round-Trip Fidelity of settings.local.json (measured)

A prior single observation recorded a content-lossy `--wipe` merge: a dropped `hooks.PreToolUse`
block and a dropped `mcpServers` block. Two independent re-check rounds have since measured the
round-trip fidelity of `settings.local.json` across `--wipe` empirically, rather than relying on
the code-reading claim this document previously asserted.

**Measurement**: 24 `--wipe` invocations across 12 wipe-pairs, run against an isolated scratch
copy of the repository (never the live deploy tree) in the most recent round, plus 3 pairs from
an earlier round -- **15 pairs cumulative**. Each pair was compared three ways: semantic equality
(`jq -S`, recursively sorted keys, then hashed), an explicit structural presence check on
`hooks.PreToolUse`, `hooks.Stop`, `mcpServers`, `permissions.allow`, `permissions.deny`, and
`enabledMcpjsonServers` (validated against a positive control -- synthetic deletion of
`hooks.PreToolUse` and `mcpServers` -- before its "0 dropped" result was trusted), and spot-check
raw byte diffs.

**Result**: 0 of 15 cumulative pairs showed any dropped key, array element, or block. Every
observed difference across all pairs was pure key/array **reordering**, attributable to Lua
`pairs()` iteration nondeterminism across process runs -- semantically identical under `jq -S`,
never byte-identical. The most recent round additionally varied the pre-existing
`settings.local.json` state across six variants (baseline, extra permissions, reversed/scrambled
key order, ~2.5x bloated content, a minimal file stripped to only `hooks` and `mcpServers`, and a
pre-seeded duplicate `PreToolUse` matcher block deliberately exercising the matcher-merge/dedup
code path) and found no correlation between pre-existing state and loss.

**Candidate root cause for the original observation**: commit `1692e33e8` moved the settings
snapshot restoration in `manager.regenerate` to run *before* the extension reload loop; the
pre-fix ordering (restore-after-load) would produce exactly the observed failure shape by letting
the reload loop's own settings-fragment merges get clobbered by a later restore. The measured
sampling above ran entirely against the post-fix code, and its 0/15 result is consistent with
that fix being effective.

**Known limitation**: all sampling was strictly serial, against an idle target, in a single
process. The `specs/.deploy-lock` mutex `--wipe` and non-destructive regeneration both acquire is
fail-open/non-blocking by design (the same acquire/warn-and-proceed shape as
`specs/.commit-lock`) -- see `deploy-headless.sh` and
`context/patterns/batch-orchestration-guardrails.md`, which already document that a genuinely
concurrent `--wipe` "could corrupt the `.claude/` tree." A `--wipe` racing another `--wipe`, or a
`--wipe` racing a concurrent hand-edit of `settings.local.json`, on the same target is **outside**
what this measurement covers, and remains an untested, narrower hypothesis distinct from the
plain-repeated-wipe question this measurement answers.

Full methodology, per-pair results, and the positive-control validation are recorded in the
originating research report,
`specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`.

## Root-Resolution Guard for Core Scripts

Any core script under `agent-system/extensions/core/scripts/` that resolves its repo root as
`"$(cd "${SCRIPT_DIR}/../.." && pwd)"` is correct ONLY once deployed (`.claude/scripts/` or
`.opencode/scripts/`, two levels under the repo root). Run from the source store, the same
expression silently resolves to `agent-system/extensions/` and proceeds against a bogus root.
Every such script MUST source the shared guard immediately after that root computation:
`. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` -- the trailing `|| exit 1` is required
because several core scripts do not use `set -e`, so a bare `source` of a missing/failing
helper would otherwise print an error and continue unguarded. `deploy-root-guard.sh` validates
its own `BASH_SOURCE[0]` location structurally (no filesystem I/O) against exactly two accepted
deploy-tree grandparents, `.claude` and `.opencode` -- never hardcode just one. Do NOT use
`git rev-parse --show-toplevel` as a substitute: it would silently succeed by finding the true
repo root, masking the invocation-context error this guard exists to surface.

## Related Documentation

- `scripts/deploy-headless.sh` -- scripted regeneration for non-interactive contexts
- `scripts/verify-deploy.sh` -- checks a deployed tree against its source store
- `scripts/check-deploy-freshness.sh` -- the non-blocking staleness check documented in
  `## Detecting When You're Stale` above
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- `mark_loaded`'s `source_git_head` write
  side backing the same section
- `scripts/tests/test-deploy-freshness.sh` -- fixture suite pinning both directions and every
  silent-skip branch of the freshness check
- `specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`
  -- the empirical `--wipe` round-trip-fidelity measurement backing the
  `### Round-Trip Fidelity of settings.local.json (measured)` subsection above
- `docs/guides/creating-extensions.md` -- extension authoring guide (manifest schema, file
  templates, deployment categories)
- `scripts/check-extension-docs.sh` -- doc-lint gate; its core deploy-drift lane surfaces
  never-deployed core scripts/hooks
- `context/patterns/batch-orchestration-guardrails.md` -- the authoritative inter-cycle redeploy
  checkpoint contract (trigger, failure contract, sequencing, idempotence guard) that this
  document's `## Automated Exception` subsection reconciles against the deliberate-invocation
  constraint above; also the authoritative home of `### The Postflight Completion-Deploy Gate`,
  which this document's second `## Automated Exception` subsection reconciles the same way
- `scripts/lib/deploy-freshness-lib.sh` -- the shared freshness-comparison algorithm both tiers
  of the two-tier staleness model above source (`deploy_freshness_stale_names` for tier 1,
  `deploy_freshness_status` for tier 2)
- `scripts/tests/test-postflight-deploy-gate.sh` -- fixture suite pinning the postflight
  completion-deploy gate's six conclusiveness branches, the check-only contract, and the
  no-worse-than-baseline verification tier this task's own dogfooded completion demonstrates
