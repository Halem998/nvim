# Implementation Plan: Task #859

- **Task**: 859 - Fix generate-task-order.sh: dependency tree renders flat for non-lowercase topic strings (topic-key case mismatch)
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/859_fix_task_order_topic_case_indentation/reports/01_topic-standardization.md
- **Artifacts**: plans/01_topic-normalization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The origin bug (dependency tree renders flat for any topic whose stored string is not already
lowercase) is one symptom of a single structural root cause: there is no canonical-form
normalization anywhere in the topic subsystem. The write chokepoint (`manage-topics.sh`) stores
topics with exact case-sensitive matching and zero normalization, and the render/read guards in
`generate-task-order.sh` compare a locally-lowercased grouping key against the raw stored topic
string. This plan introduces exactly ONE normalization helper — `normalize_topic()`, canonical
form lowercase kebab-case — and routes every write-time store and every read-time comparison
through it, eliminating scattered ad-hoc `${var,,}` lowercasing. The same helper fixes the origin
bug, the separator duplicate-heading risk, and forward-prevents new collisions in one consistent
change. The plan is deliberately scoped to the six genuine gaps identified by research; existing
infrastructure (the Mode A/B/C interactive topic-assignment system and `manage-topics.sh` as the
state-mutation chokepoint) is REUSED, not rebuilt.

### Research Integration

Key findings from `reports/01_topic-standardization.md` shaping this plan:
- The origin bug is confirmed at `.claude/extensions/core/scripts/generate-task-order.sh` lines
  553 and 578 (and mirrored at `.opencode/scripts/generate-task-order.sh` lines 481 and 506). The
  `.claude/` core source is the source of truth; the deployed `.claude/scripts/generate-task-order.sh`
  is regenerated from it.
- The write-side topic-assignment system (Mode A interactive / B inherit / C suggest, documented in
  `.claude/context/patterns/topic-assignment-pattern.md`, enforced via `manage-topics.sh`) already
  satisfies mandate items 1 and 2 for interactive callers — it must be reused, not re-created.
- The genuine gap is canonical-form normalization: `manage-topics.sh` (`add`/`set`/`validate`) does
  exact case-sensitive `jq index($t)` matching (lines 73-78, 120-126, 151-153); the canonical form
  (lowercase kebab-case) lives only as a UI hint string, never enforced.
- The `.opencode/` renderer is actually MORE broken than `.claude/`: its grouping key does no
  normalization at all (raw `[[ "$tp" == "$topic" ]]` at line 393), so the shared-normalizer fix
  makes the two renderers behaviorally identical.
- This repository's own `active_topics` are already clean lowercase kebab-case (Finding 8), so NO
  data migration is required locally — only a verification/fixed-point confirmation step.
- Autonomous-context fallback for topic assignment is undefined (no `orchestrator_mode` path),
  unlike the `--lit` flag's `AUTONOMOUS_GLOBAL` deterministic-default pattern; currently latent but
  the mandate asks for it. Keep the fix minimal (a documented directive).
- The schema reference (`state-management-schema.md`) documents neither `topic` nor `active_topics`
  despite both being mandatory.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (no `roadmap_path` provided). No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Introduce a single canonical `normalize_topic()` helper (lowercase kebab-case) and make it the
  spine of the change — reused at both the write chokepoint and every read/render comparison.
- Fix the origin renderer bug so the dependency tree renders with `└─` indentation for any topic
  regardless of stored casing, and collapse case/separator variants into a single heading.
- Keep the two renderers (`.claude/` core source and `.opencode/`) behaviorally identical.
- Enforce canonical form at write time in `manage-topics.sh` so new collisions cannot enter
  `active_topics`.
- Add a minimal deterministic-default autonomous-context directive for topic assignment.
- Document the mandatory `topic` field and `active_topics` array in the schema reference.
- Confirm (not migrate) that this repository's existing topic data is already canonical.

**Non-Goals**:
- Rebuilding the existing Mode A/B/C topic-assignment picker or `manage-topics.sh` chokepoint
  (already comprehensive — reuse only).
