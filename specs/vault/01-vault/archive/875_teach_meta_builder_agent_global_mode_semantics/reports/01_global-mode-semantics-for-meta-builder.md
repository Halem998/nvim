# Research Report: Task #875

**Task**: 875 - Teach meta-builder-agent global-mode semantics
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T00:00:00Z
**Effort**: ~2 hours (research)
**Dependencies**: 873 (COMPLETED, Phases 1-4; Phase 5 BLOCKED — see below)
**Sources/Inputs**: Codebase read (meta-builder-agent.md, skill-meta/SKILL.md, commands/meta.md,
  validate-meta-write.sh, generate-todo.sh, manage-topics.sh), dependency's summary and plan
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- Verified precondition holds: `agent-system/extensions/core/agents/meta-builder-agent.md` and
  `.claude/agents/meta-builder-agent.md` are still byte-identical (`diff` returned nothing).
  `agent-system/extensions/core/skills/skill-meta/SKILL.md` and `commands/meta.md` now carry the
  dependency's landed `target_root`/`mode_target` threading, the `--local` flag, and a chained-`cd`
  postflight convention that was empirically proven at the shell level (Phase 4 of the dependency).
- `meta-builder-agent.md` currently has **zero** references to `target_root`/`mode_target`/`GLOBAL_ROOT`
  anywhere — the dependency's threaded delegation field is not consumed at all. Every read and write
  path in the file is a bare CWD-relative `specs/...` or `.claude/...` string. The gap is real and
  comprehensive, not confined to the four call-outs in the task description.
- The task description's line numbers for the "Stage 0 inventory" (:158-162) and "task-dir renderings"
  (:821, :1032-1034, :1071-1074, :1118-1119) match the file **exactly** as read today. Its line numbers
  for the "return-schema examples" (:138-143) do **not** match — that content is actually the
  `Stage 5: Return Structured JSON` block, now at lines ~1258-1332, roughly 1120 lines further down
  (the file grew substantially between when the task description was written and now, from Interview
  Stage 3.5 consolidation, dependency-validation pseudocode, and the Kahn's-algorithm/graph-generation
  Python blocks). This is flagged per the task's own "MUST be checked rather than assumed" instruction:
  do not trust the task description's line numbers for that section: locate the return-schema block by
  content ("Return Structured JSON") when implementing.
- A materially important finding not called out in the task description: two of the scripts
  `meta-builder-agent.md` invokes via bare Bash calls resolve their own root **differently**.
  `generate-todo.sh` accepts explicit `--state FILE --todo FILE` overrides but *also* self-resolves a
  `PROJECT_ROOT` from its own `BASH_SOURCE[0]` (script location), not CWD. `manage-topics.sh` has
  **no override flag at all** and relies **solely** on its own `BASH_SOURCE[0]`-derived
  `PROJECT_ROOT` (`"$SCRIPT_DIR/../.."`). Consequence: invoking either script via a *bare* relative
  path (`.claude/scripts/generate-todo.sh`) after a `cd "$TARGET_ROOT"` **works**, because
  `BASH_SOURCE[0]` becomes relative-to-the-now-current-directory and resolves to the target repo's own
  script. Invoking via a bare relative path **without** first `cd`-ing into `$TARGET_ROOT` in the same
  Bash call resolves to whichever repo's copy happens to sit at the current CWD — silently operating on
  the *wrong* repo's `state.json`/`TODO.md`. This must be handled correctly in every Bash block that
  calls these scripts, not just in Stage 0's read-only inventory.
- Recommended design: qualify every `specs/` and `.claude/` path in `meta-builder-agent.md` by
  `target_root` using the pattern already established and empirically verified by the dependency
  (chained-single-Bash-call `cd`, or literal `${target_root}/...`-prefixed absolute paths for
  Write/Edit, which are unaffected by shell `cd` entirely). Full per-line classification and concrete
  before/after text is in Findings below.
- The SCOPE BOUNDARY (current line 26) and surrounding FORBIDDEN/REQUIRED lists conflate two rules that
  now diverge: (1) "this agent never implements — it only creates tasks" (an actor/workflow rule,
  independent of location) and (2) "`.claude/` is a disposable deploy artifact — never a legitimate
  write target for anyone" (a location-correctness rule). A concrete reframing is proposed in Decisions.
