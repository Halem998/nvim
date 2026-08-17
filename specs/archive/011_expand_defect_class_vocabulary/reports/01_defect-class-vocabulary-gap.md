# Research Report: Expand defect_class Vocabulary

- **Task**: 11 - expand_defect_class_vocabulary
- **Started**: 2026-08-10T23:05:00Z
- **Completed**: 2026-08-10T23:40:00Z
- **Effort**: 1 hour
- **Dependencies**: None (independent of the sibling session-id-mismatch fix; this task only adds
  vocabulary/documentation, it does not touch lock-acquire call sites)
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/system-defect-record.sh` (the enum's validated
    definition)
  - `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (the Signal A
    table, the canonical vocabulary enumeration)
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
    `skill-orchestrate-hard/SKILL.md` (defect_class consumer call sites)
  - `specs/errors.json` (the three grounding error records plus the gap record itself)
  - `agent-system/extensions/core/scripts/install-extension.sh` (`merge_index_entries`, the
    orphan-drift root cause)
  - `agent-system/extensions/core/hooks/validate-handoff-location.sh` (the regex-boundary root
    cause, referenced by error text; not opened directly — line/content cited from the error
    record and confirmed against the discrimination doc's own citation of the same hook)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- `defect_class` is a single closed enum, validated in exactly one place —
  `agent-system/extensions/core/scripts/system-defect-record.sh`'s `case` statement — and
  documented in exactly one canonical table — the Signal A table in
  `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`. These are the
  only two files that enumerate the vocabulary; both are already named in the task's
  `file_scope`.
- All three grounding instances genuinely lack a fitting existing class. None can be
  folded into `HANDOFF_MISLOCATED`, `SOURCE_STORE_BOUNDARY_VIOLATION`, or any of the other eight
  — each names a materially different failure shape than every existing entry (detailed
  shape-by-shape comparison below).
- Minimum viable addition: three new classes, matching the task's own suggested shapes —
  `SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, `DEPLOY_ORPHAN_DRIFT`.
- No existing class is renamed, removed, or reworded. No new detector is wired — per the
  document's own precedent (`ARTIFACTS_MISSING_ON_SUCCESS` was added to the vocabulary before any
  detector existed for it), naming the vocabulary and wiring a recorder call are separate,
  sequential pieces of work; this task is scoped to the former only, exactly as its WORK section
  states.
- Consumers that switch on `defect_class` value (`skill-orchestrate/SKILL.md`,
  `skill-orchestrate-hard/SKILL.md`) all hardcode one existing class per call site and require no
  changes — none of them contains a generic switch/dispatch over the full enum that would need a
  new arm for the three additions.

## Context & Scope

The task's own description supplies the grounding: `err_1786349061588_fqHbUZ` records that the
ten-instance Signal A enum covers none of four shapes surfaced in one batch (lock/session
contention, hook-regex defects, plan-marker drift, deploy-ghost index entries), of which three are
in scope here per the WORK section (plan-marker drift is not named as a target instance and is
left out — see "Excluded from scope" below).

Scope is: locate every enumeration of `defect_class`, confirm the three grounding instances lack a
fit, and determine the minimum new-class set plus the exact documentation edits needed. This
report does not implement the edits (research phase); it hands the planner/implementer an exact,
citation-backed change set.

## Findings

### Where defect_class is enumerated

Exactly two files enumerate the vocabulary (confirmed by grepping the whole
`agent-system/extensions` tree for every existing class name, e.g. `OFF_SCHEMA_STATUS`):

1. **`agent-system/extensions/core/scripts/system-defect-record.sh`** — the validated definition,
   three locations within the one file:
   - Header comment, line 16: `# One of the ten Signal A instances (see the discrimination
     document's Signal A table) --`
   - `usage()` text, lines 91-95: the pipe-delimited class list shown on `-h`/argument error
   - `case "$defect_class" in` validation, lines 160-166 (the actual gate — an unlisted value
     exits 1 with the message at line 165, which also says "ten Signal A instances")
2. **`agent-system/extensions/core/context/patterns/system-defect-discrimination.md`** — the
   canonical Signal A table (lines 72-88, 10 rows), which is the document
   `system-defect-record.sh`'s own comments point readers to. This is where new instances get
   *defined* (name + one-line description + "where computed" pointer); the script's enum is a
   restatement/validator of the same closed list.

Both files are already the task's declared `file_scope`, confirming this is the complete target
set. No JSON schema constrains `defect_class` — `events-schema.json` has no `defect_class`
property (the `detail` object is `additionalProperties: true` by design, per the discrimination
doc's deduplication-rule section), so no schema file needs editing.

### Consumers that switch on defect_class value

`grep -rln "defect_class"` across `agent-system/extensions` returns exactly four files: the two
above, plus `skills/skill-orchestrate/SKILL.md` and `skills/skill-orchestrate-hard/SKILL.md`.
Both SKILL.md files call `system-defect-record.sh --defect-class <LITERAL>` at five fixed call
sites total (`HANDOFF_STALE_OR_ABSENT`, `HANDOFF_MISLOCATED`, `ARTIFACTS_SHAPE_MISMATCH`,
`OFF_SCHEMA_STATUS` twice) — each site hardcodes one specific existing class as a literal
argument. Neither file contains a generic `case`/dispatch keyed on `defect_class` value that
would need a new arm for the three additions; they are producers of specific values, not
consumers that branch on the full enum. **No change needed in either SKILL.md for this task.**

Two further incidental references were checked and confirmed out of scope: `commands/orchestrate.md:675`
cites `OFF_SCHEMA_STATUS` once as a worked example row in a table, not an enumeration of the
vocabulary; `scripts/reconcile-task-status.sh:213` cites the same class in a comment pointing back
to the discrimination doc. Neither restates or validates the enum.

### Instance-by-instance fit analysis

The task instructs: "confirm the three instances above genuinely lack a fitting class (do not add
classes for shapes that already have one)." Below, each grounding error is checked against all ten
existing classes.

**1. `err_1786349061524_pY97cE` — MT-1/MT-4 session-id mismatch (lock/session contention)**

> `skill-orchestrate/SKILL.md:1960` acquires per-task locks with suffixed
> `${session_id}_${task_num}` while Stage MT-1 registers the batch registry entry under the bare
> `session_id`; `session_contention()` self-exclusion (`lib/file-scope-overlap.sh:115`) is exact
> string match, so the batch contends against its own registration and every task is refused.

No existing class fits: `STATE_SYNC_DIVERGENCE` is specifically `state.json`/`TODO.md`
desynchronization (a different pair of files entirely); `OFF_SCHEMA_STATUS` is a status-value
vocabulary violation, not a locking bug; none of the handoff/artifact/task-reference/format
classes touch locking or session-id identity at all. This is a genuinely new shape: two call sites
disagree on what string identifies "the same unit of work," breaking an exact-match
self-exclusion check.

**2. `err_1786349061492_XpY38x` — 3-digit handoff-location regex (hook-regex/path-depth boundary)**

> `validate-handoff-location.sh:65` allow-pattern uses exact-count `[0-9]{3}_` so every task dir
> numbered >999 fails to match; handoff writes for tasks 1000-1003 are rejected exit 2.

This is adjacent to, but distinct from, `HANDOFF_MISLOCATED`. `HANDOFF_MISLOCATED` names *a
handoff actually written outside its task directory* — a content/location defect in what was
written. This error is the opposite failure mode: a **correctly-located** handoff write is
**wrongly rejected** by the detector itself, because the detector's own regex encodes a hidden
3-digit boundary assumption that real task-directory numbers (1000+) violate. Folding this into
`HANDOFF_MISLOCATED` would conflate "the write is in the wrong place" with "the gate that checks
placement has a boundary bug" — two different bugs with different fixes (one is a writer bug, the
other is a detector bug). No other existing class touches regex/pattern boundary correctness.

