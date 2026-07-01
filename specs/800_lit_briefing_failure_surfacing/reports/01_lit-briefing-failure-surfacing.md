# Research Report: Task #800

- **Task**: 800 - [--lit FAILURE SURFACING] literature-briefing.sh crashes are silently treated as empty briefings
- **Started**: 2026-07-01T00:00:00Z
- **Completed**: 2026-07-01T00:30:00Z
- **Effort**: ~1 hour
- **Dependencies**: Task 799 (fixes the underlying jq crash in literature-briefing.sh; complementary, not a blocker for this task)
- **Sources/Inputs**:
  - `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`
  - `.claude/skills/skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md`
  - `.claude/scripts/literature-briefing.sh`, `.claude/scripts/literature-lit-flag-resolve.sh`
  - `.claude/output/lit.md` (transcript of the manual diagnosis that surfaced this bug)
  - `specs/799_literature_briefing_authors_type_crash_fix/summaries/01_authors-type-crash-fix-summary.md`
  - `.claude/CLAUDE.md` ("Literature Mode (`--lit`)" section)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- All six `--lit` consumers (`skill-researcher`, `skill-planner`, `skill-implementer`, and their `-hard` variants) invoke `literature-briefing.sh` with the identical anti-pattern `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""`, which discards stderr unconditionally and discards the exit code (the `||` branch reassigns the same empty value the crash already produced, so it is a no-op in practice).
- The invocation site is documented as **Stage 4a: Memory Retrieval (Auto)** in every skill, not "Stage 4b" as the task description states — Stage 4b is "Read and Inject Format Specification" (report-format.md), unrelated to literature. Any fix must target Stage 4a.
- `literature-briefing.sh` uses `set -euo pipefail` and does exit non-zero on real failures (task 799 documents a confirmed jq exit 5 from a string-vs-array `.authors` field bug, now fixed at the script level) but also has two intentional `exit 1` paths for malformed `--global`/`--top-n` arguments — any non-zero exit, crash or misuse, should be surfaced identically.
- The cleanest fix is a new shared wrapper script (matching the existing `literature-lit-flag-resolve.sh` pattern already used identically by all six skills) that passes through to `literature-briefing.sh`, lets its stderr flow normally, and appends a distinguishing `[lit] briefing generation failed (exit N)` line to stderr on non-zero exit. Each skill's Stage 4a literature-injection bash block then calls the wrapper in place of `literature-briefing.sh` directly, with the `2>/dev/null` removed.
- `literature-lit-flag-resolve.sh` — despite being described in CLAUDE.md as the shared classifier every skill uses — is **not actually referenced by any of the six SKILL.md files**; the skills still carry the older inline AskUserQuestion pseudocode predating that helper. This is a pre-existing documentation/implementation drift, out of scope for task 800, but worth flagging as a follow-up.
- The `lit_context=$(bash ... literature-briefing.sh 2>/dev/null) || lit_context=""` pattern also appears verbatim in four cslib-extension skills (`skill-cslib-research`, `skill-cslib-research-hard`, `skill-cslib-implementation`, `skill-cslib-implementation-hard`), which are outside task 800's declared scope but share the same bug and should use the same wrapper once it exists.

## Context & Scope

Task 800 is a documentation/behavior fix scoped to the **consumer side** of `--lit`: the six core skills' invocation of `literature-briefing.sh` must distinguish "script crashed" (non-zero exit) from "script legitimately found nothing" (exit 0, empty stdout) and must never silently fall into the empty-briefing path on crash. Task 799 already fixed the specific jq crash that was observed in practice; this task is about ensuring *future* crashes (of any kind, in this script or a re-introduced bug) can never again be silently absorbed as "no literature."

Scope is explicitly: `skill-researcher`, `skill-planner`, `skill-implementer`, `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`. Not in scope: fixing `literature-briefing.sh` itself (task 799), and not in scope: the four cslib-extension skills with the identical bug (noted below as a candidate follow-up).

## Findings

### Codebase Patterns

**Invocation site is Stage 4a, not Stage 4b, in every skill.**

`grep -n "^### Stage" .claude/skills/*/SKILL.md` confirms all six skills structure their preflight identically:
- `### Stage 4a: Memory Retrieval (Auto)` — contains both the `memory-retrieve.sh` call and, immediately after it in the same section, all literature-briefing logic.
- `### Stage 4: Prepare Delegation Context` — assembles the prompt.
- `### Stage 4b: Read and Inject Format Specification` (or "Read Format Specification" in `-hard` variants) — reads `report-format.md`/`plan-format.md`; has nothing to do with literature.

