# Implementation Plan: Fix literature-audit.sh arg validation and /literature --validate schema scoping

- **Task**: 111 - Fix literature-audit.sh arg validation and /literature --validate schema scoping
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/111_fix_audit_arg_validation_and_validate_schema_scoping/reports/01_audit-arg-validation-and-validate-schema-scoping.md
- **Artifacts**: plans/01_audit-arg-validation-and-validate-schema-scoping.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two small, independent correctness fixes in the literature extension's tooling, both re-verified
present in the source store. Defect 1: `literature-audit.sh`'s arg loop silently swallows every
unrecognized token (including `-h`/`--help`) and falls through to a live default audit; the fix
adds the usage/`-h`/unknown-arg-exit-64 handling that `literature-ingest-online.sh` already
implements, plus a guard on `--pdf`'s unchecked operand consumption. Defect 2:
`/literature --validate` Step 2 applies document-level required-field rules to every index entry,
so it fires on ~11k section-level chunk entries that lack those fields by design; the fix scopes
the `missing_fields` check to top-level document entries using the existing `parent_doc` predicate
and reconciles the surrounding prose with what the check actually enforces.

**Edit target**: `agent-system/extensions/literature/` (the source store). `.claude/` copies are
disposable deploy artifacts and MUST NOT be hand-edited — see
`.claude/rules/source-store-deploy-boundary.md`. The research confirmed no source/deploy drift at
task start, so the source store is a clean base.

**Definition of done**: `literature-audit.sh --help` prints usage and exits 0 without converting
anything; an unknown flag exits 64 with a stderr message; and a `--validate` run over the real
index reports schema warnings only for top-level document entries, with the Step 2 prose and the
Step 4 report heading describing exactly that behavior.

### Research Integration

The research report supplies both the exact edit sites and the two in-repo conventions to reuse
rather than reinvent:

- `literature-ingest-online.sh:153-163` (`show_usage()` heredoc to stderr), `:190-193`
  (`-h|--help)` -> `show_usage; exit 0`), `:196-202` (unknown-arg -> stderr message +
  `show_usage` + `exit 64`) — the template for Phase 1.
- `literature-coverage-delta.sh:212`'s `select(.parent_doc == null or .parent_doc == "")` — the
  canonical top-level-document predicate for Phase 2. The research explicitly ruled out a
  `path`-trailing-slash predicate: that check exists nearby in SKILL.md (lines 413-422) for a
  different purpose (file-vs-directory existence testing) and is not equivalent.
- The research found a **pre-existing prose/implementation mismatch** the task description did not
  mention: Step 2's prose (line 380) lists 7 required fields, but the implementing jq block
  (lines 457-464) checks only 4 (`doc_type`, `source_format`, `authors`, `title`). `id`/`path` are
  covered separately by the schema-shape bucket (lines 397-411); `keywords`/`summary` are checked
  by nothing. Phase 2 reconciles this rather than leaving it wider.
- The research confirmed the book/parent `doc_type: "book"` carve-out at SKILL.md:426-427 needs no
  separate special-casing: that record is itself top-level (`parent_doc` unset), so it is covered
  once the scoping predicate lands.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (`specs/ROADMAP.md` does not exist); no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- `literature-audit.sh` surfaces usage on `-h`/`--help` (exit 0) and rejects unknown arguments
  loudly (stderr + exit 64), matching the existing `literature-ingest-online.sh` convention.
- `literature-audit.sh --pdf` fails loudly instead of appending an empty or flag-shaped path when
  its operand is missing.
- `/literature --validate`'s required-schema-field check evaluates only top-level document
  entries, using `literature-coverage-delta.sh`'s existing `parent_doc` predicate.
- Step 2 prose and the Step 4 "Schema Warnings" report section describe what the corrected check
  actually enforces, closing the pre-existing 7-fields-documented/4-fields-checked gap.
- All edits land in `agent-system/extensions/literature/`, never in `.claude/`.

**Non-Goals**:
- Fixing corpus **data** defects. The ~137 genuine entry-level problems (75 missing `keywords`,
  62 missing `summary`, 2 comma-joined single-author strings) are explicitly out of scope. This
  task changes the CHECK, not the DATA — a correct fix makes those real defects *more* visible by
  removing ~11k entries of noise around them.
