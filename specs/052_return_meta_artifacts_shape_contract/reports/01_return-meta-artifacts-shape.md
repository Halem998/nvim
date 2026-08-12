# Research Report: `.return-meta.json` `artifacts` Shape Is Unenforced and Frequently Undeclared

- **Status**: COMPLETE
- **Date**: 2026-08-11
- **Origin**: Detected live during an autonomous `/orchestrate` run in a consumer repository
  (ModelChecker). The orchestrator emitted `ARTIFACTS_SHAPE_MISMATCH` and recorded it as a system
  defect (`evt_1786510331206_WBl5l1`); the artifact had to be linked by hand.

## Summary

`.return-meta.json`'s `artifacts` field is normatively specified as an **array of objects**
(`{type, path, summary}`), but nothing enforces that shape and roughly a quarter of dispatchable
agents never show it. A `python-implementation-agent` dispatch wrote a **bare-string array**
instead:

```json
["specs/.../plans/01_....md", "specs/.../summaries/01_....md"]
```

The consumer could not resolve a path from it, so artifact linking silently produced nothing.
The work itself was complete and correct — only the machine-readable pointer to it was lost.

This is a **silent** failure of the same family as the settings-override defect documented
elsewhere: a wrong shape produces a no-op, not a crash, so it survives undetected until something
downstream happens to look.

## The Normative Contract

`core/context/formats/return-metadata-file.md` is unambiguous. `artifacts` is **required**, typed
as an *array of objects*, each carrying `type` / `path` / `summary`:

```json
"artifacts": [
  {
    "type": "report|plan|summary|implementation|handoff",
    "path": "specs/001_setup_lsp_config/reports/01_lsp-config-research.md",
    "summary": "Brief 1-sentence description of artifact"
  }
]
```

The same file declares itself normative for `.return-meta.json`,
`specs/.return-meta-multi-{session_id}.json`, and by reference `.orchestrator-handoff.json`.

## Finding 1: ~19 Agents Carry No Inline Template At All

A sweep of every `*/agents/*.md` in `agent-system/extensions/` for the `"artifacts"` key, and for
a `"type"` field within three lines of it (the marker of a correctly-shaped object template):

**No `"artifacts"` key anywhere in the file** — the agent is given no inline shape to copy:

| Extension | Agents |
|---|---|
| core | `code-reviewer-agent`, `general-research-hard-agent`, `planner-agent`, `planner-hard-agent`, `spawn-agent`, `synthesis-agent` |
| python | `python-implementation-agent`, `python-research-agent` |
| typst | `typst-implementation-agent`, `typst-research-agent` |
| z3 | `z3-implementation-agent`, `z3-research-agent` |
| latex | `latex-implementation-agent`, `latex-research-agent` |
| lean | `lean-implementation-hard-agent`, `lean-research-hard-agent` |
| cslib | `cslib-research-hard-agent` |
| email | `email-implementation-agent` |
| literature | `literature-agent` |

**Has an `"artifacts"` key but no adjacent `"type"` field** — a template exists but may not show
the object shape:

`cslib-vet-agent`, `filetypes-router-agent`, `lean-implementation-agent`, `lean-research-agent`,
and `lean/context/project/lean4/lean-implementation-flow.md`.

By contrast `core/general-implementation-agent.md` carries a full, correct inline template.

## Finding 2: Absence of a Template Correlates With — But Does Not Determine — Failure

Both `python-implementation-agent` and `python-research-agent` lack an inline template. In the
observed run, the **research** dispatch nonetheless wrote a correctly-shaped `artifacts` array
(its path resolved cleanly), while the **implementation** dispatch wrote bare strings.

The behavior is therefore *non-deterministic*: without an inline example, an agent may or may not
recover the shape from the shared format document. This is the worst failure profile for
detection — it works often enough to look fine, and the failures land unpredictably.

`core/planner-agent.md` also has no inline template and also produced a correct array in the same
run, reinforcing the same conclusion.

## Finding 3: There Is No Validator, and Detection Is Structurally Partial

