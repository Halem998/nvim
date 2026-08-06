# Research Report: Wire Non-Conformance Detection into the Hard-Mode Resume-Scan Sites

**Task**: 960 - Wire non-conformance detection into the hard-mode resume-scan sites
**Started**: 2026-08-06T14:55:17Z
**Completed**: 2026-08-06T15:40:00Z
**Effort**: Research only (meta task, source-store edits deferred to /plan + /implement)
**Dependencies**: Dependency tasks 959 and 957 have both landed (confirmed live in source store; see Findings)
**Sources/Inputs**: Codebase read of the source store (`agent-system/extensions/**`), no web research needed
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is confirmed, live, unchanged by tasks 959/957: both declared resume-scan sites
  select the next phase via `grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path"
  | head -1`, which silently discards non-conforming headings before any conformance check runs.
  The existing `warn_nonconforming` calls at both sites sit in a structurally unreachable branch
  (`next_heading` non-empty AND `extract_phase_number` fails — impossible, since the grep already
  guarantees `next_heading` matches `PHASE_HEADING_ERE`).
- The library (`phase-heading-patterns.sh`) already exports exactly the right non-racy predicate
  for the fix: `has_nonconforming_phase_headings <file>` (boolean, safe under `pipefail`) plus
  `warn_nonconforming <file> <label>` for the loud per-heading report. No library change is
  needed — this is purely a call-site wiring gap.
- **A third site with the identical bug exists outside the declared file scope**:
  `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` Stage 3 (lines
  91–137, specifically 108–124) is a byte-for-byte structural clone of `skill-implementer-hard`'s
  Stage 3b, including the same unreachable `warn_nonconforming` branch. It is not in this task's
  declared file scope but is a direct hit from the audit the task explicitly requests
  (`grep -rl 'phase-heading-patterns.sh' agent-system/extensions`). Flagged for a deliberate
  in-scope/out-of-scope decision at planning time.
- A fourth, lower-severity site with the same *shape* of blind spot: `update-task-status.sh`
  (line ~516, `first_phase_heading=$(grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT STARTED\]" ...)`
  inside the plan-initialization convenience path). This one is explicitly self-documented in an
  adjacent comment as "redundant convenience... Non-fatal" (superseded by the dispatched agent's
  own phase-status calls) — lower stakes than the two dispatch-selection sites, but the same
  filter-before-check pattern. Recommended for a documented decision, not necessarily a code
  change.