- Restructuring SKILL.md, changing the Step 4 report format, or altering the authors-shape check.
- Redeploying `.claude/` or reconciling the resulting source/deploy delta (normal and expected
  until the next regeneration).
- Adding a test harness — the literature extension has no `tests/` directory today, and creating
  one is out of proportion to two localized fixes.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A parallel not-started task restructures SKILL.md into mode-gated sections, invalidating the recorded line numbers | M | M | Re-locate by anchor text, not line number: `"Required schema fields present"` for the prose, `missing_fields=$(echo "$entry_json"` for the jq block, `### Schema Warnings` for the report section. Phase 2 Step 1 does this location pass before any edit. |
| Hardening `--pdf` operand consumption changes behavior for an existing caller | L | L | Phase 1 enumerates in-repo callers first (research grep found none that invoke the script); the change converts a silent-wrong-result into a loud exit-64, which is the intended direction. Land the usage/unknown-arg fix and the `--pdf` guard as separate hunks so the guard can be dropped independently if a caller surfaces. |
| Scoping the check to top-level entries hides a genuine section-level defect | L | L | Section entries remain covered by the existing checks that run for every entry regardless of level: the schema-shape bucket (`id`/`path`) and the existence/token-count checks. Phase 2 makes this explicit in prose rather than relying on it implicitly. |
| The `parent_doc` predicate misclassifies entries if the real index uses a different absent-value convention | M | L | Phase 2 verifies empirically against the real `specs/literature-index.json` before and after, and reports actual counts — not just a code read. |
| Hand-editing `.claude/` copies instead of the source store | H | L | Both phases name the source-store path explicitly; the advisory `validate-meta-write.sh` hook also fires on `.claude/**` writes. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel. The two defects are fully independent — they
touch different files with no shared state — so Phase 2 must not be blocked on Phase 1.

---

### Phase 1: Add usage and argument validation to literature-audit.sh [NOT STARTED]

**Goal**: `literature-audit.sh` prints usage and exits 0 on `-h`/`--help`, rejects unrecognized
arguments with a stderr message and exit 64, and refuses a `--pdf` with a missing or flag-shaped
operand — all matching the convention `literature-ingest-online.sh` already establishes.

**Tasks**:
- [ ] Confirm the current arg loop in `agent-system/extensions/literature/scripts/literature-audit.sh`
      still matches the research's transcription (locate by anchor: `while [[ $# -gt 0 ]]; do` inside
      `main()`), and confirm no `usage()`/`show_usage()` already exists (`grep -n 'usage'`).
- [ ] Enumerate in-repo invocations of the script (`grep -rn 'literature-audit' agent-system/ .claude/`)
      and record the result in the implementation summary — this is the evidence backing the
      Scope Hypothesis below and the `--pdf` risk mitigation.
- [ ] Add a `usage()` function mirroring `literature-ingest-online.sh:153-163`: a
      `cat >&2 << 'USAGE' ... USAGE` heredoc whose body reproduces the three invocation forms
      already documented in the script header (lines 9-11), verbatim, so header and usage cannot
      drift. Include `-h, --help` in the listed forms.
- [ ] Add a `-h|--help) usage; exit 0 ;;` arm to the `case` in `main()`, placed before the
      catch-all.
- [ ] Replace the catch-all `*) shift ;;` with:
      `*) echo "literature-audit.sh: unknown argument: $1" >&2; usage; exit 64 ;;`
      — matching `literature-ingest-online.sh`'s message shape (`scriptname: unknown argument: $1`)
      and the codebase-wide exit-64 usage-error convention.
- [ ] Harden the `--pdf` arm as a separate hunk: reject a missing operand (nothing follows) or an
      operand beginning with `-`, with a stderr message plus `exit 64` in the same style. Keep the
      existing `*.pdf|*.djvu)` positional arm working unchanged.
