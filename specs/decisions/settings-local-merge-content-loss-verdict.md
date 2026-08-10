# Decision Record: settings.local.json Deploy-Merge Content-Loss — Verdict

This record closes out the re-check of `err_1786350581208_23mAsn` (task 1015) and states explicit
positions on both residual hypotheses that the re-check surfaced but did not resolve, so neither
is silently dropped. It complements, and does not duplicate,
`specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`
(full methodology and per-pair results) and
`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`'s
`### Round-Trip Fidelity of settings.local.json (measured)` subsection (the durable deploy-doc
record of the measurement itself).

## The Verdict

**0 of 12** wipe-pairs (24 `--wipe` invocations) reproduced any dropped block or key in
`settings.local.json` in this round, across five sequential-continuation pairs and seven
reset-and-vary pairs spanning six pre-existing-state variants (baseline, extra permissions,
reversed/scrambled key order, ~2.5x bloated content, minimal, and a pre-seeded duplicate
`PreToolUse` matcher deliberately exercising the matcher-merge/dedup code path). Combined with the
prior re-check round's 0 of 3, the cumulative non-reproduction rate is **0 of 15** across two
independent re-check efforts.

**Methodology**: every pair ran against an isolated scratch copy of the repository, never the
live deploy tree, and was compared three ways — semantic equality (`jq -S`, recursively sorted
keys, hashed), an explicit structural presence check on `hooks.PreToolUse`, `hooks.Stop`,
`mcpServers`, `permissions.allow`, `permissions.deny`, and `enabledMcpjsonServers`, and spot-check
raw byte diffs. The structural detector was validated against a **positive control** (synthetic
deletion of `hooks.PreToolUse` and `mcpServers` from a copy, both correctly flagged) before its
"0 dropped" result across the real sample was trusted.

**Every observed difference across all 15 cumulative pairs was pure key/array reordering** — Lua
`pairs()` iteration nondeterminism across process runs — never a missing key, array element, or
block. No correlation was found between pre-existing `settings.local.json` state, size, or
ordering and any loss.

## Candidate Root Cause for the Original Observation

Commit `1692e33e8` moved the settings-snapshot restoration step in `manager.regenerate` (`init.lua`)
to run *before* the extension reload loop, rather than after it. The pre-fix ordering
(restore-after-load) would let the reload loop's own settings-fragment merges get silently
clobbered by the later restore — producing exactly the original observation's failure shape (a
dropped `hooks.PreToolUse` block and a dropped `mcpServers` block). All 15 cumulative wipe-pairs
ran against the post-fix code, and the 0/15 result is consistent with that fix being effective.
This is a plausible explanation for the original single observation, not a proven one — the
pre-fix code was never itself re-run under this task's sampling to confirm the failure mode
directly.

## The Writer Constraint (why closure, not downgrade)

The task's originating instruction asked to downgrade the record's severity from `high` to `low`.
The sanctioned writer, `agent-system/extensions/core/scripts/errors-append.sh`'s `update`
subcommand, accepts exactly four flags — `--id`, `--fix-status`, `--fixed-date`, `--fix-task` —
confirmed by re-reading its argument-parsing case block immediately before acting. There is no
sanctioned path to mutate `severity` on an existing record. Hand-editing `specs/errors.json` was
not an option: the file is protected by a `flock`-disciplined validated writer and a formal
schema, and a hand edit would bypass both.

**Closure supersedes downgrading.** A record with `fix_status: "fixed"` is out of triage
regardless of its historical severity stamp, which delivers the same practical outcome the
downgrade instruction was after — the record no longer surfaces as an open high-severity item —
without widening the writer's mutation surface for one bookkeeping wish. `err_1786350581208_23mAsn`
was closed via `errors-append.sh update --id err_1786350581208_23mAsn --fix-status fixed --fix-task 1015`;
its `message`, `context`, `severity`, and `recovery` fields are unchanged, preserving the original
observation's historical record intact.

## Position: The Concurrency Residual

**Verdict: closed as out of scope. No follow-up task.**

All 15 cumulative wipe-pairs ran strictly serially, in a single process, against an idle scratch
target. The `specs/.deploy-lock` mutex that both `--wipe` and non-destructive regeneration
acquire is fail-open/non-blocking **by deliberate design** — the same acquire/warn-and-proceed
shape as `specs/.commit-lock` — and this is already documented in `deploy-headless.sh` and in
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`, both of which
state plainly that a concurrent `--wipe` "could corrupt the `.claude/` tree."

The concurrency hypothesis is therefore a **known and accepted risk of an existing, documented
design**, not an untracked defect this re-check discovered. It is also a different defect class
from the question this task's sampling actually answers — "does the merge logic lose content on a
plain repeated wipe" — which 0/15 rules out with reasonable confidence. Opening a follow-up task
to chase a concurrency reproduction would be speculative work against a risk that is already named
and accepted at the design level, not new information changing that acceptance.

The hypothesis is preserved in writing, not discarded: both in the measured-fidelity subsection of
`regeneration-is-manual-only.md` and here, so a future recurrence has a concrete starting point —
interleave two `--wipe` runs, or a `--wipe` against a concurrent `settings.local.json` edit,
against the same target, which serial sampling deliberately did not attempt.

## Position: `err_1786350581240_JyztWt` (Ordering Nondeterminism, Low)

**Verdict: stays open, unchanged, and does NOT fall out of this task.**

This record is real — present in all 12 of this round's pairs (and all 15 cumulative) — correctly
severity-rated as cosmetic to JSON consumers, and its only practical consequence is defeating a
future byte-identical-diff acceptance criterion for deploy output. This task's deploy-doc
correction removes the one place that criterion was *asserted as already met* (the now-corrected
"byte-identically" claim) — that is an honest correction of a false claim, not a fix of the
underlying nondeterminism. The actual fix (deterministic key/array ordering at generation time in
the merge/index-build routine) is unchanged in scope and remains tracked under this record's own
`suggested_action`. It is deliberately **not** marked fixed, and its `fix_status` was verified
unchanged (`unfixed`) after Phase 1's writer call closed the sibling record.

## Scope Boundary Honored

No file under `lua/neotex/plugins/ai/shared/extensions/` and no merge/backup/deploy script
(`merge.lua`, `init.lua`, `settings_backup.lua`, `deploy-headless.sh`) was edited by this task.
Reproduction was not established, so no fix was attempted; every change in this close-out is
either a field-scoped JSON mutation through the sanctioned writer, additive documentation prose,
or this new decision record.
