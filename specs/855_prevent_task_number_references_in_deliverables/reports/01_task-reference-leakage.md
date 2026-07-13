Task: 855 - Prevent task-number references in deliverable files
Started: 2026-07-13T00:00:00Z
Completed: 2026-07-13T19:30:00Z
Effort: 3-5 hours
Dependencies: None
Sources/Inputs: - Codebase (.claude/rules/, .claude/hooks/, .claude/settings.json, .claude/agents/, .claude/skills/, .claude/context/, .claude/extensions/nvim/, .claude/extensions/core/merge-sources/, lua/neotex/plugins/ai/), grep tests of the proposed regex
Artifacts: - specs/855_prevent_task_number_references_in_deliverables/reports/01_task-reference-leakage.md
Standards: report-format.md, subagent-return.md

## Executive Summary

- All four enforcement layers are buildable with **zero further discovery** — exact insertion
  anchors, file contents, and a grep-tested regex are provided below.
- The regex `\btasks?[[:space:]]+[0-9]` (case-insensitive) passes all 9 required positive cases
  and all 14 required-negative cases with **zero false positives**. A refined variant
  `\btasks?[:,]?[[:space:]]+[0-9]` additionally catches `tasks: 823, 824` (colon-before-number)
  at no cost to the negative set — recommend the refined variant.
- **Critical finding**: `.claude/hooks/validate-meta-write.sh` exists on disk, is documented in
  four places as "wired," and is listed in `manifest.json`'s `provides.hooks` — but it is **NOT
  actually present in the deployed `PostToolUse` array of `.claude/settings.json`**. This is
  direct proof that `provides.hooks` (manifest.json) only controls **file-copy** during
  extension deployment; it does **not** wire a hook into `settings.json`'s trigger tables. The
  new hook (Layer 2) must be added to `.claude/settings.json` explicitly, by hand, or it will
  silently never fire — exactly like `validate-meta-write.sh` today.
- `.claude/CLAUDE.md` is confirmed auto-generated; its "Rules References" section is sourced
  from `.claude/extensions/core/merge-sources/claudemd.md` (lines 441-451), which is merged in
  by `lua/neotex/plugins/ai/claude/extensions/merge.lua` (mirrored in
  `lua/neotex/plugins/ai/shared/extensions/merge.lua`) during the picker's sync/"Load Core"
  operation. The new rule must be added there, not to the deployed CLAUDE.md directly.
- The two `documentation-policy.md` copies are byte-identical today. The `.claude/extensions/nvim/`
  copy is canonical (source); `.claude/context/project/neovim/` is the deployed copy, per the
  standard "Context copied to `.claude/context/`" extension-deployment pattern. Both must be
  edited identically in the same commit since a sync would otherwise silently overwrite the
  deployed copy from the (then out-of-date) source, or leave them diverged until the next sync.
