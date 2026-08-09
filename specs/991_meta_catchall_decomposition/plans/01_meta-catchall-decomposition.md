# Implementation Plan: Break the meta task_types catch-all, derive tier algorithmically

- **Task**: 991 - meta_catchall_decomposition
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: `specs/991_meta_catchall_decomposition/reports/01_meta-catchall-decomposition.md`
- **Artifacts**: plans/01_meta-catchall-decomposition.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four work items land on two source-store files (plus three files named in the Scope Expansion
section): the `index-entries.json` hook data and the `validate-context-budgets.sh` validator.
The mechanical, self-verifying work — algorithmic tier derivation at all four `.tier` call sites,
and the two broken agent names — lands first, behind a verification harness built and proven in
Phase 1. The higher-churn hook/trim work (real hooks for the 25 meta-only entries, then trimming
`"meta"` out of the remaining 61) lands after, once there is a diffable instrument to measure it
with.

The plan is built against measured numbers, not the task description's numbers. It states its
own reachable verification bar in a dedicated section rather than carrying the original,
unreachable one forward.

### Research Integration

Four findings from the research report are treated as decided input and are not re-litigated:

1. **Corrected census.** The description's "123-entry" figure was a key-presence census
   mis-narrated as a value census. The real numbers, re-confirmed independently while writing
   this plan: **25** meta-only entries (all in core), **86** meta-tagged entries in core plus
   **1** in nvim, **0** entries carrying an authored `tier` field, **136** core entries, **187**
   deployed entries. Every phase below targets these numbers.
2. **The budget check and the trim are disjoint.** `validate-context-budgets.sh`'s per-agent
   check reads only `load_when.agents`; it never reads `task_types`. Trimming `"meta"`
   (item 2) therefore provably **cannot** move any per-agent budget number, and adding real
   hooks (item 1) **increases** `general-implementation-agent` by 1,470 lines. Trimming still
   delivers a real ~38% cut to `meta-builder-agent`'s *resolved context* under the documented
   adaptive query (93 entries / 26,987 lines -> ~57 / ~16,600). Both statements are true; this
   plan asserts both and never implies the trim fixes the budget check.
3. **Four `.tier` call sites, not one.** Verbose per-agent listing, Tier Classification Check,
   Dead Entry Check (twice), Double-Loading Check. All four are converted in Phase 2. The
   all-hooks-empty fallthrough derives to Tier 4, which makes the Dead Entry Check a tautology,
   so it is replaced by an explicit-intent check keyed on a new `on_demand` marker (Phase 4).
   Restating the Double-Loading Check without its tier predicate surfaces **49** matches
   immediately (re-confirmed: 49 of 187); Phase 2 owns that by downgrading the restated check to
   a reported warning, with justification, rather than letting it fail the run on day one.
4. **Both broken agent names live in one core entry**, `contracts/adversarial-verification.md`.
   Fixed in Phase 3 by dropping the two extension-owned names from core and adding a mirror
   entry to `cslib/index-entries.json`, matching the pattern `lean/index-entries.json` already
   uses.

### Two findings added by this plan

Neither contradicts the research; both close open questions it flagged.

**A. The entry schema already forbids an authored `tier` — and forbids unknown keys.**
`agent-system/extensions/core/context/index.schema.json` sets `additionalProperties: false` on
the entry shape and carries a `$comment` stating that `tier` is *deliberately absent* because it
"is meant to be derived algorithmically from load_when shape rather than hand-authored, since no
entry in practice ever populated it accurately." This is independent confirmation of work item 3's
whole premise. It also means the `on_demand` explicit-intent marker cannot simply be added to
entries: it must be declared as a schema property first, or it is an `additionalProperties`
violation. Phase 4 does both, in that order. (`check-extension-docs.sh` Rule T does not enforce a
closed top-level key set today — only required keys, the forbidden `description`/`tags` keys, and
a closed `load_when` key set — so the marker would pass Rule T while silently violating the
schema. That gap is why the schema edit is mandatory, not optional.)

**B. The loader upserts index entries by `path`; it never appends duplicates.** The research
flagged "confirm loader dedup behavior before adding the cslib entry" as an open question.
`lua/neotex/plugins/ai/shared/extensions/merge.lua`'s `append_index_entries` replaces an existing
`path` in place and appends only new paths, so no duplicate-path state is reachable. The real
caveat is different and is documented in that function's own header: under upsert, **whichever
extension is processed last wins the whole entry**. A naive cslib mirror entry naming only
`cslib-research-hard-agent` would, in a cslib-loaded deploy where cslib is processed after core,
*replace* core's entry and silently unhook `general-research-hard-agent`. Phase 3 therefore
writes the cslib entry as a **union** (`general-research-hard-agent` +
`cslib-research-hard-agent`), so the load-order race degrades gracefully in both directions
instead of dropping a hook. Fixing load-order override priority in general is out of scope and
remains the dormant issue that header already records.

### Prior Plan Reference

No prior plan. A prior dispatch on this task died mid-stream from an API stall before producing
one; nothing from it is carried forward.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was consulted.

## The Verification Bar: Decision and Restatement

The bar as originally written — "`validate-context-budgets.sh` reports zero per-agent budget
violations" — is **not reachable inside this task's file scope**, and this plan does not pretend
otherwise. Of the 10 baseline violations, 8 are per-agent budget overruns totalling ~252,000
tokens of overshoot, driven by `load_when.agents` breadth spread across core, nvim, and nix.
This task's work does not touch that surface, and item 1 slightly worsens two of those agents.
The bar's own escape clause is the intended path.

### Options considered

**(a) Raise `CAPS` to measured post-work values, with per-agent written justification.**
This is what the bar literally licenses, and it is rejected. A cap set equal to current usage can
never fail; raising all eight would convert the per-agent budget check from a live instrument
into a permanent tautology, retiring the only mechanism that would notice future growth. The same
error mode this task is fixing elsewhere — the Dead Entry Check about to become vacuous under
tier derivation — would be reintroduced deliberately in the budget check. Worse, six of the eight
overruns belong to agents this task's scope has no mandate over (`nix-*`, `neovim-*`,
`general-research-agent`, `code-reviewer-agent` surface): "documenting a deliberate cap change"
for them would be recording a decision this task is not entitled to make.

