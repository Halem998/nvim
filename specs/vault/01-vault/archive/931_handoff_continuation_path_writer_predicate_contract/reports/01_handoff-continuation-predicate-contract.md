# Research Report: Task #931

**Task**: 931 - handoff_continuation_path_writer_predicate_contract
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: research
**Dependencies**: None (adjacent sibling tasks cover the outer dispatch-context `handoff_path`
anchor, the missing-handoff-after-research case, and a fixture that reproduces the predicate as
currently-intended with `handoff_path` populated — none overlap this task's scope)
**Sources/Inputs**: Codebase read (agent-system/extensions/core and cslib/lean counterparts),
recent git history
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- The predicate mismatch is real, but it is **not** "writers emit `handoff_path: null` inside a
  populated `continuation_context`." The actual current defect is a **field-name/shape schism**:
  the sole active `.orchestrator-handoff.json` writer (the hard-mode H9 wrap-up, per
  `docs/architecture/handoff-schema.md`'s own "Handoff Writers" table) emits a **flat top-level
  `continuation_path` string**, while `orchestrate-triage-classify.sh` (and base
  `skill-orchestrate/SKILL.md`'s hand-applied mirror of the same rule) checks only a **nested
  `continuation_context.handoff_path`** — a key the active writer never emits at all.
- `validate-handoff.sh` already treats `continuation_path` and `continuation_context` as two
  equally acceptable forms ("Optional fields... continuation_path or continuation_context — one
  of these two forms is acceptable"). This is a precedent already living in the codebase for
  exactly the relaxation Option B proposes — it just isn't honored by the classifier.
- `skill-orchestrate-hard/SKILL.md`'s own inline partial-state handler reads `.continuation_path`
  (matching the actual writer), so hard-mode-to-hard-mode round trips are self-consistent. The
  break is specifically in the **base engine / shared classifier's** predicate, which was written
  against the nested schema documented in `handoff-schema.md` and `skill-base.sh`'s
  `skill_write_orchestrator_handoff` (a function `handoff-schema.md`'s own table marks
  "Defined, unreferenced — No caller currently invokes it").
- A third, narrower defect: `cslib-implementation-hard-agent.md`'s Stage 5 template hardcodes
  `"continuation_context": null` with **no instruction anywhere in the file** for populating it
  (unlike core/lean's explicit "on partial: populate `continuation_path`" instructions) — cslib
  hard-mode partial handoffs currently never populate any continuation pointer at all.
- Recommendation: **Option B**, scoped precisely — relax `orchestrate-triage-classify.sh` and
  the identical hand-applied rule in `skill-orchestrate/SKILL.md` Stage 4 to accept **either**
  `continuation_path` (top-level, non-null) **or** `continuation_context.handoff_path` (nested,
  non-null), mirroring `validate-handoff.sh`'s already-established dual-acceptance convention.
  Rewrite `handoff-schema.md` to document both forms and correct the "single active writer"
  narrative to say what it actually emits. Fix cslib's Stage 5 template as a related but
  separable follow-up (flag it; do not silently fold it into this task's implementation).

## Context & Scope

Researched, against current on-disk state (all three implicated files — `skill-orchestrate/
SKILL.md`, `skill-orchestrate-hard/SKILL.md`, and `handoff-schema.md` — were confirmed modified
within the last several commits by an unrelated, now-completed sibling task adding
`dispatch_status` three-tier validation, per `git log`):

1. The literal predicate in `orchestrate-triage-classify.sh`.
2. The literal writer code/instructions in `skill-base.sh` and the H9 wrap-up contract
   (`context/contracts/wrap-up.md`) plus its three agent-level instantiations (core, cslib, lean).
3. What `docs/architecture/handoff-schema.md` currently documents.
4. Every writer of any continuation-pointer field in `.orchestrator-handoff.json`, and what each
   actually emits.
5. Every consumer of that field, and what would change/break under Option B.
6. How a regression test for this should be shaped against the now-established
   `agent-system/extensions/core/scripts/tests/` harness convention.

## Findings

### 1. The classifier's actual predicate (`orchestrate-triage-classify.sh`)

```bash
# lines 200-204
blocker_count=$(jq -r '(.blockers // []) | length' "$handoff_path" 2>/dev/null)
case "$blocker_count" in ''|*[!0-9]*) blocker_count=0 ;; esac

continuation_ok=$(jq -r '(.continuation_context // null) as $c | if ($c != null and ($c.handoff_path // null) != null) then "true" else "false" end' "$handoff_path" 2>/dev/null)
[ "$continuation_ok" = "true" ] || continuation_ok="false"
```

This checks **only** `.continuation_context.handoff_path`. It never inspects a top-level
`.continuation_path` field. The script's own header (lines 41-45) transcribes the rule it
implements:

```
# Precedence for `partial` status (transcribed from the single-task Stage 4 handler's explicit
# reads, which both engines share):
#   1. continuation_context is non-null AND carries a handoff_path -> route toward `implement`
#   2. else blockers is non-empty                                  -> `needs_human`
#   3. else (neither)                                               -> `implement` (both engines)
```

When `continuation_ok=false` and `blocker_count=0` (the exact shape of a hard-mode partial
handoff — see below), the verdict logic (lines 266-269) emits:

```
{"group":"implement", "handoff_state": (if $hstate == "absent" then "absent" else "empty" end), ...}
```

**Important correction to the task's framing**: `handoff_state: "empty"` currently routes to
`group: "implement"` for both engines — **not** `"exit_partial"` (that value is explicitly
documented at lines 88-94 as "RESERVED — defined but not currently emitted by any row as of this
schema version"). The script's own header narrates that a prior single-engine divergence on this
exact row ("partial-with-neither") was **already converged to `implement` for both engines** by
a just-completed sibling task. So the task is **no longer stranded outright** (it will still get
re-dispatched to implement) — but it is dispatched via the "no handoff, no blockers" branch of
`skill-orchestrate/SKILL.md` Stage 4 (lines 423-482), which probes `.return-meta.json` via
`orchestrate-recover-outcome.sh` instead of passing the handoff's own `continuation_context`
object into the next dispatch. This is exactly item (c) in the task's RESIDUE list, and it is
confirmed still live on disk: the classifier still cannot see the real continuation pointer, so
the richer resume context (note/hint/exact phase count from the handoff itself, as opposed to
`.return-meta.json`'s coarser fields) never reaches the successor dispatch.

### 2. What the writers actually emit

**`skill-base.sh`'s `skill_write_orchestrator_handoff`** (lines 588-669) — confirmed via
`docs/architecture/handoff-schema.md`'s own "Handoff Writers" table (line 267) and a full-tree
grep: **defined, but zero callers**. If it were called, it would write the nested nested nested
form (from an env var no writer currently sets):

```bash
# line 628
local continuation_json="${ORCHESTRATOR_HANDOFF_CONTINUATION_JSON:-null}"
...
# lines 651-665
--argjson continuation "$continuation_json" \
'{ ... "continuation_context": $continuation }' > "$handoff_path"
```

This is the ONLY code path anywhere in the tree that would ever produce a nested
`continuation_context: {handoff_path: ..., orchestrator_mode: ...}` object matching what
`docs/architecture/handoff-schema.md` documents and what the classifier checks — and it is dead
code.

**`context/contracts/wrap-up.md`** (the canonical H9 contract, `--hard`-only, loaded by
`skill-implementer-hard`, `general-implementation-hard-agent`, `skill-orchestrate-hard`) documents
a **flat, top-level `continuation_path` string**, not a nested object:

```json
{
  "status": "implemented | partial | blocked",
  "skeleton": false,
  "phases_completed": 2,
  "phases_total": 5,
  "sorry_inventory": [],
  "blockers": [ ... ],
  "continuation_path": "specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TS}.md"
}
```
> "`continuation_path`: Path to the handoff markdown artifact if `status != "implemented"`. Null
> when status is "implemented"."

There is no `continuation_context` key in this schema at all.

**`general-implementation-hard-agent.md` Stage 5** (lines 288-317, the CORE agent, and per
`handoff-schema.md`'s own table "the only active writer of `.orchestrator-handoff.json` today")
matches `wrap-up.md` exactly — flat `"continuation_path": null` (populated on partial/blocked,
per "On `partial` or `blocked`: populate `blockers`... " instructions at line 316). **No
`continuation_context` key is ever written by this agent.**

**`lean-implementation-hard-agent.md` Stage 5** (lines 257-302) writes **both** keys, but always
shows `continuation_context` hardcoded `null`:
```json
{
  ...
  "continuation_path": null,
  "continuation_context": null
}
```
with population instructions only for `continuation_path` (line 302, mirroring core). No
instruction anywhere in the file populates `continuation_context`.

**`cslib-implementation-hard-agent.md` Stage 5** (lines 259-274) is the outlier — it has **only**
`continuation_context`, **no** `continuation_path` key at all, and it too is hardcoded `null`
with zero instruction for populating it on partial/blocked:
```json
{
  "status": "implemented | partial | blocked",
  "skeleton": false,
  "summary": "...",
  "phases_completed": N,
  "phases_total": M,
  "sorry_inventory": [],
  "blockers": [],
  "continuation_context": null,
  "artifacts": [...]
}
```
This means cslib's hard-mode agent, as currently instructed, **never populates any continuation
pointer at all** on a partial/blocked outcome — a narrower, related defect worth flagging
separately (see Risks & Mitigations).

**`validate-handoff.sh`** (the schema validator) already treats the two forms as equally valid,
and is the one place in the tree that already implements something like Option B:
```bash
# lines 180-186, 206-221
continuation_path=$(jq -r ".continuation_path // \"__MISSING__\"" "$HANDOFF_FILE" ...)
continuation_context=$(jq -r ".continuation_context // \"__MISSING__\"" "$HANDOFF_FILE" ...)
if [[ "$continuation_path" == "__MISSING__" ]] && [[ "$continuation_context" == "__MISSING__" ]]; then
  log_warn "Optional field absent: continuation_path (or continuation_context) -- add null if not applicable"
...
  log_pass "Continuation field present (continuation_path or continuation_context)"
```
and at the status/continuation consistency check (line 206-221) it accepts EITHER field being
non-null as satisfying "partial implies a continuation pointer."

### 3. What `docs/architecture/handoff-schema.md` currently says

The doc documents **only** the nested form as canonical (JSON Schema block, lines 74-126):
```json
"continuation_context": {
  "handoff_path": "specs/NNN_slug/handoffs/phase-N-handoff-TIMESTAMP.md",
  "orchestrator_mode": true
}
```
and its field definition (lines 217-223):
> "### `continuation_context` (optional, present when `status = "partial"`)
> Points to the continuation handoff file written by the agent. The orchestrator reads
> `handoff_path` and passes it in the next implement dispatch as `continuation_context`. It also
> carries `orchestrator_mode`... It does NOT carry `phases_completed` or `phases_total`."

It never mentions `continuation_path` anywhere in the document — despite its own "Handoff
Writers" table (line 265) naming `general-implementation-hard-agent.md` H9 Stage 5 as "the only
active writer... today," and that writer emitting `continuation_path`, not `continuation_context`.
The doc's "Example Handoff Objects -> Partial with Continuation" (lines 523-551) shows a
`continuation_context` object — an example that, per the writer findings above, **no currently
active writer would ever actually produce**. The doc is self-contradictory: it correctly
identifies the sole active writer, but documents a schema that writer does not implement.

### 4. Consumers of the continuation pointer, and Option-B impact

| Consumer | Field read | Would Option B break it? |
|---|---|---|
| `orchestrate-triage-classify.sh` | `.continuation_context.handoff_path` | This IS the file to change (add `.continuation_path` as an OR-branch) |
| `skill-orchestrate/SKILL.md` Stage 4 partial handler (base) | `.continuation_context` (line 379), explicitly cross-referenced (lines 369-372) as "the identical triage rule applied by hand" to the classify script — **must change in lockstep** | Same as above; the SKILL.md prose and the script are declared one rule, two copies |
| `skill-orchestrate-hard/SKILL.md` Stage 4 partial handler (hard) | `.continuation_path` only (line 624) — does NOT fall back to `.continuation_context` | Not broken by Option B (it already reads the flat form); for full symmetry it could also gain an OR-fallback, though no current writer needs it |
| `orchestrate-dry-run-report.sh` | Calls the classify script and reports its `handoff_state`/`group` verbatim | Inherits the fix automatically; no separate change needed since its entire purpose is mirroring the live path |
| `validate-handoff.sh` | Both forms already, independently | Already compatible; becomes the reference precedent to cite |
| `skill-base.sh`'s `skill_write_orchestrator_handoff` | Writes nested form only, unreferenced | Out of the hot path; lowest priority — could be left alone or given a parallel flat-field env var, not required for the definition-of-done |
| Downstream: what gets PASSED to the next implement dispatch as `context.continuation_context` (`skill-orchestrate/SKILL.md` line 410) | Currently the raw `.continuation_context` handoff field, which will still be null/absent when only `continuation_path` was populated | This is a real secondary gap: even after the classifier correctly recognizes `continuation_path` as "continuation available," Stage 4's dispatch-context construction at line 410 still needs to normalize `continuation_path` into whatever shape the successor implementation agent expects (`continuation_context: {handoff_path: ..., orchestrator_mode: true}`, matching the shape `subagent-continuation-loop.md` already documents for the *intra-skill* successor case) — this normalization step is implementation work, not just a predicate relaxation, and should be scoped explicitly in the eventual plan |

### 5. Regression test shape (per `context/standards/shell-script-testing.md`)

The now-established convention (confirmed by both existing suites,
`scripts/tests/test-census-count.sh` and `scripts/tests/test-validate-no-task-references.sh`,
both registered in `manifest.json`'s `provides.scripts` array as `tests/test-<name>.sh`) is:

- **Location rule**: a fix to a single script (`orchestrate-triage-classify.sh`) is a "narrow,
  fixture-driven suite for a single script" -> belongs at
  `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`, testing
  `../orchestrate-triage-classify.sh` by relative path — not a new flat top-level suite.
- **Helper convention**: `pass()`/`fail()`/`info()`, integer `PASSED`/`FAILED` counters,
  `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, exit 0 iff `FAILED==0`.
- **Fixture convention**: inline heredocs into a `mktemp -d` workdir with a `trap cleanup EXIT` —
  no committed fixture tree, since these are plain-text JSON fixtures. The suite needs a
  synthetic `specs/state.json` (with a `partial`-status `active_projects` entry) plus a synthetic
  `specs/{NNN}_{slug}/.orchestrator-handoff.json` inside that workdir, since the script resolves
  `PROJECT_ROOT` from its own location — the test will need to either invoke it with a
  temp-rooted copy (as `test-census-count.sh` does by copying the tool into `$WORKDIR`) or set an
  override; check whether `orchestrate-triage-classify.sh`'s `PROJECT_ROOT` derivation
  (`$(cd "$SCRIPT_DIR/../.." && pwd)`, line 114) allows a copied-tree invocation the same way
  `test-census-count.sh` copies `census-count.sh` into `$WORKDIR` — this needs a small
  investigation step in the implementation phase (copy the whole `scripts/` dir plus a synthetic
  `specs/` sibling into the workdir, or add a `STATE_FILE`-override mechanism; the script
  currently hardcodes `STATE_FILE="$PROJECT_ROOT/specs/state.json"` with no env-var override,
  which the test harness will need to either work around via directory structure or via a small,
  separately-justified override addition).
- **Mutation-check discipline is mandatory here** (`shell-script-testing.md`'s "Mutation checks
  for regex-shaped fixes" section applies directly: this is exactly a "regex/pattern fix" in
  spirit — a predicate-shape fix): the suite is not trustworthy until shown to FAIL against the
  pre-fix predicate (nested-only) on a fixture where `continuation_path` is populated but
  `continuation_context` is null/absent — i.e., exactly the null-`handoff_path`
  (or absent-`continuation_context`)-with-populated-note case named in the definition-of-done.
  Concretely: one fixture with `continuation_context: null, continuation_path: "specs/.../handoffs/..."`
  should assert `handoff_state == "continuation"` (or whatever the fixed classification is named)
  post-fix, and the suite should be run once against the current (pre-fix) script to confirm it
  reports `"empty"` there, proving the fixture actually exercises the gap before the fix lands.
- **Registration**: add `"tests/test-orchestrate-triage-classify.sh"` to `manifest.json`'s
  `provides.scripts` array alongside the two existing `tests/` entries.

## Decisions

- **Option B is the grounded recommendation**, but precisely scoped as: extend the classifier's
  (and base SKILL.md's hand-applied mirror's) predicate to accept `continuation_path` (top-level,
  non-null) as an equally-valid alternative to `continuation_context.handoff_path` (nested,
  non-null) — mirroring `validate-handoff.sh`'s already-shipped dual-acceptance convention. This
  is **not** "accept any substantive payload" as the task's framing loosely suggested (no writer
  anywhere emits a `continuation_context.note` field); it is "accept the field shape the sole
  active writer actually emits, the same way the schema validator already does."
- Do NOT choose Option A (forcing all writers onto the nested form): it would require rewriting
  `wrap-up.md`'s canonical schema and three separately-maintained agent files (core, cslib, lean)
  AND `skill-orchestrate-hard/SKILL.md`'s own already-self-consistent reader — a much wider
  blast radius than fixing two consumers (the classify script and base SKILL.md's mirrored
  prose) to recognize a form that's already validated as legitimate elsewhere in the tree.
- `docs/architecture/handoff-schema.md` must be rewritten, not patched: its JSON Schema block,
  `continuation_context` field definition, "orchestrator_mode Flag in Continuation Context"
  example, and "Partial with Continuation" example all currently show only the nested form that
  the documented sole active writer does not produce. It should document both forms, state which
  writer emits which, and cite `validate-handoff.sh`'s existing dual-acceptance as the precedent.
- The dispatch-context normalization gap (item 4's downstream row) is real implementation work,
  separate from the predicate fix itself, and should be an explicit phase/step in the eventual
  plan rather than assumed to fall out of the predicate relaxation alone.

## Risks & Mitigations

- **Risk**: fixing only the classifier without fixing the dispatch-context construction at
  `skill-orchestrate/SKILL.md` line 410 leaves the successor implement dispatch still unable to
  actually consume the continuation pointer (it would correctly route to the "continuation
  available" branch but pass a `continuation_context` value that's still null). **Mitigation**:
  scope this normalization explicitly as a plan phase; do not treat the predicate fix alone as
  satisfying the definition-of-done's "classifies as a continuation" bar if the successor never
  actually receives usable resume context.
- **Risk**: cslib's Stage 5 template never populates any continuation pointer on partial/blocked
  today, independent of which option is chosen. **Mitigation**: flag as a related but separable
  defect for a follow-up task (or a clearly-scoped additional phase) — fixing the classifier's
  predicate does nothing for cslib until its agent file is also given population instructions.
- **Risk**: `skill-orchestrate-hard/SKILL.md`'s reader only checks `.continuation_path`, so if a
  future writer (e.g., a revived `skill_write_orchestrator_handoff`) ever emits only the nested
  form, hard-mode's own reader would miss it — the mirror-image of today's bug. **Mitigation**:
  give the hard-mode reader the same OR-fallback for full symmetry, even though no current writer
  requires it yet.
- **Risk**: the regression test's dependency on `specs/state.json` and `PROJECT_ROOT` resolution
  makes it harder to sandbox than `test-census-count.sh`'s single-binary copy pattern.
  **Mitigation**: investigate at implementation time whether copying `scripts/` plus a synthetic
  `specs/` sibling into `$WORKDIR` is sufficient, or whether a minimal, separately-justified
  env-var override for `STATE_FILE` is warranted — do not skip the mutation-check discipline to
  avoid this friction.

## Context Extension Recommendations

- **Topic**: continuation-pointer field-shape convention (`continuation_path` vs
  `continuation_context.handoff_path`).
- **Gap**: no single context file documents that these are two historically-diverged,
  now-intentionally-dual-accepted forms; `handoff-schema.md` currently asserts only one is
  canonical while `validate-handoff.sh` already accepts both.
- **Recommendation**: once the classifier fix lands, add a short "Two Accepted Forms" subsection
  to `docs/architecture/handoff-schema.md` (not a new file) cross-referencing `wrap-up.md` (flat
  form, hard-mode canonical) and the nested form (documented, currently dead-writer-only), so a
  future editor does not re-diverge them a third time.

## Appendix

### Files read (grounding for this report)

- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (full)
- `agent-system/extensions/core/scripts/skill-base.sh` (lines 560-680, `skill_write_orchestrator_handoff`)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (full)
- `agent-system/extensions/core/context/contracts/wrap-up.md` (full)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (Stage 5, lines 286-425)
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (lines 245-284)
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` (lines 255-302)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 4 partial handler, lines 330-502)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 4 partial handler, lines 600-770)
- `agent-system/extensions/core/scripts/validate-handoff.sh` (continuation-field checks)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (header/purpose)
- `agent-system/extensions/core/context/patterns/subagent-continuation-loop.md` (full — the
  *different*, intra-skill successor `continuation_context` shape, confirmed out of scope but
  useful as the shape precedent for the dispatch-context normalization gap noted above)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (full)
- `agent-system/extensions/core/scripts/tests/test-census-count.sh` (header/pattern reference)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` registration lines)

### Search queries used

- `grep -n "continuation_context|handoff_path|ORCHESTRATOR_HANDOFF_CONTINUATION_JSON" skill-base.sh`
- `grep -rln "continuation_context" agent-system --include=*.md --include=*.sh`
- `grep -n "continuation" general-implementation-hard-agent.md / cslib.../lean...`
- `grep -n "orchestrate-triage-classify" skill-orchestrate/SKILL.md skill-orchestrate-hard/SKILL.md orchestrate-dry-run-report.sh`
- `grep -rn '"note"' agent-system/extensions/core` (confirmed no literal `continuation_context.note`
  field exists anywhere in the tree — the task's phrasing describes the *substance* of the
  markdown handoff content, not a literal JSON field name)
