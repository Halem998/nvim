# Research Report: Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher

- **Task**: 128 - Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher
- **Started**: 2026-09-01T13:02:35Z
- **Completed**: 2026-09-01T13:09:17Z
- **Effort**: ~1 hour
- **Dependencies**: Task 119
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (source-of-truth reference for the orphaned gate; read-only, not edited)
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (migration target)
  - `specs/TODO.md` task entries for the gate-repair task and the companion word-boundary portability audit task
  - Empirical `grep` behavior on the deployed shell (`ugrep 7.8.4`)
- **Artifacts**:
  - `specs/128_fix_h4_adversarial_gate_matcher/reports/01_fix-h4-adversarial-gate-matcher.md` (this report)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both reported gate failures were reproduced exactly, empirically, against the grep actually deployed on this machine (`ugrep 7.8.4`, POSIX/DFA `-E` engine): the literal-string heading match fails on a numbered heading, and the composed `\b`-boundary table pattern fails even on a perfectly canonical, unnumbered header line.
- Two minimal-diff corrected patterns were derived and verified against all required positive and negative cases, plus a regression check against an already-supported alternate table format. Both live entirely within the existing `grep -q`/`grep -qiE` invocation style — no new flags or engines.
- An alternative fix (switching to `grep -P`, the PCRE2 engine, which preserves `\b` semantics exactly) was evaluated and also passes every case, but is not the recommended fix — see Decisions.
- The gate (`#### State: researched` handler plus its `adversarial_verified` state variable, set at three sites in the `-hard` engine) has never been ported into the base `skill-orchestrate/SKILL.md` engine. That base engine's own text documents the omission as a deliberate, recorded scope decision — not an oversight — and explicitly asks a future task to "account for this gate separately." This task is that accounting.
- Full migration site inventory (both handlers, the three state-variable sites, the re-dispatch loop body, and the doc text that must be updated) is recorded below, anchored by heading/surrounding text rather than line number alone since the target file is under concurrent edit by sibling tasks in the same batch.
- Recommendation: land the corrected matcher only in the base engine's ported gate; leave the `-hard` engine's original (broken) pattern untouched since that engine is scheduled for deletion, and record the resulting asymmetry explicitly in both files using this repo's existing "Asymmetry decision (recorded, not acted on)" convention.

## Context & Scope

This is a `meta` task: repair a hard-mode gate that currently produces a false negative — it always re-dispatches an extra, wasted research pass even against a genuinely conforming report — and, in the same pass, carry that gate across from the orphaned `-hard` orchestration engine (slated for deletion) into the consolidated base engine, which does not yet have it.

Scope is deliberately narrow: fix and port exactly the H4 adversarial-verification gate. The general characterization of why composed `\b` constructs misbehave under the deployed grep is owned by the companion word-boundary portability audit task and is explicitly out of scope here — this report treats that failure mode only insofar as it explains why the two concrete production patterns needed to change, and defers the broader guidance (which constructs are portable in general, a full site audit) to that other task.

## Findings

### Confirmed reproduction of both original failures

Both checks in the deployed gate were reproduced against literal test files, using the grep that is actually invoked (`ugrep 7.8.4`, confirmed via `grep --version`, matching the class recorded against this defect):

- `grep -q "## Adversarial Self-Verification" <file>` → **NOMATCH** against a file whose heading is `## 7. Adversarial Self-Verification` (plain substring match, no numbering tolerance).
- `grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' <file>` → **NOMATCH** against the literal canonical header line `| Claim | Source / counterexample | Verification method | Confidence |`, even with the heading unnumbered. This is the compositional `\b` failure the companion audit task owns; every individual fragment (`\bclaim\b`, `\bsource\b[^|]*\bcounterexample\b`, etc.) matches in isolation, but the fully composed pattern does not, under this engine's POSIX/DFA `-E` path.

### Corrected patterns (empirically verified)

Both are minimal-diff from the originals — same `grep -q`/`grep -qiE` invocation style, no new engine flag:

**Heading** — tolerates an optional `N.` or `N.N` numbering prefix:

```
grep -qE '## ([0-9]+\.([0-9]+\.)?[[:space:]]*)?Adversarial Self-Verification' "$research_path"
```

**Table** — the `\b` word-boundary anchors are dropped:

```
grep -qiE '\|[^|]*claim[^|]*\|[^|]*source[^|]*counterexample[^|]*\|' "$research_path"
```

