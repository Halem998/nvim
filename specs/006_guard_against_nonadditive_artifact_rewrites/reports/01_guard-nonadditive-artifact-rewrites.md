# Research Report: Task #6

**Task**: 6 - guard_against_nonadditive_artifact_rewrites
**Started**: 2026-08-10T22:24:00Z
**Completed**: 2026-08-10T22:50:00Z
**Effort**: N/A (research phase)
**Dependencies**: 5 (unrelated to this guard — the roadmap_items producer chain; no code overlap found)
**Sources/Inputs**: Codebase exploration (declared file-scope files plus their direct callers/consumers)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The four sanctioned writers (`skill_link_artifacts` in `skill-base.sh`, `orchestrator-postflight.sh`
  Stage 8, `link_artifact` in `reconcile-task-status.sh`, and `skill-reviser/SKILL.md` Stage 8) are
  **not literally append-only today** — every one of them runs a documented two-step
  remove-then-add pattern that deletes *all* existing artifacts of the same `type` before adding
  one new entry. This is intentional "keep the latest report/plan/summary pointer" behavior, not a
  bug, and it is the same pattern taught as the reference idiom in
  `context/patterns/inline-status-update.md`. Any invariant design that naively demands "every path
  present beforehand must still be present" will make every one of these routine, sanctioned calls
  fail — which directly conflicts with the verification bar's "existing `link_artifact` /
  `skill_link_artifacts` call sites are unaffected."
- The recommended invariant is therefore **per-type, not per-path**: for every distinct `.type`
  value, the count of paths *removed* by a write must not exceed the count of paths *added* of
  that same type in the same write. This single rule (a) is a no-op for first-time links (0
  removed, 1 added), (b) permits the routine 1-for-1 report/plan/summary supersession (1 removed, 1
  added), and (c) rejects the exact shape of the observed incident (5 removed, 2 added nets a
  loss) — without needing any call site to change.