- Real-world scope of the leak is worse than the single example in the task description:
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` contains at least
  9 distinct task-number citations (`task 805`, `task 820` x3, `task 827`, `task 852` x2,
  `task 854` x2) accumulated across 8+ historical commits. Retroactive cleanup is explicitly
  out of scope per the task description; this is noted only to calibrate the size of the
  problem and justify prioritizing the advisory (non-blocking) hook design already decided.

## Context & Scope

Researched all four enforcement layers named in the task: (1) a new auto-applied rule, (2) an
advisory `PostToolUse` hook wired into `settings.json`, (3) reinforcement snippets in
implementer agents/skills, (4) documentation-policy.md updates in both the deployed and
extension-source copies. Also researched the CLAUDE.md auto-generation/merge mechanism so the
new rule is discoverable, and confirmed the canonical-vs-deployed relationship between
`.claude/extensions/nvim/context/...` and `.claude/context/project/neovim/...`.

## Findings

### Codebase Patterns

#### Rule file format (Layer 1)

Existing rules under `.claude/rules/*.md` use one of two header conventions, both currently in
production:

1. **YAML frontmatter with `paths:`** (used by `artifact-formats.md`, `plan-format-enforcement.md`,
   `state-management.md`):
   ```markdown
   ---
   paths: specs/**/*
   ---

   # Artifact Format Rules
   ```
   `git-workflow.md` uses an array form: `paths: ["specs/**/*", ".claude/**/*"]`.

2. **Plain `## Path Pattern` section, no frontmatter** (used by `neovim-lua.md`):
   ```markdown
   # Neovim Lua Development Rules

   ## Path Pattern

   Applies to: `lua/**/*.lua`, `after/**/*.lua`, `*.lua`
   ```
   The `docs/guides/creating-extensions.md` and `docs/guides/adding-domains.md` templates for
   new domain rules (`Step 4: Create Domain Rule` / `## Creating Rules`) both use this same
   `## Path Pattern` / `Applies to:` convention — this is the documented/canonical pattern for
   new rules, not the frontmatter form.

   These rules are Claude Code's own native path-scoped rule-attachment feature (confirmed by
   `docs/architecture/extension-system.md:94` — `rules/  # Auto-applied rules (.md files)` — and
   by CLAUDE.md's own "Core rules (auto-applied by file path)" framing). **Caveat for the
   implementer**: whether this native auto-attachment reliably fires for Task-tool-spawned
   subagents (which is how virtually all `.claude/` writes actually happen in this architecture
   — via `general-implementation-agent` etc., not the root session) could not be confirmed by
   static file inspection alone. Given this uncertainty, Layer 3's explicit per-agent
   reinforcement should proceed regardless as defense-in-depth — the two layers are
   complementary, not redundant, and Layer 3 is cheap.

   Since the new rule's scope is "everywhere EXCEPT specs/**" (an exclusion, not a small
   inclusion glob), a glob-only `Applies to:` line cannot cleanly express "the entire repo minus
   one subtree." **Recommendation**: state the rule's applicability as prose (mirroring how
   `error-handling.md` and `workflows.md` are scoped to `.claude/**` in the CLAUDE.md table
   rather than by literal glob) plus an explicit "Exceptions" section, rather than attempting a
   negative-glob `Applies to:` line. Register it in the CLAUDE.md "Rules References" table with
   scope annotation `(everywhere except specs/**)`.

   The rule's required content, `CLAUDE.md` MUST NOT DO 1/2/3, and Layer-2's regex ALL derive
   from the single canonical example already in the codebase — see "Exact File Contents" below.

#### Hook contract (Layer 2)

Read both precedent hooks in full (`.claude/hooks/validate-plan-write.sh`,
`.claude/hooks/validate-meta-write.sh`). Their shared contract:

- **Input parsing** (identical boilerplate in both): read stdin JSON (`PostToolUse` hook input),
  extract `.tool_input.file_path` via `jq -r '.tool_input.file_path // empty'`; if stdin is a
  TTY (interactive/no-stdin), fall back to `$CLAUDE_TOOL_INPUT` env var with the same jq
  extraction. Both use `set -uo pipefail` (not `-e`, so a jq failure doesn't kill the hook).
- **Content is not extracted from tool_input at all.** Neither hook parses `.content` or
  `.new_string`. `validate-plan-write.sh` delegates entirely to
  `.claude/scripts/validate-artifact.sh "$FILE" "$artifact_type"`, which re-reads the artifact
  **off disk** (it's a `PostToolUse` hook — the write has already landed by the time the hook
  fires) and greps/scans the file's actual on-disk content. This is simpler and more robust than
  parsing `tool_input.content`/`new_string` (which differs in shape between `Write` — full
  `content` field — and `Edit` — `old_string`/`new_string` pair, requiring a branch). **The new
  hook should follow the same "read the file off disk" pattern**, uniformly handling both `Write`
  and `Edit` without a tool-type branch.
- **Output shape**: JSON on stdout, always. `{}` for no-op/pass (both the "no target path" early
  exit and the "path doesn't match my scope" early exit use `echo '{}'`). Corrective/advisory
  output is `{"additionalContext": "..."}` — a single string field, no `systemMessage` field is
  used by either precedent. This field surfaces as extra context to the agent; it is inherently
  non-blocking (there is no `permissionDecision: "deny"` or exit-2 blocking pattern in either
  precedent hook — those hooks that DO block, like `guard-destructive-git.sh`, are `PreToolUse`
  hooks using `permissionDecision`/exit 2, an entirely different mechanism not applicable here
  since Layer 2 is explicitly advisory/`PostToolUse`).
- **Exit codes**: both hooks always `exit 0` at the very end (bash script exit), regardless of
  the internal validation result — the *validation* result is communicated purely via the JSON
  `additionalContext` payload, never via the hook script's own exit code. (`validate-artifact.sh`
  itself has a richer internal exit-code contract — 0/1/2/3/4 — but `validate-plan-write.sh`
  translates all of those into a `case` statement that always ends in `exit 0` for the hook
  process itself.)
