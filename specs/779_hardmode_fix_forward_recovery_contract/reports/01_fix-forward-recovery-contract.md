# Research Report: Task #779

- **Task**: 779 - Hard-mode: fix-forward recovery contract (disambiguate 'restore green')
- **Started**: 2026-07-03T15:20:00Z
- **Completed**: 2026-07-03T15:26:00Z
- **Effort**: ~1 hour (research)
- **Dependencies**: 778 (DONE — strategic-sorry skeleton policy), 780 (DONE — git-snapshot.sh + guard-destructive-git.sh + git-workflow.md rule)
- **Sources/Inputs**: Codebase read (contracts/, rules/, skills/, agents/, scripts/, hooks/), specs/state.json
- **Artifacts**: This report; `.orchestrator-handoff.json`
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- New file `.claude/context/contracts/recovery.md` should hold the canonical Recovery Ladder contract — it fits the existing one-file-per-H-technique pattern in `contracts/` (anti-analysis.md=H2, wrap-up.md=H9, territory.md=H7, convergence.md=H6, adversarial-verification.md=H4, reference-grounding.md=H3) rather than a section bolted onto wrap-up.md, which is already schema-dense (handoff JSON, sorry_inventory, commit discipline).
- The 3-rung ladder maps directly onto mechanisms that already exist and just need naming/sequencing: rung (a) fix-forward has no existing artifact (it is the new default-behavior statement); rung (b) is `anti-analysis.md`'s five-condition strategic-sorry test + `wrap-up.md`'s `skeleton:true`/`sorry_inventory` schema (both already shipped by task 778); rung (c) is `git-workflow.md`'s "No Destructive Git on Uncommitted Work" rule + `.claude/scripts/git-snapshot.sh` + `.claude/hooks/guard-destructive-git.sh` (all shipped by task 780).
- `skill-orchestrate-hard/SKILL.md`'s `build_hard_mode_prompt_context()` (lines 305-319) is the single, precise injection point for the disambiguated phrasing — it is the only place in the repo that currently constructs per-dispatch hard-mode prompt text, and it presently has zero mention of RED/green/recovery, confirming the motivating failure's ambiguous "restore green" wording was ad-libbed by a live orchestrator rather than sourced from any template.
- `.claude/rules/error-handling.md`'s "Build Error Recovery" block (4 lines: capture/log/"Keep source unchanged"/report) is compatible with fix-forward in spirit but never says so explicitly, and sits directly above the jq-recovery block that already models a "retry-then-fix" pattern — it needs one added line making "keep source unchanged" mean "do not revert to fix a RED build; report/fix in place," plus a cross-reference to the new `recovery.md`.
- Every rules/skills/agent file this task touches (`error-handling.md`, `git-workflow.md`, `skill-orchestrate-hard/SKILL.md`, `general-implementation-hard-agent.md`) has an identical dual copy under `.claude/extensions/core/` that must be edited in lockstep; `context/contracts/*.md` files, by contrast, have no core-extension mirror and exist only under `.claude/context/contracts/` (single source), so the new `recovery.md` only needs to be written once.

## Context & Scope

Task 779 asks for an unambiguous recovery contract so "reach green"/"restore green" always means
fix-forward, never revert-to-prior-commit, plus a canonical 3-rung recovery ladder (fix forward →
strategic-sorry skeleton → snapshot-then-rollback), wired into the hard-mode implementation
contract and into `skill-orchestrate-hard`'s dispatch prompt construction, and aligned with
`error-handling.md`'s Build Error Recovery section. Both hard dependencies (778: strategic-sorry
skeleton; 780: snapshot-before-destructive-git) are `status: "completed"` in `specs/state.json`,
and their mechanisms were read directly from the current source (not assumed from the task
description) per the task's explicit instruction.

## Findings

### Codebase Patterns

**`.claude/context/contracts/` — the contract-per-H-technique pattern**

