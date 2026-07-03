# Research Report: Task #772

**Task**: 772 - Make hard-mode orchestrator a pure dispatcher (strip implementation capability)
**Started**: 2026-07-03T00:00:00Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: 3-6 hours
**Dependencies**: 778 (DONE), 774 (in-flight, "planned" status, actively being implemented concurrently)
**Sources/Inputs**:
- Codebase: `.claude/skills/skill-orchestrate-hard/SKILL.md` (deployed + `.claude/extensions/core/` dual copy, currently byte-identical)
- `.claude/skills/skill-orchestrate/SKILL.md` (base, for behavioral contrast — "Same as base" references in the hard variant)
- `.claude/context/contracts/anti-analysis.md`, `.claude/context/contracts/wrap-up.md` (task 778's shipped skeleton/sorry_inventory schema)
- `.claude/skills/skill-implementer-hard/SKILL.md` (task 774's in-flight Stage 3b fix, directly informs 772's Stage 4 fix)
- `.claude/scripts/skill-base.sh`, `.claude/scripts/update-task-status.sh` (status-transition mechanics)
- `.claude/docs/guides/creating-commands.md`, `.claude/settings.json`, `.claude/skills/skill-git-workflow/SKILL.md`, `.claude/agents/spawn-agent.md` (scoped-tool syntax precedent: `Bash(cmd:*)`, `Read(path/*)`)
- `specs/state.json` (task 772/773/774/778/779 metadata, dependency graph)
- `specs/779_hardmode_fix_forward_recovery_contract/plans/01_recovery-contract-fix-forward.md`, `specs/774_hardmode_chunk_sizing_phase_subdivision/plans/01_skeleton-followup-phase-sizing.md` (sibling-task overlap detection)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Item 1 (remove Edit)** is a single one-line frontmatter edit at `SKILL.md:4`, safe: `Edit` is not referenced anywhere in the skill's own body — its presence was only ever exploited emergently by the orchestrator agent at runtime (the RC1 defect described in the task).
- **Item 2 (constrain Bash)** should use Claude Code's proven `Bash(cmd:*)` scoped-tool syntax (precedent: `skill-git-workflow/SKILL.md:4` and `.claude/settings.json`'s `allow` array) enumerated against every command the file **actually already uses** (`jq`, `mkdir`, `mv`, `rm`, `ls`, `sort`, `tail`, `grep`, `cat`, `date`, `echo`, `source`) — the file currently contains **zero** build/test/compiler invocations, so structural scoping is additive hardening, not a functional change — plus an explicit written "Forbidden Bash Operations" list (lake/lean-lsp/npm/pytest/nvim --headless etc.) since frontmatter scoping alone cannot enumerate every project's build tool.
- **Item 3 (blocking, single-phase, no background/parallel)** has a direct, pre-existing **structural conflict**: Stage 4's "Parallel Wave Dispatch (optional H7)" section (`SKILL.md:323-344`) explicitly documents "Parallel dispatch via multiple simultaneous Agent tool calls" and is listed as a supported feature in the Key Differences table (`SKILL.md:541`). Task 772's literal wording ("exactly one Agent call per cycle... FORBID background/parallel dispatch") is incompatible with this section as written. **This is a decision the plan must make explicitly**, not silently reconcile.
- **Item 4 (restrict Reads)** needs a similar scope decision: the skill's own Context References section (`SKILL.md:22-31`) anticipates reading `.claude/context/contracts/*.md` and `.claude/docs/architecture/*.md`, and Stage 4's H4 adversarial-verification gate (`SKILL.md:233-252`) greps the **research report** content — none of these are literally "handoff JSON, state.json, or plan files" per the task's wording, but none are "implementation source files" either (the actual RC1/RC4 concern). Recommend widening the *documented* allowlist to these four categories while keeping the explicit forbid on implementation source.
- **Item 5 (accept skeleton handoffs)** is the deepest finding: `SKILL.md:283`'s `next_phase=$((phases_completed + 1))` is the **exact same naive integer-increment defect** that task 774 just fixed at `skill-implementer-hard/SKILL.md:129-148` (heading-scan phase selection + skeleton-exhaustion detection) — and 774's plan **explicitly assigns the orchestrator-side fix and follow-up-task routing to task 772** ("Routing to the follow-up tasks themselves remains skill-orchestrate-hard's job (task 772) — out of scope here", `skill-implementer-hard/SKILL.md:154-155`). Additionally, Stage 5 (`SKILL.md:450-461`) is documented only as "Same as base `skill-orchestrate` Stage 5" — but base Stage 5's postflight-status-transition case statement (`skill-orchestrate/SKILL.md:357-359`) maps **any** `dispatch_status == "implemented"` straight to `skill_postflight_update(..., "implement", ...)`, which `update-task-status.sh`'s `postflight:implement` mapping (line 92) sets to `STATE_STATUS="completed"` — i.e., taken literally, a single phase's `"implemented"` handoff (skeleton or not) would flip the *whole task* to `completed` after phase 1, breaking the per-phase loop. This gap is orthogonal to skeleton-specifically but item 5's "accept as progress, not demand completeness" instruction is the natural place to fix it: the plan must gate that postflight call on `phases_completed >= phases_total`.
- **Sibling-task overlap**: 773 (depends on 772, so serializes *after* it) and 779 (status `planned`, no formal dependency on 772, **can run concurrently**) both edit `skill-orchestrate-hard/SKILL.md` in overlapping regions — 779 adds a "5th CONTRACT SLOT" to `build_hard_mode_prompt_context()` (`SKILL.md:307-319`), the exact function item 5 also touches. **Recommend explicit serialization of 772 and 779** on this file even though state.json doesn't encode it.

