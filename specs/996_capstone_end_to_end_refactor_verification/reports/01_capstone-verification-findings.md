# Research Report: Capstone acceptance gate — end-to-end verification of the refactored agent system

- **Task**: 996 - Capstone: end-to-end verification of the refactored agent system
- **Started**: 2026-08-10T00:57:00Z
- **Completed**: 2026-08-10T08:14:00Z
- **Effort**: ~4 hours (live command execution, scratch-tree deploy tests, code reading)
- **Dependencies**: 985, 986, 993, 995, 999
- **Sources/Inputs**: `agent-system/extensions/core/scripts/deploy-headless.sh`, `verify-deploy.sh`,
  `install-extension.sh`, `lib/file-scope-overlap.sh`, `system-defect-record.sh`,
  `validate-handoff-location.sh`, `skill-orchestrate/SKILL.md`, `lua/.../extensions/verify.lua`,
  `lua/.../extensions/config.lua`; live execution of `check-extension-docs.sh`,
  `validate-state.sh --deep`, `check-task-references.sh`, `verify-deploy.sh --findings`,
  `tests/run-all.sh` (both source-store and deployed copies); two scratch-tree deploy runs under
  `/tmp/.../scratchpad/` (destroyed after comparison, never touched the live `.claude/`)
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- Of the four **GATES** sub-requirements, 3 of 4 pass live today (`check-extension-docs.sh`,
  `validate-state.sh --deep`, `check-task-references.sh`); the fourth (`run-all.sh` green) fails,
  and `verify-deploy.sh --findings` confirms the batch's own claim exactly: **22/23** (1 of 23
  checks failed, that one check being the shell test-suite gate).
- The **DEPLOY** scope's "byte-identical twice" requirement **fails on direct test**: two
  consecutive `--wipe` runs against the same scratch target produced different `context/index.json`
  (non-deterministic key/array order plus a wall-clock timestamp), different `settings.json`
  (non-deterministic hook-array order), and — more seriously — a **content-lossy** difference in
  `settings.local.json` (one run silently dropped an entire hooks block and an MCP-server block
  the other run had). This is a new finding, not previously named in the batch's leads.
  "Declared-vs-deployed parity + hash equality" (gate 5 / `verify.lua`) **passes today**, but only
  because it is a one-directional check (declared → present, never deployed → declared); it has no
  mechanism to catch the GHOST orphan files, so the "PASS" verdict coexists with real orphan drift.
- All 6 of the batch's "live findings" leads are **confirmed as literally true** by direct
  code-reading and/or execution, with two of them turning out worse than described: the GHOST
  index entries are not just stale index.json rows but two actual orphaned files
  (`context/orchestration/orchestration-validation.md`, `context/orchestration/subagent-validation.md`)
  plus two more orphans not previously named (`docs/architecture/architecture-spec.md`,
  `docs/README.md`); and `run-all.sh` has a **7th, previously-unreported failure**
  (`test-common-lib.sh`) distinct from the "5 path-depth + 1 EXTENSION.md" description.
- The 3-digit task-number regex bug in `validate-handoff-location.sh` is not hypothetical: `next_project_number` is already **1007**, so every task ≥1000 (999 excepted — 3-digit) trips it going forward.
- The multi-task session-ID mismatch in `skill-orchestrate` (Stage MT-1 registers bare
  `$session_id`; Stage MT-4 acquires `${session_id}_${task_num}`) is confirmed by direct line
  citation and, combined with `session_contention()`'s exact-string self-exclusion, is a real,
  structural block on multi-task `/orchestrate` batches — not exercised live in this dispatch
  (blast-radius/cost), but the code path is unambiguous.
- **LIVE CYCLE** scope was **not exercised end-to-end** in this research dispatch (spinning a real
  scratch-task `/orchestrate` cycle mutates state and consumes real agent dispatches — judged
  out of scope for a read-only verification pass). The one sub-item that a static check already
  covers — "routing resolution yields an agent file that exists on disk for every task_type" — is
  effectively verified via `lint-routing-wiring.sh` (verify-deploy.sh gate 7, PASS). The remaining
  LIVE CYCLE sub-items (handoff schema validity, gate-out zero-repair, clean-run defect-recorder
  silence) are unverified either way.

## Context & Scope