```
adversarial-verification.md   H4  loaded by: general-research-hard-agent, cslib/lean research-hard
anti-analysis.md              H2  loaded by: general-implementation-hard-agent, general-research-hard-agent
convergence.md                H6  loaded by: (skill-level only; no agent load_when entries)
reference-grounding.md        H3  loaded by: general-research-hard-agent, planner-hard-agent
territory.md                  H7  loaded by: general-implementation-hard-agent
wrap-up.md                    H9  loaded by: general-implementation-hard-agent
```

Each file in `.claude/context/index.json` has a `subdomain: "contracts"`, `domain: "core"` entry
with `load_when.agents: [...]`. `convergence.md` (H6) shows precedent for a contract with an
**empty** `load_when.agents` array — its consumer is `skill-orchestrate-hard` itself (a skill,
not an agent), read directly rather than injected via agent context references. This is the exact
shape task 779's ladder needs: `recovery.md` is consumed by (1) an agent
(`general-implementation-hard-agent`, via its Context References list, same as
`anti-analysis.md`/`wrap-up.md`), and (2) a skill (`skill-orchestrate-hard`, which reads it
directly to build `build_hard_mode_prompt_context()`, same as `convergence.md`'s consumption
pattern by the churn-detection stage).

Both `anti-analysis.md` and `wrap-up.md` open with an identical boilerplate line:
```
**`--hard`-only**: This entire contract is loaded exclusively by hard-mode dispatch paths
(`skill-implementer-hard`, `general-implementation-hard-agent`, `skill-orchestrate-hard`);
STANDARD mode never loads this file...
```
`recovery.md` should carry the same disclaimer for its *ladder rungs b and c as formal contract
sections* (strategic-sorry and snapshot-marker mechanics are hard-mode/task-780 machinery), while
being explicit that **the fix-forward directive in rung (a) is phrased so it is safe to also state
verbatim in standard-mode dispatch prompts** — this satisfies the task's "must be safe for
standard mode too" requirement without claiming the whole file is loaded outside `--hard`.

**Task 778's actual mechanism (`anti-analysis.md` lines 59-84, "Strategic sorries")**

Five conditions, ALL required, for a main-target-level placeholder to count as a strategic sorry
rather than a forbidden abandoned/stuck placeholder:
1. Deliberate division boundary (planned skeleton division point, not a stuck attempt)
2. Tightly scoped (one theorem/function/definition, not a module or file)
3. Documented (comment states assumption, why-deferred, owning follow-up task)
4. Tracked (recorded in handoff `sorry_inventory` with `strategic: true` + non-null `follow_up_task`)
5. Build-green (the placeholder itself is syntactically/type-valid — `sorry` in Lean4, `admit`,
   `raise NotImplementedError`, or an explicit `-- STUB:` marker — and the build/typecheck passes)

A dispatch meeting all five reports `status: "implemented"`, `skeleton: true` in
`.orchestrator-handoff.json` (schema in `wrap-up.md` lines 12-63), with a full 7-field
`sorry_inventory` entry per sorry: `{file, line, statement, strategic, assumption, why_deferred,
follow_up_task}`. This is exactly rung (b): "the build goes green WITHOUT losing structure."

**Task 780's actual mechanism (`git-snapshot.sh` + `guard-destructive-git.sh` + `git-workflow.md`)**

- `.claude/scripts/git-snapshot.sh [--branch] [TASK]`: no-op on a clean tree; on a dirty tree,
  writes `specs/{NNN}_{SLUG}/working-progress-{ts}.patch` (git diff HEAD) plus a belt-and-suspenders
  `git stash push -u` (default mode) or a WIP commit on a `wip-snapshot-{ts}` scratch branch
  (`--branch` mode), then writes `specs/{NNN}_{SLUG}/.git-snapshot-marker` (KEY=VALUE:
  `TIMESTAMP`, `HEAD_SHA`, `PATCH_PATH`, `STASH_REF`, `BRANCH_NAME`).
- `.claude/hooks/guard-destructive-git.sh` (PreToolUse Bash hook): on a dirty tree, blocks
  (`exit 2` + stderr) `git reset --hard`, `git checkout -- <path>`, `git restore <path>` (without
  `--staged`), `git clean -fd` (any flag order), `git stash drop`/`clear`, and forced
  `git checkout`/`git switch` (`-f`/`--force`) — UNLESS a `.git-snapshot-marker` younger than 120s
  exists anywhere under `specs/**` (found via `find specs -maxdepth 3 -name .git-snapshot-marker`),
  in which case it deletes the marker (single-shot consumption) and allows the command through.
  Clean-tree commands are always exempt (`git status --porcelain` empty ⇒ exit 0 immediately).
