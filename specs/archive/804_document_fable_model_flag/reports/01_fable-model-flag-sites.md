# Research Report: Task #804

**Task**: 804 - Document the --fable model-selection flag alongside --haiku, --sonnet, and --opus everywhere the other model flags appear in the agent system
**Started**: 2026-07-04
**Completed**: 2026-07-04
**Effort**: small-medium (documentation-heavy, one code-path fix)
**Dependencies**: None (coordinated batch with 808/809/810 lock/gate infra; audited afterward by 811-814)
**Sources/Inputs**: Codebase grep across `.claude/`, `.opencode/`, CLAUDE.md, merge-sources
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, artifact-formats.md

## Executive Summary

- `--fable` has **zero references** anywhere in the repository (`.claude/`, `.opencode/`, `CLAUDE.md`). It is not documented and not wired into the parser. Every enumeration of model flags currently lists only `--haiku`, `--sonnet`, `--opus`.
- The **single point of code-level wiring** that must change is `.claude/scripts/parse-command-args.sh` (and its byte-identical mirror `.claude/extensions/core/scripts/parse-command-args.sh`), which sets `MODEL_FLAG` via three `if` checks and strips flags in `FOCUS_PROMPT` via three `sed` calls — both need a fourth `--fable` branch. `command-route-skill.sh` does **not** touch model flags (it only handles `--hard` routing), so no change is needed there.
- Documentation sites split into three tiers of duplication that must all be kept in sync: (1) `.claude/commands/{research,plan,implement}.md` == byte-identical to `.claude/extensions/core/commands/{research,plan,implement}.md` (verified via `diff`, zero output); (2) `.claude/CLAUDE.md` is auto-generated from `.claude/extensions/core/merge-sources/claudemd.md` — edits belong in the merge-source, not the generated file; (3) `.opencode/commands/{research,plan,implement}.md` is a **third, near-identical but not byte-identical** copy (per its own README, `.opencode/commands/` is claimed as the "active" definitions and `.claude/commands/` as the deprecated legacy mirror) — it repeats the same `--haiku|--sonnet|--opus` enumeration and has its own model-resolution block.
- The `Agent` tool itself (harness-level, not `.claude/`-controlled) already accepts `"fable"` as a valid `model` enum value alongside `"sonnet"`, `"opus"`, `"haiku"` — confirmed from this session's own tool schema. So wiring `--fable` -> `model_flag: "fable"` -> `Agent({model: "fable"})` requires no harness change, only propagation through the documented/parsed flag chain.
- Full flag-resolution path: `/research|/plan|/implement` (frontmatter `argument-hint` + Options table) -> command markdown "Extract Model Flags" step (research.md/plan.md only; implement.md relies solely on the sourced parser) -> `parse-command-args.sh` (`MODEL_FLAG` export) -> skill delegation `args:` string (`model_flag={MODEL_FLAG}`) -> skill SKILL.md Stage (e.g. skill-researcher Stage "Model/Effort Flags") -> `Agent({model: model_flag})` call. `--fable` must be added at every link.

## Context & Scope

Scope per task 804: audit and update every documentation/reference site enumerating model flags, verify the actual model-resolution code path recognizes `--fable`, and add it wherever `--haiku`/`--sonnet`/`--opus` are parsed but `--fable` is not. This is a research-only dispatch; no files were modified. Findings are organized by exact file:line so a subsequent `/plan` can turn this into a phased edit list without re-discovery. Per user focus, findings are scoped precisely so the design coheres with the concurrent batch (804/808/809/810, later audited by 811-814) rather than sprawling into unrelated systems.

## Findings

### Codebase Patterns — Sites that enumerate `--haiku`/`--sonnet`/`--opus` and must gain `--fable`

**Tier 1 — Command markdown, canonical Claude-Code copy (edit both, currently byte-identical):**