**3. `err_1786349061556_LuKGif` / `err_1786350581273_TAWj0I` — deploy orphan-file drift**

> `orchestration/orchestration-validation.md` and `orchestration/subagent-validation.md` exist
> only in deployed `.claude/context/index.json` with no source-store owner ... `install-extension.sh
> merge_index_entries` is purely additive so no source edit removes them.
> [...] The live `.claude/` tree carries 4 orphan files absent from a clean scratch regenerate ...
> Declared-vs-deployed parity for `provides.*` categories is one-directional by design.

This is adjacent to, but distinct from, `SOURCE_STORE_BOUNDARY_VIOLATION`. That class fires on a
**direct write under `.claude/**`** — an agent authoring a deploy-artifact path instead of the
source store, i.e. a write-time violation. This defect has no such write: the files were
presumably deployed correctly at some past point, then their source-store owner was removed
through a legitimate edit, and the deploy engine's additive-only merge left the deployed copy
(and its index entry) behind permanently. It is a **drift-over-time / stale-entry accumulation**
defect, not a boundary-violating write. No other existing class names "deployed artifact outlives
its source."

**Conclusion**: all three grounding instances are confirmed to lack a fitting existing class, for
the reasons above — each is materially different in kind (not just in wording) from every one of
the ten existing entries. Per the discrimination document's own instruction ("a closed,
extensible list — extending it is a future task's decision, not silently done by a detection
site"), this is exactly the deliberate-extension case the document anticipates.

