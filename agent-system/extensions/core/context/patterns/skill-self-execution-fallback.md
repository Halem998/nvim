# Shared Self-Execution Fallback (Stage 5b)

**Placed in core context** so the `@`-import below resolves for every skill that can fall back to
inline (non-subagent) execution, regardless of which extension owns the importing skill. This
file is the SINGLE canonical Stage 5b block. It stays a prose `@`-import rather than becoming a
`skill-base.sh` function because it is agent instructions directed at whichever agent is
executing the skill — a "notice what you just did and write a file accordingly" directive — not
shell logic with a fixed input/output contract. Before this block existed, some skills had no
Stage 5b at all: the report found the team skills' degraded path ("Stage 4a: Fallback to Single
Agent" in `skill-team-research`/`skill-team-plan`/`skill-team-implement`) re-delegates wholesale
to a single-agent skill instead of writing return metadata itself, which means a team run that
falls back produces **no** `.return-meta.json` of its own — the exact defect class this block
exists to close. Every instruction below is DIRECT and EXECUTABLE prose — there is no bash fence
to keep pseudocode out of, but the same "no vague hand-waving" bar applies: an importing skill
must be able to follow this block's steps literally.

A skill importing this block MUST NOT also keep an inline copy of Stage 5b. If the importing
skill's own body still contains a hand-written "if you did the work directly, write metadata"
paragraph sitting alongside this import, that is drift re-accumulating and must be deleted, not
kept "just in case".

## Preconditions (state the importing skill already has in scope)

- The importing skill has a defined "primary path" (normally: invoke the Agent tool with a
  specific `subagent_type`) and this stage is reached only when that primary path was NOT taken —
  the skill (or the orchestrating agent executing it) performed the work directly instead:
  reading files, writing artifacts, or updating metadata without ever spawning a subagent.
- The importing skill already knows its own operation's success status value
  (`"researched"` | `"planned"` | `"implemented"`, or a team-specific equivalent) and the
  `return-metadata-file.md` schema location
  (`@.claude/context/formats/return-metadata-file.md`).

## Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent — including a team
skill's degraded single-agent fallback path), you MUST write a `.return-meta.json` file now,
before proceeding to postflight. Use the schema from `return-metadata-file.md` with the
appropriate success status value for this operation and the artifact information for whatever you
actually produced.

This write obligation is not optional and is not satisfied by the re-delegated agent's own
`.return-meta.json` write in a wholesale-redelegation fallback — if this skill's fallback
re-delegates the ENTIRE operation to another skill/agent (rather than performing the work itself),
the re-delegated agent's metadata write already satisfies this obligation and this stage is a
no-op; if instead this skill's fallback performs SOME OF the work itself (e.g. a team skill
degrading to a single teammate it drives directly, rather than invoking a separate skill), THIS
skill must write `.return-meta.json` itself, because no other agent will.

If you DID use the Agent tool (the skill's normal Stage 5), skip this stage entirely — the
subagent already wrote the metadata, and writing it again here would silently clobber whatever
the subagent produced.

## Failure Semantics

If this stage is reached, the fallback path was taken, and the fallback subsequently fails to
produce any artifact at all (no report, no plan, no implementation), still write
`.return-meta.json` — with `status: "failed"` and an empty or explanatory `artifacts` array, not a
skipped write. Postflight (Stage 6 onward) unconditionally reads this file; a missing file is
treated as `status: "failed"` by `skill_read_metadata`, but the explicit write here is preferred
over relying on that fallback, since it lets this stage record a specific `failure reason` the
implicit fallback cannot.