- **Wiring in `settings.json`**: confirmed by reading the full `PostToolUse` array (`.claude/settings.json`
  lines 135-154). Exact structure to mimic for the new hook:
  ```json
  {
    "hooks": [
      {
        "command": "bash .claude/hooks/validate-plan-write.sh 2>/dev/null || echo '{}'",
        "type": "command"
      }
    ],
    "matcher": "Write|Edit"
  }
  ```
  This is a **second array entry** in `PostToolUse`, sibling to the `state.json`-specific entry
  (matcher `"Write"`) and preceding `UserPromptSubmit`. Multiple `PostToolUse` entries with
  different matchers all fire independently per tool call — Claude Code does not short-circuit
  on the first match. The new hook's entry should be added as a third `PostToolUse` array
  element, matcher `"Write|Edit"`, command
  `bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'`.

  **CRITICAL RISK (see Executive Summary)**: `validate-meta-write.sh` exists as a file, is
  referenced as "wired" in `.claude/commands/meta.md`, `.claude/agents/meta-builder-agent.md`,
  `.claude/skills/skill-meta/SKILL.md` (and their `extensions/core/` source mirrors), and is
  listed in `.claude/extensions/core/manifest.json`'s `provides.hooks` array and
  `.claude/extensions.json`'s deployed-files inventory — **but grepping the live, deployed
  `.claude/settings.json` for `validate-meta-write` returns zero matches.** `manifest.json`'s
  `provides.hooks` list only controls which **files get copied** into `.claude/hooks/` when the
  extension is (re)deployed (per `docs/guides/adding-domains.md`: "When loaded: ... Rules copied
  to `.claude/rules/` ... Settings merged into settings.json" — evidently the settings-merge step
  for this particular hook either never ran or was reverted). **Do not assume adding the hook
  filename to a manifest's `provides.hooks` array is sufficient** — the implementer must add the
  literal `PostToolUse` array entry to `.claude/settings.json` by hand (or verify whatever
  settings-merge tooling is supposed to do it actually did, before considering Layer 2 done).

- **Skip conditions** (from the task's own spec, confirmed against the two precedents'
  early-exit style): skip (emit `{}`) when `$FILE` is empty; skip when `$FILE` matches
  `specs/*` or `*/specs/*` (mirrors `validate-meta-write.sh`'s own `specs/*|*/specs/*` skip
  case verbatim — reuse this exact case pattern). No additional "tracked deliverable areas"
  allowlist is needed beyond "not under specs/" — the task's own principle is "everywhere
  outside specs/ is a deliverable," so the skip condition IS the specs/ exclusion, not a
  separate positive allowlist.

#### Regex design (Layer 2, continued) — grep-tested

Final recommended pattern (GNU ERE, case-insensitive):

```
grep -Eqi '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE"
```

Base pattern (meets the task's minimum bar exactly, no colon/comma extension):
```
\btasks?[[:space:]]+[0-9]
```

Both were executed via `grep -E` against the required test strings (see raw test files
`/tmp/.../scratchpad/pos.txt`, `/tmp/.../scratchpad/neg.txt` used during this research; the
implementer does not need those files — the strings are reproduced below):

**Positive test table** (must MATCH — verified: 9/9 matched by both patterns):

| Test string | Matches? |
|---|---|
| `(task 35)` | yes |
| `(tasks 823-824)` | yes |
| `(tasks 823, 824)` | yes |
| `task 823:` | yes |
| `tasks 823-824` (bare) | yes |
| `Architecture context (task 35): the freshness machinery` | yes |
| `task 35's fix` (possessive edge case) | yes (intentional — still a citation) |
| `Task 92 fixed a bug` (sentence-initial capital) | yes (requires `-i` / case-insensitive) |
| `meta-task 12 was closed` (hyphen-prefixed) | yes (`\b` fires after `-`; acceptable) |

**Negative test table** (must NOT match — verified: 0/14 false positives for base pattern; the
refined pattern additionally converts the last row from a documented miss into a correct catch):

| Test string | Base pattern | Refined pattern |
|---|---|---|
| `task queue` | no match | no match |
| `task type` | no match | no match |
| `async task` | no match | no match |
| `background task` | no match | no match |
| `TaskCreate and TaskUpdate tools` | no match | no match |
| `a task` | no match | no match |
| `the task` | no match | no match |
| `task list` | no match | no match |
| `task_number` | no match | no match |
| `task-lock` | no match | no match |
| `task directory` | no match | no match |
| `2026-07-06 is a date` | no match | no match |
| `version 2.3.0 released` | no match | no match |
| `tasks: 823, 824` (colon between "tasks" and number) | **no match (documented miss)** | **matches (caught)** |

**Recommendation**: ship the refined pattern `\btasks?[:,]?[[:space:]]+[0-9]` — it strictly
dominates the base pattern (same 0 false positives, catches one more real-world shape) at
negligible added complexity.

**Discriminator explanation**: the pattern never matches on the word "task"/"tasks" alone; it
requires `task`/`tasks` to be *immediately* followed (after an optional single `:` or `,`) by
whitespace and then a digit. This is exactly why `task queue`, `task type`, `a task`, `task
list`, `background task` all fail — none has a digit in that position. `TaskCreate`/`TaskUpdate`
fail because there's no whitespace between "Task" and the following capitalized word (no
`[[:space:]]+` match point) — case-insensitivity does not create a false positive here since the
failure mode is structural (no space), not case. Dates (`2026-07-06`) and version numbers
(`2.3.0`) never match because nothing in the pattern triggers without a preceding literal
`task`/`tasks` token.