- Phase 5 of the dependency (873) never reached `skill-meta` or `meta-builder-agent` — it was blocked
  by Claude Code's non-interactive workspace-trust dialog before mode detection. **The same blocker
  will almost certainly block a live end-to-end verification of this task too.** What CAN be verified
  without a human's interactive session is enumerated in Risks & Mitigations / a dedicated note below;
  a live cross-repo `/meta` run creating a real task and confirming it lands under
  `~/.config/nvim/specs/` (not the invoking repo's `specs/`) genuinely cannot be exercised headlessly
  and must be the user's manual step, mirroring the dependency's own recorded manual procedure.

## Context & Scope

Task 875 must edit exactly one file — `agent-system/extensions/core/agents/meta-builder-agent.md` —
so that it correctly consumes the `target_root`/`mode_target` fields task 873 now threads into its
delegation context, performs every read/write operation against that resolved root rather than
whatever repo the agent process happens to have as its CWD, and so that any tasks it *creates* whose
domain is agent-system changes name `agent-system/extensions/core/**` paths (the source store) as
their edit targets rather than `.claude/**` (a disposable, regenerated deploy tree). This is research
only — no edits were made to the target file; the file was read and fully inventoried, and this report
records the analysis for the subsequent `/plan` and `/implement` phases.

## Findings

### Precondition Verification

```
$ diff agent-system/extensions/core/agents/meta-builder-agent.md .claude/agents/meta-builder-agent.md
(no output — files are byte-identical)
```

The task description's claim that source and deploy copies are still identical holds. This means the
edit-target file has had **zero** drift since the last `<leader>al` sync, and the eventual diff will be
entirely attributable to this task.

### Full Inventory of `specs/` and `.claude/` References in `meta-builder-agent.md`

`grep -n 'specs/\|\.claude/'` returns 47 matches. Each is classified below into one of five
categories. Only Categories B, C, D, and E require changes; Category A is correct as-is.

**Category A — Agent's own operational context loading (NO CHANGE)**

These are `@`-references or prose mentions of context/doc files the agent reads *for its own
guidance* (how to write a command, the metadata-file schema, the multi-task-creation standard, the
overlap algorithm). They correctly resolve against whatever repo's `.claude/` is deployed in the
current session regardless of `target_root`, because they are not about *where the deliverable
lands* — they are the agent's own reference material. Lines: 9, 13 (prose, informational only), 20
(prose), 63, 64, 73, 74, 75 (see caveat below), 78, 79, 80, 395, 581.

**Caveat on line 75**: `| analyze | \`@.claude/CLAUDE.md\`, \`@.claude/context/index.json\` |` sits in
the Mode-Context Matrix specifically for **analyze mode**, whose entire purpose (Stage 3C, System
Analysis) is to inventory and report on the *target* system's structure — this is actually
Category B in intent (the CLAUDE.md/index.json being analyzed must be the resolved target's, matching
Stage 3C's own inventory block at lines 1204-1226), not Category A. Static `@`-syntax cannot be
parameterized by a runtime variable, so this must be rewritten as an explicit runtime `Read` instruction
(`Read {target_root}/.claude/CLAUDE.md` and `Read {target_root}/.claude/context/index.json`), not left
as a static `@`-reference, which would otherwise silently load the *agent's own* deployed copy instead
of the target's.

**Category B — Read-only inventory operations against the resolved target's `.claude/`/`specs/`
(MUST qualify with `target_root`)**

| Lines | Content | Fix |
|---|---|---|
| 154, 158-162 | Interview Stage 0 `DetectExistingSystem`: `ls .claude/commands/*.md`, `find .claude/skills -name SKILL.md`, `ls .claude/agents/*.md`, `ls .claude/rules/*.md`, `jq '.active_projects | length' specs/state.json` | Prefix every path with `${TARGET_ROOT}` (absolute), e.g. `ls "${TARGET_ROOT}/.claude/commands"/*.md`. This matches the task description's explicit call-out exactly. |
| 1161 | Stage 3B Step 2, `jq '.active_projects[] | select(...)' specs/state.json` | Same qualification. |
| 1206-1226 | Stage 3C Step 1 (`analyze` mode inventory): four component-listing blocks plus `jq -r '.active_projects[]...' specs/state.json` | Same qualification; this is the read-only twin of Stage 0's inventory and was not explicitly named in the task description's bullet list but is the same category of bug. |
| 75 | Mode-Context Matrix analyze-mode row (see Category A caveat above) | Rewrite as explicit `Read {target_root}/...` runtime instruction, not `@`-syntax. |

**Category C — Task-creation content: `file_scope`/`affected_area` heuristics that currently point
at `.claude/` subdirectories (MUST change to source-store paths)**

This is the task description's second required change ("Tasks this agent CREATES must name
`agent-system/extensions/core/**` paths as edit targets rather than `.claude/**` paths").

| Lines | Content | Fix |
|---|---|---|
| 391 | File-footprint heuristic: "match domain keywords ... against their corresponding `.claude/` subdirectories (`skills/`, `agents/`, `commands/`, `rules/`, `context/patterns/`, etc.)" | Change the target directory family from `.claude/{skills,agents,commands,rules,context}/` to `agent-system/extensions/core/{skills,agents,commands,rules,context}/` (and note core vs. extension source dirs when the task is extension-scoped, if that distinction is knowable at this stage — see Decisions). |
| 421 | Stage 3.5 "Affected Area" extraction description: "Parse for directory mentions (.claude/commands/, .claude/skills/, .claude/agents/, etc.)" | Same directory-family change. |
| 429, 435 | Stage 3.5 worked examples: `affected_area: ".claude/commands/"`, `affected_area: ".claude/skills/"` | Update the two worked examples to `agent-system/extensions/core/commands/` and `agent-system/extensions/core/skills/`. |
| 241 | Interview Stage 2.5 classification keywords list includes literal `".claude/"` as a keyword trigger for `task_type = "meta"` | This one is about *classifying the task*, not about *where the task's file_scope points* — it is arguably fine to leave as a keyword trigger (a user typing ".claude/" in a description still signals "meta"), but should be read alongside a comment clarifying that the *keyword* can stay `.claude/` even though the *file_scope produced* should not. Flagged for planner judgment, not a hard requirement. |

Note: Stage 6's literal `state.json` entry example (lines ~721-734) does not include a `file_scope`
field in its example JSON at all today — `file_scope` is populated earlier (Stage 3, Component 4a)
and merely referenced by name in Stage 6, not re-rendered. No change needed to the Stage 6 JSON
example itself beyond what Category D covers for the write target.

**Category D — Actual write/mutate operations against `specs/` under the resolved target (MUST
qualify)**

| Lines | Content | Fix |
|---|---|---|
| 741 | `bash .claude/scripts/generate-todo.sh` (regenerate TODO.md) | See "Script Path-Resolution Subtlety" below — must run against `$TARGET_ROOT`, either via a preceding same-call `cd` or an absolute script path. |
| 821, 1032-1034, 1071-1074, 1118-1119 | DeliverSummary table-rendering: `specs/{padded}_{task['slug']}/` and the three worked examples (`specs/037_add_topological_sorting/`, etc.) | These are informational text shown to the *user*, not file operations — but in global mode they are actively misleading: a user who reads "specs/037_..." while their own CWD is a foreign repo will reasonably read it as relative to *their* repo, then run `/research 37` from that same foreign repo and get a mismatch (task 37 actually lives under `$TARGET_ROOT`). This was not automatically correct and needed exactly the verification the task description demanded. Fix: render `{target_root}/specs/{padded}_{slug}/` in the table (or, more usefully, print the resolved `target_root` once as a header line in the DeliverSummary output — e.g. "**Created in**: {target_root} ({mode_target} mode)" — so the reader has an unambiguous anchor without needing to re-read every table cell). |
| 1358, 1364 | `bash .claude/scripts/manage-topics.sh add "$topic"` / `set "$task_num" "$batch_topic"` | See "Script Path-Resolution Subtlety" below — `manage-topics.sh` has **no** `--state` override; correctness here depends entirely on invocation-path resolution. |
| 1372 | `bash .claude/scripts/generate-todo.sh` (repeat call in Stage 6 step 4a) | Same as line 741. |
| 1378 | `git add specs/` (Stage 6 "5. Git Commit") | Must become the same chained pattern skill-meta's postflight already uses: `GLOBAL_ROOT_OR_TARGET_ROOT="{target_root}"; cd "$TARGET_ROOT" && git add specs/ && git commit -m ...` as a single Bash call. See "Possible duplicate commit" note below. |
| 1271 | Stage 5 return-JSON example: `"path": "specs/TODO.md"` (the `Return Structured JSON` block, misidentified by stale line numbers in the task description as ":138-143" — see Context Verification above) | Should render the resolved path (`{target_root}/specs/TODO.md`, or an absolute path) so a caller reading the return JSON — not just the human-readable DeliverSummary text — can determine where the artifact actually landed. This directly serves the task's stated goal that "the agent definition itself should be unambiguous about where it writes." |
| ~47 (implicit, "Write - Create task entries and directories") | The Allowed Tools list documents that this agent creates task *directories* via Write, but Stage 6's per-task loop (lines ~702-715) only has prose comments ("# 2. Update state.json", "# 3. Update TODO.md") with no literal `mkdir`/`Write` shown. Whatever the literal mechanism turns out to be (a `mkdir -p` in Bash, or a placeholder `Write` call), it must be `target_root`-qualified. This is schematic in the current doc and should be made concrete with an explicit qualified-path example during implementation, not left implicit. |

**Category E — SCOPE BOUNDARY / anti-bypass wording (MUST reframe)**

Lines 26, 28-33 (Constraints section) and 1424-1429 (Critical Requirements MUST NOT list) state the
rule as "MUST NOT write to `.claude/` paths ... creates TASKS in `specs/` only ... Write any files
outside specs/". This conflates two now-distinct rules — see Decisions below for the precise
reframing recommendation.

### Script Path-Resolution Subtlety (new finding, not in the task description's bullet list)

Both scripts self-resolve a project root from their own invocation path:

```bash
# generate-todo.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TODO_FILE="${PROJECT_ROOT}/specs/TODO.md"     # overridable via --todo
STATE_FILE="${PROJECT_ROOT}/specs/state.json"  # overridable via --state

# manage-topics.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/specs/state.json"    # NOT overridable — no flag exists
```

Consequence for `meta-builder-agent.md`'s Bash blocks: `BASH_SOURCE[0]` is exactly the string used to
invoke the script. Two invocation strategies both work correctly, and one does **not**:

1. **Correct — chained `cd` then relative invocation, single Bash call**:
   `cd "${TARGET_ROOT}" && bash .claude/scripts/generate-todo.sh` — `BASH_SOURCE[0]` becomes
   `.claude/scripts/generate-todo.sh` resolved against the now-current directory, so `PROJECT_ROOT`
   correctly becomes `$TARGET_ROOT`. Mirrors the exact pattern task 873's dependency already
   established and empirically verified for `git`.
2. **Correct — fully-absolute invocation, no `cd` needed**:
   `bash "${TARGET_ROOT}/.claude/scripts/generate-todo.sh"` — `BASH_SOURCE[0]` is already rooted at
   `$TARGET_ROOT`, so `PROJECT_ROOT` resolves correctly regardless of CWD. This form also sidesteps
   the "must be a single Bash call" fragility entirely, since it carries no cwd dependency at all.
3. **Incorrect — bare relative invocation with no `cd`** (what the file does today):
   `bash .claude/scripts/generate-todo.sh` from whatever CWD the agent process happens to have. If
   that CWD is a foreign repo (the very case global mode exists to redirect *away* from), this
   silently regenerates the *foreign* repo's `TODO.md` from the *foreign* repo's `state.json` — a
   silent wrong-repo write, not a crash, which makes it a dangerous failure mode to leave unaddressed.

`generate-todo.sh`'s `--state`/`--todo` overrides are a second, independent way to force
correctness (`--state "${TARGET_ROOT}/specs/state.json" --todo "${TARGET_ROOT}/specs/TODO.md"`) but
do **not** by themselves fix `PROJECT_ROOT`, which also feeds the log file path
(`${PROJECT_ROOT}/.agent-logs/generate-todo.log`) and the `generate-task-order.sh --print` delegate
call (line ~326 comment: "We pass our STATE_FILE via a temporary symlink workaround if it differs...
normally both scripts share the same PROJECT_ROOT/specs/state.json default" — i.e. even the flag
overrides have a documented caveat about staying in sync with `PROJECT_ROOT`). **Recommendation**:
prefer invocation strategy 2 (fully-qualified absolute script path) for both scripts, since it is
correct unconditionally and does not depend on this coupling; use it consistently rather than mixing
`--state`/`--todo` flags with a possibly-mismatched `PROJECT_ROOT`.

### Possible Pre-Existing Duplicate Git Commit (flag, not a defect introduced by this task)

`meta-builder-agent.md`'s own Stage 6 has a "5. Git Commit" step (`git add specs/ && git commit -m
"meta: create {N} tasks..."`, line ~1376-1380) that appears to duplicate `skill-meta/SKILL.md`'s
postflight commit (added by the dependency, "Postflight Git Commit" section). Since the agent runs
and (presumably) commits *before* returning to the skill, the skill's later `git add specs/ && git
commit` would find nothing new staged and no-op/fail harmlessly — not a functional bug, but worth a
planner-level decision on whether meta-builder-agent's own commit step should be qualified in place
(consistent, minimal-diff) or removed in favor of relying solely on skill-meta's postflight (bigger,
out-of-file-scope-adjacent change, since it would mean editing Stage 6 more invasively). This report
does not recommend removing it — that would be a mechanism redesign, which is explicitly out of
scope — only flags that if kept, its `git add specs/`/`git commit` must receive the same
`target_root`-qualified chained-`cd` treatment as line 1378 already calls for under Category D.

## Decisions

1. **Path-qualification mechanism**: use `${target_root}`-qualified absolute paths as the default
   strategy for every operation (Write/Edit calls, and script invocations via their fully-qualified
   path), reserving the chained-`cd`-then-relative pattern specifically for the `git` commit step
   (mirroring the dependency's already-tested convention exactly). Rationale: absolute-path
   qualification is uniformly correct for both Bash and Write/Edit tools (Write/Edit ignore `cd`
   entirely, so they need literal qualified paths regardless), whereas `cd`-chaining is a Bash-only
   mechanism that must be re-derived in every single Bash call (no persistence across calls) — using
   it everywhere multiplies the chances of a missed re-derivation. Reserving it for `git` keeps this
   file consistent with the one place the dependency already proved the chained pattern live (Phase 4
   of 873), rather than introducing a second, unverified variant.

2. **`target_root` must be added to Stage 1's parsed delegation fields.** Currently Stage 1's example
   JSON (lines ~115-125) only shows `metadata`, `mode`, `prompt`. It must be extended to show
   `mode_target` and `target_root` as fields the agent extracts and holds as `$TARGET_ROOT` for the
   remainder of execution — this is the load-bearing addition that makes every fix in Category B/D
   possible; without it there is no variable to qualify paths with.

3. **SCOPE BOUNDARY reframing** (Category E). Recommended replacement text for the two rules that are
   currently conflated in the Constraints section (line 26) and the FORBIDDEN list (lines 28-33):

   - **Rule 1 (actor/workflow — unchanged in substance, reworded for clarity)**: "This agent MUST NOT
     implement system changes directly, in either the source store or a deploy tree. It creates TASKS
     only; all actual file creation/modification happens through the `/implement` lifecycle after
     tasks are created and confirmed."
   - **Rule 2 (location-correctness — new, source-store-vs-deploy-tree specific)**: "`.claude/` under
     any repo is a gitignored, disposable deploy artifact regenerated from the source store
     (`agent-system/extensions/core/**` and any loaded extensions) — no agent, including
     `/implement`-lifecycle agents, should hand-author files there; such edits are silently wiped by
     the next `<leader>al` regeneration. Tasks this agent creates whose scope is an agent-system
     change must therefore name `agent-system/extensions/core/**` (or the relevant extension's source
     directory) as their edit target, never `.claude/**`."
   - Both rules stay, but as two clearly separate sentences/bullets rather than one merged sentence,
     so a future reader does not assume "don't write .claude/" is the *only* content of the boundary
     (it omits the equally-real "don't implement at all" rule) or that "creates TASKS in specs/ only"
     licenses writing to *any* `specs/` regardless of repo (it doesn't — it must be
     `{target_root}/specs/`).
   - The `validate-meta-write.sh` hook (verified identical between source and deploy copies) only
     detects literal `.claude/` writes; it has no way to detect a `specs/` write landing in the *wrong*
     repo (its `case` skip pattern `specs/*|*/specs/*` matches unconditionally regardless of which
     repo the path belongs to). This should be stated plainly in the reframed boundary text so it is
     not mistaken for a backstop that also enforces target-root correctness — it does not, and cannot
     from a PostToolUse hook alone (it only sees the tool's file_path argument, not which repo the
     agent intended).

4. **File-footprint heuristic (Category C) target directory family**: change from
   `.claude/{skills,agents,commands,rules,context}/` to
   `agent-system/extensions/core/{skills,agents,commands,rules,context}/`. Left as an open question
   for the planner: whether to also special-case non-core extensions (e.g. a task about an
   `email`-domain skill should point at `agent-system/extensions/email/...`, not `core`). The current
   heuristic has no signal to distinguish core vs. extension scope short of parsing which extension
   manifest a keyword belongs to — out of scope to solve fully here; recommend documenting the `core`
   default explicitly and leaving extension-aware disambiguation as a noted limitation rather than
   silently guessing.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Same workspace-trust-dialog blocker (from 873 Phase 5) prevents a headless live end-to-end test of this task's changes | Documented explicitly below — expect the implementation/verification phase to rely on static checks (file content review, `bash -n` on extracted blocks, `diff` confirming source-vs-deploy divergence) plus a **manual verification procedure** for the user to run interactively, mirroring 873's own recorded procedure. Do not fabricate a live-test pass. |
| Over-qualifying paths that were actually Category A (agent's own context loads) could break the agent's ability to load its own reference material if `target_root` is substituted where it shouldn't be | Category A vs. B/C/D classification above is exhaustive over all 47 grep matches; implementation should preserve every Category A line unchanged and only touch B/C/D/E lines. |
| `manage-topics.sh`'s missing `--state` override means any future refactor of that script could silently break the fully-qualified-absolute-path fix if the script's internal `SCRIPT_DIR` logic changes | Out of `file_scope` for this task (script itself is not the edit target) — flagged here for awareness only, not actioned. |
| Reframing the SCOPE BOUNDARY prose could be read as loosening the "never implement directly" rule if worded carelessly | Decisions section above keeps Rule 1 explicitly intact and unweakened; only adds Rule 2 as a new, additional constraint. |

## What Can and Cannot Be Statically Verified

**Can be verified without a human's interactive session** (static, file-content-level):
- That `target_root`/`mode_target` are correctly extracted in Stage 1 and referenced consistently by
  name (`$TARGET_ROOT`) throughout every Category B/C/D location identified above.
- That every Category B/D bash block either qualifies with an absolute `${TARGET_ROOT}`-prefixed path,
  or is part of the single chained `cd "$TARGET_ROOT" && ...` git-commit block (Decision 1) — checked
  by direct text inspection line-by-line, the same way this report's inventory was produced.
  `bash -n` on each extracted bash block for basic syntax validity (mirrors 873's own Phase 1/2
  verification method).
- That the Category C heuristic and worked examples now name `agent-system/extensions/core/**` rather
  than `.claude/**`.
- That the SCOPE BOUNDARY reframing (Decision 3) is present and does not contradict itself, and that
  `grep -rinE '\btasks? [0-9]{2,4}\b' meta-builder-agent.md` introduces no new task-number references
  (matches the sibling files' verification convention from 873).
- That source (`agent-system/extensions/core/agents/meta-builder-agent.md`) and deploy
  (`.claude/agents/meta-builder-agent.md`) diverge after the edit (confirming the edit landed in the
  source store, not the deploy tree) — the same check 873's Phase 4 ran for its three files.

**Cannot be verified without a human's interactive session** (genuinely requires clearing the
workspace-trust dialog):
- An actual live cross-repo `/meta` invocation that reaches `skill-meta` → `meta-builder-agent`
  dispatch, creates a real task, and confirms the task directory, `state.json` entry, and `TODO.md`
  update all land under `~/.config/nvim/specs/` when invoked from a foreign repo's CWD — this is
  exactly the coupling 873's Phase 5 left "fully unverified" and handed to this task, and the same
  headless blocker documented in 873's summary (a non-interactive `claude -p` run cannot clear a
  fresh workspace's trust dialog) applies identically here. If a live test is attempted during
  implementation, it must be reported honestly as attempted/blocked, never inferred as passing.
- Whether the DeliverSummary text's proposed `target_root` header (Category D, line 821 fix)
  renders correctly in the actual interactive UI — text-content correctness can be checked statically,
  but the end-user-facing rendering in a real session cannot.

## Context Extension Recommendations

None — this is a self-contained single-file agent-system fix; no gap in `.claude/context/` was
identified during this research that would benefit future unrelated tasks.

## Appendix

- Commands run: `diff` (precondition check), `grep -n 'specs/\|\.claude/'` (full inventory),
  targeted `Read` of `meta-builder-agent.md` (full file), `skill-meta/SKILL.md` (full file),
  `commands/meta.md` (full file), `validate-meta-write.sh` (full file + diff against deploy copy),
  `generate-todo.sh` and `manage-topics.sh` (path-resolution logic sections only).
- Dependency artifacts read: `specs/873_global_default_target_resolution_for_meta/summaries/01_global-default-target-resolution-summary.md`,
  `specs/873_global_default_target_resolution_for_meta/plans/01_global_default_target_resolution.md`.
