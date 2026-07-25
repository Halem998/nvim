# Implementation Plan: Task #892

- **Task**: 892 - Prevent stale/misplaced .orchestrator-handoff.json reads
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None. (Task 896 touches `scripts/skill-base.sh` as well; serialize file edits
  if both run, but neither is a logical prerequisite of the other.)
- **Research Inputs**: `specs/892_prevent_stale_and_misplaced_orchestrator_handoff_reads/reports/01_stale-misplaced-handoff-reads.md`
- **Artifacts**: plans/01_stale-misplaced-handoff-reads.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The observed defect — the orchestrator reading a previous cycle's handoff while the current
cycle's handoff landed at the repo root — has two independent causes that must not be conflated.
This plan fixes both, adds two detection layers, and records honestly what each layer can and
cannot catch. Phases 1-2 add the two enforcement primitives (an absolute repo-root anchor in
`skill-base.sh`; a `Write|Edit` PostToolUse location hook). Phases 3-6 thread an absolute
`handoff_path` anchor through every instruction and dispatch site so no writer ever has to guess.
Phase 7 adds the mtime-vs-dispatch-window staleness gate and the mechanism-agnostic stray-file
sweep. Phase 8 updates the schema doc so it stops endorsing a relative-only convention.

### BINDING CONSTRAINTS (read before touching anything)

1. **SOURCE-STORE RULE.** The source of truth is `agent-system/extensions/core/` and
   `agent-system/extensions/lean/`. `.claude/` is a GITIGNORED, DISPOSABLE deploy artifact
   regenerated from the source store by the extension picker's "Load Core" sync. **Every edit in
   this plan targets `agent-system/extensions/**` and NEVER `.claude/**`.** If you find yourself
   editing a path beginning `.claude/`, stop — you are editing the wrong copy and your work will
   be erased on the next sync. Reading `.claude/` for comparison is fine; writing is not.
2. **No task-number citations** in any file outside `specs/**`. Do not write "task 892",
   "(tasks 823-824)", or similar into any file this plan modifies. Cite durable anchors instead:
   a filename, a section heading, or the behavior itself.
3. **Line anchors shift.** Every line number in this plan is advisory only. Before every edit,
   locate the target by the **quoted text** given in that phase and confirm it matches. The
   quoted text is authoritative; the line number is a hint. If the quoted text is not found
   verbatim, do NOT guess — grep for the distinctive fragment, re-read the surrounding block,
   and adapt the replacement to what is actually there.

### Research Integration

Carried forward faithfully from the research report:

- **The root cause is DUAL-PATH, not a single bug.**
  - (a) `skill_write_orchestrator_handoff` in `scripts/skill-base.sh` builds a cwd-relative
    handoff path (`specs/${padded_num}_${project_name}/...`) and writes to it via Bash redirect.
    This is a genuine script-layer weakness and is fixed in Phase 1 — but it is **NOT** what
    caused the observed stray. That function is called only by base-mode skills; the agent that
    produced the stray was a hard-mode agent that never calls it.
  - (b) The **actual trigger**: hard-mode write instructions (`context/contracts/wrap-up.md`,
    `agents/general-implementation-hard-agent.md`, `lean/agents/lean-implementation-hard-agent.md`,
    and the dispatch-prompt bullet in `lean/skills/skill-lean-implementation-hard/SKILL.md`) tell
    the agent to write `.orchestrator-handoff.json` with **no directory path anywhere in the
    instruction chain**, while `skill-orchestrate/SKILL.md`'s dispatch sites never pass a
    `task_dir` into the delegation context. The reader knows the scoped path; the writer is never
    told it. Fixed in Phases 3-6.
- **PostToolUse hook viability is PARTIAL, and this was verified honestly.** A `Write|Edit`-matched
  hook IS enforceable and will catch every hard-mode agent-direct write, because Write/Edit tool
  calls always carry a resolved, literal `tool_input.file_path`. It is **STRUCTURALLY BLIND** to
  `skill_write_orchestrator_handoff`'s write: that happens via `jq -n ... > "$handoff_path"` inside
  a `Bash` tool call, whose `tool_input` carries only the **unexpanded** command text — the string
  `"$handoff_path"` appears verbatim and its resolved value is not recoverable by any hook. **Do
  not claim, in code comments, docs, or the summary, that the hook covers the script path.** The
  script path is covered by Phase 1's absolute-path fix plus Phase 7's stray sweep.
- **The staleness check REUSES `dispatch_start_ts`**, already captured via `date -u +%s`
  immediately before all four dispatch sites for infra-failure discrimination, and reuses the
  identical `stat -c %Y` mtime-comparison pattern already present in Stage 5's missing-handoff
  branch. **Do not invent a parallel timestamp mechanism.**
- **`skill-orchestrate-hard/SKILL.md` is IN SCOPE.** It was not in the original component list but
  shares the identical `TASK_DIR` / `handoff_file` / `dispatch_start_ts` shape and would regress
  independently. Phases 6 and 7 cover it in lockstep with the base skill.
- **`general-research-agent.md` and `general-research-hard-agent.md` need NO change.** Both already
  prohibit using the H9 handoff schema for research. Leave the prohibition intact; do not add a
  path instruction there.
- **`lean/context/contracts/anti-analysis.md` needs NO location fix.** It only references the
  `sorry_inventory` field's existence. Leave it alone.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Every handoff writer resolves an absolute destination; none relies on ambient cwd.
- Every dispatched agent receives an absolute `handoff_path` (and `task_dir`) in its delegation
  context.
- A misplaced handoff written via the Write/Edit tool is caught at write time by a hook.
- A misplaced handoff written by ANY mechanism is caught at read time by the orchestrator.
- A correctly-located but out-of-dispatch-window handoff is never trusted as this cycle's result.
- The hook's partial coverage is recorded in the deliverable itself (hook header comment +
  `handoff-schema.md`), not left as tribal knowledge.

**Non-Goals**:
- Fixing `skill_link_artifacts`'s sibling cwd-relativity bug in the same file (separate task).
- Converting `TASK_DIR`, `loop_guard_file`, `churn_file`, or state.json paths to absolute
  throughout `skill-base.sh` — only the handoff path and a new exported anchor are in scope.
- Deploying to `.claude/`. Deployment happens via the extension picker's "Load Core" sync, not
  from this task.