**(b) Re-scope the bar to derivation-passes + no new violations beyond the documented increase.**
Chosen.

### The chosen bar (the plan's actual, checkable success criterion)

After all phases, a validator run against the merged index MUST report **exactly this**:

| Check | Required result |
|-------|-----------------|
| Tier Classification Check | `OK` — every entry classifies via `derived_tier`; 0 violations. The authored `tier` field is read at zero call sites. |
| Dead Entry Check (now explicit-intent) | `OK` — 0 violations. Every all-hooks-empty entry carries `on_demand: true`; an unmarked one would still be reported. |
| Double-Loading Check | Reported as a **warning** naming 49 entries. 0 violations. |
| Tier 1 Check | `OK`, unchanged (3 entries / 334 lines). |
| Per-agent budget | Exactly **8** violations — the same eight agents as the baseline, no ninth. |
| `general-implementation-agent` | Exactly **68,560** tokens (baseline 56,800 + 11,760 = the documented +1,470 lines from G1 and G5). |
| `planner-agent` | Exactly **31,848** tokens (baseline 29,200 + 2,648 = the documented +331 lines from G1). |
| Every other capped agent | Byte-identical to its baseline value. |
| Total violations / exit code | **8** / exit **1**. |

Exit 1 is the accepted, expected terminal state. It reflects eight pre-existing overruns that
this task deliberately did not paper over. The two increased numbers are not incidental drift:
they are named, predicted to the token before implementation begins, and any deviation from them
is a phase failure.

Two derived non-negotiables follow from this bar:
- Correct hooks outrank the cap. G1 and G5 route to the agents that actually consume those files;
  the resulting increase is accepted and documented rather than avoided by leaving hooks wrong.
- Any *unpredicted* change to a capped agent's number is a defect, in either direction. A
  decrease is as suspect as an increase — it means a hook was dropped that should not have been.

### Deviation on the bar's literal command

The bar names `bash .claude/scripts/validate-context-budgets.sh`. That command reads the
**deployed** `.claude/context/index.json` and runs the **deployed** copy of the validator; both
are regenerated from the source store, so neither reflects a source-store edit until a redeploy
runs. Running the source-store copy directly is refused by `deploy-root-guard.sh` by design.

The implementer **MUST NOT** run `deploy-headless.sh`.
`context/patterns/regeneration-is-manual-only.md` sanctions exactly one automated caller
(`skill-orchestrate` Stage MT-3 step 7) and states that no other automated caller is licensed
without its own recorded exception. This task has no such exception and does not create one.

Instead, Phase 1 builds a shadow harness that reconstructs the merged index from the active
extensions' source `index-entries.json` files and runs the *source-store* validator against it,
and then **proves the harness equivalent to the deployed run** before any edit is made. That
equivalence has already been demonstrated once during planning: the reconstructed index has a
path set identical to the deployed index (187 entries, verified by `diff` of sorted path lists),
and the source-store validator run against it reproduced the deployed baseline output verbatim,
including the 10 violations and exit 1. Phase 1 re-establishes this as a recorded gate rather
than relying on the planning-time observation.

The deployed confirmation run is therefore **post-implementation**, performed by the operator (or
by the sanctioned orchestrate checkpoint) after a redeploy, and is listed under Testing &
Validation as an operator step — not as an implementer step.

## Goals & Non-Goals

**Goals**:
- Every one of the 25 meta-only core entries carries a real `agents`/`commands` hook, or is
  explicitly marked on-demand; none is reachable only via `task_types: ["meta"]`.
- `"meta"` appears in zero `load_when.task_types` arrays across the source store, so `meta` ceases
  to be a load_when discriminator and `meta-builder-agent`'s resolved context drops to ~57
  entries / ~16,600 lines.
- `validate-context-budgets.sh` derives tier from `load_when` shape at all four former `.tier`
  call sites; the authored `tier` field is read nowhere.
- The Dead Entry Check retains real signal via an explicit `on_demand` marker rather than
  becoming a tautology.
- No agent name in any `load_when.agents` array names an agent absent from this deploy.
- Every phase's effect on capped agents is predicted before the edit and confirmed after it.

**Non-Goals**:
- Reducing the 8 pre-existing per-agent budget overruns. Out of file scope; see the bar decision.
- Raising or otherwise editing the `CAPS` or `EXCEPTIONS` tables. Deliberately untouched.
- Triaging the 49 entries the restated Double-Loading Check surfaces. Recorded as a follow-up;
  the check reports them as a warning so the signal exists without blocking.
- Fixing load-order override priority for paths declared by more than one extension. The upsert
  header already records this as a known dormant issue; Phase 3 mitigates its blast radius for
  the one entry it touches and changes nothing structural.
- Authoring a `context/reference/index-tier-semantics.md` (the research's context-extension
  recommendation). The derivation's authority for now is the documented `derived_tier` function
  and its header comment in the validator. Recommended as follow-up.
- Promoting the Phase 1 harness into `agent-system/extensions/core/scripts/`. It stays a task
  artifact; promoting it is a separate decision with its own deploy surface.
- Any edit under `.claude/**`, and any redeploy.

## Scope Expansion

The declared `file_scope` is `agent-system/extensions/core/index-entries.json` and
`agent-system/extensions/core/scripts/validate-context-budgets.sh`. Three files outside it are
required. Each is named here with justification rather than being widened into silently.

| File | Phase | Why it is unavoidable |
|------|-------|------------------------|
| `agent-system/extensions/cslib/index-entries.json` | 3 | Work item 4 removes `cslib-research-hard-agent` from core's `contracts/adversarial-verification.md`. cslib has no entry for that path today, so removal alone would silently un-index the contract for cslib. The mirror entry is the second half of the fix, not an extra. Established precedent: `lean/index-entries.json` already carries exactly this mirror. |
| `agent-system/extensions/core/context/index.schema.json` | 4 | `additionalProperties: false` on the entry shape means the `on_demand` marker is a schema violation until the property is declared. Without this, Phase 4's fix for the Dead Entry Check tautology is not schema-legal. |
| `agent-system/extensions/nvim/index-entries.json` | 7 | Exactly one meta-tagged entry lives outside core. Leaving it means `"meta"` survives in the source store and the trim's stated goal ("zero remaining") is false. One-line edit. |