- [ ] Do NOT touch `.claude/scripts/literature-audit.sh`.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (a) the script has no existing `usage()`/`show_usage()`
function, and (b) no in-repo caller invokes `literature-audit.sh` programmatically, so the `--pdf`
hardening breaks nothing. Confirm both at implementation time with
`grep -n 'usage' agent-system/extensions/literature/scripts/literature-audit.sh` and
`grep -rn 'literature-audit' agent-system/ .claude/` before editing; if a programmatic caller
does exist, land the usage/unknown-arg hunk and report the `--pdf` hunk as deferred rather than
silently changing that caller's behavior.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-audit.sh` - add `usage()`; add
  `-h|--help` arm; convert catch-all to unknown-arg error + exit 64; guard `--pdf` operand.

**Verification**:
- `bash -n agent-system/extensions/literature/scripts/literature-audit.sh` parses clean.
- `shellcheck` on the file reports no new findings relative to before the edit (if available;
  note its absence otherwise rather than skipping silently).
- `bash agent-system/extensions/literature/scripts/literature-audit.sh --help` prints usage to
  stderr and exits 0 — critically, with **no PDF conversion and no `/tmp` output**, which is the
  observed defect. Confirm exit status explicitly (`echo $?`).
- `bash .../literature-audit.sh --bogus` prints `literature-audit.sh: unknown argument: --bogus`
  to stderr plus usage, and exits 64.
- `bash .../literature-audit.sh --pdf` (trailing, no operand) exits 64 with a message rather than
  appending an empty path.
- The usage heredoc text agrees line-for-line with the script header's documented invocation
  forms (lines 9-11).
- Enumerated dependent set (from the grep above) is unaffected: no in-repo caller passes an
  argument the new validation would now reject.

---

### Phase 2: Scope /literature --validate schema check to top-level document entries [NOT STARTED]

**Goal**: The `missing_fields` check in `/literature --validate` Step 2 evaluates only top-level
document entries (via the existing `parent_doc` predicate), section entries are held only to the
checks that already apply to them, and the Step 2 prose plus the Step 4 report heading describe
the corrected behavior accurately.

**Tasks**:
- [ ] **Location pass first**: re-locate the three edit sites in
      `agent-system/extensions/literature/skills/skill-literature/SKILL.md` by anchor text, not
      line number — `Required schema fields present` (Step 2 prose, ~line 380),
      `missing_fields=$(echo "$entry_json"` (jq block, ~lines 457-464), and
      `### Schema Warnings` (Step 4 report, ~line 653). If the parallel SKILL.md restructure has
      landed, use the anchors and record the new locations in the summary.
- [ ] Capture the **before** measurement against the real index so the fix is empirically
      demonstrated, not asserted: count entries total, entries lacking `doc_type`, entries lacking
      `authors`, and how many of each are top-level (`parent_doc` null/empty) vs. section entries.
- [ ] Gate the `missing_fields` jq block on the canonical top-level predicate, reusing
      `literature-coverage-delta.sh:212`'s form verbatim — `.parent_doc == null or .parent_doc == ""`
      — reading from the already-parsed `$entry_json` (no new file read, no second index query).
      Section entries produce no `missing_fields` output and never populate `schema_warnings[]`.
- [ ] Update the Step 2 prose (point 3) to state that the required-field list applies to
      **top-level document entries only**, and to name the fields the check *actually* enforces
      (`doc_type`, `source_format`, `authors`, `title`) rather than the 7 it currently lists —
      closing the pre-existing prose/implementation mismatch the research surfaced.
- [ ] In the same prose edit, state explicitly which checks section entries remain subject to:
      existence, the schema-shape bucket (`id`/`path`), and token-count drift. Do not imply a
      separate 3-field section-entry check exists — no such code path does, and none is being
      added.
- [ ] Leave the book/parent `doc_type: "book"` note (SKILL.md:426-427) unchanged; the research
      confirmed that record is top-level and already covered by the new scoping.
- [ ] Confirm the Step 4 `### Schema Warnings ({count}) — entries missing required v2 fields`
      heading remains accurate under the new scoping; adjust its wording only if it now overstates
      scope, and keep the per-entry line format unchanged.
- [ ] Do NOT touch `.claude/skills/skill-literature/SKILL.md`.
- [ ] Do NOT modify any index data (`specs/literature-index.json` or the global index) — the ~137
      genuine data defects stay untouched by design.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (a) ~11,078 of 11,545 entries lack `doc_type` and 11,043
