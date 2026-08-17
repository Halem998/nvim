# Implementation Plan: Task #41

- **Task**: 41 - eager_context_measurement_harness
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/041_eager_context_measurement_harness/reports/01_eager-context-measurement-harness.md`
- **Artifacts**: plans/01_eager-context-measurement-harness.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `agent-system/extensions/core/scripts/measure-eager-context.sh`: a harness that **predicts**
the session-start eager context set from the source store alone — modelling what a regenerate
*would* produce rather than measuring the (routinely stale) deployed `.claude/` tree, and never
invoking `deploy-headless.sh` or `nvim`. It accounts for four channels (parent CLAUDE.md chain,
predicted generated CLAUDE.md, resolving `@`-imports, and `paths:`-gated rules), emits bytes plus
`bytes/4` token estimates per contributing source and in total in a stable machine-parseable
format, flags any volatile file it finds rather than counting it, and splits `--check` (report,
exit 0/1) from `--write` (report plus a JSON baseline snapshot for later drift comparison).

Definition of done: the script exists, runs clean under both modes, derives its eager rule set
dynamically from `paths:` frontmatter (not a hardcoded list), is registered in the core
manifest's `provides.scripts`, is catalogued in the utility-scripts inventory, and has had its
total reconciled against the recorded 70,160 B / 17,540-token baseline with any delta explained
rather than forced to match.

### Research Integration

The research report is verified ground truth and this plan builds on it without re-deriving:

- **Assembly algorithm** (report Finding 1): `generate_claudemd()` in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua:768-879`. Read active extensions from
  `.claude-extensions.json` at the project root, sort alphabetically, pull `core` to the front,
  resolve each extension's `manifest.json` `.merge_targets.claudemd.source` relative to that
  extension's own directory, prepend `core/templates/claudemd-header.md` when core is loaded,
  right-trim each fragment, join with `\n\n`, append one trailing `\n`.
- **Must not regenerate** (report Finding 1 + Decisions): `context/patterns/regeneration-is-manual-only.md`
  licenses exactly one automated caller of `deploy-headless.sh` (skill-orchestrate Stage MT-3),
  and this script is not it. The harness models the concatenation in bash. This is both the
  literal task instruction and a hard policy constraint.
- **Corrected `paths:` model** (report Finding 3): the task description's literal "absent or
  `**/*`" rule under-counts eager rules by ~71%. The harness must glob-**match** each rule's
  `paths:` value against a representative touched-path set. This plan implements the corrected
  model and Phase 3 records the deviation explicitly.
- **`@`-imports resolve to 0 today** (report Finding 2): zero `@`-refs exist anywhere in the
  chain, deliberately. The channel is still implemented generally; reporting 0 is the correct
  result, not a bug.
- **Prior art is not done** (report Executive Summary): `measure-eager-surface.sh` measures the
  deployed tree and hardcodes a 9-file/6-rule list — the two anti-patterns this work fixes. Its
  snapshot-JSON *shape* is reusable; its `--baseline`/`--compare` *flag names* are not.
- **Baseline provenance** (report Finding 5): 70,160 B / 17,540 tokens is the Phase-7
  post-redeploy whole-prefix figure in
  `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`. The "~9.5k tokens after" figure
  has no citable source and is an externally supplied target, not an assertion to verify.

### Planner-verified additions (dry-run evidence, not re-derivation)

Two facts were confirmed by dry-run during planning and are handed to the implementer as
calibration anchors rather than hypotheses to rediscover:

1. **The trim+join model is byte-exact today.** Summing the header plus the six active
   extensions' `claudemd` sources gives 33,209 B raw. Applying the algorithm — subtract one
   trailing newline per part (7 parts), add 6 separators x 2 B, add 1 final newline — gives
   `33209 - 7 + 12 + 1 = 33215`, which equals the deployed `.claude/CLAUDE.md` exactly. A
   correct implementation of Phase 1 must land on 33,215 B (subject to source-store drift).
2. **The `.claude/**` probe is what widens the rule set past the historical six.** Under a
   default representative touched-path set covering both `specs/**` and `.claude/**`, eight core
   rules match: the historical six (23,547 B, the figure `context-layers.md` already records)
   plus `error-handling.md` (2,987 B) and `workflows.md` (759 B), totalling 27,293 B.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A new `measure-eager-context.sh` that predicts the eager set from source-store files only.
