# Agent System Review — 2026-08-10 (Capstone Acceptance Gate)

**The capstone acceptance gate FAILS.** It is not blocked as a whole — enough live evidence
exists to return a definitive verdict on two of the three verification scopes — but the third
scope is BLOCKED, and one of its sub-items is additionally UNVERIFIABLE-AS-WRITTEN. This document
is the dated closing bookend to `review-2026-07-29-agent-system.md`, which opened the refactor
batch this gate now closes out. This task fixes nothing structural: every finding below is
recorded (an `errors.json` entry and/or a spawned follow-up task) rather than repaired, per the
gate's own mandate.

---

## 1. Verdict by scope

| Scope | Sub-items | Verdict |
|---|---|---|
| DEPLOY | 6 | **FAIL** — 4 PASS, 1 FAIL, 1 CONDITIONAL |
| GATES | 4 (+ `verify-deploy.sh` as a 5th accounting) | **FAIL** — 3 PASS, 1 FAIL; `verify-deploy.sh --findings` 22/23 |
| LIVE CYCLE | 4 | **BLOCKED** — 1 statically PASS, 1 BLOCKED, 1 BLOCKED, 1 additionally UNVERIFIABLE-AS-WRITTEN |
| Review artifact (scope item 4) | 1 | Not a verification item — this document, produced here |

## 2. DEPLOY scope — 6 sub-items

| # | Sub-item | Verdict | Evidence |
|---|---|---|---|
| i | Wipe+regenerate to a scratch tree succeeds | **PASS** | `deploy-headless.sh --wipe` against a fresh scratch repo (both the original research dispatch and this task's own re-check, 4 separate wipes) exited 0 each time and produced a complete `.claude/` tree. |
| ii | Running it twice is byte-identical | **FAIL** | Confirmed non-deterministic in two independent ways across 3 re-check wipe-pairs run for this task: `context/index.json` and `settings.json` differ in object-key/array-element ordering beyond the expected `generated` timestamp (semantically identical under `jq -S`, cosmetically different raw text); `settings.local.json` differed by ordering only in all 3 re-check pairs (0 of 3 reproduced the originally-observed dropped-block content loss — see decision note below). |
| iii | Declared-vs-deployed parity + content-hash equality for EVERY `provides.*` category | **CONDITIONAL** | `verify-deploy.sh` gate 5 (`verify.lua`) PASSES today as implemented, because it is one-directional: its result shape (`{checked, missing, hash_mismatch, protected}`) has no `extra`/`orphan` field and only ever iterates the declared side. Under the bidirectional reading the word "parity" invites, it FAILS: 4 files are present in the live deployed tree and absent from a clean scratch regenerate (see next row). |
| iv | No quarantined/deprecated file present in the deployed tree | **PASS** | `find .claude -path '*deprecated*'` on the live tree returns nothing, despite `agent-system/extensions/core/scripts/deprecated/` and a literature-extension `deprecated/` existing in the source store. |
| v | Protected (`.syncprotect`) files survive the round-trip | **PASS** | `.syncprotect` lists `context/repo/project-overview.md`; confirmed retained live, and independently confirmed by this task's own orphan-diff (below) to be excluded from the orphan set for exactly this reason — it is generated user content outside any extension's static `provides` list, not deploy cruft. |
| vi | `settings.local.json` survives the round-trip | **PASS** | The file exists post-wipe in every run; its content-stability (not its mere survival) is what sub-item ii's FAIL covers. |

**The orphan-file list (feeds sub-item iii).** Confirmed by this task's own `comm -23` diff of the
live `.claude/` tree against a clean scratch regenerate: exactly 4 files, matching the batch
research's claim without correction —
`context/orchestration/orchestration-validation.md`,
`context/orchestration/subagent-validation.md`,
`docs/architecture/architecture-spec.md`,
`docs/README.md`.
The mechanical reason: `install-extension.sh`'s `merge_index_entries()` is purely additive
(`.entries += (...)`, no subtractive/stale-removal step), and `verify.lua` never walks the
deployed tree looking for undeclared content.

**Decision on the content-loss non-reproduction.** The original research observed one instance of
a content-lossy `settings.local.json` merge (a dropped `hooks.PreToolUse` block and an
`mcpServers` block between two runs). This task's own re-check (3 wipe-pairs, run specifically to
confirm or refute reproducibility before any fix effort is spent) did **not** reproduce it — 0 of
3. Per the plan's own risk mitigation, non-reproduction is a result, not grounds to withhold
recording: `err_1786350581208_23mAsn` records the finding at severity **high** (not critical) with
the 0-of-3 rate stated explicitly, and Phase 7's re-run procedure (Section 6 below) adds an
explicit re-check step so this does not quietly become a non-finding.