No other file outside the declared scope is edited. In particular, `check-extension-docs.sh` is
**not** edited: its Rule T does not enforce a closed top-level key set, so a newly declared
`on_demand` property needs no lint change. This is recorded as a known asymmetry (Finding A), not
fixed here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Harness diverges from the real merged index (e.g. a new extension is activated, or two active extensions declare the same path) so phase verifications measure a fiction | H | L | Phase 1 gate asserts three things every run: active-extension list read live from `.claude-extensions.json`, zero duplicate paths across the reconstructed set, and path-set identity with the deployed index. Any failure stops the phase; the harness is never used unproven. |
| The +1,470 / +331 line increases are miscounted, so a real regression hides inside an "expected" delta | H | M | Both numbers are predicted per-phase to the token before the edit (Phases 5 and 6 each state their own contribution), not only in aggregate at the end. An unpredicted delta in either direction fails the phase. |
| Deriving Tier 4 from emptiness retires a working check | M | H (certain, by construction) | Phase 4's explicit-intent `on_demand` marker restores the distinction between "deliberately grep-only" and "someone forgot to hook this". Phase 4's verification specifically tests the negative case: temporarily unmarking one entry must reproduce the violation. |
| Restated Double-Loading Check turns a silent no-op into 49 immediate failures, blocking the bar | M | H (certain) | Downgraded to a reported warning in Phase 2, with the count and (verbose) list printed. Recorded as follow-up triage in Non-Goals. Never folded in silently. |
| Dropping `"meta"` un-indexes a file some meta dispatch relied on | H | M | Strict ordering: the 25 meta-only entries **gain** a real hook (Phases 5-6) **before** anything loses `"meta"` (Phase 7). No entry is ever hookless at a phase boundary. Phase 7 additionally asserts that every entry it touches still has at least one non-empty hook after the edit. |
| The cslib mirror entry loses `general-research-hard-agent` to the loader's last-writer-wins upsert | M | M | Phase 3 writes the union of both agent lists into the cslib entry, so either load order leaves `general-research-hard-agent` hooked. |
| `on_demand` violates `additionalProperties: false` | M | H (certain if unhandled) | Phase 4 edits the schema first, entries second, and verifies with a JSON-Schema-aware check plus `check-extension-docs.sh` Rule T. |
| Large multi-entry JSON edits corrupt `index-entries.json` | H | L | Every phase's first verification step is `jq empty` on each edited file plus an entry-count assertion; `jq`-driven bulk rewrites are preferred over hand-editing for the 49-entry and 62-entry operations. |
| Implementer runs `deploy-headless.sh` to "make the bar's literal command work" | M | M | Explicit MUST NOT in the bar section and repeated in Phase 8. The harness exists precisely so this temptation has a sanctioned alternative. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |
| 7 | 8 | 7 |

Phases within the same wave can execute in parallel. Wave 2 is genuinely parallel: Phase 2 edits
only `validate-context-budgets.sh`, Phase 3 edits only the two `index-entries.json` files. Every
later wave is a single phase because Phases 4-7 all mutate
`agent-system/extensions/core/index-entries.json` and must serialize on it.

**Baseline to diff every phase against** (recorded in the research, re-confirmed during planning):
exit 1, 10 violations — 8 per-agent budget overruns, 1 tier classification (187 missing), 1 dead
entries (3 found). `meta-builder-agent` 130,360 tokens vs 15,000 cap;
`general-implementation-agent` 56,800; `planner-agent` 29,200; `neovim-implementation-agent`
40,104; `general-research-agent` 28,744; `neovim-research-agent` 22,872;
`nix-implementation-agent` 22,520; `nix-research-agent` 19,896; `spawn-agent` 5,568 (OK);
`code-reviewer-agent` 5,544 (OK).

---

### Phase 1: Build and prove the shadow verification harness [COMPLETED]

**Goal**: Establish a repeatable, redeploy-free way to run the source-store validator against the
true merged index, and prove it reproduces the deployed baseline exactly — before any edit exists
to measure.

**Tasks**:
- [ ] Create `specs/991_meta_catchall_decomposition/shadow-validate.sh`. It must:
  - Read the active extension list live: `jq -r '.extensions | to_entries[] | select(.value.status == "active") | .key' .claude-extensions.json`. Do not hardcode the list.
  - Reconstruct the merged index by concatenating those extensions' `index-entries.json` entries:
    `jq -s '{version:"1.0.0", generated:"shadow", entries: [.[].entries[]]}'`.
  - **Assert zero duplicate `path` values** across the reconstruction; abort loudly if any exist (the loader upserts by path, so a duplicate would mean the concatenation is no longer equivalent to a real merge).
  - Assemble a shadow deploy tree under the scratchpad: a directory whose `scripts/` parent basename is `.claude` (required by `deploy-root-guard.sh`), containing `lib/`, `deploy-root-guard.sh`, and the **source-store** `validate-context-budgets.sh`.
  - Run the validator with `--index` pointed at the reconstructed index, printing its full output and preserving its exit code.
- [ ] Assert path-set identity against the deployed index:
      `diff <(reconstructed sorted paths) <(deployed sorted paths)` must be empty.
- [ ] Run the harness and capture output to `specs/991_meta_catchall_decomposition/baseline-validator.txt`.
- [ ] Capture the deployed run to a second file and `diff` the two. They must be identical apart from the `Index:` path line.
- [ ] Record the four census numbers as a baseline block in the same file: core meta-only (25), core meta-tagged (86), nvim meta-tagged (1), entries with authored `tier` (0), and the Double-Loading predicate match count (49).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The reconstructed index is asserted to have exactly 187 entries with a path
set identical to the deployed index, and the harness output is asserted to match the deployed
baseline (10 violations, exit 1). Confirm by running both and diffing; do not assume. If the
active-extension set has changed since planning, the counts will differ — that is a real signal,
not a harness bug, and must be recorded before proceeding.

