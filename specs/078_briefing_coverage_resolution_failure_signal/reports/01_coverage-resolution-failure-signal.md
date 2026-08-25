# Research Report: Task #78

- **Task**: 78 - briefing_coverage_resolution_failure_signal
- **Started**: 2026-08-24T00:00:00Z
- **Completed**: 2026-08-24T00:00:00Z
- **Effort**: ~4-6 hours (single script + two doc files + one test section)
- **Dependencies**: schema-unification task (already completed — see Prior Work below)
- **Sources/Inputs**: Codebase (agent-system/extensions/literature/**), completed-task summaries
  under specs/077, specs/070, specs/vault/01-vault/archive/800
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely located: `literature-briefing.sh`'s per-repo mode loop
  (`agent-system/extensions/literature/scripts/literature-briefing.sh:175-292`) skips an
  unresolvable `doc_id` via a bare `continue` at line 193 with **no counter update anywhere** —
  `coverage_count` (line 301, `= ${#briefing_lines[@]}`) only ever reflects successes.
- A second, more severe instance of the same defect already exists at
  `literature-briefing.sh:295-297`: when **every** requested `doc_id` is skipped,
  `briefing_lines` is empty and the script does a bare `exit 0` — no marker, no banner, no output
  at all. This is currently indistinguishable from a genuinely empty/absent sub-index and must be
  folded into the fix, not left as an untouched edge case.
- Recommended design: reuse the existing `sparse` boolean/marker/banner machinery rather than
  inventing a second, unconsumed signal. A skip-rate threshold that also sets `sparse=true`
  automatically engages both existing consumers (`lit-stage4a-flow.md`'s two-checkpoint re-prompt
  and `adhoc-navigation-directive.md`'s mirror of it) with **zero changes to either file** — this
  is the same "which downstream code actually reads this flag" checkpoint the
  `[DEGRADED RETRIEVAL ...]` banner precedent already established.
- `literature-lit-flag-resolve.sh` (Checkpoint 1, pre-generation) is explicitly **out of scope**
  by its own header comment ("do not re-implement its full doc_id/GLOBAL_INDEX cross-reference
  here (Risk 4: counting duplication)") — all work belongs in `literature-briefing.sh`
  (Checkpoint 2), consistent with the task's SOURCE-STORE-scoped file list.
- Global mode (`--global`) has no analogous "requested doc_id" concept — its segments arrive
  pre-resolved from `literature-search.sh`. The marker schema should stay uniform across modes
  (add `requested=`/`skipped=`/`skip_rate=` fields) but global mode's values are trivially
  `skipped=0`.
- A ready-made fixture/test pattern to extend exists: `test-lit-pipeline.sh`'s Section F (lines
  ~490-700+) already carries a header comment explicitly earmarking "a companion coverage-marker
  regression" as the deferred item this task now closes — a new Section G following the exact
  same fixture idiom (hand-built `index.json` + real-schema `.literature.db` via
  `literature-schema.sql`) is the natural home for the AC5 regression test.

## Context & Scope

Researched the current state of `agent-system/extensions/literature/scripts/literature-briefing.sh`
and `literature-briefing-invoke.sh`, the two Stage 4a consumers of the `lit-coverage` marker
(`agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` and
`agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md`),
the sparse-coverage domain doc, `literature-lit-flag-resolve.sh` (Checkpoint 1), and the three
named prior-work artifacts (schema-unification task 77, tier-starvation fix task 70, and the
vaulted `lit_briefing_failure_surfacing` task) to confirm design precedent and current line
numbers (the task description warned these drift).

## Findings

### Codebase Patterns

**`literature-briefing.sh` repo-mode loop** (lines 141-301):
- `doc_ids` populated from the sub-index at line 167.
- Loop body (175-292) resolves each `doc_id` against `$GLOBAL_INDEX` via two jq lookups (with,
  then without, the `parent_doc` filter — post-schema-unification tolerant lookup).
- **The only skip site**: lines 191-194 —
  ```bash
  if [ -z "$parent_entry" ]; then
    echo "Warning: doc_id '$doc_id' not found in global index — skipping" >&2
    continue
  fi
  ```
  No counter, no array append, before the `continue`. This is the single generic failure point —
  any *future* resolution-failure cause funnels through this one `continue` today, so instrumenting
  here (rather than trying to enumerate causes) satisfies the task's "must fire for any future
  resolution failure from any cause" requirement.
- Success path appends one entry to `briefing_lines` per resolved `doc_id` (line 291), so for
  repo mode `resolved_count == ${#briefing_lines[@]}` always holds — a useful invariant for the
  regression test's assertions.
- **Second silent-exit site** (lines 294-297):
  ```bash
  if [ "${#briefing_lines[@]}" -eq 0 ]; then
    exit 0
  fi
  ```
  comment: "regression-preserved". This fires whenever *every* requested `doc_id` skips — the
  full-failure variant of the exact defect this task targets. It must be changed to fall through
  to the shared marker/banner block (with `resolved=0`, `skipped=N`) instead of exiting silently,
  or the regression test's simplest fixture shape (a sub-index with a single unresolvable
  `doc_id`) would produce **zero stdout and no marker at all** — nothing to assert against.
- `coverage_mode`/`coverage_count` set at lines 299-301 (repo) and 379-380 (global) — the single
  shared exit point (404-476) is where the `sparse` boolean and `<!-- lit-coverage ... -->`
  marker are computed (420-424) and where the `[SPARSE COVERAGE ...]` banner is emitted
  (427-430). This shared block is mode-agnostic; new fields belong here so both modes share one
  formatting site.

**Marker consumers** (must keep matching):
- `lit-stage4a-flow.md:203`: `grep -q 'lit-coverage mode=global .*sparse=true'` — requires
  `mode=global` immediately after `lit-coverage `, then `sparse=true` appearing later on the
  line; `.*` tolerates anything inserted between or after, as long as field *names* `mode=` and
  `sparse=` and their relative order are preserved.
- `adhoc-navigation-directive.md:45-46` restates the same marker/grep contract in prose, citing
  `lit-stage4a-flow.md` as the source of truth — no independent grep of its own to break.
- Both consumers only ever check `mode=global ... sparse=true` (the two-checkpoint re-prompt is
  scoped to the *global-search* result of "Use global corpus now"). The **repo-mode** case (where
  this task's real-world evidence occurred) is not currently re-prompted by either consumer at
  all — `SUBINDEX_PRESENT` and the interactive/autonomous `SPARSE_PROMPT_NEEDED` branches only
  ever call `literature-briefing-invoke.sh` with no arguments and assign the result directly to
  `lit_context`, with no marker inspection afterward. This is an important scoping fact: **making
  `sparse=true` fire correctly on high repo-mode skip rate changes what the marker *says*, but
  today nothing downstream re-prompts on a sparse *repo-mode* marker** — only the global-mode
  marker is actively polled. The fix is still fully justified per the acceptance criteria (the
  marker must stop lying, and skipped doc_ids must be visible in the body for the *consuming
  agent*, independent of whether Stage 4a itself re-prompts), but a plan should not claim this
  change alone causes an automatic sparse-triggered re-prompt for repo-mode runs — that would
  need a follow-up edit to `lit-stage4a-flow.md`'s `SUBINDEX_PRESENT`/`SPARSE_PROMPT_NEEDED`
  branches, which is arguably beyond this task's declared scope (extend the marker + body
  surfacing + document policy) unless the user wants that wired in too.

**`literature-lit-flag-resolve.sh`** (Checkpoint 1, pre-generation, lines 118-131): counts
`.entries | length` only — deliberately does **not** cross-reference against `$GLOBAL_INDEX`
("Risk 4: counting duplication" per its own header comment at lines 43-50). This confirms
Checkpoint 1 is intentionally cheap/approximate and Checkpoint 2 (`literature-briefing.sh`'s own
marker, post-generation) is the sole authoritative place a real doc_id-to-global-index resolution
failure can be detected — matching the task's SOURCE-STORE file list, which only names
`literature-briefing.sh`.

**Global mode** (lines 303-402): segments arrive pre-resolved from `literature-search.sh`'s
JSON envelope (`chunk_id`/`doc_id`/`section_path`/`title`/`summary`/`token_count`/
`provenance_fidelity` all present on each result object) — there is no per-item external lookup
that can fail the way repo mode's `jq` cross-reference can. No analogous skip site exists or is
needed in global mode; `requested_count == coverage_count` and `skipped_count == 0` there,
always.

**Test scaffold** (`test-lit-pipeline.sh` Section F, lines ~487-700+): a header comment
immediately above `section_f()` (lines 490-495) explicitly says:
```
# NOTE: a companion coverage-marker regression (asserting a deliberately-unresolvable doc_id
# drives the lit-coverage marker to report the failure rather than falsely reporting
# sparse=false) is a distinct, separately-tracked defect and is intentionally out of scope for
# this section.
```
This is a direct, named pointer at this task. Section F's fixture idiom (hand-authored
`index.json` with several deliberately-shaped "cases," a `.literature.db` built from the real
`literature-schema.sql` rather than a hand-rolled `CREATE TABLE`, `log_pass`/`log_fail` per
assertion, cleanup via `TEMP_LIT_DIR_F`/the existing `cleanup()` trap) is the template a new
Section G should follow — add one more case whose `doc_id` is registered in the sub-index but has
**no matching entry** in `index.json` at all (the simplest way to force the skip path), alongside
at least one resolvable sibling entry so the test also exercises the *partial*-failure shape the
task's evidence describes (not just full failure).

### External Resources

Not applicable — this is entirely internal bash/jq tooling with no external API or library
surface; no web research was needed or performed.

### Recommendations

1. **Add `skipped_doc_ids=()` and `skip_count=0`** initialized alongside `doc_num=0` (~line 173),
   append/increment at the line-191-194 skip site (both counter and array — the array is what
   AC2's body-surfacing needs).
2. **Change the line-294-297 early exit** from `exit 0` to falling through into the shared
   marker/banner block when `${#briefing_lines[@]} -eq 0` **and** `skip_count > 0` (i.e. this was
   a resolution failure, not a structurally empty/absent sub-index — the `entry_count -eq 0` and
   missing-file guards at lines 150-164 remain untouched and still exit silently, since those are
   the legitimately-empty cases already messaged upstream by `literature-lit-flag-resolve.sh`'s
   directives).
3. **Extend the marker** (line 424) with `requested=` `skipped=` `skip_rate=` fields, inserted
   *after* the existing `threshold=T` (safest position — leaves `mode=`, `seg_count=`, `sparse=`
   byte-for-byte adjacent and in their original relative order, so both consumers' `.*`-tolerant
   greps are unaffected regardless of insertion point, but appending after all existing fields is
   the lowest-risk choice and easiest to eyeball-diff against the "must keep working" fields).
   Compute `skip_rate` as an integer percentage via pure bash arithmetic (`skip_count * 100 /
   requested_count`), matching the codebase's existing style of avoiding `awk`/`bc` for
   arithmetic already expressible in bash `(( ))`.
4. **Fold the skip-rate signal into the existing `sparse` boolean** rather than adding a second,
   uninspected flag: introduce `LITERATURE_SKIP_RATE_THRESHOLD` (env var, suggest default `50`
   meaning 50%, matching `LITERATURE_SPARSE_THRESHOLD`'s existing env-var-with-default idiom at
   line 68) and set `sparse=true` when **either** `coverage_count < LITERATURE_SPARSE_THRESHOLD`
   (existing rule, unchanged) **or** `skip_count * 100 >= requested_count *
   LITERATURE_SKIP_RATE_THRESHOLD` (new rule). This is the direct answer to the task's open
   question in scope item 4 ("should that force sparse=true or a distinct signal?") — reusing
   `sparse` means the two existing global-mode consumers respond correctly with **zero edits** to
   either flow file, satisfying AC3 by construction rather than by leaving the new signal
   unconsumed. A wholly separate flag that nothing greps for would repeat exactly the
   silent-signal failure mode this task exists to close.
5. **Emit a new banner in the same family** as `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]` /
   `[SPARSE COVERAGE ...]`, e.g. `[SKIPPED SOURCES - N of M requested document(s) could not be
   resolved (Y%); see "Unresolved Documents" below]`, placed immediately after the existing
   `[SPARSE COVERAGE ...]` banner block (~430) so it appears whenever `skip_count > 0`,
   independent of whether the skip rate alone crossed the sparse threshold (a low but nonzero
   skip rate is still worth surfacing per AC1 even when it doesn't flip `sparse`).
6. **Surface skipped doc_ids in the body** (AC2): a short `## Unresolved Documents` section
   listing each `doc_id` from `skipped_doc_ids[]`, placed right after the new banner (item 5),
   before the per-document entries — so it reads immediately after the coverage signals and
   before the (possibly gutted) document list, giving the consuming agent both "how bad" and
   "specifically what" in one place. Reasonable to keep this repo-mode-only (global mode's array
   is always empty, so the section is naturally omitted there via the same `${#skipped_doc_ids[@]}
   -gt 0` guard used for the other conditional sections).
7. **Update `sparse-coverage.md`** (AC4) with a new bullet documenting
   `LITERATURE_SKIP_RATE_THRESHOLD`, the "folded into `sparse`, not a separate signal" decision
   and its rationale (consumer reuse), and the marker's three new fields — mirroring the existing
   `LITERATURE_SPARSE_THRESHOLD` bullet's structure exactly. Also update
   `index-entries.json`'s `project/literature/domain/sparse-coverage.md` entry (line ~247-273):
   its `keywords` array should gain `LITERATURE_SKIP_RATE_THRESHOLD`/`skip_rate` and its
   `line_count` (currently `33`) must be resynced to the file's new length, matching this
   extension's existing index-entry maintenance convention (already resynced for other files by
   task 77's own diff).
8. **New Section G in `test-lit-pipeline.sh`** (AC5): reuse Section F's fixture idiom exactly —
   a sub-index with (a) one resolvable `doc_id` matching a real `index.json`/`.literature.db`
   entry and (b) one `doc_id` present in the sub-index but absent from `index.json`. Assert: the
   emitted `<!-- lit-coverage ... -->` marker's `skipped=` field is `1` (not `0`), `sparse=true`
   (via the skip-rate rule, using a small requested-count fixture — e.g. 2 requested, 1 skipped =
   50% — so it exercises the *new* rule rather than accidentally tripping the old absolute-count
   rule), and the body contains the skipped `doc_id` under an "Unresolved Documents" heading. Also
   add one assertion exercising the full-failure case (item 2 above): a sub-index whose sole entry
   is unresolvable must still emit a marker (not empty stdout), with `resolved`/`seg_count=0` and
   `skipped=1`.

## Decisions

- **Scope is entirely within `literature-briefing.sh`** (plus the two documentation files named
  in the task and `test-lit-pipeline.sh`); `literature-lit-flag-resolve.sh` is confirmed
  out-of-scope by its own explicit "do not duplicate the cross-reference" design note, and no
  finding in this research contradicts that.
- **Reuse `sparse`/the marker/banner family rather than invent a new unconsumed flag.** This is
  the single highest-leverage design decision in this report — it is what makes AC1 and AC3
  simultaneously satisfiable without editing `lit-stage4a-flow.md` or
  `adhoc-navigation-directive.md` at all.
- **The line-294-297 silent full-failure exit must be fixed as part of this task**, not treated
  as a pre-existing separate defect, because AC5's simplest regression fixture (a single
  deliberately-unresolvable `doc_id`) cannot be asserted against otherwise — the script would
  produce empty stdout with no marker, and "sparse=false" vs. "no marker at all" are both failures
  of the same non-silence invariant.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Marker field insertion breaks the two greps | Append new fields strictly after `threshold=T`, leave `mode=`/`seg_count=`/`sparse=` untouched and in original order; verify both greps against a sample marker string before/after in the plan's own verification phase |
| Folding skip-rate into `sparse` changes existing global-mode behavior for corpora that were previously reported `sparse=false` | Only true when `skip_count > 0`, which never occurs in global mode (no skip site exists there) — the new rule is structurally a no-op for `mode=global`, so no existing global-mode marker output changes |
| Threshold value (`LITERATURE_SKIP_RATE_THRESHOLD` default) picked without real-world calibration data | Document the choice and rationale explicitly in `sparse-coverage.md` (AC4 requires this anyway); default should be conservative enough not to flag normal partial-curation sub-indices (e.g. 1-of-4 legitimately superseded entries) — a $\geq 50\%$ default is a reasonable, clearly-stated starting point, not a precision-tuned value |
| Full-failure-exit fix (line 294-297) regresses the pre-existing "genuinely empty sub-index" silent-exit contract | Gate the fallthrough strictly on `skip_count > 0` (i.e., "we had requests and all failed") vs. the untouched `entry_count -eq 0` / missing-file / `doc_ids` empty guards earlier in the function, which remain silent exits unconditionally |

## Context Extension Recommendations

- **Topic**: skip-rate/failure-signal fields on the `lit-coverage` marker.
- **Gap**: `sparse-coverage.md` currently documents only the absolute-count threshold; once this
  task lands, the marker's schema and the "why folded into `sparse`" decision need a durable home
  there (AC4 already requires this update, so no separate follow-up task is needed — just ensure
  the implementer treats it as required, not optional documentation).

## Appendix

### Files inspected

- `agent-system/extensions/literature/scripts/literature-briefing.sh` (476 lines, full read)
- `agent-system/extensions/literature/scripts/literature-briefing-invoke.sh` (41 lines, full read)
- `agent-system/extensions/literature/scripts/literature-lit-flag-resolve.sh` (relevant sections)
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md` (full read)
- `agent-system/extensions/literature/context/project/literature/patterns/adhoc-navigation-directive.md` (full read)
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` (full read)
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` (Section F, ~lines 487-700+)
- `agent-system/extensions/literature/index-entries.json` (sparse-coverage.md entry)
- `specs/077_unify_literature_global_index_schema/summaries/01_unify-global-index-fts-namespace-summary.md`
  (predecessor task; confirms it is `[COMPLETED]` and explicitly defers this exact defect in its
  own Follow-ups section)
- `specs/070_fix_discover_tier_starvation_and_silent_tier3_failure/summaries/01_fix-discover-tier-starvation-summary.md`
  (general precedent: never let a degraded result self-report as healthy)
- `specs/vault/01-vault/archive/800_lit_briefing_failure_surfacing/plans/01_lit-briefing-failure-surfacing.md`
  (design precedent for the wrapper/failure-surfacing posture this task extends)

### Search queries / commands used

- `find agent-system/extensions/literature -iname "*briefing*"`
- `find agent-system/extensions -iname "*sparse-coverage*" -o -iname "*lit-stage4a-flow*" -o -iname "*adhoc-navigation-directive*"`
- `grep -n "Section F" -A 40 test-lit-pipeline.sh`
- `grep -rn "LITERATURE_SPARSE_THRESHOLD" agent-system/extensions/literature/ agent-system/extensions/core/`
- `grep -rln "schema.unification\|stub-entry\|lit_briefing_failure_surfacing\|tier-starvation\|silent-tier3" specs --include="*.md" -i`