- Adding a `PreToolUse` Bash-matched hook that attempts to parse redirect destinations out of
  shell command text. The research established this cannot be done reliably.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits `.claude/**` instead of `agent-system/extensions/**`; work erased on next sync | H | M | Constraint 1 restated in every phase's Files-to-modify list; Phase 8 verification greps for accidental `.claude/` edits |
| Line anchors shifted; edit lands in the wrong block | H | H | Every phase gives quoted anchor text as authoritative; implementer re-verifies before editing |
| `BASH_SOURCE`-derived repo root is wrong if the file is relocated | M | L | Anchor is `<repo-root>/.claude/scripts/skill-base.sh` = two levels up; documented in an inline comment; `SKILL_REPO_ROOT` is overridable for tests |
| Hook made blocking breaks a legitimate edge case | M | L | Match is on the EXACT basename `.orchestrator-handoff.json` only, never a substring or glob; allowlist covers both `specs/{NNN}_` and `specs/OC_{NNN}_` forms |
| Stray sweep is slow or noisy | L | L | Bounded to two exact paths (repo root, `specs/`), never a recursive `find` |
| Staleness gate misfires when `dispatch_start_ts` is unset | M | L | Fallback `${dispatch_start_ts:-9999999999}` makes an unset window fail CLOSED (treated as stale), matching the existing missing-handoff branch's defaults-to-charging posture |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5, 6 | 1 |
| 3 | 7 | 5, 6 |
| 4 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave touch disjoint files and can execute in parallel.

**Territory (file ownership, no overlap within a wave)**:

| Phase | Owns |
|-------|------|
| 1 | `core/scripts/skill-base.sh` |
| 2 | `core/hooks/validate-handoff-location.sh`, `core/merge-sources/settings-hooks.json`, `core/manifest.json` |
| 3 | `core/context/contracts/wrap-up.md`, `core/agents/general-implementation-hard-agent.md`, `core/skills/skill-implementer-hard/SKILL.md` |
| 4 | `lean/agents/lean-implementation-hard-agent.md`, `lean/skills/skill-lean-implementation-hard/SKILL.md` |
| 5 | `core/skills/skill-orchestrate/SKILL.md` |
| 6 | `core/skills/skill-orchestrate-hard/SKILL.md` |
| 7 | `core/skills/skill-orchestrate/SKILL.md`, `core/skills/skill-orchestrate-hard/SKILL.md` (after 5, 6) |
| 8 | `core/docs/architecture/handoff-schema.md` |

---

### Phase 1: Absolute repo-root anchor in `skill-base.sh` [COMPLETED]

**Goal**: Give `skill-base.sh` a cwd-independent repo-root anchor, export an absolute
`TASK_DIR_ABS` for downstream consumers, and make `skill_write_orchestrator_handoff` write to an
absolute path.

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` — three edits

**Tasks**:

- [x] **Edit 1a — add the repo-root anchor.** Locate the line (advisory ~line 22):
  ```
  SKILL_CONTEXT_BUDGET="${SKILL_CONTEXT_BUDGET:-8000}"
  ```
  Insert immediately AFTER it:
  ```bash

  # ─────────────────────────────────────────────────────────────────────────────
  # REPO ROOT ANCHOR
  # This file is deployed at <repo-root>/.claude/scripts/skill-base.sh, so the repo root is two
  # directories up from this file's own location. Resolving from BASH_SOURCE — rather than from
  # the ambient working directory or `git rev-parse --show-toplevel` — keeps paths built below
  # correct no matter where the caller's shell happens to be, and stays correct inside git
  # worktrees and nested repos where `git rev-parse` answers a different question.
  # Override only in tests.
  SKILL_REPO_ROOT="${SKILL_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  export SKILL_REPO_ROOT
  ```

- [x] **Edit 1b — export an absolute task dir.** In `skill_validate_input`, locate (advisory
  ~line 172):
  ```
    TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
  ```
  Replace with:
  ```bash
    TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
    # Absolute companion to TASK_DIR. TASK_DIR stays relative because many existing consumers
    # depend on its relative form; TASK_DIR_ABS is the anchor to hand to dispatched agents and
    # to build write destinations from.
    TASK_DIR_ABS="${SKILL_REPO_ROOT}/${TASK_DIR}"
  ```
  Then locate the export line a few lines below (advisory ~line 178):
  ```
    export TASK_DATA TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM TASK_DIR
  ```
  Replace with:
  ```bash
    export TASK_DATA TASK_TYPE TASK_STATUS PROJECT_NAME DESCRIPTION PADDED_NUM TASK_DIR TASK_DIR_ABS
  ```

- [x] **Edit 1c — make the handoff write absolute.** In `skill_write_orchestrator_handoff`,
  locate (advisory ~line 513):
  ```
    local handoff_path="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
  ```
  Replace with:
  ```bash
    # ABSOLUTE, not cwd-relative. A bare `specs/...` string written via the Bash redirect below
    # lands wherever the shell's working directory happens to be at call time, which silently
    # strands the handoff outside the task directory and leaves the orchestrator reading the
    # previous cycle's file. SKILL_REPO_ROOT is resolved from BASH_SOURCE at source time.
    local handoff_path="${SKILL_REPO_ROOT}/specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
    mkdir -p "$(dirname "$handoff_path")"
  ```

- [x] **Edit 1d — record the hook's blind spot at the write site.** Locate the closing redirect
  in the same function (advisory ~line 560):
  ```
      }' > "$handoff_path" && \
  ```
  Insert immediately BEFORE the `jq -n \` line that begins the write (advisory ~line 538,
  currently preceded by the comment `# Write handoff JSON`). Replace that comment line:
  ```
    # Write handoff JSON
  ```
  with:
  ```bash
    # Write handoff JSON.
    # NOTE: this is a Bash redirect, not a Write-tool call. The PostToolUse location hook
    # (hooks/validate-handoff-location.sh) reads tool_input.file_path and therefore CANNOT see
    # this write at all — a Bash tool_input carries the unexpanded command text, in which
    # "$handoff_path" appears verbatim and its resolved value is unrecoverable. The absolute
    # path constructed above, plus the orchestrator-side stray sweep in skill-orchestrate
    # Stage 5, are what protect this code path. Do not weaken the absolute anchor on the
    # assumption that the hook is a backstop here; it is not.
  ```