This is the composed-system capstone verification gate: task 996 fixes nothing itself, only
records findings for follow-up. This report characterizes exactly how much of the declared
verification scope (DEPLOY / GATES / LIVE CYCLE) passes today, against the six numbered leads
supplied in the delegation context from the batch that landed immediately before this dispatch
(985/986/993/995/999 and siblings). Every claim below was independently checked — live command
execution where safe and cheap, direct source-line citation where execution was infeasible or
risky (multi-task `/orchestrate`, a full live cycle).

## Findings

### DEPLOY scope

1. **Wipe+regenerate to scratch succeeds — PASS.** `deploy-headless.sh --wipe TARGET` accepts an
   arbitrary `TARGET_REPO`; `global_extensions_dir` is hardcoded to
   `~/.config/nvim/agent-system/extensions` in `lua/neotex/plugins/ai/shared/extensions/config.lua:66`
   independent of TARGET, so a scratch-dir run is a valid test without cloning the whole repo. Ran
   it against a fresh scratch git repo seeded with the live `.claude-extensions.json` (5 active
   extensions: nvim, nix, core, memory, email — confirmed via `jq` on the live file). Result:
   clean run, `DEPLOY_COUNT=5`, 445 files.

2. **Byte-identical twice — FAIL, directly reproduced.** Ran `--wipe` twice on the identical
   scratch target and diffed the two resulting `.claude/` trees:
   - `context/index.json`: a `"generated": "<ISO8601>"` timestamp differs (expected/cosmetic), but
     more significantly, **key order and array order inside every index entry differ between
     runs** (e.g. `keywords`/`summary`/`domain` fields reordered) — genuine non-determinism, most
     likely Lua table/hash iteration order leaking into JSON encoding without a sort step.
   - `settings.json`: hook-array order and per-hook key order differ between the two runs
     (same class of bug).
   - `settings.local.json`: **not just reordered — actually lossy.** One run was missing an
     entire `hooks.PreToolUse` (mail-guard) block and the `mcpServers.obsidian-memory` block that
     the other run had. This reads as a merge race/drop across extensions' settings-local
     fragments, not cosmetic key reordering, and is the most serious DEPLOY finding in this report.

3. **Declared-vs-deployed parity + content-hash equality, every `provides.*` category —
   PASSES TODAY, with a documented blind spot.** `verify-deploy.sh`'s gate 5 (backed by
   `lua/neotex/plugins/ai/shared/extensions/verify.lua`) reports PASS live. Reading `verify.lua`
   confirms why this coexists with orphan drift: its result shape is
   `{checked, missing, hash_mismatch, protected}` — there is no `extra`/`orphan` field anywhere in
   the file. Every check iterates the DECLARED side (source manifests / index-entries) and asks
   "is this present and hash-matching in the deployed tree?" — it never walks the deployed tree
   looking for content that is not declared anywhere. This is why the GHOST entries (next
   paragraph) exist without failing gate 5.

4. **GHOST orphan files — CONFIRMED, and larger than described.** Diffing the live deployed
   `.claude/` against a fresh scratch regenerate (same 5-extension set) found, present in the live
   tree but **absent** from a clean regenerate:
   - `context/orchestration/orchestration-validation.md`
   - `context/orchestration/subagent-validation.md`
   - `docs/architecture/architecture-spec.md` (not previously named in the batch leads)
   - `docs/README.md` (not previously named in the batch leads)

   These are actual orphaned **files**, not merely stale `index.json` rows. `install-extension.sh`'s
   `merge_index_entries()` (line 179) is confirmed purely additive — `.entries += (...)` at line
   207, no corresponding subtractive/stale-removal step anywhere in the file. This makes the
   DEPLOY scope's "declared-vs-deployed parity... for EVERY provides.* category" requirement
   unsatisfiable **as a bidirectional guarantee** — only self-healable by manual deletion or a new
   subtractive-merge feature. As currently implemented (one-directional), the requirement is
   satisfied; as most readers would interpret "parity," it is not.

5. **Protected files / `.syncprotect` — PASS.** `.syncprotect` exists at repo root, lists
   `context/repo/project-overview.md`. `deploy-headless.sh`'s `--wipe` path snapshots
   `.syncprotect`-listed paths plus `settings.json`/`settings.local.json` before `rm -rf .claude`
   and restores them across the deletion (per script header). Live tree correctly retains
   `project-overview.md`. `settings.local.json` does survive the round-trip, but see finding 2 —
   its content is not stably reproduced run-to-run.