### Excluded from scope: plan-marker drift

`err_1786349061588_fqHbUZ` (the gap record) names a fourth shape — "plan-marker drift" — that the
task's own WORK section does not list among the three target instances to name, and no concrete
grounding error record for it was found in `specs/errors.json` (only the three cited above have
dedicated records at the cited IDs). Adding a class for it now would violate the task's explicit
minimum-set instruction ("add the minimum set of new classes needed to name them precisely" —
scoped to the three named instances). Recommend leaving it for a future task once a concrete
grounding instance exists, consistent with how this document already treats
`ARTIFACTS_MISSING_ON_SUCCESS` (named, not yet detected anywhere).

## Decisions

- **Three new classes, minimum set, matching the task's suggested shapes exactly**:

| New class | One-line definition | Where instance evidence lives | Attribution (Signal B) |
|---|---|---|---|
| `SESSION_LOCK_CONTENTION` | A task-lock acquire/release call keyed to a session-id string that does not match the session-id used to register the same unit of work elsewhere (e.g. batch admission), causing exact-match self-exclusion logic to spuriously contend against the caller's own registration. | `err_1786349061524_pY97cE` | `skills/skill-orchestrate/SKILL.md` (the acquire call site at the cited line) |
| `HOOK_REGEX_BOUNDARY_DEFECT` | A validation hook's regex or path-depth pattern encodes an unstated boundary assumption (e.g. a fixed digit-count quantifier) that silently breaks once real inputs cross that boundary, wrongly rejecting (or wrongly accepting) otherwise-valid inputs. | `err_1786349061492_XpY38x` | `hooks/validate-handoff-location.sh` |
| `DEPLOY_ORPHAN_DRIFT` | A file (or index entry) present in the deployed `.claude/**` tree with no corresponding source-store owner, surviving indefinitely because the deploy/merge routine is purely additive with no stale-entry pruning step. | `err_1786349061556_LuKGif`, `err_1786350581273_TAWj0I` | `scripts/install-extension.sh` (`merge_index_entries`) |

- **No existing class is renamed, removed, or reworded** — verified by diffing the proposed edits
  against the current ten rows/enum values; every existing row's text is preserved verbatim.
- **No detector is wired in this task** — the three new classes join the vocabulary undetected,
  mirroring the document's own precedent for `ARTIFACTS_MISSING_ON_SUCCESS` ("not currently
  computed anywhere"). Wiring `system-defect-record.sh` calls at the three root-cause sites
  (the lock-acquire call, the regex hook, the deploy-merge routine) is downstream work for
  whichever task actually fixes those defects — recording the vocabulary and fixing/instrumenting
  the site are separate, sequential pieces of work per this document's own stated pattern.
- **Naming style**: `SCREAMING_SNAKE_CASE`, matching all ten existing values.

## Recommended Edits (exact, for the implementation phase)

### 1. `agent-system/extensions/core/scripts/system-defect-record.sh`

- Line 16 header comment: `the ten Signal A instances` -> `the thirteen Signal A instances`.
- Lines 91-95 `usage()` text: append the three new values to the pipe-delimited list (place after
  `STATE_SYNC_DIVERGENCE`, preserving every existing entry unchanged):
  `...STATE_SYNC_DIVERGENCE|SESSION_LOCK_CONTENTION|HOOK_REGEX_BOUNDARY_DEFECT|DEPLOY_ORPHAN_DRIFT`
- Lines 161-163 `case` validation: add the three new values as additional matched literals in the
  same no-op arm (`;;`), preserving every existing literal unchanged.