**Timing**: 30 minutes

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` exits 0.
- `grep -n 'SKILL_REPO_ROOT' agent-system/extensions/core/scripts/skill-base.sh` shows the
  definition, the export, the `TASK_DIR_ABS` use, and the `handoff_path` use.
- `grep -n 'local handoff_path=' agent-system/extensions/core/scripts/skill-base.sh` shows a path
  beginning `${SKILL_REPO_ROOT}/`, with no bare-relative `specs/` form remaining.
- Sanity check the anchor arithmetic:
  `bash -c 'BASH_SOURCE_TEST=.claude/scripts/skill-base.sh; cd "$(dirname "$BASH_SOURCE_TEST")/../.." && pwd'`
  run from the repo root prints the repo root.

---

### Phase 2: `validate-handoff-location.sh` PostToolUse hook + registration [COMPLETED]

**Goal**: Catch — at write time — any Write/Edit-tool write of `.orchestrator-handoff.json` that
lands outside a task directory, and record in the hook itself exactly what it cannot catch.

**Depends on**: none

**Files to create/modify**:
- CREATE `agent-system/extensions/core/hooks/validate-handoff-location.sh`
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — add hook entry
- `agent-system/extensions/core/manifest.json` — add to `provides.hooks`

**Planning decision recorded here (was left open by research): the hook exits 2, not advisory.**
Rationale and its honest limit: a `PostToolUse` hook runs *after* the write has already happened,
so `exit 2` does not prevent the file from being created — what it does is surface stderr to the
model as a tool error, forcing acknowledgement and remediation instead of the silently-ignorable
`additionalContext` nudge the meta/plan hooks use. A misplaced handoff has no legitimate
caller-context exception the way `.claude/` writes do inside `/implement`, and the failure is
worse than a missing handoff (it causes a *wrong* read, not a detected absence). The stderr text
therefore must tell the agent to **delete the stray and rewrite at the correct absolute path**.

**Tasks**:

- [x] **Create the hook** at `agent-system/extensions/core/hooks/validate-handoff-location.sh`
  with exactly this content:
  ```bash
  #!/bin/bash
  # PostToolUse hook: reject Write/Edit-tool writes of .orchestrator-handoff.json that land
  # outside a specs/{NNN}_{SLUG}/ task directory.
  #
  # WHY: the handoff is the orchestrator's only channel for learning a dispatch's outcome. A
  # handoff written to a bare filename resolves against the ambient working directory at
  # Write-tool-call time and strands outside the task directory. The orchestrator then finds no
  # handoff at the expected path — or worse, finds the PREVIOUS cycle's file still sitting there
  # and reports its status as if it were this dispatch's result.
  #
  # COVERAGE LIMITATION — DELIBERATE, DO NOT "FIX" BY WIDENING THE MATCHER:
  #   This hook reads tool_input.file_path, which only Write and Edit tool calls carry. It
  #   therefore catches every agent-direct handoff write (the hard-mode wrap-up path — which is
  #   the path that actually broke). It is STRUCTURALLY BLIND to handoff writes performed by
  #   Bash redirection, as skill_write_orchestrator_handoff in scripts/skill-base.sh does via
  #   `jq -n ... > "$handoff_path"`: a Bash tool_input carries the raw, UNEXPANDED command text,
  #   in which "$handoff_path" appears verbatim; its resolved value is not present in the hook
  #   input and cannot be recovered by any amount of pattern matching. Adding a Bash matcher
  #   would produce false confidence, not coverage.
  #   That path is protected instead by (a) skill-base.sh building an absolute path from
  #   SKILL_REPO_ROOT, and (b) the mechanism-agnostic stray-handoff sweep in
  #   skills/skill-orchestrate/SKILL.md Stage 5, which catches a misplaced handoff regardless of
  #   how it was written.
  #
  # Exit 2 (not advisory additionalContext): PostToolUse runs after the write, so this does not
  # prevent the file from existing; it surfaces stderr to the model as an error so the stray is
  # actually removed and rewritten, rather than silently ignored.

  set -uo pipefail

  # Parse file path from stdin (PostToolUse hook input), with env-var fallback.
  if [ -t 0 ]; then
    FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
  else
    INPUT=$(cat)
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    if [ -z "$FILE" ]; then
      FILE=$(printf '%s' "${CLAUDE_TOOL_INPUT:-}" | jq -r '.file_path // empty' 2>/dev/null)
    fi
  fi

  # Early exit for empty path (~1ms on the overwhelming majority of Write/Edit calls).
  if [ -z "$FILE" ]; then
    echo '{}'
    exit 0
  fi

  # EXACT basename match only — never a substring or glob. A file merely *containing* the string
  # (say, a doc or a test fixture named handoff-example.json) is none of this hook's business.
  if [ "$(basename "$FILE")" != ".orchestrator-handoff.json" ]; then
    echo '{}'
    exit 0
  fi

  # Allowed shapes, absolute or relative:
  #   specs/{NNN}_{SLUG}/.orchestrator-handoff.json      (Claude Code tasks)
  #   specs/OC_{NNN}_{SLUG}/.orchestrator-handoff.json   (OpenCode tasks)
  if printf '%s' "$FILE" | grep -Eq '(^|/)specs/(OC_)?[0-9]{3}_[^/]+/\.orchestrator-handoff\.json$'; then
    echo '{}'
    exit 0
  fi

  cat >&2 << EOF
  MISPLACED ORCHESTRATOR HANDOFF: $FILE

  .orchestrator-handoff.json must be written INSIDE its own task directory:
    specs/{NNN}_{SLUG}/.orchestrator-handoff.json

  A handoff written anywhere else is invisible to the orchestrator, which will then either
  report a missing handoff or — worse — read the previous cycle's leftover file and report its
  status as this dispatch's result.

  Remediate now, in this order:
    1. Delete the file you just wrote at $FILE.
    2. Re-write it at the ABSOLUTE path supplied in your delegation context as 'handoff_path'
       (or '{task_dir}/.orchestrator-handoff.json' using the absolute 'task_dir').
    3. If neither field is present in your delegation context, do NOT guess a path — say so
       explicitly in your final message so the orchestrator can detect the gap.

  Never write a bare '.orchestrator-handoff.json' filename: it resolves against whatever the
  ambient working directory happens to be when the Write tool runs.
  EOF

  exit 2
  ```
  Note for the implementer: the `cat >&2 << EOF` heredoc body above is indented for readability
  inside this plan. In the actual file, the heredoc body and its terminating `EOF` must start at
  column 0 (unquoted `EOF`, so `$FILE` interpolates). Verify with `bash -n`.

- [x] **Register in `merge-sources/settings-hooks.json`.** Locate the existing `PostToolUse` block:
  ```json
      "PostToolUse": [
        {
          "matcher": "Write|Edit",
          "hooks": [
            { "type": "command", "command": "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'" }
          ]
        }
      ]
  ```
  Replace the `hooks` array with:
  ```json
          "hooks": [
            { "type": "command", "command": "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'" },
            { "type": "command", "command": "bash .claude/hooks/validate-handoff-location.sh" }
          ]
  ```
  **Note the deliberate asymmetry**: the new entry has NO `2>/dev/null || echo '{}'` suffix. That
  suffix is what makes the sibling hooks advisory — it swallows stderr and forces exit 0. This
  hook's entire purpose is to surface stderr and exit 2, so the suffix must be omitted.

- [x] **Register in `manifest.json`.** In `provides.hooks`, insert `"validate-handoff-location.sh"`
  in alphabetical position — immediately BEFORE `"validate-meta-write.sh"`.

**Timing**: 40 minutes

**Verification**:
- `bash -n agent-system/extensions/core/hooks/validate-handoff-location.sh` exits 0.
- `jq empty agent-system/extensions/core/merge-sources/settings-hooks.json` exits 0.
- `jq -e '.provides.hooks | index("validate-handoff-location.sh")' agent-system/extensions/core/manifest.json`
  exits 0.
- Positive case (must exit 0, print `{}`):
  ```bash
  echo '{"tool_input":{"file_path":"specs/892_foo/.orchestrator-handoff.json"}}' \
    | bash agent-system/extensions/core/hooks/validate-handoff-location.sh; echo "exit=$?"
  ```
- Absolute positive case (must exit 0):
  ```bash
  echo '{"tool_input":{"file_path":"/home/u/repo/specs/007_bar/.orchestrator-handoff.json"}}' \
    | bash agent-system/extensions/core/hooks/validate-handoff-location.sh; echo "exit=$?"
  ```
- OpenCode positive case (must exit 0):
  ```bash
  echo '{"tool_input":{"file_path":"specs/OC_012_baz/.orchestrator-handoff.json"}}' \
    | bash agent-system/extensions/core/hooks/validate-handoff-location.sh; echo "exit=$?"
  ```
- Negative case (must exit 2 with the remediation text on stderr):
  ```bash
  echo '{"tool_input":{"file_path":".orchestrator-handoff.json"}}' \
    | bash agent-system/extensions/core/hooks/validate-handoff-location.sh; echo "exit=$?"
  ```
- Unrelated-file case (must exit 0):
  ```bash
  echo '{"tool_input":{"file_path":"lua/foo.lua"}}' \
    | bash agent-system/extensions/core/hooks/validate-handoff-location.sh; echo "exit=$?"
  ```

---

### Phase 3: Core hard-mode write instructions state the absolute path [COMPLETED]

**Goal**: Every core-extension instruction that tells an agent to write the handoff names an
absolute anchor, and `skill-implementer-hard` supplies that anchor in its delegation context.

**Depends on**: 1 (consumes `SKILL_REPO_ROOT`)

**Files to modify**:
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`

