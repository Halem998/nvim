# Research Report: Task #906

**Task**: 906 - fix_gate_out_validation_arity_and_status_vocabulary
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: Medium (two independent defects, one shared-helper extraction, one vocabulary consolidation)
**Dependencies**: 885, 896, 901, 909 (file-overlap serialization only — not logical prerequisites, per task description)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/ canonical source store), live command output cited in delegation context
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both defects in the task description are confirmed exactly as described, against the
  canonical source at `agent-system/extensions/core/`, with all line-number claims re-verified
  and several found to have drifted (documented below — none of the drift changes the diagnosis).
- **Defect 1** (call-arity bug): confirmed live at `agent-system/extensions/core/scripts/command-gate-out.sh:115`. The required-approach constraint (extract one shared per-task-directory validation helper into `skill-base.sh`, not an inline loop) is buildable and safe: `command-gate-out.sh` can `source .claude/scripts/skill-base.sh` exactly the way `orchestrator-postflight.sh:71` already does, so the helper is reachable.
- **Defect 2** (forbidden status vocabulary): confirmed at three writers — `skill-orchestrate/SKILL.md:934` (Stage 8 clean exit), and `skill-orchestrate/SKILL.md`'s Stage MT-5 exit-status determination (line 1396, feeding the `--arg status "$exit_status"` write at line 1412). Fix direction is exactly as settled in the task description: change the offending writer(s) to emit `"implemented"`, not `"completed"`; do not touch `command-gate-out.sh`'s accept-list.
- **New interaction investigated and resolved**: `orchestrate-recover-outcome.sh`'s accept-list (`researched|planned|implemented`) does **not** need any change and is not endangered by the Stage 8 fix — its freshness gate (`meta_mtime >= window_start_ts`) is timestamp-based, not vocabulary-based, and Stage 8 (final postflight) always runs strictly after every Stage 5 recovery call within the same `/orchestrate` invocation, so there is no path by which a Stage-8-written `.return-meta.json` is ever read by a Stage 5 call it doesn't belong to. Full reasoning below.
- Broad re-grep for other `--arg status "completed"` writers targeting `.return-meta.json` turned up two additional hits (`skill-team-implement/SKILL.md:490`, and two `context/patterns/*.md` examples) — all three write **state.json**'s task status (where `"completed"` is correct), not `.return-meta.json`. Confirmed non-offenders; see Findings.
- The "stop-behavior" rationale behind the vocabulary prohibition (`context/formats/return-metadata-file.md:79`) is verified still current: it is a live, actively-enforced constraint in agent operating instructions today, not a stale premise. No escalation needed.

## Context & Scope

Verified all claims in the task description (`jq -r '.active_projects[]|select(.project_number==906)|.description' specs/state.json`) against the canonical source store `agent-system/extensions/core/` (the `.claude/` tree is a gitignored, disposable deploy artifact per the binding SOURCE-STORE RULE — all fix work must target `agent-system/extensions/core/**`). Live evidence from this orchestration run (two real `[FAIL] File not found` reproductions) was treated as ground truth for Defect 1's symptom and re-derived independently from the arity mismatch in the two scripts.

## Findings

### Defect 1: validate-artifact.sh call-arity bug

**Confirmed, line numbers re-verified (some drifted from the task description, diagnosis unchanged):**