- `validate-state.sh`'s existing `--deep` Check D4 (terminal-status immutability, lines 364-404)
  already establishes the needed mechanism: fetch the prior git-committed version of `state.json`
  via `git show <sha>:./<path>` and diff specific fields against the live file. A new `--deep`
  check (D5) can reuse that same `prior_json` variable to diff `.artifacts` per `project_number`,
  which is exactly the design the task asks for ("catches drift regardless of writer, including
  direct jq") — it inspects the file's content, not the call path that produced it, so it applies
  identically to `state-write.sh` traffic, hand-rolled `jq ... > tmp && mv`, and anything else.
- `state-write.sh` and `context/schemas/state-schema.json` are **not** in this task's declared file
  scope, and no change to either is required by the recommended design — the check lives entirely
  in `validate-state.sh` (content-inspection) plus documentation/comment updates in `skill-base.sh`,
  `rules/state-management.md`, and `general-implementation-agent.md`.

## Context & Scope

Researched: the four sanctioned artifact-writing call sites, the two files that would host a new
invariant check (`skill-base.sh`, `validate-state.sh`), where `validate-state.sh --deep` is
actually invoked in the pipeline (so "enforcement" has teeth), and the existing prior-commit-diff
mechanism (`--deep` Check D4) as a structural precedent to extend rather than reinvent.

Out of scope per the task's `SOURCE-STORE RULE`: this report proposes no changes outside
`agent-system/extensions/**`, and cites no task numbers outside `specs/**`.

## Findings

### Codebase Patterns

**1. All four sanctioned writers use the same two-step "remove-same-type, then add" idiom**, not a
pure append:

- `agent-system/extensions/core/scripts/skill-base.sh:562-593` (`skill_link_artifacts`) — Step 1
  filters out all `.artifacts[]` entries with the incoming `$atype`; Step 2 does
  `.artifacts += [{"path":...,"type":...,"summary":...}]`.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh:412-434` (Stage 8) — identical
  two-step shape against `$artifact_type_from_meta`.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:141-186` (`link_artifact`) —
  identical two-step shape, plus an `artifact_already_linked` idempotency guard (line 130) that
  short-circuits if the exact path is already present.
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md:352-368` (Stage 8, plan revision) —
  identical two-step shape, hardcoded to `type == "plan"`.
- The reference idiom document, `context/patterns/inline-status-update.md` (lines 94-100,
  122-128, 150-156), teaches exactly this pattern for research/plan/summary postflight, explicitly
  labeled "Add artifact (avoids jq escaping bug)" — it is the documented *safe* way to link an
  artifact, and it removes a path every time a same-type artifact already exists.

**Why this exists**: research/plan/summary are "latest pointer" slots. When `/research` is re-run
on an already-researched task, or `/revise` produces a new plan version, the old
same-type artifact's *link* is superseded (its type: `report`/`plan`/`summary`) — the underlying
file stays on disk untouched, only the state.json pointer moves to the newer artifact. This is
corroborated by `context/patterns/artifact-linking-todo.md`'s parameterization table (research /
plan / summary, one `field_name` each) and by `context/schemas/state-schema.json`'s
`memory_candidates` field description, which explicitly says "append-only during the task
lifecycle" as a *contrast* — that phrasing exists precisely because `artifacts` is *not* documented
as append-only anywhere today, confirming the task's premise that the rule is real but
unenforced and unstated.

**2. The observed incident's shape (11→8, five dropped, two added) is inconsistent with a single
legitimate same-type supersession**, which is always a 1-for-1 replace under every sanctioned call
site above. A per-type "removed ≤ added" rule flags this precisely: whichever `type` absorbed the
net loss (`removed(T) > added(T)`) fails, while every routine 1-for-1 or 0-for-N (pure add) call
passes untouched. A stricter *global path-superset* rule (no removal ever, except an explicit
opt-in) would also catch the incident, but it would additionally require every one of the four
sanctioned call sites above to be modified to pass some new opt-in on every single routine
supersession call — which the verification bar explicitly rules out ("existing … call sites are
unaffected").

**3. `validate-state.sh --deep` Check D4 (terminal-status immutability, lines 364-404) is the
directly reusable precedent** for a content-inspection, writer-agnostic invariant:
- It resolves `state_dir` and the sibling `STATE_FILE`'s git history (`git -C "$state_dir" log -1
  --format=%H -- "$rel_path"`), reads the prior committed JSON via `git show
  "${prior_commit}:./${rel_path}"` into `prior_json`, and diffs specific per-entry fields between
  `prior_json` and the live file, keyed on `project_number`.
- It is **WARN-level**, not FAIL-level — a deliberate best-effort choice (line header comment:
  "best-effort... skipped when STATE_FILE is not inside a git work tree or has no prior committed
  version"). A new artifact-loss check should likely be **FAIL-level** instead, since silent
  artifact loss is exactly the concrete, already-observed harm this task exists to prevent (unlike
  D4's more speculative terminal-status-mutation scenario) — this is a design decision for the
  planner, not settled by precedent alone.
- Reusing the *same* already-computed `prior_json` (rather than a second `git show` call) keeps a
  new D5 check cheap and consistent with D4's existing pattern for finding "the prior committed
  artifacts array."

**4. `validate-state.sh --deep` is currently wired as Gate 10 of
`agent-system/extensions/core/scripts/verify-deploy.sh` (lines 453-476)**, run against the
deployed tree's live `specs/state.json`. This is the only automated caller found in the codebase
(`grep -rln "validate-state.sh"` matches only `manifest.json`, the test suite, `verify-deploy.sh`,
and the script itself). This means today the check is **periodic** (whenever `verify-deploy.sh`
runs, e.g. on deploy) rather than **synchronous** (blocking the offending write itself, the way a
PreToolUse hook or `state-write.sh`-internal check would be). This periodic cadence is consistent
with D4's own "best-effort" framing and is the natural fit for a content-inspection check that must
work regardless of which writer produced the file — but it is a real trade-off the plan should
name explicitly: a direct-jq write that both drops artifacts *and* is never followed by a
`verify-deploy.sh` run before the next legitimate write (which would move `prior_json`'s baseline
forward) could still slip through undetected. Nothing in the current architecture offers a
synchronous alternative without touching `state-write.sh` (out of this task's declared file scope)
or wiring a new PreToolUse hook (a larger architectural change not implied by the task's WORK
items).

**5. `skill-base.sh` is declared in file scope but no code-level defect was found in
`skill_link_artifacts` itself** — its two-step pattern is exactly the sanctioned, 1-for-1
supersession shape a per-type invariant should permit. The most defensible reason for this file's
inclusion in scope is documentation: a short comment cross-referencing the new append-only rule
(added to `rules/state-management.md` per Work item 3) directly above `skill_link_artifacts`'s
two-step block, explaining *why* this specific removal is safe under the new invariant (same-type,
1-for-1) and warning against generalizing the pattern to a wholesale `.artifacts = [...]`
assignment. This keeps the file "touched" without functionally changing a call site the
verification bar says must stay unaffected.

**6. `general-implementation-agent.md`'s existing `MUST NOT` list (lines 745-752, Critical
Requirements section) already has six numbered bullets** including one for
`no-task-references-in-deliverables.md` (bullet 7) sourced verbatim from a canonical fragment
comment convention. Work item 4's new bullet ("never assign `.artifacts` wholesale; append, or call
the helper") should follow this same numbered-bullet style and — since no direct `.artifacts`
mutation currently appears anywhere in this agent's documented Stages (confirmed by grep: no
`skill_link_artifacts`, `link_artifact`, or `.artifacts =`/`+=` reference anywhere in
`general-implementation-agent.md`) — the bullet is a preventive guard against exactly the kind of
undocumented, improvised jq write the task's "OBSERVED, WITH LOSS" paragraph describes, not a fix
to any currently-documented Stage.

### External Resources

Not applicable — this is a wholly internal machine-state invariant with no external library or
documentation dependency.

### Recommendations

1. **`validate-state.sh`**: add a new `--deep` check (next available letter, likely `D5`) that,
   reusing D4's already-fetched `prior_json`, computes per-`project_number`, per-`.type` path sets
   from `prior_json` and the live file, and FAILs (recommend FAIL-level, diverging from D4's WARN
   precedent — see Finding 3) whenever `removed(T) > added(T)` for any type `T`, unless an
   explicit, named opt-in is supplied. The opt-in should be a new repeatable CLI flag on
   `validate-state.sh` itself (e.g. `--allow-artifact-removal <project_number>[:<type>]`), since
   the writer and the periodic validator are decoupled (Finding 4) — there is no write-time hook to
   attach a per-call opt-in to without touching `state-write.sh`, which is out of scope. A
   CLI-level, human/operator-supplied flag matches "explicit, named opt-in" and keeps the
   legitimate-deletion case expressible without any schema or writer change.
2. **`skill-base.sh`**: add an explanatory comment above `skill_link_artifacts`'s two-step block
   (no functional change) cross-referencing the new rule in `rules/state-management.md` and
   explaining why its own same-type 1-for-1 remove-then-add is exempt by construction under the
   per-type invariant. This satisfies the file's declared scope without touching the four call
   sites the verification bar protects.
3. **`rules/state-management.md`**: add an explicit "Artifacts Are Append-Only (With Supersession)"
   subsection near the existing "File Synchronization" section (which currently only says agents
   "update state.json only" without ever stating the artifacts-list contract). State the rule in
   the same terms as the schema's existing `memory_candidates` precedent ("append-only... during
   the task lifecycle"), name the one sanctioned exception (same-type 1-for-1 supersession, as
   already practiced by every current writer), and point at `validate-state.sh --deep` as the
   enforcement mechanism plus its opt-in flag for genuine deletions.
4. **`general-implementation-agent.md`**: add MUST NOT bullet 8 to the existing numbered list
   (Critical Requirements, lines 745-752): "Never assign `.artifacts` wholesale
   (`.artifacts = [...]`) when updating `specs/state.json` directly — append via `+=`, or call
   `skill_link_artifacts`/the sanctioned helper; see `.claude/rules/state-management.md`'s
   append-only artifacts rule."
5. **Test fixtures**: extend `agent-system/extensions/core/scripts/tests/test-validate-state.sh`
   (existing fixture-driven structural model, PASSED/FAILED counters, `pass()`/`fail()`/`info()`
   helpers) with a new defect fixture pair: (a) a git-committed baseline `state.json` with N
   artifacts, followed by an uncommitted rewrite that drops more paths of one type than it adds —
   asserted FAIL; (b) the same rewrite re-run with `--allow-artifact-removal` — asserted PASS. This
   directly satisfies the verification bar's "both directions executed."

## Decisions

- Recommend a **per-type count invariant** (`removed(T) ≤ added(T)`), not a strict global
  path-superset invariant, because the latter is incompatible with every existing sanctioned call
  site's routine behavior (Finding 1-2) and the task explicitly requires those call sites stay
  unaffected.
- Recommend the check live in **`validate-state.sh --deep`** (content-inspection, writer-agnostic),
  not `state-write.sh` (out of declared file scope and would miss direct-jq writes per the task's
  own stated preference).
- Recommend **FAIL-level**, diverging from D4's WARN precedent, since this task's entire premise is
  a concrete, already-observed data-loss incident rather than a speculative one.
- Recommend the opt-in be a **CLI flag on `validate-state.sh`**, not a new state.json field, since
  the schema file and `state-write.sh` are both outside this task's declared scope and the
  writer/validator are architecturally decoupled (periodic, not synchronous).

## Risks & Mitigations

- **Risk**: `validate-state.sh --deep` only runs via `verify-deploy.sh` (periodic, not per-write) —
  a direct-jq write that drops artifacts could still land before the next validation pass, and if
  a subsequent legitimate write happens (and gets committed) before validation runs, D5's
  `prior_json` baseline moves forward and the loss becomes invisible to a future diff.
  **Mitigation**: name this trade-off explicitly in the plan; if closing it fully is desired, a
  follow-up task could give `state-write.sh` an optional in-process self-check (would require
  expanding file scope) — out of scope for this task as declared.
- **Risk**: A per-type "removed ≤ added" rule cannot distinguish "legitimate 1-for-1 supersession"
  from "one artifact removed and a different, unrelated one coincidentally added of the same type
  in the same commit window" (a same-count false negative). **Mitigation**: accept this as a
  bounded blind spot — the task's stated verification bar is about catching bulk/silent loss (the
  observed 5-dropped/2-added shape), not adversarial 1-for-1 substitution, and the schema's
  `path`-uniqueness plus git history still make such a substitution forensically recoverable.
- **Risk**: FAIL-level (vs. D4's WARN-level) changes `verify-deploy.sh`'s gate 10 from
  "warns but passes" to "blocks deploy" for any task with real historical artifact loss, which
  could surface latent, already-committed corruption in older tasks as a new deploy blocker.
  **Mitigation**: the plan should scope the new check to only run its comparison from the
  *implementation* task's own dependency baseline forward, or accept a one-time triage pass to
  reconcile any pre-existing drift before the check goes live as FAIL-level.

## Context Extension Recommendations

- **Topic**: append-only invariants for `state.json` array fields.
- **Gap**: `context/reference/state-management-schema.md` documents artifact *formats* and
  *numbering* extensively but never states an append-only contract for `.artifacts`; the only
  existing "append-only" language in the whole schema surface is the `memory_candidates` field
  description, which is easy to miss as an implicit precedent.
- **Recommendation**: once this task's rule lands in `rules/state-management.md`, consider a
  follow-up cross-reference from `context/reference/state-management-schema.md`'s `artifacts` field
  row (line 94) pointing at the new subsection, so a future reader consulting the schema reference
  directly (rather than the rules file) also discovers the contract. Not required by this task's
  declared file scope; noted for a future task rather than acted on here.

## Appendix

**Search queries used** (all local codebase, no web search — this is a fully internal
machine-state-invariant task with no external dependency):
- `grep -rln "\.artifacts" agent-system/extensions/core/scripts/*.sh agent-system/extensions/core/agents/*.md agent-system/extensions/core/skills/**/*.md`
- `grep -n "artifacts\s*=\s*\[\|\.artifacts =" -r agent-system/extensions/core --include="*.sh" --include="*.md"`
- `grep -rln "validate-state.sh" agent-system/extensions/core/`
- Direct reads: `skill-base.sh` (lines 553-594), `validate-state.sh` (full file, 427 lines),
  `orchestrator-postflight.sh` (lines 400-460), `reconcile-task-status.sh` (lines 130-200),
  `rules/state-management.md` (full file), `context/schemas/state-schema.json` (lines 200-260),
  `context/patterns/inline-status-update.md` (full file), `context/patterns/artifact-linking-todo.md`
  (lines 1-60), `skill-reviser/SKILL.md` (lines 330-390), `general-implementation-agent.md` (lines
  580-755), `scripts/tests/test-validate-state.sh` (lines 1-40 + grep of test names),
  `scripts/verify-deploy.sh` (lines 453-476).

**References**:
- `agent-system/extensions/core/scripts/skill-base.sh:553-594`
- `agent-system/extensions/core/scripts/validate-state.sh:364-404` (D4, model for new D5)
- `agent-system/extensions/core/scripts/verify-deploy.sh:453-476` (Gate 10, current invocation site)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh:412-434`
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:130-186`
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md:352-368`
- `agent-system/extensions/core/context/patterns/inline-status-update.md`
- `agent-system/extensions/core/context/schemas/state-schema.json:236` (memory_candidates
  append-only precedent language)
- `agent-system/extensions/core/agents/general-implementation-agent.md:745-752` (MUST NOT list)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` (fixture-test structural model)