Any implementation plan for task 800 must edit the bash blocks inside **Stage 4a**, in each of the six `SKILL.md` files.

**The buggy invocation pattern is byte-identical across all six skills, appearing at three sites each:**

1. A commented pseudocode line inside the `AskUserQuestion` "Create task and run now" branch (illustrative, `#`-prefixed, inside the Stage 4a bash fence).
2. A numbered-list prose instruction in "Stage 4a-fork: Inline population" step 2: `` - If yes: run `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""` ``.
3. The live, always-executed bash block at the end of Stage 4a:
   ```bash
   # Literature briefing injection (runs if sub-index already exists OR was just created by fork)
   if [ "$lit_flag" = "true" ] && [ -f "specs/literature-index.json" ]; then
     lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
   fi

   # lit_context will be empty string if:
   # - lit_flag is not "true" (skipped)
   # - specs/literature-index.json is empty or missing (after all detection/setup above)
   # - script exited with error
   ```
   The trailing comment (`# - script exited with error`) currently documents the silent-swallow behavior as *intended*. This comment must be rewritten as part of any fix — it currently normalizes the exact bug this task exists to close.

Exact line numbers of the live (site 3) invocation, confirmed by direct read:
- `skill-researcher/SKILL.md:244`
- `skill-planner/SKILL.md:255`
- `skill-implementer/SKILL.md:237`
- `skill-researcher-hard/SKILL.md:206`
- `skill-planner-hard/SKILL.md:214`
- `skill-implementer-hard/SKILL.md:229`

**Why the current pattern is broken, precisely:**

`lit_context=$(cmd) || lit_context=""` — in bash, the exit status of `var=$(cmd)` *is* the exit status of `cmd`. On failure, `cmd`'s stdout (whatever was emitted before it died, typically none since `literature-briefing.sh` builds output in an array and only `cat`s the `<literature-briefing>` header/footer at the very end, after the per-entry loop that can crash) is already assigned to `lit_context`, so it is already `""`. The `|| lit_context=""` clause is therefore a no-op safety net that reinforces, rather than catches, the silent failure. Combined with `2>/dev/null` discarding literature-briefing.sh's own `Warning:`/`Error:` stderr lines, **no signal of any kind survives the invocation on crash** — the exit code is read nowhere, and stderr never reaches the transcript. This exactly matches the manual diagnosis in `.claude/output/lit.md` (lines 237-320): the agent had to run the script directly (`EXIT=5`), trace it with `bash -x`, and hand-build a replacement briefing inline, because the SKILL.md-prescribed invocation gave it nothing to go on.

**`literature-briefing.sh` non-zero exit paths** (from direct read of `.claude/scripts/literature-briefing.sh`):
- `set -euo pipefail` at the top (line ~41) means *any* unguarded failing command (e.g. a jq runtime error) kills the script immediately with that command's exit code — this was jq exit 5 in the task-799 bug, and could be any other future unguarded failure.
- Explicit `exit 1` for missing `--global` query argument.
- Explicit `exit 1` for missing `--top-n` numeric argument.
- All *legitimate empty* cases (missing sub-index, empty `entries` array, missing global index, no doc_ids resolved) use explicit `exit 0` with empty stdout — this is the case Stage 4a's comment `# - specs/literature-index.json is empty or missing` correctly describes, and it must remain silent/empty-context (no notice needed) since it's an intentional, already-announced-by-caller state.
- Task 799 already hardened three internal jq/arithmetic sites that fed unguarded bash arithmetic, but by design did **not** relax `set -e`/`pipefail` or wrap the loop in a function — meaning any *other* unguarded jq call anywhere else in the script (or in a future edit) can still produce the same silent-crash failure mode. This is exactly why task 800's consumer-side fix is complementary rather than redundant with task 799's script-side fix.

**`literature-lit-flag-resolve.sh` is unrelated to this bug, and is not actually wired into any of the six skills.**

Read of `.claude/scripts/literature-lit-flag-resolve.sh` (110 lines) confirms it only classifies *which branch of the Stage 4a decision tree applies* (`LIT_DISABLED` / `SUBINDEX_PRESENT` / `GLOBAL_MISSING` / `PROMPT_NEEDED` / `AUTONOMOUS_GLOBAL`) before `literature-briefing.sh` is ever invoked — it has no visibility into `literature-briefing.sh`'s own exit status and cannot detect a crash. It already follows the pattern this task should replicate: a directive/rationale printed to stdout/stderr respectively, with the calling skill responsible for surfacing anything visible.