- Dynamic derivation of the eager rule set by glob-matching `paths:` frontmatter against a
  documented, overridable representative touched-path set.
- Per-source bytes + `bytes/4` token estimates and a grand total, in a stable machine-parseable
  format.
- A `--check` (default, exit 0/1) / `--write` (report + JSON snapshot) split following
  `generate-context-line-counts.sh`'s flag vocabulary and root-resolution pattern.
- Loud flagging — never silent inclusion — of any volatile file encountered.
- Registration in the core manifest and the utility-scripts inventory; an explicit written
  statement of how this script relates to `measure-eager-surface.sh`.

**Non-Goals**:
- Reproducing, validating, or targeting the "~9.5k tokens after" figure. It has no repo source
  and is a target for a future normalization pass, not this harness's concern.
- Performing the downward normalization itself. This task builds the measuring instrument only.
- Invoking `deploy-headless.sh`, `nvim --headless`, or any real regenerate — explicitly forbidden.
- Deleting or rewriting `measure-eager-surface.sh`. Its disposition is *documented* here, not
  executed; removal would be a separate decision.
- Any write under `.claude/**`. All edits target `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer copies `measure-eager-surface.sh`'s deployed-tree reads or hardcoded file lists, defeating the task's purpose | H | M | Phase 1 forbids reading `.claude/**` for measurement; Phase 3 forbids any hardcoded rule list; Phase 6 asserts the derivation is dynamic |
| Bash `[[ str == pattern ]]` treats `**` as `*` and `*` does not cross `/`, so `specs/**/*` silently fails to match a nested path | H | H | Phase 3 mandates a `glob_to_ere` translation + `=~` matching, with named unit cases including `specs/**/*` against a 3-segment path |
| Representative touched-path set is a policy choice, not a fact; a careless default silently changes the total | M | H | Default set is explicit, documented in the script header, echoed in output, and overridable by env var; Phase 3 enumerates exactly which rule each probe catches |
| Shelling out to `deploy-headless.sh` "just to be accurate" | H | L | Called out in Overview, Non-Goals, and Phase 1 tasks; Phase 6 greps the script to confirm absence |
| Reintroducing a task-number citation into a deliverable | M | M | Phase 5 fixes the one existing stale citation using a file-path + section-heading anchor and forbids bare task-number text |
| Total diverges from the 70,160 B baseline and gets "fixed" by fudging the model | H | M | Phase 6 explicitly requires explaining the delta, and pre-supplies the expected direction and cause |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 1-4
all edit the same single new file, so parallel execution would mean concurrent edits to one
territory; Phases 5-6 depend on the script's behavior being final.

---

### Phase 1: Scaffold, CLI Contract, and Predicted-CLAUDE.md Assembly [COMPLETED]

**Goal**: Create the script with its argument contract, root resolution, byte/token helpers, and
a bash replication of `generate_claudemd()` that predicts the assembled CLAUDE.md size from
source-store files alone.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/measure-eager-context.sh` with `#!/usr/bin/env bash`
      and `set -uo pipefail` (match `measure-eager-surface.sh`; avoid `-e` so a missing optional
      file reports rather than aborts).
- [x] Add the root-resolution preamble verbatim from `generate-context-line-counts.sh`:
      `[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1`
      then `REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"` and
      `EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"`.
- [x] Parse arguments: `MODE="check"` default; `--write` sets write mode; `--check` or no
      argument is check mode; `--write` accepts an optional snapshot path argument (default a
      documented path under the repo); anything else prints `Usage:` to stderr and exits 2.
- [x] Add `bytes_of()` (prints 0 for a missing file, never errors) and `tokens_of()`
      (integer `bytes / 4`).
- [x] Implement the parent CLAUDE.md chain channel: `$(dirname "$REPO_ROOT")/CLAUDE.md` and
      `$REPO_ROOT/CLAUDE.md`, each reported by label, path, bytes, tokens; a missing file is
      reported as 0 B, not an error.
