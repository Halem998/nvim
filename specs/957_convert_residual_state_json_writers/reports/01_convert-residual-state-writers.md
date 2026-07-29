# Research Report: Task #957

**Task**: 957 - convert_residual_state_json_writers
**Started**: 2026-07-29T15:00:00Z
**Completed**: 2026-07-29T15:10:49Z
**Effort**: medium (mechanical conversion across 16 files, 6 doc updates)
**Dependencies**: `agent-system/extensions/core/scripts/state-write.sh` (already built, do not re-invent)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/state-write.sh`, `context/patterns/task-lock.md`,
  the 16 `file_scope` skill/command files, the 6 stale-idiom doc files, prior-conversion
  precedents in `commands/review.md` and `commands/implement.md`
- Verification tooling: `scripts/test-state-write-concurrency.sh`,
  `scripts/test-task-lock-reap.sh`, `.claude/scripts/check-task-references.sh`,
  `.claude/scripts/check-extension-docs.sh`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md

## Executive Summary

- `state-write.sh` is fully built, correct, and already has 10 live callers among core scripts
  (`skill-base.sh`, `archive-task.sh`, `manage-topics.sh`, `update-task-status.sh`,
  `reconcile-artifacts.sh`, `orchestrator-postflight.sh`, `reconcile-task-status.sh`,
  `orchestrate-predispatch-review.sh`) plus two prose precedents already converted in
  `commands/review.md` and `commands/implement.md`. The mechanism needs no changes — only the
  16 `file_scope` files need their inline write blocks swapped for calls to it.
- The task's own baseline count (48 + 8 = 56 sites) is explicitly flagged in the task
  description as approximate ("re-measure at implementation time, do not trust this count as
  final"). A precise re-grep restricted to literal `specs/state.json` write-then-`mv` sites
  (excluding `specs/archive/state.json` and vault-path writes, which this task's verification
  bar does not cover — see Decisions) found **68** sites across the 16 files, higher than the
  stated 56. This is consistent with the task's own caveat and does not change the shape of the
  work, only its size.
- **Scope-boundary finding (important for the implementer)**: `state-write.sh`'s `STATE_FILE` is
  hardcoded to `specs/state.json`. It does **not** currently support writing
  `specs/archive/state.json` or vault-root `state.json`. `skill-todo`'s vault-operation logic and
  `commands/task.md`'s `--recover` path both intermix `specs/state.json` writes with
  `specs/archive/state.json` writes in the same code blocks. The task description's verification
  bar is explicitly scoped to `specs/state.json`-targeted patterns only ("a repo-wide grep ...
  for any remaining `specs/state.json`-targeted `> tmp && mv`..."), so `specs/archive/state.json`
  write sites are out of scope for this task and must be left as-is — converting them would
  require extending `state-write.sh` with a `--file` argument, which is not part of this task's
  mechanism-reuse mandate ("do not re-invent").
- Two established precedents already show both directions of the fold-vs-don't-fold judgment
  call the task description asks the implementer to apply: `commands/review.md` lines 628-655
  (task-creation write, deliberately NOT folded with `--regen-todo` because `manage-topics.sh set`
  must run in between) and lines 816-826 (`.active_goal` write, folded with `--regen-todo`
  because nothing but the regen follows). These are the two reference examples to imitate.
- The self-generating `--session-id` fallback pattern
  (`sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')`) is already established in five
  scripts (`manage-topics.sh`, `archive-task.sh`, `reconcile-artifacts.sh`,
  `orchestrate-predispatch-review.sh`, `skill-base.sh`) and is directly relevant here because
  `commands/todo.md` currently has **zero** `session_id` references anywhere in the file — the
  `/todo` command has no session_id threaded through it today, so its converted write sites will
  need the self-generating fallback, not an inherited variable. `task.md`'s Sync Mode
  (`--sync`) already has its own local precedent for this at line 442
  (`sync_session_id="sess_$(date +%s)_..."`). Most `SKILL.md` files, by contrast, already have
  `$session_id` in scope from the skill's delegation context (confirmed in
  `skill-implementer/SKILL.md`), so those conversions can reuse the existing variable directly.