6. **No quarantined/deprecated file in deployed tree — PASS.** Source store has
   `agent-system/extensions/core/scripts/deprecated/` and a literature-extension `deprecated/`
   dir; `find .claude -path '*deprecated*'` on the live deployed tree returns nothing.

### GATES scope

All four commands were actually run against the live repo (not merely inspected):

| Requirement | Result |
|---|---|
| `check-extension-docs.sh`, hardened defaults, no env overrides | **PASS**, exit 0. All 20 extensions report Extension-Status PASS; only advisory WARN/ADVISORY noise (README-older-than-manifest drift warnings, undeployed literature zotero scripts) that "does NOT affect the PASS/FAIL verdict" per the script's own banner. |
| `validate-state.sh --deep` | **PASS**, exit 0, 14 passed / 0 warnings / 0 failed, including all 6 `--deep` invariants (TODO.md/state.json sync, no self-referential/dangling/cyclic dependencies, no terminal-status immutability violations). |
| `check-task-references.sh` (repo-wide) | **PASS**, exit 0, 0 unexempted occurrences across all 4 scanned trees (`agent-system/extensions`, `.opencode`, `lua`, `.memory`). |
| `tests/run-all.sh` green | **FAIL.** See below — confirmed pre-existing but with one previously unreported failure. |

**`verify-deploy.sh --findings` (all 12 documented gates, gate0-gate12 = 13 named checks but the
tool itself reports 23 total sub-checks)**: **FAIL — 1 of 23 check(s) failed**, exactly matching
the batch's "22/23" claim. The single failing gate is gate 8, the shell-test-suite runner; every
other gate (event/error-store files, hook registration, doc-lint, task-reference lint, the
manifest parity+hash gate, agent-contracts lint, routing-wiring lint, postflight-boundary lint,
state-schema validation, contract-compliance lint, state-writer-boundary lint) is a clean PASS.

**`run-all.sh` deep-dive — confirmed pre-existing, but incompletely described by the batch leads.**
Ran BOTH copies directly:

- **Source-store copy** (`agent-system/extensions/core/scripts/tests/run-all.sh`): 36 total
  suites, **34 passed, 2 failed**:
  1. `test-index-entries-schema.sh` — "Rule U did not fire on a 61-line EXTENSION.md" (the
     EXTENSION.md length-assertion bug named in the batch leads).
  2. `test-four-tier-conflict.sh` — "Tier-2 resolving case -- rc=2 ... task 501's lock is held by
     another session; waiting up to 5000ms and retrying." This is **flaky, caused by real lock
     contention from other concurrently-running agent sessions active in this same repo right
     now** (this research dispatch ran alongside several other named sibling agents per the
     session's active-agent list) — not a deploy defect, but worth noting as evidence that
     `task-lock.sh` contention logic is genuinely exercised under concurrency, live, in this
     environment.
- **Deployed copy** (`.claude/scripts/tests/run-all.sh`): 33 total suites, **26 passed, 7 failed**:
  the same EXTENSION.md failure, **plus 5 suites failing on a `REPO_ROOT` path-depth resolution
  bug** (`test-loop-guard-staleness.sh`, `test-reconcile-handoff-status.sh`,
  `test-resume-scan-nonconformance.sh`, `test-skill-base-lifecycle.sh`,
  `test-update-task-status.sh` — each either can't find a source-store file it expects at
  `/home/benjamin/agent-system/...` (missing the `.config/nvim` path segment) or can't find the
  deployed tree at `/home/benjamin/.claude/scripts` for the same reason), **plus a 7th, previously
  unreported failure**: `test-common-lib.sh`'s single-source assertion flags
  `.opencode/scripts/command-gate-in.sh` for an inline `sess_$(date +%s)_...` session-ID generator
  that duplicates `lib/common.sh`'s canonical generator — this test PASSES in source-store mode
  and only fails in deployed mode, meaning it is either the same REPO_ROOT-resolution class of bug
  manifesting differently, or a genuine migration gap from task-history context (`lib/common.sh`'s
  session-ID canonicalization migrated Claude-Code-side scripts but not the parallel `.opencode/`
  tree's `command-gate-in.sh`). Either way it is a real, currently-failing, distinct-from-the-named-5
  failure that the batch's lead description did not capture.
  Git history confirms both the path-depth-affected tests and `lib/common.sh`'s session-ID
  migration predate this immediate batch (995/999/1001-1003) — this is pre-existing, not newly
  introduced.

### The six batch leads — verification verdicts

1. **verify-deploy.sh 22/23, pre-existing** — CONFIRMED exactly (see GATES section above), with
   the caveat that the actual `run-all.sh` failure set is larger and more varied than "path-depth
   bug × 5 + EXTENSION.md × 1" (see the 7th failure above, and the flaky lock-contention failure
   in source-store mode).
2. **Deploy consistency after task 995's gate-12 addition and `deploy-headless.sh` run** —
   `lint-state-writer-boundary.sh` is present and passing as gate 12 in the live
   `verify-deploy.sh --findings` run (confirmed above). The deploy is "consistent" in the sense
   verify-deploy.sh's own parity gate checks, but see DEPLOY findings 2 and 4 above for the two
   respects (non-determinism, orphan files) in which "consistent" does not mean byte-stable or
   fully congruent with source.
3. **GHOST index entries make declared-vs-deployed parity unsatisfiable** — CONFIRMED, and shown
   to be two more files than named (4 orphans total, not 2), plus the precise mechanical reason
   (`verify.lua`'s one-directional check design, `merge_index_entries()`'s purely-additive merge).
4. **`validate-handoff-location.sh`'s `[0-9]{3}` regex breaks past task 999** — CONFIRMED by
   direct regex reading (line 65: `'(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$'`)
   — the fixed-position `{3}` immediately before a literal `_` cannot match any 4+-digit task
   number's path. `next_project_number` is already 1007, so this is live, not hypothetical.
5. **Multi-task `task-lock.sh acquire` self-contention bug** — CONFIRMED by direct line citation:
   Stage MT-1 (`skill-orchestrate/SKILL.md:1418`) registers
   `session-register "$session_id" ...` (bare); Stage MT-4 (line 1960) acquires with
   `task-lock.sh acquire "$task_num" "$op" "${session_id}_${task_num}" ...` (suffixed).
   `session_contention()`'s self-exclusion (`lib/file-scope-overlap.sh:109-114`) is
   `select($sess.session_id != $own_sid)` — exact string match, so the suffixed acquire-time ID
   never matches the bare registered ID, and the batch's own session is treated as a foreign
   contender on every task's lock acquire. Not exercised live (a multi-task `/orchestrate` run
   is expensive and mutates state); the code path is unambiguous enough that live reproduction
   was judged unnecessary to confirm the defect.