| File | Lines | Content |
|---|---|---|
| `.claude/commands/research.md` | 4 | `argument-hint: ... [--fast\|--hard] [--haiku\|--sonnet\|--opus]` |
| `.claude/commands/research.md` | 36-38 | Options table rows for `--haiku`/`--sonnet`/`--opus` |
| `.claude/commands/research.md` | 293-300 | "4. Extract Model Flags" step: 3 bullet mappings + "If none" fallback text |
| `.claude/commands/research.md` | 319 | "Remove `--haiku`, `--sonnet`, `--opus`" in Extract Focus Prompt step |
| `.claude/commands/research.md` | 408-411 | Model-resolution mapping: `model_flag="haiku" -> pass model: haiku` (etc.), plus null-fallback line |
| `.claude/commands/plan.md` | 4, 31-33, 301-308(approx), 413-416 | Same pattern as research.md (verified lines 4/31-33/301-305/413-416) |
| `.claude/commands/implement.md` | 4, 26-28 | argument-hint + Options table only — implement.md has **no** explicit "Extract Model Flags" step; it relies entirely on the sourced `parse-command-args.sh` output (`MODEL_FLAG`) referenced directly in the `args:` string at lines 150 and 154 |

`.claude/extensions/core/commands/research.md`, `.../plan.md`, `.../implement.md` are **byte-identical** to their `.claude/commands/` counterparts (`diff` produced no output for all three). Both copies must be edited identically, or a sync mechanism must be identified/used (no explicit sync script for commands was found via grep of `.claude/scripts/*.sh`; treat as two edit targets until a planner confirms otherwise).

**Tier 2 — CLAUDE.md generated file + its merge-source (edit the source, not the generated file):**

| File | Lines | Content |
|---|---|---|
| `.claude/CLAUDE.md` | 102-104 | Command Reference table: `[--fast\|--hard] [--haiku\|--sonnet\|--opus]` for `/research`, `/plan`, `/implement` |
| `.claude/CLAUDE.md` | 236 | "Model Enforcement" paragraph: "model flags (`--haiku`, `--sonnet`, `--opus`) select the model family" |
| `.claude/CLAUDE.md` | 291 | Hard Mode composability bullet: "`--hard` works with model flags: `--hard --opus` uses Opus model with hard-mode contracts" |
| `.claude/extensions/core/merge-sources/claudemd.md` | 93-95, 227, 282 | **Identical text** — this is the generation source. Per CLAUDE.md's own documented policy ("CLAUDE.md is auto-generated from merge-sources" for meta tasks), edits must land here; editing `.claude/CLAUDE.md` directly will be overwritten on next regeneration. |

**Tier 3 — `.opencode/commands/` mirror (separate system, same flag documentation, claims to be "active"):**