- Porting the write-side topic-assignment system to `.opencode/` (`.opencode/` has no
  `manage-topics.sh`, no `topic-assignment-pattern.md`, no `/task` Step 4.5). This is flagged as a
  separate follow-up, explicitly out of scope here (see Phase 3).
- Any data migration of `specs/state.json` (Finding 8: no variants exist locally — verification
  only; the real state.json must remain byte-unchanged by this work).
- Rewiring `/spawn`, `/fix-it`, or `/review` callers for autonomous execution (the gap is latent;
  Phase 4 is a documented directive only).
- Removing or "fixing" any pre-existing task-number citation already present in the scripts
  (e.g. the `task 796` comment at core line 499) — out of scope; do not add NEW ones.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A shared sourced library across `.claude/scripts/`, `.claude/extensions/core/scripts/`, and `.opencode/scripts/` adds deployment/regeneration complexity and cannot cross the `.opencode/` tree | M | H | Do NOT create a sourced lib. Define `normalize_topic()` as one self-contained function and embed a byte-identical, clearly-marked "keep in sync" copy in each of the (at most three) scripts. Within each script there is exactly one definition and every call routes through it. |
| Editing only the core source leaves the deployed `.claude/scripts/generate-task-order.sh` stale, so verification via `generate-todo.sh` tests old code | H | M | In Phase 2, apply the identical change to the deployed copy as well (or trigger its regeneration), and note the core source is authoritative on next extension load. Verify against the deployed copy that `generate-todo.sh` actually invokes. |
| Tests accidentally mutate the real `specs/state.json` | H | M | All renderer/write tests operate on a COPY of state.json in the scratchpad or `specs/tmp/`, never the live file. Phase 6 asserts `git diff specs/state.json` shows no topic-data change. |
| Write-time normalization silently changes a user's typed topic (e.g. `Modal Logic` -> `modal-logic`) | L | M | This matches the already-documented hint-text intent and is strictly better than silent collisions; document the behavior in the schema note (Phase 5). Surfacing the normalized value in the picker confirmation is a caller concern, out of scope here. |
| Task-number citation leaking into a deliverable file outside `specs/**` | M | L | Every doc/script phase includes an explicit MUST-NOT: no `task 859` (or any task-number) reference in `normalize_topic()` comments, `topic-assignment-pattern.md`, or `state-management-schema.md`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 5 | -- |
| 2 | 2, 3 | 1 |
| 3 | 6 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Define canonical `normalize_topic()` and enforce at the write chokepoint [COMPLETED]

**Goal**: Establish the single normalization helper (the spine of the whole change) and apply it in
`manage-topics.sh` so every stored topic and every `active_topics` entry is canonical at write time.

**Canonical form**: lowercase kebab-case — lowercase, runs of whitespace/underscores collapsed to a
single `-`, repeated `-` collapsed, leading/trailing `-` trimmed. This matches the existing hint
text and every current `active_topics` value; it is enforced, not merely suggested.

**Reference implementation** (implementer may refine but must keep it a single self-contained idiom;
this exact block is copied byte-identical into Phases 2 and 3):

```bash
# normalize_topic: canonical topic form (lowercase kebab-case).
# CANONICAL DEFINITION -- keep byte-identical across manage-topics.sh and both
# generate-task-order.sh copies (core extension + .opencode). No task-number references.
normalize_topic() {
  local t="${1,,}"
  t="${t//_/-}"
  t="$(printf '%s' "$t" | tr -s '[:space:]' '-')"
  t="$(printf '%s' "$t" | tr -s '-')"
  t="${t#-}"; t="${t%-}"
  printf '%s' "$t"
}
```

**Tasks**:
- [x] Add the `normalize_topic()` function block to `.claude/scripts/manage-topics.sh` (near the top,
      after path resolution). *(completed)*
- [x] In the `add` subcommand (lines 65-91): normalize `TOPIC` via `TOPIC="$(normalize_topic "$TOPIC")"`
      before the `jq --arg t "$TOPIC"` call so both the membership test and the stored value are canonical. *(completed)*
- [x] In the `set` subcommand (lines 96-139): normalize `TOPIC` the same way before the `jq` call that
      sets `.topic` and appends to `active_topics`. *(completed)*