- `.claude/rules/git-workflow.md` "No Destructive Git on Uncommitted Work" (lines 84-119) is the
  human-readable rule text mirroring the hook's exact command list and exemptions, plus the
  instruction: "Before any intentional rollback that would otherwise be blocked, run
  `bash .claude/scripts/git-snapshot.sh` first, then retry the destructive command."

This is exactly rung (c): "SNAPSHOT first ... then roll back, smallest revert scope." Rung (c)'s
contract text should cite the script/hook by name and command, not paraphrase it, since the hook
is the actual enforcement — the contract's job is to make the ladder's *ordering and rationale*
explicit ("only after (a) and (b) have failed"), not to re-describe hook internals.

**`skill-orchestrate-hard/SKILL.md`'s dispatch-prompt construction (lines 267-344)**

`build_hard_mode_prompt_context()` (lines 307-318) is a bash function returning a fixed 4-item
"HARD MODE DISPATCH — CONTRACT SLOTS" block, interpolated into both the per-phase dispatch prompt
(line 301) and the parallel-wave dispatch prompt (line 339):
```
1. Mission: Implement phase $next_phase only. Do not continue past this phase.
2. Anti-Analysis Rules: Read .claude/context/contracts/anti-analysis.md. First file edit within 20% of tool calls.
3. Wrap-up Contract: Write .orchestrator-handoff.json before terminating. Incremental commits.
4. Settled Design Preamble: State the decided design before first tool call.

PHASES COMPLETED: $phases_completed of $phases_total
```
A grep of the entire 543-line SKILL.md for `RED`, `green`, `build error`, `revert`, `rollback`,
and `restore green` returns **zero matches** — confirming the motivating failure's ambiguous
"if RED, first restore green" instruction was not sourced from this template; it was generated
live by an orchestrator constructing an ad-hoc prompt outside this function. This is the strongest
argument for baking a 5th contract slot into `build_hard_mode_prompt_context()`: once the phrasing
lives in the template, every per-phase and parallel-wave dispatch emits it automatically and no
orchestrator has to improvise wording under time/context pressure.

Stage 6 (Blocker Escalation, lines 464-496) is the other place dispatch prompts get constructed
(blocker-research re-dispatch, line 484-487) but it dispatches to `$RESEARCH_AGENT`, not an
implementation agent, so it is out of scope for the recovery ladder (which only applies to
implementation dispatches that could encounter a RED build).

**`general-implementation-hard-agent.md`'s Context References + Stage 5 wrap-up**

The agent file (`.claude/agents/general-implementation-hard-agent.md`, identical to
`.claude/extensions/core/agents/general-implementation-hard-agent.md`) already lists
`anti-analysis.md` and `wrap-up.md` as "MANDATORY" Context References (lines 26-27) and has a
"Strategic-Sorry Skeleton (Hard Mode)" section (lines 44-52) summarizing the five-condition test
inline plus a worked handoff JSON example (Stage 5, Step 1, lines 220-244). It has **no reference
to git-snapshot.sh, guard-destructive-git.sh, or any recovery/rollback language** — task 780's
mechanisms are enforced purely at the hook layer and via `git-workflow.md`, never surfaced in this
agent's own instructions. Adding `@.claude/context/contracts/recovery.md` to its Context
References list (same MANDATORY tier as anti-analysis.md/wrap-up.md) and a short "Recovery Ladder"
section mirroring the existing "Strategic-Sorry Skeleton" section is the natural insertion point.

**`skill-implementer-hard/SKILL.md`**

