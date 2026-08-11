# Source Store / Deploy Boundary

<!-- Deliberately eager (no `paths:` frontmatter): this rule's only automated enforcement is a
PostToolUse, non-blocking hook, so an agent gated on first path-touch would learn the rule only
AFTER the violating write landed. Keeping it eager is a recorded decision from the
context-loading audit (see context/architecture/context-layers.md, eager-vs-lazy channels) —
do not add a `paths:` glob here without first moving enforcement to a pre-write gate. -->

## Path Pattern

Applies to: any write whose target path is `.claude/**` in a repository whose source store is
`agent-system/extensions/**`. This is a *target-path* rule, not a content-scanning rule.

## Principle

`.claude/` under this repo is a gitignored, disposable deploy artifact regenerated from the
source store at `agent-system/extensions/**`. Hand-authored files landing in `.claude/` are
silently wiped by the next regeneration — the edit appears to succeed but has no lasting effect.

## Correct Edit Target

Edit the source store instead:
- `agent-system/extensions/core/**` for core system files (commands, skills, agents, rules,
  context, hooks, scripts, merge-sources).
- `agent-system/extensions/<ext>/**` for extension-owned files.

**Before** (observed anti-pattern, illustrative only):
```
Write .claude/hooks/validate-meta-write.sh
```

**After**:
```
Write agent-system/extensions/core/hooks/validate-meta-write.sh
```

## Exceptions

- Writes under `specs/**` (task-management artifacts) are unaffected — task creation and
  artifact authoring there is legitimate regardless of lifecycle stage.
- The deploy/reload process, which writes the entire `.claude/` tree by design, is not a
  violation.

## Enforcement

Two layers, neither of which alone is a guarantee:

- **Advisory hook**: `validate-meta-write.sh` (PostToolUse, non-blocking) fires on `Write`/`Edit`
  targeting `.claude/**` paths (including `.claude/scripts/**` and `.claude/hooks/**`) and injects
  a corrective `additionalContext` message naming the correct source-store target. It never
  blocks the write.
- **Agent reinforcement**: implementer-agent contracts include a MUST NOT bullet against
  hand-authoring `.claude/**` files (see agent files).

**Known limitation**: a PostToolUse hook sees only a `file_path` argument. It cannot know task
type, lifecycle stage, command context, or which repository the path belongs to — its
`specs/*|*/specs/*` skip matches unconditionally regardless of repo. It is therefore only ever an
advisory nudge on path *shape*, not a backstop for target-root correctness, and it is not a
guarantee that the rule is followed. The durable enforcement is this rule file plus the agent
contracts; the hook is the reminder.