- [x] Decide and document (a one-line comment) whether `validate` (lines 144-160) normalizes its input
      before comparison; recommend YES so `validate "Modal Logic"` matches a stored `modal-logic`. *(completed: normalizes before comparison)*
- [x] Do NOT add any task-number reference in the new comments. *(completed: verified, no task-number refs)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/manage-topics.sh` - add `normalize_topic()`; normalize in `add`/`set` (and
  `validate` per decision) before the jq matching calls.

**Verification**:
- Copy `specs/state.json` to a scratch fixture. Run `manage-topics.sh add "Modal Logic"` against the
  fixture (via a temporary `STATE_FILE` override or a copied checkout) and confirm `active_topics`
  gains `modal-logic`, not `Modal Logic`.
- Run `add "modal_logic"` and `add "modal-logic"` on the fixture and confirm they do not create new
  entries (idempotent under normalization — a single `modal-logic`).
- Run `set <task> "Code Hygiene"` on the fixture and confirm the task's `topic` is stored as
  `code-hygiene`.
- Confirm the real `specs/state.json` is untouched (`git diff` clean).

---

### Phase 2: Fix the origin renderer via the shared normalizer (core extension source) [NOT STARTED]

**Goal**: Route the renderer's grouping key and both comparison guards through `normalize_topic()`
so the tree renders correctly for any casing and case/separator variants collapse into one heading.

**Tasks**:
- [ ] Add the byte-identical `normalize_topic()` block (from Phase 1) to
      `.claude/extensions/core/scripts/generate-task-order.sh`.
- [ ] Replace the ad-hoc grouping-key lowercasing with `normalize_topic` calls:
      line 430 (`local t_key="${t,,}"`), line 441 (`local tp_key="${tp,,}"`), and the membership
      test at line 456 (`[[ "${tp,,}" == "$topic" ]]`) — so the grouping key is the fully canonical
      form (collapsing `-`/space/underscore variants, not just case). This alone removes the
      duplicate-heading risk (`Modal Logic` vs `modal-logic` collapse to one section).
- [ ] Fix the two comparison guards so both sides are normalized:
      line 553 (`"$task_topic_val" != "$_current_section_topic"`) and
      line 578 (`"$dep_topic" != "$_current_section_topic"`). Because `_current_section_topic` is
      set from the already-canonical grouping key (line 470), normalize the right-hand raw value:
      compare `"$(normalize_topic "$dep_topic")"` / `"$(normalize_topic "$task_topic_val")"` against
      `_current_section_topic`. After this, `!=` is correct without special-casing.
- [ ] Keep the deployed `.claude/scripts/generate-task-order.sh` in sync: apply the identical change
      to it (or trigger its regeneration from the core source), since `generate-todo.sh` invokes the
      deployed copy. Note in a comment that the core extension source is authoritative on load.
- [ ] Do NOT add any task-number reference in new comments; do not touch the pre-existing `task 796`
      comment at line 499.

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/scripts/generate-task-order.sh` - add helper; normalize grouping key
  (430, 441, 456) and guards (553, 578).
- `.claude/scripts/generate-task-order.sh` - mirror the identical change (deployed copy) for
  immediate verification.

**Verification**:
- Build a fixture state.json (scratchpad copy) containing a Title-Case topic (`"Modal Logic"`) on a
  small intra-topic dependency chain (e.g. 491->495->496->484 as in the task description), plus a
  second task stored as `"modal-logic"` in the same logical topic.
- Run the renderer against the fixture (`generate-task-order.sh --print` with `STATE_FILE` pointed at
  the fixture, or `generate-todo.sh` on a copied checkout) and confirm: (a) `└─` indentation appears
  under a single `### Modal Logic` heading; (b) there is exactly ONE `### Modal Logic` heading (no
  duplicate from the separator variant).
- Confirm the real `specs/state.json` and live `specs/TODO.md` are not left mutated by the test.

---

### Phase 3: Mirror the renderer fix to `.opencode/` (render-side parity only) [NOT STARTED]