Dropping `\b` is safe here (does not reopen a false-positive hole) because the `|`-delimited cell structure of the pattern already does the discriminating work `\b` was meant to add: a prose sentence merely containing the words "claim"/"source"/"counterexample" without pipe-delimited table cells does not match. Verified directly: a sentence reading "This section disclaims outsourced counterexamples informally, without a table." (deliberately chosen to contain loose substrings of all three keywords) still returns NOMATCH against both the corrected pattern and the original `-P` pattern, because it has no `|` characters at all.

### Full test matrix (all six required plus one regression check, run against real files under the deployed grep)

| Case | Heading | Table | Combined gate result | Required |
|---|---|---|---|---|
| `## 7. Adversarial Self-Verification` + canonical table header | MATCH | MATCH | PASS (no re-dispatch) | Positive |
| `## 7.2. Adversarial Self-Verification` (N.N form) + canonical table header | MATCH | MATCH | PASS (no re-dispatch) | Extra positive |
| Unnumbered `## Adversarial Self-Verification` + canonical table header | MATCH | MATCH | PASS (no re-dispatch) | Positive |
| No adversarial section at all | NOMATCH | (n/a) | FAIL (re-dispatch triggers) | Negative |
| Section present, no claim/source/counterexample table | MATCH | NOMATCH | FAIL (re-dispatch triggers) | Negative |
| Already-documented alternate header, `\| # \| Claim under attack \| Source / counterexample \| Outcome \|` | MATCH | MATCH | PASS (no re-dispatch) | Regression check (no format previously supported should stop working) |

Every row was run as the literal combined `grep -qE ... && grep -qiE ...` shell conditional, against a real file, exactly as the production gate would evaluate it — never merely reasoned about.

### The `-P` (PCRE2) alternative, evaluated and rejected

`grep -qPi '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|'` — i.e., the ORIGINAL pattern unmodified, run under the `-P` engine instead of `-E` — also passes every row of the matrix above, since the deployed grep's PCRE2 engine evaluates composed `\b` anchors correctly (this is also the control case the companion word-boundary audit task's bisection relies on). It was evaluated as a candidate fix and rejected in favor of dropping `\b` under `-E`; see Decisions for the rationale.

### Migration site inventory (base engine: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`)

The base engine's own text already names this gate as the one piece of hard-mode state-machine logic not yet ported, next to an acceptance-checklist table listing everything that *has* been migrated (H1, H5, H6, the burnout breaker, the loop-guard/churn-state plumbing). The sites below are where the port lands, each anchored by heading or surrounding text (not line number alone) since this file is under concurrent edit by other tasks in the same batch:

- **Acceptance-checklist table** — the table immediately under the heading "Hard-mode state-machine migration — acceptance checklist." lists each migrated behavior and the stage that implements it. Add a row for the H4 gate here once it is ported, alongside the existing H1/H5/H6 rows.
- **"Not migrated" line** — the sentence beginning `**Not migrated**: the \`researched\`-state adversarial verification gate (H4) — see the residue note immediately below.` This line, and the phrase "Everything else in the source engine's state-machine logic ... is now reproduced here," need updating once H4 is added to that "everything."
- **"Hard-mode residue not yet migrated" paragraph** — the full paragraph beginning `**Hard-mode residue not yet migrated**: the \`researched\`-state adversarial verification gate (H4) — the \`#### State: researched\` handler in the \`-hard\` engine and its \`adversarial_verified\` state variable...`, ending with "...its absence here is not evidence it was folded in elsewhere in this file." This entire paragraph documents the gap this task closes and should be replaced with a short note recording that the gate is now ported (pointing at the acceptance-checklist row) plus the co-maintenance asymmetry note (see Decisions).
- **`#### State: \`researched\`` handler** — begins with "Read research artifact path from state.json:" and computes `research_artifact` via a `jq` query against `state.json`'s `.artifacts[] | select(.type == "report")`, immediately followed by `skill_preflight_update "$task_number" "plan" "$session_id"`. The H4 gate (hard-mode-gated) belongs immediately before that `skill_preflight_update` call, reusing the already-computed `research_artifact` as the gate's `$research_path` rather than recomputing it with a second `jq` call (the `-hard` engine's own version recomputes it independently, which is unnecessary here since the base handler already has the value in scope).
- **`#### State: \`planning\`` handler** — its own text states it is "**Converged** ... dispatch to plan, identically to the \`researched\` handler above," and it duplicates the same `research_artifact` computation and `skill_preflight_update "$task_number" "plan" "$session_id"` call verbatim. The same gate insertion applies here, in the same position, for the same reason (a task stranded in `planning` has research already complete and needs the identical re-dispatch-to-plan treatment).
- **`#### State: \`not_started\` or \`not started\`` handler** and **`#### State: \`researching\`` handler** — both currently end with the identical phrase "After Agent tool returns: read handoff (Stage 5). Increment cycle_count." In the `-hard` source, both of that engine's equivalent handlers instead end with "After Agent tool returns: read handoff (Stage 5). Set \`adversarial_verified=false\`. Increment cycle_count." — the reset exists so that a fresh research dispatch always requires the gate to re-verify, rather than trusting a stale `true` from a previous cycle. Both base-engine handlers need the equivalent hard-mode-gated reset added.
- **Stage 2 hard-mode-only variable init block** — the block that assigns `churn_file="${TASK_DIR}/.orchestrator-churn-state.json"` inside `if [ "${hard_mode:-false}" = "true" ]; then ... fi`, commented "Hard-mode-only per-target churn-state file (H5/H6)." The `adversarial_verified` variable's initial `=false` assignment belongs in this same hard-mode-gated block, in the same style (assigned unconditionally-in-scope but only meaningfully used inside `$hard_mode` branches, per that block's own comment convention).
- **"Asymmetry decision (recorded, not acted on)" convention** — this file already has a worked example of the exact convention this task should reuse: the paragraph beginning "**Asymmetry decision (recorded, ...)**: the 3-signal \`loop-guard-staleness\` detector now exists in this engine, behind the \`$hard_mode\` gate (D4) — it is no longer absent..." That paragraph records that a design question (whether base mode should unconditionally gain a hard-only detector) is deliberately left open rather than acted on, without introducing drift. The H4 co-maintenance asymmetry (see Decisions) should be recorded the same way, in both files.