6. **`system-defect-record.sh`'s ten-class vocabulary has no class for lock/session, hook-regex,
   plan-marker-drift, or deploy-ghost-entry defects** — CONFIRMED by reading the closed enum at
   `system-defect-record.sh:161-163`: `OFF_SCHEMA_STATUS`, `ARTIFACTS_SHAPE_MISMATCH`,
   `HANDOFF_MISLOCATED`, `META_MISSING_AFTER_NARRATION`, `ARTIFACTS_MISSING_ON_SUCCESS`,
   `HANDOFF_STALE_OR_ABSENT`, `SOURCE_STORE_BOUNDARY_VIOLATION`, `TASK_REFERENCE_IN_DELIVERABLE`,
   `ARTIFACT_FORMAT_VIOLATION`, `STATE_SYNC_DIVERGENCE`. None of these is a fit for any of the
   three genuinely-new defect classes this very research surfaced (lock/session-ID mismatch,
   task-number regex, deploy orphan-file drift) — confirming the taxonomy gap has real, current
   instances to point to, not just hypothetical ones.

### LIVE CYCLE scope — not exercised

A real scratch-task `/orchestrate` cycle was not run in this dispatch: it mutates `specs/state.json`
and the session registry, dispatches real subagents, and (per lead 5) a **multi-task** cycle would
currently fail outright on the lock bug — but the capstone's literal wording asks for "**one**
scratch-task" cycle (single-task), which does not traverse Stage MT-4's batch codepath at all and
is not known to be blocked. Given the cost and blast-radius of a live cycle versus the read-only
nature of this research dispatch, only the sub-items checkable statically were verified:
- "Routing resolution yields an agent file that exists on disk for every task_type declared in any
  loaded manifest" — effectively covered by `lint-routing-wiring.sh` (verify-deploy.sh gate 7),
  which is currently PASS.
- Handoff schema validity, gate-out zero-format-errors/zero-auto-repairs, and system-defect-recorder
  silence-on-clean-run are **unverified** either way — they require an actual cycle to observe and
  were not attempted here.