**Goal**: Make `.opencode/scripts/generate-task-order.sh` behaviorally identical to the `.claude/`
renderer by applying the same normalizer; explicitly scope out `.opencode/` write-side parity.

**Tasks**:
- [ ] Add the byte-identical `normalize_topic()` block to `.opencode/scripts/generate-task-order.sh`.
- [ ] Normalize the grouping key: the `.opencode/` renderer currently does NO normalization
      (raw `topics_to_render+=("$t")` at 368/380 and `[[ "$tp" == "$topic" ]]` at line 393). Route
      these through `normalize_topic` so grouping matches `.claude/` behavior.
- [ ] Fix the two guards: line 481 (`"$task_topic_val" != "$_current_section_topic"`) and
      line 506 (`"$dep_topic" != "$_current_section_topic"`) by normalizing both sides, exactly as in
      Phase 2.
- [ ] Add a short, explicit comment (in the plan summary and optionally the script header) recording
      that `.opencode/` write-side topic-assignment parity (no `manage-topics.sh`, no
      `topic-assignment-pattern.md`, no `/task` topic step) is OUT OF SCOPE for this task and is a
      recommended follow-up — do NOT silently skip it, flag it.
- [ ] Do NOT add any task-number reference to `.opencode/` deliverable files.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/scripts/generate-task-order.sh` - add helper; normalize grouping key (368/380/393) and
  guards (481, 506).

**Verification**:
- Run BOTH renderers (`.claude/scripts/generate-task-order.sh --print` and
  `.opencode/scripts/generate-task-order.sh --print`) against the SAME fixture state.json and `diff`
  the Grouped-by-Topic sections — confirm they are identical (same headings, same `└─` indentation).
- Confirm the follow-up note for `.opencode/` write-side parity is present (surfaced in the summary),
  not silently omitted.

---

### Phase 4: Autonomous-context deterministic-default directive for topic assignment [COMPLETED]

**Goal**: Add a minimal deterministic-default fallback so a future autonomous task-creation path
never dead-ends on `AskUserQuestion`, mirroring the `--lit` flag's `AUTONOMOUS_GLOBAL` pattern.

**Tasks**:
- [x] In `.claude/context/patterns/topic-assignment-pattern.md`, add a short "Autonomous Context"
      subsection: when `orchestrator_mode == true`, callers MUST NOT invoke `AskUserQuestion`. The
      deterministic default is: (1) inherit the parent topic if one exists (Mode B), else (2) apply
      the Mode C path heuristic if it resolves, else (3) assign a documented sentinel/leave
      unassigned and emit a visible `[topic:auto]` notice to the transcript. This is never a silent
      no-op — mirror the `[lit:auto]` notice contract. *(completed)*
- [x] Keep it a documented directive only (the gap is latent — no autonomous caller reaches the
      picker today, per Finding 5). Do NOT rewire `/spawn`, `/fix-it`, or `/review`. *(completed: directive only, no callers rewired)*
- [x] Cross-reference the `--lit` `AUTONOMOUS_GLOBAL` directive by durable anchor (its section name),
      not by any task number. *(completed)*
- [x] Do NOT add any task-number reference. *(completed: verified clean)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/patterns/topic-assignment-pattern.md` - add the Autonomous Context subsection.

**Verification**:
- `grep -n "orchestrator_mode" .claude/context/patterns/topic-assignment-pattern.md` returns the new
  directive; confirm it names a deterministic default AND a visible notice, and explicitly forbids
  `AskUserQuestion` in the autonomous path.

---

### Phase 5: Document `topic` and `active_topics` in the schema reference [COMPLETED]

**Goal**: Close the schema documentation gap so both mandatory fields are documented, including the
canonical form and its write-time enforcement.

**Tasks**:
- [x] In `.claude/context/reference/state-management-schema.md`, add a `topic` row to the "Project
      Entry Fields" table (string; the canonical topic, lowercase kebab-case; maintained via
      `manage-topics.sh`; normalized at write time). *(completed)*
- [x] Add `active_topics` to the "state.json Full Structure" JSON example (top-level array) and add a
      short `active_topics` subsection: top-level array, canonical form lowercase kebab-case,
      maintained exclusively through `manage-topics.sh`, normalized on write so case/separator
      variants cannot diverge. *(completed: added Topic Fields subsection)*