## 3. GATES scope — 4 sub-items + `verify-deploy.sh`

| Sub-item | Verdict | Evidence |
|---|---|---|
| `check-extension-docs.sh`, hardened defaults, no env overrides | **PASS** | Exit 0; all 20 extensions report Extension-Status PASS (advisory WARN noise only). |
| `validate-state.sh --deep` | **PASS** | Exit 0, 14/0/0 (passed/warnings/failed), all 6 `--deep` invariants hold — including after this task's own Phase 5 task creation (re-confirmed, still 14/0/0). |
| `check-task-references.sh` (repo-wide) | **PASS** | Exit 0, 0 unexempted occurrences across all 4 scanned trees. |
| `tests/run-all.sh` green | **FAIL** | Source-store copy: 34/36 passed (2 failures — the EXTENSION.md Rule-U bug and a flaky lock-contention test attributable to concurrent sibling sessions, not a deploy defect). Deployed copy: 26/33 passed (7 failures — the same EXTENSION.md bug, 5 `REPO_ROOT` path-depth failures, and a 7th, previously-unreported failure: `test-common-lib.sh` flags `.opencode/scripts/command-gate-in.sh`'s inline session-ID generator, which duplicates `lib/common.sh`'s canonical one and only fails in deployed mode). The 7th failure is newly recorded as `err_1786350581305_8cNAZ7`. |
| `verify-deploy.sh --findings` (accounting, not one of the 4) | **22/23** | The single failure is gate 8, the shell-test-suite runner (which surfaces the `run-all.sh` failures above). Every other gate — including gate 7, routing-wiring lint, load-bearing for LIVE CYCLE sub-item 1 below — is a clean PASS. |

## 4. LIVE CYCLE scope — 4 sub-items, BLOCKED

| Sub-item | Verdict | Evidence |
|---|---|---|
| Routing resolution yields an agent file that exists on disk for every declared `task_type` | **Statically PASS** | Effectively discharged by `lint-routing-wiring.sh` (`verify-deploy.sh` gate 7), currently a clean PASS — independent of running an actual `/orchestrate` cycle. |
| Cycle produces a schema-valid handoff (or, under the single-channel design, no handoff and no recovery-bridge warnings) | **BLOCKED** | No cycle was run; see the blocking argument below. |
| Gate-out reports zero format errors and zero auto-repaired fields | **UNVERIFIABLE-AS-WRITTEN** | See Section 5. |
| The system-defect recorder emits NO `system_defect` event on the clean run (the negative test), and the deferred-defect surface renders empty | **BLOCKED**, and independently already-failing on current state | See the blocking argument below; separately, `specs/events.jsonl` already carries 3 pre-existing `system_defect` events (all dated 2026-08-08), so the "deferred-defect surface renders empty" clause fails on current state regardless of any new cycle. |

### The blocking argument (why LIVE CYCLE is BLOCKED, not merely unrun)

`specs/state.json`'s `next_project_number` is 1007 (>= 1000), so any task created now to exercise
a live cycle is numbered 4 digits. `hooks/validate-handoff-location.sh` matches
`.orchestrator-handoff.json` paths against
`(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$` — a fixed-position `[0-9]{3}`
(exactly three digits, no `{3,}` or `+` quantifier) that structurally cannot match a 4+-digit
directory segment. Every such task's handoff write therefore trips the hook's non-match branch,
which both exits 2 with a false MISPLACED diagnostic and unconditionally calls
`system-defect-record.sh --defect-class HANDOFF_MISLOCATED`, emitting a `system_defect` event.
Acceptance sub-item 4 above requires the recorder to emit NO event on a clean run; because this
emission fires on every 4-digit task regardless of whether the orchestrated work itself completed
cleanly, the negative test cannot pass for reasons wholly unrelated to system health. LIVE CYCLE
is therefore recorded as BLOCKED, gated specifically on `err_1786349061492_XpY38x` (the regex
fix, spawned as task 1007) landing — not on any other defect in this batch, and not on general
system health.