**Files to modify**:
- `specs/991_meta_catchall_decomposition/shadow-validate.sh` - new task-artifact harness
- `specs/991_meta_catchall_decomposition/baseline-validator.txt` - new recorded baseline

**Verification**:
- `bash specs/991_meta_catchall_decomposition/shadow-validate.sh` exits 1 and prints `Violations: 10`.
- The duplicate-path assertion passes (0 duplicates).
- The path-set `diff` against `.claude/context/index.json` is empty.
- The harness-vs-deployed output `diff` shows only the `Index:` line.

---

### Phase 2: Derive tier algorithmically at all four `.tier` call sites [COMPLETED]

**Goal**: Replace every read of the never-populated authored `tier` field with a derivation from
`load_when` shape, and restate the two checks whose meaning changes as a result.

**Tasks**:
- [x] Add a single `derived_tier` jq function, defined once and reused, with a header comment *(completed)*
      stating the rule table and citing `index.schema.json`'s `$comment` as the reason the field
      is derived rather than authored:
      `always == true` -> 1; non-empty `agents` -> 2; non-empty `commands` or `task_types` -> 3;
      all hooks empty -> 4.
- [x] **Call site 1** (verbose per-agent listing): replace `\(.tier // "?")` with the derived *(completed)*
      value, so verbose output prints real tiers instead of `Tier ?`.
- [x] **Call site 2** (Tier Classification Check): stop counting `.tier == null`. Report the *(completed)*
      derived tier distribution (counts per tier 1/2/3/4) and total entries. Status is `OK`
      whenever every entry classifies — which, given a total function over the four cases, is
      always. Keep the section heading and the `OK`/`FAIL` line shape so the output stays
      diffable against the baseline.
- [x] **Call site 3** (Dead Entry Check): replace `.tier != 4` with the explicit-intent predicate *(completed)*
      `((.on_demand // false) != true)` in **both** the count query and the listing query. Update
      the section's comment to state that emptiness alone no longer exempts an entry.
      Note: this phase leaves the check reporting 3 violations; Phase 4 marks those entries.
- [x] **Call site 4** (Double-Loading Check): drop the `.tier == 3` term entirely — under *(completed)*
      derivation it is unsatisfiable, so keeping it would make the check structurally rather than
      accidentally dead. Restate as
      `select((.load_when.agents // [] | length) > 0 and (.load_when.commands // [] | length) > 0)`.
      Increment `WARNINGS`, **not** `VIOLATIONS`. Print the count unconditionally and the list
      under `--verbose`. Add a comment recording why it is a warning: the restatement surfaces 49
      pre-existing matches at once, and triaging them is separate work.
- [x] Leave `CAPS` and `EXCEPTIONS` byte-identical. Do not touch them. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly four `.tier` read sites are asserted to exist (verbose listing;
Tier Classification Check; Dead Entry Check, twice; Double-Loading Check). Confirm with
`grep -n '\.tier' agent-system/extensions/core/scripts/validate-context-budgets.sh` **after** the
edit — it must return zero matches. A non-zero result means a site was missed.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` - `derived_tier` function; all four call sites; Double-Loading downgraded to warning

**Verification**:
- `grep -c '\.tier' agent-system/extensions/core/scripts/validate-context-budgets.sh` returns 0.
- `bash -n agent-system/extensions/core/scripts/validate-context-budgets.sh` passes.
- Harness run: Tier Classification Check reports `OK` with a tier distribution; Dead Entry Check still reports 3; Double-Loading reports a **warning** naming 49 entries and adds 0 violations.
- Total violations drop from 10 to **9**; exit still 1.
- Per-agent budget block is byte-identical to the baseline (this phase touches no hook data).

---

### Phase 3: Fix the two broken agent names and add the cslib mirror [COMPLETED WITH EXCLUSIONS]

**Goal**: No `load_when.agents` value in the deployed index names an agent absent from this
deploy, without silently un-indexing the contract for cslib.

**Tasks**:
- [x] In `agent-system/extensions/core/index-entries.json`, entry `contracts/adversarial-verification.md`: set `load_when.agents` to `["general-research-hard-agent"]`, dropping `cslib-research-hard-agent` and `lean-research-hard-agent`. Leave `commands` and `task_types` as they are (both empty). *(completed)*
- [ ] In `agent-system/extensions/cslib/index-entries.json`, add a mirror entry for *(deviation: skipped — blocked by check-extension-docs.sh Rule R, a hard source-level gate requiring every index entry to have a source file at `<ext>/context/<path>`; cslib ships no copy of this contract. See this phase's Reasoned Exclusions.)*
      `contracts/adversarial-verification.md` following the shape `lean/index-entries.json`
      already uses for the same path. Set
      `load_when.agents = ["general-research-hard-agent", "cslib-research-hard-agent"]` — the
      **union**, per Finding B, so the loader's last-writer-wins upsert cannot drop the general
      hook. Set `task_types: ["cslib"]` to match cslib's declared routing task type. Populate
      `path`, `domain`, `subdomain`, `summary`, `line_count`, `keywords` per the schema's required
      set; take `line_count` from the actual file, not from core's copy.
- [x] Do **not** edit `lean/index-entries.json` or any other extension's existing references to these two agent names — the research established they are correct in context. *(completed)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| cslib mirror entry for `contracts/adversarial-verification.md` | `check-extension-docs.sh` Rule R (`check_line_count_accuracy`, a HARD gate — `INDEX_TRUTH_GATE_MODE` defaults to `hard`) requires every `index-entries.json` entry to resolve to a source file at `<ext>/context/<path>`. cslib ships no copy of this contract, so the mirror entry is structurally illegal regardless of its `load_when` shape. The plan cited `lean/index-entries.json` as shape precedent, but lean's mirror is legal only because lean also owns `lean/context/contracts/adversarial-verification.md` (93 lines, lean-specialized) — a fact the plan did not account for. Making the cslib entry legal would require authoring a cslib-specialized ~103-line copy of a core-owned contract: new content, a new file outside the declared Scope Expansion, and precisely the "guessing at a shape" the phase's own contingency forbids. | Added the entry, ran `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`; it reported `[cslib] FAIL: Rule R: index-entries.json entry 'contracts/adversarial-verification.md' has no source file at context/contracts/adversarial-verification.md`. Reverted; `git diff` on `cslib/index-entries.json` is now empty and the extension re-reports PASS. Rule R source: `check-extension-docs.sh` lines 600-644. |

Taken under this phase's own documented contingency: "Keep the core removal — it is correct on
its own — and record the cslib mirror as unfinished rather than guessing at a shape." The core
removal landed and is verified. Recorded follow-up: for cslib to hook this contract, cslib must
first own a copy at `cslib/context/contracts/adversarial-verification.md` (mirroring how lean
does it); the index entry is the second step, not the first.

Known consequence, stated rather than hidden: in a cslib-loaded deploy the contract was
previously reachable for `cslib-research-hard-agent` via core's entry, and now is not. The plan
ranked these explicitly — "A core entry naming an absent agent is the defect being fixed; an
absent cslib entry is a lesser, recorded gap" — and this outcome follows that ranking.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Exactly 2 broken names in exactly 1 core entry, and cslib has exactly 0
existing entries for this path. Confirm before editing by re-running the broken-name detection
(`comm -23` of referenced agent names against `ls .claude/agents/`) and by grepping cslib's index
for the path. If cslib already has an entry, merge into it rather than adding a second.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one entry's `agents` array
- `agent-system/extensions/cslib/index-entries.json` - new mirror entry (Scope Expansion)

**Verification**:
- `jq empty` passes on both edited files; core entry count still 136; cslib count is exactly one higher than before.
- Broken-name detection over the reconstructed index returns empty.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` reports no new Rule T findings for core or cslib.
- Harness run: violation count and every capped-agent token value byte-identical to the phase's starting state (neither removed agent is capped, so a change here is a defect).