Separately: `grep -rln "literature-lit-flag-resolve.sh" .claude/skills/*/SKILL.md .claude/context/` returns **only** `.claude/context/project/literature/patterns/adhoc-navigation-directive.md` — none of the six `SKILL.md` files reference this script at all, despite CLAUDE.md's "Literature Mode" section stating "each skill (skill-researcher, skill-planner, skill-implementer, and their `--hard` variants) resolves the situation via the shared helper `.claude/scripts/literature-lit-flag-resolve.sh`." The six skills still carry the older inline `AskUserQuestion` pseudocode (visible in the Stage 4a excerpts above) that predates this helper. This is a real CLAUDE.md/SKILL.md drift, but it is orthogonal to task 800's exit-status bug and should not be fixed as a side effect here — it would silently expand scope and risk conflating two unrelated defects in one diff. Recommend flagging as a separate follow-up task.

**Same bug reproduced verbatim in four extension skills (out of task 800's declared scope):**

```
.claude/skills/skill-cslib-research/SKILL.md:73
.claude/skills/skill-cslib-research-hard/SKILL.md:131
.claude/skills/skill-cslib-implementation/SKILL.md:85
.claude/skills/skill-cslib-implementation-hard/SKILL.md:170
```

Each has exactly one occurrence of the identical `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""` line. These are not named in task 800's scope, but once a shared wrapper exists, converting these four call sites is a trivial one-line-per-file follow-up (they should not be silently included in task 800's diff, to keep the change reviewable and matching the task's declared scope).

### External Resources

Not applicable — this is a pure codebase/shell-behavior investigation; no external documentation consulted.

### Recommendations

**Recommended approach: one new shared wrapper script + a mechanical find/replace in Stage 4a of all six skills.**

1. **Add `.claude/scripts/literature-briefing-invoke.sh`** (name matches the existing `literature-<verb>.sh` convention alongside `literature-lit-flag-resolve.sh`, `literature-create-setup-task.sh`, etc.). It should:
   - Accept and pass through all arguments verbatim to `literature-briefing.sh` (so it works for both per-repo mode with no args and `--global "<query>" [--top-n N]` mode).
   - Capture only `literature-briefing.sh`'s exit code — **do not** swallow its stderr; let `literature-briefing.sh`'s own `Warning:`/`Error:` lines flow through to the wrapper's stderr unmodified (this preserves today's behavior for legitimate warnings, e.g. "Global index not found at...").
   - On non-zero exit, additionally emit a single distinguishing line to stderr: `[lit] briefing generation failed (exit N)` (matching the `[lit]`/`[lit:auto]` notice-prefix convention already established in CLAUDE.md's "Literature Mode" section for `PROMPT_NEEDED`'s "Skip this run" and `AUTONOMOUS_GLOBAL`'s auto-selection notices) and print nothing to stdout.
   - On exit 0, print the script's stdout through unchanged (including the legitimate-empty case, which is still just an empty string — no extra notice, since that path is already covered by the existing GLOBAL_MISSING/PROMPT_NEEDED/AUTONOMOUS_GLOBAL announcements upstream in Stage 4a).
   - Minimal illustrative shape (for the implementer, not literal-final code):
     ```bash
     #!/usr/bin/env bash
     set -uo pipefail
     SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     output=$(bash "$SCRIPT_DIR/literature-briefing.sh" "$@")
     ec=$?
     if [ "$ec" -ne 0 ]; then
       echo "[lit] briefing generation failed (exit $ec)" >&2
       exit 0
     fi
     printf '%s' "$output"
     ```
     (Exiting 0 from the wrapper itself, after printing the notice, keeps every call site's existing `|| lit_context=""` fallback semantics intact with zero call-site restructuring — the `||` becomes dead code but harmless, or can be dropped in the same edit for cleanliness.)

2. **In each of the six `SKILL.md` files' Stage 4a**, replace all three occurrences (pseudocode comment, "If yes: run ..." prose instruction, and the live bash block) of
   ```
   bash .claude/scripts/literature-briefing.sh 2>/dev/null
   ```
   with
   ```
   bash .claude/scripts/literature-briefing-invoke.sh
   ```
   removing the `2>/dev/null` (the wrapper is now what decides what reaches stderr, and it must not be suppressed a second time by the call site).

3. **Rewrite the stale trailing comment** in the live bash block (all six skills) from
   ```
   # - script exited with error
   ```
   to something like
   ```
   # - literature-briefing.sh exited non-zero (wrapper already emitted a visible
   #   "[lit] briefing generation failed (exit N)" notice to stderr above)
   ```
   so the documentation no longer describes the silent-swallow as intended behavior.

4. **Do not** touch `literature-briefing.sh` itself (task 799's territory) or `literature-lit-flag-resolve.sh` (unrelated classifier, not part of the crash path).

5. **Do not** touch the four `skill-cslib-*` files in this task — flag them as a natural one-line-per-file follow-up once the wrapper exists, but keep task 800's diff scoped to the six named skills per the task description.

**Why a shared wrapper over per-skill duplicated bash:** the codebase already establishes this exact idiom for `--lit` cross-skill consistency — `literature-lit-flag-resolve.sh` is invoked identically (per CLAUDE.md's description, though see the drift finding above) from all `--lit`-supporting skills specifically so that "no directive branch defaults to an empty briefing without either a visible logged notice or an explicit user choice." A wrapper script keeps the "how do we detect and announce a crash" logic in exactly one place, so a future change to the notice format, or additional crash-recovery logic (e.g. retry-once), only needs a single edit instead of six-to-ten synchronized edits across skill files — which is precisely the kind of drift already found with `literature-lit-flag-resolve.sh` not being wired in everywhere it's documented to be.

## Decisions

- Confirmed the fix target is **Stage 4a** ("Memory Retrieval (Auto)") in all six skills, not "Stage 4b" as the task description states; Stage 4b is unrelated (report/plan format injection).
- Recommend a new shared script `literature-briefing-invoke.sh` rather than duplicating an exit-check bash snippet six times, to match the codebase's existing shared-helper idiom for `--lit` (`literature-lit-flag-resolve.sh`, `literature-create-setup-task.sh`).
- Recommend the notice format `[lit] briefing generation failed (exit N)` exactly as specified in the task description, matching the existing `[lit]`/`[lit:auto]` prefix convention.
- Recommend leaving `literature-briefing.sh`, `literature-lit-flag-resolve.sh`, and the four `skill-cslib-*` files untouched — out of task 800's declared scope, flagged instead as follow-ups.

## Risks & Mitigations

- **Risk**: If the wrapper swallows stdout on failure but a caller still checks `[ -n "$lit_context" ]` expecting non-empty on success only, behavior is unchanged from today (empty on failure) — the only behavior *added* is the visible stderr notice, so this is a strictly additive, low-risk change.
- **Risk**: Six files times three sites each (18 edit sites) risks partial/inconsistent application. Mitigation: since all three sites in each file are byte-identical strings today (`bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""` appears verbatim, differing only by pseudocode-comment prefix), a single deterministic find/replace per file (not manual editing) minimizes drift risk. The plan should call for a verification grep after edits: `grep -rn "literature-briefing.sh 2>/dev/null" .claude/skills/*/SKILL.md` should return zero results in the six target files afterward.
- **Risk**: Conflating this fix with the `literature-lit-flag-resolve.sh` wiring drift noted above would expand scope unpredictably. Mitigation: explicitly out of scope, called out for a separate follow-up task.

## Context Extension Recommendations

- **Topic**: `literature-lit-flag-resolve.sh` wiring drift (CLAUDE.md documents it as wired into all six skills; it is wired into none).
- **Gap**: No context file currently tracks the divergence between CLAUDE.md's "Literature Mode" narrative and the actual Stage 4a bash content in the six SKILL.md files.
- **Recommendation**: File a follow-up meta task (out of scope here) to either (a) actually wire `literature-lit-flag-resolve.sh` into Stage 4a of all six skills, replacing the inline `AskUserQuestion` pseudocode, or (b) correct CLAUDE.md's description to match current SKILL.md reality, whichever the maintainer prefers as source of truth.

## Appendix

- Search commands used: `grep -rn "LIT bytes\|literature-briefing.sh\|lit_context\|literature-lit-flag-resolve.sh"` across the six skill files; `grep -n "^### Stage" .claude/skills/*/SKILL.md`; `grep -rn "literature-briefing.sh" .claude/skills/*/SKILL.md` (repo-wide, found the four cslib extension sites); `grep -rln "literature-lit-flag-resolve.sh" .claude/skills/*/SKILL.md .claude/context/`.
- Direct reads: `.claude/scripts/literature-briefing.sh` (315 lines, full read), `.claude/scripts/literature-lit-flag-resolve.sh` (110 lines, full read), `.claude/output/lit.md` (lines 1-359, transcript of the manual diagnosis), `specs/799_literature_briefing_authors_type_crash_fix/summaries/01_authors-type-crash-fix-summary.md`.