## Context & Scope

Task 772 modifies `skill-orchestrate-hard` ONLY (hard-mode; base `skill-orchestrate` is explicitly out of scope) to make it structurally incapable of doing implementation work itself. Five numbered requirements from the task description map to five investigation areas below. Two prerequisite tasks are relevant:

- **Task 778 (DONE)**: shipped the `skeleton` boolean + extended `sorry_inventory` schema (`file, line, statement, strategic, assumption, why_deferred, follow_up_task`) into `.claude/context/contracts/wrap-up.md` and the 5-condition strategic-sorry test into `.claude/context/contracts/anti-analysis.md`. These are single-copy files (no `.claude/extensions/core/` mirror) and are **out of scope for 772** — 772 only needs to *consume/read* them correctly in the orchestrator's own logic, never edit them.
- **Task 774 (in-flight, `planned` status but actively mid-implementation — commit `41cd982d4` already landed)**: fixed the analogous defect in `skill-implementer-hard/SKILL.md` Stage 3b (heading-scan phase selection replacing integer-increment; scoped handoff path; skeleton-exhaustion detection). 774's plan explicitly hands the **orchestrator-side** half of this same defect class to 772.

## Findings

### Finding 1 — Frontmatter (Item 1): exact line, safe removal

`allowed-tools: Agent, Bash, Read, Edit` is at **`.claude/skills/skill-orchestrate-hard/SKILL.md:4`** and, byte-identically, **`.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md:4`** (the two copies are currently 100% identical — `diff` returns nothing). `Edit` is referenced nowhere else in the file body (only `Read .claude/context/contracts/anti-analysis.md` appears at line 312, referring to the *contract's own* "First file edit" language for the *dispatched agent*, not the orchestrator itself). Change:

```
allowed-tools: Agent, Bash, Read
```

applied to both copies. This is a pure subtraction with zero references to update elsewhere in the file.

### Finding 2 — Bash scoping (Item 2): current usage inventory + precedent syntax

Grepping the file for command invocations, the **only** commands the skill's own instructions currently issue are: `jq`, `mkdir`, `mv`, `rm`, `ls`, `sort`, `tail`, `grep`, `cat`, `date`, `echo`, `source`. There is **no** `git`, `lake`, `lean`, `npm`, `pytest`, `nvim --headless`, or any build/test/compiler invocation anywhere in `skill-orchestrate-hard/SKILL.md` today — the orchestrator is already, in practice, orchestration-only. This means item 2's job is to make that **structural** rather than incidental (RC1's root cause was that unrestricted `Bash` let the *live agent* improvise `lake build`/`lean-lsp` calls at runtime on task 305, even though the skill's own written instructions never asked for it).

Two complementary mechanisms, both with codebase precedent:

1. **Frontmatter scoping** (`Bash(cmd:*)` syntax) — confirmed valid via:
   - `.claude/skills/skill-git-workflow/SKILL.md:4`: `allowed-tools: Bash(git:*)` (single-pattern precedent)
   - `.claude/agents/spawn-agent.md:5-9` (YAML list form): `tools: [... , Bash(jq:*)]`
   - `.claude/settings.json`'s `allow` array holds multiple `Bash(cmd:*)` entries side by side (`Bash(git:*)`, `Bash(lake *)`, `Bash(pdflatex *)`, etc.), confirming the pattern-matching mechanism supports an enumerated allowlist — though no existing skill combines *multiple* `Bash(...)` patterns on one `allowed-tools:` line, so the exact multi-pattern-in-one-line syntax should be smoke-tested during implementation (e.g. `allowed-tools: Agent, Bash(jq:*), Bash(mkdir:*), Bash(mv:*), Bash(rm:*), Bash(ls:*), Bash(sort:*), Bash(tail:*), Bash(grep:*), Bash(cat:*), Bash(date:*), Bash(echo:*), Bash(source:*), Read`).
2. **Explicit written prohibition** — a new subsection (e.g. "## Bash Constraints" directly under the header, or folded into the existing intro note at `SKILL.md:9-13`) stating in plain language: orchestration-only Bash (`jq` state/handoff reads, file bookkeeping, `git status`/`git log` for read-only context, `bash .claude/scripts/*.sh` status-sync helpers) is permitted; build/test/compiler invocations (`lake build`, `lean-lsp`/`mcp__lean-lsp__*`, `nvim --headless`, `npm test`, `pytest`, `cargo test`, `go test`, or any language build tool) are **forbidden in the orchestrator's own context** — that work belongs exclusively to dispatched implementation agents.

Recommend **both**: frontmatter scoping as the structural gate, plus the written list as a human/audit-readable statement of intent (mirroring how the `anti-analysis.md`/`wrap-up.md` contracts are prose-based behavioral rules layered on top of tool permissions elsewhere in this codebase).

### Finding 3 — Blocking single-phase dispatch (Item 3): conflicts with existing H7 parallel-wave section

Current single-phase dispatch is at **`SKILL.md:267-321`** (`#### State: \`planned\` or \`implementing\` — Per-Phase Dispatch (H1)`): exactly one `Agent tool:` invocation per state-machine cycle (line 299-303), followed by `After dispatch: read handoff (Stage 5)... Increment cycle_count` (line 321) — this part already matches item 3's requirement almost exactly, and is genuinely blocking/foreground (the loop body is a linear bash-pseudocode sequence; there is no async/background construct).

**The conflict**: immediately below it, **`SKILL.md:323-344`** (`#### State: \`planned\` or \`implementing\` — Parallel Wave Dispatch (optional H7)`) documents:

```
for phase in "${wave_phases[@]}"; do
  ...
  Agent tool:
    subagent_type: $IMPLEMENT_AGENT
    ...
done
# NOTE: Parallel dispatch via multiple simultaneous Agent tool calls
```

and the file's own "Key Differences" table (`SKILL.md:541`) lists `Parallel dispatch | None | Wave-based with territory (H7)` as a supported hard-mode feature. This is the H7 Territory Contracts capability advertised in the file's own overview (`SKILL.md:20`).

Task 772's item 3 root-causes on a **background** dispatch quote ("launched it in the background and will continue the orchestration" — the orchestrator continuing its own work while an agent ran unsupervised), which is a different failure mode than **parallel-but-still-blocking** wave dispatch (multiple simultaneous `Agent tool:` calls in one turn, all awaited before the loop proceeds — this codebase's own `Agent` tool documentation elsewhere describes exactly this pattern for independent work). However, the task's literal text — "exactly one Agent call per cycle... FORBID background/parallel dispatch of implementation agents" — reads H7 out of scope entirely. **This is a scope decision the plan must make explicitly**, with two options:
  - **(a) Disable/remove the H7 Parallel Wave Dispatch section** (`SKILL.md:323-344`) and update the Key Differences table row (`SKILL.md:541`) and the file overview bullet (`SKILL.md:20`) to reflect its removal (or gate it behind a note that it is currently disabled pending a future task).
  - **(b) Keep H7 but reclassify it**: treat "one Agent call per cycle" as the *default* rule, with H7 wave dispatch as an explicit, narrowly-scoped exception requiring evidence the plan file declares a genuine independent-file wave (already partially true — Territory building at `SKILL.md:346-347` extracts owned/read-only files from the plan) — i.e., argue H7 wave dispatch is not "background" in the RC3 sense since the orchestrator still blocks on all N calls returning.