- [x] Implement `predict_claudemd_bytes()` replicating `generate_claudemd()`:
      read active extensions via
      `jq -r '.extensions | to_entries[] | select(.value.status=="active") | .key' "$REPO_ROOT/.claude-extensions.json" | sort`,
      move `core` to the front, resolve each extension's fragment via
      `jq -r '.merge_targets.claudemd.source // empty' "$EXT_DIR/<ext>/manifest.json"` (never
      hardcode `merge-sources/claudemd.md` or `EXTENSION.md` — both shapes exist), prepend
      `$EXT_DIR/core/templates/claudemd-header.md` when core is active, and compute the assembled
      size as: sum of each part's right-trimmed byte length, plus `2 * (parts - 1)` for the
      `\n\n` joins, plus 1 for the trailing newline.
- [x] Compute each part's trimmed length without materializing the whole document (e.g. per-file
      `wc -c` minus trailing-whitespace length), or by building the predicted document in a
      `mktemp` file and measuring it — either is acceptable; the temp-file route is easier to get
      byte-exact and must clean up after itself.
- [x] Write the script header comment: what the script measures, why it predicts rather than
      measures the deployed tree, and an explicit "this script MUST NOT invoke `deploy-headless.sh`
      or `nvim`" line citing `context/patterns/regeneration-is-manual-only.md`'s
      single-sanctioned-caller rule.
- [x] Print a provisional table of the three sources measured so far plus a running subtotal.

*(completed: all Phase 1 tasks implemented in `measure-eager-context.sh`; predicted assembled
CLAUDE.md verified at exactly 33,215 B via the mktemp-materialization route, matching
`wc -c < .claude/CLAUDE.md` byte-for-byte)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 6 active extensions (`core, email, literature, memory,
nix, nvim`), 7 concatenated parts, and a predicted assembled size of **33,215 B** matching the
currently-deployed `.claude/CLAUDE.md` byte-for-byte. Confirm at implementation time by running
the script and comparing to `wc -c < .claude/CLAUDE.md`. If they differ, first check whether the
source store has drifted ahead of the deploy (expected and legitimate — that is the whole point
of the script) by diffing the fragment sizes; only treat it as a model bug if the deployed tree
is known-current. This one-time comparison to the deployed file is a *calibration check*, not a
measurement dependency: the script itself must never read `.claude/CLAUDE.md`.

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-eager-context.sh` - new file (scaffold, CLI,
  parent-chain channel, assembly prediction)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/measure-eager-context.sh` passes.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh` runs and
  prints the parent chain plus a predicted assembled-CLAUDE.md figure.
- The predicted figure equals 33,215 B (or the delta is explained by source-store drift).
- `grep -c 'deploy-headless\|nvim' measure-eager-context.sh` returns 0 outside of the header
  comment's prohibition text.

---

### Phase 2: `@`-Import Channel and Volatile-File Guard [COMPLETED]

**Goal**: Detect `@`-imports generally (directory-relative resolution, existence-tested), and add
the volatile-file deny-list that flags rather than counts.

**Tasks**:
- [x] Implement `scan_at_imports <file> <containing-dir>`: match `@`-prefixed path tokens in the
      file's lines, resolve each **relative to the containing file's own directory** (not the repo
      root, not `.claude/`), and test `[[ -f ... ]]`.
- [x] Run the scan over the parent CLAUDE.md, the repo CLAUDE.md, and the predicted generated
      CLAUDE.md content. For the predicted content, the containing directory is the *target*
      directory (`$REPO_ROOT/.claude`), because that is where a regenerate would place the file —
      document this in a comment, since it is the non-obvious half of the directory-relative rule.
- [x] Report each resolving `@`-ref as its own line (label, resolved path, bytes, tokens) and add
      its bytes to the eager total.
- [x] Report each non-resolving (`dangling`) `@`-ref on a distinct line contributing 0 B, so a
      future added-but-broken ref is visible rather than silently inert. A dangling ref is
      informational and must **not** by itself fail `--check`.
- [x] Add `VOLATILE_PATHS` deny-list — `specs/TODO.md`, `specs/state.json`, `specs/errors.json` —
      as a named array with a comment that it is extensible.
- [x] Check every candidate path considered by any channel (`@`-import targets, merge sources,
      rule files) against the deny-list. On a hit: emit a loud `FLAG: volatile file ... would be
      eagerly loaded` line, exclude its bytes from the legitimate eager total, and set a
      `VOLATILE_HITS` counter that makes `--check` exit 1.
- [x] Add a header-comment note that this channel is expected to report **0 resolving `@`-imports
      and 0 volatile hits** in the current tree, and that this is the correct result, citing
      `context/architecture/context-layers.md`'s "Eager vs. Lazy Loading Channels" (channel 2)
      for why merge sources deliberately use plain backticked paths instead of `@`-refs.

*(completed: verified 0 resolving/0 dangling refs in the live tree; a scratch-copy test with an
injected `@specs/state.json` ref produced `FLAG: volatile file 'specs/state.json' ...` and exit 1,
and a separately injected dangling ref produced a `DANGLING:` line with exit 0 — both reverted,
no scratch changes committed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-eager-context.sh` - add `@`-import scan and
  volatile-file guard

