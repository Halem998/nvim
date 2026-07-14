# Ad-Hoc Navigation Directive (Primary-Session Conversational `--lit`)

## Trigger

The user asks conversationally to consult/search "the literature", a specific paper, or
otherwise invokes `--lit`-like behavior while the primary/root session is **not** inside a
`/research|/plan|/implement|/orchestrate --lit` dispatch — i.e. skill Stage 4a did not run for
this request. Without this directive, the primary session has no documented path to reproduce
Stage 4a's literature navigation, so it either fabricates ad-hoc behavior or silently does
nothing. Neither is acceptable.

## Procedure (mirrors Stage 4a, `--orchestrator-mode` hardcoded `false`)

A live user is always present in a conversational request, so the autonomous branch
(`AUTONOMOUS_GLOBAL`) is unreachable here — `--orchestrator-mode` is always passed as `false`.

1. Run the classification helper:

   ```bash
   bash .claude/scripts/literature-lit-flag-resolve.sh --lit-flag true \
     --orchestrator-mode false --query "<user request text>"
   ```

2. Branch on the directive token printed to stdout. Only four directives are reachable from the
   primary session (`AUTONOMOUS_GLOBAL` cannot occur since `--orchestrator-mode` is always
   `false`; `LIT_DISABLED` cannot occur since `--lit-flag` is always `true` here):

   - **`SUBINDEX_PRESENT`** → run the per-repo briefing with no arguments:

     ```bash
     bash .claude/scripts/literature-briefing.sh
     ```

   - **`GLOBAL_MISSING`** → emit a visible chat notice that no literature is available (no
     per-repo sub-index and no global Literature index found). Do not proceed silently — say so
     in the response, then continue without a briefing.

   - **`PROMPT_NEEDED`** → issue `AskUserQuestion` with the **identical** three options and
     wording used by Stage 4a (see `.claude/skills/skill-researcher/SKILL.md` lines 195-238):
     - **"Use global corpus now"** (recommended default, listed first): run
       `literature-briefing.sh --global "<query>"` and inject the result for this response only.
       No setup, no file writes.
     - **"Create curation task"**: run `literature-create-setup-task.sh` to create the
       `populate_literature_sub_index` task, then attempt the same Stage 4a-fork inline
       population Stage 4a uses (see SKILL.md lines 254-275) so this conversation also benefits;
       once `specs/literature-index.json` exists, run the no-arg `literature-briefing.sh`.
     - **"Skip this run"**: an explicit, user-chosen decision. Log `[lit] Skipped by user choice`
       and continue without a briefing — non-silent because it is an explicit, logged choice.

   - `LIT_DISABLED` and `AUTONOMOUS_GLOBAL` are not applicable here: the primary session only
     runs this procedure when the user has requested `--lit`-equivalent behavior (so
     `--lit-flag` is always `true`), and a live user is always present in a conversational
     request (so `--orchestrator-mode` is always `false`).

## Routing the Result

Once a `<literature-briefing>` block has been produced (or the branch above explicitly declined
to produce one), route it one of two ways:

- **(a) Self-execution** — the primary session answers the user's request directly: use the
  briefing content itself, running `literature-search.sh` and `Read`ing chunks on demand per
  `.claude/context/project/literature/patterns/agent-exploration.md`.

- **(b) Subagent dispatch** — the primary session is about to delegate to a subagent (e.g. via
  the `Agent` tool): inject the `<literature-briefing>` block into the subagent's prompt using
  the same placement rule as skill-researcher Stage 5 — after `<memory-context>` (if any) and
  before task-specific instructions.

Never dispatch an empty `<literature-briefing>` block. If no briefing was produced (the
`GLOBAL_MISSING` or "Skip this run" branches), inject nothing rather than an empty tag.

## Non-Silence Invariant

No branch above may silently inject nothing or silently auto-search. Every branch either:
produces a `<literature-briefing>` block, or explicitly and visibly announces why none was
produced (a logged notice or an explicit user choice). This mirrors the non-silence invariant
that governs Stage 4a itself.

## Sources of Truth

This file documents primary-session-specific *routing* (self-execution vs. subagent dispatch)
around the existing directive machinery — it does not re-derive the classification rules. For
the canonical classification logic and exact `AskUserQuestion` wording, see:

- Stage 4a in `.claude/skills/skill-researcher/SKILL.md` (lines 146-278) — the directive
  `case`/`esac`, the `PROMPT_NEEDED` three-option `AskUserQuestion` block, the Stage 4a-fork
  inline population procedure, and the Stage 5 injection-placement rule.
- `.claude/scripts/literature-lit-flag-resolve.sh` — the single source of truth for directive
  classification.

If Stage 4a's wording or branching changes, update this file to match rather than letting the
two drift apart.