`core/scripts/` contains `validate-artifact.sh`, `validate-handoff.sh`, `validate-state.sh`,
`validate-index.sh`, `validate-wiring.sh`, `validate-context-*.sh` — but **no
`validate-return-meta.sh`**. Nothing checks this file's shape at write time or read time.

The only detection is opportunistic. `orchestrate-recover-outcome.sh` computes
`ARTIFACTS_SHAPE_MISMATCH` when a non-empty `artifacts` array yields no resolvable path, and
`skill-orchestrate/SKILL.md` consumes it. But that consumer arm sits on the **recovered** path
only — the branch reached when no handoff was written. `skill-orchestrate/SKILL.md`'s own
"Known residual gap" note states this directly: the handoff-present path never calls
`orchestrate-recover-outcome.sh`, so the signal is never *computed* there at all.

Consequence: a malformed `artifacts` array written by a dispatch that DID produce a handoff is
invisible to every existing mechanism.

## Finding 4: Not Covered by Any Existing Task

Reviewed every non-terminal task in the agent-system repo. The nearest neighbour is
`fix_return_meta_lifecycle_ordering`, which concerns *when* `.return-meta.json` is deleted
relative to `command-gate-out.sh` consuming it — an ordering defect, not a shape defect. The two
are independent: fixing the ordering would still consume a malformed array, and fixing the shape
would still be defeated by premature deletion. No other task mentions the artifacts shape.

## Impact

- Artifact links silently missing from `state.json` / `TODO.md`, so a completed report, plan, or
  summary becomes undiscoverable through the task system even though the file exists.
- The orchestrator's artifact-linking postflight becomes a no-op without saying so.
- Blast radius is every task type routed to one of the ~19 template-less agents, which includes
  the `python`, `z3`, `typst`, and `latex` extensions in their entirety, plus core's `planner-agent`
  — an agent on the default path for nearly every task.

## Recommendations

Ordered by leverage. The first two are complementary, not alternatives.

1. **Add `validate-return-meta.sh`** — the missing sibling of `validate-handoff.sh`. Validate
   `artifacts` is an array of objects each carrying `type`/`path`/`summary`, and that `path`
   resolves. Wire it where `.return-meta.json` is consumed, and consider a `--fix` mode that
   promotes a bare string to `{path: <string>}` with the type inferred from the path segment
   (`reports/` → `report`, `plans/` → `plan`, `summaries/` → `summary`), since that repair is
   unambiguous.
2. **Give every dispatchable agent an inline template.** Copy the shape from
   `core/general-implementation-agent.md`. This is mechanical and is the fix that would have
   prevented the observed failure outright.
3. **Close the handoff-present detection hole** named in `skill-orchestrate/SKILL.md`'s own
   residual-gap note, so `ARTIFACTS_SHAPE_MISMATCH` is computed on both paths rather than only
   after recovery.
4. **Consider a lint gate** in `verify-deploy.sh`, in the same family as
   `lint-agent-contracts.sh`, asserting every dispatchable agent declares a correctly-shaped
   `artifacts` template. This converts a recurring class of defect into a deploy-time failure.

## Open Questions For Planning

- Should the consumer become tolerant of bare strings (accept and normalize), or should the
  contract stay strict with the failure made loud? Tolerance risks entrenching the malformed
  shape; strictness risks losing artifacts until every agent is fixed. A `--fix`-style
  normalization at a single chokepoint, paired with a loud notice, may capture both.
- Do the "has key but no adjacent `type`" agents (notably the `lean` family) actually emit a
  correct shape? Each needs reading in full; the proximity heuristic used in this sweep cannot
  settle it.
- Is `core/planner-agent.md` worth prioritizing ahead of the extension agents, given it sits on
  the default path for nearly every task?

## References

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — normative contract
- `agent-system/extensions/core/agents/general-implementation-agent.md` — correct inline template
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — computes the signal
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — consumes it; states the
  residual gap
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the predicate
- `agent-system/extensions/core/scripts/validate-handoff.sh` — the model for the missing validator