Already references `anti-analysis.md`, `wrap-up.md`, `territory.md` at lines 24-26 ("loaded by
agent") and passes "anti-analysis contract reference and territory params" in its own dispatch
prompt construction (line 239). This is the second dispatch-prompt-construction site (besides
`skill-orchestrate-hard`) that the task explicitly names as a consumer — it should get the same
`recovery.md` reference addition, consistent with how it already lists the other two hard-mode
contracts.

### Dual Deployed/Source Copies

Confirmed by direct diff — files with an identical mirror under `.claude/extensions/core/` that
must be edited in both places (or via whatever sync tooling the repo uses) to stay consistent:

| File | Deployed | Source (identical) |
|------|----------|---------------------|
| `general-implementation-hard-agent.md` | `.claude/agents/` | `.claude/extensions/core/agents/` |
| `error-handling.md` (rule) | `.claude/rules/` | `.claude/extensions/core/rules/` |
| `git-workflow.md` (rule) | `.claude/rules/` | `.claude/extensions/core/rules/` |
| `skill-orchestrate-hard/SKILL.md` | `.claude/skills/` | `.claude/extensions/core/skills/` |
| `error-handling.md` (standard, distinct from the rule) | `.claude/context/standards/` | `.claude/extensions/core/context/standards/` |

By contrast, **`.claude/context/contracts/*.md` (anti-analysis.md, wrap-up.md, territory.md,
convergence.md, adversarial-verification.md, reference-grounding.md) have NO core-extension
mirror** — `find .claude/extensions/core -iname "anti-analysis.md" -o -iname "wrap-up.md"`
returns nothing; these files exist only under `.claude/context/contracts/`, not registered in
`.claude/extensions/core/manifest.json` either. (The `lean` extension has its own *override*
copies of `anti-analysis.md`, `reference-grounding.md`, `adversarial-verification.md` under
`.claude/extensions/lean/context/contracts/` — that is the documented "Domain Specialization"
pattern, not a sync duplicate, and out of scope here since task 779 is domain-agnostic.) This
means the new `recovery.md` is a **single-copy file** with no sync burden — write it once at
`.claude/context/contracts/recovery.md` and register it once in `.claude/context/index.json`.

### `.claude/rules/error-handling.md` — Build Error Recovery (current text, lines 82-87)

```
### Build Error Recovery
```
1. Capture error output
2. Log to errors.json
3. Keep source unchanged
4. Report error with context
```
```

This is compatible with fix-forward (it never says "revert"), but "Keep source unchanged" is
itself ambiguous in the opposite direction — read literally it could suggest *not even fixing
forward*, i.e., freezing the source and only reporting. In context (this is the generic,
non-hard-mode error-handling rule, sitting between "Timeout Recovery" and "jq Parse Failure
Recovery," both of which describe active-repair flows) it most likely means "don't silently patch
around the error without understanding it" / "don't revert to hide the failure" rather than
"never touch the file" — but the task explicitly flags this line for alignment, and the ambiguity
is real. Recommend rewording to something unambiguous, e.g.:

```
### Build Error Recovery
1. Capture error output
2. Log to errors.json
3. Fix forward: correct the source to resolve the error. Never discard uncommitted changes to
   reach a passing build — see .claude/context/contracts/recovery.md for the full recovery ladder
   (fix forward -> strategic-sorry skeleton -> snapshot-then-rollback) and the "No Destructive Git
   on Uncommitted Work" rule in git-workflow.md.
4. Report error with context
```

This also needs to land in the `.claude/extensions/core/rules/error-handling.md` mirror (confirmed
identical byte-for-byte to the deployed copy today).

The separate, much larger `.claude/context/standards/error-handling.md` (1056 lines, a
generic pattern-catalog document for building error-handling systems generally, not specific
day-to-day agent guidance) contains a "3. Rollback Strategy" pattern (lines 863-891) with an
example `git reset --hard {safety_commit}`. This pattern already requires "Create safety
checkpoint before operation" as step 1 — i.e., it independently encodes the same
snapshot-before-rollback discipline task 780 formalized, just for a different scenario (mid-way
multi-file-write failure with a pre-planned checkpoint, not an agent misreading an ambiguous
"restore green" instruction). It is not the file task 779 names in scope (`error-handling.md`
"Build Error Recovery" refers to the rule, confirmed by the task's own text: "'Keep source
unchanged' / 'Never lose completed work'" — that exact phrase "Never lose completed work" does
NOT appear verbatim in either error-handling.md file; closest existing text is "Never lose
completed work" under `## Error Handling` in the top-level `.claude/CLAUDE.md` ("On failure: ...
preserve partial progress") and "2. Preserve Progress / Never lose completed work" in
`.claude/rules/error-handling.md` lines 45-49). This standards file is optional/secondary
alignment scope — worth a one-line cross-reference to `recovery.md` in its Rollback Strategy
section, but not a required edit for task 779's stated scope.

### External Resources

Not applicable — this is a pure meta/agent-system task with all relevant material local to the
repository; no web research was needed or performed.

### Recommendations

1. **Create `.claude/context/contracts/recovery.md`** (new file, single copy, no extension
   mirror needed) as the tenth contract file, following the exact structural convention of
   `anti-analysis.md`/`wrap-up.md`: an opening paragraph naming the technique, a `--hard`-only
   disclaimer scoped to rungs (b)/(c) only, then the ladder itself. Suggested skeleton:
   - **Title/intro**: "Recovery Contract — Fix-Forward Discipline" (avoid minting a new "H10"
     label in this research report; defer the H-numbering decision, if any, to planning, since
     CLAUDE.md's Hard Mode section enumerates H1-H9 by name and adding a tenth would require a
     CLAUDE.md edit not explicitly requested by task 779).
   - **"Green" Means Fix Forward** section: the canonical disambiguation statement (see exact
     wording below).
   - **The Recovery Ladder** section: three rungs, each naming its actual mechanism and file
     paths (not paraphrased) — rung (a) has no external file (it is the default action itself);
     rung (b) cites `anti-analysis.md`'s five-condition test + `wrap-up.md`'s `skeleton`/
     `sorry_inventory` schema by section name; rung (c) cites `git-snapshot.sh`,
     `guard-destructive-git.sh`, and `git-workflow.md`'s rule by path/command.
   - **Domain Specialization** section (matching the pattern in anti-analysis.md/wrap-up.md),
     noting rung (b) is inherently domain-specific (Lean4 `sorry`, Python `NotImplementedError`,
     etc.) and pointing to the existing per-domain sub-sorry conventions.

2. **Canonical disambiguation statement** (drop-in text for `recovery.md`'s lead section):
   > "Reach green" and "restore green" mean: make the current working tree pass its build/tests
   > by adding or correcting code — **fix forward**. They NEVER mean: `git reset`, `git checkout`,
   > `git restore`, or any other revert/rollback to a prior commit while uncommitted changes exist.
   > An agent MUST NOT discard uncommitted work to reach green. If a rollback is genuinely the
   > right call, it is rung (c) of the ladder below, and it is preceded by a mandatory snapshot.

3. **The 3-rung ladder** (drop-in text, referencing the actual mechanisms found above):
   > **Rung (a) — Fix forward (always attempt first).** Diagnose the RED cause and correct it in
   > place: add the missing code, fix the defect, complete the implementation. This is the only
   > default action; rungs (b) and (c) exist only for the cases where (a) is genuinely blocked.
   >
   > **Rung (b) — Strategic-sorry skeleton (when a sub-goal is genuinely blocked).** Land a
   > documented placeholder meeting all five conditions in `anti-analysis.md`'s "Strategic
   > sorries" test (deliberate division boundary, tightly scoped to one theorem/function/
   > definition, documented, tracked, build-green). Report `status: "implemented"`,
   > `skeleton: true`, with a full `sorry_inventory` entry per `wrap-up.md`'s schema. This reaches
   > green without losing structure — it is a division marker, not a discard.
   >
   > **Rung (c) — Snapshot, then roll back, smallest scope (last resort only).** Only when
   > rollback is truly required — never as a first response to RED. Before running any
   > destructive git command, run `bash .claude/scripts/git-snapshot.sh [--branch] <task>`
   > (writes a durable `.patch` + stash backup, or a WIP branch commit, and a 120s freshness
   > marker). `.claude/hooks/guard-destructive-git.sh` enforces this automatically: it blocks
   > `git reset --hard`, `git checkout -- <path>`, `git restore <path>` (non-staged),
   > `git clean -fd`, `git stash drop`/`clear`, and forced checkout/switch on a dirty tree unless
   > a fresh snapshot marker exists. Prefer the smallest revert scope (a single file or path) over
   > a broad `git reset --hard`.

4. **`skill-orchestrate-hard/SKILL.md`** — add a 5th slot to `build_hard_mode_prompt_context()`
   (both copies: `.claude/skills/` and `.claude/extensions/core/skills/`), e.g.:
   > `5. Recovery Discipline: If RED, FIX FORWARD to reach green — never revert/reset/checkout to
   > a prior commit. If a sub-goal is genuinely blocked, land a documented strategic-sorry
   > skeleton (anti-analysis.md) instead of discarding structure. Only if rollback is truly
   > required: snapshot first via 'bash .claude/scripts/git-snapshot.sh', then use the smallest
   > revert scope. Full ladder: .claude/context/contracts/recovery.md.`
   This makes the disambiguated phrasing the *default* for every per-phase (line 301) and
   parallel-wave (line 339) dispatch, closing the exact gap that produced the motivating failure
   (an orchestrator improvising "restore green" outside any template).

5. **`skill-implementer-hard/SKILL.md`** — add `recovery.md` to the Context References list
   (line ~24-26 area) alongside `anti-analysis.md`/`wrap-up.md`/`territory.md`, and mention it in
   the dispatch-prompt-construction text at line 239 ("Pass anti-analysis contract reference and
   territory params...") so both named dispatch-prompt-construction sites are covered per the
   task's explicit scope item 3.

6. **`general-implementation-hard-agent.md`** (both copies) — add
   `@.claude/context/contracts/recovery.md` to the MANDATORY Context References list (next to
   `anti-analysis.md`/`wrap-up.md`), and add a short "Recovery Ladder (Hard Mode)" section
   mirroring the existing "Strategic-Sorry Skeleton (Hard Mode)" section (lines 44-52), stating
   the fix-forward default and pointing to rung (b)/(c) mechanics rather than re-deriving them.

7. **`.claude/rules/error-handling.md`** (both copies) — reword the "Build Error Recovery" block
   per the drop-in text above (Findings section), replacing the ambiguous "Keep source unchanged"
   with an explicit fix-forward + no-discard statement and a cross-reference to `recovery.md` and
   the existing `git-workflow.md` "No Destructive Git" rule.

8. **Optional/secondary**: one-line cross-reference from `.claude/context/standards/error-handling.md`'s
   "3. Rollback Strategy" pattern (line ~863) to `recovery.md`, noting that agent-facing
   rollback (as opposed to this file's generic multi-file-write-failure pattern) always follows
   the ladder. Not required by task 779's stated scope; flagged for planner discretion.

## Decisions

- Recovery contract lives in a **new standalone file** `.claude/context/contracts/recovery.md`,
  not a section appended to `wrap-up.md`. Rationale: matches the established one-contract-per-file
  convention, keeps `wrap-up.md` (already schema-dense) focused on handoff/commit mechanics, and
  gives the recovery ladder its own `index.json` entry so it can be independently referenced by
  both an agent (Context References) and a skill (direct read in `skill-orchestrate-hard`), the
  same dual-consumption shape already proven by `convergence.md`.
- Do not mint a new "H10" label in this research phase; the CLAUDE.md Hard Mode section's H1-H9
  enumeration is out of task 779's explicit scope and any renumbering/labeling decision should be
  made explicitly during planning, not implied by the research report.
- The ladder's rung (a) fix-forward *statement* (not the full contract file) is written to be
  safe/quotable in standard-mode contexts too, satisfying the task's "must be safe for standard
  mode too" requirement, while the file as a whole retains the same `--hard`-only load disclaimer
  used by anti-analysis.md/wrap-up.md for rungs (b)/(c).
- `.claude/context/standards/error-handling.md`'s Rollback Strategy section is treated as
  optional/secondary alignment (not required scope) since the task names `error-handling.md`
  "Build Error Recovery" specifically, which is the rule file, not the standards file.

## Risks & Mitigations

- **Risk**: Editing `build_hard_mode_prompt_context()` without updating both the
  `.claude/skills/skill-orchestrate-hard/SKILL.md` and `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  copies would silently reintroduce drift the moment either copy is treated as canonical.
  **Mitigation**: Plan phase must explicitly list both paths as a single atomic edit, verified
  with `diff` post-edit (as this report did for the pre-existing state).
- **Risk**: Rewording `error-handling.md`'s "Build Error Recovery" could be read as loosening the
  existing "3. Keep source unchanged" guarantee if not phrased carefully (i.e., someone might read
  the new "fix forward" language as license to make large speculative changes).
  **Mitigation**: The drop-in wording above keeps "Fix forward: correct the source to resolve the
  error" scoped narrowly ("correct... to resolve the error", not "make any changes"), and adds
  the explicit "Never discard uncommitted changes" clause rather than removing the original
  intent.
- **Risk**: A future contract file added to `.claude/extensions/core/context/contracts/` (were one
  ever created, e.g. by an extension needing a domain override for recovery.md, mirroring the
  lean extension's pattern for anti-analysis.md) could diverge from the core version. **Mitigation**:
  Not applicable to this task (no extension override requested), but the report notes the
  `lean` extension override pattern for the planner's awareness in case a future task requests one
  for `recovery.md`.

## Context Extension Recommendations

- **Topic**: Recovery/rollback discipline for hard-mode agents
- **Gap**: `.claude/context/index.json` has no entry (and no file) for a recovery contract; the
  `contracts` subdomain currently documents H2/H3/H4/H6/H7/H9 but has no cross-cutting
  "what does GREEN mean" statement, leaving each contract to implicitly assume it without stating
  it.
- **Recommendation**: The planned `recovery.md` file should be registered in
  `.claude/context/index.json` under `subdomain: "contracts"`, `domain: "core"`, with
  `load_when.agents: ["general-implementation-hard-agent"]` (matching `anti-analysis.md`'s and
  `wrap-up.md`'s pattern) and `keywords` including `fix-forward`, `recovery-ladder`,
  `strategic-sorry`, `snapshot`, `restore-green`, `rollback` for discoverability in future
  context-gap-detection passes.

## Appendix

### Files Read
- `.claude/context/contracts/anti-analysis.md` (68 lines)
- `.claude/context/contracts/wrap-up.md` (94 lines, incl. Build-Green Invariant, sorry_inventory schema)
- `.claude/context/contracts/territory.md`, `convergence.md`, `adversarial-verification.md`, `reference-grounding.md` (listing/index only)
- `.claude/rules/git-workflow.md` (198 lines, incl. "No Destructive Git on Uncommitted Work")
- `.claude/rules/error-handling.md` (Build Error Recovery block, lines 82-87)
- `.claude/context/standards/error-handling.md` (1056 lines; Rollback Strategy pattern, lines 863-891)
- `.claude/scripts/git-snapshot.sh` (193 lines, full read)
- `.claude/hooks/guard-destructive-git.sh` (149 lines, full read)
- `.claude/skills/skill-orchestrate-hard/SKILL.md` (543 lines; dispatch construction, lines 260-344; escalation, lines 464-496)
- `.claude/skills/skill-implementer-hard/SKILL.md` (grep + targeted read, lines 20-30, 235-245)
- `.claude/agents/general-implementation-hard-agent.md` (301 lines, full read)
- `.claude/context/index.json` (contracts subdomain entries)
- `specs/state.json` (tasks 779, 780 entries — confirmed 780 `status: "completed"`)

### Search Queries / Commands Used
- `find .claude/extensions/core -iname "anti-analysis.md" -o -iname "wrap-up.md"` (confirmed no mirror)
- `diff` across all dual-copy candidate pairs (agents, rules, skills, context/standards)
- `grep -n -i "restore green\|reach green\|RED state\|get back to green"` across skills/agents (zero hits)
- `grep -n -i "build error\|revert\|rollback\|restore green\|reach green"` in `skill-orchestrate-hard/SKILL.md` (zero hits)
- `python3 -c "..."` against `.claude/context/index.json` to dump all `contracts/*.md` index entries verbatim