---

### Phase 4: Declare `on_demand` in the schema and mark the existing all-empty entries [COMPLETED]

**Goal**: Restore real signal to the Dead Entry Check by making "deliberately grep-only"
expressible and schema-legal, so it stays distinguishable from "someone forgot to hook this".

**Tasks**:
- [x] In `agent-system/extensions/core/context/index.schema.json`, add an `on_demand` property to *(completed)*
      the `$defs.entry` shape: `{"type": "boolean", "description": "..."}`. It is optional;
      absence means `false`. Do **not** relax `additionalProperties: false`.
- [x] Extend that entry's existing `$comment` (do not replace it — it is the load-bearing record *(completed)*
      that `tier` is derived, not authored) with a sentence explaining that `on_demand` is the
      explicit-intent marker consumed by the Dead Entry Check, and that it exists precisely
      because deriving Tier 4 from emptiness would otherwise make that check a tautology.
- [x] In `agent-system/extensions/core/index-entries.json`, add `"on_demand": true` to the three *(completed)*
      entries that are all-hooks-empty today: `reference/artifact-templates.md`,
      `contracts/convergence.md`, `contracts/orchestrator-discipline.md`.
- [x] Confirm no other extension owns an all-hooks-empty entry; if the harness reports one *(completed)*
      outside core, stop and record it rather than editing a file outside this plan's scope.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: Exactly 3 all-hooks-empty entries exist, all owned by core (confirmed
during planning by per-extension lookup). Re-derive the list from the reconstructed index before
editing rather than trusting this count; if it is not 3, or any is outside core, halt and record.

**Files to modify**:
- `agent-system/extensions/core/context/index.schema.json` - new `on_demand` property; extended `$comment` (Scope Expansion)
- `agent-system/extensions/core/index-entries.json` - `on_demand: true` on 3 entries

