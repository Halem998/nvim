# Research Report: Task #32

**Task**: 32 - redeploy_and_remediate_install_once_settings
**Started**: 2026-08-24T21:01:00Z
**Completed**: 2026-08-24T21:08:14Z
**Effort**: 1-2 hours (research only; implementation is separate)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/skill-base.sh`, `.claude/scripts/skill-base.sh`,
  `lua/neotex/plugins/ai/shared/extensions/{loader,init}.lua`, `.claude/settings.json`,
  `agent-system/extensions/core/root-files/settings.json`, `specs/TODO.md`, `specs/state.json`
- Tooling: `bash .claude/scripts/verify-deploy.sh --findings --quiet`,
  `bash .claude/scripts/check-extension-docs.sh`, `bash .claude/scripts/system-defect-record.sh`,
  `claude mcp list`, `git log`
**Artifacts**:
- This report
- Captured pre-deploy findings baseline (verbatim, embedded below)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The description's revised premise is directionally correct but its two headline numbers are
  wrong: measured commit count since deploy is **44** (not 133), and files changed under
  `agent-system/` since deploy is **16** (not 15). The 4-drifted-scripts figure undercounts:
  `verify-deploy.sh`'s own gate5 measures **6 drifted scripts + 2 never-deployed scripts = 8
  script-level findings**, plus 3 more drifted/missing non-script files, for **11 gate5
  findings total** (this is also the literal "11 finding(s)" the tool reports).
- All three named premises are CONFIRMED: (a) `mcp-server-ownership.md` is deployed and
  byte-identical; (b) the `mcp__lean-lsp__*` grant is present at `.claude/settings.json:188` and
  absent from `agent-system/extensions/core/root-files/settings.json`; (c) `settings.json` is
  genuinely `install_once` in `loader.lua`/`init.lua` (verified by reading the code, not just the
  comments).
- The four previously-completed, not-yet-live tasks are identifiable and traceable:
  **"Fix mint dispatch seq persisted counter"** (dir `065_fix_mint_dispatch_seq_persisted_counter`)
  and the three literature fixes in dirs `069_harden_conversion_quality_gate_against_mojibake`
  (HIGH severity, corpus-corruption gate), `070_fix_discover_tier_starvation_and_silent_tier3_failure`
  (MEDIUM), and `071_fix_validate_directory_path_false_positives_and_flag_mismatch` (LOW). All
  four show `[COMPLETED]` in `specs/TODO.md`.
- The PRE-deploy `verify-deploy.sh --findings --quiet` baseline is captured verbatim below (52
  lines, 3 of 23 checks failed). It independently reproduces the mint-dispatch-seq bug live: the
  deployed script's own test suite (`test-mint-dispatch-seq.sh`) fails 4 of its cases
  (`Case C/D/E/F`) against the currently-deployed `skill-base.sh` in exactly the way the ambient-
  variable bug predicts.
- `system-defect-record.sh`'s non-zero exit this dispatch is **not** a drift/breakage finding: the
  script is present, unchanged between source and deployed copies, and correctly exits 1 on a
  bare invocation with no required arguments (that is its documented "argument error" exit code).
  The orchestrator's raw observation is real (it did exit non-zero) but the cause is "called
  without required flags," not "broken in the deployed tree."
- Both deferred-decision premises are confirmed factually: `lean-lsp` IS registered at user scope
  pointing at `/home/benjamin/Projects/BimodalLogic` (not this repo); the 9 playwright grants ARE
  duplicated verbatim across `agent-system/extensions/web/settings-fragment.json` and
  `agent-system/extensions/present/settings-fragment.json`.
- Risk from deploying "the entire source store": low and mischaracterized in the premise. Of the
  44 repo-wide commits since deploy, only 12 commits / 16 files touch `agent-system/` (the actual
  deploy source); the rest is `specs/` task-management churn deploy-headless.sh never reads. All
  16 deploy-relevant files trace cleanly to the four already-completed, reviewed tasks. No
  in-flight/uncommitted or unrelated work is mixed into the drift set.

## Context & Scope

Research-only per task instructions: measure current deploy-drift state, confirm/refute the
description's premises against live evidence, identify which completed tasks become live at
this deploy, capture a verbatim PRE-deploy findings baseline (required input for the
implementation phase), assess the two deferred decisions, and flag risk in deploying the whole
source store. No deploy was run, no files were edited, no `.claude/**` file was hand-modified.

## Findings

### 1. Measured deploy-drift state

**Deploy timestamp**: batch-deployed files cluster at mtime `2026-08-17 21:36:33/34`
(`.claude/scripts/skill-base.sh`, `.claude/CLAUDE.md`, hundreds of others). Two files —
`.claude/scripts/validate-state.sh` and `.claude/context/schemas/state-schema.json` — carry a
much newer mtime (`2026-08-24 11:37-11:38`) and are byte-identical to source: these were
apparently resynced individually (e.g. via the picker's per-artifact `Ctrl-l` update) since the
last full deploy, not part of the pending drift.

**Git measurement since 2026-08-17 21:36:34 -0700** (the actual deploy timestamp, not a rounded
"7 days ago"):
- Total repo-wide commits: **44** (description's "133" figure is not reproducible under any
  reasonable "since last deploy" boundary I tried; the true, deploy-relevant subset is much
  smaller — see below).
- Commits touching `agent-system/` (the deploy source root): **12**.
- Distinct files changed under `agent-system/` : **16** (description's "15" is close but not
  exact).

**`verify-deploy.sh --findings --quiet` gate5** ("deployed vs source" content check) reports
**11 findings** — this matches the tool's own narrative line
`[FAIL] manifest-driven verification reported 11 finding(s)` exactly, and reconciles the full
16-file git diff:

| Status | Count | Files |
|---|---|---|
| Drifted scripts (content differs) | 6 | `scripts/skill-base.sh`; `scripts/literature-convert.sh`; `scripts/literature-discover.sh`; `scripts/literature-normalize-authors.sh`; `scripts/tests/generate-test-fixtures.py`; `scripts/tests/test-literature-convert.sh` |
| Missing scripts (never deployed) | 2 | `scripts/tests/test-mint-dispatch-seq.sh`; `scripts/literature_quality_gate.py` |
| Drifted non-script docs | 3 | `context/patterns/regeneration-is-manual-only.md`; `commands/literature.md`; `skills/skill-literature/SKILL.md` |
| Already resynced (byte-identical) | 2 | `scripts/validate-state.sh`; `context/schemas/state-schema.json` |
| Changed but not gate5-checked | 3 | `manifest.json` (core); `manifest.json` (literature); `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md` |

6 + 2 + 3 + 2 + 3 = 16, reconciling the full git diff exactly. So: the description's "4 drifted
scripts" undercounts — the true count is **6 drifted + 2 never-deployed = 8 script-level
findings**, plus 3 more drifted non-script deliverables. Note the 3 "not gate5-checked" files
(both `manifest.json`s and the literature pattern doc) are real source changes that
`verify-deploy.sh` gate5 does not currently compare — worth flagging as a possible coverage gap
in that script, though fixing it is out of this task's scope.

**Pre-existing (unrelated) findings**, present in the baseline and NOT attributable to tasks
65/69/70/71 — these must NOT be misread as newly introduced after the deploy:
- 10 `gate3` "Rule R" index-entries.json line-count mismatches (core: `architecture/context-layers.md`,
  `patterns/batch-orchestration-guardrails.md`, `patterns/file-footprint-overlap.md`,
  `patterns/file-metadata-exchange.md`, `patterns/regeneration-is-manual-only.md`,
  `patterns/skill-postflight-flow.md`, `reference/orchestrator-critical-paths.json`,
  `schemas/state-schema.json`, `standards/postflight-tool-restrictions.md`; literature:
  `project/literature/domain/literature-index.md`).
- 1 `gate3` "Rule S" project-wide finding: `context/contracts/return-meta-artifacts-template.md`
  has no `index.json` entry.
- A cluster of `gate8` test-suite failures unrelated to mint-dispatch-seq: a "single-source
  assertion" failure (inline `sess_$(date...)` generation found outside `lib/common.sh` in three
  other test files) and two `validate-return-meta.sh` fix-roundtrip failures. These are
  pre-existing and should be re-examined post-deploy on their own merits, not attributed to this
  task.

**`system-defect-record.sh` non-zero exit — investigated and explained, not a defect.** Both the
deployed (`.claude/scripts/system-defect-record.sh`) and source
(`agent-system/extensions/core/scripts/system-defect-record.sh`) copies are present and match
their respective call sites in `skill-base.sh` (lines ~401, ~791), each of which passes all
required flags. Running the script bare (no arguments) — as the orchestrator apparently did —
prints the usage banner and exits 1, which the script's own documented exit-code table names as
"1 argument error." This is expected CLI behavior, not evidence the script is missing, drifted,
or broken. No drift or bug found here.

### 2. Premise confirmation

All three confirmed by direct inspection, not by re-trusting the task description:

- **(a) mcp-server-ownership.md**: `diff -q` between
  `.claude/context/patterns/mcp-server-ownership.md` and
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` reports no difference
  (byte-identical), file size 18,827 B as the description states.
- **(b) stale grant present/absent as claimed**: `grep -n "lean-lsp" .claude/settings.json` hits
  line 188 (`"mcp__lean-lsp__*"`); the same grep against
  `agent-system/extensions/core/root-files/settings.json` returns no match.
- **(c) install-once semantics real, verified in code**: `lua/neotex/plugins/ai/shared/extensions/loader.lua`
  defines `INSTALL_ONCE_ROOT_FILES = { ["settings.json"] = true, ["settings.local.json"] = true }`
  (line 134), exposes it as `M.INSTALL_ONCE_ROOT_FILES`, and `CATEGORY_DESCRIPTORS.root_files`
  wires `install_once = INSTALL_ONCE_ROOT_FILES` (line 231); the copy loop at line 476 skips
  copying when `descriptor.install_once[entry_name]` is true AND the target file already exists.
  `lua/neotex/plugins/ai/shared/extensions/init.lua` (the `manager.unload`/`reload` module)
  references `loader_mod.INSTALL_ONCE_ROOT_FILES` at lines 770/776 to exclude these files from
  deletion during unload, and reports an explicit `"%d preserved (settings install-once)"` count.
  This fully substantiates the description's claim about `loader.lua`/`manager.unload`/
  `CATEGORY_DESCRIPTORS`.

### 3. Tasks that become live at this deploy

Traced via `specs/TODO.md` task directories (all `[COMPLETED]`):

- **Task directory `065_fix_mint_dispatch_seq_persisted_counter`** — "Fix mint dispatch seq
  persisted counter." Fixes `skill_orchestrate_mint_dispatch_seq` in `skill-base.sh` to derive
  the new sequence value by reading `.dispatch_seq_counter` back out of the loop-guard file
  (`jq -r '(.dispatch_seq_counter // 0) + 1'`) instead of an ambient shell variable that
  collapses to 0 in any fresh shell/subprocess. Deployed `skill-base.sh` still has the old
  ambient-variable body; the deployed script's own regression test
  (`scripts/tests/test-mint-dispatch-seq.sh`, itself never-deployed) demonstrates the failure
  live against the deployed file (Cases C/D/E/F in the captured baseline below).
- **Task directory `069_harden_conversion_quality_gate_against_mojibake`** — HIGH severity,
  corpus-corruption vector. Hardens the literature conversion quality gate
  (`literature-convert.sh` / `literature_quality_gate.py`) to detect control-character/mojibake
  PDF-extraction output (printable-character ratio, NUL-byte check, two-sided word-ratio band)
  so an unextractable PDF fails on every conversion tier instead of silently passing garbage into
  the global corpus and FTS index on the pymupdf fallback tier, while preserving that fallback
  tier for genuinely rescuable PDFs.
- **Task directory `070_fix_discover_tier_starvation_and_silent_tier3_failure`** — MEDIUM
  severity. Fixes `literature-discover.sh`: Tier 3 (Semantic Scholar) failures were silently
  swallowed (`2>/dev/null || true`), and Tier 1 local-corpus hits could starve Tiers 2/3 under the
  default limit. Adds visible failure notices and reserved per-tier quotas.
- **Task directory `071_fix_validate_directory_path_false_positives_and_flag_mismatch`** — LOW
  severity. Fixes `skill-literature` validate mode's `[ ! -f "$full" ]` check to branch on `-d`
  for directory-path entries (was reporting 65/368 entries falsely stale), plus a
  `--dry-run` flag/doc mismatch in `literature-normalize-authors.sh`.

For a future `CHANGE_LOG` entry (respecting the no-task-numbers-outside-`specs/**` rule): cite
these by their durable anchor — the mint-dispatch-seq persisted-counter fix in
`scripts/skill-base.sh`, and the three literature hardening fixes to the conversion quality gate,
the discovery tier-starvation/silent-failure fix, and the validate-mode directory-path fix —
rather than by task number.

### 4. PRE-deploy `verify-deploy.sh --findings --quiet` baseline (verbatim)

Captured at 2026-08-24T21:0x UTC, BEFORE any deploy ran. `run-all.sh` (invoked internally as part
of this check) took several minutes; the full run completed cleanly and is reproduced exactly
below, byte for byte, for the implementation phase's before/after diff:

```
  [FAIL] doc-lint reported failures
         re-run without --quiet for detail: bash .claude/scripts/check-extension-docs.sh
  [FAIL] manifest-driven verification reported 11 finding(s)
         re-run without --quiet for detail: bash .claude/scripts/verify-deploy.sh
  [FAIL] run-all.sh reported failing or undiscoverable suites (exit 1)
         re-run for detail: bash agent-system/extensions/core/scripts/tests/run-all.sh
[verify-deploy] FAIL -- 3 of 23 check(s) failed
FINDING gate3 [core] FAIL: deployed script content drift (deployed != extension source): scripts/skill-base.sh
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'architecture/context-layers.md' line_count mismatch: declared 219, actual 221
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'patterns/batch-orchestration-guardrails.md' line_count mismatch: declared 737, actual 812
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'patterns/file-footprint-overlap.md' line_count mismatch: declared 194, actual 202
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'patterns/file-metadata-exchange.md' line_count mismatch: declared 305, actual 314
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'patterns/regeneration-is-manual-only.md' line_count mismatch: declared 210, actual 259
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'patterns/skill-postflight-flow.md' line_count mismatch: declared 126, actual 177
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'reference/orchestrator-critical-paths.json' line_count mismatch: declared 70, actual 74
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'schemas/state-schema.json' line_count mismatch: declared 262, actual 267
FINDING gate3 [core] FAIL: Rule R: index-entries.json entry 'standards/postflight-tool-restrictions.md' line_count mismatch: declared 216, actual 219
FINDING gate3 [literature] FAIL: deployed script content drift (deployed != extension source): scripts/literature-convert.sh
FINDING gate3 [literature] FAIL: deployed script content drift (deployed != extension source): scripts/literature-discover.sh
FINDING gate3 [literature] FAIL: deployed script content drift (deployed != extension source): scripts/literature-normalize-authors.sh
FINDING gate3 [literature] FAIL: deployed script content drift (deployed != extension source): scripts/tests/generate-test-fixtures.py
FINDING gate3 [literature] FAIL: deployed script content drift (deployed != extension source): scripts/tests/test-literature-convert.sh
FINDING gate3 [literature] FAIL: Rule R: index-entries.json entry 'project/literature/domain/literature-index.md' line_count mismatch: declared 144, actual 117
FINDING gate3 [project-wide] FAIL: Rule S: deployed context/contracts/return-meta-artifacts-template.md has no entry in .claude/context/index.json
FINDING gate5 core: Content differs from source: context/patterns/regeneration-is-manual-only.md
FINDING gate5 core: Content differs from source: scripts/skill-base.sh
FINDING gate5 core: Missing scripts: scripts/tests/test-mint-dispatch-seq.sh
FINDING gate5 literature: Content differs from source: commands/literature.md
FINDING gate5 literature: Content differs from source: scripts/literature-convert.sh
FINDING gate5 literature: Content differs from source: scripts/literature-discover.sh
FINDING gate5 literature: Content differs from source: scripts/literature-normalize-authors.sh
FINDING gate5 literature: Content differs from source: scripts/tests/generate-test-fixtures.py
FINDING gate5 literature: Content differs from source: scripts/tests/test-literature-convert.sh
FINDING gate5 literature: Content differs from source: skills/skill-literature/SKILL.md
FINDING gate5 literature: Missing scripts: scripts/literature_quality_gate.py
FINDING gate8     [FAIL] Case B: expected persisted .dispatch_seq_counter 3, got '1'
FINDING gate8     [FAIL] Case C: expected persisted .dispatch_seq_counter 6, got '100'
FINDING gate8     [FAIL] Case C: expected stdout 6 (guard wins over ambient=99), got '100'
FINDING gate8     [FAIL] Case D: expected first subprocess stdout 11, got '1'
FINDING gate8     [FAIL] Case D: expected second subprocess stdout 12, got '1'
FINDING gate8     [FAIL] Case E: expected persisted .dispatch_seq_counter 38, got '37'
FINDING gate8     [FAIL] Case E: expected stdout 38, got ''
FINDING gate8     [FAIL] Case F: expected persisted .dispatch_seq_counter 1, got 'null'
FINDING gate8     [FAIL] Case F: expected stdout 1, got ''
FINDING gate8     [FAIL] fix-roundtrip: --fix run exited 1 (expected 0) -- see /tmp/tmp.K0O2cXjc2K/fix-apply.out
FINDING gate8     [FAIL] fix-roundtrip: repaired file exited 1 on independent re-validation (expected 0) -- see /tmp/tmp.K0O2cXjc2K/fix-after.out
FINDING gate8     [FAIL] single-source assertion: inline sess_$(date generation found outside lib/common.sh:
FINDING gate8 /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-common-lib.sh
FINDING gate8 /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-mint-dispatch-seq.sh
FINDING gate8 /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh
FINDING gate8 /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh
FINDING gate8     [PASS] common_test_fail emits '[FAIL] <msg>'
```

Note this is a `> FILE 2>&1` capture with no `| grep '^FINDING '` filtering applied, so it
includes the narrative PASS/FAIL summary lines the tool's own docs describe as preceding the
`FINDING` lines — useful here for full auditability, but the implementation phase's *diff*
against the POST-deploy capture should follow the tool's documented consumer pattern
(`grep '^FINDING ' | sort -u`) to avoid false deltas from narrative-line reordering.

The `gate8 Case B` failure (`expected persisted .dispatch_seq_counter 3, got '1'`) appeared only
in this later, complete capture and not in an earlier truncated read taken mid-run; the
implementation phase should treat the full 52-line capture above (not any earlier partial read)
as the authoritative pre-deploy baseline.

### 5. Deferred decisions — settle vs. defer assessment

**(a) lean-lsp registered at user scope, pointing at a different repository.**
Confirmed via `claude mcp list`:
```
lean-lsp: /home/benjamin/Projects/BimodalLogic/.claude/scripts/lean-lsp-mcp-wrapper.sh --lean-project-path /home/benjamin/Projects/BimodalLogic - ✔ Connected
```
This is registered globally (user scope) but hardcodes a path into a different repository
(`BimodalLogic`), so any OTHER project relying on user-scope `lean-lsp` registration would get a
wrongly-scoped server. **Recommendation: DEFER**, but not indefinitely — this is a real,
reproducible bug class (user-scope registration used for a fundamentally per-project resource),
and the task description itself names the fix direction ("moving it to the new project-scoped
mechanism"). It is out of scope for a deploy-and-remediate task because fixing it means either
re-registering the MCP server (an operator action outside `.claude/` source-store edits) or
building/wiring the project-scoped registration mechanism (a separate, nontrivial task). Settling
it here would scope-creep task 32 well beyond "redeploy + remove one stale grant."

**(b) nine playwright grants duplicated between web and present settings fragments.**
Confirmed via direct inspection: both `agent-system/extensions/web/settings-fragment.json` and
`agent-system/extensions/present/settings-fragment.json` grant the identical 9 tools
(`browser_click`, `browser_console_messages`, `browser_find`, `browser_navigate`,
`browser_network_requests`, `browser_snapshot`, `browser_take_screenshot`, `browser_type`,
`browser_wait_for`). **Recommendation: DEFER**, per the description's own framing — this is
harmless duplication (both extensions grant permissions they each independently need; an additive
deep-merge just makes the redundancy visible, not broken) and the description explicitly warns
not to "break working grants chasing tidiness." The clean fix (grant playwright tools once at
machine scope in the NixOS configuration, per the grant-at-registration-scope rule) is a
NixOS-side task, not a `.claude/`-source-store edit, and is naturally out of scope here.

### 6. Risk of deploying the entire source store

Deploying the entire source store via `deploy-headless.sh` is **low risk** here, and the
description's "133 commits" framing overstates the exposure:

- Only 12 of the 44 commits since the last deploy (16 files) touch `agent-system/` at all — the
  remainder is `specs/` task-management churn (TODO.md, state.json, task directories) that
  `deploy-headless.sh` never reads, since it deploys from the `agent-system/extensions/**` source
  store, not the whole repository.
- All 16 deploy-relevant files trace cleanly to the four completed, `[COMPLETED]`-marked tasks
  identified in Section 3 above — none of the pending drift belongs to an in-flight, uncommitted,
  or unrelated task. There is no risk of deploying half-finished work mixed in with these fixes.
- The one genuine residual risk: `verify-deploy.sh` gate5 does not compare `manifest.json` content
  or all context-pattern docs (see the "changed but not gate5-checked" row in Section 1), so a
  clean POST-deploy `verify-deploy.sh --findings` pass would not, by itself, prove those 3 files
  deployed correctly — a direct `diff` against source (as this report performed by hand) remains
  worthwhile for those three specifically, or as a general follow-up to widen gate5's coverage.
- The `gate3` "Rule R" index-entries.json line-count mismatches (10 files, all pre-existing) and
  the `gate8` single-source-assertion / fix-roundtrip failures are unrelated to this deploy's
  payload and will very likely persist unchanged after deploying task 32's payload — the
  implementation phase should confirm they are byte-identical pre/post (not newly introduced)
  rather than treating a nonempty POST-deploy findings set as a failure signal in itself.

## Decisions

- Baseline capture method: `verify-deploy.sh --findings --quiet` full un-filtered output (52
  lines) is the authoritative PRE-deploy artifact for this task, captured in Section 4 above and
  reproduced byte-for-byte — the implementation phase should diff the POST-deploy capture against
  this exact text (after `grep '^FINDING ' | sort -u` on both sides per the tool's documented
  consumer pattern) rather than re-deriving a new baseline.
- `system-defect-record.sh`'s earlier nonzero exit is explained as expected CLI usage-error
  behavior on a bare invocation, not a defect; no further investigation of that script is
  warranted.
- Both deferred decisions (lean-lsp user-scope mis-registration; duplicated playwright grants) are
  recommended DEFER, each with the specific reason given in Section 5, not blanket punting.

## Risks & Mitigations

- **Risk**: post-deploy `verify-deploy.sh` still reports findings (it will — the pre-existing
  index-entries.json line-count mismatches and gate8 unrelated failures are not part of this
  task's payload and will not be fixed by this deploy). **Mitigation**: diff the POST-deploy
  `FINDING` set against the verbatim PRE-deploy set above; only a truly NEW finding (absent from
  the list in Section 4) is a genuine regression signal.
- **Risk**: hand-editing `.claude/settings.json` to remove the stale `mcp__lean-lsp__*` grant will
  trip the `source-store-boundary` advisory hook (expected, per the task description) —
  mitigation is procedural: record the install-once reasoning in the implementation summary
  rather than "fixing" the warning by editing the source copy (which is already correct and must
  not be touched).
- **Risk**: a fresh Claude Code session is required to observe MCP registration changes (the
  current session cannot self-verify this). **Mitigation**: the implementation/verification phase
  should explicitly note this as a manual follow-up check outside the current session's ability
  to self-verify.
- **Risk**: `gate5`'s blind spot on `manifest.json` and some context docs (3 files) means a clean
  `verify-deploy.sh` pass alone will not prove those specific files deployed. **Mitigation**: spot
  `diff` those 3 files by hand post-deploy (as this report did pre-deploy) rather than relying on
  `verify-deploy.sh` alone for them.

## Context Extension Recommendations

- **Topic**: `verify-deploy.sh` gate5 coverage
- **Gap**: gate5 ("deployed vs source" content check) does not compare `manifest.json` files or
  all context-pattern docs, so genuine drift in those files (observed directly here — both core
  and literature `manifest.json`, plus one literature pattern doc) is invisible to the automated
  gate and requires manual `diff`.
- **Recommendation**: consider widening gate5 (or adding a dedicated gate) to include
  `manifest.json` and context-pattern-doc content comparison, so a clean `verify-deploy.sh` run
  becomes a stronger guarantee. This is an improvement to `verify-deploy.sh` itself, not something
  to build inside task 32.

## Appendix

Commands used (all read-only; no deploy run, no `.claude/**` file modified):
- `diff -q .claude/context/patterns/mcp-server-ownership.md agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `grep -n "lean-lsp" .claude/settings.json` / `agent-system/extensions/core/root-files/settings.json`
- `grep -n "install_once\|INSTALL_ONCE_ROOT_FILES\|CATEGORY_DESCRIPTORS" lua/neotex/plugins/ai/shared/extensions/{loader,init}.lua`
- `git log --oneline --since="2026-08-17 21:36:34 -0700"` (repo-wide and scoped to `agent-system/`)
- `git log --since=... --name-only --pretty=format: -- agent-system/ | sort -u`
- `find .claude -type f -not -path "*/tmp/*" -printf '%T@ %p\n' | sort -rn` (deploy-batch mtime clustering)
- `bash .claude/scripts/verify-deploy.sh --findings --quiet` (captured verbatim, Section 4)
- `bash .claude/scripts/check-extension-docs.sh` (doc-lint detail, corroborates gate3 findings)
- `bash .claude/scripts/system-defect-record.sh` (bare invocation, confirms usage-error exit 1)
- `claude mcp list | grep -i lean` (confirms user-scope BimodalLogic registration)
- `jq -r '.. | strings | select(test("playwright"))' agent-system/extensions/{web,present}/settings-fragment.json`
- Manual per-file `diff -q` reconciliation of all 16 changed `agent-system/` files against their
  deployed counterparts (Section 1 table)