**Tasks**:

- [x] **Edit 3a — `wrap-up.md`.** Locate (advisory ~line 14, under `## Orchestrator Handoff JSON
  Schema`):
  ```
  Every hard-mode implementation dispatch MUST write `.orchestrator-handoff.json` before
  terminating. Maximum 400 tokens. Required fields:
  ```
  Replace with:
  ```markdown
  Every hard-mode implementation dispatch MUST write the orchestrator handoff before
  terminating. Maximum 400 tokens.

  ### Write location — absolute path, never a bare filename

  Write to the ABSOLUTE path supplied in your delegation context as `handoff_path`. If
  `handoff_path` is absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute
  `task_dir` from your delegation context. If BOTH are absent, STOP and report the missing
  anchor in your final message — do not guess.

  A bare `.orchestrator-handoff.json` filename resolves against whatever the ambient working
  directory happens to be when the Write tool runs. The file then lands outside the task
  directory, and the orchestrator either sees no handoff or reads the PREVIOUS cycle's leftover
  and reports its status as this dispatch's result. That silent wrong-answer failure is worse
  than a missing handoff.

  A `PostToolUse` hook (`hooks/validate-handoff-location.sh`) rejects Write/Edit calls whose
  destination is not `specs/{NNN}_{SLUG}/.orchestrator-handoff.json`. Treat that rejection as a
  hard error: delete the stray file, then rewrite at the correct absolute path.

  Required fields:
  ```

- [x] **Edit 3b — `general-implementation-hard-agent.md`.** Locate (advisory ~line 253):
  ```
  **Step 1: Write `.orchestrator-handoff.json`**

  Always write this file, even on successful completion:
  ```
  Replace with:
  ```markdown
  **Step 1: Write the orchestrator handoff**

  Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is
  absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute `task_dir` from your
  delegation context. If neither field is present, STOP and say so in your final message rather
  than guessing.

  NEVER write a bare `.orchestrator-handoff.json` filename. It resolves against the ambient
  working directory at Write-tool-call time and strands the handoff outside the task directory,
  where the orchestrator will instead read the previous cycle's leftover file. See
  `context/contracts/wrap-up.md`, "Write location", for the full rule.

  Always write this file, even on successful completion:
  ```

- [x] **Edit 3c — `skill-implementer-hard/SKILL.md`, absolute task dir.** Locate (advisory
  ~line 129):
  ```
    task_dir="specs/${padded_num}_${project_name}"
  ```
  (the occurrence inside the `if [ "$orchestrator_mode" = "true" ]` block in Stage 3b, directly
  above the comment beginning `# Fixed: was the un-scoped`). Replace with:
  ```bash
    task_dir="specs/${padded_num}_${project_name}"
    # Absolute anchor handed to the dispatched agent so it never has to resolve a bare filename
    # against the ambient working directory. SKILL_REPO_ROOT is exported by skill-base.sh when
    # sourced; $(pwd) is a last-resort fallback for direct invocation.
    task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/${padded_num}_${project_name}"
    handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"
  ```

- [x] **Edit 3d — `skill-implementer-hard/SKILL.md`, delegation context.** Locate (advisory
  ~line 221) in the delegation-context JSON block:
  ```
    "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
  ```
  Replace with:
  ```json
    "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
    "task_dir": "{task_dir_abs — ABSOLUTE path to the task directory}",
    "handoff_path": "{handoff_path_abs — ABSOLUTE path the agent MUST write its handoff to}"
  ```