The regex is confirmed live: registered in the deployed `.claude/settings.json`
(`"command": "bash .claude/hooks/validate-handoff-location.sh"`), sourced from
`agent-system/extensions/core/merge-sources/settings-hooks.json` with an identical command
string — a live wiring, not a deploy gap.

## 5. The UNVERIFIABLE-AS-WRITTEN sub-item

"Gate-out reports zero format errors and zero auto-repaired fields" has no instrumentation to
report against — this is a distinct condition from being verified and found failing. The traced
call path: `command-gate-out.sh` (134 lines; its only related content is the comment
`# Non-blocking artifact validation (link repair)`) calls `skill_validate_task_artifacts` in
`skill-base.sh`, which invokes exactly `validate-artifact.sh "$f" "$type" --fix 2>/dev/null` per
artifact file. `validate-artifact.sh` emits a terminal
`[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining` line and
`exit 2` — but `skill_validate_task_artifacts` discards stderr, collapses every non-zero exit into
one generic `WARNING: ... has format issues (non-blocking)` with no numeric detail carried
forward, and always `return 0`s. `command-gate-out.sh` therefore receives no signal at all from
this step. There is no "gate-out reports" surface anywhere in that chain against which "zero
auto-repaired fields" can be asserted or refuted. Secondary hazard: `--fix` mutates the artifact
in place unconditionally, so a repair both happens and goes uncounted at every layer above
`validate-artifact.sh` itself. Recorded as `err_1786350581339_Q4VnFy`.

## 6. Closing-bookend framing against the opening review

`review-2026-07-29-agent-system.md` named five root causes. This capstone's findings show:

| Root cause (2026-07-29) | Status after this refactor batch |
|---|---|
| 1. Duplicated mechanism instead of shared mechanism | Substantially addressed by the structural waves this capstone verifies (shared `state-write.sh`, `skill-base.sh` lifecycle functions, consolidated routing ladder) — no new duplicated-mechanism instance surfaced by this gate. |
| 2. Verification that silently passes | **Still live — two fresh instances found by this gate.** The DEPLOY non-determinism (Section 2, sub-item ii) is a redeploy that can silently reorder or (in the originally-observed case) drop configuration with no error surfaced. The one-directional parity check (Section 2, sub-item iii) is a gate that reports PASS while 4 files silently drift out of sync with the source of truth. Both are fresh instances of exactly the "verification that silently passes" pattern the opening review diagnosed as root cause 2 — this refactor batch narrowed the pattern's footprint elsewhere but did not eliminate the pattern itself. |
| 3. The error-tracking/self-healing layer is fiction | Addressed: `specs/errors.json` now exists, has a schema, an append script (`errors-append.sh`) holding `flock` across the full read/transform/validate/`mv` sequence, and is the mechanism this very gate uses to record its own findings (Section 7 below). |
| 4. Dead machinery accumulates and is still documented as live | Not directly probed by this gate's scope; orthogonal to DEPLOY/GATES/LIVE CYCLE. |
| 5. (Task treadmill / duplicated-fix-per-symptom generative mechanism) | This gate's own disposition discipline (Section 7 — fold before spawn, one task per decision even when two error ids point at it) is a deliberate attempt not to re-add treadmill instances; whether it succeeds is only knowable in retrospect. |

## 7. Defect ledger — all 10 confirmed defects

