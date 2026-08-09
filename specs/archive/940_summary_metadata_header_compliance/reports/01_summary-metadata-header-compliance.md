# Research Report: Task #940

**Task**: 940 - summary_metadata_header_compliance
**Started**: 2026-07-28T00:00:00Z
**Completed**: 2026-07-28T00:00:00Z
**Effort**: ~1 session
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), live reproduction against
  scripts/validate-artifact.sh, git history, filesystem census of specs/*/summaries/*.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause (item A), established empirically, not assumed**: `general-implementation-agent.md`'s
  own Stage 6 ("Create Implementation Summary") carries a literal, concrete, ready-to-copy Markdown
  skeleton that has never matched `summary-format.md`. It opens with `**Completed**:` /
  `**Duration**:` and has no `**Task**:`, `**Status**:`, `**Started**:`, `**Artifacts**:`, or
  `**Standards**:` line at all — precisely the five fields the validator reports missing.
  `general-implementation-hard-agent.md`'s Stage 6 says "Same as base agent," so hard-mode
  dispatches inherit the identical defective skeleton.
- This is not a case of the spec being unavailable. It is actively injected into **every** dispatch:
  `skill-implementer/SKILL.md`'s Stage 4b reads `summary-format.md` in full and inlines it into the
  subagent prompt as a `<artifact-format-specification>` block reading "You MUST follow this format
  specification exactly." This has been standing behavior since a commit long predating the recent
  dispatches under review (`task 863 phase 1`), so its mere presence cannot explain the compliance
  gap — the agent's own later, concrete Stage 6 instruction wins over the earlier, generic,
  cross-referenced prose block, because nothing in either file tells the agent to reconcile the two
  when they conflict.
- A **second, independent, real-time enforcement path already exists and is also being overridden**:
  `hooks/validate-plan-write.sh` is a generic PostToolUse hook that fires on every `Write`/`Edit` to
  `specs/*/summaries/*.md` (not just plans, despite the filename), runs `validate-artifact.sh`
  without `--fix`, and injects an `additionalContext` message ("ARTIFACT VALIDATION FAILED... You
  MUST delegate...") back into the *same* agent turn immediately after the non-compliant write. This
  means the defect survives two independent, already-wired advisory checks — the postflight
  Stage 6a call in `skill-implementer/SKILL.md` and this real-time hook — not merely one silently
  ignored cross-reference.
- **This is a long-standing, wide-spread condition, not a 3-dispatch anomaly.** A census of
  `specs/*/summaries/*.md` in this repository found at least 20+ prior summaries with no
  `**Task**:` line at all, going back many tasks. The two in-session summaries the delegation
  message points to as the "successful" counter-examples are the only two the census turned up with
  a fully-compliant header, and both were produced under a hand-authored, non-standard dispatch
  prompt (per the delegation message) rather than through the standing template.
- **A distinct, verified secondary bug**: `validate-artifact.sh`'s `--fix` auto-repair path does
  not work on real artifacts and can crash the validator outright. Reproduced live (see Findings):
  its anchor search `grep -n '^- \*\*'` is meant to find the last metadata line, but the actual
  header format (used by both the defective template and the two compliant hand-written summaries)
  never uses a leading `- ` bullet — so the anchor search instead matches the first line-initial
  `- **Bold**:` bullet it finds anywhere in the document (commonly a "What Changed" or
  "Verification" bullet), and the subsequent `sed -i` insertion at that wrong anchor fails on
  ordinary prose (an em dash in the observed reproduction), aborting the whole script under
  `set -euo pipefail` before it ever reaches its own `[FAIL]`/`[PASS]` summary line.
- **Enforcement-posture recommendation (item C)**: keep the check non-blocking, but fix the root
  template (item B) so a compliant run again produces zero warnings, and additionally: (1) fix or
  remove the broken `--fix` anchor logic rather than leave a validator subcommand that can crash on
  ordinary content, and (2) close a related asymmetry — `skill-implementer-hard/SKILL.md` has no
  Stage-6a-equivalent postflight validation call at all (unlike `skill-implementer`,
  `skill-researcher`, `skill-researcher-hard`, `skill-planner`, and `skill-planner-hard`, which all
  call `validate-artifact.sh`). Hard-mode summaries still get the real-time PostToolUse hook (it is
  path-pattern-based, not skill-specific), but they get no final postflight confirmation.

## Context & Scope

Scoped to items A-E of the task description: (A) establish empirically why the required summary
header is not being produced; (B) make the writers emit it; (C) decide and justify an enforcement
posture; (D) explicitly out of scope — no backfill of historical summaries; (E) describe how to
verify a fix (a live fix was not implemented — this is a research-only dispatch — but the exact
verification mechanics and a demonstration of current failure behavior are included below).

All source-of-truth reading was done against `agent-system/extensions/core/**`, per this session's
standing note that the deployed `.claude/` tree is stale on purpose. No comparison in this report
is against the deployed tree; every path cited below is under `agent-system/extensions/core/`
unless explicitly marked otherwise. No agent or skill files were edited.

## Findings

### Codebase Patterns

**The agent's own writing-stage template is the actual point of divergence.**
`agents/general-implementation-agent.md` Stage 6 ("Create Implementation Summary") reads:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Overview
...
## What Changed
...
## Decisions
...
## Plan Deviations
...
## Verification
...
## Notes
...
```

Compare against `context/formats/summary-format.md`'s required metadata block:

```
- **Task**: {id} - {title}
- **Status**: [NOT STARTED] | [IN PROGRESS] | [BLOCKED] | [ABANDONED] | [COMPLETED]
- **Started**: {ISO8601}
- **Completed**: {ISO8601}
- **Effort**: {estimate}
- **Dependencies**: {list or None}
- **Artifacts**: list of linked artifacts summarized
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file
```

and required sections: Overview, What Changed, Decisions, **Impacts**, **Follow-ups**,
**References**.

`scripts/validate-artifact.sh`'s `SUMMARY_METADATA` array is `("Task" "Status" "Started"
"Completed" "Artifacts" "Standards")` and `SUMMARY_SECTIONS` is `("Overview" "What Changed"
"Decisions" "Impacts" "Follow-ups" "References")` — consistent with the format doc, and NOT
consistent with the agent's own Stage 6 skeleton, which is missing `Task`, `Status`, `Started`,
`Artifacts`, `Standards` from the header (matching the five errors named in the task description
exactly) and `Impacts`, `Follow-ups`, `References` from the sections (a defect the task
description did not name, but which the same root cause produces).

`agents/general-implementation-hard-agent.md` Stage 6 reads only "Same as base agent. Path:
`specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md`." — it does not carry its own skeleton, but
inherits the base agent's defective one by reference, so the defect is present in both the base
and hard-mode implementation paths identically.

**The format spec is already injected into every dispatch — this rules out "reference never
loaded" as the cause.** `skills/skill-implementer/SKILL.md` Stage 4b:

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

and Stage 5 wraps it verbatim into the subagent prompt:

```
<artifact-format-specification>
## CRITICAL: Summary Format Requirements

You MUST follow this format specification exactly when writing the implementation summary.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

placed "AFTER the delegation context JSON and BEFORE any other instructions." `git log --all -S
"Stage 4b: Read and Inject Format"` shows this mechanism was introduced at `task 863 phase 1` —
long before the three consecutive failing dispatches the task description reports and long before
the two in-session compliant summaries. Its age and continuous presence rule out "the reference is
listed but never loaded" as the operative cause: it is loaded and force-injected on literally every
`/implement` (base-mode) dispatch, and still the defect persisted across an unknown-but-large
number of historical dispatches (see census below). `skill-implementer-hard/SKILL.md` has the
identical Stage 4b injection (`### Stage 4b: Read Format Specification`), so hard-mode dispatches
receive the same injected spec too.

**A second, independent, already-wired advisory check also fires and is also overridden.**
`hooks/validate-plan-write.sh` (despite its plan-specific filename) is a generic PostToolUse hook
whose path-matching `case` block explicitly includes `specs/*/summaries/*.md` alongside plans and
reports. On every `Write`/`Edit` to a summary path, it runs `validate-artifact.sh` (without
`--fix`) and, on exit code 1, emits:

```
{"additionalContext": "ARTIFACT VALIDATION FAILED for summary: {FILE}\n{output}\n\nYou MUST
delegate artifact creation to the appropriate skill ... Fix the issues above or re-run the
command with proper skill delegation."}
```

This fires in the *same* agent turn, immediately after the write that produced the non-compliant
file — a materially more immediate signal than the postflight-only Stage 6a check. That it, too,
fails to produce compliance corroborates the task description's framing that an advisory signal
firing on effectively every run has been fully desensitized: two independently-wired checks, one
of them real-time and in-band with the writing agent's own turn, both consistently ignored.

**Verified count of the historical scope of the defect.** A scan of every
`specs/*/summaries/*.md` file in this repository for a `**Task**:` line found at least 20 prior
summaries with no such line (a non-exhaustive `head -20` list; the actual count was not fully
enumerated but the search was not close to exhausting the population when the display limit was
hit). This is strong evidence against "3 consecutive dispatches" being an isolated recent
regression — it is a long-standing condition across a large fraction of this repository's
implementation history. No `TBD` placeholder text (the signature of a successful `--fix`
auto-repair) was found anywhere in any summary file, which is explained by the next finding.

**Reproduced live: `validate-artifact.sh --fix` is broken on real artifacts, not merely
ineffective.** Copied an existing non-compliant historical summary
(`specs/908_.../summaries/01_git-index-contention-summary.md`, which has the identical
`**Completed**:` / `**Duration**:`-only header as the current Stage 6 template) to a scratch path
and ran `validate-artifact.sh <copy> summary --fix`:

```
Validating summary: <copy>
  [ERROR] Missing metadata field: **Task**:
  [ERROR] Missing metadata field: **Status**:
  [ERROR] Missing metadata field: **Started**:
  [ERROR] Missing metadata field: **Artifacts**:
  [ERROR] Missing metadata field: **Standards**:
sed: -e expression #1, char 23: unknown command: `-'
```

The script aborts at that `sed` command (under `set -euo pipefail`) without ever reaching its own
`[FAIL] N error(s)` summary line. Diagnosis: the auto-fix anchor search
(`grep -n '^- \*\*' "$artifact_path" | tail -1`) is written to find the *last* metadata line — but
the real metadata convention (used by the Stage 6 template, and by both the format doc's own
example skeleton and the two compliant in-session summaries) is bare `**Field**:` with no leading
`- ` bullet. The anchor search therefore falls through to whatever line-initial `- **Bold**:`
bullet happens to occur last in the whole file — in this reproduction, a `- **Files verified**:
Yes — ...` line deep in the template's own "Verification" section (confirmed via `grep -n '^-
\*\*' | tail -3`). The subsequent multi-line `sed -i "${last_meta_line}a\\ ..."` insertion then
fails on that line's content (an em dash), crashing the whole validation run. Net effect: `--fix`
is not merely a no-op for these artifacts, it can actively abort validation before its own
diagnostic summary prints, and it has never once produced a `TBD`-placeholder-repaired file in
this repository's history.

**Downstream consumption check — no machine reads these header fields.** Searched
`agent-system/extensions/core/scripts/*.sh` for any code that greps/parses `**Task**:`,
`**Status**:`, or `**Started**:` out of a summary file's content. None found.
`reconcile-task-status.sh` only checks for the *existence* of a summary file at a given path (a
phase-transition signal), never its header content. The only two consumers of the header fields
are `validate-artifact.sh`'s own presence check and a human reader. This matters for the
proportionality argument in Decisions below: there is no evidence of any functional/machine
breakage risk from a missing header, only a documentation/readability and audit-trail
consistency cost.

### External Resources

Not applicable — this is a self-contained codebase defect; no external documentation was
consulted.

### Recommendations

1. **Fix `general-implementation-agent.md` Stage 6's inline skeleton in place** to literally
   match `summary-format.md`'s metadata block and section list (Task/Status/Started/
   Completed/Effort/Dependencies/Artifacts/Standards header; Overview/What Changed/Decisions/
   Impacts/Follow-ups/References sections), rather than adding a third cross-reference. This is
   the one file that actually governs the shape of what gets written, for both base and hard
   modes (the hard agent inherits it by "Same as base agent").
2. **Do not rely on `--fix` as a safety net** until its anchor logic is corrected (require the
   anchor to be a metadata-block line specifically — e.g. a line matching the field-name list
   itself, not any bold bullet — and quote/escape the insertion text so ordinary prose content
   cannot break the `sed` command), or until it is replaced with a non-shell-fragile
   implementation. Today it can crash the validator rather than repair the file.
3. **Add a Stage-6a-equivalent postflight `validate-artifact.sh` call to
   `skill-implementer-hard/SKILL.md`**, matching the pattern already used by
   `skill-implementer/SKILL.md`, `skill-researcher/SKILL.md`, `skill-researcher-hard/SKILL.md`,
   `skill-planner/SKILL.md`, and `skill-planner-hard/SKILL.md` (the last two both invoke it as
   `... --fix || true`, i.e. explicitly non-blocking). Hard-mode summaries currently get only the
   generic real-time PostToolUse hook, with no final postflight confirmation step.
4. Leave `hooks/validate-plan-write.sh`'s summary coverage and
   `skill-implementer/SKILL.md`'s Stage 6a exactly as-is mechanically (both are structurally
   sound); the defect was never in whether these checks run, only in what they were checking
   against actually complying with what was written.

## Decisions

- **Enforcement posture (item C): keep it non-blocking, but make a passing run produce zero
  warnings so a warning again carries signal.** Justification:
  - This repository has a standing, explicitly documented preference for defer-not-fail /
    non-blocking guardrails over hard failures for conditions that are not structural facts
    threatening silent, hard-to-attribute harm (`context/patterns/batch-orchestration-guardrails.md`:
    "Defer-not-fail exists to make the system's response to a transient scheduling conflict
    SMALLER than the conflict"; the same file's admission-dimension table explicitly classifies
    `scripts/validate-artifact.sh` as a case where "a defect fails loudly (a validation error)
    rather than silently corrupting a scheduling decision" — i.e. its existing loud *console*
    error output is already doing the intended job of surfacing the defect; only its consequence
    (nothing gates on it) is toothless).
  - No downstream automation parses the header fields (verified above) — the actual harm of a
    missing header is a documentation/audit-trail quality cost, not a functional break. A cost of
    that shape does not meet this repository's own stated bar for escalating to a hard block
    (compare the self-modification hazard, which is BLOCKING specifically because the harm is
    "silent and hard to attribute later" — the opposite of this case, where the harm is neither
    silent, once the template is fixed, nor especially hard to attribute).
  - The tension the task description names is real but resolves the same way once the root cause
    is fixed: an advisory check that fires on 100% of runs is noise; an advisory check that fires
    on <1% of runs (only genuine future regressions) is signal again, and is exactly the
    non-blocking design this repository already prefers elsewhere. Escalating to a hard block
    would be solving a problem that a correct template already eliminates, at the cost of
    departing from a deliberate, repo-wide guardrail philosophy.
  - Rejected alternative: auto-repair via `--fix`. Beyond the crash bug found above, a
    `TBD`-placeholder "repair" makes a non-compliant artifact *look* compliant to the validator
    while supplying zero real information — arguably worse than an honest, visible failure,
    because it would hide the defect from exactly the human reader the header exists to serve.
    `--fix` should not be treated as a substitute for fixing the generation template.

## Risks & Mitigations

- **Risk**: Fixing only the visible five-field header (matching the task description's literal
  complaint) without also fixing the three missing sections (Impacts/Follow-ups/References) would
  leave `validate-artifact.sh`'s section check still failing on every future summary, reproducing
  a variant of the same noise problem one layer down. **Mitigation**: item B's fix should bring
  Stage 6 into full conformance with `summary-format.md` — both the header and the six required
  sections — not just the header fields named in the task description.
- **Risk**: A future implementer fixing item B in isolation might not notice
  `general-implementation-hard-agent.md`'s Stage 6 says "Same as base agent" and could assume it
  needs its own separate fix, adding needless duplication. **Mitigation**: the hard agent's Stage
  6 requires no edit as long as the base agent's Stage 6 is corrected in place — this report
  records that explicitly so the eventual plan does not duplicate the skeleton into both files.
- **Risk**: Repairing `--fix`'s anchor logic is itself a small piece of shell scripting with its
  own fragility (as demonstrated). **Mitigation**: recommendation 2 above deliberately allows
  either "fix the anchor + escaping" or "remove the `--fix` capability for summaries and rely on
  the corrected generation template," rather than mandating a specific shell fix — that decision
  belongs in the plan, informed by how much value a working auto-repair adds once the root
  template is correct (likely marginal, per the Decisions section above).

## Context Extension Recommendations

- **Topic**: Advisory-check desensitization pattern (a check that fires on ~100% of runs is
  functionally equivalent to no check).
- **Gap**: This pattern — a template or generator that structurally cannot satisfy a downstream
  validator, defeating that validator's advisory signal by volume rather than by a single missed
  case — is not currently named anywhere in `context/patterns/` or `context/standards/`. It
  recurred identically here in two independent checks (postflight call + real-time hook).
- **Recommendation**: Consider a short pattern note (e.g.
  `context/patterns/advisory-signal-desensitization.md`) capturing the general principle "a
  passing run should produce zero warnings, or the warning is not doing its job" and the
  diagnostic technique used here (grep the actual historical population of an artifact type for
  the defect before assuming a specific recent regression) for reuse by future `/errors`,
  `/distill --review`, or similar diagnostic work.

## Appendix

- Search queries / commands used:
  - `jq -r '.active_projects[] | select(.project_number == 940) | .description' specs/state.json`
  - `find agent-system/extensions/core -iname "*summary-format*" -o -iname
    "*general-implementation-agent*" -o -iname "*general-implementation-hard-agent*"`
  - `grep -n "summary\|SLUG}/summaries\|Stage 6\|Create.*Summary" skill-implementer/SKILL.md`
  - `git log --all --oneline -S "Stage 4b: Read and Inject Format" -- skill-implementer/SKILL.md`
  - `git log --all --oneline -S "artifact-format-specification" -- skill-implementer/SKILL.md`
  - `grep -rn "validate-artifact.sh" agent-system/extensions/core/` (full-repo call-site census)
  - Live reproduction: `cp specs/908_.../summaries/01_....md <scratch>; bash
    scripts/validate-artifact.sh <scratch> summary --fix`
  - `for f in specs/*/summaries/*.md; do grep -qF '**Task**:' "$f" || echo "$f"; done`
- References:
  - `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage 6, the defective
    template)
  - `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 6, inherits
    by reference)
  - `agent-system/extensions/core/context/formats/summary-format.md` (the spec being diverged
    from)
  - `agent-system/extensions/core/scripts/validate-artifact.sh` (`SUMMARY_METADATA`,
    `SUMMARY_SECTIONS`, the `--fix` anchor bug)
  - `agent-system/extensions/core/skills/skill-implementer/SKILL.md` (Stage 4b injection, Stage 6a
    postflight check)
  - `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md` (Stage 4b injection
    present; Stage 6a-equivalent postflight check absent)
  - `agent-system/extensions/core/hooks/validate-plan-write.sh` (real-time PostToolUse hook,
    covers summaries despite its filename)
  - `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
    (defer-not-fail / non-blocking guardrail philosophy cited in Decisions)