- [x] **Edit 3e — `skill-implementer-hard/SKILL.md`, dispatch prompt.** Locate (advisory ~line 243)
  in Stage 5:
  ```
    - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
  ```
  Replace with:
  ```
    - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
  ```
  and insert immediately after the closing ``` of that code block:
  ```markdown
  The prompt MUST state the handoff destination explicitly, not leave it to the agent to infer:
  "Write your orchestrator handoff to the ABSOLUTE path `{handoff_path_abs}`. Never write a bare
  `.orchestrator-handoff.json` filename."
  ```

**Timing**: 35 minutes

**Verification**:
- `grep -n 'handoff_path' agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
  shows the new `handoff_path_abs` assignment, the delegation-context field, and the prompt line.
- `grep -n 'Write location' agent-system/extensions/core/context/contracts/wrap-up.md` matches.
- `grep -rn 'task 8\|task 9\|(task ' agent-system/extensions/core/context/contracts/wrap-up.md
  agent-system/extensions/core/agents/general-implementation-hard-agent.md` returns no new
  task-number citations introduced by this phase.
- No file under `.claude/` was modified: `git status --short .claude/` (should be empty or
  pre-existing only; `.claude/` is gitignored, so also confirm no edits were attempted there).

---

### Phase 4: Lean hard-mode write instructions state the absolute path [COMPLETED]

**Goal**: Same fix as Phase 3, applied to the lean extension — including the dispatch-prompt
bullet that is the literal text the lean phase agent receives.

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`

**Tasks**:

- [x] **Edit 4a — `lean-implementation-hard-agent.md`.** Locate (advisory ~line 259):
  ```
  **Step 1: Write `.orchestrator-handoff.json`** (always, even on success):
  ```
  Replace with:
  ```markdown
  **Step 1: Write the orchestrator handoff** (always, even on success):

  Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is
  absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute `task_dir` from your
  delegation context. If neither is present, STOP and say so in your final message rather than
  guessing.

  NEVER write a bare `.orchestrator-handoff.json` filename. It resolves against the ambient
  working directory at Write-tool-call time and strands the handoff outside the task directory,
  where the orchestrator will read the previous cycle's leftover file instead. See
  `context/contracts/wrap-up.md`, "Write location", for the full rule.
  ```

- [x] **Edit 4b — `skill-lean-implementation-hard/SKILL.md`, dispatch bullet.** This is the
  load-bearing one: it is the literal text injected into the Agent-tool `prompt`. Locate
  (advisory ~line 178):
  ```
  - Write `.orchestrator-handoff.json` with sorry_inventory
  ```
  Replace with:
  ```markdown
  - Write the orchestrator handoff (with sorry_inventory) to the ABSOLUTE path given as
    `handoff_path` in the delegation context — never a bare `.orchestrator-handoff.json` filename
  ```

- [x] **Edit 4c — `skill-lean-implementation-hard/SKILL.md`, delegation context.** Locate
  (advisory ~line 148):
  ```
    "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json"
  ```
  Replace with:
  ```json
    "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json",
    "task_dir": "{ABSOLUTE path to the task directory}",
    "handoff_path": "{ABSOLUTE path the agent MUST write its handoff to}"
  ```

- [x] **Edit 4d — `skill-lean-implementation-hard/SKILL.md`, resolve the absolute anchor.** Locate
  (advisory ~line 97):
  ```
  padded_num=$(printf "%03d" "$task_number")
  ```
  Insert immediately after:
  ```bash
  # Absolute anchor handed to the dispatched agent. SKILL_REPO_ROOT is exported by skill-base.sh
  # when sourced; $(pwd) is a last-resort fallback for direct invocation.
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/${padded_num}_${project_name}"
  handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"
  ```

- [x] **Edit 4e — `skill-lean-implementation-hard/SKILL.md`, read sites.** Locate (advisory
  ~line 113):
  ```
  handoff_file=$(ls "specs/${padded_num}_${project_name}/.orchestrator-handoff.json" 2>/dev/null | head -1)
  ```
  Replace with:
  ```bash
  handoff_file=$(ls "${handoff_path_abs}" 2>/dev/null | head -1)
  ```
  Then locate (advisory ~line 257):
  ```
  handoff_file="specs/${padded_num}_${project_name}/.orchestrator-handoff.json"
  ```
  Replace with:
  ```bash
  handoff_file="${handoff_path_abs}"
  ```
  Leave the occurrence in the artifact/staging path list (advisory ~line 328) as a relative path —
  those entries are repo-relative by design.

- [x] **Edit 4f — dispatch prompt.** Locate (advisory ~line 164):
  ```
    - prompt: [Include task_context, delegation_context, plan_path, phase_number,
               territory, continuation_context, metadata_file_path]
  ```
  Replace with:
  ```
    - prompt: [Include task_context, delegation_context, plan_path, phase_number,
               territory, continuation_context, metadata_file_path, handoff_path]
  ```

**Timing**: 35 minutes

**Verification**:
- `grep -n 'handoff_path_abs\|handoff_path' agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
  shows the assignment, both read sites, the delegation-context field, the prompt list, and the
  dispatch bullet.
- `grep -n 'orchestrator-handoff' agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
  shows no remaining bare-relative `specs/${padded_num}...` read path except the staging list.
- No `.claude/` file was edited.

---

### Phase 5: Thread the absolute anchor through `skill-orchestrate/SKILL.md` [COMPLETED]

**Goal**: The base orchestrator resolves an absolute task dir and hands `task_dir` +
`handoff_path` to every dispatched agent.

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`

**Tasks**:

- [x] **Edit 5a — Stage 1a, resolve the absolute anchor.** Locate (advisory ~line 55):
  ```
  Extract: `PROJECT_NAME`, `TASK_TYPE` (default: "general"), `DESCRIPTION`, `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`.
  ```
  Replace with:
  ```markdown
  Extract: `PROJECT_NAME`, `TASK_TYPE` (default: "general"), `DESCRIPTION`, `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`.

  Then resolve the absolute anchor that every dispatched agent will be handed. `TASK_DIR` stays
  relative (many consumers below depend on that); `TASK_DIR_ABS` is the anchor that goes into
  delegation contexts, because a dispatched agent has no reliable way to know what the ambient
  working directory will be when its Write tool runs.

  ```bash
  # SKILL_REPO_ROOT is exported by skill-base.sh, which resolves it from BASH_SOURCE rather than
  # from the ambient cwd. $(pwd) is a last-resort fallback for direct invocation.
  TASK_DIR_ABS="${TASK_DIR_ABS:-${SKILL_REPO_ROOT:-$(pwd)}/${TASK_DIR}}"
  HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
  ```
  ```