**Verification**:
- Script runs clean; `@`-import section reports 0 resolving refs and 0 dangling refs.
- Volatile-file section reports 0 hits; `--check` still exits 0.
- Temporarily adding a `@specs/state.json` ref to a scratch copy of a scanned file produces a
  `FLAG:` line and exit 1 (revert the scratch change afterwards — do not commit it).

---

### Phase 3: Rules `paths:` Glob-Match Channel (Corrected Model) [COMPLETED]

**Goal**: Derive the eager rule set dynamically by glob-matching each source-store rule's `paths:`
frontmatter against a documented, overridable representative touched-path set.

**Tasks**:
- [x] Implement `glob_to_ere <pattern>`: escape regex metacharacters (`.` in particular), then
      translate `**/` -> `(.*/)?`, remaining `**` -> `.*`, `*` -> `[^/]*`, `?` -> `[^/]`, and
      anchor with `^`/`$`. **Do not use bash `[[ str == pattern ]]`** — inside `[[ ]]`, `**` is
      treated as a plain `*` regardless of `shopt -s globstar`, and `*` does not cross `/`, so
      `specs/**/*` would silently fail to match a nested path. Match with `[[ "$path" =~ $ere ]]`.
- [x] Define the representative touched-path set as a named array with an env-var override
      (`EAGER_REP_PATHS`, comma-separated), following the `REPO_ROOT`/`EXT_DIR` override style
      already used in this scripts directory. Default: one probe under `specs/**` that is not a
      plan file (e.g. `specs/000_example/reports/01_example.md`) and one under `.claude/**`
      (e.g. `.claude/context/example.md`). These are probe strings only — nothing is read from
      them.
- [x] Echo the active representative path set in the script's output so a reader can audit the
      classification rather than trusting it.
- [x] Enumerate every source-store rule via `"$EXT_DIR"/*/rules/*.md`, extract its `paths:` value
      from the YAML frontmatter, and normalize both scalar (`paths: specs/**/*`,
      `paths: "**/*"`) and JSON-array (`paths: ["specs/**/*", ".claude/**/*"]`) forms into a list
      of member globs.
- [x] Classify each rule: `paths:` absent -> always-eager; any member glob matching any
      representative path -> eager (record *which* glob and *which* probe matched); otherwise ->
      deferred, excluded from the total.
- [x] Restrict the eager set to rules belonging to **currently active** extensions (from
      `.claude-extensions.json`). An inactive extension's rules are never deployed, so a
      `web`/`lean`/`latex` rule must not enter the total even if its glob somehow matched.
- [x] Report each eager rule on its own line with label, path, bytes, tokens, and the matched
      glob/probe (or `frontmatter absent`), and add its bytes to the total.
- [x] Add a header-comment section recording the deviation from the task description's literal
      model: the "absent or `**/*`" rule under-counts by ~71%; the corrected glob-match model is
      implemented instead. Cite the correction by durable anchor —
      `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`, section
      "Eager-Context Measurement-Harness Correction" — never as a bare task number.
- [x] Add a header-comment note that this script's rule total will **exceed**
      `measure-eager-surface.sh`'s hardcoded six-rule figure by `error-handling.md` +
      `workflows.md`, and that this is a correct divergence by design, not a bug to reconcile.