Given the task description's explicit, unqualified phrasing, **recommend (a)** as the literal-compliance default, flagging (b) as an alternative for the user/planner to accept if H7 is considered load-bearing enough to preserve.

### Finding 4 — Read restriction (Item 4): scope tension with the skill's own Context References

The task says: "Restrict orchestrator Reads to handoff JSON, state.json, and plan files ONLY — forbid reading implementation source files." Two places in the current file read content beyond that narrow list:

1. **`SKILL.md:22-31`** (Context References section) lists `.claude/context/contracts/{convergence,territory,anti-analysis,wrap-up}.md` and `.claude/docs/architecture/{orchestrate-state-machine,handoff-schema}.md` as "load as needed" — these are agent-system contract/schema docs, not task implementation source, but are also not literally "handoff JSON, state.json, or plan files."
2. **`SKILL.md:233-252`** (H4 adversarial verification gate) does `grep -q "## Adversarial Self-Verification" "$research_path"` and `grep -q "| Claim | Source/Counterexample" "$research_path"` — i.e. inspects the **research report** content (via Bash `grep`, not the `Read` tool, but functionally a content read) to decide whether to skip re-verification. Research reports are also not literally "plan files."

Both of these are legitimate, load-bearing orchestrator behaviors that are clearly *not* the RC1/RC4 concern (reading Lean/Lua/proof source files to reason about implementation directly). Recommend the plan explicitly widen the documented allowlist to four categories rather than three:
  - `specs/state.json`
  - `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (and sibling `.orchestrator-loop-guard`, `.orchestrator-churn-state.json`)
  - `specs/{NNN}_{SLUG}/plans/*.md` and `specs/{NNN}_{SLUG}/reports/*.md` (reports needed for the H4 grep check)
  - `.claude/context/contracts/*.md` and `.claude/docs/architecture/*.md` (fixed, small, non-task-specific contract/schema references)
  - **Forbidden, explicitly**: anything under the project's own source tree (`lua/**`, `after/**`, or equivalent per-project source roots for other task types) — i.e. anything an `IMPLEMENT_AGENT` would itself modify.

For structural (not just documented) enforcement, `Read(path/*)` glob-scoping is confirmed valid Claude Code syntax (`.claude/docs/guides/creating-commands.md:59`: `` `Read(specs/*), Bash(git:*)` ``), so a frontmatter line such as `Read(specs/**), Read(.claude/context/contracts/*), Read(.claude/docs/architecture/*)` is a viable structural gate — recommend testing exact glob depth support (`*` vs `**`) during implementation since no existing skill in this codebase currently uses a multi-pattern `Read(...)` allowlist to copy from.

### Finding 5 — Skeleton handoff acceptance (Item 5): the real fix is two-part, and one part is already assigned to 772 by task 774

**Part A — phase-selection defect at `SKILL.md:283`.** The per-phase dispatch block computes:

```bash
next_phase=$((phases_completed + 1))
```

This is the **exact same pattern** task 774 just replaced in `skill-implementer-hard/SKILL.md` (formerly line ~129, now a heading-scan block at lines ~129-165) because plain integer-increment cannot address sub-phase headings (`4.1`, `4.2` from skeleton/follow-up subdivision) or sparse numbering, and has no signal for "the plan's phases are exhausted because the last dispatch was a skeleton." 774's own Stage 3b now does:

```bash
next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" \
  | head -1 | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')
```
and, when no incomplete heading remains **and** the last handoff had `skeleton == true`, emits an explicit exhaustion notice (`skill-implementer-hard/SKILL.md:151-159`):
```bash
elif [ -f "$handoff_file" ] && [ "$(jq -r '.skeleton // false' "$handoff_file" ...)" = "true" ]; then
  follow_up_tasks=$(jq -r '.follow_up_tasks // [] | join(", ")' "$handoff_file" ...)
  ...
  echo "[hard-mode] Skeleton plan exhausted -- ${follow_up_count} follow-up tasks pending: {${follow_up_tasks}}" >&2
  next_phase=""
```
774's plan states verbatim: *"Routing to the follow-up tasks themselves remains skill-orchestrate-hard's job (task 772) — out of scope here; Stage 3b only makes the condition legible."* (`skill-implementer-hard/SKILL.md:154-155`). **This is a direct, explicit assignment of work to 772** — the plan for 772 should mirror the same heading-scan fix at `SKILL.md:283` (for consistency between orchestrator and implementer phase-selection logic) and add the **routing** behavior 774 deliberately left out: when the orchestrator's own Stage 4 dispatch determines the plan is skeleton-exhausted, it must transition the task to an appropriate terminal/handoff state (e.g. `pr_ready` with a note enumerating pending follow-up tasks) rather than looping on a nonexistent phase until `MAX_CYCLES` is hit.

**Minor inconsistency to flag for the planner**: 774's Stage 3b reads a top-level `.follow_up_tasks` (plural) field from the handoff JSON — but task 778's shipped `wrap-up.md` schema has **no such top-level field**; it only has a per-entry `sorry_inventory[].follow_up_task` (singular). Since `wrap-up.md` is explicitly out of scope for both 774 and 772 (778 is "Preserved Assets," must not regress), 772's own routing logic should **derive** the follow-up task list by mapping/dedup'ing `sorry_inventory[].follow_up_task` across the handoff, not rely on the (currently unpopulated) `.follow_up_tasks` top-level field that 774's Stage 3b optimistically reads. Recommend the plan note this explicitly so the two skeleton-exhaustion code paths (implementer's notice and orchestrator's routing) agree on where the follow-up task list actually comes from.

**Part B — Stage 5 status-transition gap (independent of skeleton, but item 5's framing is the right place to fix it).** `SKILL.md:450-461` (current Stage 5) reads only:

```
Same as base `skill-orchestrate` Stage 5, plus:
sorry_inventory=$(echo "$handoff" | jq -c '.sorry_inventory // []')
if [ "$(echo "$sorry_inventory" | jq 'length')" -gt 0 ]; then
  echo "[hard-orchestrate] Sorry inventory: ..." >&2
fi
```

Base Stage 5 (`skill-orchestrate/SKILL.md:349-359`) contains the actual postflight status-transition logic, including:

```bash
case "$dispatch_status" in
  ...
  implemented)
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status"
    ;;
```

`skill_postflight_update` (`.claude/scripts/skill-base.sh:275-290`) calls `update-task-status.sh postflight $task_number implement $session_id` whenever status is in `researched|planned|implemented` — and `update-task-status.sh`'s `map_status` table (`postflight:implement) STATE_STATUS="completed"`) sets the **whole task's** `state.json` status straight to `completed`. In base mode this is correct because a single base-mode implement dispatch really does cover the *entire* plan (`skill-orchestrate/SKILL.md:224-239`: `"Implement task $task_number following the plan"` — one shot, no phase looping via state.json status). In hard mode, however, each per-phase dispatch also returns `status: "implemented"` (per phase, not per plan — see `general-implementation-hard-agent.md:219` "On `implemented`: set `status: "implemented"`..."), so if Stage 5 literally reuses the base case statement unmodified, **the first phase's `"implemented"` handoff (skeleton or not) would flip the task to `completed` after phase 1**, terminating the per-phase loop prematurely and never reaching phase 2+. This is currently underspecified — the SKILL.md text says "Same as base" without qualifying it for per-phase semantics, so it is ambiguous whether the deployed/live behavior already handles this correctly (via runtime judgment) or has always been latent.

Recommend the plan make Stage 5's postflight-update explicit and hard-mode-specific:

```bash
if [ "$dispatch_status" = "implemented" ]; then
  if [ "$phases_total" -gt 0 ] && [ "$phases_completed" -lt "$phases_total" ]; then
    # Phase complete, plan not yet complete: do NOT call skill_postflight_update.
    # Leave state.json status as "implementing" so Stage 3a re-enters the per-phase
    # dispatch handler on the next cycle. This applies identically whether or not
    # the phase handoff carried skeleton: true — a skeleton phase is still "this
    # phase done, proceed to next phase," never "task done."
    echo "[hard-orchestrate] Phase ${phases_completed}/${phases_total} complete (skeleton=${skeleton}). Continuing." >&2
  else
    skill_postflight_update "$task_number" "implement" "$session_id" "implemented"
  fi
fi
```

with the existing `sorry_inventory` logging (`SKILL.md:456-459`) extended to also read/log the `skeleton` boolean and each entry's `follow_up_task`.

### Finding 6 — Churn detection (Stage 4b) already does not misfire on skeleton dispatches

`SKILL.md:399-446` (H6 churn detection) only triggers on `handoff_status = "partial"` with `has_blockers = true` and zero phase delta (`SKILL.md:412`). A skeleton dispatch reports `status: "implemented"` (per `wrap-up.md`'s status/skeleton interaction table — `skeleton: true` is invalid unless `status == "implemented"`), so it can never enter the churn/three-strikes path today. No change needed here beyond the Stage 5 fix in Finding 5 — this is confirmation, not a defect.

### Sibling-task overlap map (for implementation serialization)

| Task | Status | Touches `skill-orchestrate-hard/SKILL.md`? | Region | Dependency relationship to 772 |
|------|--------|---|---|---|
| 773 — orchestrator-discipline contract + burnout breaker | not_started | Yes — new contract reference "at the top of the state-machine loop" (likely Stage 2/3, `SKILL.md:124-178`) | Stage 2/3 area | **Depends on 772** (`dependencies: [772]` in state.json) — serializes automatically *after* 772 completes; no concurrent-edit risk if dependency order is respected. |
| 774 — skeleton/phase-sizing planning leg | planned, **in-flight now** | No — edits `skill-implementer-hard/SKILL.md`, `general-implementation-hard-agent.md`, `plan-format.md`, `planner-hard-agent.md`. Explicitly does **not** touch `skill-orchestrate-hard` (774's plan line 91: "Edit `skill-orchestrate-hard` — that is task 772's territory"). | n/a (no file overlap) | 772 **depends on 774** (must wait for 774's Stage 3b handoff-path/phase-selection fix to land, which it already has per `git log`: commit `41cd982d4`). No concurrent-edit risk, but 772's plan should re-verify 774's final state before finalizing its own mirrored fix. |
| 779 — fix-forward recovery contract | **planned** (not yet implemented) | **Yes** — adds a "5th CONTRACT SLOT" to `build_hard_mode_prompt_context()` at `SKILL.md:307-319` (779's plan: "function at line 307, CONTRACT SLOTS block at lines 309-314") | Same function item 5 of 772 also touches (Stage 4 dispatch-prompt construction) | **No formal dependency on 772** in state.json (779 depends on `[778, 780]` only) — genuine concurrent-edit risk on the same file/function. **Recommend explicit manual serialization**: implement 772 (or 779) fully, land it, then implement the other, even though state.json won't enforce this automatically. |
| 778 — strategic-sorry skeleton policy | **completed** | No — only touched `wrap-up.md`, `anti-analysis.md`, `skill-implementer-hard/SKILL.md`, `general-implementation-hard-agent.md` | n/a | Foundational dependency, already merged; no further action. |

**Recommendation for the plan**: sequence 772 to land *before* 779 if at all schedulable (or coordinate a rebase), since 772's item 5 changes and 779's 5th-contract-slot addition are both localized to `build_hard_mode_prompt_context()` (`SKILL.md:305-319`) and its immediately surrounding "CONTRACT SLOTS" numbered list (`SKILL.md:309-314`) — a straightforward textual collision if both land independently without one being aware of the other's insertion.

### Dual-copy verification

`.claude/skills/skill-orchestrate-hard/SKILL.md` and `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` are currently **byte-identical** (`diff` returns nothing, both 543 lines). Every edit for items 1-5 must be mirrored to both paths in lockstep, matching the pattern already used by 774/778/779 for their own dual-copy files. Post-implementation, `diff -q` between the two copies must return empty (no drift tolerance, unlike the literature-script-name drift noted as pre-existing/intentional in the `skill-implementer-hard` SKILL.md pair).

## Decisions

- Frontmatter change (Finding 1) is unambiguous: remove `Edit`, no further discussion needed.
- Bash/Read scoping (Findings 2, 4) should use **both** a structural `allowed-tools` scoped-pattern gate (`Bash(cmd:*)`, `Read(path/*)`) **and** an explicit prose "Forbidden Operations" section, since frontmatter glob-scoping cannot itself enumerate every possible build/test tool across task types, and the exact multi-pattern-per-line syntax is unverified in this codebase (no existing precedent combines more than one `Bash(...)`/`Read(...)` entry on a single `allowed-tools:` line) and should be smoke-tested during implementation.
- Parallel wave dispatch (Finding 3) requires an explicit scope decision from the plan/user: disable H7 wave dispatch (literal reading of item 3) vs. reclassify it as a narrow, still-blocking exception. This report recommends disabling it as the literal-compliance default but flags the alternative.
- Skeleton acceptance (Finding 5) is two distinct, both-required changes: (A) heading-scan phase-selection mirroring 774's `skill-implementer-hard` fix plus skeleton-exhaustion routing to follow-up tasks (explicitly assigned to 772 by 774's plan), and (B) an explicit gate on the Stage 5 postflight status-transition so a per-phase `"implemented"` handoff does not prematurely flip the whole task to `completed`. (B) is not skeleton-specific but is naturally fixed alongside (A) since both concern "when is a per-phase handoff routed as ongoing progress vs. final completion."

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `Bash(cmd:*)`/`Read(path/*)` multi-pattern syntax on one `allowed-tools:` line may not parse/enforce as expected (unverified in this codebase) | Smoke-test with a minimal reproduction (e.g. temporarily invoke the skill and attempt a disallowed Bash/Read call) before relying on it as the sole enforcement layer; keep the prose prohibition as a fallback behavioral contract regardless. |
| Disabling H7 parallel wave dispatch removes an advertised feature (`SKILL.md:20`, `:541`) without an explicit user sign-off | Surface the tradeoff explicitly in the plan's "Decisions" section (as this report does) rather than silently deleting it; let the plan/user confirm before implementation. |
| 772 and 779 both edit `build_hard_mode_prompt_context()` concurrently | Recommend explicit manual serialization (land one fully before starting the other); note the risk in 772's plan's Territory table so whoever dispatches 779 later is aware of 772's insertion. |
| Stage 5 postflight-gate fix (Finding 5, Part B) touches core state-transition logic not explicitly named in the task's 5 numbered items — risk of scope creep | Frame it explicitly as required-for-item-5 (an "implemented" per-phase skeleton handoff cannot be "accepted... as progress" if the very next line of the same Stage flips the task to `completed`), not as an unrelated addition; keep the change minimal (a single conditional gate, no new fields). |
| 774's Stage 3b reads `.follow_up_tasks` (plural, top-level) which has no schema backing in `wrap-up.md` | 772's own routing logic should derive from `sorry_inventory[].follow_up_task` (the actually-shipped field) rather than copying 774's read of the unpopulated field; note this explicitly in 772's plan so the two skeleton-exhaustion code paths do not diverge. |

## Context Extension Recommendations

- **Topic**: Multi-pattern `allowed-tools` scoping precedent.
- **Gap**: No existing skill in this codebase combines more than one `Bash(cmd:*)` or `Read(path/*)` pattern on a single `allowed-tools:` frontmatter line; there is no documented example or test of this syntax's exact glob-depth support (`*` vs `**`).
- **Recommendation**: once 772 implements and verifies this pattern, consider adding a short worked example to `.claude/docs/guides/creating-skills.md` (which already documents the single-pattern and `Agent`-only forms) so future hard-mode/restricted skills have a citable precedent.

## Appendix

### Search queries / investigation steps used
- Read full `skill-orchestrate-hard/SKILL.md` (543 lines) and diffed against `.claude/extensions/core/` copy (identical).
- Read full `skill-orchestrate/SKILL.md` relevant sections (Stage 4 planned/implementing, Stage 5 handoff reading + postflight case statement, Stage 5a drift inspection).
- Read `.claude/context/contracts/anti-analysis.md` and `wrap-up.md` in full (task 778's shipped schema).
- Grepped `general-implementation-hard-agent.md` and `skill-implementer-hard/SKILL.md` for `skeleton`/`sorry_inventory`/`follow_up_task*` usage; read Stage 3b (774's in-flight fix) and Stage 6/7 (778's postflight handling) in full.
- Read `.claude/scripts/skill-base.sh` (`skill_postflight_update`) and `.claude/scripts/update-task-status.sh` (`map_status` table) to trace the state.json status-transition mechanism triggered by handoff `status` fields.
- Grepped all `.claude/skills/*/SKILL.md` and `.claude/agents/*.md` for `allowed-tools`/`tools:` patterns to find scoped-Bash/Read precedent (`skill-git-workflow`, `spawn-agent`, `.claude/settings.json`, `.claude/docs/guides/creating-commands.md`).
- Read `specs/774_.../plans/01_skeleton-followup-phase-sizing.md` and `specs/779_.../plans/01_recovery-contract-fix-forward.md` in full for sibling-task overlap detection (Territory tables, exact line/function references to `skill-orchestrate-hard`).
- Queried `specs/state.json` for tasks 772/773/774/778/779 (status, dependencies, description, artifacts) and for any other active task whose description mentions "orchestrate-hard".
- `git log --oneline -5 -- .claude/skills/skill-implementer-hard/SKILL.md` to confirm 774's Stage 3b fix has already landed despite 774's overall status still reading "planned".

### Key file/line reference table

| Concern | File | Lines |
|---|---|---|
| Frontmatter allowed-tools | `skill-orchestrate-hard/SKILL.md` (+ core copy) | 4 |
| Context References (Read scope tension) | `skill-orchestrate-hard/SKILL.md` | 22-31 |
| H4 adversarial verification (reads research report) | `skill-orchestrate-hard/SKILL.md` | 225-261 (grep at 237-238) |
| Per-phase dispatch (H1, blocking single call) | `skill-orchestrate-hard/SKILL.md` | 267-321 |
| `next_phase` integer-increment defect | `skill-orchestrate-hard/SKILL.md` | 283 |
| `build_hard_mode_prompt_context()` / CONTRACT SLOTS (779 overlap) | `skill-orchestrate-hard/SKILL.md` | 305-319 |
| H7 Parallel Wave Dispatch (item-3 conflict) | `skill-orchestrate-hard/SKILL.md` | 323-347 |
| Stage 4b Churn Detection (confirmed no skeleton misfire) | `skill-orchestrate-hard/SKILL.md` | 399-446 |
| Stage 5 Handoff Reading (sorry_inventory only, missing skeleton gate) | `skill-orchestrate-hard/SKILL.md` | 450-461 |
| Key Differences table (H7 row, if disabled) | `skill-orchestrate-hard/SKILL.md` | 534-543 |
| Base Stage 5 postflight case statement (source of the completed-too-early gap) | `skill-orchestrate/SKILL.md` | 349-363 |
| `skill_postflight_update` | `.claude/scripts/skill-base.sh` | 275-290 |
| `postflight:implement -> completed` mapping | `.claude/scripts/update-task-status.sh` | 92 |
| 774's heading-scan fix + skeleton-exhaustion notice (pattern to mirror) | `skill-implementer-hard/SKILL.md` | 122-165 |
| 778's `skeleton`/`sorry_inventory` schema | `.claude/context/contracts/wrap-up.md` | 12-64 |
| 778's 5-condition strategic-sorry test | `.claude/context/contracts/anti-analysis.md` | 59-83 |
| Scoped-tool syntax precedent | `skill-git-workflow/SKILL.md:4`, `spawn-agent.md:5-9`, `.claude/settings.json`, `.claude/docs/guides/creating-commands.md:59` | — |