- [x] **Edit 5b — absolute handoff read path.** Locate (advisory ~line 111):
  ```
  handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  ```
  Replace with:
  ```bash
  # Absolute: this must name the same file the dispatched agent was told to write, and that
  # instruction is absolute. Comparing a relative read path against an absolute write path is how
  # a misplaced handoff goes unnoticed.
  handoff_file="${HANDOFF_PATH_ABS}"
  ```
  Leave `loop_guard_file` relative — out of scope.

- [x] **Edit 5c — the four single-task dispatch contexts.** Each is a table row of the form
  `| `context` | `{ ... }` |`. Add `task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS` to
  each. The four exact current values (advisory lines 245, 293, 333, 382):

  1. `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag }`
     -> `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }`
  2. `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag }`
     -> `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }`
  3. `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, lit_flag }`
     -> `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }`
  4. `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, continuation_context, lit_flag }`
     -> `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, continuation_context, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }`

- [x] **Edit 5d — the revise re-dispatch context.** Locate (advisory ~line 659):
  ```
  | `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path }` |
  ```
  Replace with:
  ```
  | `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS }` |
  ```

- [x] **Edit 5e — the three multi-task dispatch contexts.** In the multi-task section (advisory
  ~lines 900-925), add a per-task absolute anchor and thread it. First, in the `For each task in
  research_tasks:` list, insert a new first bullet before the existing `- Record the dispatch
  window:` bullet — and do the same for `plan_tasks` and `implement_tasks`:
  ```markdown
  - Resolve this task's absolute anchor: `task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/$(printf '%03d' "$task_num")_${project_name}"` and `handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"`
  ```
  Then append `, task_dir: task_dir_abs, handoff_path: handoff_path_abs` inside the closing brace
  of each of the three `context = { ... }` values (advisory lines 907, 913, 920).

**Timing**: 40 minutes

**Verification**:
- `grep -c 'handoff_path: HANDOFF_PATH_ABS' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns 5 (four single-task sites + the revise re-dispatch).
- `grep -c 'handoff_path: handoff_path_abs' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  returns 3 (multi-task sites).
- `grep -n 'handoff_file=' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` shows
  `${HANDOFF_PATH_ABS}` and no bare `${TASK_DIR}/.orchestrator-handoff.json`.
- `grep -n 'TASK_DIR_ABS' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` shows
  the Stage 1a resolution.

---

### Phase 6: Thread the absolute anchor through `skill-orchestrate-hard/SKILL.md` [COMPLETED]

**Goal**: Identical treatment for the hard-mode orchestrator, so it cannot regress independently.

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`

**Tasks**:

- [x] **Edit 6a — resolve the absolute anchor.** Locate (advisory ~line 115):
  ```
  TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
  ```
  Replace with:
  ```bash
  TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"
  # Absolute companion. TASK_DIR stays relative for existing consumers; TASK_DIR_ABS is the
  # anchor handed to dispatched agents, which cannot know the ambient working directory their
  # Write tool will resolve against. SKILL_REPO_ROOT is exported by skill-base.sh.
  TASK_DIR_ABS="${TASK_DIR_ABS:-${SKILL_REPO_ROOT:-$(pwd)}/${TASK_DIR}}"
  HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
  ```

- [x] **Edit 6b — absolute handoff read path.** Locate (advisory ~line 199):
  ```
  handoff_file="${TASK_DIR}/.orchestrator-handoff.json"
  ```
  Replace with:
  ```bash
  # Absolute: must name the same file the dispatched agent was told to write.
  handoff_file="${HANDOFF_PATH_ABS}"
  ```
  Leave `loop_guard_file` and `churn_file` relative — out of scope.

- [x] **Edit 6c — research dispatch context.** Locate (advisory ~line 350):
  ```
    delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true}
  ```
  Replace with:
  ```
    delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS}
  ```

- [x] **Edit 6d — H4 adversarial-verification re-dispatch context.** Locate (advisory ~line 397):
  ```
          delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit"}
  ```
  Replace with:
  ```
          delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS}
  ```

- [x] **Edit 6e — plan dispatch context.** Locate (advisory ~line 428):
  ```
      delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, ...}
  ```
  Replace with:
  ```
      delegation_context: {task_number, session_id, effort_flag: "hard", orchestrator_mode: true, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, ...}
  ```

- [x] **Edit 6f — implement dispatch context object.** Locate the `dispatch_context` heredoc
  (advisory ~line 476):
  ```
      "plan_path": "'$plan_path'",
      "phase_number": '$next_phase'
    }'
  ```
  Replace with:
  ```bash
      "plan_path": "'$plan_path'",
      "phase_number": '$next_phase',
      "task_dir": "'$TASK_DIR_ABS'",
      "handoff_path": "'$HANDOFF_PATH_ABS'"
    }'
  ```

**Timing**: 30 minutes

**Verification**:
- `grep -c 'HANDOFF_PATH_ABS' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  returns at least 6 (definition, `handoff_file`, four dispatch sites).
- `grep -n 'handoff_file=' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  shows `${HANDOFF_PATH_ABS}`.
- `grep -n 'delegation_context:' agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  shows `handoff_path` on every line.

---

### Phase 7: Staleness gate and stray-handoff sweep in both orchestrators [NOT STARTED]

**Goal**: At read time, refuse to trust a handoff that predates the current dispatch window, and
detect a misplaced handoff regardless of which mechanism wrote it.