- All four verification-bar regression checks pass cleanly at baseline, before any conversion
  work starts: `test-state-write-concurrency.sh` (4/4 passed), `test-task-lock-reap.sh` (6/6
  passed), `check-task-references.sh` (PASS, 0 unexempted occurrences across 4 trees), and
  `check-extension-docs.sh` (fails only on a pre-existing, unrelated `literature` extension
  issue — `email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `memory`,
  `nix`, `nvim`, `present`, `project-wide`, `python`, `slidev`, `typst`, `web`, `z3` all PASS).
  The implementer should confirm this `literature` failure is unchanged (not worsened) by their
  edits rather than trying to fix it — it is out of `file_scope`.

## Context & Scope

This is a meta task converting 48-68 inline hand-rolled `specs/state.json` write blocks
(`jq ... > tmp && mv`) across 14 `SKILL.md` files and 2 command files to calls to the
already-built `state-write.sh` mutex-guarded writer, then updating 6 documentation files that
still describe the old hand-rolled idiom as the recommended pattern. All edits must target
`agent-system/extensions/core/**` (the source store), never `.claude/**` (the disposable deploy
artifact) — this is stated explicitly in the task description and is also the standing rule in
`.claude/rules/source-store-deploy-boundary.md`.

The `file_scope` is exactly 22 paths (14 `SKILL.md` + `task.md` + `todo.md` + 3 `context/patterns`
files + 1 `context/troubleshooting` file + 1 `context/standards` file + 1 `docs/guides` file).

## Findings

### Codebase Patterns

**The mechanism (`state-write.sh`)** — `agent-system/extensions/core/scripts/state-write.sh`
(228 lines, `bash -n` clean):
- Signature: `state-write.sh <jq-filter> --session-id SID [--arg NAME VALUE]...
  [--argjson NAME VALUE]... [--regen-todo] [--dry-run]`
- Sequence: fail-closed mutex acquire (via `task-lock.sh scope-acquire`, honoring
  `SCOPE_MUTEX_HELD=1` guest mode for nesting) -> private `mktemp` staging under `specs/tmp/` ->
  apply the caller's jq filter -> `jq empty` validate -> atomic `mv` -> optional in-mutex
  `--regen-todo` (calls `generate-todo.sh`, a regen failure is a non-fatal warning) -> release.
- Exit codes: 0 success, 1 usage error, 2 mutex-acquire ABORT (state.json untouched), 3 jq
  transform failed (state.json untouched), 4 invalid JSON produced (state.json untouched).
- `STATE_FILE` is hardcoded to `$PROJECT_ROOT/specs/state.json` — no `--file` override exists.
  This is the scope-boundary finding above.

**Existing callers (10 scripts + 2 command-prose precedents)**, useful as conversion templates:
- `skill-base.sh` (lines ~465-509): two helper functions demonstrating the
  `local session_id="${N:-}"; if [ -z "$session_id" ]; then session_id="sess_$(date +%s)_..."; fi`
  fallback pattern immediately followed by a `state-write.sh` call.
- `manage-topics.sh` (lines 55-68): `--session-id=*` flag parsing plus the same fallback,
  guarding on `[[ -z "$SESSION_ID" ]]`.
- `commands/review.md` line 628-655: the "don't fold `--regen-todo`" precedent — task creation
  via `state-write.sh` is immediately followed by a *separate* `manage-topics.sh set` call
  (topic assignment) before any TODO.md regen is appropriate, so `--regen-todo` is deliberately
  omitted from that call.
- `commands/review.md` line 816-826 and `commands/implement.md` line 304-313: the "fold
  `--regen-todo`" precedent — a single-field write immediately followed by nothing else, so
  `--regen-todo` is folded directly into the same call.

**File-by-file re-grep of `file_scope`** (literal `specs/state.json` write-then-`mv`/`.tmp`
patterns only, excluding `specs/archive/state.json` and vault paths):

| File | Site count (re-measured) |
|---|---|
| `skill-implementer/SKILL.md` | 5 |
| `skill-implementer-hard/SKILL.md` | 1 |
| `skill-planner/SKILL.md` | 2 |
| `skill-planner-hard/SKILL.md` | 3 |
| `skill-project-overview/SKILL.md` | 1 |
| `skill-researcher/SKILL.md` | 5 |
| `skill-researcher-hard/SKILL.md` | 1 |
| `skill-reviser/SKILL.md` | 5 |
| `skill-spawn/SKILL.md` | 4 |
| `skill-status-sync/SKILL.md` | 6 |
| `skill-team-implement/SKILL.md` | 3 |
| `skill-team-plan/SKILL.md` | 3 |
| `skill-team-research/SKILL.md` | 5 |
| `skill-todo/SKILL.md` | 12 (plus several more `specs/archive/state.json` / vault-path
  sites that are out of scope — see below) |
| `commands/task.md` | 6 (plus 2 `specs/archive/state.json` sites in the `--recover` path,
  out of scope) |
| `commands/todo.md` | 6 (plus 1 `specs/archive/state.json` site, out of scope) |
| **Total (in-scope, `specs/state.json` only)** | **68** |

This exceeds the task description's stated baseline of 48+8=56, which the task description
itself warns is not final. The implementer should treat 68 as the working count and re-verify at
the end via the verification bar's own grep, not trust either number as authoritative going in.

**`skill-todo/SKILL.md` is the largest and most structurally complex file** — its vault
(task-number-reset) operation writes to `specs/state.json`, `specs/archive/state.json`, and a
new `specs/vault/{NN-vault}/state.json` in an interleaved sequence (renumbering loop, archive
move, vault-root creation). Only the `specs/state.json` writes in that sequence are in scope;
the `specs/archive/state.json` and vault-root writes must be left as hand-rolled (or flagged as
a documented, separate follow-up) since `state-write.sh` cannot target them without a `--file`
extension that is explicitly out of this task's "do not re-invent" mandate.

**Session-ID availability differs by file**:
- Most `SKILL.md` files already have `$session_id` in scope from the skill's delegation context
  (verified in `skill-implementer/SKILL.md`, which references `"session_id": "${session_id}"` and
  `--session "${session_id}"` throughout) — these conversions reuse the existing variable.
- `commands/todo.md` has **zero** existing `session_id` references — `/todo` has no session_id
  threaded through it at all today. Its conversion needs the self-generating fallback pattern
  from scratch, following the `manage-topics.sh`/`archive-task.sh` template.
- `commands/task.md`'s Sync Mode already has a local precedent for a self-generated
  `sync_session_id` (line 442, used because Sync Mode does not source `command-gate-in.sh` and so
  has no session_id of its own) — the rest of `task.md`'s modes may already have `$session_id` or
  `$task_number`-scoped equivalents in context; this needs per-site confirmation during
  implementation, not assumed uniformly.

### Documentation Files Needing Updates (6 files, `file_scope`)

All six contain literal, worked examples of the old `jq ... > specs/tmp/state.json && mv ...`
idiom presented as the recommended pattern, with concrete line counts:
- `context/patterns/inline-status-update.md`: 10 occurrences of the old idiom.
- `context/patterns/jq-escaping-workarounds.md`: 10 occurrences.
- `context/patterns/file-metadata-exchange.md`: 2 occurrences.
- `context/troubleshooting/workflow-interruptions.md`: 1 occurrence (a worked recovery example).
- `context/standards/postflight-tool-restrictions.md`: no direct `> tmp && mv` string, but a
  tool-allowlist table (lines ~40-52) that names `jq` on state.json, `mkdir -p specs/tmp`, and
  `mv specs/tmp/state.json specs/state.json` as the *approved postflight tool pattern* — this
  table needs to be updated to reference `state-write.sh` as the approved tool instead of the
  raw jq/mkdir/mv triad, even though it doesn't contain the literal old-idiom string a naive grep
  would catch.
- `docs/guides/creating-skills.md`: 1 occurrence (a worked example at line ~128).

### External Resources

Not applicable — this is a pure codebase-internal mechanical conversion task with no external
dependencies or libraries.

### Recommendations

1. **Convert file-by-file in the order the task lists them**, treating `skill-status-sync`
   (smallest, 6 sites, single-purpose file) as a good first conversion to validate the pattern
   before tackling `skill-todo` (largest, most structurally entangled with the out-of-scope
   archive/vault writes).
2. **For each site**, decide fold-vs-don't-fold against the `commands/review.md` precedent: fold
   `--regen-todo` only when nothing but the TODO.md regen follows the write in the same logical
   step; otherwise leave the regen as a separate step (or omit it if the existing code never
   called `generate-todo.sh` immediately after that particular site — not every one of the 68
   sites necessarily had a paired regen call today; this must be checked per-site, not assumed).
3. **Explicitly do not touch `specs/archive/state.json` or vault-path writes** in `skill-todo`,
   `task.md`, or `todo.md` — leave them as hand-rolled `jq ... > tmp && mv`. Consider adding a
   one-line inline comment at each such site noting it is intentionally out of scope for this
   conversion (referencing the mechanism name `state-write.sh`'s current `specs/state.json`-only
   design, not a task number, per the deliverable-citation rule).
4. **For `commands/todo.md`**, generate the session_id fresh using the established fallback
   pattern at the top of whichever write path needs it, rather than threading one variable
   through the whole file if the existing structure doesn't already support that — match
   `manage-topics.sh`'s local-fallback style over `command-gate-in.sh`'s single-entry-point
   style, since `/todo` doesn't have one clear entry point script.
5. **Update the 6 doc files last**, once the conversion pattern has stabilized from the 16
   code-bearing files, so the doc examples reflect the actual final call shape (including
   whichever `--regen-todo` fold decisions were made) rather than a guessed-ahead shape.
6. **Re-run the verification bar's own grep** (not just `bash -n` and the two regression
   scripts) as the final check, since this research confirmed the task's stated baseline count is
   already known to be off — do not stop at "48 in file_scope converted," stop at "grep returns
   zero" as the task instructs.

## Decisions

- **`specs/archive/state.json` and vault-root `state.json` writes are out of scope.** The task
  description's verification bar is explicitly worded as `specs/state.json`-targeted only, and
  `state-write.sh`'s `STATE_FILE` is hardcoded with no override mechanism. Converting those sites
  would require extending the mechanism, which conflicts with "MECHANISM (already built, do not
  re-invent)." This decision should be treated as binding for the implementation phase unless a
  future task explicitly extends `state-write.sh` with a `--file` argument.
- **The task's baseline count (56) is confirmed approximate, not wrong in kind** — the re-grep
  found 68 in-scope sites using the same conceptual definition (literal `specs/state.json`
  write-then-mv/`.tmp`), consistent with the task description's own explicit caveat. No
  correction to the task description is needed; the implementer should just expect somewhat more
  volume than 56.

## Risks & Mitigations

- **Risk**: accidentally converting an `specs/archive/state.json` or vault-path write while doing
  a fast find/replace across `skill-todo/SKILL.md`, since both site types are visually similar
  and interleaved in the same code blocks. **Mitigation**: convert one site at a time by exact
  line match, not a blanket regex substitution across the whole file; verify each converted
  site's target path is literally `specs/state.json` before touching it.
- **Risk**: folding `--regen-todo` into a write where another operation (e.g.
  `manage-topics.sh set`, an artifact-linking step, or a subsequent write to the *same* state
  entry) must land first, silently reordering behavior. **Mitigation**: follow the
  `commands/review.md` don't-fold precedent exactly — only fold when the write is "immediately
  followed by nothing but the regen."
- **Risk**: `commands/todo.md`'s conversion introduces a session_id where none existed before,
  and two independent write sites in the same command run generate two *different*
  self-generated session_ids, which would be attributed inconsistently in mutex-holder logs.
  **Mitigation**: generate the session_id once, near the top of the relevant `/todo` mode's
  logic, and thread that single value through every `state-write.sh` call in that mode's
  execution — do not call the fallback generator separately at each site.
- **Risk**: the `postflight-tool-restrictions.md` table update is easy to miss since it doesn't
  contain the literal `> tmp && mv` grep target the other 5 doc files do. **Mitigation**: this
  report explicitly flags it; the implementer should treat the allowlist-table rows (not a
  string match) as the thing to update there.

## Context Extension Recommendations

- **Topic**: `state-write.sh` scope limitation (specs/state.json only, no archive/vault target).
- **Gap**: `context/patterns/task-lock.md`'s "State-Write Convention" section documents the
  residual-surface conversion this task performs but does not mention that `state-write.sh`
  cannot target `specs/archive/state.json` or vault-root `state.json` at all. A future reader
  converting those sites (if ever undertaken) would benefit from that constraint being stated
  explicitly in the same section, rather than rediscovering it via grep as this report did.
- **Recommendation**: once this task's conversion lands, add a short paragraph to
  `context/patterns/task-lock.md`'s "State-Write Convention" section noting the
  `specs/archive/state.json` / vault-path exclusion as a known, named boundary of the mechanism
  (not a residual gap) — this is a natural follow-up documentation edit, not something to do as
  part of this task's own `file_scope`.

## Appendix

### Search Queries / Commands Used

- `grep -rn 'state\.json' <file_scope skills/commands> | grep -iE 'tmp|mv |mktemp'`
- `grep -rlnE '(specs/state\.json.*(>|\.tmp|mktemp)|state\.json\.tmp|state\.json\.bak)' agent-system/`
  (repo-wide sweep, confirmed no non-`state-write.sh` script under `agent-system/extensions/core/scripts/`
  or `hooks/` still hand-rolls the pattern; the wider extension-directory hits outside `file_scope`
  — cslib, epidemiology, founder, lean, literature, present, web — are separately out-of-scope
  surfaces per `task-lock.md`'s own note, not part of this task)
- `grep -cE '(^|[^/])specs/state\.json[^.]*(>|\.tmp)' <file>` per-file precise count
- `grep -rln 'sess_\$(date +%s)_\$(od' agent-system/extensions/core/scripts/*.sh` — located the
  five existing self-generating session_id fallback precedents
- `grep -l 'state-write.sh' agent-system/extensions/core/skills/*/SKILL.md
  agent-system/extensions/core/commands/*.md` — confirmed zero of the 16 `file_scope` files have
  been converted yet; only `commands/review.md` and `commands/implement.md` (outside
  `file_scope`) already show the converted pattern
- `bash -n agent-system/extensions/core/scripts/{state-write,task-lock}.sh` — both clean
- `bash agent-system/extensions/core/scripts/test-state-write-concurrency.sh` — 4/4 passed at
  baseline
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` — 6/6 passed at baseline
- `bash .claude/scripts/check-task-references.sh` — PASS, 0 occurrences, at baseline
- `bash .claude/scripts/check-extension-docs.sh` — fails only on pre-existing `literature`
  extension issue, unrelated to this task, at baseline

### References

- `agent-system/extensions/core/scripts/state-write.sh` — the mechanism
- `agent-system/extensions/core/context/patterns/task-lock.md` — "State-Write Convention" and
  "Known residual surface" sections (source of this task's mandate)
- `agent-system/extensions/core/commands/review.md` lines 590-655, 795-826 — fold/don't-fold
  precedent
- `agent-system/extensions/core/commands/implement.md` lines 300-313 — additional converted
  precedent
- `agent-system/extensions/core/scripts/{skill-base,manage-topics,archive-task,
  reconcile-artifacts,orchestrate-predispatch-review}.sh` — session_id self-generating fallback
  precedents