### Reference sites in the `-hard` engine (read-only; not edited)

`agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` is the source of truth for the logic being ported. It is not edited by this task (see Decisions on the co-maintenance asymmetry). The three `adversarial_verified` set-sites, and the gate/re-dispatch body itself, are:

- **Stage 2 initial assignment** — `adversarial_verified=false`, the last statement in the block that also computes `blocker_escalation_count`/`MAX_BLOCKER_ESCALATIONS` from `loop_guard_init_json`.
- **`#### State: \`researching\`` handler's post-dispatch reset** and **the `not_started`-equivalent handler's post-dispatch reset** — both end with the sentence "After Agent tool returns: read handoff (Stage 5). Set \`adversarial_verified=false\`. Increment cycle_count." (this exact sentence occurs twice in the file, once per handler).
- **`#### State: \`researched\` — WITH Adversarial Verification Gate (H4)` handler** — the heading itself names the gate. Its body: a comment beginning `# H4: Adversarial verification gate`, an `if [ "$adversarial_verified" = "false" ]; then` block that computes `research_path` via `jq`, runs the two `grep` checks (the broken originals), and on success sets `adversarial_verified=true` (comment: "Adversarial verification section with Claim Verification Table found in report. Proceeding to planning."); on failure it dispatches `$RESEARCH_AGENT` again (comment: "# Dispatch a focused verification research pass") with `focus_prompt: "divergence audit"` and `orchestrator_mode: false`, explicitly does **not** write `.orchestrator-handoff.json` (per that file's own comment: "$RESEARCH_AGENT never writes .orchestrator-handoff.json"), and loops (comment: "Increment cycle_count. Loop continues."). A trailing `if [ "$adversarial_verified" = "true" ]; then` block runs `skill_preflight_update` and dispatches `$PLANNER_AGENT` — with an explicit comment warning that `skill_preflight_update` fires "ONLY here, strictly inside the adversarial_verified=true branch — never in the H4 verification re-dispatch branch above."

## Decisions

- **Fix the table pattern by dropping `\b`, not by switching to `-P`.** Both were verified to work. Dropping `\b` was chosen because it stays inside the existing `grep -E` invocation style already used everywhere else in both engine files (no new flag/engine dependency to introduce), and does not risk failing outright on any deployment where grep was built without PCRE2 support (unlikely but not guaranteed across every environment this code runs in, per the task record noting the defect was "observed live on a successful `/orchestrate --hard` run in a consumer repo" — i.e., this code is not confined to one machine). The `|`-delimited structure already prevents the loose-substring false positive `\b` existed to guard against, so nothing is lost by dropping it.
- **Fix the heading pattern by tolerating an optional `N.`/`N.N` prefix, not by requiring one or anchoring to line-start.** The original had no `^` line-start anchor (a plain substring match); the corrected pattern preserves that (unanchored), changing only the addition of an optional numbering group. This is the minimal change that satisfies both required positive cases without altering matching behavior for any other input the original pattern already handled.
- **Port the gate into the base engine's `researched` and `planning` handlers, gated on `hard_mode`**, following the same fork style already used for H1/H5/H6 in that file, reusing the `researched`/`planning` handlers' pre-existing `research_artifact` computation rather than duplicating the `jq` query the `-hard` engine's version runs independently.
- **Co-maintenance asymmetry: fix only the base engine; leave the `-hard` engine's original (broken) pattern untouched.** The two engine files carry an explicit convention (visible in several comments in the base engine, e.g. "so the two engines cannot drift apart on this...") that a one-sided change is normally a defect. That convention's own escape clause — already exercised elsewhere in this same file for the `loop-guard-staleness` detector question — permits recording a deliberate asymmetry instead of mirroring a change into a file that provides no further benefit from being kept in sync. The `-hard` engine is scheduled for deletion by a separate, already-dependent task; mirroring the fix into it would be pure waste (a second site to maintain for a file about to be removed) with no correctness benefit, since nothing will dispatch through the `-hard` engine's gate once the base engine's ported copy is live and preferred. Both files should get a short "Asymmetry decision (recorded, not acted on)" note, in the style already used in the base engine for a prior asymmetry decision, so a reader of either file understands the discrepancy is deliberate.
- **Preserve the false-negative-only direction of the gate.** The corrected patterns were verified never to pass a report lacking either the section or the table — the fix only removes spurious NOMATCHes on genuinely conforming input; it introduces no new way for the gate to wrongly pass unverified research.

## Recommendations

1. In `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: add the hard-mode-gated `adversarial_verified` state variable (Stage 2 init site, alongside `churn_file`), the two post-dispatch resets (`not_started` and `researching` handlers), and the gate-plus-re-dispatch body (inserted into both the `researched` and `planning` handlers, immediately before their shared `skill_preflight_update "$task_number" "plan" "$session_id"` call), using the corrected patterns given above — not the originals.
2. Update the acceptance-checklist table and remove/rewrite the "Not migrated" and "Hard-mode residue not yet migrated" text in the same file to reflect that H4 is now ported, per the anchors given in Findings.
3. Leave `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` unedited; add a brief "Asymmetry decision (recorded, not acted on)" note in both files recording that the matcher fix was applied only to the base engine's ported copy, deliberately, because the `-hard` engine is scheduled for deletion.
4. Do not attempt to generalize the `\b`-removal fix to other sites in the codebase as part of this task — that is the explicit scope of the companion word-boundary portability audit task, which owns the bisection evidence and will produce general portable-construct guidance separately.
5. When implementing, re-run the six-case (plus regression) test matrix above against the actual files being edited, using the real deployed grep, as the acceptance verification step — not by re-deriving the patterns from first principles.

## Risks & Mitigations

- **Risk**: a future edit reintroduces `\b` into the table pattern (e.g., during a later refactor that "restores" what looks like a more precise regex). **Mitigation**: the comment already present in the `-hard` source describing the pattern's shape-matching intent should be carried into the ported copy along with an explicit note that `\b` was deliberately removed for grep-portability reasons, pointing at the companion word-boundary audit task rather than silently omitting the anchors.
- **Risk**: line-number drift from concurrent edits to `skill-orchestrate/SKILL.md` by sibling tasks in the same batch makes literal line-number anchors stale. **Mitigation**: every site above is also anchored by heading text or a verbatim surrounding phrase, not by line number alone.
- **Risk**: forgetting to gate the ported gate on `hard_mode` would make it run in base mode too, changing base-mode behavior unintentionally. **Mitigation**: explicit reminder in Recommendations; this mirrors the existing, already-reviewed H1/H5/H6 fork style in the same file, which is the pattern to copy.

## Appendix

- Deployed grep identity confirmed via `grep --version` → `ugrep 7.8.4 x86_64-pc-linux-gnu +sse2; -P:pcre2jit`.
- Test files and shell invocations were run directly in a scratch directory against literal heredoc-authored Markdown fixtures reproducing each required case; no test artifacts were retained in the repository.
- The `\b` compositional-failure characterization (why the deployed engine mis-evaluates a `\b` occurring downstream of an earlier `\b`-anchored subexpression separated by a `[^|]*` run) is treated here only as the explanation for why the fix works; the general audit and portable-construct guidance belong to the companion word-boundary portability audit task, not this report.