- `agent-system/extensions/core/scripts/command-gate-out.sh:115` (task description said line 101 — stale; both canonical source and the currently deployed `.claude/scripts/command-gate-out.sh` are now at line 115, so source and deploy have NOT drifted relative to each other, only relative to the task description's earlier snapshot):
  ```bash
  bash .claude/scripts/validate-artifact.sh "$task_dir" --fix 2>/dev/null || true
  ```
- `agent-system/extensions/core/scripts/validate-artifact.sh:4` usage: `<artifact_path> <type> [--fix] [--strict]`, types `{report, plan, summary}` (line numbers unchanged — this file was not touched this session).
- With the buggy call, `"--fix"` binds to the `type` positional and `"$task_dir"` (a directory) binds to `artifact_path`. Execution reaches the guard at `validate-artifact.sh:54-57`:
  ```bash
  if [ ! -f "$artifact_path" ]; then
    echo "[FAIL] File not found: $artifact_path"
    exit 3
  fi
  ```
  `[FAIL]` goes to stdout (not stderr), so the caller's `2>/dev/null` does not suppress it; `|| true` swallows the exit 3. This exactly matches the two live `[FAIL] File not found: specs/913_...` / `specs/916_...` lines observed in this orchestration run.

**Uniformity evidence re-verified — every other caller uses the correct 3-token form:**

| Caller | Line (canonical source) |
|---|---|
| `scripts/skill-base.sh` (`skill_validate_artifact` function) | 341 (task description said 326 — that line is the function's doc-comment/Stage-6a header, not the call itself; the call is 15 lines further down in the same function) |
| `scripts/orchestrator-postflight.sh` | 274 (task description said 270 — off by 4, same statement) |
| `skills/skill-researcher/SKILL.md` | 328 (unchanged) |
| `skills/skill-planner/SKILL.md` | 350 (unchanged) |
| `skills/skill-implementer/SKILL.md` | 380 (unchanged) |
| `skills/skill-reviser/SKILL.md` | 314 (unchanged) |
| `skills/skill-planner-hard/SKILL.md` | 244 (unchanged) |
| `skills/skill-researcher-hard/SKILL.md` | 233 (unchanged) |

`command-gate-out.sh` is confirmed the lone deviant.

**Required-approach feasibility check (shared helper in `skill-base.sh`, not an inline loop):**

`command-gate-out.sh`'s own header (lines 5-8) states it "can be called as a subprocess (not sourced) since it only produces side effects." This describes how *Claude Code's Bash tool* would invoke it, not a restriction on what the script itself may do internally — a bash script sourcing another bash script (`source .claude/scripts/skill-base.sh`) is unrelated to that concern and has direct precedent: `orchestrator-postflight.sh:71` already does exactly this (`source .claude/scripts/skill-base.sh`) from the same kind of standalone-subprocess context, then calls skill-base.sh functions later in the same file. `skill-base.sh` itself resolves its own repo root from `BASH_SOURCE` (line ~30), so sourcing it correctly does not depend on the caller's cwd. **Conclusion: the helper is reachable from `command-gate-out.sh` via `source .claude/scripts/skill-base.sh`, following the `orchestrator-postflight.sh` precedent exactly.**

**Design for the new helper** (adjacent to the existing `skill_validate_artifact` function at `skill-base.sh:324-345`, which validates exactly one known `(path, kind)` pair — that function is not itself reusable for a whole-directory sweep because `validate-artifact.sh` only ever takes one file and one type per invocation, confirmed at `validate-artifact.sh:25-26`). A new function, e.g. `skill_validate_task_artifacts "$task_dir"`, should:
- Glob `"$task_dir"/reports/*.md` → validate each as `report`
- Glob `"$task_dir"/plans/*.md` → validate each as `plan`
- Glob `"$task_dir"/summaries/*.md` → validate each as `summary`
- Call `validate-artifact.sh "$file" "$kind" --fix` per file, non-blocking (loop continues past per-file failures — matches the current `|| true` non-blocking semantics), with a glob-no-match guard (`nullglob` or `[ -e ... ]` check) since not every task directory has all three subdirectories populated (e.g., a `[RESEARCHED]`-only task has no `summaries/`).
- `command-gate-out.sh` then calls `source .claude/scripts/skill-base.sh && skill_validate_task_artifacts "$task_dir"` in place of the current line-115 call.

This satisfies the required approach: the abstraction lives in exactly one place, `command-gate-out.sh` and any future caller consume it identically, and the per-file-type correctness bug (the actual root cause) cannot recur because no call site chooses the type argument by hand anymore for the directory-sweep case.

**Documentation fix required (`commands/research.md`):**

`agent-system/extensions/core/commands/research.md:424` currently reads:
```
2. **Verify Artifacts** (research-specific; kept inline — `command-gate-out.sh`'s
   `validate-artifact.sh --fix` leg is dead code and cannot substitute for this check)
```
This is the exact same root cause, confirmed by direct inspection — the "dead code" observation is accurate today and only today, precisely because of Defect 1. Grep across `commands/*.md` and `docs/**/*.md` found this is the **only** occurrence of this "dead code" claim — no other doc needs a parallel fix. Once Defect 1 is fixed, the parenthetical must be updated to no longer claim dead code, since the two checks are not, in fact, redundant even when gate-out is working: the inline "Verify Artifacts" step in `research.md` validates that the specific artifact path(s) named in the *agent's own return metadata* exist on disk (a claim-integrity check on the subagent's report), whereas `command-gate-out.sh`'s directory sweep validates *format compliance* (metadata fields, required sections) for every artifact file present, regardless of what the agent claimed. Recommend rewording to something like: "kept inline as a claim-integrity check — distinct from and complementary to `command-gate-out.sh`'s directory-wide format sweep" rather than asserting the sweep is dead.

### Defect 2: forbidden status vocabulary in .return-meta.json

**Confirmed, three writers, line numbers re-verified (drifted from task description due to two other in-session edits to the same file — `skill_propagate_completion_summary` addition and the `orchestrate-recover-outcome.sh` integration):**

1. `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:934` — Stage 8, clean exit:
   ```bash
   jq -n \
     --arg status "completed" \
     ...
   ```
   (task description said line 731 — stale, same file, same statement otherwise.)
2. `skill-orchestrate/SKILL.md:951` — Stage 8, partial exit: `--arg status "partial"` — **this one is already correct** (`"partial"` is in the valid vocabulary); no change needed here.
3. `skill-orchestrate/SKILL.md`, Stage MT-5 (multi-task), exit-status determination at line 1396-1398:
   ```
   - `failed_count == 0` AND `deferred_self_modifying` is empty → `"completed"` (remove
     `mt_state_file`)
   - `failed_count > 0` OR `deferred_self_modifying` is non-empty → `"partial"` ...
   ```
   feeding `--arg status "$exit_status"` at line 1412, written to `specs/.return-meta-multi.json` at line 1426 (task description cited lines 1004-1006/1009 — stale, same file/statement). This is prose (SKILL.md instructs the agent what logic to implement), not literal bash setting a variable — the fix is a text edit to the bullet, changing the arrow target from `"completed"` to `"implemented"`. The `"partial"` branch is already correct and needs no change.

**`.return-meta-multi.json` is currently unconsumed** — a repo-wide grep found no reader of this file anywhere in `agent-system/extensions/core/` outside the writer itself (`batch-orchestration-guardrails.md` explicitly notes multi-task dispatch never sources `command-gate-out.sh`). It exists purely as a diagnostic/reporting artifact today. The fix should still be applied for vocabulary consistency and to avoid seeding a bad precedent for a future reader, per the task's required approach (one vocabulary, enforced consistently).

**Do NOT invert the fix** — re-confirmed. `command-gate-out.sh`'s accept-list (lines 84-85, unchanged from the task description):
```bash
if [ -n "$expected_status" ] && { [ "$skill_status" = "implemented" ] || \
   [ "$skill_status" = "researched" ] || [ "$skill_status" = "planned" ]; }; then
```
is correct and matches `context/formats/return-metadata-file.md`'s documented vocabulary exactly. `skill-orchestrate` is the offender.

**Comment that becomes misleading once the branch is live** — `command-gate-out.sh:69-73` (the inline comment reasoning about the orchestrate arm never having been exercised) must be updated once Defect 2 lands; it currently correctly describes today's unreachable state but would be stale and misleading the moment the branch becomes reachable.

**Third-writer audit re-confirmed, one addition found and cleared:**
- `skill-orchestrate-hard/SKILL.md` re-checked: greped every `.status` reference (lines 317, 675, 799, 823, 912) — all are *reads* (of `handoff`, `recover_json`, or state.json's `.status`), none write `.return-meta.json`. Confirmed non-offender, as the task description's prior audit stated.
- **New hit found during this task's broader re-grep** (not in the task description's audit list): `skills/skill-team-implement/SKILL.md`. Line 490 has `--arg status "completed"`, but this writes **state.json**'s task status (Stage 12, `[COMPLETED]` marker) — a different, correct vocabulary. Its actual `.return-meta.json` write is Stage 13 (line ~523), which already emits `"status": "implemented"` — correct, not an offender.
- Two more `--arg status "completed"` hits in `context/patterns/jq-escaping-workarounds.md:150` and `context/patterns/inline-status-update.md:129` are both **state.json** postflight example snippets (`[COMPLETED]` marker), not `.return-meta.json` examples. Confirmed non-offenders.
- `scripts/orchestrator-postflight.sh:445` (`[ "$notify_status" = "implemented" ] && notify_status="completed"`) is a **third, unrelated vocabulary**: a wezterm tab-color/TTS notification status, explicitly commented as such ("wezterm.lua only has 'completed' in its color table"). Not part of the `.return-meta.json` contract; no change needed.
- `commands/orchestrate.md` uses `"completed"`/`[COMPLETED]` exclusively for **state.json** task-status / TODO.md markers (e.g. line 522's `Final status: [COMPLETED]`), never for `.return-meta.json`. Not an offender. **Recommend the report/plan explicitly flag this distinction** (skill_status vocabulary vs. state.json task-status vocabulary vs. wezterm notification vocabulary — three separate, legitimately different enumerations sharing the word "completed"/"implemented" in different files) so a future implementer does not conflate them and "fix" a correct state.json write.

**New interaction investigated (flagged in delegation context, not in the original task description): does `orchestrate-recover-outcome.sh`'s accept-list interact with the Stage 8 fix?**

`orchestrate-recover-outcome.sh` (new since the task description was written) is a read-only helper called from base Stage 5, hard Stage 5, and multi-task Stage MT-4 step 1, to recover an outcome from `.return-meta.json` when `.orchestrator-handoff.json` is missing. Its accept-list is `researched|planned|implemented` (documented at its own header, lines ~42-45) — already exactly the correct vocabulary, requiring no change.

The theoretical hazard: Stage 8 writes `${TASK_DIR}/.return-meta.json` with the orchestrate-level final status, to the **same path** that Stage 5/MT-4 read from mid-loop for **sub-dispatch** (research/plan/implement) recovery. If a stale Stage-8-written file were ever picked up by a later Stage 5 call as if it described a fresh sub-dispatch, the vocabulary fix (`completed`→`implemented`) would newly make that stale file *pass* the accept-list check where it previously failed it (accidentally, via the bug).

Verified this is **not actually possible**, for two independent reasons:
1. **Freshness gate is timestamp-based, not vocabulary-based.** `orchestrate-recover-outcome.sh` compares `meta_mtime` (the file's actual mtime) against `window_start_ts` (captured immediately before the *current* dispatch's Agent tool call). A `.return-meta.json` written by a *previous* `/orchestrate` invocation's Stage 8 necessarily has an mtime *before* the current invocation's `window_start_ts` (time only moves forward across separate invocations), so it is correctly classified `META_STALE` regardless of what status string it contains.
2. **Stage 8 only runs once, and strictly last.** Within a single `/orchestrate` invocation, Stage 8 (postflight) is the terminal step — it runs only after every internal dispatch cycle (and therefore every Stage 5/MT-4 recovery call) for that invocation has already completed. There is no code path within one invocation where Stage 8's write could precede a Stage 5 read it might be mistaken for.

**Conclusion: no change needed to `orchestrate-recover-outcome.sh`.** This is worth stating explicitly in the plan so a future reviewer doesn't reintroduce coupling here — the two mechanisms (mtime freshness, status vocabulary) are orthogonal by design, and the vocabulary fix is safe in isolation.

**Vocabulary format doc re-verified — no drift, no divergence:**
- `context/formats/return-metadata-file.md` lines 71-77 (vocabulary table) and line 79 ("Never use `"completed"`") are byte-identical in position and content to what the task description cited (72-75/79) — this file was not touched this session.
- `docs/architecture/handoff-schema.md` line 74 (task description said line 45 — stale, three sections were added earlier in the file, pushing content down) states `"status": "researched | planned | implemented | partial | failed | blocked"` — **identical** vocabulary to `return-metadata-file.md`. Confirmed: this is intentional agreement between two governing different files (`.return-meta.json` vs. `.orchestrator-handoff.json`), not a disagreement to reconcile. **Where the identity is enforced today: nowhere explicitly** — the two files simply happen to list the same six words independently. The required approach ("make `return-metadata-file.md` normative, have `handoff-schema.md` reference rather than restate") is not yet implemented; recommend adding one sentence at `handoff-schema.md`'s vocabulary line pointing to `context/formats/return-metadata-file.md` as the shared, normative enumeration for both files' `status` field.
- `docs/architecture/handoff-schema.md` line 268 documents `orchestrate-recover-outcome.sh`'s own `researched|planned|implemented` accept-list inline (prose, not code) — this is a second restatement of the same three success values and would also benefit from a cross-reference rather than restating them, for the same drift-prevention reason.

**Stop-behavior rationale check (task asked to verify this isn't a stale premise):**

Confirmed **current and actively enforced**, not stale: the instructions governing this very research agent's own required output format include, verbatim, "Use status value 'completed' (triggers Claude stop behavior)" under a MUST NOT list. This is a live constraint experienced directly in this session, not something to escalate — the premise fully holds.

## Decisions

- Defect 1 fix location: new shared function in `agent-system/extensions/core/scripts/skill-base.sh`, adjacent to `skill_validate_artifact` (~line 324), not an inline loop in `command-gate-out.sh`. `command-gate-out.sh` sources `skill-base.sh` (precedented by `orchestrator-postflight.sh:71`) to call it.
- Defect 2 fix: change `skill-orchestrate/SKILL.md:934` (Stage 8 clean exit) and the Stage MT-5 exit-status bullet (line 1396-1398 area) from `"completed"` to `"implemented"`. Leave the `"partial"` branches (line 951, and the MT-5 partial bullet) unchanged. Do not touch `command-gate-out.sh`'s accept-list or `orchestrate-recover-outcome.sh`'s accept-list — both are already correct.
- Update the misleading `command-gate-out.sh:69-73` comment block once Defect 2's branch becomes reachable.
- Update `commands/research.md:424`'s "dead code" parenthetical once Defect 1 is fixed — reword to describe the two checks as complementary (claim-integrity vs. format sweep), not redundant/dead.
- Add a one-sentence cross-reference from `docs/architecture/handoff-schema.md` (both its schema table and its `orchestrate-recover-outcome.sh` prose passage) to `context/formats/return-metadata-file.md` as the single normative vocabulary source, rather than restating the six-value enumeration independently in multiple places.
- No change needed to: `skill-orchestrate-hard/SKILL.md` (reader only), `skill-team-implement/SKILL.md` (already correct in both its state.json and return-meta writes), `orchestrator-postflight.sh:445` (unrelated wezterm-notification vocabulary), `orchestrate-recover-outcome.sh` (already correct, and provably safe against the Stage 8 fix via the mtime freshness argument above).

## Risks & Mitigations

- **Risk**: the new `skill_validate_task_artifacts` helper silently no-ops if none of `reports/`, `plans/`, `summaries/` exist yet (e.g., a task freshly created but not yet researched). **Mitigation**: use a glob-existence guard per subdirectory so an empty/missing subdirectory is skipped without error, matching the current non-blocking posture.
- **Risk**: sourcing `skill-base.sh` inside `command-gate-out.sh` pulls in unrelated machinery (extension hook dispatch, `SKILL_REPO_ROOT` resolution) that wasn't previously loaded in that execution context. **Mitigation**: verified `skill-base.sh`'s top-level code (repo-root resolution via `BASH_SOURCE`, `SKILL_CONTEXT_BUDGET` default) is side-effect-free at source time — no writes, no process spawning — so sourcing it is safe; this mirrors `orchestrator-postflight.sh`'s existing use.
- **Risk**: verification step (b) in the task's required verification — "exercise the defensive status-correction branch for operation=orchestrate against a deliberately desynced state.json" — needs a disposable/sandboxed task directory and state.json entry to avoid corrupting real task state during the implementation phase's manual test. Recommend the plan create a throwaway task directory (or a git-stashed test fixture) for this specific verification step rather than desyncing a real task's state.json.

## Context Extension Recommendations

- **Topic**: `.return-meta.json` status vocabulary vs. state.json task-status vocabulary vs. lifecycle-notification vocabulary are three distinct enumerations that all happen to use the word "completed" or "implemented" in different files. **Gap**: no single document currently disambiguates these three vocabularies side by side. **Recommendation**: after this task lands, consider adding a short disambiguation table to `context/formats/return-metadata-file.md` (or a new `context/patterns/status-vocabularies.md`) enumerating the three vocabularies and which file/field each governs, to prevent a future contributor from cross-wiring them (as nearly happened during this research pass with the `skill-team-implement` and `orchestrator-postflight.sh:445` hits, both ultimately cleared as false positives).

## Appendix

- Canonical source root confirmed at repo root: `agent-system/extensions/core/` (verified present via `find`).
- Key files inspected: `scripts/command-gate-out.sh`, `scripts/validate-artifact.sh`, `scripts/skill-base.sh`, `scripts/orchestrator-postflight.sh`, `scripts/orchestrate-recover-outcome.sh`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `skills/skill-team-implement/SKILL.md`, `commands/research.md`, `commands/orchestrate.md`, `context/formats/return-metadata-file.md`, `docs/architecture/handoff-schema.md`, `context/patterns/jq-escaping-workarounds.md`, `context/patterns/inline-status-update.md`.
- Search commands used: targeted `grep -n` for `validate-artifact`, `--arg status`, `dead code`, `return-meta-multi`, `researched.*planned.*implemented`, across `agent-system/extensions/core/` (scripts, skills, commands, docs, context).