- Line 165 error message: `the ten Signal A instances` -> `the thirteen Signal A instances`.

### 2. `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`

- Signal A table (lines 72-88): append three new rows after the `STATE_SYNC_DIVERGENCE` row,
  using the definitions and "where computed" text from the Decisions table above. For "where
  computed," follow the existing convention used for `ARTIFACTS_MISSING_ON_SUCCESS`
  (**not currently computed anywhere** — see the detection hole note) since no detector calls
  `system-defect-record.sh` for these three yet.
- "Extending the Signal A vocabulary is an explicit decision, not a silent act" section (lines
  122-132): add a short paragraph analogous to the existing one, naming the three new instances
  and stating they were added deliberately to name three concrete grounding defects. Describe the
  defects by shape/type rather than by opaque error-record ID, consistent with this section's
  existing style (it names the prior five additions by class name only, with no ID citations
  anywhere in the current file — confirmed by inspection): "the `lock_session_self_contention`,
  `hook_regex_defect`, and `deploy_ghost_index_entries`/`deploy_orphan_files_undercounted` error
  shapes" rather than the raw `err_...` identifiers. `err_...` IDs are telemetry identifiers, not
  task numbers, and are not themselves prohibited by the no-task-references rule — but matching
  this document's own established citation style is preferable to introducing a new one.
- Wherever "the ten instances" (or equivalent count language) appears in prose, update to
  "thirteen" — checked occurrences: none found stated as a bare number outside the script (the doc
  itself never writes out "ten" as prose; it enumerates the table directly), so likely no doc-side
  count-word edit is needed beyond the table itself — implementer should re-grep for `\bten\b`
  in this file before finalizing to confirm.

### Not in scope / explicitly not edited

- The deduplication rule's identity-key list (lines 341-343) already only names five of the ten
  existing instances (a pre-existing staleness predating this task, not something this task's
  WORK section asks to fix). Recommend flagging as a separate, small documentation-hygiene item
  rather than folding into this task's diff, to keep this task's change minimal and reviewable.
- `commands/orchestrate.md` and `scripts/reconcile-task-status.sh` — both cite one existing class
  as an example/comment, not as an enumeration; no edit needed.
- `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md` — no generic
  switch over `defect_class`; no edit needed (confirmed above).
- `context/schemas/events-schema.json` — no `defect_class` property exists; `detail` is
  `additionalProperties: true` by design; no edit needed.

## Risks & Mitigations

- **Risk**: a future reader assumes the three new classes are already wired to a detector because
  they now appear in the enum/table. **Mitigation**: the recommended table rows explicitly state
  "not currently computed anywhere," following the document's own existing convention for
  `ARTIFACTS_MISSING_ON_SUCCESS", so this is not a new risk pattern.
- **Risk**: scope creep — fixing the underlying `err_1786349061524_pY97cE` session-id mismatch
  bug from within this task. **Mitigation**: this task's CONSTRAINT explicitly forbids
  multi-task `/orchestrate` until that sibling task lands, and this task's own scope (per WORK) is
  vocabulary-naming only; the recommended edits above touch no lock-acquire, hook-regex, or
  deploy-merge logic.
- **Risk**: the pre-existing stale identity-key list (dedup rule) is mistaken for something this
  task must reconcile. **Mitigation**: called out explicitly above as excluded, with a recommended
  follow-up framing distinct from this task's diff.

## Appendix

- Grounding error records: `err_1786349061588_fqHbUZ` (the gap), `err_1786349061524_pY97cE`,
  `err_1786349061492_XpY38x`, `err_1786349061556_LuKGif`, `err_1786350581273_TAWj0I` — all read
  from `specs/errors.json`.
- Search commands used: `grep -rn "defect_class" agent-system/extensions --include="*.sh"
  --include="*.md"`; `grep -rln "OFF_SCHEMA_STATUS" agent-system/extensions`; `grep -n
  "merge_index_entries" agent-system/extensions/core/scripts/*.sh`.
- `agent-system/extensions/core/scripts/system-defect-record.sh` lines 16, 91-95, 160-166 (enum
  definition and validation).
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` lines 72-88
  (Signal A table), 122-132 (deliberate-extension precedent), 341-343 (dedup identity-key list,
  noted stale but out of scope).