**Implementation notes / edge cases for the implementer**:
- Use `grep -Eqi` (quiet, extended, case-insensitive) — the `-i` flag is required to catch
  sentence-initial `Task 92 ...`; do not substitute a `[Tt]` character class as a case-insensitive
  workaround, `-i` is simpler and already covers `TASK`/`Tasks`/etc.
- `\b` (word boundary) is a GNU grep extension, fully supported in this repo's Linux/GNU
  environment (confirmed via the working test runs above) — no portability shim needed since this
  codebase targets Linux only (see env block: `Platform: linux`). No `\<`/`\>` fallback is
  required.
- The `meta-task 12` / possessive `task 35's` matches are intentional over-inclusion, not bugs —
  both are still legitimate task-number citations that the rule wants surfaced. This is
  advisory-only, so slight over-inclusion is an acceptable and correct trade-off versus
  under-inclusion (a blocking hook would need to be far more conservative; an advisory one does
  not).
- Known non-goal: this regex does not attempt to special-case commit-message content (the hook
  only fires on `Write`/`Edit` tool calls, which never touch `.git/COMMIT_EDITMSG` or `git commit
  -m` payloads — commit messages are exempt structurally, not by the regex).

### External Resources

Not applicable — this is a pure codebase-convention task; no external documentation was needed
beyond what the four precedent artifacts (hooks, rules, agents, merge-sources) already establish.

### Recommendations — Exact File Contents and Insertion Anchors

#### Layer 1 — `.claude/rules/no-task-references-in-deliverables.md` (new file)

Follow the `## Path Pattern` convention (matches `neovim-lua.md` and the documented
`creating-extensions.md`/`adding-domains.md` templates — do NOT use YAML frontmatter, since this
rule needs prose to express an exclusion, not a simple glob):