## Decisions

- Treated `verify-deploy.sh`'s gate 5 PASS and the GHOST-orphan-file FAIL as complementary facts,
  not a contradiction: the capstone's DEPLOY wording ("declared-vs-deployed parity... for EVERY
  provides.* category") is satisfied by the existing one-directional implementation, but not by a
  bidirectional reading a reasonable engineer would expect from the word "parity."
- Did not attempt to fix any of the five confirmed defects (regex, lock/session, orphan files,
  non-determinism, missing defect-taxonomy classes) — task 996 fixes nothing structural per its own
  description; that is plan/implement-phase or follow-up-task work.
- Did not run a live `/orchestrate` cycle (single- or multi-task) given cost and state-mutation
  concerns for a read-only research dispatch; recommend this be the first live action in this
  task's plan/implement phase, on a genuinely disposable scratch task number, single-task mode only.

## Recommendations

1. **Highest priority — fix `validate-handoff-location.sh`'s regex** (`[0-9]{3}` → `[0-9]{3,}` or
   equivalent) before more tasks cross 1000; it is already firing falsely today.
2. **Fix the Stage MT-1 / Stage MT-4 session-ID mismatch** in `skill-orchestrate/SKILL.md` (either
   register under the suffixed ID per task, or acquire under the bare ID) — this fully blocks
   multi-task `/orchestrate`, a documented, advertised capability.
3. **Investigate the `settings.local.json` content-lossy merge** found in DEPLOY finding 2 — this
   is the most consequential of the newly-found defects since it can silently drop a hook or MCP
   server registration on a routine redeploy, with no error surfaced.
4. **Decide whether index.json/settings.json non-determinism is worth fixing** (sort merge output
   deterministically) — low risk today (JSON semantics are order-independent for most consumers)
   but it defeats any future byte-identical-diff-based verification.
5. **Add a subtractive/orphan-detection pass** to the index-entries and docs merge (or accept and
   document that "parity" is one-directional by design) — otherwise the 4 orphan files found here
   will only grow over time as the source store evolves.
6. **Fix `test-common-lib.sh`'s newly-found 7th `run-all.sh` failure** — migrate
   `.opencode/scripts/command-gate-in.sh`'s inline session-ID generator to the canonical source
   (or explicitly exempt `.opencode/` from the single-source scan if that tree is intentionally
   independent of `lib/common.sh`).
7. **Add defect-taxonomy classes** to `system-defect-record.sh` for at least: lock/session
   contention, hook-regex/path-depth boundary bugs, and deploy orphan-file drift — three concrete
   instances now exist to ground the new classes' definitions.
8. Given the volume of confirmed, distinct defects (8 total: regex bug, MT lock bug, 4 orphan
   files, non-deterministic merge ×2 forms including one lossy, 7th run-all failure, missing
   defect classes), this capstone task will very likely need `errors.json` entries and/or several
   spawned follow-up tasks rather than a single fix — consistent with its own "fixes nothing
   structural itself" framing.

## Risks & Mitigations

- **Risk**: fixing the MT-1/MT-4 session-ID mismatch changes multi-task lock semantics broadly.
  **Mitigation**: the fix is narrow (one of the two sites' ID string) and the existing
  `test-four-tier-conflict.sh`/`test-conflict-predicate.sh` suites already assert on
  `session_contention()`'s self-exclusion behavior, so a fix should be covered by existing tests
  plus a new multi-task-specific regression case.
- **Risk**: the `settings.local.json` lossy-merge finding was observed on a scratch repo lacking
  the live repo's exact history; it is possible (though the two runs were on the identical target
  with no changes between them) that this is itself a flake rather than deterministic. **Mitigation**:
  re-run the same two-consecutive-wipe test at plan/implement time to confirm reproducibility
  before spending fix effort.

## Appendix

- Live commands run: `check-extension-docs.sh` (exit 0), `validate-state.sh --deep` (exit 0, 14
  passed), `check-task-references.sh` (exit 0, 0 findings), `verify-deploy.sh --findings` (FAIL,
  1 of 23), `tests/run-all.sh` both copies (source-store: 34/36 passed; deployed: 26/33 passed).
- Scratch-tree deploy tests were run under this session's scratchpad directory and deleted after
  comparison; the live `.claude/` tree was never modified by this research.
- `next_project_number` at time of writing: 1007 (`jq -r '.next_project_number' specs/state.json`).