- [x] Note the canonical form once, authoritatively, and reference `manage-topics.sh` by filename
      (durable anchor). Do NOT add any task-number reference. *(completed: verified clean)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - add `topic` field row, `active_topics`
  JSON entry + subsection.

**Verification**:
- `grep -n "active_topics" .claude/context/reference/state-management-schema.md` and
  `grep -n "topic" .claude/context/reference/state-management-schema.md` confirm both are documented
  with the canonical-form (lowercase kebab-case) note.

---

### Phase 6: Local verification — confirm no migration needed and behavior is correct [NOT STARTED]

**Goal**: Confirm (not migrate) that this repository's existing topic data is already canonical and
that the full change leaves `specs/state.json` byte-unchanged, and run the end-to-end render check.

**Tasks**:
- [ ] Write a throwaway verification loop (scratchpad) that runs `normalize_topic` over every entry
      in `active_topics` and every `active_projects[].topic` in the live `specs/state.json` and
      asserts each is already a fixed point (normalize(x) == x) — expecting ZERO differences
      (Finding 8). If any differ, STOP and report (would indicate a migration is actually needed).
- [ ] Run `bash .claude/scripts/generate-todo.sh` against the real repo and confirm the live
      Grouped-by-Topic tree still renders correctly (existing all-lowercase topics unaffected) and
      `specs/TODO.md` regenerates cleanly.
- [ ] Confirm `git diff specs/state.json` shows no topic-data change attributable to this work (all
      fixture testing used copies).
- [ ] Record in the summary that migration scope for this repository is zero tasks (verification
      only), and that the fix is preventive/structural, landing in the shared core source for other
      repos.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only). Fixtures live in the scratchpad; `specs/state.json` must not change.

**Verification**:
- The fixed-point loop reports zero non-canonical values in live state.json.
- `generate-todo.sh` regenerates `specs/TODO.md` without error and the tree renders correctly.
- `git diff specs/state.json` is clean of topic-data mutations.

## Testing & Validation

- [ ] `manage-topics.sh add`/`set` store canonical (lowercase kebab-case) values; variants of the
      same topic collapse to one `active_topics` entry (Phase 1).
- [ ] Origin bug fixed: a Title-Case topic renders with `└─` indentation under a single heading;
      case/separator variants collapse to one section (Phase 2).
- [ ] `.claude/` and `.opencode/` renderers produce identical Grouped-by-Topic output on the same
      fixture (Phase 3).
- [ ] `topic-assignment-pattern.md` documents an autonomous deterministic-default directive with a
      visible notice and no `AskUserQuestion` (Phase 4).
- [ ] `state-management-schema.md` documents `topic` and `active_topics` with canonical form (Phase 5).
- [ ] Live `specs/state.json` topic data is an unchanged fixed point under `normalize_topic`; no
      migration performed (Phase 6).
- [ ] No task-number references introduced in any deliverable file outside `specs/**`.

## Artifacts & Outputs

- `.claude/scripts/manage-topics.sh` (helper + write-time normalization)
- `.claude/extensions/core/scripts/generate-task-order.sh` (helper + normalized grouping/guards)
- `.claude/scripts/generate-task-order.sh` (deployed mirror kept in sync)
- `.opencode/scripts/generate-task-order.sh` (mirrored renderer fix)
- `.claude/context/patterns/topic-assignment-pattern.md` (autonomous-context directive)
- `.claude/context/reference/state-management-schema.md` (schema documentation)
- `specs/859_fix_task_order_topic_case_indentation/summaries/01_topic-normalization-summary.md`
  (execution summary, including the `.opencode/` write-side follow-up flag)

## Rollback/Contingency

All changes are additive helper functions plus in-place comparison/grouping edits across six files;
no state data is migrated. To revert, `git checkout` the six modified files. Because `specs/state.json`
is intentionally never mutated by this work, there is no data rollback to perform. If the deployed
`.claude/scripts/generate-task-order.sh` diverges from the regenerated core source after a future
extension load, re-run the extension load/regeneration — the core extension source is authoritative.