| Error id | Type | Severity | Disposition |
|---|---|---|---|
| `err_1786349061492_XpY38x` | hook_regex_defect (`validate-handoff-location.sh` 3-digit regex) | high | **Spawned task 1007** — highest priority; blocks this gate's own LIVE CYCLE scope |
| `err_1786349061524_pY97cE` | lock_session_self_contention (`skill-orchestrate/SKILL.md` MT-1/MT-4 session-id mismatch) | critical | **Spawned task 1008** — fully blocks multi-task `/orchestrate` |
| `err_1786349061556_LuKGif` | deploy_ghost_index_entries | medium | **Spawned task 1009** (jointly with `err_1786350581273_TAWj0I`, one decision, one task) |
| `err_1786349061588_fqHbUZ` | defect_vocabulary_gap | medium | **Spawned task 1011** — 3 concrete instances now ground the new classes |
| `err_1786344051474_RcIhk6` | delegation_interrupted (prior interrupted dispatch) | — | Entry only — historical record, no live fix target |
| `err_1786350581208_23mAsn` | deploy_merge_content_loss | high (0-of-3 reproduction rate stated in message) | Entry only — re-check step added to Section 8's re-run procedure |
| `err_1786350581240_JyztWt` | deploy_nondeterministic_merge | low | Entry only — folds into task 1009 |
| `err_1786350581273_TAWj0I` | deploy_orphan_files_undercounted | medium | **Spawned task 1009** (jointly with `err_1786349061556_LuKGif`) |
| `err_1786350581305_8cNAZ7` | test_suite_failure_undocumented | medium | **Spawned task 1010** — no open `run-all.sh` task existed to fold into |
| `err_1786350581339_Q4VnFy` | acceptance_criterion_not_instrumented | medium | Entry only — this gate's own re-run procedure (Section 8) states the criterion as currently unverifiable rather than requiring new instrumentation before any re-run |

Five tasks spawned (1007–1011), each carrying its originating error id(s), a named target file,
the SOURCE-STORE RULE, the DELIVERABLE RULE, and a constraint against driving it with multi-task
`/orchestrate` until `err_1786349061524_pY97cE` (task 1008) lands. `validate-state.sh --deep`
exits 0 (14/0/0) after their creation; `specs/TODO.md` was regenerated via `generate-todo.sh`,
never hand-edited.

## 8. What this task deliberately did NOT do, and why

This is a RECORDING gate, not a repair gate, by its own description's binding language: "This
task fixes nothing structural itself." Accordingly:

- **No fix was applied** to the handoff-location regex, the MT-1/MT-4 session-id mismatch, the
  orphan files, the merge non-determinism, the 7th `run-all.sh` failure, or the defect-vocabulary
  gap. All five are handed off to the spawned tasks above.
- **No auto-repair instrumentation was added** to `command-gate-out.sh`. The gap is recorded
  (Section 5), not built.
- **The DEPLOY and GATES scopes were not re-run wholesale.** The batch research already executed
  them live; this task only re-checked the two reproducibility-flagged DEPLOY items (Section 2)
  and traced the gate-out instrumentation gap (Section 5).
- **No live `/orchestrate` cycle was run.** Section 4 establishes why it cannot yet run cleanly
  rather than attempting it and absorbing a guaranteed false-positive defect event.