*(completed: verified exactly 8 eager core rules totalling 27,293 B against the default
representative path set — matching the historical six [23,547 B] plus error-handling.md [2,987 B]
and workflows.md [759 B]; `glob_to_ere` unit cases pass; narrowing `EAGER_REP_PATHS` to the
`specs/**` probe alone reproduces the 23,547 B six-rule total)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that the default representative path set yields exactly
**8 eager core rules totalling 27,293 B** — the historical six (`artifact-formats.md`,
`git-workflow.md`, `no-task-references-in-deliverables.md`, `pr-prohibition.md`,
`source-store-deploy-boundary.md`, `state-management.md`; 23,547 B) plus `error-handling.md`
(2,987 B) and `workflows.md` (759 B) — and that `plan-format-enforcement.md`
(`specs/**/plans/**`), `project-overview-detection.md` (literal single file), and every
extension-gated `*.lean`/`*.tex`/`*.nix`/`*.lua`/`*.astro` rule are correctly excluded. Confirm
at implementation time by reading the script's own per-rule output, not by assuming; if the count
differs, report which rule changed class and why before adjusting anything.

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-eager-context.sh` - add `glob_to_ere`,
  representative-path set, rule enumeration and classification

**Verification**:
- `glob_to_ere` unit cases pass, checked inline or in a scratch harness: `specs/**/*` matches
  `specs/000_example/reports/01_example.md`; `.claude/**/*` matches `.claude/context/example.md`;
  `**/*` matches both; `specs/**/plans/**` matches neither default probe; `**/*.lean` matches
  neither.
- Script output lists 8 eager rules with a matched-glob column and 0 hardcoded rule names in the
  classification path (`grep` the script: no literal rule filename appears outside comments).
- Overriding `EAGER_REP_PATHS` to only the `specs/**` probe drops `error-handling.md` and
  `workflows.md`, reproducing the historical 23,547 B six-rule class total.

---

### Phase 4: Stable Machine-Parseable Output, Totals, and `--write` Snapshot [COMPLETED]

**Goal**: Finalize the output contract — per-source and total bytes/tokens in a stable
machine-parseable form — and implement `--write`'s JSON baseline snapshot.

**Tasks**:
- [x] Define and document the stable per-source record: `channel`, `label`, `path`, `bytes`,
      `tokens_est`. Emit one line per source in a fixed field order with a fixed separator
      (tab-delimited or a `KEY=value` form), preceded by a header line naming the fields, so
      downstream parsing does not depend on column alignment.
- [x] Emit per-channel subtotals (parent chain, predicted CLAUDE.md, `@`-imports, rules) and a
      grand `TOTAL` row with both bytes and `bytes/4` tokens.
- [x] Print a human-readable summary block modelled on `generate-context-line-counts.sh`'s
      `=== Summary (check mode) ===`, ending in `CHECK PASSED: ...` (exit 0) or
      `CHECK FAILED: ...` (exit 1). `--check` fails only on a volatile-file hit or an
      unreadable required source — never merely because the total changed.
- [x] Implement `--write`: perform the identical measurement, print the same report, and
      additionally write a timestamped JSON snapshot. Model the snapshot's *content shape* on
      `measure-eager-surface.sh`'s `write_json()` — a `timestamp`, a `sources` array of
      `{channel, label, path, bytes, tokens_est}` objects, per-channel subtotals, and
      `total_bytes` / `total_tokens_est` — while keeping the `--check`/`--write` flag vocabulary
      required by this task. Build the JSON with `jq -n` rather than hand-assembled string
      concatenation.
- [x] Record the active representative path set inside the snapshot, so a later comparison can
      tell whether a delta came from content drift or from a changed measurement policy.
- [x] Document the output contract and the snapshot schema in the script header.

*(completed: `--write` produces valid JSON per `jq empty`; `--bogus` exits 2 with a `Usage:` line;
two consecutive `--check` runs produce byte-identical stdout)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-eager-context.sh` - output formatting, totals,
  `--write` snapshot

**Verification**:
- `REPO_ROOT=$(pwd) bash .../measure-eager-context.sh` exits 0 and prints a complete table with
  per-channel subtotals and a grand total.
- `REPO_ROOT=$(pwd) bash .../measure-eager-context.sh --write /tmp/snap.json` exits 0, writes
  the file, and `jq empty /tmp/snap.json` passes.
- `bash .../measure-eager-context.sh --bogus` prints `Usage:` to stderr and exits 2.
- Re-running `--check` twice produces byte-identical output (no timestamps or nondeterminism in
  check-mode output).

---

### Phase 5: Registration, Inventory, and Context-Layers Reconciliation [NOT STARTED]

**Goal**: Wire the script into the extension manifest and operator docs, and state the
relationship to the predecessor script.

**Tasks**:
- [ ] Add `measure-eager-context.sh` to `provides.scripts` in
      `agent-system/extensions/core/manifest.json`, placed to match the array's existing ordering
      convention. (Confirmed required: `measure-eager-surface.sh` and
      `generate-context-line-counts.sh` are both already declared there.)
- [ ] Add an entry for `measure-eager-context.sh` to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`, matching the
      existing bullet style (`.claude/scripts/<name>` - description, noting `--check`/`--write`).
- [ ] Add the missing entry for the predecessor `measure-eager-surface.sh` to the same inventory
      (the research report flagged this pre-existing gap), and in that entry state the
      coexistence decision explicitly.
- [ ] **Coexistence decision to record**: the two scripts coexist. `measure-eager-surface.sh`
      remains as the deployed-tree before/after delta tool with a fixed composition (useful for
      apples-to-apples comparison across a single cut); `measure-eager-context.sh` is the
      source-store predictive harness with dynamic `paths:` derivation. Note in the inventory
      that the new script's rule total is intentionally wider. Do not delete or modify
      `measure-eager-surface.sh` in this task.
- [ ] Fix the stale citation in
      `agent-system/extensions/core/context/architecture/context-layers.md` (channel 3, "Eager
      budget ceiling" bullet): it points at `specs/054_split_eager_rules_budget/baseline-bytes.md`,
      but that file now lives at `specs/archive/054_split_eager_rules_budget/baseline-bytes.md`.
      Correct the path and add the section heading ("Eager-Context Measurement-Harness
      Correction") so the anchor is durable. Cite by file path plus section heading only — do not
      introduce any bare "task N" text into this deliverable.
- [ ] Add a short pointer in that same `context-layers.md` bullet naming
      `scripts/measure-eager-context.sh` as the tool that implements the corrected glob-match
      model described there. Keep it to one sentence — this file is itself lazily loaded but is
      referenced by the eager CLAUDE.md, so avoid growth beyond what the pointer needs.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts that `provides.scripts` registration is required for a
new core script, and that exactly three files change (`manifest.json`,
`utility-scripts-inventory.md`, `context-layers.md`). Confirm the registration requirement by
checking that both sibling scripts are already declared there (they are), and confirm the file
count by the actual diff; if a fourth file turns out to need updating (e.g. a deploy verification
list), include it and say so rather than skipping it.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add script to `provides.scripts`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - add both entries
  and the coexistence statement
- `agent-system/extensions/core/context/architecture/context-layers.md` - fix stale citation
  path, add section-heading anchor, add one-sentence tool pointer

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` passes and
  `jq -r '.provides.scripts[]' ... | grep -c measure-eager-context.sh` returns 1.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (or the repo's doc-lint
  entry point) reports no new failures.
- `bash .claude/scripts/check-task-references.sh` (repo-wide task-reference lint) reports no new
  violations in the three changed files.
- The cited archive path resolves: `ls specs/archive/054_split_eager_rules_budget/baseline-bytes.md`.

---

### Phase 6: Verification Run and Baseline Reconciliation [NOT STARTED]

**Goal**: Run the finished harness end to end and reconcile its total against the recorded
70,160 B / 17,540-token baseline, explaining the delta rather than forcing a match.

**Tasks**:
- [ ] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh`
      and capture the full output.
- [ ] Run `--write` against a snapshot path and validate the JSON with `jq`.
- [ ] Confirm the anti-pattern guards hold: the script never reads `.claude/CLAUDE.md` or
      `.claude/rules/*` for measurement, never invokes `deploy-headless.sh` or `nvim`, and
      contains no hardcoded rule or file list in its classification path.
- [ ] Reconcile against the baseline. Expected accounting to confirm or correct:
      the recorded 70,160 B is `parent + repo + assembled + six rules (23,547 B)`. Today's
      corrected-model total is `parent (769) + repo (3,046) + assembled (33,215) +
      eight rules (27,293) = 64,323 B / 16,080 tokens`. The delta of about -5,800 B decomposes
      into two opposing movements: **+3,746 B** from the corrected model newly counting
      `error-handling.md` and `workflows.md`, and roughly **-9,580 B** of genuine shrinkage in
      the parent/repo/assembled group since that post-redeploy measurement. Verify both halves
      against the script's own per-source output.
- [ ] Write the reconciliation into the implementation summary as a short table (baseline
      composition, current composition, per-cause delta). Do not adjust the model to hit 70,160 B.
- [ ] State explicitly in the summary that the "~9.5k tokens after" figure was **not** validated,
      because it has no citable source in the repo and is a target for a future normalization
      pass, not an assertion this harness reproduces.
- [ ] Run the standard gate set for the repo (shell syntax check across changed scripts, `jq empty`
      across changed JSON, doc-lint, task-reference lint).

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts a current total near 64,323 B / 16,080 tokens and a
specific two-part decomposition of the delta from 70,160 B. These are planner dry-run figures and
will drift with any source-store edit landing between planning and implementation. Confirm every
number from the script's own output at implementation time; if the total differs, re-derive the
decomposition from the per-source rows rather than reusing these numbers.

**Files to modify**:
- None (verification only). Any defect found is fixed in place in
  `agent-system/extensions/core/scripts/measure-eager-context.sh`.

**Verification**:
- Both modes exit 0 with no `FLAG:` lines.
- The reconciliation table accounts for the full delta with no unexplained residual.
- `grep -nE 'deploy-headless|nvim --headless' measure-eager-context.sh` matches only the header
  comment's prohibition text.
- `grep -n '\.claude/CLAUDE\.md\|\.claude/rules' measure-eager-context.sh` shows no measurement
  read of the deployed tree.

---

## Testing & Validation

- [ ] `bash -n` passes on `measure-eager-context.sh`.
- [ ] `--check` (and bare invocation) exits 0 on a clean tree; `--bogus` exits 2 with a `Usage:` line.
- [ ] `--write <path>` produces valid JSON (`jq empty`) containing per-source records, per-channel
      subtotals, a grand total, and the active representative path set.
- [ ] Predicted assembled CLAUDE.md matches the deployed file byte-for-byte when the deploy is
      current (calibration only — not a runtime dependency).
- [ ] `glob_to_ere` matches `specs/**/*` against a 3-segment nested path and excludes
      `specs/**/plans/**` and `**/*.lean` from the default probe set.
- [ ] Eight eager rules are derived dynamically, with the matched glob shown per rule and no
      hardcoded rule names in the classification path.
- [ ] Narrowing `EAGER_REP_PATHS` to the `specs/**` probe alone reproduces the historical
      23,547 B six-rule class total.
- [ ] An injected volatile `@`-ref on a scratch copy produces a `FLAG:` line and exit 1; the
      scratch change is reverted.
- [ ] `jq empty` passes on the modified `manifest.json`; the script appears once in
      `provides.scripts`.
- [ ] Doc-lint and task-reference lint report no new violations.
- [ ] No file under `.claude/**` was written by this task.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/measure-eager-context.sh` (new)
- `agent-system/extensions/core/manifest.json` (modified — `provides.scripts`)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (modified — two
  entries plus coexistence statement)
- `agent-system/extensions/core/context/architecture/context-layers.md` (modified — stale
  citation path fixed, section-heading anchor added, one-sentence tool pointer)
- `specs/041_eager_context_measurement_harness/summaries/01_eager-context-measurement-harness-summary.md`
  (implementation summary, including the baseline reconciliation table)

## Rollback/Contingency

Every change is additive and confined to four source-store files. To revert: delete
`measure-eager-context.sh`, and `git checkout` the three modified files
(`manifest.json`, `utility-scripts-inventory.md`, `context-layers.md`). Nothing under `.claude/**`
is touched, so no redeploy is required to undo — and none is required to land the change either,
since the script is invoked directly from the source store via
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh`.

If Phase 1's assembly model cannot be made byte-exact, the fallback is to build the predicted
document in a temp file and measure it directly rather than computing the size arithmetically;
this is strictly more reliable and costs only a `mktemp`. If Phase 3's glob translation proves
unreliable for an unanticipated `paths:` form, report the specific form and fall back to
per-form explicit handling rather than silently classifying it as deferred — a rule silently
dropped from the eager total is the exact failure mode this harness exists to prevent.
