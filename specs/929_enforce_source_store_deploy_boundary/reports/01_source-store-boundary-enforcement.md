# Research Report: Task #929

**Task**: 929 - enforce_source_store_deploy_boundary
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: Medium (one hook fix + one hook widen/rewrite + one new rule file + ~15 one-line agent-contract edits)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system source store, .claude deploy tree, specs/archive)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both verified root causes in the task description are confirmed against the live source tree,
  with exact line numbers identified for the fix.
- `agent-system/extensions/core/hooks/validate-meta-write.sh` exists and deploys (it is listed in
  `core/manifest.json`'s `provides.hooks`), but is entirely absent from
  `agent-system/extensions/core/merge-sources/settings-hooks.json`'s `PostToolUse` array — the
  deployed `.claude/settings.json` confirms this (diffed directly): only
  `validate-no-task-references.sh` and `validate-handoff-location.sh` are wired to `Write|Edit`.
  The hook file is dead code; it has never executed.
- The hook's own path coverage (`is_meta_path` case statement) also has the gap the task
  describes: it lists `commands/`, `skills/`, `agents/`, `rules/`, `context/`, `extensions/`,
  `*/CLAUDE.md` but omits `.claude/scripts/**` and `.claude/hooks/**` — exactly where the lost
  combining-mark toolchain landed.
- A precise, already-in-repo template exists for the "one rule file, one-line agent references"
  pattern the task asks for: two `cslib` implementation agents already carry a one-line MUST NOT
  bullet of the form `Reference task numbers (...) -- see .claude/rules/<rule>.md; ... instead`.
  This is the exact shape to replicate for the new rule across all ~15 implementer-agent
  contracts, avoiding a 16th copy-paste instance of prose duplication.
- `meta-builder-agent.md` already carries a substantial hand-written prose statement of this
  exact constraint ("Rule 2 (location-correctness)", lines 32–37) that duplicates what the hook's
  advisory text and the new rule file will say. This is itself an instance of the "copy-paste
  propagation" problem the task explicitly warns against — recommend collapsing it to a pointer
  at the new rule file rather than adding a third independent prose copy.

## Context & Scope

Verified the two named root causes against the live source store
(`agent-system/extensions/core/`), located the exact deployed-vs-source diff, and surveyed how
many implementer-agent contract files exist and how the one existing "rule-file pointer in a
MUST NOT bullet" pattern is phrased, so the eventual plan can reuse it verbatim rather than invent
a new phrasing convention. No web research was needed; this is entirely a codebase/config-schema
task per the routing table (task_type: meta).

## Findings

### Root Cause (a) — hook never registered

- `agent-system/extensions/core/manifest.json` → `provides.hooks` lists `validate-meta-write.sh`
  (deploys as a file), but `agent-system/extensions/core/merge-sources/settings-hooks.json`'s
  `PostToolUse` array only wires two hooks under the `Write|Edit` matcher:
  ```json
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command", "command": "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'" },
        { "type": "command", "command": "bash .claude/hooks/validate-handoff-location.sh" }
      ]
    },
    { "matcher": "Write|Edit", "hooks": [ { ... events-log-artifact.sh ... } ] }
  ]
  ```
- Deployed `.claude/settings.json` was diffed directly against this merge-source and matches it
  byte-for-byte for the hooks that exist — confirming the deploy step is a straight copy and that
  the fix belongs exclusively in the source-store merge-source file, never in `.claude/settings.json`
  itself.
- **Fix location**: add a third command entry to the *same* `hooks` array as the two existing
  siblings (same matcher block, so it fires in the same PostToolUse pass):
  `{ "type": "command", "command": "bash .claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'" }`
  — this is the "following their existing invocation form" the task asks for (relative
  `bash .claude/hooks/X.sh`, stderr-suppressed, `|| echo '{}'` fallback matching
  `validate-no-task-references.sh`'s form; `validate-handoff-location.sh` itself omits the
  fallback deliberately since it uses exit 2 to surface an error, which is not this hook's model —
  `validate-meta-write.sh` is advisory/exit-0 like `validate-no-task-references.sh`, so it should
  copy that sibling's exact invocation form, not the exit-2 one).

### Root Cause (b) — path coverage and inverted advice, even once registered

`agent-system/extensions/core/hooks/validate-meta-write.sh`'s `is_meta_path` case statement:
```bash
case "$FILE" in
  .claude/commands/*|*/.claude/commands/*) is_meta_path=true ;;
  .claude/skills/*|*/.claude/skills/*) is_meta_path=true ;;
  .claude/agents/*|*/.claude/agents/*) is_meta_path=true ;;
  .claude/rules/*|*/.claude/rules/*) is_meta_path=true ;;
  .claude/context/*|*/.claude/context/*) is_meta_path=true ;;
  .claude/extensions/*|*/.claude/extensions/*) is_meta_path=true ;;
  */CLAUDE.md) is_meta_path=true ;;
esac
```
confirms the gap exactly as described: no `.claude/scripts/*` or `.claude/hooks/*` case, so a
write to `.claude/scripts/<toolchain>.sh` — the actual incident path — falls through
`is_meta_path=false` and the hook exits silently with `{}`, registration aside.

The advisory text emitted when `is_meta_path=true`:
```
"...If you are executing within /implement (general-implementation-agent), this write is
legitimate and you may proceed."
```
is the backwards clause the task flags: under the source-store rule, an `/implement`-lifecycle
write into `.claude/**` is precisely the failure mode (general/meta implementation agents are the
actors most likely to hand-author files, and the incident this task cites was authored by exactly
that lifecycle). The rewritten message needs to (1) state the source-store rule, (2) name
`agent-system/extensions/<ext>/...` as the correct target, (3) drop the `/implement`-is-fine
carve-out entirely, and (4) fold in the two new path cases.

### Existing template for "one rule file, referenced by a one-line MUST NOT bullet"

Grep across every implementer-agent contract for a rule-file pointer inside a MUST NOT list found
exactly one precedent, appearing in two sibling files:

- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md:533`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md:375`

Both read (verbatim, only the enclosing numbered-list index differs):
```
Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see
.claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames,
section headings) instead
```
This is the one-line-pointer shape the task's "PREFER ONE RULE FILE REFERENCED BY THE
IMPLEMENTERS" instruction calls for, already proven out in this codebase for the sibling rule
(`no-task-references-in-deliverables.md`) that this task is explicitly modeled on. No other
implementer-agent contract references any rule file from inside its MUST NOT list at all — every
other agent's task-number-citation constraint (if present) is enforced only by the
`validate-no-task-references.sh` hook, with zero agent-contract-level backstop. The new rule
should follow the identical convention: one short bullet, `-- see .claude/rules/<new-file>.md;
<one-clause summary> instead`, appended to each implementer agent's existing MUST NOT list.

**Full list of implementer-agent contract files requiring the new bullet** (MUST NOT list
already present at the line shown; append after the last existing item):

| File | MUST NOT line |
|---|---|
| `agent-system/extensions/core/agents/general-implementation-agent.md` | 617 |
| `agent-system/extensions/core/agents/general-implementation-hard-agent.md` | 422 |
| `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` | 513 |
| `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` | 362 |
| `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md` | 400 |
| `agent-system/extensions/python/agents/python-implementation-agent.md` | 155 |
| `agent-system/extensions/web/agents/web-implementation-agent.md` | 910 |
| `agent-system/extensions/latex/agents/latex-implementation-agent.md` | 164 |
| `agent-system/extensions/lean/agents/lean-implementation-agent.md` | 427 |
| `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` | 498 |
| `agent-system/extensions/typst/agents/typst-implementation-agent.md` | 145 |
| `agent-system/extensions/z3/agents/z3-implementation-agent.md` | 150 |
| `agent-system/extensions/email/agents/email-implementation-agent.md` | 167 |
| `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` | 532 |
| `agent-system/extensions/nix/agents/nix-implementation-agent.md` | 860 |

(15 files total — matches the task description's "a dozen implementers" order of magnitude.)

### `meta-builder-agent.md` already has a hand-written, duplicate copy of this exact rule

`agent-system/extensions/core/agents/meta-builder-agent.md:28-43` carries:
```
- **Rule 1 (actor/workflow -- substance unchanged)**: this agent MUST NOT implement system changes
  directly...
- **Rule 2 (location-correctness)**: `.claude/` under any repo is a gitignored, disposable deploy
  artifact regenerated from the source store (`agent-system/extensions/core/**` plus loaded
  extensions). No agent -- including `/implement`-lifecycle agents -- should hand-author files
  there; such edits are silently wiped by the next regeneration. Tasks this agent creates whose
  scope is an agent-system change must name `agent-system/extensions/core/**` (or the relevant
  extension's source directory) as their edit target, never `.claude/**`.

**Hook limitation**: `validate-meta-write.sh` (a PostToolUse hook) detects only literal `.claude/`
writes...
```
This is functionally identical prose to what the hook's advisory text says and what the new rule
file will say — a second, independent hand-maintained copy, predating this task, of the exact
constraint being centralized. It already even correctly documents the hook's blind-spot
limitation (the "detects only literal `.claude/` writes... not a backstop for target-root
correctness" caveat) — useful phrasing to reuse or fold into the new rule file's own limitation
section. Since `meta-builder-agent.md` itself never writes implementation files (Rule 1: it only
creates tasks), this "Rule 2" paragraph is arguably redundant with the new shared rule rather than
agent-specific; the plan should decide whether to collapse it to a one-line pointer (consistent
with the "prefer one rule file" instruction) or leave it as-is on the grounds that meta-builder is
the one agent most likely to reason about the source-store distinction while writing task
descriptions and therefore benefits from the fuller inline explanation. Recommend collapsing it to
match the cslib-style pointer, both for consistency and because leaving it would create exactly
the two-independent-copies problem item 3 of the task warns against.

### `CLAUDE.md`'s "Rules References" list is the other place a new rule file must be registered

`agent-system/extensions/core/merge-sources/claudemd.md:478-488` contains the auto-generated
"Rules References" section of the deployed root `CLAUDE.md`/`.claude/CLAUDE.md`:
```
## Rules References

Core rules (auto-applied by file path):
- @.claude/rules/state-management.md - Task state patterns (specs/**)
- @.claude/rules/git-workflow.md - Commit conventions
- @.claude/rules/error-handling.md - Error recovery (.claude/**)
- @.claude/rules/artifact-formats.md - Report/plan formats (specs/**)
- @.claude/rules/workflows.md - Command lifecycle (.claude/**)
- @.claude/rules/plan-format-enforcement.md - Plan format checklist (specs/**)
- @.claude/rules/no-task-references-in-deliverables.md - No task-number citations outside specs/**
```
The sibling rule this task is modeled on (`no-task-references-in-deliverables.md`) is registered
here as a one-line entry. The new rule needs the same treatment: a new bullet, e.g.
`- @.claude/rules/source-store-deploy-boundary.md - .claude/** is a disposable deploy artifact;
edit agent-system/extensions/** instead`, inserted alongside the existing seven. This is a
required third edit location beyond the two the task names explicitly (item 3's "add it as a core
rule file"), since the rule file existing on disk is not the same as it being discoverable/loaded
via the documented "Core rules (auto-applied by file path)" mechanism this system already uses.

### Shape of the sibling rule file to model the new one on

`agent-system/extensions/core/rules/no-task-references-in-deliverables.md` uses this section
structure (confirmed byte-identical between source and deployed copy — no drift):
```
# <Title>
## Path Pattern
Applies to: ...
## Principle
...
## Exceptions (... ARE permitted here)
...
## Reference Durable Anchors Instead   [rule-specific section name]
Before/After examples
## Enforcement
- Advisory hook: ... (PostToolUse, non-blocking) ...
- Agent reinforcement: ... MUST NOT rule ...
```
A second, shorter exemplar (`pr-prohibition.md`) instead uses YAML frontmatter (`paths: "**/*"`)
rather than a prose "## Path Pattern" section — both conventions coexist in this rules directory,
so either is acceptable; the prose-header style matches the explicitly-named sibling more closely
and is recommended for consistency with the rule this task is modeled on.

For the new rule, the "Path Pattern" is inherently different in kind from its sibling: it is not
"every file except specs/**" but rather "any write whose *target* is `.claude/**` in a repo whose
source store is `agent-system/extensions/**`" — i.e. it's a target-path rule, not a
content-scanning rule, so its Enforcement section should point at the *widened*
`validate-meta-write.sh` (post Root-Cause-(b) fix) rather than a new hook, and its own text must
carry the "KNOWN LIMITATION" framing from the task description (path-shape-only, cannot see
lifecycle or repo identity) rather than overclaiming enforcement — this constraint is given
verbatim in the task description and should be transcribed into the rule file near-verbatim, not
paraphrased into a stronger claim.

## Decisions

- Treat this as four coordinated edit locations, not one: (1) `settings-hooks.json` hook
  registration, (2) `validate-meta-write.sh` path-coverage + advisory-text rewrite, (3) new rule
  file `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (name chosen to match
  the kebab-case, descriptive-noun-phrase convention of its siblings), (4) `claudemd.md`'s Rules
  References bullet — plus (5) one-line MUST NOT bullets across the 15 implementer-agent contract
  files listed above, reusing the exact cslib-precedent phrasing template.
- Recommend `meta-builder-agent.md`'s existing "Rule 2" paragraph be collapsed to a one-line
  pointer at the new rule file during planning, rather than left as a third independent prose
  copy, per the task's explicit anti-copy-paste instruction — this is a scope note for the planner
  to decide on, not a unilateral research decision.
- The advisory-hook rewrite should keep the "detects only literal `.claude/` writes" and "not a
  backstop for target-root correctness" caveat language already present in
  `meta-builder-agent.md`, since it is accurate, already-written, and directly reusable rather
  than needing to be re-derived.

## Risks & Mitigations

- **Risk**: widening `is_meta_path` to include `.claude/scripts/*` and `.claude/hooks/*` could
  fire on the deploy/reload process itself if that process is ever driven through the Write/Edit
  tool rather than filesystem copy. **Mitigation**: confirmed via direct diff that deploy is a
  plain file copy (not a Claude-Code tool call), so this hook — which only fires on Write/Edit
  tool invocations — structurally cannot see the loader's writes; no explicit carve-out is needed
  beyond what the task's non-goals already state.
- **Risk**: making the hook's message too long/prescriptive could make it read as blocking even
  though it exits 0. **Mitigation**: match the concision of `validate-no-task-references.sh`'s
  existing advisory text (single sentence + "This is advisory only and does not block the write.")
  as a length/tone template.
- **Risk**: 15 near-identical one-line edits are individually low-value but collectively easy to
  miss one of. **Mitigation**: the table above is exhaustive (grep-verified against every
  `*implementation*agent.md` file in `agent-system/extensions/*/agents/` and
  `agent-system/extensions/core/agents/`); the planner should treat it as the authoritative
  checklist rather than re-deriving the file list.

## Context Extension Recommendations

- **Topic**: rule-file "family" naming/structure conventions (prose Path Pattern header vs. YAML
  `paths:` frontmatter) are not documented anywhere as an explicit choice — both exist
  side-by-side in `agent-system/extensions/core/rules/` with no stated preference.
- **Gap**: a future rule author has to grep two existing files to discover the two conventions;
  there is no `.claude/context/` doc describing "how to add a new core rule file."
- **Recommendation**: not in scope to create now, but worth a follow-up `meta` task if this
  pattern keeps recurring — a short `context/patterns/adding-a-core-rule.md` documenting the two
  conventions, the `claudemd.md` Rules References registration step, and the
  "agent-contract-pointer" convention this report's cslib precedent demonstrates.

## Appendix

- Files read: `agent-system/extensions/core/manifest.json`, `merge-sources/settings-hooks.json`,
  `hooks/validate-meta-write.sh`, `hooks/validate-no-task-references.sh`,
  `hooks/validate-handoff-location.sh`, `rules/no-task-references-in-deliverables.md`,
  `rules/pr-prohibition.md`, `merge-sources/claudemd.md`, `agents/meta-builder-agent.md`,
  `agents/general-implementation-agent.md`, `agents/general-implementation-hard-agent.md`, and
  all 13 extension `*-implementation-agent.md` / `*-implementation-hard-agent.md` files.
- Commands used: `find`/`grep`/`diff` against `agent-system/extensions/core/` (source) and
  `.claude/` (deployed) to confirm zero drift on the relevant files.
- No web search was performed; this task is entirely internal-codebase verification.