**Verification**:
- `jq empty` passes on both files; core entry count still 136.
- Harness run: Dead Entry Check reports `0 -- OK`. Total violations drop from 9 to **8**; exit 1.
- Per-agent budget block byte-identical to the previous phase (marking changes no hook).
- **Negative test** (required, not optional): temporarily remove `on_demand` from one of the three entries, re-run the harness, confirm the Dead Entry Check reports 1 violation naming that entry, then restore it. This proves the check still has signal rather than having become a tautology.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` reports no new Rule T findings.

**Deviation recorded — `meta-builder-agent` moved +40 tokens (130,360 -> 130,400):**

The phase predicted a byte-identical per-agent block. It is not, and the difference is real,
exact, and fully traced rather than papered over:

1. `index.schema.json` is itself an indexed context entry, and its `load_when.agents` names
   `meta-builder-agent`. The plan did not account for the schema file being hooked to the very
   agent whose number the bar tracks.
2. This phase's own mandated edit — "Extend that entry's existing `$comment`" plus the new
   `on_demand` property — grew the file from 128 to 133 lines.
3. `check-extension-docs.sh` Rule R is a hard gate on `line_count` accuracy and failed with
   `line_count mismatch: declared 128, actual 133`, so correcting the declared count to 133 was
   mandatory, not optional.
4. 5 lines x 8 tokens = 40 tokens; 130,360 + 40 = 130,400 exactly. No other capped agent moved.

The delta is a correct measurement of real content growth, not a dropped or misrouted hook, so
the instrument behaved exactly as intended. Shrinking the `$comment` to restore 128 lines was
rejected: that would be tuning the artifact to flatter the number. **The chosen bar's
`meta-builder-agent` row is therefore restated as 130,400**, and Phase 8 attests against that
value with this justification attached.

---

### Phase 5: Real hooks for meta-only groups G1, G2+G7, G3 [COMPLETED]

**Goal**: Give 15 of the 25 meta-only entries the hooks their actual consumers imply, and remove
`"meta"` from each in the same edit — the hook and its replacement land together so no entry is
ever hookless.

**Tasks**:
- [x] **G1, checkpoint lifecycle** (3 entries, 331 lines) — `checkpoints/checkpoint-gate-in.md`, *(completed)*
      `checkpoints/checkpoint-commit.md`, `checkpoints/checkpoint-gate-out.md`.
      Set `agents: ["general-implementation-agent", "general-implementation-hard-agent",
      "planner-agent", "planner-hard-agent"]`, `commands: []`, `task_types: []`.
      Deliberately excludes `meta-builder-agent` and the research agents: `/meta` creates tasks,
      it does not run the commit lifecycle.
- [x] **G2 + G7, error/event records** (5 entries, 1,020 lines) — `formats/errors-format.md`, *(completed)*
      `formats/events-format.md`, `schemas/errors-schema.json`, `schemas/events-schema.json`, and
      `patterns/system-defect-discrimination.md` (the entry added after the prerequisite census;
      folded into G2 per the research's decision).
      Set `commands: ["/errors", "/orchestrate"]`, `agents: []`, `task_types: []`.
      Command-scoped because these are consumed by whoever is *writing* a record at that moment —
      a command-phase fact, not an agent identity. Zero capped-agent cost.
- [x] **G3, orchestration + handoff** (7 entries, 1,638 lines) — `formats/handoff-artifact.md`, *(completed)*
      `orchestration/sessions.md`, `orchestration/subagent-validation.md`,
      `patterns/file-metadata-exchange.md`, `patterns/infra-failure-discrimination.md`,
      `patterns/mcp-tool-recovery.md`, `patterns/postflight-control.md`.
      Set `commands: ["/orchestrate"]`, `agents: []`, `task_types: []`.
      **Command-scoped, contra the prerequisite's tentative "plus every research/plan/implement
      agent" suggestion**: enumerating those agents would add ~1,638 lines each to six agents
      already over budget, for reachability the `/orchestrate` command hook already provides.
- [x] Verify every touched entry ends with at least one non-empty hook before moving on. *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: 15 entries, 2,989 lines, with a predicted capped-agent delta of **+331
lines (+2,648 tokens) to `general-implementation-agent` and to `planner-agent`, and zero to every
other capped agent**. Confirm by re-running the harness and comparing every row: expected
`general-implementation-agent` 59,448 and `planner-agent` 31,848, all others unchanged. Any other
movement is a defect.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - 15 entries' `load_when` blocks

**Verification**:
- `jq empty` passes; core entry count still 136.
- Meta-only count drops from 25 to exactly **10**.
- Harness run: `general-implementation-agent` = **59,448**, `planner-agent` = **31,848**, all other capped agents byte-identical to Phase 4. Violations still **8**; exit 1.
- Zero entries among the 15 have all hooks empty.

---

### Phase 6: Real hooks for meta-only groups G4, G5, G6 [COMPLETED]

**Goal**: Finish the meta-only set — including the three entries that are deliberately dropped to
grep-only, which is where Phase 4's `on_demand` marker earns its existence.

**Tasks**:
- [x] **G4, team mode** (3 entries, 657 lines) — `patterns/team-orchestration.md`, *(completed)*
      `reference/team-wave-helpers.md`, `formats/team-metadata-extension.md`.
      Set `agents: ["synthesis-agent"]`, `commands: []`, `task_types: []`. `synthesis-agent` is
      uncapped, so this is budget-free. Recorded limitation: the team skills are not agents and
      `--team` is a flag rather than a command, so `synthesis-agent` is the only hook the schema
      can currently express for this group.
- [x] **G5, git / CI / commit discipline** (4 entries, 1,139 lines) — `standards/git-safety.md`, *(completed)*
      `standards/git-integration.md`, `standards/ci-workflow.md`,
      `standards/postflight-tool-restrictions.md`.
      Set `agents: ["general-implementation-agent", "general-implementation-hard-agent"]`,
      `commands: []`, `task_types: []`. Explicitly excludes every research agent. This is the
      single largest budget impact of the whole task and is accepted deliberately: the hook is
      correct, and correctness outranks the cap per the bar section.
- [x] **G6, quick-reference, drop to grep-only** (3 entries, 285 lines) — `routing.md`, *(completed)*
      `validation.md`, `reference/workflow-diagrams.md`.
      Set all `load_when` arrays empty **and** add `"on_demand": true` to each. Omitting the
      marker would trip the Dead Entry Check — which is the intended behavior, and the reason
      Phase 4 precedes this one.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Scope Hypothesis**: 10 entries, 2,081 lines, with a predicted capped-agent delta of **+1,139
lines (+9,112 tokens) to `general-implementation-agent` only**. Confirm by harness: expected
`general-implementation-agent` 68,560, `planner-agent` unchanged at 31,848, all others unchanged.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - 10 entries' `load_when` blocks; 3 gain `on_demand: true`

**Verification**:
- `jq empty` passes; core entry count still 136.
- Meta-only count is exactly **0**. This is work item 1 complete.
- Harness run: `general-implementation-agent` = **68,560**, `planner-agent` = **31,848**, all other capped agents byte-identical to Phase 5.
- Dead Entry Check still reports `0 -- OK` (all six all-empty entries now carry `on_demand`). Violations still **8**; exit 1.
- Count of entries carrying `on_demand: true` is exactly 6.

---

### Phase 7: Trim `"meta"` from the wider meta-tagged set [COMPLETED]

**Goal**: Make `"meta"` disappear from every `load_when.task_types` array in the source store, so
`meta-builder-agent`'s resolved context stops sweeping in everything tagged meta regardless of
relevance.

**Tasks**:
- [x] **Class 1 — 49 core entries with `"meta"` plus at least one `agents` hook**: drop `"meta"` *(completed)*
      from `task_types`, leaving `agents` untouched. Redundant where `agents` already names
      `meta-builder-agent`; wrong where it does not (the entry is agent-scoped and `"meta"`
      re-broadens it to every meta-typed dispatch). Prefer a `jq` bulk rewrite over hand-editing.
- [x] **Class 2 — 12 core entries with `"meta"` plus a `commands` hook and no `agents`**: read *(completed)*
      each one and decide whether it is genuinely meta-specific. The measured command sets are
      `/todo`, `/task`, `/errors`, `/fix-it`, `/orchestrate`, `/research,/plan,/implement` — none
      obviously meta-specific, so the expected outcome is "drop `"meta"`, add `/meta` to none".
      Where a genuine meta-specific entry is found, add `"/meta"` to its `commands` in the same
      edit. Record the per-entry decision.
- [x] **The one nvim entry** carrying `"meta"`: it also carries other hooks, so it falls in *(completed)*
      class 1 — drop `"meta"`, change nothing else.
- [x] Assert no entry was left with all hooks empty by this trim. If one appears, it means an *(completed)*
      entry's only hook really was `"meta"` and Phases 5-6 missed it — halt and record rather
      than papering over it with `on_demand`.

**Timing**: 1.25 hours

**Depends on**: 6

**Verification Tier**: interface

**Scope Hypothesis**: 61 core entries plus 1 nvim entry carry `"meta"` at this point (the
original 86 core minus the 25 meta-only entries already handled in Phases 5-6). Re-derive both
counts from the files immediately before editing; if they are not 61 and 1, the earlier phases did
not do what they claimed and this phase must halt.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - 61 entries' `task_types` arrays
- `agent-system/extensions/nvim/index-entries.json` - 1 entry's `task_types` array (Scope Expansion)

**Verification**:
- `jq empty` passes on both; core entry count still 136, nvim still 24.
- Count of entries containing `"meta"` in `task_types` is **0** across every extension's `index-entries.json` — checked repo-wide, not only in core. This is work item 2 complete.
- Count of all-hooks-empty entries is still exactly 6 (the marked ones), i.e. the trim created no new orphans.
- `meta-builder-agent`'s resolved-context adaptive query (`always` OR `agents` OR `task_types` OR `commands: /meta`) against the reconstructed index returns approximately **57 entries / ~16,600 lines**, down from 93 / 26,987 — the ~38% reduction. Record the exact measured pair.
- Harness run: every capped-agent token value **byte-identical to Phase 6**, including `meta-builder-agent` still at 130,360. This identity is the phase's most important assertion: it is the direct empirical proof that the trim moves resolved context without moving the validator's per-agent number, exactly as the research predicted. A change here would mean the validator reads `task_types` after all and the plan's whole model is wrong.
- Violations still **8**; exit 1.

**Measured results:**

| Assertion | Predicted | Measured |
|-----------|-----------|----------|
| core meta-tagged before trim | 61 | 61 (49 class 1 + 12 class 2) |
| nvim meta-tagged before trim | 1 | 1 |
| `"meta"` in `task_types` repo-wide after | 0 | 0 (checked across all 19 extensions, not only core) |
| all-hooks-empty entries after | 6, all `on_demand` | 6, all `on_demand: true` — trim created no orphans |
| per-agent block vs Phase 6 | byte-identical | byte-identical |
| `meta-builder-agent` resolved context | ~57 entries / ~16,600 lines | **54 entries / 16,634 lines** (from 93 / 26,987 = **38.4%** reduction) |

Class 2 per-entry decision (all 12): `"meta"` dropped, `/meta` added to **none**. Each of the 12
already carries a command hook reaching its real consumer (`/task`, `/todo`, `/errors`,
`/fix-it`, `/orchestrate`, `/research,/plan,/implement`), and all 12 are task-management, state,
or orchestration infrastructure rather than system-builder material. The two closest calls were
`repo/self-healing-implementation-details.md` and `reference/orchestrator-critical-paths.json`
(both touch system self-modification), but each is already hooked to the command that actually
consumes it — `/errors,/fix-it` and `/orchestrate` respectively — so neither needed `/meta`.

The entry count landed at 54 rather than the estimated ~57 because G6's three entries
(`routing.md`, `validation.md`, `reference/workflow-diagrams.md`) became deliberately hookless
`on_demand` entries in Phase 6 and so leave the resolved set entirely. The line total (16,634 vs
~16,600 predicted) confirms the estimate was sound.

---

### Phase 8: Final gate, delta accounting, and bar attestation [NOT STARTED]

**Goal**: Confirm the chosen bar row by row against the recorded baseline, and hand the operator
an unambiguous statement of what remains and why.

**Tasks**:
- [ ] Run the harness one final time; capture to `specs/991_meta_catchall_decomposition/final-validator.txt`.
- [ ] Produce a side-by-side delta table (baseline vs final) covering every row of the chosen bar,
      and confirm each required result. Any mismatch is a failure, not a note.
- [ ] Re-run the guard checks: `bash -n` on the validator; `grep -c '\.tier'` returns 0;
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`;
      `bash agent-system/extensions/core/scripts/check-task-references.sh` if available, since
      this task edits deliverable trees outside `specs/**`.