```markdown
# No Task-Number References in Deliverables

## Path Pattern

Applies to: the entire repository EXCEPT `specs/**/*` (task-management artifacts), git commit
messages, and PR/branch metadata — see Exceptions below.

## Principle

Deliverable files — the actual work product under `.claude/`, `lua/`, other code, and
documentation — MUST NOT reference ephemeral task-management metadata such as "task N",
"tasks N-M", or "(task N)". Task numbers are renumbered during vault operations (when
`next_project_number` exceeds 1000, tasks are renumbered by subtracting 1000 — see
`.claude/rules/state-management.md`), and are meaningless to a future reader of a context file,
standard, or piece of code who has no access to (or interest in) the task tracker.

## Exceptions (task numbers ARE permitted here)

- `specs/**` artifacts: reports, plans, summaries, `TODO.md`, `state.json`
- Git commit messages (the `task {N}: {action}` convention in `.claude/rules/git-workflow.md`
  is the allowed use and stays as-is)
- PR/branch metadata (branch names like `task-{N}-{slug}`, PR descriptions)

## Reference Durable Anchors Instead

When a deliverable needs to explain provenance, prior context, or "why does this section exist,"
cite a durable anchor: a sibling document's filename, a section heading, a decision-record name,
or a verified fact — never the ephemeral task number that happened to produce it.

**Before** (observed leak, `.claude/context/project/email/domain/wrapper-contracts.md`):
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)

**Architecture context (task 35)**: the freshness machinery below is mechanism 3 ...
```

**After**:
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer

**Architecture context**: the freshness machinery below is mechanism 3 of the notmuch indexing
pipeline described in `wrapper-contracts.md` section 9 (mbsync trigger paths) ...
```

The durable anchor is the section/document reference ("section 9", "mbsync trigger paths"), not
the task number that happened to write it.

## Enforcement

- **Advisory hook**: `.claude/hooks/validate-no-task-references.sh` (PostToolUse, non-blocking)
  scans new/edited content outside `specs/**` for task-number citation patterns and surfaces a
  reminder — it never blocks the write.
- **Agent reinforcement**: implementation agents that author files outside `specs/**` include a
  MUST NOT rule against task-number citations (see agent files below).
```

Add to `.claude/extensions/core/merge-sources/claudemd.md`'s "Rules References" section
(exact anchor — insert as a new bullet immediately after the existing 6, before the
`**Extension Rules**:` sentence):

```markdown
- @.claude/rules/plan-format-enforcement.md - Plan format checklist (specs/**)
- @.claude/rules/no-task-references-in-deliverables.md - No task-number citations outside specs/**

**Extension Rules**: When extensions are loaded, additional rules are added (e.g., {domain}-rules.md for domain-specific development).
```

(The literal file at `.claude/CLAUDE.md` is regenerated from this merge-source — do not hand-edit
the deployed `.claude/CLAUDE.md` "Rules References" table directly; it will be overwritten by the
next sync. Edit `.claude/extensions/core/merge-sources/claudemd.md` and either re-run the sync
[picker "Load Core" / `Ctrl-l`, per `lua/neotex/plugins/ai/claude/extensions/merge.lua`] or hand-
mirror the same line into the deployed `.claude/CLAUDE.md` in the same commit so the two don't
drift until the next sync.)

#### Layer 2 — `.claude/hooks/validate-no-task-references.sh` (new file)

```bash
#!/bin/bash
# PostToolUse hook: advisory detection of task-number citations in deliverable files
# Triggers on Write/Edit outside specs/**. Never blocks -- additionalContext only.
# Mirrors validate-plan-write.sh / validate-meta-write.sh's input-parsing and output contract.

set -uo pipefail

# Parse file path from stdin (PostToolUse hook input)
if [ -t 0 ]; then
  FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
else
  INPUT=$(cat)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [ -z "$FILE" ]; then
    FILE=$(echo "$CLAUDE_TOOL_INPUT" 2>/dev/null | jq -r '.file_path // empty' 2>/dev/null)
  fi
fi

if [ -z "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Skip specs/ paths - task numbers are the allowed use there
case "$FILE" in
  specs/*|*/specs/*)
    echo '{}'
    exit 0
    ;;
esac

# Skip if file doesn't exist (defensive) or isn't a text file we can grep
if [ ! -f "$FILE" ]; then
  echo '{}'
  exit 0
fi

# Scan on-disk content (write has already landed by PostToolUse time)
if grep -Eqi '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE" 2>/dev/null; then
  match=$(grep -Eino '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE" 2>/dev/null | head -3 | tr '\n' ';' )
  cat << EOF
{"additionalContext": "ADVISORY: ${FILE} appears to cite a task number outside specs/** (matches: ${match}). Task numbers are ephemeral work-management metadata and get renumbered during vault operations -- deliverable files should reference durable anchors (sibling doc filenames, section headings, decision-record names) instead. See .claude/rules/no-task-references-in-deliverables.md. This is advisory only; no action is required if this is a false positive."}
EOF
  exit 0
fi

echo '{}'
exit 0
```

Wire into `.claude/settings.json`'s `PostToolUse` array. Exact insertion: add as a new array
element immediately after the existing `validate-plan-write.sh` entry (currently the last
`PostToolUse` entry before `UserPromptSubmit`, lines ~145-153):

```json
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/validate-plan-write.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "Write|Edit"
      },
      {
        "hooks": [
          {
            "command": "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'",
            "type": "command"
          }
        ],
        "matcher": "Write|Edit"
      }
    ],
```

Remember to `chmod +x .claude/hooks/validate-no-task-references.sh` (all existing hooks are
executable) and confirm post-wiring with a manual `grep -n "validate-no-task-references"
.claude/settings.json` — do not trust manifest.json alone (see the `validate-meta-write.sh` gap
documented above).

Also add `"validate-no-task-references.sh"` to `.claude/extensions/core/manifest.json`'s
`provides.hooks` array (alongside `"validate-meta-write.sh"`, `"validate-plan-write.sh"`, etc.,
currently lines ~146-160) and to `.claude/extensions.json`'s deployed-files inventory (mirrors
the pattern at line 390 for `validate-meta-write.sh`) — this controls file-copy on
redeploy/sync, which is necessary but (per the finding above) NOT sufficient on its own for
settings.json wiring.

#### Layer 3 — Agent reinforcement (no shared context file exists; edit 6 agent files directly)

**Investigated and ruled out**: a shared "output standards" context file loaded by all
implementers. Queried `.claude/context/index.json` for `load_when.agents` intersections across
`general-implementation-agent`, `general-implementation-hard-agent`, `neovim-implementation-agent`,
`nix-implementation-agent`, `cslib-implementation-agent`, `cslib-implementation-hard-agent` — zero
overlap (each domain implementer loads entirely disjoint domain-specific context; only
`general-implementation-hard-agent` and `general-implementation-agent` share
`patterns/checkpoint-before-overflow.md` and `patterns/task-lock.md`, neither of which is a
content-standards file). **No single shared insertion point exists** — the six agent files must
each be edited individually.

**Researcher/planner agents ruled out**: `general-research-agent.md` writes only to
`specs/{NNN}_{SLUG}/reports/` (Stage 6 "Path Construction") and `planner-agent.md` writes only to
`specs/{NNN}_{SLUG}/plans/` (line 158) — both write exclusively inside the allowed `specs/**`
zone. Neither authors deliverable files directly (context-file creation happens later, via
`general-implementation-agent`, which IS in the target list). No edit needed to either.

**SKILL.md files ruled out as the primary target**: `skill-implementer`, `skill-implementer-hard`,
`skill-neovim-implementation`, `skill-nix-implementation`, `skill-cslib-implementation`,
`skill-cslib-implementation-hard` are thin orchestration wrappers (Trigger Conditions ->
Execution Flow -> Postflight -> "MUST NOT (Postflight Boundary)") that delegate content authoring
to their paired agent — they do not themselves describe content-quality rules. The agent files
are the correct, content-authoring-adjacent insertion point.

**Target: 6 agent files, each has a `## Critical Requirements` / `**MUST NOT**:` numbered list.**
Add a new numbered item to each list (append after the last existing item, renumbering not
required since markdown numbered lists don't require sequential literal numbers, but keep it
last for minimal diff). Exact quoted anchors (verified via Read) and the exact line to add:

1. **`.claude/agents/general-implementation-agent.md`** (line 545, end of `**MUST NOT**:` list,
   after `5. Skip Stage 0 early metadata creation`):
   ```
   6. Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead
   ```

2. **`.claude/agents/general-implementation-hard-agent.md`** (line 357, end of `**MUST NOT**:`
   list, after `5. Use status value "completed" (triggers Claude stop behavior)`): same new line
   as item 1, renumbered `6.`. Note this agent's `**MUST NOT**:` list does NOT say "same as base"
   (only its `**MUST DO**:` list does) — it must be edited explicitly, do not rely on inheritance
   from `general-implementation-agent.md`.

3. **`.claude/agents/neovim-implementation-agent.md`** (line 490, end of `**MUST NOT**:` list,
   after `9. Skip Stage 0 early metadata creation (critical for interruption recovery)`): same
   new line, renumbered `10.`.

4. **`.claude/agents/nix-implementation-agent.md`** (line 819, end of `**MUST NOT**:` list, after
   `10. Use deprecated overlay variables self/super (use final/prev)`): same new line, renumbered
   `11.`.

5. **`.claude/agents/cslib-implementation-agent.md`** (`**MUST NOT**:` list starts line 506;
   read only the first 3 items during this research — implementer should append after the last
   item in the full list, which extends past what was read here).

6. **`.claude/agents/cslib-implementation-hard-agent.md`** (line 368, end of `**MUST NOT**:` list,
   after `6. Return implemented status if any new axiom was introduced`): same new line,
   renumbered `7.`. Same caveat as item 2 — this hard variant's `**MUST NOT**:` list is its own
   list, not inherited.

All six agent files also have an identical-shape `## Context References` bullet list near the
top (already present); optionally add a reference line there too
(`` `@.claude/rules/no-task-references-in-deliverables.md` - Deliverable content standard ``) for
extra visibility, but the `**MUST NOT**:` addition is the load-bearing one since it's inside the
"Critical Requirements" section every implementer agent already treats as binding.

#### Layer 4 — Documentation-policy standards (both copies, canonical = extensions/nvim/)

**Confirmed byte-identical today** (`diff` exit 0). **Sync direction**: per the standard
extension-deployment pattern documented in `docs/guides/adding-domains.md` ("When loaded: ...
Context copied to `.claude/context/`") and `nvim/manifest.json`'s `provides.context: ["project/neovim"]`
declaration, `.claude/extensions/nvim/context/project/neovim/` is the **canonical source**;
`.claude/context/project/neovim/` is the **deployed copy** that gets overwritten from source on
sync. **The implementer must edit `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`
first** (source of truth), then either re-run the sync or hand-mirror the identical edit into
`.claude/context/project/neovim/standards/documentation-policy.md` in the same commit — both
copies must stay identical, and `documentation-policy.md` is not listed in `.syncprotect`
(confirmed: `.syncprotect` currently only protects `context/repo/project-overview.md` and
`output/implementation-001.md`), so an eventual sync WILL silently overwrite the deployed copy
from source if they're allowed to diverge.

Exact insertion anchor (both files, identical content, insert as a new final bullet under
`## Style Guidelines`, after the existing `- Document any dependencies or requirements` line):

```markdown
## Style Guidelines
- Use clear, concise language
- Include code examples with syntax highlighting
- Maintain consistent formatting across all README files
- Link to relevant keymaps and commands where applicable
- Document any dependencies or requirements
- Do not cite task numbers ("task N", "tasks N-M") in README or standards content -- task
  numbers are ephemeral work-management metadata (see .claude/rules/no-task-references-in-deliverables.md);
  reference the relevant module, file, or section instead
```

### Decisions

- Regex: ship `\btasks?[:,]?[[:space:]]+[0-9]` (case-insensitive `-i` flag), not the unrefined
  base pattern — strictly dominates it on the test set.
- Hook reads file content off disk (post-write), not from `tool_input.content`/`new_string` —
  matches both precedents' actual behavior and sidesteps the Write-vs-Edit payload-shape
  difference entirely.
- Layer 3 targets six agent files directly (no shared context file exists); SKILL.md files and
  researcher/planner agents are out of scope for Layer 3 edits.
- Layer 4 canonical source is the `.claude/extensions/nvim/` copy; both copies edited in the same
  commit rather than relying on sync timing.
- New rule uses the `## Path Pattern` prose-header convention (not YAML frontmatter), since its
  scope is an exclusion (repo-wide except specs/**) rather than a simple inclusion glob.

## Risks & Mitigations

- **False positives**: mitigated by the grep-tested regex (0/14 on required negatives) and by
  the hook being strictly advisory (`additionalContext` only, never blocks) — an occasional
  false positive costs a reviewer's attention, not a failed operation.
- **Silent non-wiring** (the `validate-meta-write.sh` precedent): the implementer MUST verify
  with a direct `grep -n "validate-no-task-references" .claude/settings.json` after editing, not
  trust manifest.json/extensions.json entries alone. Recommend the planner add an explicit
  verification step/phase for this.
- **CLAUDE.md auto-generation constraint**: hand-editing the deployed `.claude/CLAUDE.md`
  "Rules References" table is not durable — it must be edited in
  `.claude/extensions/core/merge-sources/claudemd.md`, with the deployed copy either regenerated
  via sync or hand-mirrored in the same commit to avoid a temporary drift window.
  `.claude/extensions/core/commands/meta.md` / `.claude/commands/meta.md` and their `docs/`
  siblings are themselves near-duplicate deployed/source pairs following the same pattern
  (evidence: identical `validate-meta-write.sh` references appear in both `.claude/commands/`
  and `.claude/extensions/core/commands/` copies) — this "source under extensions/core or
  extensions/nvim, deployed copy under top-level .claude/" duplication is a repo-wide pattern,
  not unique to documentation-policy.md.
- **Context-window/diff size for the planner**: six separate agent-file edits (Layer 3) plus one
  new rule, one new hook, one settings.json edit, and two documentation-policy edits is nine
  files touched minimum — appropriately phased below.
- **Retroactive leak volume**: `wrapper-contracts.md` alone has 9+ pre-existing task-number
  citations; this task's scope explicitly excludes retroactive cleanup, but the planner should
  note this is a known, larger follow-up (potentially its own future task) rather than attempt
  it inside this task's phases.

## Recommended Phase Breakdown (for /plan)

1. **Phase 1 — Rule**: create `.claude/rules/no-task-references-in-deliverables.md`; add its
   entry to `.claude/extensions/core/merge-sources/claudemd.md`'s Rules References list; mirror
   the same bullet into the deployed `.claude/CLAUDE.md` Rules References table in the same
   phase (avoid a drift window). Verify: `grep -n "no-task-references" .claude/CLAUDE.md
   .claude/extensions/core/merge-sources/claudemd.md` both show the new line.

2. **Phase 2 — Hook + settings wiring**: create `.claude/hooks/validate-no-task-references.sh`
   (`chmod +x`); add the `PostToolUse` array entry to `.claude/settings.json`; add the filename
   to `.claude/extensions/core/manifest.json`'s `provides.hooks` and to
   `.claude/extensions.json`'s file inventory. Verify: manually `Write` or `Edit` a scratch file
   outside `specs/` containing `(task 999)` and confirm the hook fires with `additionalContext`
   (can be tested by invoking the hook script directly with piped JSON input mimicking the
   `PostToolUse` schema, or by observing the live tool-call transcript). Also verify a `specs/**`
   write does NOT trigger the hook.

3. **Phase 3 — Agent reinforcement**: edit the `**MUST NOT**:` list in all six agent files
   (`general-implementation-agent.md`, `general-implementation-hard-agent.md`,
   `neovim-implementation-agent.md`, `nix-implementation-agent.md`,
   `cslib-implementation-agent.md`, `cslib-implementation-hard-agent.md`) per the exact anchors
   above.

4. **Phase 4 — Documentation-policy standards**: edit
   `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` (canonical
   source) and `.claude/context/project/neovim/standards/documentation-policy.md` (deployed copy)
   identically, per the anchor above. Verify: `diff` the two files shows no output (still
   identical) after the edit.

Each phase is independently committable and independently verifiable, matching this repo's
commit-per-green-substep convention (`.claude/rules/git-workflow.md`).

## Context Extension Recommendations

- **Topic**: hook-wiring verification. **Gap**: there is no documented, repeatable way to verify
  that a `manifest.json provides.hooks` entry actually resulted in a `settings.json` array
  wiring (the `validate-meta-write.sh` gap discovered here would have been caught by such a
  check). **Recommendation**: consider a follow-up task to add a `validate-wiring.sh` check (a
  script by that name already exists at `.claude/scripts/validate-wiring.sh` — worth checking in
  a future task whether it already covers this gap or should be extended to). Not in scope here.

## Appendix

### Search queries / commands used

- `grep -n "validate-meta-write" .claude/settings*.json` (confirmed unwired)
- `diff .claude/context/project/neovim/standards/documentation-policy.md .claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` (confirmed identical)
- `jq -r '.entries[] | select(.load_when.agents) | select(.load_when.agents | any(. == $a)) | .path'` per implementer agent against `.claude/context/index.json` (confirmed no shared context file)
- `grep -Ein '\btasks?[[:space:]]+[0-9]'` / `grep -Ein '\btasks?[:,]?[[:space:]]+[0-9]'` against constructed positive/negative test files (see regex test tables above)
- `grep -n "Rules References" -A 10 .claude/extensions/core/merge-sources/claudemd.md` (confirmed CLAUDE.md merge-source location)
- `grep -rln "merge-sources\|claudemd" lua/` (confirmed the Lua-side sync/merge tooling: `lua/neotex/plugins/ai/claude/extensions/merge.lua`, `lua/neotex/plugins/ai/shared/extensions/merge.lua`)
- `git log --oneline -- .claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (confirmed 8+ commits progressively adding task-number citations)

### References

- `.claude/rules/artifact-formats.md`, `.claude/rules/git-workflow.md`,
  `.claude/rules/state-management.md`, `.claude/rules/plan-format-enforcement.md`,
  `.claude/rules/neovim-lua.md` (rule format precedents)
- `.claude/hooks/validate-plan-write.sh`, `.claude/hooks/validate-meta-write.sh`,
  `.claude/scripts/validate-artifact.sh` (hook contract precedents)
- `.claude/settings.json` (PostToolUse wiring)
- `.claude/agents/general-implementation-agent.md`, `general-implementation-hard-agent.md`,
  `neovim-implementation-agent.md`, `nix-implementation-agent.md`, `cslib-implementation-agent.md`,
  `cslib-implementation-hard-agent.md` (Layer 3 targets)
- `.claude/context/project/neovim/standards/documentation-policy.md`,
  `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` (Layer 4)
- `.claude/extensions/core/merge-sources/claudemd.md`,
  `lua/neotex/plugins/ai/claude/extensions/merge.lua` (CLAUDE.md generation mechanism)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (observed leak
  example, plus 8 additional real leaks discovered during this research)