- Every OTHER consumer of the library that performs a similar "scan/count phase headings" role
  (`update-task-status.sh`'s `count_plan_phases`/D3 gate, `skill-base.sh`'s
  `skill_corroborate_phase_counts`, `general-implementation-agent.md`/
  `general-implementation-hard-agent.md` Stage 5a, `validate-artifact.sh`, `commands/task.md`
  Step 3, `skill-orchestrate/SKILL.md`'s recovery diagnostic) is **already correctly wired**:
  each calls `has_nonconforming_phase_headings`/`nonconforming_phase_headings` and warns *before*
  trusting any derived count or selection. `update-task-status.sh`'s D3 gate (lines ~276–334) is
  the strongest exemplar of the "whole-file check first, INCONCLUSIVE branch second" shape and is
  the right model to copy for the fix.
- Recommended posture: **keep the two declared sites' postures deliberately different**, but note
  that `skill-orchestrate-hard`'s currently-described posture ("warns and leaves `next_phase`
  empty") is not actually safe as structured today — leaving `next_phase` empty causes the
  surrounding `if/elif/else` to fall through into either the skeleton-exhaustion branch or the
  "all phases genuinely complete" branch, both of which are false readings when the real state is
  "conformance is broken, truth is unknown." The fix needs a **dedicated third branch** that
  routes to the skill's own established `EXIT (partial, ...)` terminal-condition convention
  (already used at three other sites in the same file), not a fallthrough into the existing
  two branches. See "Posture Decision" below for full reasoning.

## Context & Scope

Verified against the CURRENT source store (not the task description's original snapshot) that
dependency tasks 959 (H4 adversarial-table matcher / completion-propagation work) and 957
(phase-heading unification, which introduced `phase-heading-patterns.sh` itself) have both
landed: `git log` shows `task 959: complete orchestration` as the most recent commit, and the
library file, its D3 gate in `update-task-status.sh`, and the already-wired consumer sites below
all exist on disk exactly as task 957 would have produced them. The bug this task targets is a
residual gap task 957 did NOT close at the two per-phase dispatch-selection sites — it is not a
regression introduced by 959.

## Findings

### 1. The library's available predicates and their contracts

File: `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` (225 lines).

| Symbol | Kind | Contract |
|---|---|---|
| `PHASE_HEADING_ERE` | var | `^### Phase [0-9]+(\.[0-9]+)?:` — conforming-only heading match (line 26) |
| `PHASE_STATUS_OPEN_ERE` | var | `\[(NOT STARTED\|IN PROGRESS\|PARTIAL\|BLOCKED)\]` (line 97) |
| `PHASE_HEADING_LOOSE_ERE` | var | `^### Phase ` — "claims to be a phase heading" match, the basis of non-conformance detection (line 56) |
| `extract_phase_number <heading_line>` | fn | Prints the number token and returns 0 only if the line already matches `PHASE_HEADING_ERE`; prints nothing and returns 1 otherwise. **Never** returns a truncated prefix (lines 105–118). |
| `nonconforming_phase_headings <file>` | fn | Emits `linenum:heading` for every line matching the loose heading form but failing the canonical number grammar or the closed marker enum. Emits nothing (not even for a file with zero phase headings at all — that's the separate "no conforming headings" case) (lines 149–165). |
| `has_nonconforming_phase_headings <file>` | fn | Boolean (return 0/1). **The predicate this task's fix should call.** Captures the full producer output via command substitution before testing emptiness — explicitly documented (lines 167–182) as the fix for a `pipefail` race in the `nonconforming_phase_headings \| grep -q .` form, which the task description also explicitly warns against using. |
| `warn_nonconforming <file> <label>` | fn | Prints a loud, per-heading, line-numbered, reason-specific block to stderr for every non-conforming heading (naming the specific defect: bad number token vs. unrecognized marker vs. both, plus the `[DESCOPED]` → `[COMPLETED WITH EXCLUSIONS]` guidance when applicable). Returns 1 if any were found, 0 otherwise — the caller uses this return to decide whether to take the INCONCLUSIVE branch (lines 184–225). |

No changes to this library are needed for the fix; both required predicates already exist and are
already used correctly elsewhere in the same file tree (see Finding 5).

### 2. Site A — `skill-orchestrate-hard/SKILL.md`, H1 per-phase dispatch selection

Current exact code (lines 510–529, inside `#### State: planned or implementing — Per-Phase
Dispatch (H1)`, itself starting at line 492):

```bash
next_phase=""
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than re-derived
  # inline. Uses the library's OPEN alternation (NOT STARTED|IN PROGRESS|PARTIAL|BLOCKED) and
  # extract_phase_number so a non-conforming heading is never silently mis-selected or truncated.
  . .claude/scripts/lib/phase-heading-patterns.sh
  next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1)
  if [ -n "$next_heading" ]; then
    next_phase=$(extract_phase_number "$next_heading") || next_phase=""
    if [ -z "$next_phase" ]; then
      warn_nonconforming "$plan_path" "orchestrate-hard-next-phase" || true
      echo "[hard-orchestrate] H1: next-phase heading-scan found a non-conforming heading — refusing to guess a phase number; see warning above." >&2
    fi
  fi
fi
```

Line 521's grep is the choke point: because `PHASE_HEADING_ERE` requires the conforming number
grammar, a line like `### Phase 4C: ... [IN PROGRESS]` never enters the grep's output at all.
`next_heading` instead becomes whatever the FIRST conforming OPEN-status heading after it is
(e.g. `### Phase 5: ... [NOT STARTED]`), which `extract_phase_number` then parses cleanly — so
the `if [ -z "$next_phase" ]` branch at line 524 (which contains the only `warn_nonconforming`
call at this site) never fires; it is provably dead code given the grep that feeds it.

**Downstream consequence of the current structure** (relevant to the posture decision below):
the subsequent `if [ -n "$next_phase" ] / elif [ "$last_skeleton" = "true" ] / else` cascade
(lines 531–603) has exactly three outcomes: dispatch a phase, treat the plan as
skeleton-exhausted (→ `pr_ready`), or treat the plan as genuinely fully complete ("deferring to
Stage 5 completion gate", line 602). None of the three is correct when `next_phase` is empty
*because the plan is malformed* rather than because every phase is actually closed — the `else`
branch's own comment ("all phases are genuinely complete") is a claim that is false in the
non-conforming case.

### 3. Site B — `skill-implementer-hard/SKILL.md`, Stage 3b single-phase dispatch context

Current exact code (lines 143–165, inside `### Stage 3b: Single-Phase Dispatch Context (H1)`):

```bash
next_phase=""
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Scan phase headings top-to-bottom; first OPEN-alternation heading wins. Sourced from the
  # shared anchor (scripts/lib/phase-heading-patterns.sh) rather than re-derived inline; a
  # non-conforming heading is reported by name rather than silently resuming at a wrong or
  # absent phase -- a silent wrong resume point is more damaging here than a loud stop.
  # Heading form: "### Phase {N or N.1}: {name} [STATUS]"
  . .claude/scripts/lib/phase-heading-patterns.sh
  next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1)
  if [ -n "$next_heading" ]; then
    next_phase=$(extract_phase_number "$next_heading") || next_phase=""
    if [ -z "$next_phase" ]; then
      warn_nonconforming "$plan_path" "implementer-hard-next-phase" || true
      echo "[hard-mode] STOP: resume-scan found a non-conforming phase heading -- refusing to guess a resume point. See warning above." >&2
      exit 1
    fi
  fi
fi

if [ -n "$next_phase" ]; then
  echo "[hard-mode] Per-phase dispatch: targeting phase ${next_phase} (heading-scan)" >&2
elif [ -f "$handoff_file" ] && [ "$(jq -r '.skeleton // false' "$handoff_file" 2>/dev/null)" = "true" ]; then
  ... # skeleton-exhaustion detection, next_phase="" (informational only, no exit)
else
  next_phase=1
  echo "[hard-mode] No incomplete phase heading found and no handoff, dispatching phase 1" >&2
fi
```

Same choke point at line 156: the grep already filters to conforming headings, so the `exit 1` at
line 162 (the intended loud stop) is dead code for exactly the same structural reason as Site A.
Note the additional danger here specific to this site's `else` branch (line 178–180): if the
whole plan's conforming OPEN scan comes up completely empty (e.g. a plan where the only open
phase is `4C`, non-conforming, with nothing conforming after it), this site does not fall into
"all complete" — it falls into `next_phase=1`, i.e. it would **re-dispatch phase 1** on a plan
that may already be mostly done. This is arguably worse than Site A's fallthrough and is a second,
distinct illustration of why the whole-file check must run before any of this cascade, not just
before the dead `exit 1` branch.

### 4. Site C (undeclared, found by the audit) — `skill-lean-implementation-hard/SKILL.md`

Not in this task's declared file scope, but a direct hit of the audit the task explicitly
requests. File: `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`,
`### Stage 3: Plan Resolution and Phase Identification` (lines 91–137). Current exact code
(lines 108–124):

```bash
. .claude/scripts/lib/phase-heading-patterns.sh
next_phase_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_file" | head -1)

phase_number=""
if [ -n "$next_phase_heading" ]; then
  phase_number=$(extract_phase_number "$next_phase_heading") || phase_number=""
  if [ -z "$phase_number" ]; then
    warn_nonconforming "$plan_file" "lean-implementation-hard-next-phase" || true
    return error "Non-conforming phase heading found during resume-scan -- refusing to guess a resume point. See warning above."
  fi
fi
```

This is a structural clone of Site B (same grep, same dead `warn_nonconforming`/stop branch, even
matching comment style — "a silent wrong resume point is more damaging here than a loud stop").
It inherits the identical blind spot. This file is owned by the `lean` extension
(`agent-system/extensions/lean/**`), not `core`, and is outside this task's declared `file_scope`.
**Recommendation**: the plan/implementation phase for this task should make an explicit,
documented in-scope/out-of-scope call rather than silently leaving it — either extend
`file_scope` to include it (cheap: same fix pattern, same library, no new predicate needed) or
explicitly defer it to a follow-up task and say so in the plan, per this task's own emphasis on
deliberate, recorded decisions rather than silent scope drift.

### 5. Consumer audit — sites that are already correctly wired

Ran `grep -rl 'phase-heading-patterns.sh' agent-system/extensions` (the exact command the
library's own header specifies for finding consumers) and checked every non-test, non-doc,
non-manifest hit for the same filter-before-check ordering bug:

| Site | Role | Verdict |
|---|---|---|
| `scripts/update-task-status.sh` `count_plan_phases()` + D3 gate (lines 276–334) | TOTAL/DONE phase-accounting gate for the `implement` postflight transition | **Correctly wired.** Calls `has_nonconforming_phase_headings` (line 318) and takes a distinct, named `INCONCLUSIVE` branch (line 325–329) *before* trusting `PHASE_CHECK_TOTAL`/`PHASE_CHECK_DONE`. This is the strongest reference implementation of the "whole-file check first" shape in the codebase — recommended as the model to copy. |
| `scripts/skill-base.sh` `skill_corroborate_phase_counts()` (lines 663–724) | Handoff-recovery evidence corroboration | **Correctly wired.** `has_nonconforming_phase_headings` gates the branch at line 711 before the corroborated counts are trusted; on a hit it warns and leaves `plan_markers_verified=absent` rather than trusting `_cpc_total`/`_cpc_completed`. |
| `scripts/validate-artifact.sh` (lines 210–264) | Plan-artifact linter | **Correctly wired** (advisory-first by design, D3). Calls `nonconforming_phase_headings` unconditionally (line 227) and warns regardless of strict mode; the later Verification-Tier loop over conforming-only headings (line 247) is a separate, already-independently-warned advisory concern, not a silent selection. |
| `agents/general-implementation-agent.md` / `general-implementation-hard-agent.md` Stage 5a marker-repair (lines ~418–436 / ~295–315) | Bulk stale-marker repair loop | **Correctly wired.** `has_nonconforming_phase_headings` check and `warn_nonconforming` call precede the `stale_total` grep and the repair loop; a non-conforming heading is skipped from repair (never mis-repaired) after having already been named. |
| `commands/task.md` Step 3 (lines 621–643) | `/task --review` phase-status enumeration for human display | **Correctly wired** (informational, not a selection). `has_nonconforming_phase_headings`/`warn_nonconforming` run immediately after the enumeration grep and before the categorization step; the warning is unconditional regardless of what `$phases` contains. |
| `skills/skill-orchestrate/SKILL.md` recovery diagnostic (lines 717–768) | Missing/stale-handoff DIAGNOSTIC-ONLY phase-count recovery (never drives a status transition, per its own comment at line 725) | **Correctly wired**, and also a different kind of site than A/B/C — it is not a "select the next phase to dispatch" scan, so even before the `has_nonconforming_phase_headings` check at line 742 was added it could not have caused the same out-of-order-dispatch consequence; it is included here for completeness since it is a literal hit of the audit grep. |
| `scripts/update-phase-status.sh` (line 135) | Look up the heading for one CALLER-SUPPLIED, already-validated phase number | **Not applicable / documented exception.** Uses `PHASE_HEADING_PREFIX` parameterized on a specific number, not a "scan for the next open phase" filter — plan-format.md's consumer list explicitly calls this out as "the one deliberately parameter-driven site." No blind spot: if the given number's heading doesn't exist verbatim, the lookup simply fails, it never silently substitutes a different phase. |
| `scripts/update-task-status.sh` `first_phase_heading` (line ~516, inside plan-initialization) | First-phase auto-advance-to-IN_PROGRESS convenience on plan creation | **Same blind-spot *shape*, lower severity.** `first_phase_heading=$(grep -m1 -E "${PHASE_HEADING_ERE}.*\[NOT STARTED\]" "$plan_file" \|\| echo "")` filters to conforming headings with no whole-file conformance check first. Unlike Sites A/B/C this is not a resume/dispatch decision — the adjacent comment at line 522–524 documents it as "Superseded by the base agent owning every per-phase transition directly; this call is a redundant convenience, recoverable via the agent's own explicit calls. Non-fatal." Recommended for an explicit, recorded decision in the plan (fix it for consistency, or explicitly leave it and cite this self-documented low-severity rationale) rather than silent omission. |

Test/doc/manifest hits from the same grep (`tests/test-phase-heading-patterns.sh`,
`tests/test-reconcile-handoff-status.sh`, `tests/test-deploy-propagation.sh`,
`tests/test-errors-append.sh`, `tests/test-validate-handoff.sh`,
`tests/test-corroborate-phase-counts.sh`, `scripts/check-extension-docs.sh`, `manifest.json`,
`rules/plan-format-enforcement.md`, `context/patterns/system-defect-discrimination.md`,
`context/guides/extension-development.md`, `context/formats/plan-format.md` itself) are either
test fixtures for the library's own regex behavior, doc cross-references, or the manifest's
file-list entries — none contain an independent next-phase selection scan and are not part of
this audit's blast radius.

**No test currently exercises the exact bug at Sites A/B/C** (`test-phase-heading-patterns.sh`
tests the library's regexes/functions in isolation; there is no existing shell-testable unit for
the SKILL.md-embedded resume-scan logic itself, since that logic lives inside markdown pseudo-bash
blocks rather than a standalone `.sh` script). Flagging this as a verification gap the
implementation phase should address, e.g. via a small `bash -c` harness reproducing the site's
exact block against a fixture plan containing the `4C`/`5` pattern from the task's verification
bar, asserting the loud warning appears and phase 5 is NOT selected.

### 6. `plan-format.md`'s "Canonical phase-heading shape" subsection — current state

Lines 105–160 (406-line file). Confirmed still states the D1 decision verbatim as described in
the task: "Letter-suffixed sub-phases (`3a`) are deliberately not supported by any consumer and
must not be used. This is a decision, not an unimplemented feature... **This prohibition was
re-affirmed, not merely repeated**, after a triggering artifact used `3a`/`3b`/`3c`: the general
fix for that observed gap is loud non-conformance detection (below) rather than a widened
grammar..." (lines 112–119). The "Non-conforming headings" paragraph (lines 121–127) states the
closed-contract framing verbatim: "It is never silently dropped, collapsed into an adjacent
number, or counted toward either TOTAL or DONE. This is a closed contract, not an aspiration."

The consumer list at lines 147–160 **already names both hard-mode resume-point scans** ("...
`skill-implementer-hard`'s and `skill-lean-implementation-hard`'s resume-point scans, and
`skill-orchestrate`'s (and `skill-orchestrate-hard`'s) recovery-count and `next_phase` greps")
— i.e. the doc's own consumer list already anticipated `skill-lean-implementation-hard` as a
consumer of this contract, reinforcing that Site C (Finding 4) is squarely in scope of what this
document promises is closed, even though it sits outside this task's declared `file_scope`. This
doc's own text is consistent with fixing Site C in the same pass, or explicitly noting why not.

No change to `plan-format.md`'s prose contract is needed — the gap is purely in the call sites,
not in the documented policy. The one edit this task's `file_scope` inclusion of
`plan-format.md` most plausibly implies: once the fix lands, update the consumer-list sentence
(and/or add a short implementation note) to record that the resume-scan sites' wiring was
verified/repaired, so a future reader doesn't have to re-derive that the "closed contract" claim
is actually true end-to-end. Per `no-task-references-in-deliverables.md`, any such edit must not
cite this task by number — reference the fix by its actual mechanism (e.g. "the resume-scan sites
now run `has_nonconforming_phase_headings` before selection") instead.

## Posture Decision

**Recommendation: keep the two postures deliberately different, but give
`skill-orchestrate-hard`'s posture a structurally real branch instead of relying on the
`next_phase`-empty fallthrough.**

Reasoning:

1. **`skill-implementer-hard` (and, if brought into scope, `skill-lean-implementation-hard`) are
   single-shot leaf workers.** Their non-conforming-heading check runs in the skill's own bash
   preamble, strictly *before* any `Agent tool` dispatch — confirmed by reading Stage 3b/Stage 3
   in full: the `exit 1` (Site B, line 162) sits above the first `Agent tool:` block in the file.
   No subagent has been dispatched yet, so no `.orchestrator-handoff.json` write is expected or
   owed at this point (the H9 wrap-up contract applies to a *dispatched* agent's own termination,
   not to the dispatching skill's own precondition check). A raw `exit 1` here is safe, loud, and
   unambiguous: the caller (a human running `/implement N --hard` directly, or
   `skill-orchestrate-hard`'s `Agent tool` call which will observe the dispatch failure) is
   already equipped to see and react to a failed dispatch. **Keep `exit 1` at Site B** (and adopt
   the identical shape at Site C if it is folded into this task's scope).

2. **`skill-orchestrate-hard` is not a leaf worker — it IS the long-running orchestration loop**,
   with its own established, already-used terminal-condition vocabulary (`EXIT (partial)` /
   `EXIT (success, ...)`, used at six other points in the same 1453-line file, e.g. lines 715,
   723, 735, 1236, 1305, 1313). A raw `exit 1` from inside this skill's own bash preamble would be
   a nonlocal, uncontrolled jump out of the entire `/orchestrate --hard` command execution, with
   no `EXIT (...)` bookkeeping, no task-status transition, no message shaped like every other
   terminal path in the file. That would be a worse outcome than the bug it replaces, not a
   parallel fix.
3. **The task description's characterization of the current posture — "warns and leaves
   `next_phase` empty" — is accurate as prose but not safe as implemented.** Tracing the
   surrounding `if [ -n "$next_phase" ] / elif [ "$last_skeleton" = "true" ] / else` cascade
   (lines 531–603) shows that an empty `next_phase` is NOT itself a terminal outcome — it falls
   through into one of the other two branches, both of which assert a specific, different claim
   ("skeleton exhausted, transition to `pr_ready`" or "all phases genuinely complete, defer to
   Stage 5"). Neither claim is true when the real reason `next_phase` is empty is "the plan is
   malformed and the true next phase is unknown." Simply moving the existing dead
   `warn_nonconforming` call earlier (to run on the whole file before the grep) without also
   restructuring the branch would still leave the false-completion risk in place — it would only
   add a warning to stderr on the way to the same wrong conclusion.
4. **Recommended concrete shape for the fix at Site A** (for the planning phase to size and word
   precisely): run `has_nonconforming_phase_headings "$plan_path"` immediately after sourcing the
   library and before the `next_heading` grep; on a hit, call `warn_nonconforming` (reusing the
   existing label `"orchestrate-hard-next-phase"`) and route to a **new, distinct branch** that
   does not set `next_phase`, does not fall into the `last_skeleton` or "all complete" branches,
   and instead logs a targeted message and takes this file's own `EXIT (partial, ...)` convention
   — mirroring the shape already used at lines 712–716 ("no handoff, no blockers" → log + `EXIT
   (partial)`). This keeps the two sites' postures deliberately different for a documented reason
   (leaf worker vs. orchestration loop) while making `skill-orchestrate-hard`'s posture actually
   safe rather than merely descriptively "empty."
5. **`skill-implementer-hard`'s `else: next_phase=1` fallback** (Finding 3) needs the same
   whole-file gate applied *before* it, not just before the dead `exit 1` — otherwise the fix
   only closes the false-warn-then-guess-5 case and leaves the (arguably worse)
   false-re-dispatch-phase-1 case open when the only open phase in the whole file is
   non-conforming.

## Risks & Mitigations

- **Risk**: fixing only the grep line without restructuring the surrounding `if/elif/else` at
  Site A silently reintroduces a milder version of the bug (a warning is printed, but the wrong
  branch is still taken). **Mitigation**: the plan must treat the non-conforming case as a third,
  first-class branch with its own `EXIT (partial, ...)`, not a value of `next_phase=""` that is
  indistinguishable from "genuinely done."
- **Risk**: Site C (`skill-lean-implementation-hard`) is a real instance of the exact bug but sits
  outside the declared `file_scope`; silently ignoring it would leave `plan-format.md`'s own
  consumer list (which already names it) inconsistent with reality. **Mitigation**: the plan
  should make an explicit in-scope/out-of-scope call and record the reasoning, per this task's own
  standard for the two declared sites' postures.
- **Risk**: `update-task-status.sh`'s `first_phase_heading` site (line ~516) has the same
  filter-before-check shape but is explicitly documented as non-fatal/redundant. Over-fixing it
  could add unnecessary complexity to a path already scheduled for removal via the "agent owning
  every per-phase transition directly" comment. **Mitigation**: treat as an explicit-decision item
  (fix minimally for consistency, or record why not) rather than a required change.
- **Risk**: no existing automated test exercises the resume-scan sites' embedded bash directly
  (they live in markdown, not `.sh` files). **Mitigation**: the implementation phase should add a
  small fixture-driven `bash -c` check reproducing the task's own verification bar (`4C`
  `[IN PROGRESS]` followed by `5` `[NOT STARTED]` → loud warning, no phase-5 selection; a fully
  conforming plan resolves unchanged) alongside `bash -n` syntax validation of the edited
  `SKILL.md` code blocks.

## Context Extension Recommendations

None — `plan-format.md`'s "Canonical phase-heading shape" subsection and
`phase-heading-patterns.sh`'s header already fully document the grammar, the closed contract, and
the consumer-discovery mechanism. The only recommended doc touch is the small "verified/repaired"
note on `plan-format.md`'s consumer-list sentence described in Finding 6, which is in-scope
(the file is in this task's declared `file_scope`) rather than a new context-gap.

## Appendix

**Search queries / commands used**:
- `grep -n "PHASE_HEADING_ERE\|PHASE_STATUS_OPEN_ERE\|next_phase\|next_heading\|warn_nonconforming\|has_nonconforming\|nonconforming_phase_headings\|extract_phase_number" <file>` against both declared SKILL.md files
- `grep -rl 'phase-heading-patterns.sh' agent-system/extensions` (the library's own documented
  consumer-discovery command)
- Full reads of `phase-heading-patterns.sh` (225 lines), `plan-format.md` lines 100–160,
  `skill-orchestrate-hard/SKILL.md` lines 490–605 and 700–770 and 1254–1320,
  `skill-implementer-hard/SKILL.md` lines 120–250, `skill-lean-implementation-hard/SKILL.md`
  lines 85–139, `update-task-status.sh` lines 270–340 and 495–533, `skill-base.sh` lines 655–725,
  `validate-artifact.sh` lines 210–265, `general-implementation-hard-agent.md` lines 285–320,
  `commands/task.md` lines 615–644, `skill-orchestrate/SKILL.md` lines 695–795
- `git log --oneline -5` to confirm dependency tasks 959/957 have landed