**Depends on**: 5, 6

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`

The same two blocks go into both files; only the log prefix differs (`[orchestrate]` in the base
skill, `[hard-orchestrate]` in the hard skill).

**Tasks**:

- [ ] **Edit 7a — base skill, insert the gate before the existing branch.** In Stage 5, locate
  (advisory ~line 445):
  ```bash
  # Reset the per-cycle exemption flag before any branch can set it.
  infra_exempt_cycle=false

  if [ ! -f "$handoff_file" ]; then
  ```
  Replace with:
  ```bash
  # Reset the per-cycle exemption flag before any branch can set it.
  infra_exempt_cycle=false

  # ── Staleness gate ────────────────────────────────────────────────────────────
  # A handoff sitting at the correct path does NOT prove this dispatch wrote it. If the current
  # dispatch wrote nothing (or wrote somewhere else), the PREVIOUS cycle's file is still there,
  # and reading it reports the previous cycle's status and phases_completed as if they were this
  # one's — a silent wrong answer, worse than a detected absence.
  #
  # Reuse the dispatch window already captured for infra-failure discrimination: dispatch_start_ts
  # is set via `date -u +%s` immediately before every Agent tool call above. This is the same
  # stat/compare technique the missing-handoff branch below already applies to .return-meta.json,
  # pointed at a second file. No new timestamp mechanism.
  #
  # Fail-closed: an unset dispatch_start_ts yields 9999999999, so a dispatch site that forgot to
  # set its window marks the handoff stale rather than trusting it — matching the missing-handoff
  # branch's defaults-to-charging posture below.
  handoff_stale=false
  if [ -f "$handoff_file" ]; then
    stale_window_start="${dispatch_start_ts:-9999999999}"
    handoff_mtime=$(stat -c %Y "$handoff_file" 2>/dev/null || stat -f %m "$handoff_file" 2>/dev/null || echo 0)
    if [ "$handoff_mtime" -lt "$stale_window_start" ]; then
      handoff_stale=true
      echo "[orchestrate] ERROR: STALE HANDOFF — $handoff_file has mtime $handoff_mtime, older than this dispatch window ($stale_window_start)." >&2
      echo "[orchestrate] This dispatch did not write it. Treating as a missing handoff, not a successful read." >&2
    fi
  fi

  # ── Stray-handoff sweep ───────────────────────────────────────────────────────
  # Mechanism-agnostic backstop. The validate-handoff-location.sh PostToolUse hook catches
  # Write/Edit-tool misplacements, but it is structurally unable to see a Bash-redirect write
  # (skill_write_orchestrator_handoff writes via `jq -n ... > "$handoff_path"`; a Bash tool_input
  # carries unexpanded command text, so the resolved destination is never visible to a hook).
  # This sweep catches a misplaced handoff no matter how it was written.
  #
  # Deliberately bounded to two exact paths — the repo root and specs/ — not a recursive find.
  # Those are the two places an unanchored write actually lands.
  sweep_root="${SKILL_REPO_ROOT:-$(pwd)}"
  for stray in "${sweep_root}/.orchestrator-handoff.json" "${sweep_root}/specs/.orchestrator-handoff.json"; do
    if [ -e "$stray" ]; then
      echo "[orchestrate] ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
      echo "[orchestrate] The correct destination is $handoff_file." >&2
      # Move aside rather than delete: preserves the evidence while ensuring no later
      # cwd-relative read can pick it up.
      mv "$stray" "${TASK_DIR}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
        && echo "[orchestrate] Stray moved into ${TASK_DIR}/ for inspection." >&2 \
        || echo "[orchestrate] WARNING: could not move stray aside; remove it manually before the next cycle." >&2
    fi
  done

  if [ ! -f "$handoff_file" ] || [ "$handoff_stale" = "true" ]; then
  ```

- [ ] **Edit 7b — base skill, make the branch message accurate for both cases.** Immediately
  inside that branch, locate:
  ```bash
    echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
    echo "This may mean orchestrator_mode was not propagated correctly."
  ```
  Replace with:
  ```bash
    if [ "$handoff_stale" = "true" ]; then
      echo "[orchestrate] ERROR: Skill did not write a handoff for THIS dispatch (a stale one from an earlier cycle is present)."
    else
      echo "[orchestrate] ERROR: Skill did not write orchestrator handoff."
    fi
    echo "This may mean orchestrator_mode was not propagated correctly, or the handoff was written outside the task directory."
  ```
  Leave the `window_start="${dispatch_start_ts:-9999999999}"` assignment further down in this
  branch exactly as it is — it is a harmless idempotent re-assignment and rewriting it risks
  disturbing the infra-failure logic, which is not in scope.

- [ ] **Edit 7c — hard skill, same two blocks.** Apply Edits 7a and 7b to
  `skill-orchestrate-hard/SKILL.md` at its analogous Stage 5 block (advisory ~line 680), anchored
  on the identical quoted text:
  ```bash
  # Reset the per-cycle exemption flag before any branch can set it.
  infra_exempt_cycle=false

  if [ ! -f "$handoff_file" ]; then
    echo "[hard-orchestrate] ERROR: Skill did not write orchestrator handoff."
  ```
  Use the `[hard-orchestrate]` prefix throughout the inserted blocks instead of `[orchestrate]`.
  Everything else is byte-identical.

**Timing**: 45 minutes

**Verification**:
- `grep -c 'STALE HANDOFF' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns
  1; same for the hard skill.
- `grep -c 'STRAY HANDOFF' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` returns
  1; same for the hard skill.
- `grep -n 'handoff_stale' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` shows
  the initialization, the assignment, the branch condition, and the message fork.
- Both files' inserted bash blocks parse: extract each fenced ```bash block containing
  `handoff_stale` and run `bash -n` on it.
- Confirm the sweep comment states the hook's blind spot: `grep -n 'structurally unable'
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` matches.

---

### Phase 8: Document the contract in `handoff-schema.md` and run final verification [NOT STARTED]

**Goal**: The schema doc records the absolute-path requirement, both write mechanisms, the hook's
exact coverage boundary, and the reader-side freshness rule — so the limitation lives in the
deliverable rather than in this plan alone.

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`

**Tasks**:

- [ ] **Edit 8a — add the write/read contract.** Locate (advisory ~line 5):
  ```
  **File location**: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (runtime; not checked in)
  ```
  Insert immediately AFTER the `**See Also**:` line that follows the header block (advisory
  ~line 9), so the new section sits above the Dual-Consumer Note:
  ```markdown

  ## Path Resolution Contract

  **Writers MUST use an absolute path.** A bare `.orchestrator-handoff.json` filename resolves
  against whatever the ambient working directory happens to be at write time, stranding the file
  outside the task directory. The orchestrator then either reports a missing handoff or — worse —
  reads the previous cycle's leftover file and reports its status as the current dispatch's
  result.

  Two independent write mechanisms exist. Both are anchored absolutely, by different means:

  | Mechanism | Anchor | Enforcement |
  |-----------|--------|-------------|
  | `skill_write_orchestrator_handoff` (`scripts/skill-base.sh`) — Bash redirect | `${SKILL_REPO_ROOT}/specs/{NNN}_{SLUG}/...`, with `SKILL_REPO_ROOT` resolved from `BASH_SOURCE` | Script-layer construction only. The PostToolUse hook CANNOT see this write. |
  | Hard-mode agent direct write — Write tool | `handoff_path` (absolute) supplied in the delegation context, with absolute `task_dir` as fallback | `hooks/validate-handoff-location.sh` (PostToolUse, matcher `Write\|Edit`) rejects out-of-tree destinations with exit 2 |

  **Hook coverage is deliberately partial, and this is not a defect to be fixed by widening the
  matcher.** `validate-handoff-location.sh` reads `tool_input.file_path`, a field only `Write` and
  `Edit` calls carry. A Bash-redirect write exposes only the raw, unexpanded command text — the
  redirect target appears as the literal string `"$handoff_path"`, and its resolved value is not
  present in the hook input at all. No pattern-matching strategy can recover it. The hook is
  therefore complete coverage for agent-direct writes and zero coverage for script writes; the
  orchestrator-side stray-handoff sweep (`skill-orchestrate` and `skill-orchestrate-hard`,
  Stage 5) is the mechanism-agnostic backstop for the latter.

  **Readers MUST check freshness.** A handoff at the correct path is not necessarily *this
  dispatch's* handoff. Both orchestrators compare the file's mtime against `dispatch_start_ts` —
  the same dispatch window already captured for infra-failure discrimination — and treat an
  out-of-window handoff exactly as they treat a missing one.
  ```

- [ ] **Edit 8b (optional cleanup, same file).** Line 3 currently reads
  `**Status**: Current architecture — designed by Task 592, implemented by Task 596.` This is a
  pre-existing violation of the no-task-references-in-deliverables rule (this file lives outside
  `specs/**`). Since the file is already being edited, replace with:
  ```markdown
  **Status**: Current architecture.
  ```
  Do not chase the same pattern into other files; that is a separate cleanup.

- [ ] **Final cross-cutting verification** (run all of these from the repo root):
  - No `.claude/` file was modified by this task. `.claude/` is gitignored, so `git status` will
    not show it; instead confirm by reviewing the implementer's own list of modified files —
    every entry must begin `agent-system/extensions/` or `specs/`.
  - No new task-number citations outside `specs/**`:
    ```bash
    git diff --stat -- agent-system/ && git diff -- agent-system/ | grep -nE '^\+.*\b[Tt]ask [0-9]{2,4}\b'
    ```
    must produce no matches.
  - Every writer-instruction site now names an absolute anchor:
    ```bash
    grep -rn 'orchestrator-handoff' \
      agent-system/extensions/core/context/contracts/wrap-up.md \
      agent-system/extensions/core/agents/general-implementation-hard-agent.md \
      agent-system/extensions/lean/agents/lean-implementation-hard-agent.md \
      agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md
    ```
    Confirm each write instruction is accompanied by `handoff_path` / absolute-path language.
  - `bash -n` passes on `skill-base.sh` and `validate-handoff-location.sh`.
  - `jq empty` passes on `settings-hooks.json` and `manifest.json`.

**Timing**: 30 minutes

**Verification**:
- `grep -n 'Path Resolution Contract' agent-system/extensions/core/docs/architecture/handoff-schema.md`
  matches.
- `grep -n 'structurally\|CANNOT see this write\|not present in the hook input' agent-system/extensions/core/docs/architecture/handoff-schema.md`
  matches — the limitation is recorded in the deliverable.
- All final cross-cutting checks above pass.

---

## Testing & Validation

- [ ] `bash -n` passes on `agent-system/extensions/core/scripts/skill-base.sh`.
- [ ] `bash -n` passes on `agent-system/extensions/core/hooks/validate-handoff-location.sh`.
- [ ] `jq empty` passes on `merge-sources/settings-hooks.json` and `core/manifest.json`.
- [ ] The hook exits 0 for all four allowed shapes (relative `specs/{NNN}_`, absolute
      `specs/{NNN}_`, `specs/OC_{NNN}_`, and unrelated files) and exits 2 with remediation text
      for a bare `.orchestrator-handoff.json`.
- [ ] `skill_write_orchestrator_handoff`'s `handoff_path` begins `${SKILL_REPO_ROOT}/`.
- [ ] All four base-orchestrator dispatch contexts, the revise re-dispatch, and the three
      multi-task dispatch contexts carry `task_dir` and `handoff_path`.
- [ ] All four hard-orchestrator dispatch contexts carry `task_dir` and `handoff_path`.
- [ ] Both orchestrators' Stage 5 contains the staleness gate and the stray sweep, and the
      staleness gate reuses `dispatch_start_ts` (no new timestamp variable is introduced —
      `grep` for any newly-added `date -u +%s` in Stage 5 must find none).
- [ ] The hook's partial coverage is stated in three places: the hook file header, the
      `skill-base.sh` write-site comment, and `handoff-schema.md`.
- [ ] No file under `.claude/` was written. No task-number citation was added outside `specs/**`.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/skill-base.sh`
- Created: `agent-system/extensions/core/hooks/validate-handoff-location.sh`
- Modified: `agent-system/extensions/core/merge-sources/settings-hooks.json`
- Modified: `agent-system/extensions/core/manifest.json`
- Modified: `agent-system/extensions/core/context/contracts/wrap-up.md`
- Modified: `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- Modified: `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- Modified: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- Modified: `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- Modified: `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- Modified: `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- Summary: `specs/892_prevent_stale_and_misplaced_orchestrator_handoff_reads/summaries/01_stale-misplaced-handoff-reads-summary.md`

Deployment to `.claude/` is out of scope and happens separately via the extension picker's
"Load Core" sync.

## Rollback/Contingency

All changes are additive text edits inside `agent-system/extensions/**`, committed per phase. To
revert any single phase, `git revert` that phase's commit — no phase depends on another's runtime
state, only on its text.

Highest-risk item to roll back independently is Phase 2's hook registration: if
`validate-handoff-location.sh` proves too aggressive in practice, remove only its entry from
`merge-sources/settings-hooks.json` (leaving the script file in place) and re-sync. Every other
protection in this plan — the absolute anchors, the staleness gate, and the stray sweep —
continues to function without it, which is the point of the layered design: the hook is the
fastest-feedback layer, never the only one.