- [ ] Confirm `CAPS` and `EXCEPTIONS` are unchanged from the baseline (`git diff` on the validator
      must show no hunk touching either table).
- [ ] Write the summary's "remaining violations" section: 8 per-agent budget overruns, each named
      with its baseline and final token value, and an explicit statement that two of them
      (`general-implementation-agent`, `planner-agent`) increased by the predicted, documented
      amounts and the other six are untouched by this work.
- [ ] Record the two follow-ups surfaced but not done: triaging the 49 Double-Loading warnings,
      and authoring the tier-semantics context file.
- [ ] State the operator's post-implementation step explicitly: redeploy (`<leader>al` ->
      `[Reload All]`, or the sanctioned headless path invoked by the operator), then run
      `bash .claude/scripts/validate-context-budgets.sh` and confirm it matches
      `final-validator.txt`. **The implementer must not run the redeploy.**

**Timing**: 0.75 hours

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: The final state is asserted to be exactly 8 violations, all per-agent
budget, with `general-implementation-agent` at 68,560 and `planner-agent` at 31,848. Confirm by
diffing `final-validator.txt` against `baseline-validator.txt` and checking every changed line is
accounted for by a phase's stated prediction.

**Files to modify**:
- `specs/991_meta_catchall_decomposition/final-validator.txt` - new recorded final state