| File | Lines | Content |
|---|---|---|
| `.opencode/commands/research.md` | 4, 37-39, 295-300(+313), 423-426 | Same argument-hint/table/extract-step/model-resolution pattern as `.claude/commands/research.md`, with slightly different fallback wording ("use agent default, currently opus for all agents" vs. Claude-Code copy's frontmatter-aware phrasing) |
| `.opencode/commands/plan.md` | 4, 32-34, 303-308, 431-434 | Same pattern |
| `.opencode/commands/implement.md` | 4, 31-33, 336-341, 466-469 | Same pattern; unlike `.claude/commands/implement.md`, this copy **does** have an explicit "Extract Model Flags" step (line 336-341) |

`.claude/commands/README.md` states `.claude/commands/` is DEPRECATED/legacy and the active definitions live in `.opencode/commands/`. This task's delegation path is Claude-Code (`skill-orchestrate` -> `general-research-agent`), so the primary edit target is `.claude/` per the task's explicit SCOPE list, but the `.opencode/commands/` copies enumerate the identical flag set and would silently continue to omit `--fable` if left unedited — flagging this as a required or at minimum strongly-recommended companion edit for design coherence (same flag surface, same command names, same users).

**Tier 4 — Model policy / standards doc:**

| File | Lines | Content |
|---|---|---|
| `.claude/docs/reference/standards/agent-frontmatter-standard.md` | 55 | "Users can override the model at invocation time using model flags (`--haiku`, `--sonnet`, `--opus`)" |
| same | 63 | Values table row for `haiku` (no fable row exists) |
| same | 83-104 | "Runtime Override Flags" section: Effort flags table (fine, untouched) + **Model flags table** (98-100): `--haiku`/`--sonnet`/`--opus` -> maps-to -> behavior, needs a 4th `--fable` row |
| same | 102 | Prose: "If no model flag is provided, the agent's frontmatter default is used (opus for deep-reasoning agents, sonnet for general-purpose agents)" — should remain accurate once fable added (unaffected) |
| same | 106-114 | "**Examples**" code block: `/research 42 --opus`, `--sonnet`, `--haiku` — could add a `--fable` example for completeness |
| `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` | identical line numbers | Byte-identical mirror of the above (same Tier-1-style duplication pattern) |

**Tier 5 — Guides / architecture docs (prose mentions, lower priority but in scope per "everywhere... appear"):**

| File | Line | Content |
|---|---|---|
| `.claude/docs/guides/creating-commands.md` | 87 | "`parse-command-args.sh` extracts ... model selectors (`--haiku`, `--sonnet`, `--opus`), and remaining text as `FOCUS_PROMPT`." |
| `.claude/extensions/core/docs/guides/creating-commands.md` | 87 | Identical mirror |
| `.claude/docs/architecture/architecture-spec.md` | 79 | Comment: `#   MODEL_FLAG      - "haiku", "sonnet", "opus", or ""` — describes `parse-command-args.sh`'s documented output values |
| `.claude/extensions/core/docs/architecture/architecture-spec.md` | 79 | Identical mirror |
| `.claude/docs/examples/research-flow-example.md` | 65 | Example trace showing `MODEL_FLAG=` (empty) — not enumerating values, low priority, optional touch for completeness only |
| `.claude/extensions/core/docs/examples/research-flow-example.md` | 65 | Identical mirror |

**Tier 6 — Skill SKILL.md files (prose descriptions + JSON schema field, no enumeration hard-codes need changing except prose lists):**

| File | Line(s) | Content |
|---|---|---|
| `.claude/skills/skill-researcher/SKILL.md` | 284 | "**Model/Effort Flags**: If `model_flag` is set (haiku, sonnet, opus), pass it as the `model` parameter..." — prose list needs `fable` added |
| `.claude/skills/skill-planner/SKILL.md` | 307 | Same prose pattern |
| `.claude/skills/skill-implementer/SKILL.md` | 277 | Same prose pattern |
| `.claude/skills/skill-team-research/SKILL.md` | 43 | Table row: "`model_flag` \| string \| No \| Model override (haiku, sonnet, opus)..." |
| `.claude/skills/skill-team-plan/SKILL.md` | 41 | Same table row pattern |
| `.claude/skills/skill-team-implement/SKILL.md` | 42 | Same table row pattern |
| `.claude/skills/skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md` | ~237/247/284 | Only `"model_flag": "{model_flag from command, null if not set}"` — a generic passthrough placeholder in a JSON schema block, **no hardcoded haiku/sonnet/opus enumeration to fix**, so no fable-specific edit is required here beyond confirming pass-through remains generic |
| `.claude/extensions/cslib/skills/skill-cslib-research-hard/SKILL.md` | 161 | Same generic `model_flag` passthrough, no enumeration |
| `.claude/extensions/cslib/skills/skill-cslib-implementation-hard/SKILL.md` | 201 | Same generic `model_flag` passthrough, no enumeration |
| All of `.claude/extensions/core/skills/skill-*` mirrors of the above | same lines | Identical duplication of skills tree under `.claude/extensions/core/skills/` vs `.claude/skills/` — confirm sync mechanism before editing both |

### External Resources

Not applicable — this is a wholly internal documentation/wiring audit; no external API or library research was needed. One useful piece of external-ish context: this session's own `Agent` tool schema (harness-level, defined outside `.claude/`) already lists `"enum": ["sonnet", "opus", "haiku", "fable"]` for its `model` parameter, confirming `fable` is a first-class, already-supported value at the harness boundary — the gap is entirely on the `.claude/` documentation/parsing side, not the `Agent` tool itself.

### Recommendations

1. **Fix the parser first** (the only functional-behavior gap): add a fourth branch to both `.claude/scripts/parse-command-args.sh` and `.claude/extensions/core/scripts/parse-command-args.sh`:
   - After line 97-99 (`--opus` check): add `if [[ "$remaining" =~ --fable ]]; then MODEL_FLAG="fable"; fi`
   - After line 124 (`sed 's/--opus//g'`): add `| sed 's/--fable//g'`
   - Update the header comment at line 17 (`MODEL_FLAG — "haiku", "sonnet", "opus", or ""`) to include `"fable"`.
   - Note: order of the four `if` checks matters only if a user passes multiple model flags at once (last-match-wins semantics documented in agent-frontmatter-standard.md line 104); appending `--fable` last preserves existing precedence for `--haiku`/`--sonnet`/`--opus` combinations and makes `--fable` win if combined with another (acceptable, matches "last one wins" doc).
2. **Then update documentation in the tier order above** — Tier 1 (command markdown, 2 copies) and Tier 4 (frontmatter standard, 2 copies) are highest priority since they define user-facing usage and the authoritative model-selection policy; Tier 2's merge-source is the correct edit point for CLAUDE.md (never edit the generated `.claude/CLAUDE.md` directly for this content, edit `.claude/extensions/core/merge-sources/claudemd.md`); Tier 3 (`.opencode/commands/`) should be included for design coherence since it documents the identical flag surface under a claimed-active status; Tier 5/6 are prose completeness passes.
3. **Decide on `--fable` tier framing in agent-frontmatter-standard.md**: the doc's "Tiered Model Policy" (opus/sonnet/inherit) and "Values" table currently only formalize `haiku` as an override-only value (not a default tier). `--fable` should likely be documented the same way — an invocation-time override value, not a new default tier — added to the "Model flags" table (lines 98-100) and the "Examples" block (106-114), without necessarily adding a new row to the "Tiered Model Policy"/"Values" tables (which describe agent *defaults*, a separate axis from user override flags). Flag this explicitly for the planner to confirm placement.
4. **No `command-route-skill.sh` change needed** — verified by grep that this script only handles `--hard`/`routing_hard` routing and has zero references to `MODEL_FLAG`/haiku/sonnet/opus.
5. **`/orchestrate` and `/orchestrate --hard` are out of scope** — verified via grep of `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`: neither references model flags at all, consistent with CLAUDE.md's own Command Reference row (`/orchestrate N [--lit]`, no model-flag support documented). No `--fable` addition is needed there; do not introduce one, to avoid scope creep relative to task 804's explicit boundary (`/research`, `/plan`, `/implement` only).
6. **`meta-guide.md` line 237** ("`/meta` does not support ... `--haiku`, `--sonnet`, or `--opus`") is a *negative* enumeration (documents what `/meta` explicitly does NOT support). For consistency it should also list `--fable` in that same negative enumeration once `--fable` exists as a flag elsewhere, otherwise a reader could assume `--fable` is supported by omission. Located at `.claude/context/meta/meta-guide.md:237` and its mirror `.claude/extensions/core/context/meta/meta-guide.md:237`.

## Decisions

- Treat `.claude/scripts/parse-command-args.sh` + its `extensions/core` mirror as the sole functional wiring surface; no other script (`command-route-skill.sh`, extension manifests, `settings.json`, `extensions.json`) references model flags at all (confirmed via grep — zero hits).
- Treat `.claude/commands/*.md` and `.claude/extensions/core/commands/*.md` as requiring parallel edits (byte-identical today; no sync script found automating this relationship within `.claude/scripts/`).
- Treat `.claude/CLAUDE.md`'s model-flag content as generated — the edit target is `.claude/extensions/core/merge-sources/claudemd.md`, not `.claude/CLAUDE.md` directly.
- Flag `.opencode/commands/` as an in-scope companion (not explicitly named in task 804's SCOPE list, which only names `.claude/commands/`) — recommend the planner make an explicit include/exclude call given the OpenCode system's own README claims it is the "active" definition set for that runtime, while this task's delegation path is Claude-Code.
- No hardcoded enumeration issues found in `-hard` skill SKILL.md files (`skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`, cslib hard variants) — they only carry a generic `model_flag` passthrough field with no haiku/sonnet/opus literal list, so they need no edit beyond an optional confirmation that passthrough remains value-agnostic.

## Risks & Mitigations

- **Risk**: Editing `.claude/commands/*.md` and `.claude/extensions/core/commands/*.md` independently could drift if a sync/generation script exists that was missed by grep. **Mitigation**: planner/implementer should re-check for a "Load Core" sync mechanism (referenced in CLAUDE.md's "Syncprotect" section) before hand-editing both, and diff after editing to confirm they remain identical (or intentionally diverge only in already-existing pre-existing differences, of which none were found for these three files).
- **Risk**: `.opencode/commands/` edits, if made, touch a second runtime's command surface outside this session's primary system — could be seen as scope creep beyond task 804's literal SCOPE list. **Mitigation**: call this out explicitly as an optional/companion phase in the plan rather than silently including or silently excluding it.
- **Risk**: Adding `--fable` to `agent-frontmatter-standard.md`'s "Tiered Model Policy" table (rather than only the "Runtime Override Flags" table) could conflate default-tier policy with invocation-time override, since no agent currently declares `model: fable` in frontmatter. **Mitigation**: recommendation 3 above scopes `--fable` to the override-flags table only, matching how `haiku` is already handled (override-only, not a frontmatter tier).
- **Risk**: This task runs in the same batch as 808/809/810 (locking/gate infra unrelated to model flags) and is later audited by 811-814 (whole-system audit). **Mitigation**: this report stays strictly scoped to model-flag documentation/wiring sites; no findings here touch locking, gating, or unrelated audit surfaces, keeping the batch's outputs cleanly separable for 811-814's later system-wide pass.

## Context Extension Recommendations

- **Topic**: Model-flag documentation duplication across three parallel trees (`.claude/`, `.claude/extensions/core/`, `.opencode/`).
- **Gap**: No existing context file documents which of these trees is authoritative/generated-from-which for command markdown and skill files (only CLAUDE.md's own generation-from-merge-sources relationship is documented). A future contributor adding any new flag will hit the same multi-site duplication discovery cost this report just paid.
- **Recommendation**: Consider a `.claude/context/architecture/` note (or an addition to `.claude/docs/README.md`) explicitly mapping "canonical source -> generated/mirrored copies" for `.claude/commands/`, `.claude/extensions/core/commands/`, `.claude/skills/`, `.claude/extensions/core/skills/`, and `.opencode/commands/`, including whether any sync script exists or whether these must be hand-kept-in-sync. This is a good candidate for the later 811-814 whole-system audit tasks rather than this task's own scope.

## Appendix

### Search queries used

```bash
grep -rn "\-\-haiku\|\-\-sonnet\|\-\-opus\|\-\-fable" --include="*.md" --include="*.sh" --include="*.json" .claude/ CLAUDE.md
grep -rln "MODEL_FLAG\|model_flag\|model-flag" .claude/
grep -n "Model/Effort Flags\|haiku, sonnet, opus\|haiku|sonnet|opus" .claude/skills/skill-*-hard/SKILL.md
grep -rln "haiku\|sonnet\|opus\|MODEL_FLAG\|model_flag" .claude/extensions/*/manifest.json
grep -n "haiku\|sonnet|opus\|MODEL_FLAG\|model_flag\|fable" .claude/skills/skill-orchestrate/SKILL.md .claude/skills/skill-orchestrate-hard/SKILL.md
grep -rn "fable\|claude-fable" -ri .claude/ CLAUDE.md   # zero true hits (one false positive: "diffable")
diff .claude/commands/{research,plan,implement}.md .claude/extensions/core/commands/{research,plan,implement}.md   # byte-identical, zero diff
```

### References

- `.claude/scripts/parse-command-args.sh` (lines 17, 91-99, 117-130) — primary code-path fix location
- `.claude/extensions/core/scripts/parse-command-args.sh` — mirror, same fix
- `.claude/commands/research.md`, `plan.md`, `implement.md` — user-facing flag docs
- `.claude/extensions/core/commands/{research,plan,implement}.md` — byte-identical mirrors
- `.claude/CLAUDE.md` (generated) / `.claude/extensions/core/merge-sources/claudemd.md` (source)
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` (and core-extension mirror)
- `.opencode/commands/{research,plan,implement}.md` — parallel OpenCode command definitions
- `.claude/commands/README.md` — documents legacy-mirror status of `.claude/commands/`