lack `authors`, essentially all of them section-level; (b) ~137 genuine document-level defects
remain after scoping (75 `keywords`, 62 `summary`, 2 comma-joined authors — the first two of which
this check does not evaluate at all); and (c) the `parent_doc` predicate correctly separates the
two populations. Confirm at implementation time by running the before/after jq counts against the
real `specs/literature-index.json` and reporting **actual** numbers in the summary. Treat a
material divergence from these figures — especially a top-level population that is still in the
thousands — as a signal that the predicate is wrong for this index, and stop to re-derive it
rather than proceeding on the assumed numbers.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - gate the `missing_fields`
  jq block on the `parent_doc` top-level predicate; correct Step 2 point 3 prose (scope + actual
  field list); state section-entry coverage explicitly; keep Step 4 heading coherent.

**Verification**:
- The edited jq expression is syntactically valid in isolation: pipe a representative top-level
  entry and a representative section entry through it and confirm the section entry yields empty
  output while a genuinely deficient top-level entry still yields its field list.
- **Before/after counts on the real index**: the number of entries that would populate
  `schema_warnings[]` drops from ~11k to the low hundreds or fewer, and every remaining entry is
  verifiably top-level (`parent_doc` null/empty). Report the exact before and after numbers.
- Spot-check that a known `doc_type: "book"` parent record (directory path, `token_count: 0`) does
  NOT appear in the post-fix warnings — it is top-level and carries `doc_type` by construction.
- Spot-check that at least one known genuine document-level defect is still reported (the fix must
  not suppress real findings).
- The Step 2 prose field list matches the jq block's field list exactly — no field named in prose
  goes unchecked, and no checked field goes unnamed.
- `specs/literature-index.json` is unmodified (`git status --short` shows no index data change).

---

## Testing & Validation

- [ ] `bash -n` clean on `literature-audit.sh`; `shellcheck` shows no new findings (or its absence
      is noted explicitly).
- [ ] `literature-audit.sh --help` -> usage on stderr, exit 0, zero side effects (no conversion,
      nothing written to `/tmp`).
- [ ] `literature-audit.sh --bogus` -> stderr message + usage, exit 64.
- [ ] `literature-audit.sh --pdf` with no operand -> stderr message, exit 64.
- [ ] The three documented invocation forms (`--pdf <path>`, `--xref`, `--all`) and bare
      `*.pdf`/`*.djvu` positionals still parse and dispatch to the same modes as before.
- [ ] `--validate` schema-warning population drops from ~11k to top-level-only, with before/after
      counts recorded from the real index.
- [ ] Every post-fix schema warning is a top-level entry; the book/parent record is absent from
      the list; at least one genuine defect is still surfaced.
- [ ] Step 2 prose and the Step 4 report heading describe the enforced behavior, with the
      documented field list matching the checked field list.
- [ ] `git status --short` shows changes confined to
      `agent-system/extensions/literature/scripts/literature-audit.sh` and
      `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (plus `specs/**`
      artifacts) — no `.claude/**` edits, no index data edits.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-audit.sh` (modified) — `usage()`,
  `-h|--help` arm, unknown-arg exit-64 catch-all, `--pdf` operand guard.
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (modified) — top-level-scoped
  `missing_fields` check, corrected Step 2 prose, coherent Step 4 report section.
- `specs/111_fix_audit_arg_validation_and_validate_schema_scoping/summaries/01_{short-slug}-summary.md`
  — implementation summary, including the before/after schema-warning counts and the caller
  enumeration result.

## Rollback/Contingency

Both phases are single-file, additive-to-small edits with no data migration and no state change.
Reverting is `git revert` of the phase commit, or `git checkout HEAD -- <file>` for a single file
before commit. Because the phases are independent, either can be reverted without affecting the
other.

Contingency by phase:
- **Phase 1**: if the `--pdf` guard turns out to break a caller discovered during the enumeration
  step, drop that hunk and keep the usage/`-h`/unknown-arg hunk — they are deliberately separate
  commits for exactly this reason.
- **Phase 2**: if the before/after counts show the `parent_doc` predicate does not cleanly separate
  the two populations on this index, do not force the edit. Revert the jq change, keep or revert
  the prose change independently, and report the measured distribution so the predicate can be
  re-derived — a wrong predicate would silently suppress genuine defects, which is worse than the
  current noise.