**Verification**:
- Every row of the "chosen bar" table in this plan is satisfied.
- `diff baseline-validator.txt final-validator.txt` shows only: the Tier Classification section (now OK with a distribution), the Dead Entry section (now OK), the Double-Loading section (now a 49-entry warning), the two predicted per-agent increases, and the violation count 10 -> 8.
- No unexplained line appears in that diff.

## Testing & Validation

Implementer-run (every one is a phase gate above; repeated here as the consolidated checklist):

- [ ] Harness reproduces the deployed baseline exactly before any edit (Phase 1).
- [ ] `grep -c '\.tier' agent-system/extensions/core/scripts/validate-context-budgets.sh` returns 0.
- [ ] `bash -n agent-system/extensions/core/scripts/validate-context-budgets.sh` passes.
- [ ] `jq empty` passes on all four edited JSON files, with entry counts: core 136, nvim 24, cslib +1.
- [ ] Meta-only entry count: 25 -> 0.
- [ ] Entries containing `"meta"` in `task_types`, repo-wide: 87 -> 0.
- [ ] All-hooks-empty entries: 3 -> 6, every one carrying `on_demand: true`.
- [ ] Dead Entry Check negative test passes (unmark one entry -> 1 violation -> restore).
- [ ] Broken-agent-name detection returns empty.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` shows no new Rule T findings.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` passes (this task edits deliverable trees outside `specs/**`).
- [ ] `CAPS` and `EXCEPTIONS` unchanged (`git diff` shows no hunk on either).
- [ ] Final harness run: 8 violations, exit 1, matching the chosen bar table row for row.

Operator-run, after implementation (explicitly **not** implementer steps):

- [ ] Redeploy the `.claude/` tree (`<leader>al` -> `[Reload All]`, or `deploy-headless.sh`
      invoked deliberately by the operator).
- [ ] `bash .claude/scripts/validate-context-budgets.sh` — output must match `final-validator.txt`
      apart from the `Index:` path line. This is the bar's literal command, run at the one point
      in the lifecycle where it is meaningful.
- [ ] `bash .claude/scripts/validate-context-budgets.sh --verbose` — spot-check that per-entry
      lines now print real derived tiers instead of `Tier ?`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-context-budgets.sh` — `derived_tier` function; four converted call sites; Dead Entry Check keyed on `on_demand`; Double-Loading restated as a warning.
- `agent-system/extensions/core/index-entries.json` — 25 entries rehooked, 6 marked `on_demand`, 61 trimmed of `"meta"`, 1 entry's broken agent names removed.
- `agent-system/extensions/core/context/index.schema.json` — `on_demand` property; extended entry `$comment`.
- `agent-system/extensions/cslib/index-entries.json` — mirror entry for `contracts/adversarial-verification.md`.
- `agent-system/extensions/nvim/index-entries.json` — one `task_types` array trimmed.
- `specs/991_meta_catchall_decomposition/shadow-validate.sh` — reusable verification harness (task artifact).
- `specs/991_meta_catchall_decomposition/baseline-validator.txt`, `final-validator.txt` — before/after records.
- Implementation summary recording the 8 remaining violations, the two documented increases, and the two follow-ups.

## Rollback/Contingency

**Rollback unit is the phase.** Every phase produces a scoped commit, so `git revert` of a single
phase's commit restores the prior state without disturbing the others. The dependency chain runs
one direction only, so reverting phase N implies reverting N+1..8 as well — revert in reverse
order.

**Nothing deployed is at risk.** All edits target `agent-system/extensions/**`; `.claude/` is a
gitignored, regenerable artifact and is never written by this task. A botched implementation
therefore cannot corrupt a running deploy — the worst case is that the next redeploy propagates a
bad `index-entries.json`, which the operator's post-implementation validator run catches before
anything depends on it.

**Per-phase contingencies**:

- *Phase 1 harness cannot reproduce the deployed baseline* (path-set diff non-empty, duplicate
  paths, or output mismatch). **Stop the task.** Do not proceed on an unproven instrument. Record
  the divergence — the likely causes are a newly activated extension or a genuinely duplicated
  path, both of which are findings in their own right and change the plan's numbers.
- *Phase 2 conversion breaks the validator* (`bash -n` fails, or output shape changes
  unexpectedly). Revert the single file; the four call sites are independent, so re-do them one
  at a time with a harness run between each.
- *Phase 3 cslib entry cannot be validated* (schema disagreement, or a pre-existing cslib entry
  for the path). Keep the core removal — it is correct on its own — and record the cslib mirror
  as unfinished rather than guessing at a shape. A core entry naming an absent agent is the
  defect being fixed; an absent cslib entry is a lesser, recorded gap.
- *Phase 4 schema change rejected* by any consumer. Fall back to leaving the Dead Entry Check
  exactly as Phase 2 left it (reporting 3 violations) and record the tautology as unresolved. Do
  **not** resolve it by deleting the three entries, and do **not** resolve it by reverting to an
  authored `tier` field — the schema `$comment` forbids the latter explicitly.
- *Phases 5-6 produce an unpredicted capped-agent delta.* Revert the phase and re-derive the
  group's line total from the files before re-applying. An unexplained delta means the group
  membership or a line count is wrong, and proceeding would corrupt the Phase 8 accounting.
- *Phase 7 leaves an entry with all hooks empty.* Revert the phase. This means Phases 5-6 missed
  a meta-only entry; fix it there, not by marking the orphan `on_demand`.
- *Phase 8 diff contains an unexplained line.* Do not close the task. Trace the line to its phase
  and either revert that phase or amend the plan's prediction with a written justification. An
  unexplained delta at the final gate is exactly the failure this plan's per-phase predictions
  exist to prevent.

**Total-abandonment path**: revert Phases 2-8's commits in reverse order. Phase 1's artifacts are
additive task-directory files and can be left in place; the harness has standalone value for any
future context-index work.