- **`specs/events.jsonl` and its 3 pre-existing `system_defect` events were not modified.**
- **No change was made under `agent-system/**`, `.claude/**`, `lua/**`, or `.opencode/**`.** Every
  write this task performed is confined to `specs/**` (`errors.json`, `state.json`, `TODO.md`,
  this review file, and the task's own `specs/996_.../` directory).

## 9. Re-run precondition checklist and procedure

The task description states "the gate re-runs after the fix lands." This section makes that
mechanical: a reader can determine, without judgement, whether the gate is ready to re-run and
exactly what to execute. **Re-running the gate is a fresh task, not a re-open of this one** — this
task's mandate ends at recording.

### 9.1 Unblock preconditions, per currently-failing or blocked sub-item

| Sub-item | Currently | Unblocks when |
|---|---|---|
| LIVE CYCLE (all 4 sub-items) | BLOCKED | Task 1008's underlying `validate-handoff-location.sh` fix (task 1007) has landed. Verify by writing a `.orchestrator-handoff.json` under a 4-digit scratch task directory and confirming no `HANDOFF_MISLOCATED` event is emitted (a negative test executed, not merely reasoned about). |
| GATES (`run-all.sh` green) | FAIL | `verify-deploy.sh --findings` reports 23/23 (currently 22/23; the one failing gate is the test-suite runner surfaced by `run-all.sh`'s failures). |
| DEPLOY (byte-identical twice) | FAIL | Two consecutive `--wipe` runs against the same target diff clean modulo the `generated` timestamp in `context/index.json` — i.e. the ordering non-determinism (task 1009's sibling low-severity finding, `deploy_nondeterministic_merge`) is also fixed, not only the content-loss question. |
| DEPLOY (parity, CONDITIONAL) | Ambiguous by design | Task 1009 resolves the ambiguity explicitly — either a subtractive/orphan-detection pass is added (parity becomes bidirectional and PASS/FAIL is unambiguous), or one-directional parity is documented as intended in `docs/architecture/architecture-spec.md` (the CONDITIONAL becomes a documented PASS). Either resolution, not the current silent ambiguity, is required before the gate re-runs. |
| LIVE CYCLE (gate-out instrumentation, UNVERIFIABLE-AS-WRITTEN) | No reporting surface | Either `command-gate-out.sh`/`skill_validate_task_artifacts` gains a repair counter/aggregate (the criterion becomes checkable), or the acceptance criterion itself is amended to something checkable given current instrumentation. Per Section 7's disposition, this was left entry-only rather than spawned — a re-run may proceed by amending the criterion instead of waiting on new instrumentation, at the re-running task's discretion. |

### 9.2 Re-run command sequence (verbatim, copy-pasteable)

```bash
# GATES — hardened defaults, no env overrides
bash .claude/scripts/check-extension-docs.sh
bash .claude/scripts/validate-state.sh --deep
bash .claude/scripts/check-task-references.sh

# verify-deploy.sh — all 23 sub-checks
bash .claude/scripts/verify-deploy.sh --findings

# run-all.sh — BOTH copies, reported separately (their failure sets differ)
bash agent-system/extensions/core/scripts/tests/run-all.sh
bash .claude/scripts/tests/run-all.sh

# DEPLOY — scratch wipe-pair procedure (run under a scratch dir, never the repo root)
SCRATCH="$(mktemp -d)"
git -C "$SCRATCH" init -q
cp .claude-extensions.json "$SCRATCH/.claude-extensions.json"
bash .claude/scripts/deploy-headless.sh --wipe "$SCRATCH"
cp -a "$SCRATCH/.claude" "$SCRATCH/.claude-run1"
bash .claude/scripts/deploy-headless.sh --wipe "$SCRATCH"
cp -a "$SCRATCH/.claude" "$SCRATCH/.claude-run2"
diff <(jq -S . "$SCRATCH/.claude-run1/context/index.json") <(jq -S . "$SCRATCH/.claude-run2/context/index.json")
diff <(jq -S . "$SCRATCH/.claude-run1/settings.json") <(jq -S . "$SCRATCH/.claude-run2/settings.json")
diff <(jq -S . "$SCRATCH/.claude-run1/settings.local.json") <(jq -S . "$SCRATCH/.claude-run2/settings.local.json")
rm -rf "$SCRATCH"

# LIVE CYCLE — single scratch-task /orchestrate cycle, after task 1007 lands
# (create a scratch task via /task, then /orchestrate it; confirm no HANDOFF_MISLOCATED
#  system_defect event is emitted, and inspect the resulting handoff/gate-out output)
```

### 9.3 Verdict rule for the re-run

The capstone PASSES only when all 14 sub-items (DEPLOY 6 + GATES 4 + LIVE CYCLE 4) are PASS, with
two named exceptions resolved explicitly rather than left ambiguous:

- The CONDITIONAL parity item must be resolved by an explicit recorded decision — either a
  bidirectional check is added and passes, or one-directional parity is documented as intended
  and the criterion is read as satisfied by design.
- The UNVERIFIABLE-AS-WRITTEN gate-out item must be resolved either by instrumenting the counter
  (and it then reports zero) or by amending the acceptance criterion to something checkable (and
  the amended criterion then passes).

A re-run that finds all 14 sub-items PASS under this rule closes the capstone. Any sub-item that
regresses or a new defect surfaced during the re-run follows this same gate's recording
discipline: an `errors.json` entry and/or a spawned follow-up task, never an in-place fix.

---

*Evidence sources: `specs/996_capstone_end_to_end_refactor_verification/reports/01_capstone-verification-findings.md`
(the sole evidence base for the batch-lead findings) and this task's own Phase 1–5 re-checks
(scratch wipe-pair diffs, hook/script tracing, `specs/errors.json` and `specs/state.json` writes).
Full evidence and per-task-step detail: `specs/996_capstone_end_to_end_refactor_verification/plans/01_capstone-gate-recording.md`.*
