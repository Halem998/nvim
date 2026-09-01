---
next_project_number: 132
---

# TODO

## Task Order

*Updated 2026-09-01. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 13,14,20,22,27,29,31,39,42,43,45,46,51,53,72,73,87,94,100,102,103,106,108,110,111,113,114,123,126,128,130,131 | -- | core-agent-system, literature, neovim |
| 2 | 30,74,104,105,109,112,120,124,129 | 29,31,102,108,126,128,130 | core-agent-system, extensions, literature |
| 3 | 75,76,107,121,125 | 74,104,120,124,128 | core-agent-system, extensions, literature |
| 4 | 127 | 121,124 | core-agent-system |
| 5 | 88 | 87,127 | core-agent-system |
| 6 | 44 | 88 | core-agent-system |
| 7 | 89 | 44 | core-agent-system |
| 8 | 90 | 89 | core-agent-system |
| 9 | 48 | 90 | core-agent-system |
| 10 | 50 | 48 | core-agent-system |
| 11 | 91 | 50 | core-agent-system |

**Grouped by Topic** (indented = depends on parent):

### Core Agent System

13 [NOT STARTED] — The acceptance criterion "gate-out reports zero format errors and
14 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
20 [NOT STARTED] — /todo's repository-metrics sync runs before its git commit, so th
22 [RESEARCHING] — === REVISED 2026-08-24 (refactor survey) ===
27 [NOT STARTED] — .opencode/scripts/execute-command.sh is a command router that can
29 [NOT STARTED] — Build the deploy-engine mechanism that lets an extension declare 
  └─ 30 [NOT STARTED] — Register the obsidian-memory MCP server through the new manifest-
31 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
  └─ 120 [NOT STARTED] — Retarget the 7 hard-mode test/lint files to skill-orchestrate's h
    └─ 121 [NOT STARTED] — Delete skill-orchestrate-hard and the three -hard lifecycle skill
      └─ 127 [NOT STARTED] — Collapse the routing ladder to routing_agents-only across all 19 
        └─ 88 [NOT STARTED] — Apply the mode-gated section convention to the largest single ins
          └─ 44 [PLANNED] — LOWER PRIORITY (per-invocation cost, not per-session). `commands/
            └─ 89 [NOT STARTED] — Apply the mode-gated section convention to the two remaining larg
              └─ 90 [NOT STARTED] — The largest duplication class in the repo, and it has never been 
                └─ 48 [NOT STARTED] — Propagate the scoped-commit fix to the 65 call sites it never rea
                  └─ 50 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
                    └─ 91 [NOT STARTED] — update-plan-status.sh reports every non-conforming plan Status li
42 [NOT STARTED] — === REVISED 2026-08-24 (refactor survey) ===
43 [NOT STARTED] — LIVE DEFECT, not an efficiency item: the email extension's five '
46 [NOT STARTED] — RESCOPE + BACKFILL NOTE (task-116 audit). Per specs/116_core_agen
51 [NOT STARTED] — Stop session-scoped orchestration runtime files from accumulating
53 [NOT STARTED] — Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect w
72 [NOT STARTED] — RESCOPE NOTE (task-116 audit, verdict RESCOPE). The team-mode fol
73 [NOT STARTED] — RESCOPE NOTE (task-116 audit, verdict RESCOPE). Same A5 team-mode
87 [NOT STARTED] — Establish the convention that fixes the single largest token leve
  └─ 88 [NOT STARTED] — Apply the mode-gated section convention to the largest single ins (see above)
100 [NOT STARTED] — Close the file_scope blind spot for AGGREGATOR/REGISTRATION files
114 [NOT STARTED] — Wire model-flag support into /orchestrate: thread model_flag from
123 [NOT STARTED] — Delete the three team-mode skills (skill-team-research, skill-tea
126 [NOT STARTED] — Implement A2 phase-forcing flags (--research/--plan/--implement) 
  └─ 124 [BLOCKED] — Delete /research, /plan, /implement commands and update the CLAUD
    └─ 125 [NOT STARTED] — Delete the three base lifecycle skills (skill-researcher, skill-p
    └─ 127 [NOT STARTED] — Collapse the routing ladder to routing_agents-only across all 19  (see above)
128 [NOT STARTED] — Repair the hard-mode H4 adversarial-verification gate, which curr
  └─ 121 [NOT STARTED] — Delete skill-orchestrate-hard and the three -hard lifecycle skill (see above)
  └─ 129 [NOT STARTED] — Audit every `\b` word-boundary construct used in a grep pattern a
130 [NOT STARTED] — Make lake-build-guard.sh's success signal trustworthy. The script
131 [IMPLEMENTING] — Make /tag produce releases that a release workflow's preflight wi

### Extensions

74 [NOT STARTED] — Build a shared, task-type-agnostic guard script that detects a us
  └─ 75 [NOT STARTED] — Wire the shared LaTeX build guard into the latex extension's life
  └─ 76 [NOT STARTED] — Close the coverage gap that the latex-extension wiring cannot rea

### Literature

39 [PLANNED] — Upgrade the literature extension's Zotero integration beyond bare
94 [NOT STARTED] — Wire the --lit flag through the three team skills so literature m
102 [NOT STARTED] — Characterize when the PyMuPDF column-clustering fallback tier act
  └─ 104 [NOT STARTED] — Resolve the sentence_boundary_glue_count() false-positive class o
    └─ 107 [NOT STARTED] — Add an OCR-misrecognition detector to the literature quality gate
  └─ 105 [NOT STARTED] — Add an OCR tier to the literature converter, or make the pre-OCR 
  └─ 109 [NOT STARTED] — Fix three distinct failure modes in the online-ingest bridge, eac
103 [NOT STARTED] — Fix literature-fidelity-audit.sh so it can verify pipeline-ingest
106 [NOT STARTED] — Route skill-literature's convert path through literature-convert.
108 [NOT STARTED] — Make the topic-scoped coverage-delta guard fast enough that every
  └─ 112 [NOT STARTED] — Make global-corpus briefing actually return results instead of si
110 [NOT STARTED] — Stop Tier 3 online discovery from being a single point of failure
111 [NOT STARTED] — Two small, independent correctness fixes in literature tooling. S
113 [NOT STARTED] — Fix the SIGPIPE crash that makes repo-mode `--lit` briefing fail 

### Neovim

45 [NOT STARTED] — TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carr

## Tasks

### 131. Tag annotated and changelog preflight
- **Status**: [IMPLEMENTING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [131_tag_annotated_and_changelog_preflight/reports/01_tag-annotated-and-changelog-preflight.md]
- **Plan**: [131_tag_annotated_and_changelog_preflight/plans/01_tag-annotated-changelog-preflight.md]
- **Summary**: [131_tag_annotated_and_changelog_preflight/summaries/01_tag-annotated-changelog-preflight-summary.md]

**Description**: Make /tag produce releases that a release workflow's preflight will actually accept. Two independent gaps in skill-tag currently emit tags that fail a standard preflight gate, and both were hit consecutively on a real release, costing four failed release runs before the artifact published.

CANONICAL SOURCE. Edit `agent-system/extensions/core/skills/skill-tag/SKILL.md` and `agent-system/extensions/core/commands/tag.md`. Do NOT edit any repo's deployed `.claude/` copy -- it is a disposable artifact regenerated from this source store.

GAP 1 -- LIGHTWEIGHT TAGS. SKILL.md's Step 6 creates the tag with `git tag "$new_version"` (line 361 at time of writing), which produces a LIGHTWEIGHT tag. A release workflow asserting `[ "$(git cat-file -t "$TAG")" = "tag" ]` rejects it. The dry-run output at line 310 prints the same lightweight form and must be updated in step with the real command so the preview does not misrepresent what will run. Switch to an annotated tag (`git tag -a`, or `-s` if signing is wanted) with a message. Decide and record where the message comes from: a sensible default is the version heading plus the CHANGELOG section for that version, which is exactly the content Gap 2 makes available; a bare `-m "$new_version"` is acceptable but should be a recorded choice, not a default reached by omission.

GAP 2 -- NO CHANGELOG GATE. SKILL.md contains no occurrence of "changelog" at all. A release preflight commonly requires a non-empty `## [VERSION]` section in a CHANGELOG before publishing. /tag validates the declared package version (its Step 3.5, "Validate Version Consistency") but nothing else, so it happily creates and PUSHES a tag that preflight then rejects -- after the push, when the tag is already public and must be deleted and re-created to fix. Add a CHANGELOG check to Step 3.5's neighborhood, BEFORE the tag is created and pushed, mirroring the existing version-consistency check's structure: locate the changelog, require a `## [VERSION]` heading, require the section under it to be non-empty after whitespace stripping.

DESIGN CONSTRAINTS, from how Step 3.5 already behaves and must continue to behave.
- Run before Step 5's `--dry-run` early exit, so `--dry-run` reports the same verdict a real run would. Step 3.5 is explicitly documented as sitting there for this reason; the new check must not regress that.
- Absence must be tolerated, not fatal. Step 3.5's "No declared package version found ... Skipping version-consistency check" is an informational outcome that proceeds normally. A repository with no CHANGELOG at all must behave the same way -- this skill is shared across repos and must not hard-require a file many of them do not have. Only a PRESENT changelog that is MISSING the version's entry is an error.
- Provide an explicit override flag paralleling the existing `--skip-version-check`, and make it disclose rather than silence: that flag's documented contract is that it "suppresses the block, not the disclosure", printing the mismatch in full before the override warning so the transcript records what was overridden. Match that behavior exactly.
- Changelog path should be discovered rather than hardcoded to one repo's layout (the motivating repo uses `code/CHANGELOG.md`, not a root-level one). Bounded-depth discovery excluding vendor/build directories, as the existing manifest discovery in Step 3.5 already does, is the established pattern to follow.

ALSO UPDATE. `commands/tag.md` documents the workflow as a numbered list and a Requirements section; neither mentions annotated tags or a changelog. Both need to state the new behavior, or the command doc silently contradicts the skill.

MOTIVATING EVIDENCE, so the fix is verified against a real gate rather than an imagined one. In the ModelChecker repository, `.github/workflows/release.yml`'s preflight job asserts, in order: tag version matches the declared package version; the changelog has a non-empty `## [VERSION]` entry; the tag is annotated AND reachable from origin/master; and the tagged copy of release.yml matches origin/master's. /tag satisfies only the first. Use that job as the reference contract when deciding what /tag should check. Note the third assertion also requires the branch to be pushed BEFORE the tag is pushed -- /tag's current Step 2 only verifies the branch is not BEHIND the remote, and does not require it to be fully pushed, so a tag created on unpushed commits passes /tag and fails preflight. Assess whether that is a third gap worth closing here or a separate concern, and record the judgment either way.

NON-GOALS. Do not change /tag's user-only status or its agent prohibition. Do not add automatic CHANGELOG authoring -- the check verifies an entry exists, it does not write one. Do not couple this skill to any single repository's directory layout.

---

### 130. Stop lake-build-guard.sh reporting passes for builds it did not run
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Make lake-build-guard.sh's success signal trustworthy. The script currently reports a pass in two independent situations where no such build happened, which defeats the standing verification gate that every hard-mode implementation phase depends on. Observed live during a successful /orchestrate --hard run; recorded as evt_1788246598349_q1AwUZ and evt_1788260467365_9bSvdb.

PATH CORRECTION (recorded so a future reader is not sent to a nonexistent path). Both defect records attribute this to agent-system/extensions/lean/scripts/lake-build-guard.sh. That path does not exist. The script's only copy is agent-system/extensions/core/scripts/lake-build-guard.sh, with its harness at agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh. The misattribution is in the event records, not in the tree.

WHY THIS IS HIGH SEVERITY. A phase can be declared green on a build that never compiled the relevant modules. In the observed run this was caught only because implementation agents independently noticed the job count looked wrong and re-ran with --no-share. That is luck, not a control. Neither the exit code nor the "Build completed successfully" string distinguishes a genuine build from either failure mode below.

DEFECT A -- UNVALIDATED SUBCOMMAND PASSTHROUGH. The script takes the full lake subcommand after `--`, i.e. `-- build TARGET`. Invoked as `-- TARGET` it printed `error: unknown command '<target>'` and STILL EXITED 0. Mechanism, by inspection of the build-mode argument loop: the `--)` branch performs `shift; lake_args+=("$@"); break` with no validation whatsoever of the first post-`--` token, and the collected vector is handed to cmd_build unchecked. A caller trusting the exit code reads a failed build as a pass. Fix direction: validate the post-`--` subcommand against the set lake actually accepts and exit in the reserved usage band (77) on an unknown one, rather than letting the mistake reach lake and be silently absorbed.

DEFECT B -- RESULT SHARING IGNORES BUILD SCOPE. A "full" lake build issued immediately after a scoped one returned the SCOPED result. Observed concretely: the full build reported 1364 jobs with output byte-identical to the immediately preceding scoped build of a single module namespace, while the genuine full build, forced with --no-share, reported 2506 jobs.

ROOT CAUSE, ESTABLISHED BY INSPECTION -- THIS IS MECHANISM, NOT HYPOTHESIS. decide_sharing() replays a prior result when the stored post_fingerprint equals the waiter's current fingerprint (plus state==complete, a live-holder check, an age bound, and --no-share not set). compute_fingerprint() hashes exactly what collect_fingerprint_files() emits, which is: every *.lean file under the project root excluding .lake/, plus lakefile.lean, lakefile.toml, lake-manifest.json, and lean-toolchain. THE LAKE ARGUMENT VECTOR IS ABSENT FROM THE FINGERPRINT ENTIRELY. A scoped build and a full build over an unchanged tree therefore hash identically, and the sharing decision cannot tell them apart. The staleness policy documented in the script's own header is a policy about SOURCE CHANGE only; it never claimed to be a policy about build SCOPE, and the gap is exactly there.

Fix direction: incorporate a normalized form of the lake argument vector into the recorded fingerprint (or into a separate recorded scope key compared alongside it) so a result is only ever replayed for an equivalently-scoped build. Independently, make replay AUDIBLE rather than silent -- the header's silent-when-no-conflict convention is right for the no-conflict path but wrong for a replay, because a caller currently has no way to distinguish a replayed result from a fresh one. Something on the order of a one-line stderr notice naming the replay and the job count, and a documented way for a caller to assert that a genuine full build actually ran.

DEFECT C -- BROKEN WAIT IDIOM, DOCUMENTATION ONLY. The natural-looking poll `until ! pgrep -f "lake-build-guard.sh build"` SELF-MATCHES the polling shell's own argv and never exits. Waiting on the build PID with `kill -0` works. No occurrence of the broken idiom exists anywhere in the source store, so this is purely a gap in the script's own usage text, not a code defect: callers are left to invent the idiom and the obvious invention is wrong. Document the working form in the header or usage output.

WHY ONE TASK AND NOT THREE. All three land in one script plus its single test harness; A and B both require the same new harness scaffolding (an invocation-count probe distinguishing genuine builds from replays); and splitting would serialize three tasks against one file for no gain.

RELATIONSHIP TO THE LATEX BUILD-CONFLICT GUARD -- PREDECESSOR, NOT SIBLING. The two share no files: the latex guard script does not yet exist and its task creates it. They are related by CONVENTION. This script's header declares, verbatim, "FAMILY CONVENTIONS (for a future latex-build-guard.sh or similar sibling)", enumerating the subcommand shape, the exit-code shape, silent-when-no-conflict, and degrade-audibly. Defect A changes the exit-code contract and Defect B's replay notice qualifies silent-when-no-conflict. The conventions must therefore settle BEFORE the sibling instantiates them, which is why the latex guard task now depends on this one rather than the reverse.

RECORDER CLASS GAP (observation, not in scope to fix). Both events were filed as OFF_SCHEMA_STATUS, which is an imperfect fit: none of the recorder's thirteen permitted classes covers "a tool reports success for work it did not do". Separately, HOOK_REGEX_BOUNDARY_DEFECT is documented in the discrimination pattern as "not currently computed anywhere", so the class used for the companion gate defect is itself only ever recorded by hand. Both facts are recorded here for whoever next revises the class taxonomy; neither is a deliverable of this task.

ACCEPTANCE (extend the existing thirteen-case plus mutation harness, do not replace it):
  - `-- TARGET` with no subcommand exits non-zero rather than 0.
  - `-- build TARGET` continues to pass the wrapped command's own exit code through untouched.
  - A scoped build followed by an unchanged-tree full build runs a REAL full build rather than replaying the scoped result, demonstrated by invocation count and not by output inspection alone.
  - A full build followed by an identical full build over an unchanged tree still replays, so the sharing optimization is preserved rather than disabled.
  - A replay is distinguishable by a caller without passing --no-share.
  - The working wait idiom appears in the usage text.
  - Mutation coverage: reverting each fix reintroduces exactly the corresponding failure.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 129. Empirically audit \b word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 128

**Description**: Audit every `\b` word-boundary construct used in a grep pattern across the source store, empirically, against the grep actually deployed, and record portable-construct guidance so the class does not recur. Surfaced by the adversarial-verification gate failure (evt_1788245094839_eybEyC); that gate is fixed separately and is NOT in this task's scope.

THE DEFECT IS COMPOSITIONAL, NOT A MISSING FEATURE. State this precisely; the imprecise version of this finding is what would sink the audit itself. The deployed grep is ugrep 7.8.4 (built with PCRE2 available: `-P:pcre2jit`). Its POSIX/DFA `-E` engine does NOT simply ignore `\b`. Every fragment of the failing pattern matches in isolation against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |`:

  PATTERN                                                          RESULT
  \bclaim\b                                                        MATCH
  claim                                                            MATCH
  \|[^|]*\bclaim\b[^|]*\|                                          MATCH
  [^|]*\bclaim\b                                                   MATCH
  \bclaim\b[^|]*                                                   MATCH
  \bsource\b[^|]*\bcounterexample\b                                MATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b                           MATCH

The full composed pattern nevertheless fails, and bisection localizes it:

  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|   NOMATCH   (production form)
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b          NOMATCH
  \|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*counterexample              MATCH     (dropped \b around counterexample)
  \|[^|]*\bclaim\b[^|]*\|[^|]*source[^|]*\bcounterexample\b              NOMATCH   (dropped \b around source)
  \|[^|]*claim[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b              NOMATCH   (dropped \b around claim)

and the unmodified production pattern under `-P` (PCRE2) returns MATCH.

So the engine mis-evaluates a `\b` that appears DOWNSTREAM of an earlier `\b`-anchored subexpression separated by a `[^|]*` run. Whether a given `\b` works depends on what else is in the pattern.

BINDING CONSTRAINT ON HOW THIS AUDIT IS PERFORMED. Because the failure is compositional, spot-testing a fragment in isolation does NOT prove the production pattern works in situ. Every site must be executed as its full, unmodified production pattern against a real positive input under the deployed grep, and the observed result recorded. Reasoning about whether a construct "should" work, testing a simplified stand-in, or generalizing from one site's result to another's are all forbidden -- they are precisely the trap this defect sets.

FOR THE SAME REASON, THIS IS NOT A MECHANICAL FIND-AND-REPLACE. A blanket `\b` removal would be wrong: `\b` carries real semantics, and several high-stakes sites were spot-verified as CURRENTLY WORKING under the deployed grep -- guard-destructive-git.sh's `--hard\b` and `(drop|clear)\b` both match (that guard is live, not silently dead), the sorry census's `\bsorry\b` matches, and literature-audit.sh's `\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+[0-9]+(\.[0-9]+)*\b` matches. Rewriting working patterns risks introducing false positives in a destructive-git guard, which is a worse outcome than the defect being audited.

SCOPE. Roughly 26 grep-adjacent `\b` sites across the source store, spanning literature scripts, lean scripts, core scripts, lint scripts, test harnesses, and hooks. For each: run the production pattern against a real positive input under the deployed grep; classify as WORKING or BROKEN on the evidence; repair only the broken ones, choosing per-site between dropping `\b` where surrounding delimiters already provide the boundary and switching that invocation to `-P`; and leave working sites alone with a one-line note recording that they were tested rather than assumed.

DELIVERABLE BEYOND THE REPAIRS. A short portability guidance note under the core standards context directory covering: that the deployed grep may be ugrep rather than GNU grep; that `\b` under `-E` is compositionally unreliable there while `-P` is reliable; that delimiter-anchored alternatives are preferred where the surrounding pattern already bounds the token; and that any new `\b` pattern must be executed against a real input before being committed. Without this note the class recurs the next time someone writes a plausible-looking boundary pattern.

SEQUENCING. Depends on the adversarial-gate fix purely to avoid a file-footprint collision: skill-orchestrate/SKILL.md is itself one of the sites, and that task owns the gate's pattern. This task covers every other site and must not touch the gate.

ACCEPTANCE: every site is accompanied by a recorded empirical result under the deployed grep; no working pattern is rewritten; each repaired pattern is demonstrated to match a real positive input AND to reject a real negative input; and the guidance note exists.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 128. Migrate the orphaned H4 adversarial-verification gate and repair its false-negative matcher
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 119

**Description**: Repair the hard-mode H4 adversarial-verification gate, which currently burns a full extra research dispatch on every hard-mode run by failing against reports that genuinely conform. Observed live on a successful /orchestrate --hard run in a consumer repo; recorded as evt_1788245094839_eybEyC, class HOOK_REGEX_BOUNDARY_DEFECT.

THE GATE AND ITS TWO INDEPENDENT FAILURES (verified, do not re-derive). The gate lives in the `#### State: researched` handler and skips re-dispatch only if BOTH of the following succeed against the research report:
  grep -q "## Adversarial Self-Verification" "$research_path"
  grep -qiE '\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|' "$research_path"
Both failed against a report containing a substantive eleven-row claim-verification table.

FAILURE ONE -- SECTION NUMBERING. The report's heading was `## 7. Adversarial Self-Verification`. The literal-string match does not tolerate numbering, and numbered report sections are routine rather than exceptional. The heading match must accept an optional `N.` or `N.N` prefix.

FAILURE TWO -- COMPOSED WORD BOUNDARIES UNDER THE DEPLOYED GREP. Independent of the heading, the table pattern fails even against a perfectly canonical unnumbered header line. This is NOT the simple claim that the deployed grep ignores `\b`; see the companion word-boundary portability audit, which owns the general characterization and carries the bisection evidence. What matters here is only the consequence: the exact production pattern above returns NOMATCH against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |`, while the same pattern with `\b` removed returns MATCH, and the unmodified pattern under `-P` returns MATCH.

DIRECTION OF THE FAILURE. This is a FALSE-NEGATIVE gate. It never wrongly passes unverified research; it wrongly re-dispatches already-verified research. The cost is a wasted dispatch cycle per hard-mode run, not a correctness hole in verification itself. Any fix must preserve that asymmetry: a report with no adversarial section and no claim table must still trip the gate and still trigger re-dispatch.

ROUTING -- THE GATE IS ORPHANED, AND THIS TASK OWNS THE MIGRATION. Do not fix this in the `-hard` engine alone; that file is slated for deletion. The hard-mode state-machine consolidation completed WITHOUT carrying this gate over, and skill-orchestrate/SKILL.md records the omission in its own text, verbatim:

  "**Not migrated**: the `researched`-state adversarial verification gate (H4) -- see the residue
  note immediately below. Everything else in the source engine's state-machine logic (H1/H5/H6/the
  burnout breaker, plus the loop-guard/churn-state plumbing they depend on) is now reproduced here."

  "**Hard-mode residue not yet migrated**: the `researched`-state adversarial verification gate
  (H4) -- the `#### State: researched` handler in the `-hard` engine and its `adversarial_verified`
  state variable, set at three separate sites and driving a verify-then-re-dispatch loop before
  planning -- has NOT been ported into this engine's `researched` handler below. This is a
  deliberate, recorded scope decision, not an oversight: it is a structurally independent residue
  (its own state variable, its own re-dispatch loop, a different handler than the four behaviors
  this engine does reproduce) and remains the one still-unmigrated piece of hard-mode
  state-machine logic. A future removal of the `-hard` engine must account for this gate
  separately; its absence here is not evidence it was folded in elsewhere in this file."

The orphaning was therefore documented but UNOWNED: the note asks that a future deletion "account for this gate separately", and no task did. The deletion task now depends on this one so the engine cannot be removed while its last unmigrated gate still lives only there.

SCOPE. Port the `#### State: researched` handler and its `adversarial_verified` state variable (set at three separate sites, driving a verify-then-re-dispatch loop before planning) into skill-orchestrate/SKILL.md's own `researched` handler, gated on `hard_mode` in the same style as the already-migrated H1/H5/H6 behaviors, and land the CORRECTED matcher there rather than transcribing the broken one. Treat the `-hard` engine as read-only reference.

CO-MAINTENANCE ASYMMETRY -- DECIDE AND RECORD, DO NOT DUAL-EDIT. The two engines carry an explicit co-maintenance contract and a one-sided change normally reproduces a named recurring defect class. That contract's own escape clause permits recording the asymmetry instead of mirroring it. Take that route here: leave the `-hard` copy untouched because it is scheduled for deletion, and record the deliberate asymmetry in both files so a reader of either one is not misled. Mirroring a fix into a file about to be deleted is wasted work and creates a second site to keep in sync for no benefit.

ACCEPTANCE (both directions required -- a gate that can only ever stay silent is not a fix):
  - POSITIVE: a report whose heading is `## 7. Adversarial Self-Verification` and whose table header is `| Claim | Source / counterexample | Verification method | Confidence |` passes the gate, under the grep actually deployed on the machine, and does not trigger re-dispatch.
  - POSITIVE: the same report with an unnumbered `## Adversarial Self-Verification` heading also passes.
  - NEGATIVE: a report with no adversarial section, and a report with the section but no claim/source/counterexample table, each still fail the gate and still trigger re-dispatch.
  - The corrected pattern is exercised against a real file by the deployed grep, never merely reasoned about.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 127. Collapse routing ladder to routing agents
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 124, Task 121

**Description**: Collapse the routing ladder to routing_agents-only across all 19 extension manifests; retire command-route-skill.sh.

CONTEXT. Every extension manifest may declare up to four routing blocks today (routing, routing_hard, routing_agents, routing_agents_hard), resolved by the shared five-step ladder in scripts/lib/manifest-routing-lib.sh. Once /research, /plan, /implement are deleted (no skill layer left to route to) and the hard-mode collapse lands (no separate hard-routing table needed -- hard mode becomes a dispatch-prep injection, not a different resolved agent file), only routing_agents remains meaningful.

WORK. (1) Remove the routing and routing_hard blocks from every extension manifest that declares them, retaining only routing_agents (plus any extension-specific op like present's critique). (2) Retire command-route-skill.sh -- confirm no remaining caller (only the now-deleted /research, /plan, /implement, /revise-adjacent paths called it; /revise itself does not use this resolver and is unaffected). (3) Update context/guides/manifest-routing-schema.md to document the collapsed two-block model (down from four), including the completeness-lint contract re-scoped to check only routing_agents completeness against itself. (4) Re-scope lint-routing-wiring.sh's Checks A/C accordingly.

DEPENDS ON both the command deletions (routing/skill-dispatch has no remaining caller) and the hard-mode file deletions (routing_hard/routing_agents_hard has no remaining caller) having already landed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/*/manifest.json (all 19), agent-system/extensions/core/scripts/command-route-skill.sh, agent-system/extensions/core/context/guides/manifest-routing-schema.md, agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A3).

---

### 126. Implement orchestrate phase forcing flags
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 117, Task 122

**Description**: Implement A2 phase-forcing flags (--research/--plan/--implement) on /orchestrate.

CONTEXT. /orchestrate has no mechanism today to re-run a lifecycle phase that already produced an artifact (e.g. `/orchestrate NNN --research` to run an additional research round on a task already [PLANNED] or beyond). No increment mechanism exists for a forced re-plan or re-implement either: orchestrator-postflight.sh's Stage 7a next_artifact_number increment fires only on research ("research only"), and skill-base.sh's "prev" mode read (next_artifact_number - 1) assumes plan/implement always share the round research just opened.

WORK. (1) Add --research/--plan/--implement flags to orchestrate.md's Options table and parse-command-args.sh, threading them into the delegation context as force_phases (e.g. ["research","plan"]). (2) Extend skill-orchestrate's Stage 1b/2 phase-resolution logic to check force_phases FIRST: when set, run exactly the composed sequence (composition means "stop after the last named phase", not "force both starting from the first") instead of the status-derived phase; with no flag, resume-from-first-incomplete-phase (today's behavior) is unchanged. (3) Change orchestrator-postflight.sh's Stage 7a increment condition from "phase == research" to "phase was force-invoked, any phase" -- a forced phase always opens a new MM_ round (append, never replace), so the round-numbering convention already in use for research works identically for a forced plan or implement. (4) Add a monotonic-max clamp to the forced-phase status write: a forced --research on a task already at [PLANNED] or beyond must never regress status back to [RESEARCHED] -- the status write is skipped (report/artifact link still added) whenever the new value would be a regression.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/commands/orchestrate.md, agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, agent-system/extensions/core/scripts/orchestrator-postflight.sh, agent-system/extensions/core/scripts/skill-base.sh, agent-system/extensions/core/scripts/parse-command-args.sh (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A2, all four sub-questions).

---

### 125. Delete base lifecycle skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 117, Task 124

**Description**: Delete the three base lifecycle skills (skill-researcher, skill-planner, skill-implementer).

PRECONDITION (verify before starting). Both the dispatch-prep rehome and the command deletions must already be landed -- once /research, /plan, /implement are deleted, nothing calls these three skills any longer (skill-orchestrate already bypasses them entirely by dispatching agents directly, per the design report's re-verified dispatch-bypass finding), so this task is pure deletion, not rewiring.

WORK. Delete skills/skill-researcher/SKILL.md (424 lines), skills/skill-planner/SKILL.md (508 lines), skills/skill-implementer/SKILL.md (725 lines), each in full (directory removal). Confirm a repo-wide grep for each skill's name (excluding this task's own specs/ artifacts, and excluding the now-historical CLAUDE.md Skill-to-Agent Mapping table row removal, which this task also performs) returns zero hits. Update the Skill-to-Agent Mapping table in CLAUDE.md / merge-sources/claudemd.md to remove the three rows.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-researcher/, .../skill-planner/, .../skill-implementer/, agent-system/extensions/core/merge-sources/claudemd.md (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A1 migration note, A7 ledger).

---

### 124. Delete lifecycle commands and update reference
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 68, Task 81, Task 117, Task 126
- **Research**: [124_delete_lifecycle_commands_and_update_reference/reports/01_lifecycle-command-deletion-preconditions.md]

**Description**: Delete /research, /plan, /implement commands and update the CLAUDE.md command reference.

PRECONDITION (verify before starting, do not proceed otherwise). The dispatch-prep stage rehoming memory retrieval and --lit resolution into skill-orchestrate must already be landed and verified working -- deleting these commands (and thereby orphaning the three lifecycle skills a later task deletes) before that rehome lands would make a currently-partial memory/--lit capability gap on /orchestrate total and permanent. Also verify the two BLOCKING defects are resolved first: the multi-task blocked-verdict discrimination defect, and the task-lock/session-registry heartbeat defect -- both would be entrenched at higher stakes once /orchestrate is the sole entry point.

WORK. Delete commands/research.md (652 lines), commands/plan.md (677 lines), commands/implement.md (506 lines). commands/revise.md is explicitly NOT touched -- its plan-revision-with-reason and description-update-fallback behaviors have no /orchestrate phase-flag equivalent and remain a distinct command. Update merge-sources/claudemd.md's Command Reference table: remove the three rows for /research, /plan, /implement, and document /orchestrate NNN --research / --plan / --implement as their replacement spelling (this requires the phase-forcing-flags task to have landed, or to land in the same window -- confirm flag support exists on /orchestrate before removing the old commands' documentation, so the reference table is never briefly wrong).

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/commands/research.md, .../plan.md, .../implement.md, agent-system/extensions/core/merge-sources/claudemd.md (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A1, A7 ledger).

---

### 123. Delete team mode skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 122

**Description**: Delete the three team-mode skills (skill-team-research, skill-team-plan, skill-team-implement).

PRECONDITION (verify before starting). The shared team-mode fan-out stage inside skill-orchestrate must already be landed and verified working -- this task is pure deletion, and synthesis-agent is explicitly NOT touched (it is preserved unchanged; the fan-out logic being deleted here is the per-phase spawn/correlate mechanism, not the cross-teammate synthesis reader).

WORK. Delete skills/skill-team-research/SKILL.md, skills/skill-team-plan/SKILL.md, skills/skill-team-implement/SKILL.md in full (directory removal, not just SKILL.md). Confirm a repo-wide grep for each deleted skill's name (excluding this task's own specs/ artifacts) returns zero hits, and confirm any command-to-skill routing table entry that named one of the three (if any survives from the pre-collapse routing model) is also removed.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-team-research/, agent-system/extensions/core/skills/skill-team-plan/, agent-system/extensions/core/skills/skill-team-implement/ (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A5-i, A7 ledger).

---

### 122. Build team mode fanout stage
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 117, Task 119
- **Research**: [122_build_team_mode_fanout_stage/reports/01_team-fanout-stage-research.md]
- **Plan**: [122_build_team_mode_fanout_stage/plans/01_team-fanout-stage.md]
- **Summary**: [122_build_team_mode_fanout_stage/summaries/01_team-fanout-stage-summary.md]

**Description**: Build the team-mode shared fan-out stage in skill-orchestrate.

CONTEXT. skill-team-research, skill-team-plan, and skill-team-implement each independently declare per-teammate finding-file naming ({NN}_{letter}-findings.md), territory contracts (file-ownership declarations preventing teammate collision), and SubagentStop-postflight-to-owning-session correlation -- triplicated because the only real difference between the three is which lifecycle phase's dispatch context to fan out. synthesis-agent is unaffected by this task (it already runs as a fresh-context, phase-agnostic reader/writer and is not touched).

WORK. Add a phase-parameterized fan-out stage to skill-orchestrate/SKILL.md implementing the finding-file convention, territory contracts, and session-correlation once, taking the lifecycle phase (research/plan/implement) as a parameter rather than being copy-pasted per phase. Add --team and --team-size flags to orchestrate.md (orchestrate.md's own Constraints section currently states "--team flag not supported" -- this task removes that constraint), defaulting --team-size to 3 (Primary + Alternatives + Critic), 2 under --fast, 4 under --hard, matching the existing documented cost table. Preserve the CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS-unset graceful-degradation path as an early check in the same stage: when unset, --team is accepted but silently falls through to single-dispatch.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, agent-system/extensions/core/commands/orchestrate.md (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A5).

---

### 121. Delete hard mode lifecycle files
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 118, Task 119, Task 120, Task 128

**Description**: Delete skill-orchestrate-hard and the three -hard lifecycle skills and agent files.

PRECONDITION (verify before starting, do not proceed otherwise). The hard-mode contract-injection mechanism, the state-machine residue migration, and the test/lint retargeting must all already be landed and verified working inside skill-orchestrate/SKILL.md -- this task is pure deletion with zero rewiring of its own.

WORK. Delete: skills/skill-orchestrate-hard/SKILL.md (1,784 lines), skills/skill-researcher-hard/SKILL.md (275 lines), skills/skill-planner-hard/SKILL.md (462 lines), skills/skill-implementer-hard/SKILL.md (507 lines), agents/general-research-hard-agent.md (332 lines), agents/planner-hard-agent.md (334 lines), agents/general-implementation-hard-agent.md (538 lines). Remove the routing_hard/routing_agents_hard blocks from the three manifests that still declare them (core, cslib, lean -- verified as the complete set of 19 manifests carrying these keys). Confirm no remaining reference to any deleted path anywhere in agent-system/ (a repo-wide grep for each deleted file's basename, excluding this task's own summary/report artifacts under specs/, must return zero hits before this task is considered complete).

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (skills/agents/manifest.json), agent-system/extensions/cslib/manifest.json, agent-system/extensions/lean/manifest.json (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A7 deletion ledger).

---

### 120. Retarget hard mode tests to engine branch
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 31, Task 118, Task 119

**Description**: Retarget the 7 hard-mode test/lint files to skill-orchestrate's hard_mode branch.

CONTEXT. Once the hard-mode contract-injection and state-machine logic land inside skill-orchestrate/SKILL.md as hard_mode-gated branches (rather than in the separate skill-orchestrate-hard/SKILL.md file), these 7 files' fixtures/assertions must be retargeted so their coverage is preserved rather than silently dropped when skill-orchestrate-hard is deleted: test-loop-guard-budget-override.sh, test-routing-resolution.sh, test-handoff-reader-parity.sh, test-loop-guard-staleness.sh, test-handoff-dispatch-identity.sh, test-resume-scan-nonconformance.sh, lint-contract-compliance.sh.

WORK. For each file, update fixture paths and assertions to exercise skill-orchestrate/SKILL.md's hard_mode=true branch instead of skill-orchestrate-hard/SKILL.md. Verify each test still exercises the SAME underlying mechanism it did before (loop-guard budget, routing resolution, handoff reader parity, resume-scan nonconformance detection, contract compliance) -- this is a retarget, not a rewrite of intent. Run the full suite after retargeting and confirm no regression in what each test actually catches (a mutation check: temporarily reintroduce the bug each test guards against and confirm the retargeted test still fails).

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/scripts/tests/**, agent-system/extensions/core/scripts/lint/** (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/02_baseline-and-audit-evidence.md (Finding 2, enumerated file set); reports/03_target-state-design.md (A4-iv).

---

### 119. Migrate hard mode state machine logic
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 117, Task 118
- **Research**: [119_migrate_hard_mode_state_machine_logic/reports/01_state-machine-migration-design.md]
- **Plan**: [119_migrate_hard_mode_state_machine_logic/plans/01_state-machine-migration.md]
- **Summary**: [119_migrate_hard_mode_state_machine_logic/summaries/01_state-machine-migration-summary.md]

**Description**: Migrate hard-mode state-machine logic (H1 phase-per-cycle, H5/H6 churn/three-strikes, burnout breaker) into skill-orchestrate.

CONTEXT. skill-orchestrate-hard/SKILL.md's genuinely hard-specific residue (measured by stage-header comparison: Stage 1b agent routing ~50 lines, Stage 1c discipline preamble ~16 lines, Stage 2 loop-guard/churn-state init ~279 lines, Stage 3c burnout circuit-breaker ~38 lines, Stage 4b churn detection ~56 lines, plus an estimated ~200 of Stage 4's 484-line dispatch-construction lines) is NOT reducible to prompt-injected text -- it implements stateful counters and thresholds (three-strikes churn detection, single-blocking-phase-per-implement-cycle dispatch limiting, a burnout circuit breaker) that only function as actual conditional logic in the engine's own state machine.

WORK. Port this residue into skill-orchestrate/SKILL.md as `if $hard_mode` conditional branches: (1) loop-guard/churn-state initialization at the equivalent of today's Stage 2; (2) the burnout circuit-breaker gate; (3) per-target churn-detection counters and the three-strikes audit-dispatch trigger, run after each implement dispatch; (4) the H1 single-blocking-phase-per-cycle limiter on implement dispatch (vs. base mode's whole-plan-per-cycle). This is the SAME file the dispatch-prep and contract-injection prerequisite tasks also edit -- coordinate to avoid overlapping edits within the same dispatch window.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/skills/skill-orchestrate/SKILL.md (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A4-i residue measurement table).

---

### 118. Build hard contracts injection
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 117
- **Research**: [118_build_hard_contracts_injection/reports/01_hard-contracts-injection-design.md]
- **Plan**: [118_build_hard_contracts_injection/plans/01_hard-contracts-injection.md]
- **Summary**: [118_build_hard_contracts_injection/summaries/01_hard-contracts-injection-summary.md]

**Description**: Build hard_contracts manifest key and contract-text injection at dispatch-prep time.

CONTEXT. context/contracts/*.md already exists as a shared contract-text store (one file per H-item: anti-analysis.md=H2, reference-grounding.md=H3, adversarial-verification.md=H4, convergence.md=H6, territory.md=H7, wrap-up.md=H9, plus recovery.md/phase-closure.md/pre-edit-gate.md/orchestrator-discipline.md), already referenced by backtick path from the 7 duplicate -hard files (3 lifecycle -hard skills, 3 -hard agents, skill-orchestrate-hard). The reduction opportunity is consumer-count, not content-authoring: today 7 files independently decide which contracts to reference; this task creates exactly one call site.

WORK. (1) Extend the dispatch-prep stage this task depends on (built by the prerequisite task) so that, when hard_mode is set, it builds and appends the ordered context/contracts/*.md reference block to the dispatch prompt. (2) Add an optional hard_contracts manifest key (shape: {task_type: [path, ...]}) letting an extension add or override a contract for its own task types, resolved by the existing manifest-routing ladder's compound-key (ext:subtype) matching; an entry prefixed "replace:core-file.md:override-file.md" substitutes rather than adds. (3) Add a deploy-time warning (not a hard error, not silent ignore) in verify-deploy.sh for any extension still declaring routing_hard/routing_agents_hard after this collapse, naming the extension and pointing at hard_contracts as the migration path.

NOT IN SCOPE. The stateful hard-mode logic (churn/three-strikes counters, burnout circuit breaker, single-phase-per-cycle implement dispatch) is NOT prompt-injectable text and is out of scope for this task -- it is a separate, dependent task (state-machine migration).

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A4-i, A4-ii, A4-iii).

---

### 117. Build orchestrate dispatch prep stage
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [117_build_orchestrate_dispatch_prep_stage/reports/01_dispatch-prep-stage-design.md]
- **Plan**: [117_build_orchestrate_dispatch_prep_stage/plans/01_dispatch-prep-stage.md]
- **Summary**: [117_build_orchestrate_dispatch_prep_stage/summaries/01_dispatch-prep-stage-summary.md]

**Description**: Build the dispatch-prep stage in skill-orchestrate: memory retrieval, --lit resolution, --clean, --fast.

CONTEXT (do not re-derive; see the design spec cited below). skill-orchestrate/SKILL.md dispatches every lifecycle phase (research/plan/implement) via the Agent tool directly against general-research-agent/planner-agent/general-implementation-agent, bypassing skill-researcher/skill-planner/skill-implementer entirely -- the sole home today of Stage 4a memory retrieval (memory-retrieve.sh, gated by clean_flag) and interactive --lit resolution (lit-stage4a-flow.md). Verified live: skill-orchestrate/SKILL.md has zero occurrences of memory-retrieve, clean_flag, lit-stage4a, or literature-briefing, against 13 pass-through lit_flag occurrences that are never resolved into a briefing. orchestrate.md's own Options table today has no --clean flag and no --fast flag at all (both present only on the now-superseded research.md/plan.md/implement.md).

WORK. Add a single dispatch-prep stage to skill-orchestrate/SKILL.md, invoked once per dispatch (both the single-task path and each multi-task wave member), immediately before the Agent-tool subagent_type call, that: (1) calls memory-retrieve.sh gated by a newly-added --clean flag on orchestrate.md, injecting a <memory-context> block into the dispatch context in the same shape skill-researcher's Stage 4a already produces; (2) calls the shared lit-stage4a-flow.md flow to resolve lit_flag into a <literature-briefing> block; (3) adds a --fast flag to orchestrate.md's Options table and threads it into dispatch-context construction the same way research.md/plan.md/implement.md already do today.

ORDERING (binding, load-bearing for the wider consolidation this task is part of). This task must land and be verified working BEFORE any task that deletes commands/research.md, commands/plan.md, commands/implement.md, or the three lifecycle skills (skill-researcher, skill-planner, skill-implementer) -- the system must never pass through a state where skill-orchestrate dispatches an agent without memory/--lit support while the skills that used to provide it are already gone.

SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/** (never .claude/**).
DELIVERABLE RULE: no task-number references in any deliverable outside specs/**.

REFERENCE: full design reasoning is specs/116_core_agent_system_consolidation/reports/03_target-state-design.md (A1 precondition, A6).

---

### 116. Design the orchestrate-centric core consolidation and rebuild the backlog around it
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [116_core_agent_system_consolidation/reports/01_orchestrate-centric-consolidation-design-inputs.md]
- **Plan**: [116_core_agent_system_consolidation/plans/01_orchestrate-centric-consolidation.md]

**Description**: Design the target state for an orchestrate-centric core agent system, then rebuild the existing backlog around that design -- revising, absorbing, abandoning, and adding tasks as the design requires. This is a META-TASK: its deliverables are a design specification plus a set of applied backlog operations, NOT edits to the running system. No command, skill, or agent file is deleted by this task; it decides what gets deleted and by which successor task.

SOURCE STORE IS THE EDIT TARGET for every successor task it creates: agent-system/extensions/** (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

RUN THIS TASK ALONE. Its file_scope includes specs/TODO.md and specs/state.json, which collide with every other task in the repo. It must never be admitted into a multi-task /orchestrate batch.

=== MOTIVATION: MEASURED SURFACE ===

Core extension inventory, measured 2026-08-31 at agent-system/extensions/core/:
    commands   18 files     7,707 lines
    skills     22 dirs     14,981 lines (SKILL.md only)
    agents     12 files     5,073 lines
    rules      10 files
    scripts   145 files    48,204 lines
    context   137 files    37,959 lines
    docs       28 files

The dominant redundancy is a materialized 3x3 product: {research, plan, implement} x {standard, hard, team}, duplicated at the command, skill, and agent layer simultaneously.

  Commands: research.md (652) + plan.md (677) + implement.md (506) + revise.md (157) = 1,992 lines
  that orchestrate.md (750) already sequences internally.

  Skills: 10 of 22 are lifecycle-phase skills --
    skill-researcher / skill-researcher-hard
    skill-planner / skill-planner-hard
    skill-implementer / skill-implementer-hard
    skill-team-research / skill-team-plan / skill-team-implement
    skill-reviser
  Plus two orchestration engines: skill-orchestrate and skill-orchestrate-hard.

  Agents: 8 of 12 are the same matrix --
    general-research-agent / general-research-hard-agent
    planner-agent / planner-hard-agent
    general-implementation-agent / general-implementation-hard-agent
    reviser-agent, synthesis-agent

  Every extension pays for the duplication too: the routing ladder in
  scripts/lib/manifest-routing-lib.sh resolves against FOUR manifest blocks per extension --
  routing, routing_hard, routing_agents, routing_agents_hard.

=== PHASE A: TARGET-STATE DESIGN ===

Produce a written specification (a report artifact) for a single-entry-point core. It must be
specific enough that a successor task can implement it without re-deriving decisions.

A1. SINGLE ENTRY POINT. /orchestrate becomes the only lifecycle command. Specify precisely what
happens to /research, /plan, /implement, /revise: deleted outright, or retained as thin aliases
that forward to /orchestrate with a phase flag. State the decision AND its reasoning. If aliases
are retained, they must carry no logic of their own -- an alias that duplicates argument parsing
or gate sequencing has not reduced anything.

A2. PHASE-FORCING FLAGS. Specify the flag surface that lets a user re-run a phase that has
already produced an artifact -- the motivating example is `/orchestrate NNN --research` running
an additional research round on a task already marked [RESEARCHED] or beyond. Cover at minimum
--research, --plan, --implement, and whatever replaces /revise. Decide and record:
  - Does a forced phase REPLACE the prior artifact, or append a new numbered one (the MM_ naming
    convention already supports 01_, 02_, 03_ within a task)? Appending is the safer default but
    grows the artifact directory; state the choice.
  - What does a forced phase do to task status? Re-running research on a [PLANNED] task must not
    silently regress the status marker and strand the plan.
  - Can phase flags compose (`--research --plan`), and if so does that mean "force both" or
    "stop after plan"?
  - What is the default with NO phase flag -- resume from the first incomplete phase, which is
    today's behavior, or something else?

A3. DEFAULTS FROM TASK TYPE AND LOADED EXTENSIONS. Specify how /orchestrate derives its dispatch
defaults (which agent, which model, which contracts) from the task's task_type plus the set of
loaded extensions, without the user naming a skill. The existing ladder in
scripts/lib/manifest-routing-lib.sh and its two consumers (command-route-skill.sh,
command-route-agent.sh) are the starting point -- state what survives, what changes, and what
each extension manifest must declare after the collapse. See
context/guides/manifest-routing-schema.md for the current four-block model.

A4. HARD MODE BECOMES CONTRACT INJECTION (decided; implement, do not re-litigate). The H2-H9
behavioral contracts are injected into the dispatch prompt rather than routed to a duplicate
skill/agent tree. This collapses skill-{researcher,planner,implementer}-hard, the three
*-hard-agent files, and skill-orchestrate-hard, and removes routing_hard / routing_agents_hard
from every extension manifest. The open work is HOW, not WHETHER:
  - Where do the contract texts live so that one edit updates every consumer? (A context file
    referenced by path, an include mechanism, or a script that emits the block.)
  - How does an EXTENSION add or override a contract for its own task types?
  - What is the migration path for extensions that currently declare routing_hard blocks --
    silent ignore, deploy-time warning, or a hard error?
  - skill-orchestrate-hard/SKILL.md is ~110KB and its multi-task half already delegates to the
    base skill (its own text says stages MT-1..MT-5 live solely in skill-orchestrate). Measure
    how much of it is genuinely hard-specific before assuming the collapse is cheap.
This subsumes the existing standalone task "Decide and implement how --hard behavioral contracts
reach agents system-wide" (topic essential-refactor), which Phase B should absorb rather than
leave running in parallel.

A5. TEAM MODE FOLDS INTO THE ENGINE (decided; implement, do not re-litigate). Parallel-teammate
capability is preserved but expressed as a flag handled inside the single engine, not as three
separate skills plus a synthesis agent. Specify:
  - What happens to skill-team-research / skill-team-plan / skill-team-implement and
    synthesis-agent -- deleted, or reduced to a fan-out helper the engine calls?
  - Whether --team survives as a user flag or becomes an automatic decision from task shape.
  - How the teammate contract layer (per-teammate finding files, territory contracts, the
    SubagentStop postflight correlation) is expressed once instead of three times.
  - Whether --team-size survives.
  - The graceful-degradation path when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is unset must be
    preserved, not dropped as incidental.

A6. PRESERVED ASSETS -- WHAT MUST NOT BE LOST. The reduction is only a win if quality holds.
Enumerate explicitly the mechanisms that must survive the collapse, and for each, name where it
lives afterward. At minimum: the GATE IN / GATE OUT checkpoint sequencing; scoped git commits per
phase; the artifact format validators; task-lock and session-registry concurrency control; the
batch admission gates (self-modification, file_scope collision, cycle budget); --lit literature
briefing injection; memory retrieval and --clean suppression; model flags (--haiku/--sonnet/
--opus/--fable); --fast; the return-metadata handoff contract and the recovery path built on it.
A deletion that quietly drops one of these is a regression, not a simplification.

A7. DELETION LEDGER AND COST. A table: every file proposed for deletion, its line count, what
replaces it, and what capability is lost (or "none"). Report the projected before/after totals
against the measured baseline in the MOTIVATION section above. Do not report an unqualified
reduction figure without naming what it cost.

=== PHASE B: BACKLOG AUDIT ===

Classify every task listed under AUDIT SCOPE below against the Phase A design. Exactly one
verdict per task, each citing the specific Phase A decision that produces it:

  ON-PATH   -- survives unchanged; sequence it relative to the refactor.
  RESCOPE   -- survives with a revised description; state what changes and why.
  ABSORB    -- merged into a consolidation task; name the target.
  MOOT      -- abandoned because the file or mechanism it fixes ceases to exist. A MOOT verdict
               MUST name the deletion in the Phase A ledger that makes it moot. "Probably
               obsolete" is not a verdict.

A task may also be judged BLOCKING -- it must land BEFORE the collapse because the collapse would
otherwise inherit or entrench its defect.

Findings already established during the /meta review that produced this task (verify, do not
re-derive):
  - The two model-flag threading tasks (wire model-flag support into /orchestrate and the base
    engine; mirror it into skill-orchestrate-hard) are ON-PATH, and the second is partly MOOT
    under A4 -- if skill-orchestrate-hard is deleted, mirroring model_flag into it is wasted
    work. Sequencing matters: settle A4 before dispatching the mirror task.
  - "Wire the --lit flag through the three team skills" is MOOT-or-RESCOPE depending on how A5
    lands. If the three team skills are deleted, --lit threading happens once in the engine.
  - The two team-mode-lifecycle tasks (teammate return-meta write conflict; SubagentStop
    postflight correlated to the marker-owning session) are RESCOPE-or-MOOT under A5 for the same
    reason. Note that both describe REAL defects -- if the fold preserves teammates at all, the
    defects survive the fold and must be re-expressed against the new location.
  - The mode-gated-section-loading chain (the convention task, and the three application tasks
    that apply it to skill-orchestrate's multi-task section, to the literature/distill skills, and
    to commands/task.md) is ON-PATH and reduces the same surface. Check for double-counting: a
    section deleted by the collapse should not also be counted as saved by mode-gating.
  - The shared-task-lookup-helper adoption lint and the scoped-commit propagation task both touch
    call sites across the whole core; their counts change if the collapse lands first. Sequence
    them deliberately in one direction or the other and say which.
  - The three latex build-guard tasks are latex-extension internals that carry the `extensions`
    topic only incidentally. They are in audit scope but the expected verdict is to return them
    to the `extensions` topic untouched.

=== PHASE C: BACKLOG OPERATIONS ===

Apply the Phase B verdicts:
  - Revise descriptions for RESCOPE tasks.
  - Abandon MOOT tasks with a recorded reason citing the Phase A ledger entry.
  - Create the successor implementation tasks the design requires, each sized to be independently
    dispatchable and each naming its own file_scope.
  - Re-topic survivors to `core-agent-system`.
  - Write the dependency ordering into state.json so the wave generator produces a correct
    sequence, and regenerate specs/TODO.md.

The successor tasks are where files actually get deleted. Size them so that no single task both
deletes a lifecycle skill AND rewires its consumers -- those are separable and the rewiring must
land first, so the system is never in a state where a dispatch resolves to a file that no longer
exists.

=== AUDIT SCOPE ===

In scope for audit and re-topic authority (32 tasks across six topics):
  agent-system, essential-refactor, orchestration-concurrency, team-mode-lifecycle,
  status-marker-lifecycle, extensions.

OUT OF SCOPE: all 15 literature-topic tasks. Extension INTERNALS are out of scope; the
extensions topic is in audit scope only where routing and manifest surface is shared with the
core. Boiling down the extensions themselves is deferred work and must not be started here.

=== VERIFICATION BAR ===

  1. The Phase A report states a decision, with reasoning, for every one of A1-A7. An item
     answered "to be determined" is an incomplete phase, not a completed one.
  2. Every task in AUDIT SCOPE carries exactly one verdict, and every MOOT verdict names the
     specific deletion that produces it.
  3. The deletion ledger's projected line-count reduction is reported against the measured
     baseline recorded in this description, with the preserved-assets list (A6) accounted for
     item by item -- each one named, with its post-collapse home.
  4. After Phase C, `bash .claude/scripts/generate-task-order.sh` (or the equivalent regeneration
     path) produces a TODO.md whose dependency waves are acyclic and whose Core Agent System
     section reflects the new ordering.
  5. No file under agent-system/extensions/** or .claude/** is created, modified, or deleted by
     this task. Its writes are confined to specs/**.

---

### 115. Mirror model-flag consumption into skill-orchestrate-hard and reconcile the composability docs
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 114

**Description**: Mirror model-flag consumption into skill-orchestrate-hard, and reconcile the documentation that currently claims /orchestrate --hard composes with model flags when it does not. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

DEPENDS ON the base model-flag threading task (wire model-flag support into /orchestrate and the base engine). The dependency is on its recorded DESIGN DECISION, not on file overlap -- the two file scopes are disjoint. Do not start this until (a) uniform-vs-lifecycle-only, (b) multi-task threading, and (c) hard-mode-MT coverage have been settled and written down there. Applying a different convention here than the base engine uses would be a failed implementation.

PART 1 -- HARD ENGINE. skills/skill-orchestrate-hard/SKILL.md: `grep -c model_flag` returns ZERO over 110,490 bytes. It has 7 `subagent_type` dispatch sites, all in its SINGLE-TASK path:
    :585, :620, :679   $RESEARCH_AGENT dispatches
    :709               $PLANNER_AGENT
    :886               $IMPLEMENT_AGENT
    :1091, :1468       $RESEARCH_AGENT (escalation / late-stage)
Add the model_flag context-parse key to its single-task Stage 1 and pass `model` at these sites, following exactly the convention the base task recorded.

ITS MULTI-TASK HALF NEEDS NO EDITS, subject to the base task's confirmation of decision (c). skill-orchestrate-hard/SKILL.md:1580 states its multi-task stages are "Same as base skill-orchestrate multi-task stages (MT-1 through MT-5)", and :1687 restates that those stages live solely in the base-skill file. So base-engine edits cover hard mode's multi-task path for free. VERIFY this delegation still holds before relying on it -- if the base task found otherwise, rescope accordingly rather than leaving hard multi-task silently unwired.

PART 2 -- DOCUMENTATION RECONCILIATION. merge-sources/claudemd.md contains a live contradiction:
  - :172 (Model Enforcement) correctly says the model flags "work on `/research`, `/plan`, and `/implement`" -- accurately omitting /orchestrate.
  - The Hard Mode `### Composability` bullet says "`--hard` works with model flags: `--hard --opus` uses Opus model with hard-mode contracts (also composable with `--fable`, e.g. `--hard --fable`)", which reads as though `/orchestrate --hard --fable` works today. It does not.
Once the base task and Part 1 land, BOTH statements become reachable-but-stale in the other direction: :172's command list must grow to include /orchestrate, and the Composability bullet becomes true rather than aspirational. Update both so the documented surface matches the implemented one, and make sure the Options table in commands/orchestrate.md (edited by the base task) agrees with whatever exemption policy decision (a) settled -- if the override is lifecycle-only, the exemption must be stated in all three places, not just one.

EDIT THE MERGE SOURCE, NOT THE GENERATED FILE. .claude/CLAUDE.md is generated from merge-sources/claudemd.md; its header says so explicitly. An edit to the generated file is wiped on the next deploy.

DO NOT:
  - Re-litigate the design decisions. They belong to the base task. If one of them looks wrong once seen in the hard engine, say so and stop rather than diverging.
  - Edit commands/orchestrate.md or skills/skill-orchestrate/SKILL.md here. Those are the base task's territory.

VERIFICATION BAR. (1) `/orchestrate N --hard --fable` dispatches hard-mode single-task research/plan/implement agents on Fable. (2) `/orchestrate N,M --hard --fable` threads through the base MT stages -- confirming the delegation claim empirically, not just by reading :1580. (3) Omitting all model flags leaves hard-mode dispatch byte-identical to today. (4) The regenerated .claude/CLAUDE.md contains no statement about model-flag command coverage that is false.

---

### 114. Wire model-flag threading through /orchestrate and the base orchestrate engine
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Wire model-flag support into /orchestrate: thread model_flag from the command through the base skill-orchestrate engine so a model override actually reaches dispatched agents. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/ (the .claude/ tree is a disposable deploy artifact regenerated from the source store -- see rules/source-store-deploy-boundary.md). Do not hand-author anything under .claude/**.

MOTIVATING CASE vs ACTUAL SCOPE. The user reported "--fable does not work with /orchestrate". --fable is NOT broken in isolation: ALL FOUR model flags (--haiku, --sonnet, --opus, --fable) are equally unwired on /orchestrate, through one single gap. The work is therefore "wire model-flag support into /orchestrate", with --fable as the motivating case. This widening was surfaced to the user and confirmed at task-creation time; it is not a silent scope expansion.

ORIGIN: observed live on 2026-08-26. `/orchestrate 394,384 --lit --fable` was invoked. Every sub-dispatch silently ran on its agent's frontmatter default model. No warning, no error -- the flag was accepted and ignored.

VERIFIED DEFECT (checked directly against the source store at agent-system/, not a deploy artifact):
  1. PARSING IS ALREADY CORRECT AND MUST NOT BE TOUCHED. scripts/parse-command-args.sh already handles all four model flags (see its lines 82 and 109-118) and exports MODEL_FLAG at line 179. The flag arrives intact. The gap is entirely downstream.
  2. commands/orchestrate.md has NO model consumer. Its `## Options` table (around line 33) lists --lit, --dry-run, --allow-self-modifying, --allow-scope-collision, --continue-budget -- no model flag. Neither of its two Skill-delegation arg strings includes a model key:
       :430  multi-task skill-orchestrate invocation (Step 4) -- threads lit_flag, allow_self_modifying, allow_scope_collision, continue_budget
       :626  single-task STAGE 2 invocation -- threads lit_flag, continue_budget
  3. skills/skill-orchestrate/SKILL.md: `grep -c model_flag` returns ZERO over 188,284 bytes. Neither single-task Stage 1's context parse nor Stage MT-1's context parse reads a model flag, and none of its 16 `subagent_type` dispatch sites passes a `model` parameter.
  4. scripts/command-route-agent.sh and scripts/lib/manifest-routing-lib.sh: `grep -n "MODEL_FLAG\|model_flag"` returns ZERO in both. Routing resolves agent NAMES by task type and effort flag only; model selection is not part of that ladder and should not be added to it. Do not attempt to fix this in the routing library.

REFERENCE PATTERN -- MIRROR THIS, DO NOT INVENT A NEW ONE. /research already implements the complete pattern end to end, in commands/research.md:
    :450-456   maps each flag to model_flag (--haiku/--sonnet/--opus/--fable), with an explicit null default documented as "use agent's frontmatter default"
    :540       threads model_flag={model_flag} into the team Skill arg string
    :544       threads model_flag={model_flag} into the single-agent Skill arg string
    :547-552   instructs that when model_flag is set, the `model` parameter is passed to the Agent tool to override the agent's default; when null, the parameter is omitted entirely
The consuming half is in skills/skill-researcher/SKILL.md:187 (context-parse key) and :195 (the pass-as-model-parameter instruction). /plan and /implement follow the same shape. The Agent tool natively accepts a `model` parameter. Adopt this shape verbatim so /orchestrate is consistent with the other three lifecycle commands.

SCOPE OF THIS TASK: commands/orchestrate.md and skills/skill-orchestrate/SKILL.md only. The hard engine and the documentation reconciliation are a separate follow-on task, which depends on the design decision recorded here.

WORK ITEMS:
  a. commands/orchestrate.md -- add the four-flag mapping and the null default (mirroring research.md:450-456); add the model flags to the `## Options` table; add model_flag={model_flag} to BOTH delegation arg strings at :430 and :626.
  b. skills/skill-orchestrate/SKILL.md -- add the model_flag key to single-task Stage 1's context parse AND Stage MT-1's context parse; pass `model` at the dispatch sites per the decision below.

DESIGN DECISIONS THIS TASK MUST SETTLE AND RECORD (do not leave implicit; the follow-on task consumes them):
  (a) UNIFORM vs LIFECYCLE-ONLY. Does the model override apply to every dispatch an orchestration makes, or only to the lifecycle dispatches (research/plan/implement), leaving the auxiliary ones at their frontmatter defaults? The auxiliary sites in skill-orchestrate/SKILL.md are: the blocker-escalation fork (:1075), the reviser dispatches (:1089, :1136), and the drift-inspection fork (:1114). Argument for lifecycle-only: the auxiliary dispatches are diagnostic/meta work whose model choice is a deliberate frontmatter decision (reviser-agent is Opus by policy), and a user passing --haiku to speed up implementation probably does not intend to downgrade the reviser. Argument for uniform: predictability -- a flag that means "run this orchestration on model X" is easier to reason about than one with unstated exemptions. Decide, state the rationale, and make the behavior explicit in orchestrate.md's Options table either way.
  (b) MULTI-TASK THREADING. How model_flag reaches Stage MT-4's three per-task dispatch loops: research (:2096), planner (:2103), implement (:2115). Each builds an explicit context object; model is a separate Agent-tool parameter, not a context field, so confirm whether it threads alongside subagent_type per-task or is resolved once at MT-1.
  (c) HARD-MODE MT COVERAGE. Confirm (and record) that hard mode's multi-task half is covered for free by base delegation -- skill-orchestrate-hard/SKILL.md:1580 and :1687 both state that its multi-task stages are the base skill-orchestrate MT-1 through MT-5. If this holds, the follow-on task only needs to edit hard mode's 7 SINGLE-TASK dispatch sites. If inspection shows it does NOT hold, say so explicitly so the follow-on task is rescoped rather than silently under-delivering.

DO NOT:
  - Modify parse-command-args.sh. It is already correct.
  - Add model selection to command-route-agent.sh or manifest-routing-lib.sh. That ladder resolves agent NAMES only; model is an orthogonal dimension passed at dispatch time.
  - Introduce sticky model state in state.json. Model flags are per-invocation only, exactly like --hard and --lit.
  - Edit skill-orchestrate-hard/SKILL.md or the claudemd merge source here -- those belong to the follow-on task.

VERIFICATION BAR. (1) `/orchestrate N --fable` on a single task visibly dispatches its research/plan/implement agents on Fable rather than their frontmatter defaults. (2) The same holds for the other three flags. (3) `/orchestrate N,M --fable` (multi-task) threads the override through MT-4's per-task loops. (4) Omitting all model flags produces byte-identical dispatch behavior to today -- no `model` parameter emitted, frontmatter defaults intact. This no-flag regression check is the most important one: it is what proves the change is additive.

RELATED, NOT A DEPENDENCY: task wire_lit_flag_through_team_skills is the same defect CLASS (a flag parsed, accepted, and then silently dropped downstream) in the team-skills subsystem. Disjoint file scope; the two do not block each other. Worth reading its description for the shape of the fix, not for shared code.

---

### 113. Fix briefing sigpipe head crash
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Fix the SIGPIPE crash that makes repo-mode `--lit` briefing fail outright. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified at task-creation time: the Logos/Theory deploy copy of literature-briefing.sh is byte-identical to the source store, so there is no drift to reconcile.

ORIGIN: observed directly during a `/research 384 --lit` run in the Logos/Theory repo on 2026-08-26, on a 52-entry sub-index against the 11,545-entry global index. Repo-mode briefing did not return a sparse or empty result -- it CRASHED, and the wrapper reported `[lit] briefing generation failed (exit 141)`. Exit 141 is 128+13, i.e. SIGPIPE.

THIS IS A DISTINCT DEFECT FROM TASKS 108 AND 112. Do not fold it into either.
  - Task 108 is the coverage-delta performance stall in literature-lit-flag-resolve.sh (also hit in the same session: the resolver exceeded a 120s timeout). Different script, different failure.
  - Task 112 is `--global` mode returning ZERO segments because the FTS5 query ANDs all terms of a full task description. That is a recall bug in global mode that exits 0. This task is a hard crash in REPO mode (`--query`), and it fires before any search happens.
A repo whose sub-index is healthy and whose corpus is fully present still gets no briefing at all. In the observed session the sub-index had 52 resolvable entries and the material was reachable by hand -- `literature-search.sh` returned good results for the same topic throughout.

ROOT CAUSE, CONFIRMED BY `bash -x` TRACE. literature-briefing.sh:63 sets `set -euo pipefail`. The script then extracts index fields with the pattern `jq ... | head -1`. For SCALAR extractions this is safe: jq emits one line, head consumes it, jq exits 0. There are two sites where the jq program selects a WHOLE ENTRY OBJECT and jq is NOT given `-c`, so it pretty-prints a multi-line object:

    literature-briefing.sh:227-230   parent_entry=$(jq -r --arg id "$doc_id" '
                                       .entries[]
                                       | select((.id // .doc_id) == $id and (.parent_doc == null or .parent_doc == ""))
                                     ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

    literature-briefing.sh:234-236   parent_entry=$(jq -r --arg id "$doc_id" '
                                       .entries[] | select((.id // .doc_id) == $id)
                                     ' "$GLOBAL_INDEX" 2>/dev/null | head -1)

`head -1` takes the opening `{` and exits. jq keeps writing the remaining lines, receives SIGPIPE, and dies 141. `pipefail` promotes the pipeline's status to 141 and `set -e` kills the script. The `2>/dev/null` hides jq's own diagnostic, so the only visible symptom is the wrapper's `exit 141` line.

WHY IT IS INTERMITTENT-LOOKING (do not be misled into calling it unreproducible). Whether jq finishes writing before head exits is a race mediated by the 64KB pipe buffer. Small entries fit the buffer and jq completes before the reader goes away, so many documents process fine; the crash lands on the first entry whose pretty-printed JSON loses that race. In the observed trace, 47 documents processed successfully and the script died on `horty_2001_agency-and-deontic-logic`. Reproduce with: `bash .claude/scripts/literature-briefing.sh --query "game theory self-play"` from a repo with a populated sub-index, or `bash -x` the same to see the exact dying site.

FIX DIRECTION (validate, then choose; the second is preferred).
  1. MINIMAL: add `-c` to both jq calls so the object is emitted on one line. This removes the race but leaves the fragile `jq | head -1` idiom in place.
  2. PREFERRED: remove the pipe entirely by bounding the result inside jq -- `jq -c 'first(.entries[] | select(...))'` or `limit(1; ...)`. This eliminates `head` from the two sites, so no SIGPIPE is possible regardless of entry size, and it is also faster (jq stops scanning at the first match rather than streaming every match into a pipe that discards them). Note the current code scans ALL entries and throws away everything after the first -- `first`/`limit` fixes a real inefficiency alongside the crash.
  3. AUDIT THE REMAINING `| head -1` SITES rather than assuming they are safe. Confirmed-scalar and therefore currently safe: :166, :251, :255, :259, :275, :281, :289, :310. Each should still be checked for the same shape, and any future whole-object extraction must not reintroduce the idiom. Consider whether a small helper (`jq_first`) is warranted so the correct pattern is the easy one.

DO NOT "FIX" THIS BY REMOVING pipefail OR set -e. Both are load-bearing for the script's other failure handling. The bug is the idiom, not the strictness.

PRESERVE EXACTLY:
  - The `(.id // .doc_id)` tolerance at both sites -- it is load-bearing for stub-shaped entries keyed only by .doc_id (see get_doc_fidelity's header contract).
  - The two-step lookup: strict parent_doc-filtered query first, then the unfiltered fallback for older entries lacking the field. Collapsing these two into one query changes which entry wins for documents that have both a parent and child entries.
  - The `<!-- lit-coverage ... -->` marker semantics, which lit-stage4a-flow.md greps to drive sparse re-prompting.

VERIFICATION BAR. (1) `literature-briefing.sh --query "<description>"` completes with exit 0 and emits a non-empty briefing against a populated sub-index -- run it against the Logos/Theory sub-index (52 entries), which is the observed failing case. (2) The emitted briefing is IDENTICAL in content to what the pre-fix script produced for the documents it managed to process before dying -- a fix that changes which entry is selected is a failed implementation. (3) Run against a sub-index containing horty_2001_agency-and-deontic-logic specifically, the document that triggered the observed crash. (4) Confirm no `jq ... | head -1` site remains where the jq program can emit a multi-line value.

FILE-OVERLAP NOTE: task 112 also edits literature-briefing.sh (global-mode query construction, :73 and :390-419). This task touches only the repo-mode parent-entry extraction at :227-236 and the `| head -1` audit, so the two are territorially separable, but they should not run concurrently against the same file. Sequence this one FIRST: it is smaller, it is a hard crash rather than a recall problem, and 112's verification bar requires actually running the briefing script -- which this task is what makes possible in repo mode.

---

### 112. Fix literature-briefing.sh --global FTS5 over-constraint returning zero segments
- **Effort**: 6-10 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 108

**Description**: Make global-corpus briefing actually return results instead of silently finding nothing. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified during task creation: the BimodalLogic deploy copies of every script named below are byte-identical to the source store, so there is no drift to reconcile.

NOTE THIS TASK SPANS TWO EXTENSIONS: literature-briefing.sh is in the literature extension, but lit-stage4a-flow.md lives in the CORE extension at agent-system/extensions/core/context/patterns/lit-stage4a-flow.md.

ORIGIN: defects observed directly during a `/research 503 --lit` run in the BimodalLogic repo on 2026-08-26. Every claim below was re-verified against the source store at task-creation time; line numbers are from that verification, not from the original session.

THE DEFECT. literature-briefing.sh --global passes its query VERBATIM to literature-search.sh (SEARCH_SCRIPT, literature-briefing.sh:73; global search mode at :390-419), whose FTS5 semantics AND all terms together. The Stage 4a flow hands it the FULL TASK DESCRIPTION -- lit-stage4a-flow.md:85 and :138 both call:

    lit_context=$(bash .claude/scripts/literature-briefing-invoke.sh --global "$description")

For the observed task that description contained the literal token <sec:representation>, absolute file paths, and 20+ content words. Result: ZERO segments. The '<' produced an FTS5 syntax error; the phrase-retry and trigram fallbacks then also returned empty. A hand-written 14-word plain-language retry ALSO returned 0 -- so this is not merely a sanitization bug, the AND-all-terms semantics alone is enough to guarantee no match at realistic query lengths.

PROOF THAT THE CORPUS WAS NEVER THE PROBLEM. Against the SAME task description, literature-coverage-delta.sh -- which routes the description through filter_terms() from literature-term-match.sh:59 first -- found 111 MATCHING GLOBAL DOCUMENTS. Nine subsequent hand-written 2-4 word searches resolved 131 segments. The material existed and was reachable the whole time; only the briefing's query construction could not reach it. That contrast between the two call sites is the core evidence for this task.

FIX DIRECTION (three parts, verify each).
  1. REUSE filter_terms. literature-briefing.sh does not currently source literature-term-match.sh at all (grep confirms no filter_terms reference in the file). literature-coverage-delta.sh:147 shows the established consumption pattern:
        mapfile -t FILTERED_TERMS < <(filter_terms "$query")
     Adopt the same helper rather than writing a second stop-word filter.
  2. REPLACE ONE AND-ALL QUERY WITH SHORT MERGED SEARCHES. Run short per-term (or OR/quorum) searches and merge results by BM25 rank. Note literature-briefing.sh:439 observes that BM25 rank is already computed inside literature-search.sh, so merging should consume that rather than recomputing relevance.
  3. SANITIZE BEFORE FTS. Strip or escape FTS5-hostile input -- '<' and '>', '/' and absolute paths, and any other character with FTS5 query-syntax meaning. This is what turned a poor-recall query into a hard syntax error.

ALSO EVALUATE THE CALLER. Consider changing lit-stage4a-flow.md to pass the task TITLE plus filtered terms rather than the raw description. TREAD CAREFULLY: that file is the single shared Stage 4a block imported and executed VERBATIM by skill-researcher, skill-planner, skill-implementer and their -hard variants, so any change there affects all six call sites at once. Fixing the briefing script alone is a legitimate, lower-blast-radius outcome if the caller change proves risky -- decide with reasons rather than defaulting.

PRESERVE THE SPARSE-COVERAGE CONTRACT. literature-briefing.sh emits the machine-readable marker `<!-- lit-coverage mode=global ... sparse=true ... -->` which lit-stage4a-flow.md:206-223 greps to drive interactive re-prompting. Improving recall MUST keep that marker accurate -- if the fix makes genuinely-sparse results look non-sparse, the re-prompt path stops firing and a real coverage gap becomes invisible.

VERIFICATION BAR. Re-run the exact failing case: the original task-503 description through `literature-briefing.sh --global`. It returned 0 segments; it must now return a non-empty, topically relevant set. Cross-check the result against the 111 documents / 131 segments that the coverage-delta and manual routes found -- those are the known-reachable ground truth for this query.

DEPENDENCY NOTE: serialized after task 108 purely as FILE-OVERLAP protection on literature-term-match.sh (108 may restructure how terms are extracted for the coverage-delta hot loop). The dependency is territorial, not semantic. If 108's summary reports it did not modify literature-term-match.sh, this task can start immediately.

---

### 111. Add literature-audit.sh argument validation and scope the /literature --validate schema check
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Two small, independent correctness fixes in literature tooling. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified during task creation: the BimodalLogic deploy copies of every script named below are byte-identical to the source store, so there is no drift to reconcile.

ORIGIN: defects observed directly during a `/research 503 --lit` run in the BimodalLogic repo on 2026-08-26. Every claim below was re-verified against the source store at task-creation time; line numbers are from that verification, not from the original session.

=== DEFECT 1: literature-audit.sh silently swallows unknown arguments ===

OBSERVED: invoking `literature-audit.sh --help` did not print usage -- it started a LIVE PDF CONVERSION of a Zotero-storage PDF into /tmp. Harmless in effect, genuinely surprising in behavior, and the exact opposite of what --help should do.

THE CAUSE, literature-audit.sh:382-387 -- the arg-parsing case has a catch-all that discards anything unrecognized and falls through to the default audit:

    case "$1" in
      --pdf) shift; explicit_pdfs+=("$1"); shift ;;
      --xref) mode="xref"; shift ;;
      --all) mode="all"; shift ;;
      *.pdf|*.djvu) explicit_pdfs+=("$1"); shift ;;
      *) shift ;;

THE FIX. Add a usage() function and handle -h/--help explicitly (exit 0). Make a genuinely unknown argument a hard error with usage on stderr (exit 64, matching the usage-error convention literature-ingest-online.sh already uses) rather than a silent discard. The script header at literature-audit.sh:9-11 already documents the three real invocation forms -- usage() should agree with it. Cheap follow-on worth doing while here: --pdf currently consumes $1 after shift without checking it exists or is non-flag, so a trailing bare `--pdf` appends an empty path.

=== DEFECT 2: /literature --validate applies document-level schema rules to section entries ===

THE DEFECT. skills/skill-literature/SKILL.md, Mode: Validate, Step 2 (SKILL.md:372-380 for the stated rule, :454-460 for the implementing check) requires id, path, token_count, keywords, summary, doc_type, source_format on EVERY entry. Section-level entries never carry the document-level fields.

MEASURED AGAINST THE LIVE GLOBAL INDEX (11,545 entries): 11,078 entries lack doc_type; 11,043 lack authors. Running validate as currently specified would therefore emit roughly ELEVEN THOUSAND spurious warnings, which is why the check is effectively unusable.

THE FIX. Scope the required-field check to TOP-LEVEL DOCUMENT entries only (path ends with '/', or parent_doc == null -- use the same predicate literature-coverage-delta.sh:212 already uses for this exact distinction, rather than inventing a second one). Section entries should be held only to id / path / token_count. Note SKILL.md:427 already carves out a related special case for book/semantic-chunk parents (doc_type 'book', token_count 0 by design) -- reconcile with it rather than adding a parallel exception. Keep the Step 4 report section ('Schema Warnings ({count}) -- entries missing required v2 fields', SKILL.md:653) coherent with whatever scoping is chosen.

EXPLICITLY OUT OF SCOPE -- CORPUS DATA, NOT TOOLING. Do NOT fix these here: 75 entries genuinely lack keywords and 62 genuinely lack summary; 2 top-level entries carry comma-joined single-author strings that `literature-normalize-authors.sh --apply` would correct. Those are data defects in the corpus and are being handled separately. This task changes the CHECK, not the DATA. A correct implementation will make those ~137 real defects MORE visible by removing the 11k of noise burying them.

COORDINATION NOTE (no dependency deliberately added). Task 89 restructures this same SKILL.md wholesale into mode-gated sections, and task 106 also edits it. This task's edit is small and localized to Validate Step 2. It was intentionally NOT made dependent on 89 -- blocking a two-line scoping fix behind a large not-started refactor is the wrong trade. Landing this first lets 89 carry the corrected text through its restructure. If 89 has already landed when this is implemented, re-locate Validate Step 2 in the new structure rather than assuming the line numbers above.

---

### 110. Add multi-provider fallback and S2_API_KEY support to literature-discover.sh Tier 3
- **Effort**: 6-10 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Stop Tier 3 online discovery from being a single point of failure. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified during task creation: the BimodalLogic deploy copies of every script named below are byte-identical to the source store, so there is no drift to reconcile.

ORIGIN: defects observed directly during a `/research 503 --lit` run in the BimodalLogic repo on 2026-08-26. Every claim below was re-verified against the source store at task-creation time; line numbers are from that verification, not from the original session.

THE DEFECT. literature-discover.sh's Tier 3 has exactly ONE provider. literature-discover.sh:537:

    local ss_url="https://api.semanticscholar.org/graph/v1/paper/search?query=${encoded_query}&fields=title,authors,year,openAccessPdf,externalIds&limit=10"

OBSERVED: Semantic Scholar returned HTTP 429 for the ENTIRE ~35-minute session -- 20+ attempts across 3 distinct queries, with 75s backoff between retries. Consequence: NO automated discovery record was produced at all, and the online-ingest bridge (literature-ingest-online.sh) could not be exercised by its normal route. A single rate-limited provider silently disables the whole online tier.

FIX 1 -- HONOR AN API KEY. Semantic Scholar's rate limits are far higher for authenticated callers. Read an S2_API_KEY environment variable and, when set, send it as an `x-api-key` request header. Verified absent today: grep for 'S2_API_KEY|x-api-key' across literature-discover.sh returns nothing. Unset must remain fully supported (anonymous access), so this is additive.

FIX 2 -- ADD FALLBACK PROVIDERS. When Semantic Scholar returns 429 (or any non-200, or an unparseable body), fall through to at least one alternate provider. Candidates, in rough order of fit:
  - OpenAlex:  https://api.openalex.org/works?search=...  (no key required, generous limits, has DOI + OA location data)
  - Crossref:  https://api.crossref.org/works?query=...   (no key, authoritative DOIs, but no OA PDF links)
  - arXiv API: http://export.arxiv.org/api/query           (Atom XML, not JSON -- note the parser cost; strong for the preprint-heavy corpus)
Choosing a subset with justification is a valid outcome; adding all three is not required.

HARD CONSTRAINT -- SCHEMA IDENTITY. Every provider MUST emit the SAME record schema that the existing Semantic Scholar branch emits, because literature-ingest-online.sh consumes it directly. The authoritative field list is the record contract documented at literature-ingest-online.sh:26-41 and constructed at literature-discover.sh:657-670: title, authors, year, doc_id, status, tier, and path|doi|pdf_url|arxiv_id. Preserve the doc_id derivation rules exactly (doi-slug | arxiv_<id> | ss_<paperId> | unknown_<slug>, see :607-608 and :627-630) -- a provider that mints doc_ids differently will break dedup and index patching downstream. Note especially that arXiv hits are status=="open_access" with arxiv_id set; there is NO literal "arxiv" status (literature-ingest-online.sh:34-39).

PRESERVE TIER SEMANTICS. Tier 3 is non-fatal by design and honors TIER3_QUOTA including rolled-forward budget from Tiers 1/2 (literature-discover.sh:506-521, :714-716). Critically, the existing code distinguishes 'Tier 3 ran and found nothing' from 'Tier 3 could not run' via the TIER3_STATUS line -- absence of the line means the former. Multi-provider fallback must keep that distinction meaningful: exhausting ALL providers is a different outcome from all providers returning zero matches, and the status line should let a reader tell them apart.

VERIFICATION BAR. Demonstrate a real end-to-end discovery producing a schema-valid record while Semantic Scholar is unavailable (simulate by forcing the S2 branch to 429). Then feed that record to `literature-ingest-online.sh --dry-run` and show it classifies without a usage error -- that is the actual integration contract this task exists to restore.

---

### 109. Fix literature-ingest-online.sh failure modes: arXiv create, orphan cleanup, pipeline fallback
- **Effort**: 8-14 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 102

**Description**: Fix three distinct failure modes in the online-ingest bridge, each observed on a real record. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified during task creation: the BimodalLogic deploy copies of every script named below are byte-identical to the source store, so there is no drift to reconcile.

ORIGIN: defects observed directly during a `/research 503 --lit` run in the BimodalLogic repo on 2026-08-26. Every claim below was re-verified against the source store at task-creation time; line numbers are from that verification, not from the original session.

=== DEFECT (a): arXiv-only open_access record fails Zotero item creation ===

OBSERVED: arXiv 1009.2803 (Gehrke & Vosmaer), a status=="open_access" record with arxiv_id set and doi==null. The PDF downloaded and passed %PDF magic-byte verification, then `zotero-write.sh item-add` failed -> ONLINE_INGEST_ZOTERO_CREATE_FAILED (exit 3).

CORRECTION -- THE PROPOSED ROOT CAUSE IS WRONG. DO NOT IMPLEMENT THE ORIGINALLY-PROPOSED FIX. The original framing was that the bridge 'hard-requires a DOI' and should be changed to key on arXiv id instead. THERE IS NO DOI HARD-REQUIREMENT AT EITHER LAYER. Verified directly:

  - literature-ingest-online.sh:692-695 already calls item-add unconditionally and appends --doi only when one is present:
        ZW_CMD=("$SCRIPT_DIR/zotero-write.sh" item-add --pdf "$STAGING_PATH")
        if [ -n "$DOI_RAW" ]; then
          ZW_CMD+=(--doi "$DOI_RAW")
        fi
  - zotero-write.sh:287 accepts EITHER --pdf or --doi ('item-add requires --pdf PATH or --doi DOI'); --pdf alone is documented at :100-101 as the preferred single atomic create+attach call.

So a DOI-less arXiv record is already a supported input shape, and the record was classified correctly (literature-ingest-online.sh:660-664 logs the arxiv_id-present resolvable case explicitly). THE FAILURE CAME FROM `zot add --pdf` ITSELF AT RUNTIME, one layer below.

START HERE, DO NOT GUESS: the real stderr was captured into ITEM_ADD_STDERR (literature-ingest-online.sh:699-701) and interpolated into the directive_stop message at :704-706. Reproduce the call and read that text. A directly relevant known unknown: zotero-write.sh:34-41 records that `zot add --pdf`'s exact `data.*` envelope field names are NOT independently confirmed against a real call, and extract_envelope_field() / resolve_storage_path_from_envelope() (literature-ingest-online.sh:473-510) exist as defensive mitigation for precisely that uncertainty. Confirming the real envelope shape is likely part of this defect.

Only AFTER the true cause is known, decide the fix. Passing a resolved published DOI when one exists (e.g. 10.1007/978-3-642-22303-7_6 for this record) may be worth doing on its own merits, but it is NOT established as the fix for this failure and must not be presented as one.

=== DEFECT (b): failure paths leave an orphan staging directory ===

OBSERVED: after the (a) failure, an EMPTY $LITERATURE_DIR/sources/arxiv_1009_2803/ directory remained with no corresponding index entry. It was removed by hand. The staging dir is created at literature-ingest-online.sh:274 (`mkdir -p "$(dirname "$dest")"`) inside the download path; there is no EXIT trap and no cleanup on the directive_stop paths.

SCOPE: every directive_stop that can fire AFTER the staging dir is created must leave no orphan behind -- at minimum ONLINE_INGEST_ZOTERO_CREATE_FAILED (3), ONLINE_INGEST_ZOTERO_ATTACH_FAILED (5), ONLINE_INGEST_PIPELINE_FAILED (6). Note ONLINE_INGEST_DOWNLOAD_FAILED (2) can also fire post-mkdir. CONSTRAINT: cleanup must remove ONLY a directory this invocation created and left empty or partial -- it must never delete a pre-existing populated sources/ directory belonging to an already-ingested document. Guard on 'we created it this run', not on 'it looks empty now'.

=== DEFECT (c): pipeline failure with no fallback-engine attempt ===

OBSERVED: Venema 2007, 'Algebras and Coalgebras' (author's PDF, 86pp). The conversion quality gate rejected the default engine's output -> ONLINE_INGEST_PIPELINE_FAILED (exit 6, literature-ingest-online.sh:735-738, from run_ingest_pipeline()). The agent then repaired it MANUALLY using the PyMuPDF column-clustering fallback engine, which produced a usable result for this document.

*** READ THIS BEFORE DESIGNING (c). *** The obvious fix -- 'auto-try the fallback engine before declaring pipeline failure' -- is exactly the premise that task 102 exists to retire. Task 102 ('Characterize converter-tier behavior and correct the falsified universal-remedy claim') establishes that the PyMuPDF column-clustering tier is NOT a universal remedy: savage_1972 and joyce_1999 are both scans that respond to it in OPPOSITE directions. An unconditional auto-retry would re-import the falsified claim. THIS TASK DEPENDS ON 102 FOR THAT REASON -- consume 102's characterization to decide WHEN a retry is warranted, or implement a narrower remedy (e.g. surface the fallback as an actionable operator suggestion in the failure message rather than performing it automatically). Defects (a) and (b) do NOT depend on 102 and may land first.

TEST VEHICLE. Automated discovery could not be exercised during the observed session because literature-discover.sh's Tier 3 was returning HTTP 429 throughout (that is task 110's subject). literature-ingest-online.sh consumes a record JSON on its own, so construct records by hand to exercise these paths, and use the script's own --dry-run mode (literature-ingest-online.sh:117-123) for the no-side-effect passes. Do not block on 110.

---

### 108. Eliminate literature-coverage-delta.sh per-entry jq spawns so --lit stops timing out
- **Effort**: 4-8 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Make the topic-scoped coverage-delta guard fast enough that every `--lit` invocation does not pay a multi-minute stall. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md). Verified during task creation: the BimodalLogic deploy copies of every script named below are byte-identical to the source store, so there is no drift to reconcile.

ORIGIN: defects observed directly during a `/research 503 --lit` run in the BimodalLogic repo on 2026-08-26. Every claim below was re-verified against the source store at task-creation time; line numbers are from that verification, not from the original session.

THE SYMPTOM. literature-lit-flag-resolve.sh calls literature-coverage-delta.sh on every `--lit` invocation (see the delta_script block at literature-lit-flag-resolve.sh:164-193). During the observed run the keyword pass over the 11,545-entry global index EXCEEDED A 120 SECOND TOOL TIMEOUT and only completed after roughly 4-5 minutes when re-run in the background. This cost is unconditional: it is paid by every `/research|/plan|/implement --lit` dispatch whose sub-index clears the absolute count floor.

CORRECTION -- THE OBVIOUS FIX IS ALREADY IMPLEMENTED. DO NOT SPEND RESEARCH TIME ON IT. The originally-proposed remedy was 'restrict the keyword pass to top-level entries (path ending in /, 216 docs) instead of all 11.5k section entries'. That restriction ALREADY EXISTS. literature-coverage-delta.sh:212 -- the feeder of the main while loop -- reads:

    done < <(jq -c '.entries[] | select(.parent_doc == null or .parent_doc == "")' "$GLOBAL_INDEX" 2>/dev/null)

so only top-level documents ever enter the loop body. Re-proposing this is a no-op.

THE ACTUAL COST, MEASURED BY INSPECTION. Two separate costs, of which the second dominates:
  (1) One jq pass that must still parse and scan all 11,545 entries to apply that parent_doc filter.
  (2) THREE `echo | jq` SUBPROCESS SPAWNS PER SURVIVING CANDIDATE, at literature-coverage-delta.sh:171-173:

        doc_id=$(echo "$entry" | jq -r '(.id // .doc_id) // ""' 2>/dev/null)
        title=$(echo "$entry" | jq -r '.title // ""' 2>/dev/null)
        keywords=$(echo "$entry" | jq -r '(.keywords // []) | join(" ")' 2>/dev/null)

      At 216 top-level docs that is ~648 process spawns, each parsing a fresh JSON document, inside a bash while loop. This is the hot path.

PRIMARY FIX DIRECTION (validate before committing to it). Collapse (1) and (2) into a SINGLE jq pass that emits one delimiter-separated record per top-level doc (doc_id / title / keywords already joined), consumed by `while IFS=$'\t' read -r doc_id title keywords`. This eliminates all ~648 per-entry spawns outright. Choose a delimiter that cannot occur in titles or keywords (tab is plausible but VERIFY against the real index; jq's @tsv escapes tabs, which is the safer route). Preserve the existing `.id // .doc_id` tolerance exactly -- it is load-bearing.

SECONDARY, ONLY IF THE ABOVE IS INSUFFICIENT. Cache the delta result keyed on a hash of (query/description, sub-index mtime, global index mtime). Prefer NOT to add caching if the single-pass rewrite alone brings the call under a few seconds -- a cache adds an invalidation-correctness burden to a guard whose whole purpose is freshness, and the measured win should decide.

DO NOT CHANGE THE MATCH SEMANTICS. The loop's match rule (literature-coverage-delta.sh:184-205) deliberately mirrors literature-discover.sh's Tier 1 rule: >= 2 distinct term hits when FILTERED_TERM_COUNT exceeds MULTI_TERM_MATCH_THRESHOLD, accept-on-first-hit otherwise. This task is a PERFORMANCE task. Any change to which documents are returned is out of scope and must be surfaced rather than silently made.

VERIFICATION BAR. Before/after wall-clock timing of a real literature-coverage-delta.sh call against the live 11,545-entry global index, plus proof that the candidate set is IDENTICAL before and after (diff the emitted candidate ids for several different queries). A speedup with a changed candidate set is a failed implementation, not a partial success.

FILE-OVERLAP NOTE: task 112 (briefing FTS5 fix) is serialized AFTER this task because both may touch literature-term-match.sh's filter_terms/term_matches helpers. If this task ends up not modifying literature-term-match.sh at all, say so in the summary so 112 can be unblocked early.

---

### 107. Add ocr misrecognition detector to quality gate
- **Effort**: 12-20 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 102, Task 104

**Description**: Add an OCR-misrecognition detector to the literature quality gate. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

THE GAP -- A CORRUPTION CLASS NO EXISTING CHECK COVERS. literature_quality_gate.py's checks are tuned for ENCODING defects: glyph-index-as-codepoint corruption (control_char_count, printable_ratio), ligature residue, dehyphenation residue, column interleaving, sentence-boundary glue. OCR MISRECOGNITION is a different class: the OCR engine emits well-formed, printable, plausibly-tokenized text that is simply WRONG. Nothing in the module detects it.

MEASURED, NOT HYPOTHESIZED. All six string-only checks were run directly against the goldblatt_1989 extraction -- a 2001 Acrobat 3.0 Capture scan whose math pages yield "{9=, 4s:", "0%", "$m", whose headings corrupt ("3.7. Complete varieties" -> "3.7. Complete v&et&s"), and whose title page renders New Zealand as "New 2Miand":

    printable_ratio              0.9994898  (70 non-printable of ~140k chars)
    control_char_count           0
    sentence_boundary_glue_count 3
    ligature_residue_count       0
    dehyphenation_residue_count  4
    column_interleaving_flagged  False (0.2604)

Every check passes. The document is corrupt by direct inspection. This is a false negative, and it is the inverse of the glue-check task's concern (false positives on legitimate binder notation) -- do not conflate the two.

A SIGNAL THAT DEMONSTRABLY WORKS, AND ITS LIMIT. PDF Creator/Producer metadata identified all 7 scan-pipeline PDFs among the corpus's 72 (`pdfinfo | grep -iE 'capture|scan|abbyy|finereader|imag'`): blackburn_2002 (Acrobat 7.0 Image Conversion), burgess_1982 / _i / _ii / 1982b and doets_1989 and gabbay_1993 (ABBYY FineReader). Cheap, one pass, no false negatives among those inspected. BUT THIS IS PROVENANCE, NOT QUALITY -- it identifies documents at RISK of misrecognition; it does not measure whether a given extraction is actually garbled. A good design likely needs both: provenance to select what to scrutinize, and a content signal to judge it.

CANDIDATE CONTENT SIGNALS TO EVALUATE (none validated -- validating them is this task's work): out-of-vocabulary rate against a wordlist; ratio of alphabetic tokens that are non-words; density of mixed alnum/symbol tokens inside otherwise-prose lines; character-n-gram implausibility; agreement between two independent extractions of the same page. Note the corpus contains dense mathematics, where symbol-heavy runs are LEGITIMATE -- a naive symbol-density threshold will fire on correct math and is likely the first thing to get wrong.

HARD CONSTRAINT INHERITED FROM THE CONVERTER-TIER TASK: that task establishes that "scanned/OCR'd" is very likely the WRONG class boundary for TIER SELECTION, because savage_1972 and joyce_1999 are both scans that respond to the fallback tier in opposite directions. That finding constrains what this detector may be USED for. Detecting probable misrecognition in order to warn, withhold certification, or route to re-OCR is in scope. Using it to auto-select a converter tier is NOT -- that is the falsified premise, and this task must not re-import it.

CONSUMERS: the fidelity-audit task's defect (c) needs exactly this class of signal to stop verified_conversion being reachable from a self-comparison; if this task lands first it should expose the detector as an importable function rather than an inline check, so the audit consumes it instead of writing a second one. The OCR-tier task's "OCR VINTAGE, NOT JUST OCR ABSENCE" framing is the same thread from the remedy side -- a detector here is the natural trigger for --force-ocr there, so coordinate the threshold with it rather than picking one independently.

A NEGATIVE RESULT IS A COMPLETE OUTCOME. If no content signal separates OCR garbling from legitimate dense mathematics at an acceptable false-positive rate, say so with the measurements, and fall back to provenance-only flagging (mark scan-derived documents as requiring manual spot-check before certification). That is a real deliverable, not a failure.

---

### 106. Route skill literature convert through gated pipeline
- **Effort**: 6-10 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Route skill-literature's convert path through literature-convert.sh so that /literature ingests are quality-gated. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

THE DEFECT -- TWO CONVERSION PATHS, ONLY ONE GATED. literature-convert.sh runs literature_quality_gate.py on every document it converts. But skill-literature's own Mode: Convert (handle_convert, "Convert Step 3b: Extract Full Text and Determine Chunking") does NOT call it -- it shells out directly:

    full_text=$(pdftotext -layout "$src" - 2>/dev/null)

and proceeds straight to chunking, metadata prompts, index.json write, literature-chunk.sh, and literature-build-index.sh. No gate check runs at any point. Every ingest through `/literature <path>` therefore bypasses the entire quality-gate layer, no matter how good that layer becomes.

CONFIRMED BY A LIVE INGEST, not by reading alone. goldblatt_1989 was ingested through this exact path on 2026-08-26 (74 chunks, indexed, in both the global index and BimodalLogic's sub-index). It is a badly OCR-garbled 2001 Acrobat Capture scan. No gate ran. Nothing warned.

WHY THIS IS THE STRUCTURAL ONE. The sibling tasks in this cluster all improve the gate or the audit. This task is what makes those improvements reachable from the path operators actually use interactively. A better gate that handle_convert never calls protects nothing.

ALSO NOTE THE TIER GAP: handle_convert uses bare `pdftotext -layout`, which is literature-convert.sh's THIRD and last-resort tier. So /literature-path ingests do not merely skip the gate -- they skip the pymupdf4llm primary tier and the PyMuPDF column-clustering fallback entirely, always landing on the weakest engine. Both defects have the same fix.

SCOPE DECISION THIS TASK MUST MAKE. Choose between (i) replacing the inline pdftotext call with a delegation to literature-convert.sh, inheriting the full ladder and gate; and (ii) keeping the inline path but invoking literature_quality_gate.py on its output and surfacing rejections. (i) is the better shape and removes a duplicated conversion implementation; (ii) is cheaper if delegation turns out to conflict with handle_convert's interactive chunk-boundary and metadata prompts, which literature-convert.sh knows nothing about. Weigh the interaction model before committing -- the interactive prompts are handle_convert's reason for existing.

DO NOT let a gate rejection become a silent skip. Whatever shape is chosen, a rejected document must surface an actionable message to the operator (the existing gate's rejection prose is the model), never be written to the index as though it converted cleanly. The corpus already contains a document that was.

ACCEPTANCE: an ingest of a known-bad document through `/literature <path>` produces a visible gate rejection or an explicit recorded caveat; the pymupdf4llm tier is reached on a document where it is the right engine; no second conversion implementation remains in the skill.

---

### 105. Add an OCR tier for image-only and poor-vintage-OCR PDFs
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 102

**Description**: Add an OCR tier to the literature converter, or make the pre-OCR prerequisite an explicit checked failure, so image-only scanned PDFs stop hard-failing the quality gate with a misleading rejection. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

THE GAP. literature-convert.sh has NO OCR tier at all. Its documented engine ladder (literature-convert.sh:15-45) is exactly three tiers: PRIMARY pymupdf4llm via a pinned auto-provisioned uv venv, a mandatory PyMuPDF column-clustering fallback (pymupdf-fallback-toc / pymupdf-fallback-heuristic), and pdftotext. None of them can recover text from a PDF with no text layer. Image-only scanned PDFs (zero text layer) therefore hard-fail the gate and must be pre-OCR'd externally with ocrmypdf before ingest. Today this surfaces to the operator as a confusing quality-gate rejection rather than as a clear, actionable "this PDF has no text layer; run ocrmypdf first".

TWO INDEPENDENT LINES OF EVIDENCE THAT THIS IS THE RIGHT INVESTMENT:
  1. The archived provenance-fidelity audit report independently reached the same conclusion from a different direction. specs/vault/01-vault/archive/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md documents 4 corpus directories (burgess_1984, gabbay_1994, thomason_1984, vardi_wolper_1986) whose PDFs extract to ZERO words via `pdftotext -layout`, making them un-ratio-checkable, and its Risks section recommends "a recommended follow-up of OCR-based extraction (`pytesseract`/`ocrmypdf`) or manual page-count spot-check before promoting to `verified_conversion`". These are the same documents that would benefit from an OCR tier here.
  2. Re-OCR is demonstrated to repair real extraction defects, not merely to enable extraction where none was possible. On joyce_1999_foundations-causal-decision-theory, `ocrmypdf --force-ocr --output-type pdf -l eng` applied to source pages 119 and 217 fixed both of that document's genuine sentence-boundary-glue defects and recovered glyphs the original 2019 archive.org OCR had dropped entirely (a closing curly quote, and the accent in "Reyni"). The dropped quote glyph was itself the cause of one zero-space transition.

KEY FRAMING TO CARRY FORWARD -- OCR VINTAGE, NOT JUST OCR ABSENCE. The joyce_1999 evidence shows the problem is not only "PDF has no text layer" but also "PDF has an OLD, POOR-QUALITY text layer". Those are different conditions needing different responses: absence needs OCR to enable extraction at all; poor vintage needs --force-ocr to REPLACE an existing but degraded layer. A design that only detects zero-text-layer PDFs will miss the second, larger class. Weigh whether the tier should offer both, and how an operator (or the pipeline) decides that an existing text layer is bad enough to warrant replacement -- note that --force-ocr on a good text layer is destructive and must not become a default.

SCOPE DECISION THIS TASK MUST MAKE. Choose between (i) a genuine OCR tier integrated into the converter ladder, and (ii) explicit detection plus a clear actionable error at ingest time that names the ocrmypdf command to run. Option (ii) is substantially cheaper and may be sufficient; option (i) is warranted only if the corpus impact justifies carrying an ocrmypdf dependency and its runtime cost. Consider provisioning implications either way -- the primary tier already uses a pinned auto-provisioned uv venv (see literature-pyenv-provision.sh), which is the natural precedent for how an OCR dependency would be managed.

DEPENDS ON the converter-tier characterization task both for file-overlap serialization on literature-convert.sh and because that task establishes whether OCR vintage or document structure is the operative class variable -- which determines what this tier should key on. Also coordinate with the glue-check task: route (a) of that task (improve the input via re-OCR) is satisfied by the capability built here, so if that task selects (a) this becomes its enabler.

---

### 104. Resolve glue-check false-positive class on math-heavy OCR'd scans
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 102

**Description**: Resolve the sentence_boundary_glue_count() false-positive class on math-heavy OCR'd scans, where the documented fallback-tier remedy provably fails. EVALUATE THREE ROUTES AND JUSTIFY THE SELECTION -- DO NOT PRESUPPOSE ANY OF THEM. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

THE SYMPTOM. sentence_boundary_glue_count() counts [a-z]\.[A-Z] transitions and the gate rejects at >=3. joyce_1999_foundations-causal-decision-theory (296pp scan, 654,128 chars of extracted markdown) yields exactly 4 hits and is rejected outright, so it cannot be ingested at all. Only TWO of the four are real defects -- genuine single missing spaces after a sentence period:
  - "...rather than strict laws of rationality.A rational agent's preference ranking..."
  - "...called Reyni-Popper measures.A Reyni-Popper measure for P rela- tive to..."
The other two are NOT defects; they are inline math notation:
  - "^s.P(S\A)u(0[A S])"   (Stalnaker's Equation)
  - "f.I+i p*( YHr"
Two real defects in 654K characters is excellent conversion quality. The document is rejected only because non-defect notation pushes a 2-real-defect document over a 3-hit cutoff. That is a MEASUREMENT-ACCURACY problem, not a request to tolerate corruption.

CRITICAL CONSTRAINT -- THE FILE'S OWN DOCSTRING PRE-EMPTIVELY PROHIBITS THE OBVIOUS FIX. literature_quality_gate.py:236-241 states verbatim: "The correct operator remedy for a document like this is reconversion with `LITERATURE_CONVERTER=fallback` (the path already proven for bacon_dorr_2024_classicism) -- never widening this exemption further, tuning the threshold-3 cutoff, or a manual override." Simply widening the exemption is a direction the file's maintainers have explicitly ruled out. This task MUST NOT be executed as "widen the exemption to cover inline math".

WHY A DEFENSIBLE DEFECT NEVERTHELESS REMAINS (the task's evidence base):
  - The prohibition is scoped to "a document like this" -- the MIXED class (hott_book_2013, ahrens_north), whose residual hits are DOMINATED BY GENUINE corruption and which therefore SHOULD stay rejected. Widening for their sake would wrongly rescue genuinely-corrupt documents. joyce_1999 is a materially different class: majority-notation hits over a 2-real-defect document.
  - The docstring ALREADY concedes and tolerates a comparable unexempted-non-defect class: arXiv subject-class codes ("math.CT", "math.AT") are described at line ~236 as "a known, deliberately unexempted secondary class, not corruption". joyce's "^s.P(S\A)" is arguably the same kind of thing.
  - THE DOCSTRING'S PRESCRIBED REMEDY IS EXHAUSTED FOR THIS DOCUMENT AND DOES NOT WORK. Reconversion via LITERATURE_CONVERTER=pymupdf (== "fallback"; literature-convert.sh:341 maps `pymupdf|fallback) ENGINE_MODE="fallback_only"`, so this is exactly the documented path) yields 5 hits -- WORSE than the primary tier's 4. The guidance assumes fallback always rescues; there now exists a real counterexample.

THE THREE ROUTES TO WEIGH (all three must be considered and the selection justified):
  (a) IMPROVE THE INPUT INSTEAD OF THE GATE -- re-OCR the source so the genuine defects disappear and the document falls below threshold honestly. This is the route most consistent with the file's stated philosophy of never weakening the gate. DEMONSTRATED TO WORK AT PAGE LEVEL, not merely hypothesized: re-OCR of the two source pages carrying joyce_1999's genuine defects (pages 119 and 217) via `ocrmypdf --force-ocr --output-type pdf -l eng` FIXED BOTH genuine defects, and the re-OCR'd extract of those two pages contains ZERO [a-z]\.[A-Z] hits.
        p119 before: "...strict laws of rationality.A rational agent's preference ranking..."
        p119 after:  "...strict laws of rationality." A rational agent's preference ranking..."
                     (re-OCR additionally recovered a closing curly quote the original 2019 archive.org OCR had dropped entirely -- the missing quote glyph is what produced the zero-space transition)
        p217 before: "...called Reyni-Popper measures.A Reyni-Popper measure for P rela- tive..."
        p217 after:  "...is a Reyni-Popper measure relative to ... {C ... Q: P(C) > 0}..."
                     (accented "Reyni" also correctly recovered)
      IMPLICATION FOR CLASS BOUNDARY: the genuine defects were an artifact of the ORIGINAL 2019 archive.org OCR TEXT LAYER -- not of the PDF and not of the converter. This is further evidence that "scanned/OCR'd" is the wrong class boundary and that OCR VINTAGE/QUALITY is the real variable. Route (a) leans on the OCR-tier task; that is a plan-time coupling, not a hard prerequisite -- this task may select (a) and hand off.
  (b) A NARROWLY-SCOPED MATH-NOTATION EXEMPTION -- permitted ONLY on proof that hott_book_2013 stays at EXACTLY 11 and ahrens_north at EXACTLY 21, and that the negative guard test "sentence-boundary-glue-genuine-fusion-still-counted" still passes. These tripwires are already pinned in scripts/tests/test-quality-gate-notation.sh:104-111, described at line 79 as "over-exemption tripwires [that] must never fall". EXACTLY UNCHANGED, NOT MERELY "NOT REDUCED": the docstring records a prior widening attempt (a blanket global markdown-underscore strip used as a preprocessing pass) that INCREASED one MIXED document from 11 to 26 hits via substitution self-interference -- deleting matched spans glued previously non-adjacent characters into brand-new spurious matches. The current implementation deliberately matches noise-tolerant runs WITHIN the exemption regex itself and has NO separate global-strip pass; preserve that property by extending the existing _PREFIX_BINDER_RE/_PREFIX_HAT_RE family rather than adding any preprocessing pass. Also preserve the existing true-positive fixture (Dorr-Bacon-style genuine <sup>-span fusion corruption). The file has an inline gate_check() self-test harness (reachable via literature-convert.sh --self-test, exercised by tests/test-literature-convert.sh:296) -- EXTEND it, never bypass it.
  (c) A DISTINCT CALIBRATION CLASS for scanned/OCR'd documents rather than changing the shared threshold-3 cutoff. Note the threshold was calibrated at 0-1 occurrences across a random sample of 60 BORN-DIGITAL corpus markdown files; scanned/OCR'd mathematical texts are a document class it was never calibrated against. Route (c) depends on the class boundary established by the converter-tier characterization task -- see the OCR-vintage framing above, which may be the better class variable than scanned-ness.

MANDATORY RECONCILIATION. Whichever route wins MUST reconcile itself with the prohibition at literature_quality_gate.py:236-241, and MUST amend that guidance IN THE SAME COMMIT if the prohibition is being narrowed. Do not leave the codebase asserting a prohibition the implementation has quietly departed from. Coordinate with the converter-tier task, which amends the REMEDY claim at lines 238-239 inside that same docstring paragraph: that task narrows only the remedy claim, this task is the only one permitted to narrow the prohibition itself.

---

### 103. Fix fidelity audit chunk-only blindness and the absent-baseline majority
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Fix literature-fidelity-audit.sh so it can verify pipeline-ingested documents at all, and resolve the absent-baseline problem that blocks the overwhelming majority of the corpus. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

DEFECT (a) -- THE AUDIT CAN NEVER VERIFY ANY PIPELINE-INGESTED DOCUMENT. At literature-fidelity-audit.sh:342-346 the `mds` list comprehension excludes filenames matching ^chunk_\d+\.md$. But the ingest pipeline (literature-ingest.sh -> literature-chunk.sh) emits ONLY chunk_NNNN.md files. So has_md is always False for pipeline-ingested documents, and classify_dir() falls through to "not_yet_converted" (when a source PDF is present) or "unverified_no_baseline" (when it is not). Neither is verified_conversion, so such documents stay permanently quarantined out of default literature-search.sh results.

MEASURED CORPUS IMPACT (~/Projects/Literature/index.json, 287 parent entries): provenance_fidelity unset 137, verified_conversion 70, no_source_pdf 66, unverified_conversion 8, unverified_no_baseline 3, unadjudicated 2, not_yet_converted 1. Default (non---include-unverified) search returns ZERO results for queries that plainly should match -- e.g. "deliberative stit" fails to surface horty_belnap_1995_deliberative-stit. Every working query currently requires the --include-unverified flag.

THE EXCLUSION IS DELIBERATE BUT NARROWER THAN THE CODE IMPLEMENTS -- THIS IS THE KEY TO THE FIX. literature-fidelity-audit.sh:33 warns that chunk_*.md presence/absence is "deliberately NOT used as signals (both are false discriminators in this corpus -- see report)" and says "do not add them back without re-reading the report's Detector Design section". That report has been located and read: specs/vault/01-vault/archive/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md, section "Detector Design" (line 76). It rejects chunk filenames for a NARROWER reason than the code implements, verbatim: "Reject as a primary signal: `chunk_*.md` filename presence/absence (see above -- false discriminator, would misclassify ~30 genuinely converted docs)."

So the report rejected chunk-ness as a CLASSIFICATION DISCRIMINATOR -- it never contemplated excluding chunk files from has_md entirely. The code conflates two different things: "do not let chunk-ness decide the verdict" (correct, per report) and "do not count chunk files as markdown at all" (never intended, and now fatal since chunks are the pipeline's only output shape). THE FIX IS THEREFORE A RECONCILIATION, NOT A CONTRADICTION OF THE REPORT: count chunk_NNNN.md toward has_md and toward the md_words sum, while keeping chunk-ness out of the verdict logic. Update the docstring at line 33 to record this distinction explicitly so the next reader does not re-introduce the conflation.

DEFECT (b) -- THE BASELINE IS UNAVAILABLE FOR NEARLY THE WHOLE CORPUS. Only 12 of 291 sources/ directories contain a source.pdf or source.djvu, so the whole-document word-ratio baseline (md_words / pdf_words via `pdftotext -layout`) simply cannot be computed for the rest, regardless of the chunk_*.md issue. Fixing has_md alone will therefore still not produce verified_conversion for most of the corpus -- the search quarantine that motivates this task would remain largely in place. This task must decide and implement a treatment: a distinct fidelity value, a different baseline, or another mechanism.

CONSTRAINT ON (b) -- DO NOT "FIX" THIS BY IMPORTING PDFs. Naively copying source PDFs into sources/ dirs makes classification WORSE (unverified_no_baseline -> not_yet_converted) and contradicts the corpus's prevailing 12/291 layout. This was tested and reverted. The answer is a classification/baseline change, not corpus surgery.

WHY (a) AND (b) ARE ONE TASK AND MUST NOT BE SPLIT (explicitly confirmed by the user): they are the same function (classify_dir), the same enum, and the same commit's worth of design. A mechanical has_md fix shipped alone would yield verified_conversion for almost nothing and would not actually clear the search quarantine that is the entire point of the work.

CONSUMERS THAT MOVE WITH THE ENUM: the report's "Flagging Behavior" section establishes that literature-search.sh and literature-briefing.sh both read provenance_fidelity, and that both must FAIL OPEN (absent value treated as unverified/loud, never silently authoritative). If this task adds or changes an enum value, both consumers need updating in the same change. Note prior art for exactly this shape: a sixth enum value (`unadjudicated`) was previously added to fix a fail-open branch, and both consumers were widened alongside it.

RELATED: the same report independently recommends OCR-based extraction (pytesseract/ocrmypdf) as the follow-up for its zero-word-baseline directories, which is the same thread as the OCR-tier task -- coordinate if the chosen (b) treatment touches that ground.

=== AMENDED 2026-08-26 (BimodalLogic ingest of goldblatt_1989) ===

DEFECT (c) -- WHEN THE BASELINE *IS* AVAILABLE, IT IS SELF-REFERENTIAL. Defect (b) above establishes that the word-ratio baseline is UNAVAILABLE for 279 of 291 sources/ dirs. This amendment adds the complementary defect: for the 12 dirs where it IS computable, the ratio does not measure what its name implies. `md_words / pdf_words` compares the stored .md against `pdftotext -layout`'s own output of the same PDF -- and when the .md was itself produced by pdftotext (which is exactly what skill-literature's handle_convert does; see the ungated-convert-path task), both sides of the ratio are the SAME EXTRACTION. The ratio is then ~1.0 by construction and carries no information about fidelity to the printed page.

WHAT THE RATIO ACTUALLY MEASURES: truncation of a conversion. What it CANNOT measure: garbling of an OCR text layer. Those are different failure modes and the enum currently conflates them under verified_conversion.

MEASURED ANCHOR CASE. goldblatt_1989 (Goldblatt, "Varieties of Complex Algebras", APAL 44, 1989) was ingested into the corpus on 2026-08-26. Its PDF is a 2001 Acrobat 3.0 Capture scan. Direct inspection of the extraction: math pages yield "{9=, 4s:", "0%", "$m"; headings corrupt ("3.7. Complete varieties" -> "3.7. Complete v&et&s"); the title page renders New Zealand as "New 2Miand"; 295 of 2960 lines carry runs of 3+ consecutive symbols. literature-fidelity-audit.sh --dry-run rates it `verified_conversion` at word_ratio 1.0162. The stamp was deliberately NOT written (--write was not run) and the sub-index entry carries an OPEN hazard instead.

REALIZED DAMAGE ALREADY IN THE CORPUS -- SIX STANDING FALSE STAMPS. A Creator/Producer survey of the 72 corpus PDFs found 7 from scan pipelines (Acrobat Capture / ABBYY FineReader / Acrobat Image Conversion). Six carry verified_conversion at word_ratio ~1.0: burgess_1982 (1.0), burgess_1982_i (1.0982), burgess_1982_ii (1.0705), burgess_1982b (1.0), doets_1989 (1.0), gabbay_1993 (1.0025). burgess_1982 is the source paper of the BX axiom system the BimodalLogic repo formalizes. blackburn_2002 is also a scan (Acrobat 7.0 Image Conversion) and is currently unstamped.

DECISION RECORDED (user, 2026-08-26): do NOT hand-strip those six stamps as a separate data edit. De-certification is an ACCEPTANCE CRITERION OF THIS TASK -- the fixed audit must re-adjudicate them to something other than verified_conversion on its own, which is also the only outcome that proves the fix works. If the fixed audit still rates any of the six verified_conversion, the fix is incomplete.

PRECEDENT THIS RE-REALIZES. The rabinovich_2014 sub-index hazard record already documents this exact failure mode once: "the mis-detection was compounded by index.json falsely certifying the corrupt extract verified_conversion", and it states the stamp must be restored only on a manual spot-check, "never on the automated word-ratio alone". That lesson is written down in prose and nothing enforces it. Whatever treatment (b) receives, (c) requires that verified_conversion stop being reachable from a self-comparison.

WHY (c) BELONGS HERE AND NOT IN A NEW TASK: it is the same function (classify_dir), the same enum, and the same commit's worth of design as (a) and (b) -- the identical no-split reasoning this description already applies to those two.

COORDINATE, DO NOT DUPLICATE: the converter-tier task warns that "scanned/OCR'd is very likely the WRONG class boundary" -- that warning is about TIER SELECTION and does not apply to certification. Using scan-derived-ness to WITHHOLD a verified stamp is not the same claim as using it to CHOOSE a converter, and this task must not be read as reopening that. Detecting the class is separately owned by the OCR-misrecognition-detection task; if that lands first, consume its detector rather than writing a second one.

---

### 102. Characterize converter-tier behavior and correct the falsified universal-remedy claim
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Characterize when the PyMuPDF column-clustering fallback tier actually helps versus hurts, and correct the now-falsified claim that it is the universal remedy for gate rejections. SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/literature/ (the .claude/ tree is a disposable deploy artifact -- see rules/source-store-deploy-boundary.md).

FALSIFIED CLAIM (single, precise edit target). literature_quality_gate.py:238-239 states the correct operator remedy for a gate-rejected document "is reconversion with `LITERATURE_CONVERTER=fallback` (the path already proven for bacon_dorr_2024_classicism)". A grep across the extension confirms this is the ONLY prose location asserting fallback-as-remedy; every other LITERATURE_CONVERTER=pymupdf occurrence is a test invocation in tests/test-literature-convert.sh. The claim is now falsified by direct measurement and must be amended.

TWO ANCHOR CASES WITH OPPOSITE OUTCOMES (both measured through the CURRENT gate; no gate change is needed to reproduce either):
  - savage_1972_foundations-of-statistics: primary tier (pymupdf4llm) 73 sentence-boundary-glue hits, fallback tier 3. Fallback is a dramatic improvement. ALL 73 hits fell in the last 20% of the document; the first 80% was completely clean. Cause: pymupdf4llm misdetects dense bibliographies and back-matter as markdown TABLES and strips inter-word spaces inside the cells, producing runs like "vidence,"pp.112-143inEssayein<br>'HonorofErnestNagel,eds.SidneyMorgenbesser,".
  - joyce_1999_foundations-causal-decision-theory: primary tier 4 hits, fallback tier 5. Fallback is WORSE. The documented remedy is exhausted for this document and does not work.

CENTRAL FINDING TO ESTABLISH -- "scanned/OCR'd" is very likely the WRONG class boundary. Both anchor documents are scanned books, yet they respond to the fallback tier in opposite directions, so scanned-ness cannot be the discriminating variable. Two candidate framings the task must weigh:
  (1) DENSE BACK-MATTER / BIBLIOGRAPHY DENSITY. savage_1972's failure is specifically pymupdf4llm's table misdetection over bibliography regions, and is positionally concentrated (last 20%). This is a document-STRUCTURE variable, not a scan variable.
  (2) OCR VINTAGE / QUALITY. joyce_1999's two genuine glue defects were traced to the ORIGINAL 2019 archive.org OCR text layer, not to the PDF geometry and not to the converter. Re-OCR of the two affected source pages (119, 217) with `ocrmypdf --force-ocr --output-type pdf -l eng` fixed BOTH genuine defects and yielded ZERO [a-z]\.[A-Z] hits on those pages; it additionally recovered a closing curly quote and an accented "Réyni" that the 2019 OCR had dropped entirely (the dropped quote glyph is precisely what produced the zero-space transition). This strongly suggests the real variable is the age/quality of the embedded text layer, which no converter tier can repair.
These two framings are not mutually exclusive and may describe two distinct failure classes needing two distinct responses.

SCOPE DISCIPLINE -- DO NOT AUTO-SELECT A TIER IN THIS TASK. An earlier framing of this work proposed auto-selecting the fallback tier for the "scanned/OCR'd document class". That premise is falsified by joyce_1999 and a naive auto-select would REGRESS documents like it (4 hits -> 5). Establishing the correct class boundary is this task's FINDING, not its premise. Any auto-selection mechanism is downstream of, and gated on, that finding; propose it only if the characterization actually supports a reliable discriminator, and prefer documenting a recommended operator setting over silent automatic behavior if it does not.

DELIVERABLES:
  1. An empirical characterization of when each tier wins, grounded in the two anchor cases plus any additional corpus documents needed to test the two candidate framings.
  2. Amend literature_quality_gate.py:238-239 so it no longer asserts fallback is the universal remedy. State the known counterexample explicitly. NOTE: this line sits inside the same docstring paragraph as the prohibition at lines 236-241 that the glue-check task must reconcile with -- coordinate the wording so the two tasks do not contradict each other. This task narrows only the REMEDY claim; it does NOT narrow the prohibition on widening the exemption.
  3. Document the recommended converter setting per document class in the extension README/context docs.

WHY THIS IS FOUNDATIONAL: the glue-check task's routes (a) re-OCR and (c) distinct calibration class both turn on the class boundary established here, and the OCR-tier task inherits the OCR-vintage finding. Neither can be decided well before this lands.

---

### 100. Close aggregator file scope blind spot
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Close the file_scope blind spot for AGGREGATOR/REGISTRATION files: a task that adds a new module must edit its parent aggregator, which by construction lies outside the new module's own declared path, so the admission gates never see that edit coming.

MIRROR OF THE COARSE-DECLARATION WORK, NOT A DUPLICATE OF IT. The completed task surface_coarse_file_scope_declarations_at_creation addresses declarations that are too BROAD -- a bare directory root swallowing every task in the repo. This is the opposite failure: a declaration that is too NARROW, omitting a file the work provably cannot avoid touching. Both degrade the same admission machinery from opposite directions, and neither fix implies the other. Read that task's resolution before designing this one so the two creation-time checks compose instead of contradicting.

OBSERVED MECHANISM (verified live, do not re-derive). In a seven-task lean4 batch in a separate consumer repo, TWO tasks each edited a module aggregator that appeared nowhere in their declared file_scope:
  - one declared [WeakCanonical/Transfer.lean, BXCanonical/DiscreteCarrierProbe.lean] and additionally edited Metalogic/BXCanonical.lean
  - one declared [Semantics/ShiftSet.lean] and additionally edited Semantics.lean
In both cases the edit was minimal and structurally REQUIRED -- a single `import` line plus a docstring index entry -- without which the newly created module is unreachable from the build. Neither agent did anything wrong: both honestly listed the aggregator in .return-meta.json's modified_files after the fact. The gap is entirely in the PRE-DISPATCH declaration that the admission gate actually consults.

THE CONCRETE HAZARD (why this is not merely cosmetic). orchestrate-batch-admit.sh compares DECLARED file_scope across non-terminal tasks to decide co-dispatch safety. An undeclared aggregator edit is invisible to that comparison. In the observed batch the two tasks happened to touch DIFFERENT aggregators, so nothing collided and the run was clean -- this was luck, not a guarantee. Two tasks that each add a module beneath the SAME parent (entirely ordinary: two new modules under Semantics/) would both be admitted to the same wave, both edit that one aggregator concurrently, and the gate designed to prevent exactly that would stay silent. The failure would surface as a lost import line or a clobbered docstring index, i.e. a task whose module silently stops being built.

NOTE THE ASYMMETRY THAT MAKES THIS DETECTABLE TODAY. modified_files (post-hoc, agent-authored, accurate here) already names the aggregator, while file_scope (pre-dispatch, human/creation-authored) does not. The system therefore already holds both halves of the evidence and never compares them.

CANDIDATE DIRECTIONS (evaluate, do not blindly adopt):
  (a) DETECTION FIRST, cheapest and lowest-risk: at postflight, compare each task's reported modified_files against its declared file_scope and emit an advisory naming any excursion. This is exactly the manual check that caught the observed case. It prevents nothing, but it converts a silent gap into a logged one and would immediately quantify how common aggregator excursions are before anyone designs a preventive rule.
  (b) CREATION TIME: when a declared path names a not-yet-existing module, infer and auto-add its parent aggregator to file_scope. Requires a language-aware notion of "parent aggregator" (Lean's Foo.lean beside Foo/), so scope it per extension rather than pretending it is universal.
  (c) ADMISSION TIME: expand declared scopes to include parent aggregators before running the overlap predicate. Strictly more conservative, and risks re-introducing the over-blocking that the evidence-gated collision narrowing deliberately removed -- weigh against that work rather than reverting it by accident.
Direction (a) is a sound first deliverable on its own and does not commit the design to (b) or (c).

DO NOT "FIX" THIS BY WIDENING DECLARATIONS BY HABIT. Declaring the enclosing directory to be safe would reintroduce precisely the coarse-declaration defect the mirror task exists to prevent. The aggregator is a single named FILE; name it, do not reach for its directory.

ACCEPTANCE: an aggregator edit made outside a task's declared file_scope is no longer silent -- at minimum it is reported against that task; and two tasks adding modules beneath a shared parent aggregator are either serialized or surfaced, demonstrated with a concrete two-task case rather than argued in the abstract.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 94. Wire lit flag through team skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: Wire the --lit flag through the three team skills so literature mode is not silently dropped in team mode. VERIFIED DEFECT (checked directly against the source store at agent-system/, not a deploy artifact): skill-team-research/SKILL.md, skill-team-plan/SKILL.md, and skill-team-implement/SKILL.md contain ZERO references to lit_flag or literature (grep -ci 'lit_flag|literature' returns 0 for all three). Their single-agent counterparts skill-researcher, skill-planner, and skill-implementer return 8 each; the -hard variants return 6 each. None of the three team skills even declares lit_flag in its Input Parameters table (they declare task_number, session_id, team_size, model_flag, effort_flag, and skill-specific fields only).

THIS IS NOT A COMMAND-LAYER BUG. All three commands already pass the flag into team mode: commands/research.md:539 passes lit_flag={lit_flag} in the team-mode args string (line 543 does the same for single-agent), and lines 465-467 parse --lit correctly; commands/plan.md:537 and commands/implement.md:319 do the same for their team-mode dispatches. The command hands the flag over and the skill drops it on the floor. Observed live during a /research N --team --lit run: the flag was accepted, passed to the skill, and did nothing.

REQUIRED FIX: each team skill must execute the canonical literature flow at context/patterns/lit-stage4a-flow.md -- the same shared block skill-researcher imports. See skill-researcher/SKILL.md around lines 153-165 for the exact import prose to mirror: call literature-lit-flag-resolve.sh, branch on all six directives (LIT_DISABLED, SUBINDEX_PRESENT, GLOBAL_MISSING, PROMPT_NEEDED, AUTONOMOUS_GLOBAL, SPARSE_PROMPT_NEEDED), issue the real four-option AskUserQuestion for the two interactive directives (including the 'Search online to ingest' option wired to the STABLE-CONTRACT literature-ingest-online.sh bridge), apply the two-checkpoint sparse re-prompt after 'Use global corpus now', and take the deterministic [lit:auto] autonomous fallback when orchestrator_mode == 'true'. Each team skill must supply the shared block's preconditions: lit_flag, description, and orchestrator_mode.

DESIGN QUESTION THE PLAN MUST DECIDE AND DOCUMENT EXPLICITLY (this is the real work, not the import). Single-agent skills resolve lit_context once and inject it into one agent prompt. Team skills spawn 2-4 teammates via the Agent tool, each with its own prompt and fresh context. Choose among: (a) the lead resolves the briefing ONCE and injects the same lit_context into every teammate prompt; (b) each teammate resolves its own; (c) the lead resolves once and teammates navigate the corpus on demand per context/project/literature/patterns/agent-exploration.md. Option (a) is the likely answer because the interactive AskUserQuestion directives cannot sensibly fire 4x in parallel, but the orchestrator_mode dual-consumer contract in lit-stage4a-flow.md MUST be checked against parallel spawn before committing to it. Whatever is chosen must be stated in prose in each skill file, because the next person will hit the same question. Consider also whether the lead should resolve BEFORE the wave spawns (Stage 5 in skill-team-research) so no teammate starts without the briefing.

STAGE-NUMBER COLLISION TO RESOLVE AS PART OF THIS WORK: skill-team-research/SKILL.md:123 has a stage literally titled 'Stage 4a: Fallback to Single Agent' -- an unrelated stage colliding with the number used by the canonical literature stage (Stage 4a) everywhere else in the system. This is a live source of confusion for anyone implementing this fix. Renumber or retitle the fallback stage; do not introduce a second Stage 4a.

VERIFICATION STEP TO INCLUDE (regression guard): add a lint asserting that every skill reachable from a command that accepts --lit either consumes lit_flag or carries an explicit documented statement of why it does not. Register it wherever the repo's other doc/contract lints are registered (see docs/reference/utility-scripts-inventory.md). This lint is what would have caught the defect.

ACCEPTANCE CRITERION: after implementing in this repo and reloading the agent system into a project repo (via <leader>al), /research N --team --lit must produce a real literature briefing for every teammate rather than silently proceeding as if --lit were absent. This task is independently implementable and independently satisfies that criterion; it is the blocker.

=== ADDENDUM 2026-08-24: DUPLICATE CHECK RESULT, AND THE RELOAD DEPENDENCY ===

DUPLICATE CHECK: a sweep of all 60 active tasks found NOTHING covering the team-skill lit_flag
defect. This task is genuinely new. Its two sibling tasks from the same /meta dispatch did overlap
existing work and were handled: the resolver-keying task was abandoned and absorbed into the
literature global-index schema-unification task, and the coverage-delta task was retargeted to
depend on that same schema task. This task has no such overlap and no dependency on either -- it
is independently implementable and independently satisfies the acceptance criterion, which is the
point of keeping it separate.

RELOAD DEPENDENCY, worth stating because the acceptance criterion runs through it: the criterion
is that /research N --team --lit produces a real briefing for every teammate in a CONSUMING repo,
which requires the fix to be deployed there, not merely committed here. The task covering
postflight deploy gating for source-store tasks documents that completed source-store work can sit
undeployed indefinitely -- and this was observed live during the run that found this defect: the
consuming repo's gate-in emitted "deployed extension 'core' is stale" and "deployed extension
'literature' is stale" warnings in the same session. Verifying this task means regenerating the
consuming repo's .claude/ tree and re-running the command there, not just reading the diff in the
source store. Do not mark it verified on a source-store-only check.

---

### 91. Make update-plan-status.sh diagnose non-conforming Status lines, and settle the trailing-text tolerance policy
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 50

**Description**: update-plan-status.sh reports every non-conforming plan Status line with one generic, undiagnosable message, and hard-fails /orchestrate postflight on a plan shape that a legitimate resume workflow produces. Reported independently by a peer session reviewing a consuming repo (BimodalLogic) and re-derived by execution against the source store on 2026-08-24.

CORRECTION TO THE ORIGINAL FILING. This task previously led with a claim that lines 62/72 compare two EMPTY strings and yield a silent SUCCESS. That is false, and it was verified false by running the script against fixtures for all three malformed shapes. Do not go looking for that path.
  - Line 62's `grep -m1 "^- \*\*Status\*\*:" | sed 's/.*\[\([^]]*\)\].*/\1/'` does NOT return empty on a bracket-less line. grep matches (the `- **Status**:` prefix is present), so `|| echo ""` never fires, and sed's substitution simply does not apply -- so the whole line comes back verbatim as `current_status`. It is non-empty, and it never equals a bare status token, so the equality check cannot pass.
  - Measured outcomes: trailing-text shape -> rc=1; no-brackets shape (target PARTIAL and target COMPLETED alike) -> rc=1; missing-`- `-prefix shape -> rc=1; well-formed change -> rc=0 and correctly stamped. There is no false-success input.
  - Consequently the old acceptance criterion "no input produces an empty-equals-empty pass" was already vacuously satisfied and has been dropped.

WHAT IS ACTUALLY WRONG. Four distinct defects, all confirmed:

1. DIAGNOSTIC OPACITY (the core defect). All three malformed shapes exit 1 with the byte-identical message `Failed to update status in <file>`. It names no line number, quotes no line content, and states no reason. The operator must reverse-engineer which of three different problems occurred.

2. `$`-ANCHOR INTOLERANCE OF TRAILING ANNOTATIONS. Line 69's replacement pattern `s/^- \*\*Status\*\*: \[.*\]$/.../` requires the line to END at the closing bracket. A plan carrying `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` can therefore NEVER be stamped -- the sed is a permanent no-op and every transition on that plan fails. This shape arose from a legitimate resume workflow, which is the argument for tolerating it rather than rejecting it.

3. PREFLIGHT MASKS THE LEADING INDICATOR. update-task-status.sh:515-525 branches fatal-vs-warn on operation. Preflight prints only `Warning: plan file update failed (non-fatal)`, so a malformed Status line survives an entire task and only bites at POSTFLIGHT, where the same failure is `exit 3`. Note carefully: postflight does NOT silently diverge. It fails loudly and calls itself retryable. The "state.json says completed while the plan still reads [IMPLEMENTING], and generate-todo.sh reads only state.json" sentence in the original filing is the code comment's RATIONALE for making postflight fatal, not a description of an undetected outcome. The real cost is a late, expensive failure that a preflight warning already knew about.

4. stdout/rc CONTRACT AMBIGUITY. The script header promises "Outputs: Updated plan file path on success, empty on failure/no-op". The idempotency early-exit (lines 62-66, already-at-target) returns rc=0 with EMPTY stdout -- so stdout alone cannot distinguish success from failure. The sole current caller branches on rc and is unaffected, but commands/implement.md:353 documents a defensive call site, and any future stdout-consuming caller would be misled.

REQUIRED FIX.
(a) Diagnose loudly. On no-match, print the offending line VERBATIM with its line number and state WHICH condition failed: missing `- **Status**:` prefix, missing brackets, or trailing text after the closing bracket. Replace the single generic message with these three distinct ones.
(b) Decide and implement a tolerance policy for trailing text after `]`. Either accept it -- rewriting only the bracketed token and preserving the remainder, which defect 2 argues for -- or reject it explicitly as malformed. Apply the choice consistently and document it in context/formats/plan-format.md, which is where plan format is specified (see its existing line 99 discussion of the three status-mutating scripts).
(c) PRESERVE the deliberate preflight/postflight asymmetry. update-task-status.sh's error text acknowledges it on purpose. The fix is diagnosability, not flipping fatality.

ALSO EVALUATE (evaluate, do not assume).
  - Whether the preflight non-fatal path should emit a one-line operator-visible WARNING naming the malformed line, given that a preflight no-op is the leading indicator of the fatal postflight failure.
  - Whether a plan-format lint should validate the Status line at plan-creation time, so a malformed line never reaches a dispatch.
  - Whether the idempotent-no-op path (defect 4) should echo the plan path rather than empty, making stdout a reliable success signal.

ACCEPTANCE.
  - Each of the three malformed shapes (trailing text, no brackets, missing prefix) produces a DISTINCT, line-numbered diagnostic quoting the offending line.
  - A well-formed plan still stamps correctly, and the already-at-target path stays a no-op.
  - The chosen trailing-text policy is implemented and documented in plan-format.md.
  - Redeploy and confirm the fix survives regeneration (.claude/ is a deploy artifact; the edit target is agent-system/extensions/core/).

PROVENANCE. Originally filed in the BimodalLogic repo and abandoned there on 2026-08-24 because its entire work product lands in this repo -- BimodalLogic's .claude/ is a gitignored deploy artifact wiped on every reload, so the fix was not executable from there. That repo's specs/archive/state.json retains the original description and its specs/PATH.md records the handoff. This entry closes that handoff and supersedes the peer session's request to file a second task.

---

### 90. Adoption lint for shared task lookup helper
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 89, Task 124

**Description**: The largest duplication class in the repo, and it has never been named in any review: the inline task-lookup jq block. 111 files carry a hand-rolled `jq --argjson num ... '.active_projects[] | select(.project_number == $num)'` lookup against specs/state.json, totalling roughly 62,000 duplicated bytes. The canonical helper skill_validate_input() already exists at skill-base.sh:185 and has SIX callers, with ZERO overlap against the 111.

For scale: this single class exceeds the three classes named in the 2026-08-11 review COMBINED (raw git commit -m, session-ID one-liner, jq #1132 block, ~58 KB together).

This is an ADOPTION gap, not a missing-abstraction gap -- the same shape as every other class here. Someone built the helper; nothing held the line. Six classes in this repo have a canonical home and near-zero adoption.

SCOPE: build the adoption lint FIRST, modelled on the corrected single-source gate (correct file-type scope, source-store-deterministic root, restricted to executable surfaces so illustrative prose in docs/ and context/ is not flagged); land it as failing-with-a-known-baseline or fix-then-enforce, whichever convention the gate fix establishes; then migrate the call sites. Migration can be incremental as long as the lint prevents NEW occurrences from day one -- preventing growth matters more than the backlog, since this class grew while unwatched.

ACCEPTANCE: lint rejects a newly introduced inline task-lookup on an executable surface; adopter count rises and duplicate count falls; both numbers recorded so the next review can measure direction rather than re-derive it.

---

### 89. Mode gate literature and distill skills
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 44, Task 87

**Description**: Apply the mode-gated section convention to the two remaining large instances, after the pilot proves it.

skill-literature/SKILL.md, 84,265 B total, 64.5% fenced bash. Seven mutually exclusive mode sections of which exactly ONE fires per invocation: Mode: Rebuild 20,170 | Mode: Convert 17,534 | Mode: Search 10,043 | Mode: Validate 5,989 | Mode: Import Pipeline 5,785 | Mode: Index 5,234 | Mode: Ingest 1,917 = ~65,772 B, 78% of the file. Cleanly '## Mode:'-delimited, so the split is mechanical. Estimated ~14,000 tokens per /literature invocation, taking it from ~46.2k toward ~32k.

skill-distill/SKILL.md, 93,044 B total, only 1.9% bash -- essentially pure prose. `## Auto Distill Complete` is 43,254 B, 46% of the file, and is an OUTPUT TEMPLATE used by --auto alone. It belongs in context/formats/, not in a skill body loaded on every /distill invocation. Estimated ~10,800 tokens per non---auto /distill, taking it from ~42.4k toward ~32k.

Combined estimated saving ~24,800 tokens across the two commands' invocations.

Both carry the same fence-interior heading hazard as the orchestrate application -- '## Mode:' and '## Auto' strings can appear inside fenced examples. Split bottom-up and verify each extracted section round-trips.

ACCEPTANCE: each mode section loads only when its mode is selected; all seven literature modes and both distill paths verified working; measured reductions reported against the 46.2k and 42.4k baselines.

---

### 88. Mode gate skill orchestrate multi task section
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 87, Task 127

**Description**: Apply the mode-gated section convention to the largest single instance in the system. skill-orchestrate/SKILL.md is 188,284 B; its `## Multi-Task Mode` section measures 103,462 B -- 55% of the file -- and is entered ONLY when multi_task_mode=true. Stage 0 states it explicitly: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' Every single-task /orchestrate N therefore loads ~26k tokens of text it will never execute, on the command intended for the longest, most context-hungry runs.

Section breakdown of the file: ## Multi-Task Mode 103,462 (only ~11% bash) | ## Execution Flow 71,570 | ## MUST NOT (Context Flatness) 8,932 | remainder ~2,500.

ESTIMATED SAVING: ~26,000 tokens per single-task /orchestrate invocation, taking its budget from ~83.5k toward ~57k. This is the single largest measured token item in the system and it is a pure move -- the section is self-contained and the branch is already explicit, so no prose rewriting is required.

Secondary, separable lever recorded here so it is not lost: this file carries 5 bash blocks of >=20 lines totalling 39,275 B, and skill-orchestrate-hard carries 9 such blocks totalling 63,892 B. Bash moved into a standalone script costs ZERO context because the script source is never loaded. That is a bigger per-token win than prose extraction and is already the established pattern here (~20 orchestrate-*.sh scripts exist). Do it in a follow-up rather than widening this work.

BEWARE the fence-interior heading trap: naive '^## ' section splitting can match headings inside fenced code blocks and silently truncate. The slim-task-command plan documents this exact hazard and mandates bottom-up extraction so earlier line numbers do not drift. Reuse that approach.

ACCEPTANCE: single-task /orchestrate no longer loads the multi-task section; multi-task /orchestrate still works end to end; measured budget reduction reported against the 83.5k baseline.

---

### 87. Mode gated section loading convention
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Establish the convention that fixes the single largest token lever in the system: MUTUALLY-EXCLUSIVE BRANCH SECTIONS LOADED UNCONDITIONALLY. A skill's SKILL.md body is loaded IN FULL on every invocation -- there is no include, partial, fragment or compose mechanism in install-extension.sh, and deploy is a byte-for-byte copy. Four files carry large sections entered on exactly one branch and skipped on every other invocation:

| File | Dead-branch section | Bytes | Share | Fires when |
| skill-orchestrate/SKILL.md | ## Multi-Task Mode | 103,462 | 55% | multi_task_mode=true only |
| skill-distill/SKILL.md | ## Auto Distill Complete | 43,254 | 46% | --auto only |
| skill-literature/SKILL.md | 7x ## Mode: sections | ~65,772 | 78% | exactly one fires |
| commands/task.md | 5 non-default modes | 25,883 | 66% | one mode per invocation |

Verified in skill-orchestrate Stage 0: 'If multi_task_mode is true: skip Stages 1-8 entirely and proceed to Stage MT-1.' The branches are explicitly exclusive, so every single-task /orchestrate N loads ~26k tokens it will never execute. Measured /orchestrate budget today is ~83.5k tokens before any work begins.

This is ONE architectural defect, not four. This work defines the convention ONLY; the per-file applications are separate tasks so each stays bounded to one agent run. The commands/task.md instance is already owned by the slim-task-command work.

SCOPE: decide the mechanism (a referenced context/ file read on demand when the branch is taken is the established pattern -- moving procedural bash to scripts/ removes it from context entirely, while moving prose to context/ saves only on invocations that do not need it); define the section-marker convention; document it in context/patterns/; and add a lint that flags a runtime-loaded .md carrying a mutually-exclusive branch section above a byte threshold. Without the lint this regresses, exactly as every other extracted-then-readopted class in this repo has.

DO NOT pursue twin-dedup between skill-orchestrate and skill-orchestrate-hard as part of this: the 2026-08-11 review's '>=28,421 B byte-identical' figure did not reproduce. Contiguous identical runs of >=8 lines total only 8,168 B. It is a weak lever and a distraction.

ACCEPTANCE: convention documented, lint in place and green, and one pilot application landed demonstrating the measured saving.

---

### 81. Mechanize task-lock and session-registry heartbeat refresh: liveness timestamps never advance during a multi-phase /implement run
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [081_mechanize_task_lock_and_session_heartbeat_refresh/reports/01_heartbeat-non-execution-root-cause.md]
- **Plan**: [081_mechanize_task_lock_and_session_heartbeat_refresh/plans/01_mechanize-heartbeat-refresh.md]
- **Summary**: [081_mechanize_task_lock_and_session_heartbeat_refresh/summaries/01_mechanize-heartbeat-refresh-summary.md]

**Description**: Task-lock and session-registry heartbeats never fire during a real single-task /implement run. Both liveness timestamps stay frozen at their acquire-time value for the entire run, so every staleness-based consumer sees a healthy, actively-working session as long-dead.

=== OBSERVED LIVE (do not re-derive the observation; DO re-derive the cause) ===

Run: /implement 111 in the PossibleWorlds repo, session sess_1787265639_358e17, PID 263643. The run SUCCEEDED — all 8 plan phases reached [COMPLETED] over ~18 minutes wall clock. Throughout:

- specs/111_verify_interval_twisted_arrow_lemma/.lock/holder.json read acquired_at=2026-08-20T22:40:39Z and heartbeat_at=2026-08-20T22:40:39Z — byte-identical.
- specs/.sessions/sess_1787265639_358e17.json read started_at and heartbeat_at at that same value — byte-identical.
- Both stayed frozen when sampled at 171s and again past the 5-, 7-, and 18-minute marks, while `ps -p 263643` confirmed the process alive and progress/phase-1-progress.json plus successive plan-heading transitions confirmed forward progress.

Eight phase transitions occurred. heartbeat_at never moved once.

=== THE CRUX: THE MECHANISM IS WIRED IN AND STILL DID NOT FIRE ===

This is NOT an absent-caller bug and must not be researched as one. Verified in the source store:

1. agent-system/extensions/core/agents/general-implementation-agent.md, Stage 4D ("Mark Phase Complete"), lines ~279-297, carries BOTH calls adjacently at the phase-transition point:
     bash .claude/scripts/task-lock.sh heartbeat "{task_number}" "{session_id}" 2>/dev/null || true
     bash .claude/scripts/task-lock.sh session-heartbeat "{session_id}" 2>/dev/null || true
   with prose asserting this is "the actual per-phase-transition site for single-task /implement".

2. agent-system/extensions/core/skills/skill-implementer/SKILL.md:217-219 documents that it is a thin wrapper with no phase-transition point of its own, and that the refresh lives in the agent's Stage 4D.

3. agent-system/extensions/core/commands/implement.md:169-183 documents the batch-loop side and states the single-task heartbeat "lives one layer down, inside each dispatched general-implementation-agent.md".

4. agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:2115 goes further and threads the BARE session_id into the dispatch context specifically "because general-implementation-agent's per-phase task-lock.sh heartbeat call presents this exact field's value against holder.json, and a suffixed value would desync the heartbeat from the lock".

5. Routing verified: task_type=formal resolves via command-route-agent.sh to general-implementation-agent (noncore-exact) — the very agent carrying the calls. Not a routing miss to some other implementation agent lacking the hook.

So: the calls exist, routing reaches them, the whole design depends on them, eight transitions occurred, and nothing moved.

=== HYPOTHESES TO INVESTIGATE — DO NOT PRE-COMMIT TO ANY ===

(a) STRUCTURAL. The calls are prose instructions inside a markdown agent definition, not enforced code. An agent may simply not run them and nothing detects the omission. If so the fix is structural: move the refresh into a script the lifecycle mechanically invokes rather than trusting an agent to execute a documented bash snippet. A concrete candidate exists — the SAME Stage 4D block already calls `bash .claude/scripts/update-phase-status.sh "$task_number" "$project_name" "$phase_num" COMPLETED`, which is the one script guaranteed to run at every phase transition. It currently takes no session_id (verified: agent-system/extensions/core/scripts/update-phase-status.sh accepts exactly 4 positional args and contains no session/SESSION reference), so mechanizing there requires threading session_id in. Weigh that against alternatives (skill-base.sh, a lifecycle hook) rather than assuming it.

(b) SILENT FAILURE. The calls ran but failed. Both use `2>/dev/null || true` — the same silence-on-failure idiom filed in the empty-block-reason task. Any of these would be indistinguishable from success:
    - Unsubstituted `{task_number}` / `{session_id}` placeholders. Note that the agent file uses BRACE-placeholder form while skill-orchestrate/SKILL.md:313,318 uses shell-variable form `"$task_number"` / `"$session_id"` for the identical calls. Determine whether substitution actually happens in the agent's rendered prompt.
    - The RELATIVE path `.claude/scripts/task-lock.sh`. Agent threads reset cwd between bash calls; a non-repo-root cwd makes every invocation a silent no-op.
    - Argument-order or subcommand mismatch.
   Check placeholder substitution and cwd empirically before anything else.

(c) FALLBACK PATH. Stage 4D offers an Edit-tool fallback for the phase heading "if the script is unavailable". Determine whether that path was taken and whether it bypasses the heartbeat site.

(d) CONDITIONAL NO-OP IN cmd_heartbeat ITSELF. Verified: cmd_heartbeat (agent-system/extensions/core/scripts/task-lock.sh:831) returns 0 WITHOUT writing in two cases — no lock directory/holder.json, and holder session_id mismatching the passed session_id — emitting only a WARN to stderr, which `2>/dev/null` discards. A session_id desync (exactly what skill-orchestrate:2115 warns about) produces a silent successful-looking no-op. cmd_session_heartbeat (line 1283) has the same never-blocks contract.

=== WHY THIS OUTRANKS A COSMETIC METADATA BUG ===

Verified consumer behavior in agent-system/extensions/core/scripts/task-lock.sh:

- TASK_LOCK_STALE_MIN defaults to 30 (line 206). cmd_acquire's stale-override path (~lines 730-740) compares heartbeat age against it and, when exceeded, prints "WARN: ... lock is stale ... overriding and acquiring" and TAKES THE LOCK. A frozen heartbeat means any /implement run exceeding 30 minutes has its lock broken out from under a live implementer mid-edit.
- TASK_LOCK_REAP_MIN defaults to TASK_LOCK_STALE_MIN * 4 = 120 (line 214). cmd_reap (line ~950) `rm -rf`s any lock whose heartbeat age exceeds it.
- cmd_check returns exit 2 for "held, stale (heartbeat older than the threshold)" (documented contract, line 117), so every downstream staleness consumer reads a live session as dead.
- The overlap-scan path at ~lines 656-666 also decides on heartbeat age, printing "proceeding without modifying it" for a lock it deems stale.

The observed 18-minute run stayed under the 30-minute threshold, so nothing actually broke THIS time. That is the honest severity: this is a live latent hazard whose blast radius scales with run length, not an already-fired incident. Establish empirically whether any long-running command has crossed 30 minutes in practice — that sets true severity.

It also misleads operators. The human running this session twice nearly concluded the implementer had died from these fields, and was corrected only by `ps` and the progress directory. A liveness field that is wrong in the "looks dead" direction is worse than no field at all.

=== DEFENSE IN DEPTH: THE TASK LOCK CANNOT CHECK LIVENESS AT ALL ===

Independent of the root cause, there is a verified asymmetry between the two registries:

- The SESSION registry records a pid. write_session_entry (task-lock.sh:471-484) persists pid and pid_source, resolve_session_pid (line ~424) does a bounded ancestor walk for the nearest "claude" process, and session-reap's dead-pid shortcut is additionally floored by a dead-pid-minutes constant (lines 225-231) so it can never fire against a recently-heartbeated entry. That reaper is already defensive.
- The TASK lock records NO pid. write_holder (task-lock.sh:298, 319-321) persists exactly seven fields — session_id, task_number, operation, acquired_at, heartbeat_at, command — and pid is not among them. cmd_reap and cmd_acquire's stale-override therefore have NOTHING but the timestamp to go on, and cannot refuse to act against a live process even in principle.

Consider adding a pid (and pid_source) to holder.json and making both the task-lock reaper and the stale-override path fail safe: refuse to reap or override a lock whose recorded pid is alive, mirroring the floor already applied on the session side. This is worth doing whatever the heartbeat root cause turns out to be, because the reaper acting on a bad timestamp is where the real damage occurs.

=== DETECTABLE FINGERPRINT ===

`acquired_at == heartbeat_at` after N minutes is a reliable fingerprint of "never heartbeated once", distinct from "heartbeated then went quiet". Consider surfacing it as its own diagnostic signal (in `check`, in the reap dry-run output, or in a health probe) rather than letting the two failure modes look identical.

=== SURVEY REQUIREMENT — DO NOT SPOT-FIX ONE CALL SITE ===

Audit every heartbeat call site for the same problem and determine which, if any, demonstrably fire:
- agent-system/extensions/core/agents/general-implementation-agent.md Stage 4D (lines ~283, 296) — the site observed failing.
- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md lines ~313, ~318, ~1518 — same snippets, same `2>/dev/null || true` silence idiom, shell-variable placeholder form.
- agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md — check for the same pattern.
- agent-system/extensions/core/commands/implement.md lines ~169-183 — documents the multi-task expectation and an intentional omission of an intra-batch session heartbeat; verify that reasoning still holds once the root cause is known.
Also check the hard-mode implementation agent for the same block.

=== DESIGN QUESTIONS TO SETTLE IN RESEARCH (directions, not decisions) ===

1. Does heartbeat refresh belong in agent prose AT ALL? Argue it explicitly. If a documented bash snippet in a markdown agent definition cannot be relied on to execute, every other best-effort snippet in that file is equally suspect and this is a systemic finding, not a local one.
2. If mechanized at a lifecycle call site, WHICH one, and how does session_id reach it? Name the threading path concretely.
3. Should these calls stay silent? `2>/dev/null || true` is correct for "never block phase progression" but it is exactly what made this undiagnosable for eight consecutive transitions. Separate "never block" from "never report" — a heartbeat that no-ops because of a session mismatch is a real defect signal being thrown away.

=== SECOND FINDING, SAME TELEMETRY-INTEGRITY THEME (decide placement in research) ===

specs/events.jsonl recorded three subagent_stop events attributed to session_id sess_1787265639_358e17 (the implementer) that carry cc_session_id 08ebe7c9-f020-45bc-bce1-0eea931247e6 — a DIFFERENT Claude session's agents. Foreign stops are logged under the marker owner's session_id because of the `head -1` arbitrary-marker mis-selection in subagent-postflight.sh, so the event record is falsified and post-hoc telemetry misattributes work between sessions. Verified in the live events.jsonl.

Decide during research whether this belongs here or as an amendment to the existing subagent-postflight marker-ownership/correlation task, which already owns the `head -1` selection defect. Default expectation: it is a CONSEQUENCE of that defect and should amend that task's acceptance criteria (the fix must be shown to correct event attribution, not merely marker selection). Do not fix it here without recording that decision.

=== RELATIONSHIP TO ADJACENT TASKS ===

Cross-reference only; no file_scope overlap was found and no hard dependency is declared:
- The subagent-postflight marker-ownership/correlation task and the empty-block-reason task both live in agent-system/extensions/core/hooks/, which this task does not touch. The empty-block-reason task shares only the `2>/dev/null` silence-idiom THEME with hypothesis (b) — cross-reference, do not merge.
If research finds this task must edit a file in either of those tasks' file_scope, declare the dependency then rather than assuming it now.

=== ACCEPTANCE CRITERIA ===

1. The root cause is established EMPIRICALLY, not argued from the source. A reproduction is recorded: run a multi-phase /implement, sample holder.json and the session registry entry across at least two phase transitions, and show heartbeat_at advancing. A fix that cannot be demonstrated against a real multi-phase run does not satisfy this criterion.
2. After the fix, both specs/{NNN}_{slug}/.lock/holder.json and specs/.sessions/{session_id}.json show heartbeat_at strictly greater than acquired_at / started_at, and advancing, within a single multi-phase /implement run.
3. The refresh survives the failure mode identified in research — if the cause is that agent prose is not executed, the fix is NOT more prose. State in the plan which mechanism guarantees execution and why it cannot be skipped.
4. A heartbeat call that no-ops (missing lock, session mismatch, unresolvable task dir) leaves a recorded trace an operator can find after the fact, without making the call blocking.
5. The call-site survey above is complete: every listed site is either demonstrated to fire, fixed, or documented as deliberately absent with the reason.
6. Either holder.json carries pid liveness information and both cmd_reap and cmd_acquire's stale-override refuse to act against a live process, or the decision not to add it is recorded with an argument for why timestamp-only reaping is acceptable for task locks when it was explicitly judged unacceptable for session entries.
7. The `acquired_at == heartbeat_at` never-heartbeated fingerprint is either surfaced as a distinct diagnostic or explicitly rejected with a reason.
8. The events.jsonl cross-session attribution finding is resolved to a definite home: fixed here, or filed as a recorded amendment to the marker-ownership task.

=== BINDING RULES ===

SOURCE-STORE RULE: edits target agent-system/extensions/**, never the deployed .claude/** tree, a disposable deploy artifact regenerated from the source store.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 76. Close task-type-keyed hook gap for non-latex agents that compile .tex
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Close the coverage gap that the latex-extension wiring cannot reach: agents that compile .tex files under a task type OTHER than `latex` currently get no build-guard protection at all, because the extension hook mechanism is keyed on task_type.

DEPENDS ON the core guard script task. This task is NOT redundant with the latex-extension wiring task -- it covers a disjoint set of dispatches, and skipping it would leave the exact incident that prompted this work uncovered.

THE GAP, VERIFIED PRECISELY. `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves which extension's hooks to run by calling `skill_get_extension_dir "$task_type"`, which maps a task type to `.claude/extensions/<ext_name>`. It then reads `.hooks[<stage>]` from THAT extension's manifest. Consequence: a preflight hook declared in the latex manifest fires if and only if `task_type == "latex"`. It never fires for any other task type. Additionally, when no extension matches the task type, `skill_get_extension_dir` returns empty and the function returns 0 immediately -- so core-typed tasks (`general`, `meta`, `markdown`) run NO lifecycle hooks whatsoever, from any extension.

WHY THIS MATTERS CONCRETELY. `agent-system/extensions/formal/manifest.json` routes ALL of `formal`, `formal:logic`, `formal:math`, and `formal:physics` implement operations to `skill-implementer` / `general-implementation-agent`. Philosophy and logic paper repositories are precisely where .tex files live, and `formal`-typed paper tasks are a normal, expected shape. The formal manifest declares NO top-level `hooks` object at all (verified: `.hooks` is null, `provides.scripts` is an empty array). So a `formal`-typed task that builds a .tex file receives zero protection from a latex-extension-only fix. The user flagged this explicitly: a latex-extension-only fix would not have covered the live incident that prompted this work. The same reasoning applies to `general`-typed tasks that happen to touch LaTeX.

DECISION TO MAKE -- WHERE THE UNCONDITIONAL PATH LIVES. Two structurally different options; choose one and record why:

  (i) AGENT-CONTRACT MANDATE. Add the guard obligation to `agent-system/extensions/core/agents/general-implementation-agent.md` and its twin `general-implementation-hard-agent.md`: before running any `pdflatex`/`latexmk` invocation, run the shared guard. Cheap, no harness change, and it composes with the "detect and refuse" mechanism (a contract can refuse; a non-blocking hook cannot). Weakness: it is instruction text an agent may skip, and it must be duplicated across the two twins.

  (ii) CORE-LEVEL UNCONDITIONAL CHECK. Add a task-type-independent guard invocation into `skill-base.sh` itself, running regardless of extension. Strongest coverage, and it survives agents ignoring instructions. Weaknesses: it touches the shared lifecycle spine that every skill in every repository depends on; it would run for every task type including ones that never touch LaTeX (mitigated if the guard is cheap and silent when no .tex conflict exists -- an explicit acceptance requirement of the core guard task); and, because hook/preflight failures are deliberately non-blocking, it still cannot ENFORCE a refusal on its own.

  A defensible outcome is BOTH: (ii) for detection and reporting, (i) for the refusal obligation. The user's framing invites exactly this ("the latex extension, a shared preflight hook, or both"). Do not silently pick the cheaper option without recording the tradeoff.

  A third possibility worth evaluating and rejecting explicitly: giving the formal extension its own preflight hook that delegates to the shared guard. This closes the `formal` case specifically but leaves `general`/`meta`/`markdown` uncovered and does not generalize -- it invites one hook per extension forever.

TWIN-FILE DISCIPLINE (binding). If option (i) is chosen, `general-implementation-agent.md` and `general-implementation-hard-agent.md` MUST be edited together in this task. A one-sided edit between engine twins is a known recurring defect class in this system. Do not assume the two files are line-symmetric; locate each site by content.

BLAST-RADIUS WARNING. If option (ii) is chosen, `skill-base.sh` is the shared lifecycle spine sourced by essentially every skill and deployed to roughly ten repositories. Changes there must be additive, must not alter existing hook ordering or the existing non-blocking semantics, and must be exercised against `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`, which already covers the hook-invocation contract.

FILE-SCOPE NOTE. This task's scope includes `agent-system/extensions/core/scripts/skill-base.sh`, which falls under the `agent-system/extensions/core/scripts/**` scope of the prerequisite core-guard task. That overlap is already serialized by the declared dependency, so no additional ordering constraint is needed -- but the two tasks must not be run concurrently.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**` (and `agent-system/extensions/formal/**` only if the rejected third option is nonetheless adopted). Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a task-type-independent path exists by which an agent about to compile a .tex file consults the shared guard, demonstrably covering `formal`-typed and `general`-typed tasks; the (i)/(ii)/both decision is recorded with reasons, and the rejected per-extension-hook option is explicitly rejected in writing; if agent contracts were edited, both twins carry equivalent obligations; if `skill-base.sh` was edited, the change is additive, preserves existing hook ordering and non-blocking semantics, and the lifecycle test suite passes; no `.claude/**` file is modified.

---

### 75. Wire build guard into latex extension preflight hook and agent contracts
- **Effort**: 2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 74

**Description**: Wire the shared LaTeX build guard into the latex extension's lifecycle and contracts, so that `latex`-typed research and implementation dispatches detect (and, per the chosen mechanism, stop) a competing vimtex continuous build before the agent runs its own.

DEPENDS ON the core guard script task: this task consumes the script and its chosen mechanism, and must not re-litigate the mechanism decision.

HOOK MECHANISM (verified). `skill_run_extension_hook()` in `agent-system/extensions/core/scripts/skill-base.sh` (lines ~89-126) dispatches four lifecycle stages -- preflight, context_injection, verification, postflight -- to a script named in the extension's manifest under a TOP-LEVEL `hooks` object. This is distinct from `provides.hooks`, which is a file-copy target list; do not confuse the two. The preflight hook is invoked from `skill_preflight_update()` (line ~225) AFTER the status update. Hooks are non-blocking by design: a non-zero exit is caught and downgraded to a `[skill-base] WARNING` line, and execution continues. THIS IS A REAL CONSTRAINT ON THIS TASK -- if the chosen mechanism is "detect and refuse", a preflight hook CANNOT enforce the refusal on its own, because the harness ignores its exit code. In that case the refusal must additionally be carried in the agent contract text (the agent declines to build), with the hook serving as the detector and reporter. Resolve this explicitly rather than assuming a non-zero exit will stop anything.

REFERENCE IMPLEMENTATION. `agent-system/extensions/nix/scripts/nix-preflight.sh` is the only existing preflight hook in the source store and shows the exact contract: five positional args (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), `set -euo pipefail`, warnings to stderr, and `exit 0` even when warnings fired. The nix manifest declares it as `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`. Only two extensions (nix, nvim) declare top-level hooks today, so this is a lightly-trodden path -- read both before writing.

DELIVERABLES.
  1. A new `agent-system/extensions/latex/scripts/` directory (it does NOT exist yet -- latex's `provides.scripts` is currently an empty array) containing a preflight hook that calls the shared core guard. The hook should be a thin adapter, not a reimplementation.
  2. `agent-system/extensions/latex/manifest.json`: add the top-level `hooks` object (preflight, and postflight if the restore/report decision requires it), and add the new script(s) to `provides.scripts`. Note the manifest currently has `"hooks": []` nested inside `provides` -- the new object is a SIBLING of `provides`, not a replacement for that field.
  3. `agent-system/extensions/latex/agents/latex-implementation-agent.md`: the build guidance is concentrated at lines ~38-62 ("Build Tools (via Bash)", listing `pdflatex`, `latexmk -pdf`, `latexmk -c`, with worked multi-pass examples) and recurs at lines ~97, ~134, and ~175 as bare build instructions. Line numbers verified at task-creation time and may drift; locate by content. Add the guard obligation, and add a MUST NOT item against running a build without first invoking the guard -- MUST NOT is the strongest lever these contracts have, and advisory prose buried mid-file is what gets skipped.
  4. `agent-system/extensions/latex/rules/latex.md`: the build-command block at lines ~74-93 presents `pdflatex`/`latexmk -pdf` with no concurrency caveat. Point it at the guard.
  5. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`: add a build-coordination section. This file already has "Automated Build", "Using latexmk", and ".latexmkrc Configuration" sections (lines ~46-60) that discuss latexmk without mentioning the watcher conflict, so it is the natural anchor. Per this extension's convention, put the explanatory prose HERE ONCE and have the agent/rules files reference it by path rather than restating it.

NO -HARD TWIN. Unlike the lean extension, latex declares no `routing_hard`/`routing_agents_hard` block and has no `-hard` agent variants, so there is no twin-file discipline burden here. `latex-research-agent.md` is a lighter touch -- research dispatches rarely build, but should not be silently exempt if the hook is manifest-level (the hook fires for ALL latex-typed operations, research included, since `operation` is only passed as an argument, not filtered on). Decide whether the hook self-filters on the `operation` argument.

SCOPE BOUNDARY. This task covers `latex`-TYPED tasks only. Coverage for agents that build .tex files under other task types is a separate task and must not be absorbed here.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/latex/**`. Never edit a deployed `.claude/**` tree.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: a latex preflight hook exists, is executable, is declared in the manifest's top-level `hooks` object, and is listed in `provides.scripts`; it delegates to the shared core guard rather than duplicating detection logic; the agent, rules, and compilation-guide files carry the obligation with prose stated once in compilation-guide.md and referenced elsewhere; the non-blocking-hook constraint is explicitly resolved (either the mechanism does not need enforcement, or the enforcement is carried in contract text); the operation-filtering decision is recorded; no `.claude/**` file is modified.

---

### 74. Add shared LaTeX build-conflict guard script (detect competing vimtex latexmk -pvc)
- **Effort**: 3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 130

**Description**: Build a shared, task-type-agnostic guard script that detects a user-owned LaTeX continuous-build watcher (`latexmk -pvc`, typically driven by nvim's vimtex plugin) competing for the same .tex target an agent is about to build, and that can report, stop, and restore it. This task delivers the MECHANISM only; wiring it into lifecycle stages is handled by the two dependent tasks.

PROBLEM (observed live, not hypothetical). An agent ran `latexmk -pdf possible_worlds.tex` in a paper repo while the user's nvim vimtex continuous-mode compile was watching the same file. The two builds raced and corrupted aux files (null bytes, `^^@`). The failure mode is already documented in that repo's own CLAUDE.md under "Build Workflow: Preventing Aux File Corruption" -- but that documentation instructs a HUMAN to run `:VimtexStop` by hand. Nothing in the agent system detects, prevents, or even warns about it, so the user must notice and intervene manually every time an agent begins LaTeX work.

WHY THE EXISTING DEBOUNCE DOES NOT COVER THIS. The paper repo carries a `.latexmkrc` with `$sleep_time = 5` and a `$compiling_cmd` that pre-scans `build/*.aux` for null bytes and unlinks corrupted files. NOTE TWO CORRECTIONS TO THE ORIGINATING PROMPT, both verified at task-creation time: the file is at `JPL/.latexmkrc`, NOT the repo root; and the value is `$sleep_time = 5`, NOT the `2` that repo's CLAUDE.md claims (that CLAUDE.md is stale on this point -- do not propagate the wrong number). More importantly, `$sleep_time` debounces the file watcher WITHIN a single latexmk instance. It provides no coordination whatsoever between two SEPARATE latexmk processes, which is precisely the race here. The `$compiling_cmd` null-byte sweep is a post-hoc corruption cleanup, not prevention. Neither existing mechanism can solve this; a new one is required.

MECHANISM DECISION -- THIS IS THE CORE RESEARCH QUESTION. An agent cannot invoke a Vim command directly, so the shutdown path is non-obvious. Three candidates, to be evaluated and one (or a documented layering) chosen:

  (a) PROCESS TERMINATION. Detect a running `latexmk -pvc` whose target resolves to the .tex file about to be built, and SIGTERM it. Most reliable, most destructive -- it kills a process the user owns, and vimtex's own state will not know its child died, potentially leaving the plugin's status display stale or its callback machinery confused.

  (b) EDITOR REMOTE CONTROL. Use `nvim --server <socket> --remote-expr` (or `--remote-send`) against the live nvim instance to invoke VimtexStop. VERIFIED FEASIBLE IN THIS ENVIRONMENT: four live sockets were present at task-creation time under `/run/user/1000/` in the form `nvim.<PID>.0` (XDG_RUNTIME_DIR). This is the only option that leaves vimtex's internal state consistent, because vimtex itself performs the stop. Costs: it requires mapping socket -> the nvim instance that actually owns the target buffer (a socket exists per nvim instance, and most of them will be unrelated); `--remote-expr` executes arbitrary expressions in the user's editor, which is a real side effect deserving explicit justification; and it depends on vimtex being loaded in that instance.

  (c) DETECT AND REFUSE. Detect the conflict and emit a clear, actionable message -- naming the PID, the target file, and the exact `:VimtexStop` remedy -- then either warn-and-continue or refuse to build. Zero side effects on user-owned processes and zero remote editor control. The user's explicit steer is to PREFER THE LEAST DESTRUCTIVE OPTION THAT RELIABLY PREVENTS THE RACE, and to weigh killing a user process or driving their editor remotely against simply refusing with a clear message. Research should take that steer seriously rather than defaulting to (a) because it is easiest to implement. A defensible outcome is (b) with (c) as fallback when no owning socket can be identified, or (c) alone.

RESTORE-VS-REPORT DECISION. Also decide whether the agent restores continuous mode on exit or merely reports that it stopped it. The user's stated position: an agent that silently leaves the user's watch mode off is its own (smaller) annoyance. At minimum, whatever is stopped must be REPORTED. Restoration is materially easier under mechanism (b) (re-invoke VimtexCompile over the same socket) than under (a) (the script would have to reconstruct and relaunch a latexmk invocation it did not create -- generally a bad idea). Note that this decision is coupled to the mechanism decision and should not be made independently of it.

REUSABLE PATTERN -- `agent-system/extensions/core/scripts/claude-refresh.sh`. That script already solves the hard parts of safe process handling and should be read before writing anything new. It takes a single atomic `ps -eo` snapshot per invocation rather than re-querying live; it applies exclusion regexes so the script can never target itself or its own ancestry; it gates destructive action behind an explicit `--force` (the calling skill handles confirmation separately); and it escalates SIGTERM (`kill -15`) -> liveness recheck (`kill -0`) -> SIGKILL (`kill -9`) rather than killing outright.

SELF-MATCH HAZARD (verified concretely, do not skip). During task creation, a plain `pgrep -af latexmk` returned exactly one "match" -- the task-creating agent's OWN bash wrapper command, whose argv merely CONTAINED the string `latexmk`. A naive detector would therefore report a phantom conflict, and under mechanism (a) would attempt to kill the agent's own shell. Detection must match on the actual executable and its `-pvc` flag, resolve the build target, and exclude self/ancestry, exactly as claude-refresh.sh does. This is not a theoretical edge case; it fired on the first probe.

DELIVERABLE. A new executable script under `agent-system/extensions/core/scripts/` (suggested name `latex-build-guard.sh`; final name to be fixed during planning). Placement in CORE, not in the latex extension, is DELIBERATE and load-bearing: the two dependent tasks show that non-latex-typed tasks also run LaTeX builds, so the mechanism cannot live behind the latex extension's task-type gate. Suggested subcommand shape (refine during planning): a `detect` mode that reports conflicts and exits non-zero, a `stop` mode implementing the chosen mechanism, and a `restore`/`report` mode for the exit path. Modes should be separable so callers can adopt detect-only first.

The script must be registered in `agent-system/extensions/core/manifest.json` under `provides.scripts` alongside the ~124 existing entries so it is deployed.

SOURCE-STORE RULE (binding): all edits target `agent-system/extensions/core/**`. Never edit a deployed `.claude/**` tree -- those are disposable artifacts regenerated on reload, so such an edit silently vanishes.
DELIVERABLE RULE (binding): no task-number references in any file outside specs/.

ACCEPTANCE: the script exists, is executable, and is registered in core's `provides.scripts`; the chosen mechanism is implemented and the rejected candidates are recorded WITH REASONS in the task's artifacts; detection correctly distinguishes a real `latexmk -pvc` on the target .tex from a process whose argv merely contains the string, and never matches itself or its own ancestry; the restore-vs-report decision is recorded and implemented; whatever the script stops is always reported to the user; the script is safe and silent (exit 0, no output) when no conflict exists, since it will run on every applicable build.

---

### 73. Correlate subagent postflight hook to marker owning session
- **Effort**: 3h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 122

**Description**: RESCOPE NOTE (task-116 audit, verdict RESCOPE). Same A5 team-mode fold as the sibling teammate-return-meta-write-conflict task: this defect (SubagentStop marker correlation) survives the fold and must be re-expressed against the new shared fan-out stage's own session-correlation logic, built by task 122 (build_team_mode_fanout_stage), rather than against the current per-skill postflight-marker convention. Retarget once task 122 lands. Original description follows.\n\nThe SubagentStop postflight hook picks an arbitrary .postflight-pending marker with no correlation to the session that owns it. In a team run, teammate stops burn the orchestrator's continuation budget and can delete the orchestrator's marker mid-run, silently removing the premature-termination guard.

VERIFIED MECHANISM (do not re-derive), file agent-system/extensions/core/hooks/subagent-postflight.sh:
- find_marker() runs `find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1`. It takes the FIRST marker found anywhere under specs/, with no correlation to which session or agent is stopping. The marker's own JSON carries a session_id field (written by skill_create_postflight_marker in agent-system/extensions/core/scripts/skill-base.sh) which the hook never reads.
- The hook is registered as a SubagentStop hook (agent-system/extensions/core/root-files/settings.json), so it fires when ANY subagent stops, including a teammate spawned by a team skill, which has no postflight obligation of its own.
- check_loop_guard() increments $TASK_DIR/.postflight-loop-guard on every such firing. MAX_CONTINUATIONS=3. On reaching the cap it executes `rm -f "$LOOP_GUARD_FILE"; rm -f "$MARKER_FILE"` and allows the stop.

CONSEQUENCE: in a team run, each teammate stop burns one continuation from the ORCHESTRATOR's budget for a marker the teammate does not own. With team_size=4 the cap is reached by teammate stops alone, and the hook then DELETES the orchestrator's .postflight-pending marker. The premature-termination guard is removed without postflight having run.

OBSERVED (live team run, skill-team-research, 4 teammates): a teammate reported the loop guard had reached 3 (MAX_CONTINUATIONS) purely from its own stop attempts, and warned the orchestrator its marker was about to be deleted. In that instance the orchestrator's postflight had already completed so nothing was lost, but that was timing luck, not design. Had synthesis taken longer, the marker would have been deleted mid-run.

THE FAILURE IS SILENT AND LEAVES NO DISTINGUISHING TRACE: skill_cleanup's normal path also removes the marker, so after the fact there is no way to tell a hook-deleted marker from a properly-completed one.

WORK: correlate the hook to the marker it is actually responsible for. Directions to evaluate, do not pre-commit:
(a) read session_id out of the marker JSON and compare against the stopping subagent's session before counting or deleting anything;
(b) have team skills suppress or scope this hook for teammate subagents;
(c) make the loop guard per-session rather than per-task-directory so a teammate's stops cannot consume the orchestrator's budget;
(d) distinguish "cap reached" from "postflight done" so the silent-deletion path is at minimum observable. log_debug already writes .agent-logs/subagent-postflight.log; decide whether that is sufficient or whether the deletion should record a system defect.

ALSO REQUIRED: reconsider whether `head -1` over a repo-wide glob is ever correct. With concurrent tasks in flight there can be several markers and the hook currently picks an arbitrary one, so the defect is not confined to team mode.

RELATED BUT DISTINCT: task 17 fix_return_meta_lifecycle_ordering (COMPLETED) touched skill_cleanup's deletion of .postflight-pending / .postflight-loop-guard / .return-meta.json, but addressed the ordering of the return-metadata read, not marker ownership or hook correlation.

FILE-SCOPE OVERLAP: this task and the teammate return-meta write-conflict task both touch the three skill-team-* SKILL.md files. Sequence them rather than running them concurrently.

ACCEPTANCE: a teammate subagent stopping during a team run does not increment the orchestrator's loop-guard counter and cannot delete a marker it does not own; a genuine cap-reached deletion is distinguishable in the log (or by whatever mechanism is chosen) from a normal skill_cleanup removal; marker selection is correlated rather than `head -1` arbitrary when multiple markers exist.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

AMENDMENT (recorded during a related task's research/implementation, cross-referenced only --
no file_scope overlap, this task's own scope is unchanged and agent-system/extensions/core/hooks/**
was not touched by that other task): the fix's correctness criterion must be shown to correct
EVENT ATTRIBUTION in specs/events.jsonl, not merely marker selection. Live events.jsonl was
observed to carry three subagent_stop events attributed to session_id
sess_1787265639_358e17 (the implementer) that actually carry cc_session_id
08ebe7c9-f020-45bc-bce1-0eea931247e6 -- a DIFFERENT Claude session's agents. Foreign stops are
logged under the marker owner's session_id as a direct consequence of the `head -1`
arbitrary-marker mis-selection this task already owns, so the event record is falsified and
post-hoc telemetry misattributes work between sessions. ACCEPTANCE (additional criterion): once
marker selection is corrected, demonstrate that a foreign subagent's stop event in
specs/events.jsonl is no longer attributed to another session's session_id -- i.e. verify the
downstream event-attribution consequence is resolved, not only the marker-selection mechanism
in isolation.

---

### 72. Fix teammate return-meta write conflict in team mode
- **Effort**: 4h
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 122

**Description**: RESCOPE NOTE (task-116 audit, verdict RESCOPE). The team-mode fold (specs/116_core_agent_system_consolidation/reports/03_target-state-design.md A5) preserves teammate capability but collapses skill-team-research/skill-team-plan/skill-team-implement into a single shared fan-out stage inside skill-orchestrate/SKILL.md, built by task 122 (build_team_mode_fanout_stage). This defect survives the fold unchanged and must be fixed against that NEW shared stage, not against the three separate team-skill files named below -- retarget the fix location accordingly once task 122 lands. Original description follows.\n\nTeammate agents spawned by team-mode skills write the skill-level .return-meta.json, clobbering the record the team skill is supposed to own. The surviving record is an arbitrary teammate's, is the wrong shape for a skill-level return, and can publish a terminal status while the operation is still running.

VERIFIED MECHANISM (do not re-derive):
skill-team-research/SKILL.md Stage 11 specifies that THE SKILL writes a single specs/{NNN}_{SLUG}/.return-meta.json for the whole team run, carrying the team_execution block (teammates_spawned/completed/failed), teammate_results, and synthesis conflict counts. A teammate's only deliverable is reports/{RR}_teammate-{letter}-findings.md, which the skill collects by glob. Teammates have no postflight step and are not supposed to write .return-meta.json at all.

But 63 agent definition files under agent-system/extensions/*/agents/*.md instruct writing specs/{NNN}_{SLUG}/.return-meta.json unconditionally. Confirmed example: agent-system/extensions/formal/agents/math-research-agent.md line 131 ("Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`") and line 326 ("Always write final metadata to ..."). Only 8 of those 63 agent files mention team mode at all (grep for team_mode|teammate_letter|skill-team), and math-research-agent is not among them. There is no team-mode carve-out anywhere in the agent definitions.

OBSERVED (live team run, skill-team-research, 4 teammates): a teammate spawned as math-research-agent wrote .return-meta.json TWICE. Mid-run the file read {"status":"researching","metadata":{"teammate":"b"}}; its second write replaced it with {"status":"researched", artifacts:[its own findings .md], next_steps:"Synthesis with teammate A findings", metadata:{agent_type:"math-research-agent","teammate":"b","findings_count":13}}. That is a single teammate's record occupying the slot reserved for the whole operation's return.

IMPACT:
(a) With N teammates racing, last-writer-wins and the surviving record is an arbitrary teammate's, not the team's.
(b) The shape is wrong for a skill-level return (no team_execution block), so the command-gate-out.sh consumer reads a well-formed but semantically false record.
(c) A teammate finishing before its siblings publishes status "researched" while the operation is still running. If the orchestrator or gate-out read it at that moment it would report the operation complete early. In the observed run the orchestrator overwrote it wholesale at postflight so no damage persisted, but that depended on the orchestrator noticing.

SECOND SYMPTOM, SAME ROOT CAUSE: a teammate spawned as formal-research-agent avoided the collision by inventing its own path .return-meta-teammate-d.json and committing it. That is a non-schema file no consumer reads. Two teammates given the same instruction chose two different wrong behaviors, which indicates the instruction is genuinely ambiguous under team mode rather than simply ignored.

WORK: decide ONE direction and apply it uniformly. Candidate directions to evaluate, do not pre-commit:
(a) add an explicit team-mode carve-out to the shared agent-definition boilerplate so a teammate writes only its findings file;
(b) give teammates a per-teammate metadata path the skill actually reads and merges (this would also make .return-meta-teammate-{letter}.json legitimate rather than stray, and must then be reconciled with the placement question owned by task 51 move_session_state_files_out_of_specs_root);
(c) have skill-team-* pass an explicit "you are a teammate, do not write .return-meta.json" instruction in every teammate prompt, and treat the agent-definition instruction as conditional on its absence.

UNIFORMITY REQUIREMENT: whatever is chosen must hold for all three team skills (skill-team-research, skill-team-plan, skill-team-implement) and for ANY agent type that can be spawned as a teammate. Team skills spawn arbitrary domain agents, so a fix touching only the core research agents is not acceptable. Also decide explicitly whether the .return-meta-teammate-{letter}.json convention is adopted or prohibited.

RELATED BUT DISTINCT:
- Task 17 fix_return_meta_lifecycle_ordering (COMPLETED) covers a different mechanism: skill_cleanup deleting .return-meta.json before command-gate-out.sh reads it. That is an ordering defect in the single-agent lifecycle; this is a write-conflict defect among concurrent teammates. Fixing 17 does not address this.
- Task 51 move_session_state_files_out_of_specs_root (NOT STARTED) covers .return-meta-*.json file PLACEMENT clutter in the specs/ root, not the write conflict. If direction (b) is chosen, coordinate with 51 on where per-teammate files live.

ACCEPTANCE: in a team run of each of the three team skills, the task directory ends with exactly one skill-owned .return-meta.json carrying the team_execution block; no teammate has overwritten it; no stray per-teammate metadata file exists unless the chosen direction deliberately defines one and a consumer reads it.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 68. Make the /orchestrate blocked verdict discriminating: dispatch a task blocked on an in-batch predecessor instead of skipping it forever
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None
- **Research**: [068_discriminate_blocked_on_in_batch_predecessor/reports/01_discriminate-blocked-classifier-row.md]
- **Plan**: [068_discriminate_blocked_on_in_batch_predecessor/plans/01_discriminating-blocked-classifier-row.md]
- **Summary**: [068_discriminate_blocked_on_in_batch_predecessor/summaries/01_discriminating-blocked-classifier-summary.md]

**Description**: Make the multi-task /orchestrate classifier's `blocked` row DISCRIMINATING rather than unconditional, so a task blocked on a predecessor the same batch is going to complete becomes dispatchable instead of being skipped on every cycle until MAX_CYCLES_MT is exhausted.

=== OBSERVED DEFECT ===

In multi-task mode a task with status `blocked` routes to the `skip` group unconditionally, with no consideration of WHAT it is blocked on. When the blocker is an in-batch predecessor, skipping defeats the entire purpose of submitting the chain as one batch: the predecessor completes, the successor is still `blocked`, NOTHING REWRITES THAT STATUS, and the successor is skipped again every subsequent cycle. The missing status rewrite is the core gap -- a status no component ever rewrites is why the skip repeats forever rather than resolving.

=== LIVE REPRODUCTION (measured in a deploy repo, `/orchestrate 437,436,434,433`) ===

- The chain was 437 -> 436 -> 434 -> 433, strictly serial by `dependencies[]`, correctly computed into four waves by Kahn's algorithm.
- The second task was `blocked` on the first; the third was `blocked` on the second. Both markers were set by `/spawn` at the moment each task spawned its own unblocker -- i.e. blocked ON AN IN-BATCH PREDECESSOR, the exact case this defect concerns.
- Both tasks' `.orchestrator-handoff.json` recorded `blockers: []` -- ZERO recorded blockers. The `blocked` status was pure dependency-ordering information, fully duplicated by the `dependencies[]` edge the wave scheduler had already consumed.
- Result: even after unrelated admission problems cleared, the batch would have dispatched the first task and then idled, skipping the rest every cycle. The operator had to hand-edit both statuses to `partial` via `state-write.sh` to make the chain runnable.

=== MEASURED SOURCE-STORE STATE (re-measure before relying on line numbers) ===

`scripts/orchestrate-triage-classify.sh` is the executable source of truth.
- Its `elif $status == "blocked"` arm (around line 311) emits group `skip` for engine `mt`, `needs_human` for engine `single`, with reason string "task #N is blocked; mt skips / single needs human".
- Its header verdict table (around line 63) carries the row `| blocked | skip | needs_human |`, and lines ~77-85 carry an explicit justification calling this divergence "a DESIGN, not an oversight", with a stated discriminator for future audits: "does the OTHER engine's own handler implement the divergence in its own code, or does only this shared table assert it? Independent implementation by both sides = design (keep it, documented); bare assertion by one shared table = defect (converge it)." That discriminator must be applied honestly to this change rather than quoted as a reason not to touch the row -- the defect here is not the ENGINE DIVERGENCE, it is the UNCONDITIONALITY of the mt side.

TWO FACTS THAT MAKE THE FIX TRACTABLE, BOTH VERIFIED BY DIRECT READ:
1. The classifier's CLI is `orchestrate-triage-classify.sh <engine> <task_number> [<task_number> ...]` -- it ALREADY RECEIVES THE FULL CANDIDATE LIST. Batch membership is therefore computable inside the classifier without a new argument or a call-site change.
2. The classifier already reads `specs/state.json` (hence `dependencies[]`) and, for `partial`-status candidates only, that candidate's own `.orchestrator-handoff.json`. Both discriminator signals are already within its declared read set; extending the handoff read to `blocked` candidates is a scope widening of an existing read, not a new I/O class. Respect the Context Flatness Constraint in its header: never read a plan, report, or summary.

HARD CONSTRAINT ON WHERE THE REWRITE CAN LIVE: the classifier header declares the script READ-ONLY and enumerates forbidden calls (`task-lock.sh acquire`, `update-task-status.sh`, `generate-todo.sh`, `skill-base.sh` write functions, `reconcile-task-status.sh` without `--dry-run`, and any dispatch of the Agent or Skill tool). So the classifier MAY decide the verdict but MUST NOT perform any status rewrite. Either the verdict alone suffices (route the discriminated row to its real phase group and let the normal dispatch path proceed, leaving the stale `blocked` string to be corrected by the dispatch's own preflight), or a separate component performs the rewrite. Research must pick one and name the component.

=== CO-MAINTENANCE SET (all must agree; verify by grep, do not trust this list) ===

- `scripts/orchestrate-triage-classify.sh` -- the jq arm AND the header verdict table AND the adjacent justification prose. All three, or the file self-contradicts.
- `skills/skill-orchestrate/SKILL.md` -- Stage MT-4's phase-grouping table (around line 2030) folds `blocked` into `skip`, with a divergence justification at ~2039-2043 and a related note at ~528. Stage MT-3 step 3's eligibility rule does NOT exclude `blocked`, so these tasks are ELIGIBLE-BUT-SKIPPED -- that combination is precisely what makes them spin rather than terminate, and it is the mechanism to keep in view when reasoning about convergence. The single-task engine's `#### State: blocked` handler (around line 658) reads blockers from state.json (not the handoff) and escalates to a human via Stage 6.
- `skills/skill-orchestrate-hard/SKILL.md` -- has its OWN compressed `#### State: blocked` handler (around line 1037: "Read blockers from state.json. Invoke blocker escalation (Stage 6)"), but its Multi-Task Mode section (from ~line 1539) is a bare "Same as base" pointer that transcribed only two mechanisms (the admission gate and the redeploy checkpoint) and has NO phase-grouping table. So determine, and record, whether it needs its own edit or genuinely inherits -- note its own stated rationale (~1544-1551) that bare pointers demonstrably fail to carry mechanisms forward.
- `scripts/tests/test-orchestrate-triage-classify.sh` -- already carries `fixture_blocked` (around line 219) and two assertions (~263-265) that name the current rows as "DOCUMENTED DIVERGENCE ... not a bug" and instruct the reader NOT to "fix" them. These fixtures WILL need rewriting, and the instruction comment must be rewritten with them so the suite does not preserve a claim the code no longer makes.
- `scripts/orchestrate-dry-run-report.sh` -- the read-only consumer of classifier verdicts; a dry-run's entire value is being a prediction of the live path, so any new verdict field or reason string must surface there.
- `context/patterns/batch-orchestration-guardrails.md` -- carries the NORMATIVE principle (around lines 100-119) that every gate "should degrade to an ORDERING CONSTRAINT ... and fall back to a genuine EXCLUSION" only when justified, with a per-gate table classifying each. The `blocked` status verdict is not currently a row in that table because it is a triage verdict rather than an admission gate; decide explicitly whether it becomes one, and whether the principle as stated already implies this fix.
- `docs/architecture/orchestrate-state-machine.md` -- line ~31's state table row for `blocked`, and line ~434's "No eligible tasks | partial | Deadlock or all blocked" outcome row.

=== PRIOR ART: THIS ROW WAS DELIBERATELY SCOPED OUT BY EARLIER WORK ===

The completed task `orchestrate_eligibility_not_status_gated` is the closest prior art and deliberately did NOT cover this. Its plan states: "The `blocked` and `unknown` classifier rows -- left unchanged per research Decision 3", and it explicitly preserved the blocked row as "the one documented engine-divergent row". That work fixed the ADJACENT `researching`/`planning` strandedness under the principle that "every admission gate degrades to an ORDERING CONSTRAINT and never to a PERMANENT EXCLUSION". This defect is the SAME PRINCIPLE applied to a row that earlier work scoped out. Research MUST locate that Decision 3 in `specs/067_orchestrate_eligibility_not_status_gated/reports/` and either OVERTURN IT WITH REASONS or NARROW IT -- silently contradicting it is not acceptable, and neither is citing it as a reason to do nothing.

=== DESIGN DIRECTION TO EVALUATE (decide; do not presuppose) ===

The plausible fix is to make the blocked row discriminating: distinguish a task blocked on a predecessor IN THE CURRENT BATCH (an ordering constraint the batch itself will discharge -- should become dispatchable once the predecessor terminates) from a task blocked on something the batch CANNOT resolve (a genuine external blocker -- skip or escalate as today). Points research must settle rather than assume:

1. WHICH DISCRIMINATOR. `dependencies[]` membership in the candidate list, the handoff's `blockers[]` being empty, or both (conjunction or disjunction)? Note the live reproduction had BOTH signals available AND AGREEING, so it does not by itself discriminate between the options -- construct the disagreement cases deliberately (dependency edge present but blockers non-empty; blockers empty but blocker is out-of-batch) and decide what each should do. Also settle whether a predecessor that FAILED counts as "discharged" (today a failed predecessor already moves its dependents to `failed_tasks` with status `blocked` -- see the state-machine doc around line 413 and skill-orchestrate around line 1554; that path must not be broken).

2. WHAT STATUS THE SUCCESSOR SHOULD BECOME once its in-batch predecessor terminates, and WHICH COMPONENT performs the rewrite. Nothing does today -- that is the core gap. Candidate homes, all in file_scope: `scripts/orchestrator-postflight.sh` (natural: a terminating predecessor clears its successors), `scripts/reconcile-task-status.sh` (which already gained a lock-aware demotion guard in the prior work and is the system's designated status-repair component), or skill-orchestrate's own Stage MT-3 cycle loop. It CANNOT be the classifier (read-only, see above). If the answer is "no rewrite is needed because the verdict alone routes it", say so explicitly and show what then corrects the stale `blocked` string, and when.

3. WHETHER THE SINGLE-TASK ENGINE'S `needs_human` ESCALATION STAYS DIVERGENT OR CONVERGES, applying the classifier header's own stated audit discriminator honestly. Note the asymmetry: a solo invocation has no sibling batch, so "in-batch predecessor" is vacuous there and the row may legitimately remain unchanged for `single` -- but that is a conclusion to argue, not to assume. Both engines' handlers implement the current divergence independently, which by the header's own rule makes it DESIGN; the question is whether the mt side's new discrimination changes that verdict.

4. WHETHER `/spawn` SHOULD STOP WRITING `blocked` AT ALL when it has just recorded the same ordering in `dependencies[]`. `skills/skill-spawn/SKILL.md` sets `status = "blocked"` directly via `state-write.sh` (around lines 114, 161, 178) and its own note at line 98 states "`[BLOCKED]` means 'has unmet dependencies', not 'encountered an error'" -- i.e. the file already documents the status as PURE ORDERING INFORMATION, corroborating the live reproduction's `blockers: []`. Decide whether that redundancy is deliberate (and only the consumer should change) or whether the producer should stop writing it. If `/spawn` keeps writing it, say what the status is FOR, given `dependencies[]` already carries the same fact.

=== ACCEPTANCE ===

- A batch submitted as a dependency chain where each successor is `blocked` on its in-batch predecessor runs END-TO-END IN A SINGLE `/orchestrate` INVOCATION, with no hand-editing of statuses and no operator instruction to run the tasks one at a time.
- A task blocked on something OUTSIDE the batch still does not silently spin: it is either skipped WITH A LOUD, NAMED WARNING or escalated, and which one is a RECORDED DECISION.
- A task whose predecessor FAILED still lands in `failed_tasks` and is not spuriously dispatched.
- All co-maintained copies of the verdict table agree, VERIFIED BY GREP, and every justification paragraph that asserts the now-changed premise is re-derived or corrected in the SAME change -- landing the mechanism while leaving prose asserting a false premise is not acceptable.
- New classifier fixtures cover the DISCRIMINATED blocked rows for BOTH engines and FAIL AGAINST THE PRE-FIX CLASSIFIER (observe the mutation-check discipline in `context/standards/shell-script-testing.md`: a suite that passes unchanged both before and after proves nothing). The existing `fixture_blocked` assertions and their "do not fix this" comment are rewritten, not left contradicting the new behaviour.
- The dry-run report predicts the new behaviour, since a dry-run that disagrees with the live path is worse than no dry-run.

=== SCOPE RULES (binding) ===

Edit ONLY `agent-system/extensions/core/**`, NEVER the deployed `.claude/**` tree, per `.claude/rules/source-store-deploy-boundary.md`; verify via a deploy after the change rather than editing the deploy tree. No task-number references in any deliverable outside `specs/**`, per `.claude/rules/no-task-references-in-deliverables.md` -- cite filenames and section headings instead. If implementation finds another file genuinely needs editing, widen `file_scope` deliberately via `state-write.sh`, naming each file exactly -- no bare directory roots, no duplicate entries.

=== SELF-MODIFYING TASK ===

`scripts/orchestrate-triage-classify.sh`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`, `scripts/orchestrate-batch-admit.sh` and `scripts/orchestrate-dry-run-report.sh` are all registered in `context/reference/orchestrator-critical-paths.json`, so `orchestrate-batch-admit.sh` will classify this task as `self_modifying`. Under the designated-candidate tie-breaker shipped by the prior admission-gate work, one self-modifying candidate is admitted per cycle, so this task self-sequences rather than deadlocking. Do NOT run it solo -- solo dispatch is the workaround that line of work exists to eliminate.

---

### 64. Decide and implement how --hard behavioral contracts reach agents system-wide
- **Status**: [ABANDONED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 42

**Description**: Decide and implement how --hard behavioral contracts reach agents system-wide. Only core, cslib, and lean declare routing_hard/routing_agents_hard. For every other extension that declares routing, --hard resolves via=hard-miss-standard-fallback and the H2-H5 behavioral contracts never reach the agent, even though CLAUDE.md advertises --hard as composable with extension routing at a 3-5x cost multiplier. In the originating session the H2/H3/H4/H5 contracts had to be hand-injected into the delegation prompt by the orchestrator for --hard to mean anything at all, which is neither reproducible nor something a user should have to do.

CORRECTED COUNT - VERIFIED INVENTORY, USE THIS NOT THE 16 FIGURE. The delegating description said 16 extensions and listed literature and slidev among them. A direct inventory of all 19 manifests under agent-system/extensions/*/manifest.json shows the real figure is 14. literature and slidev declare routing_exempt: true and declare NO routing blocks whatsoever - they are legitimately exempt, not gaps, and must not be counted, rolled out to, or failed by any lint.
The 14 that declare routing (and routing_agents) but no routing_hard/routing_agents_hard are: email, epidemiology, filetypes, formal, founder, latex, memory, nix, nvim, present, python, typst, web, z3.
For completeness: core declares routing_agents + routing_hard + routing_agents_hard but no plain routing block; cslib and lean declare all four.
CONSEQUENCE FOR LINT DESIGN: any check must skip routing_exempt: true manifests, or it emits 2 false failures on literature and slidev.

DECIDE, DO NOT PRESUPPOSE:
  (a) Declare hard variants across the remaining 14 manifests.
  (b) Make the fallback inherit standard extension routing while delivering hard contracts from a single shared contract block rather than per-skill '-hard' files.
  (c) Both, plus a lint check flagging any extension that declares routing but no routing_hard.
Weigh (b) seriously. The shared ladder lives in exactly one place - agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh, consumed by both command-route-skill.sh and command-route-agent.sh - so a resolver-side fix is a single change point covering all extensions, whereas (a) is 14 manifest edits that can drift. The fact that only 3 of 19 extensions have hard variants is itself evidence that the per-extension '-hard' file approach does not scale, and that evidence bears directly on the choice.

DEPENDS ON THE AGENT-SIDE ROUTING-DOWNGRADE FIX IN THIS BATCH, AND THAT FIX MATERIALLY DE-SCOPES THIS ONE. Once the agent side inherits standard extension routing on a hard miss, most of the 14 resolve to their correct domain agent with ZERO manifest edits. What remains is then the narrower and different question of how the H2-H5 CONTRACTS reach the agent, which is the shared-contract-block idea in option (b). Do not price a 14-manifest rollout before that fix has landed - it would be costing work the fix largely obviates. Re-run the resolver inventory after the dependency completes and report what actually still misroutes.

LINT COORDINATION (binding, read before proposing lint scope). The existing not_started task fix_present_extension_compound_skill_routing already proposes extending lint-routing-wiring.sh, which currently validates declared AGENT names but not SKILL names. Read that task's description in specs/state.json first. The checks are genuinely additive rather than duplicative, and the current coverage matters: lint-routing-wiring.sh already has Check A (routing.{op} keys have routing_agents.{op} counterparts), Check B (routing_agents/routing_agents_hard values name existing agent files), Check C (routing_hard.{op} keys have routing_agents_hard.{op} counterparts), and Check D (report-only general-* declarations). Check C therefore ALREADY covers the within-manifest hard counterpart requirement. What is missing is a new check for 'declares routing but no routing_hard at all' - additive to that task's Check B skill-name extension. Both edit the same file, so declare a dependency or otherwise serialize with it rather than duplicating its work or racing it.

ACCEPTANCE: a single documented decision among (a)/(b)/(c) with its reasoning recorded; --hard delivers the H2-H5 contracts to agents for every non-exempt extension without requiring per-invocation hand-injection by the orchestrator; any lint check added skips routing_exempt manifests and does not duplicate the sibling task's skill-name validation; CLAUDE.md's claim that --hard is composable with extension routing is either made true or corrected to match reality.

RELATED BUT DISTINCT - DO NOT ABSORB. The typst/latex task-type restriction task in this repo concerns which task type a task is ASSIGNED from keywords, not which agent or contracts a type resolves to. No file overlap with this task's resolver and lint scope, though note that if option (a) is chosen it would edit the typst and latex manifests, which that task also touches (different keys: keyword_overrides/aliases there, routing_hard/routing_agents_hard here) - coordinate if (a) is selected.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 53. Suppress expected handoff absence defect
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Stop recording a spurious HANDOFF_STALE_OR_ABSENT system defect when a contractual non-writer leaves no fresh handoff. Observed live on a clean, fully-successful base-mode /orchestrate run (recorded as evt_1786550950625_o2KoSv; the class already has 3 occurrences in specs/events.jsonl).

OBSERVED MECHANISM (verified, do not re-derive). In a base-mode /orchestrate run of a task that entered at [RESEARCHED], the plan dispatch wrote .orchestrator-handoff.json carrying dispatch_seq=1. The implement dispatch that followed wrote no handoff, correctly: docs/architecture/handoff-schema.md's "Handoff Writers" table settles that .orchestrator-handoff.json is hard-mode-implement-only, and general-implementation-agent.md states "base-mode implement is a non-writer by design". Nothing clears the prior cycle's handoff, so the planner's file was still sitting at the path when Stage 5 ran. Both freshness gates fired on it exactly as designed -- mtime predated the dispatch window, and dispatch_seq=1 did not match the minted dispatch_seq=2 -- and the dispatch_seq gate recorded a HANDOFF_STALE_OR_ABSENT system defect. The run then proceeded correctly: orchestrate-recover-outcome.sh recovered status=implemented, 7/7 phases, from .return-meta.json, and the task completed.

THE DEFECT IS ORDERING, NOT DETECTION. The gates are right and must not be weakened -- they are the identity mechanism delivered by the handoff-identity work, and they are the reason a genuine late-writer clobber would be caught. The bug is that the recording happens BEFORE the system consults whether the absence was expected. skill-orchestrate/SKILL.md's own recovery branch prints "no handoff written for this dispatch -- expected outcome for this phase's writer (base-mode research/plan/implement never write one)". The knowledge that this is expected already exists in the file; it just arrives one step too late to suppress the defect record. The recorder therefore fires on a run in which nothing went wrong.

WHY THIS MATTERS BEYOND NOISE. A defect class that fires on ordinary success carries no information, and a real stale-handoff incident becomes indistinguishable from routine base-mode operation. This is the same failure shape as the gate-out warning that cannot separate silent failure from ordinary success, tracked separately. It also directly bears on the open question of whether "zero defect events on a clean run" is a sound acceptance bar, tracked in the verification-trust bundle: that item assumes the recorder only fires on genuine agent-compliance slips. This observation falsifies that assumption and should be folded in as evidence when that decision is made.

SECOND, INDEPENDENT QUESTION -- DECIDE EXPLICITLY. Base-mode dispatch contexts pass handoff_path to every dispatch (research, plan, and implement alike), which invites a contractual non-writer to write a handoff at all. That is how the planner came to write one in the observed run. Decide whether base mode should stop passing handoff_path except where a writer is contractually expected, or whether passing it uniformly is deliberate and the leftover file should instead be cleared or rotated at dispatch start. Either resolution is acceptable; the current arrangement, where a non-writer is handed a write target and its output then trips the successor's freshness gates, is not.

CANDIDATE DIRECTIONS (evaluate, do not blindly adopt): (a) consult the writer contract before recording -- if the dispatched writer is contractually a non-writer for this mode and phase, treat a stale-or-absent handoff as the expected outcome and log it without recording a defect; (b) clear or rotate any pre-existing handoff at dispatch start so the gates only ever fire on a genuine late write from a live predecessor; (c) narrow handoff_path propagation to contractual writers. Note that (b) alone must not blind the gates to the live-predecessor late-write case, which is the hazard they exist to catch.

CO-MAINTENANCE (binding). skill-orchestrate/SKILL.md and skill-orchestrate-hard/SKILL.md carry an explicit co-maintenance contract, and the Stage 5 staleness/dispatch_seq gate is a verbatim twin across the two. A one-sided fix here reproduces a named recurring defect class. Both copies must be changed together, or the asymmetry recorded in both.

ACCEPTANCE: a clean base-mode /orchestrate run that transitions plan to implement records no system defect; a genuine stale or late-written handoff still trips the gates and still records one; and both engines agree. Demonstrate both directions -- a detector that can only ever stay silent is not a fix.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== EVIDENCE ADDED 2026-08-24 (the live-predecessor case, observed for real) ===
CONFIRMING, NOT CONTRADICTING. This task's candidate direction (b) carries the caveat that
clearing or rotating a stale handoff at dispatch start "must not blind the gates to the
live-predecessor late-write case, which is the hazard they exist to catch". That hazard has now
been OBSERVED LIVE rather than merely anticipated, and the observation should be treated as a
binding test case for whichever direction is adopted.

OBSERVED MECHANISM (verified, do not re-derive). In a seven-task lean4 batch in a separate
consumer repo, an implementation dispatch (minted dispatch_seq=19) went quiet for ~25 minutes
after writing a wrap-up summary. It was judged terminated and the task was re-dispatched as a
resume (minted dispatch_seq=22). The ORIGINAL dispatch was in fact still alive: it then completed
and wrote .orchestrator-handoff.json claiming status=implemented, 5/5 phases. Its mtime was NEWER
than the resume dispatch's own window start, so THE MTIME FRESHNESS GATE PASSED IT. Only the
dispatch_seq comparison (19 against the minted 22) exposed it as a predecessor's late write.
Recorded as evt_1787614360544_SgKpRP. The resume subsequently wrote its own seq-22 handoff and
that report was taken as authoritative.

WHY THIS IS DECISIVE FOR THE DESIGN CHOICE. It is a direct, non-hypothetical demonstration that
mtime alone is insufficient and that dispatch_seq is load-bearing, exactly as
context/patterns/dispatch-report-not-termination.md argues. Any resolution of this task that
suppresses or reorders the recording MUST still surface this case. Specifically: direction (a)
(consult the writer contract before recording) is safe here only if "contractual non-writer"
is evaluated per dispatch identity and not per phase alone -- an implement dispatch that IS a
contractual non-writer in base mode still produced a real seq-mismatched clobber in this
incident, so a contract-only check keyed on phase would have silently swallowed it.

SECONDARY OBSERVATION, RELEVANT TO THE ACCEPTANCE BAR. This task notes the open question of
whether "zero defect events on a clean run" is a sound acceptance bar and asks that this
observation be folded in as evidence. Add this one too, pulling in the opposite direction: the
run above was NOT clean, and the single recorded defect event was the only signal distinguishing
a predecessor clobber from a normal report. A bar of "zero defect events" is sound only if the
genuine-incident channel stays as loud as it is today.

=== EVIDENCE ADDED 2026-09-01 (live-predecessor late write, via git restore rather than late completion) ===
CONFIRMING, NOT CONTRADICTING. A SECOND live instance of the hazard that candidate direction (b)
is cautioned against, observed on a hard-mode /orchestrate run in a separate consumer repo and
recorded as evt_1788246742189_Fodegl. It differs from the 2026-08-24 instance in MECHANISM and
therefore widens, rather than merely repeats, the constraint on any fix.

OBSERVED MECHANISM (verified, do not re-derive). Phase 1's implementation agent finished, wrote
its handoff carrying dispatch_seq=3, and its dispatch closed cleanly. The orchestrator consumed
and DELETED both .orchestrator-handoff.json and .return-meta.json, then dispatched Phase 2 with a
freshly minted dispatch_seq=4 at dispatch_start_ts 1788246604. The Phase 1 agent then WOKE UP --
it was re-prompted about an unrelated question -- and RESTORED both JSON files from its own commit
b642bca4c, re-writing them at mtime 1788246672. That mtime falls INSIDE Phase 2's dispatch window
and is NEWER than its start, so THE MTIME FRESHNESS GATE WOULD HAVE PASSED a completed
predecessor's report (phases_completed: 1) as Phase 2's outcome. Only the dispatch_seq comparison
(3 against the minted 4) exposed it. Both files then had to be cleared MANUALLY before Phase 2
could proceed safely.

WHAT IS NEW HERE, BEYOND THE 2026-08-24 CASE. Three things.

(1) THE PREDECESSOR WAS NOT MERELY LATE -- IT RESURRECTED DELETED FILES FROM GIT. The 2026-08-24
instance was a still-running dispatch completing late. This one is a dispatch that had already
closed, whose files had already been consumed and deleted, and which then restored them from a
commit. Any resolution built on "clear or rotate the handoff at dispatch start" (direction (b))
is defeated outright by this shape: clearing at dispatch start happened, and the file came back
afterwards anyway. Direction (b) is therefore not merely insufficient, as this task already
suspected -- it is inert against this mechanism. Only an identity check on the file's CONTENT,
which is what dispatch_seq provides, survives it.

(2) THE RECOVERY FALLBACK SHARES THE EXPOSURE, AND IT IS NOT GUARDED. This task's file_scope has
until now treated the handoff freshness gates as the surface at risk. The observed incident shows
orchestrate-recover-outcome.sh is exposed too: its .return-meta.json fallback is windowed on MTIME
ONLY, with no dispatch_seq equivalent. Had Phase 2 gone partial, that fallback would have
recovered the restored predecessor's .return-meta.json and reported Phase 1's outcome as Phase 2's
-- the manual clearing is the only reason it did not. Whatever is decided about the recording
order, the recovery path needs the same identity discipline as the gate, or it becomes the
unguarded way in. agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh is added to
this task's file_scope accordingly.

(3) THE dispatch_seq GATE EARNED ITS KEEP A SECOND TIME, ON A DIFFERENT MECHANISM. This
strengthens rather than qualifies this task's binding constraint that the gates "are right and
must not be weakened". Two independent live incidents, with different causes, both passed the
mtime gate and were caught only by dispatch_seq. Any suppression or reordering of the recording
MUST still surface both shapes, and the acceptance bar should demonstrate the git-restore shape
specifically, since it is the one that defeats clearing.

---

### 51. Move session state files out of specs root
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Stop session-scoped orchestration runtime files from accumulating at the specs/ root, and make the existing reap path actually run. Originally scoped as "move the files into a dot-prefixed directory"; widened after a manual cleanup swept 79 stranded files across 5 repos (oldest dated 2026-07-11), because relocation alone hides the clutter without stopping the growth.

Three parts:

(1) Relocation (original scope). Move .orchestrator-multi-state-{sid}.json and .return-meta-multi-{sid}.json out of the specs/ root into a dot-prefixed subdirectory (e.g. specs/.orchestration/), or handle otherwise as most appropriate. Must update every writer/reader, the reaper's glob roots, .gitignore patterns, check-runtime-file-tracking.sh's probe paths, and context/standards/orchestrator-runtime-files.md's Class Table.

(2) Reaper glob coverage gap. scripts/reap-session-runtime-files.sh sweeps ONLY the current hyphen-separated shapes (specs/.orchestrator-multi-state-*.json, specs/.return-meta-multi-*.json). Three superseded naming generations are therefore permanently unreapable and had to be deleted by hand:
  - un-suffixed:     .orchestrator-multi-state.json / .return-meta-multi.json
  - dot-separator:   .orchestrator-multi-state.sess_{sid}.json
  - .prev- variant:  .orchestrator-multi-state.prev-sess_{sid}.json
Additionally .return-meta-meta.json, .return-meta-meta-sess_{sid}.json, and .meta-return.json have NO writer or reader anywhere in agent-system/ or .claude/ (orphans of a superseded convention; .meta-return.json was also tracked in git and has since been removed). Decide per shape whether to widen the reaper's globs or to add a one-shot legacy-name migration, and ensure any relocation in part (1) does not create a fourth orphaned generation.

(3) Automatic invocation (root cause). The reaper is correct and works -- it cleared 41 of 41 files on first run -- but its ONLY trigger is a manual /refresh, so litter grows unbounded between refreshes. Wire reap into /todo, which is run far more often and is already the repo's housekeeping command. Call both scripts/reap-session-runtime-files.sh and task-lock.sh session-reap (stale .sessions/ registry entries accumulate identically -- 9 dead-pid entries were swept in nvim alone). Suggested hook point: a new stage between skill-todo's stage 10 ArchiveTasks and stage 15 GitCommit, so reaped paths land in the same commit; alternatively fold the reporting half into stage 3 DetectOrphans. Must stay non-blocking and honor the existing ORCHESTRATOR_SESSION_REAP_MIN threshold (default 240min) so in-flight batch runs are never reaped; echo the reaper's own output verbatim the way skill-refresh already does. Keep /refresh's invocation working unchanged.

Affected repos observed: nvim, BimodalLogic, cslib, ModelChecker, PersonalWebsite -- so the fix belongs in the core extension source store, not any single repo's deploy.

---

### 50. Restore verification trust and close hygiene residue
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 48

**Description**: === REVISED 2026-08-24 (refactor survey) ===
SPLIT AND REDUCED. Item 1 -- the non-deterministic shell test suite -- has been extracted into its own task (deflake_shell_test_suite_under_concurrency) because it is the highest-value piece here by a wide margin: until the suite is deterministic, no acceptance gate in this repo is trustworthy in either direction, including this task's own. Do not work it here.
WHAT REMAINS is hygiene residue, and the measurements below are updated -- most of it DEGRADED since filing, which is the point:
- session-ID one-liner: 43 -> 48 files (46 of them .md). Note the gate for this exists but greps only *.sh, so it has been green throughout; the gate fix is owned by the duplication-gate task, so sequence after it rather than duplicating the migration here.
- jq #1132 block: 34 -> 36 files.
- @.claude/docs stylistic refs: 6 -> 15 occurrences.
- literature-retrieve.sh: still declared in core/manifest.json:134 despite its own header reading DEPRECATED with zero automated callers, while a 9-script scripts/deprecated/ quarantine directory sits right there. Straight quarantine-convention miss.
- topic taxonomy: PARTLY SELF-HEALED. The used-but-undeclared side is now 0. But declared-but-unused grew to TEN orphan topics: commit-scoping-concurrency, context-loading, cslib, mcp-integration, memory-improvement-loop, neovim, orchestrate-admission-gate, status-marker-lifecycle, wezterm-notifications, workflow-refactor. (Note status-marker-lifecycle is no longer an orphan -- the plan-status task now carries it.)
- ROADMAP.md: unmodified since 2026-07-12. NONE of its 11 items maps to any active task, and its success metric says '14 extensions' against 19. Rewrite it to describe work actually in flight, or delete it -- a roadmap that describes nothing is worse than no roadmap, because /review's roadmap-integration step dutifully annotates it.
Verification-surface items from the original scope are superseded by the CI-expansion and deploy-verification tasks; check for overlap before starting and drop anything they already cover.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Make the verification surface trustworthy, and close the doc-truth and duplication residue. Grouped because each item individually is too small to dispatch, and all of them undermine confidence in the same gate suite.

(1) THE SHELL TEST SUITE IS NON-DETERMINISTIC (highest value item here). Measured across five consecutive runs of scripts/tests/run-all.sh: exit 1, 0, 1, 0, 0 -- roughly a 2-in-5 failure rate, with passing runs reporting a clean 36/36. During the same review, verify-deploy.sh gate 8 passed while a standalone run failed minutes later. A gate that passes 60% of the time is not evidence of health in either direction. It is also actively harmful to the refactor's own acceptance gate: the capstone attributed a real failure to "a flaky lock-contention test attributable to concurrent sibling sessions, not a deploy defect" WITHOUT being able to confirm that, precisely because the suite cannot distinguish the two. Diagnose the contention (the suite runs concurrently with other live sessions holding the same locks), then either isolate the affected tests from shared global state or make them wait deterministically. A test that is merely retried is not fixed. ACCEPTANCE: 10 consecutive runs, executed while at least one other session is active, all report the same result.

(2) THE DEPLOY NON-DETERMINISM FINDING HAS NO OWNER. The capstone's defect ledger dispositions err_1786350581240_JyztWt (deploy_nondeterministic_merge) as "folds into" the orphan-file parity task, and leaves err_1786350581208_23mAsn (deploy_merge_content_loss, observed once, then 0-of-3 on re-check) as entry-only. The parity task's actual text discusses only the four orphan files -- it never mentions ordering or content loss. The fold was recorded but never performed, so capstone DEPLOY sub-item ii ("running the deploy twice is byte-identical") is failing with nobody assigned. A fold recorded but not performed is exactly the failure mode a defect ledger exists to prevent; note that as a process finding, not only a technical one. WORK: run the scratch wipe-pair procedure, establish whether context/index.json and settings.json still differ by object-key/array-element ordering beyond the expected generated timestamp, re-check the settings.local.json content-loss observation, and either fix the ordering non-determinism or record an explicit decision that semantic equality under `jq -S` is the standard and byte-identity is not required. Either resolution is acceptable; the current silent ambiguity is not.

(3) RE-SCOPE OR SATISFY THE LIVE-CYCLE DEFECT CRITERION. The capstone requires that a clean orchestration cycle emit no system_defect event and that the deferred-defect surface render empty. specs/events.jsonl now holds 5 such events (3 from 2026-08-08 plus 2 newer: OFF_SCHEMA_STATUS and META_MISSING_AFTER_NARRATION). Both new events are correctly-firing detectors catching real agent-compliance slips -- the recorder working as designed, not noise. DO NOT FIX THOSE TWO DEFECTS HERE: the OFF_SCHEMA_STATUS handoff-key problem belongs to the in-flight handoff identity-contract task, and META_MISSING_AFTER_NARRATION belongs to the in-flight nonterminal-fanout task. Both should have the observation appended to them. What is unowned, and what belongs HERE, is the criterion itself: decide whether "zero defect events on a clean run" is the right acceptance bar given a recorder that will legitimately fire whenever any agent slips, or whether it should be re-scoped to "no NEW defect classes" -- the same precedent the capstone already set for its unverifiable gate-out criterion. Record the decision where the acceptance criteria live.

(4) DUPLICATION WITH AN AVAILABLE SHARED MECHANISM. (a) The literal one-liner `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')` appears 43 times across 35 command and skill files, while common_session_id() exists in scripts/lib/common.sh and is already wired into command-gate-in.sh. (b) The jq Issue #1132 safety block appears in 34 source files against a canonical home in context/patterns/jq-escaping-workarounds.md and a CLAUDE.md section -- roughly 8 KB of duplication, and 8 of those copies sit inside present/ skills where they are per-invocation cost. Replace both with calls/pointers. Note that some sites may not be convertible where sourcing common.sh a second time is genuinely awkward; name any residual rather than forcing it.

(5) DEAD AND UNDOCUMENTED MACHINERY. (a) scripts/literature-retrieve.sh (7.9 KB) is deprecated by its own header ("superseded by literature-briefing.sh ... Do not add new usages"), has zero automated callers, yet is still declared in the core manifest's provides.scripts and therefore deploys every time. This repository already runs a rigorous quarantine-never-delete convention -- scripts/deprecated/ holds 11 such scripts, removed from provides so they never deploy -- and this one file simply missed the process. Put it through the same process. (b) /zulip and skill-zulip are live and deployed but have zero mentions in the generated CLAUDE.md: no Command Reference row, no extension section. (c) scripts/check-runtime-file-tracking.sh is legitimately operator-invoked-only, like its five documented siblings, but is missing from CLAUDE.md's Utility Scripts table, so a future dead-code sweep will flag it as an orphan. (d) Six `@.claude/docs/...` references remain in meta-builder-agent.md, context/architecture/system-overview.md, context/architecture/component-checklist.md and context/patterns/thin-wrapper-skill.md; they carry no runtime cost, but they model the exact syntax the context-loading audit spent a phase normalizing away.

(6) TAXONOMY AND ROADMAP DRIFT. specs/state.json's active_topics omits `context-loading` and `email`, both live topics on existing tasks, so generate-task-order.sh renders them through its append-extras path with a stderr warning instead of in curated order; meanwhile seven declared topics now have zero tasks. Separately, specs/ROADMAP.md no longer describes the work in flight -- its Phase 1 is documentation-infrastructure items that appear nowhere in the active task set, and its Success Metrics cite a task number and an extension count from a previous era. Because /review's roadmap-integration step annotates against this file, a stale roadmap makes that step a guaranteed no-op. Reconcile the topics and rewrite the roadmap to describe the actual workstreams.

NEGATIVE FINDINGS -- DO NOT RE-INVESTIGATE THESE. A caller analysis across all 138 scripts and hooks found only literature-retrieve.sh dead; the rest have live callers, including ones reachable only through skill-base.sh's dynamic hooks[$hook_name] manifest lookup and run-all.sh's glob discovery. All 193 files under context/ have live references and are enrolled in context/index.json, a real dynamic-discovery layer -- there are no orphans there and no bytes to recover. docs/ (455 KB) costs zero runtime tokens: CLAUDE.md references it only by backticked path, never @-import. Recording these so they are not re-derived.

THIS TASK IS A BUNDLE AND IS A REASONABLE CANDIDATE FOR EXPANSION -- items 1-3 are verification trustworthiness, items 4-6 are hygiene. If driven as one unit, commit them as separate phases.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 48. Propagate scoped commit to all call sites
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 90, Task 124

**Description**: Propagate the scoped-commit fix to the 65 call sites it never reached. This is a correctness/safety task, not a cleanup task.

THE MECHANISM ALREADY EXISTS AND IS CORRECT. scripts/git-commit-scoped.sh describes itself as "the single sanctioned implementation of the scoped-commit contract". It was built to close a documented concurrency defect: a bare `git commit` sweeping in a file that another concurrently-running agent had staged but not yet committed. The fix is sound. Adoption simply stopped.

MEASURED STATE: 85 occurrences of raw `git commit -m` across 70 command/skill files in the source store. Only 5 files call git-commit-scoped.sh -- skill-implementer, skill-planner, skill-team-implement, skill-orchestrate, and commands/orchestrate.md. The remaining 65 files still hand-roll the vulnerable raw form, including the highest-traffic core commands: research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md.

WHY THIS IS NOT THEORETICAL: the review that produced this task ran with eight concurrent Claude sessions active on the same machine, several in this same repository. Under that load every /research, /plan, /task, /todo, /errors and /review commit is currently capable of capturing another session's staged work. Concurrent multi-session operation is the normal working mode here, not an edge case.

THIS IS ALSO THE SHARPEST LIVE INSTANCE of the "duplicated mechanism instead of shared mechanism" root cause named in the opening refactor review. Unlike most instances of that pattern, the shared mechanism here is already written, already tested, and already proven at 5 sites -- so the work is propagation and verification, not design.

WORK: migrate call sites to git-commit-scoped.sh, highest-traffic first. Suggested ordering: (a) core commands research.md, plan.md, implement.md, todo.md, task.md, errors.md, review.md; (b) remaining core skills; (c) non-core extension commands and skills (founder, present, filetypes, lean, web, epidemiology, literature, memory, cslib).

DO NOT MECHANICALLY REWRITE ALL 85 SITES. Some call sites may legitimately differ -- a commit whose staging scope is genuinely not task-scoped, or a test fixture that must exercise the raw form. Inspect each; where a site should NOT be migrated, record why in the summary rather than silently skipping it. A migration that converts 85 of 85 without noting a single exception is more likely to be careless than thorough.

ALSO SETTLE: whether the raw form should be blocked mechanically once migration lands (a lint in the verify-deploy gate list, in the same family as lint-state-writer-boundary.sh, which already polices the analogous state.json write boundary). Without such a gate the pattern regrows on the next new command. If a lint is added, it must exempt git-commit-scoped.sh itself and its tests.

ACCEPTANCE: `grep -rl 'git commit -m' agent-system/extensions/` returns only git-commit-scoped.sh and its test files, or returns additional files each of which is named in the summary with a stated reason for exemption. Existing test suites still pass. At least one migrated command is exercised end-to-end (a real commit through the converted path) rather than only inspected statically.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 46. Fix present extension compound skill routing
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: RESCOPE + BACKFILL NOTE (task-116 audit). Per specs/116_core_agent_system_consolidation/reports/03_target-state-design.md A3: the routing-half of this defect (present's routing.implement colon-suffixed skill-name values) becomes MOOT once task 124 (delete_lifecycle_commands_and_update_reference) retires command-route-skill.sh and the skill-dispatch layer it serves. This task's live scope narrows to the routing_agents-half only: if present's routing_agents block carries the analogous colon-suffixed AGENT name, fix that, plus the lint-routing-wiring.sh extension. file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nFix present extension compound-skill routing so /implement resolves to a real skill. The present manifest's routing.implement declares "present:grant" -> "skill-grant:assemble" and "present:slides" -> "skill-slides:assemble", but the shared routing resolver (scripts/lib/manifest-routing-lib.sh, consumed via command-route-skill.sh) returns those values verbatim with no colon splitting, and no skill directories named skill-grant:assemble or skill-slides:assemble exist -- only skill-grant and skill-slides do. Running /implement on a present:grant or present:slides task therefore resolves SKILL_NAME to a nonexistent skill (verified: resolver returned skill-grant:assemble via noncore-exact). skill-grant/SKILL.md documents "assemble" as a workflow_type value, not part of the skill name, so the manifest is encoding skill + workflow_type in one field that no consumer ever splits. Decide whether the fix belongs in the manifest (drop the :suffix and carry workflow_type another way) or in the resolver (split on the first colon and expose the suffix as a workflow_type/sub-mode variable), implement it, and add a lint check so any routing or routing_hard value naming a nonexistent skill fails verify-deploy -- lint-routing-wiring.sh currently validates declared agent names but not skill names. Scope is exactly 2 occurrences, both in agent-system/extensions/present/manifest.json under routing.implement; present declares no routing_hard, and no other extension uses colon-bearing routing values. Found during a deploy-integrity audit of the Logos/Theory repo.

---

### 45. Global update extension repo registry
- **Status**: [NOT STARTED]
- **Task Type**: general
- **Topic**: neovim
- **Dependencies**: None

**Description**: TOPIC CORRECTION + BACKFILL NOTE (task-116 audit). This task carried topic core-agent-system, but its real scope (the <leader>al extension picker's 'Global Update' action) is nvim-config Lua UI code at lua/neotex/plugins/ai/claude/commands/picker/** and lua/neotex/plugins/ai/shared/extensions/**, NOT agent-system/extensions/** -- it is unrelated to the orchestrate-engine collapse. Re-topiced to neovim; file_scope backfilled from description evidence (was previously empty). Original description follows.\n\nImplement <leader>al repo registration and 'Global Update' action: when <leader>al loads extensions into other repos, register those repos and their loaded extensions in this nvim repo; add a 'Global Update' entry (similar to 'Reload All') that reloads all extensions already loaded in each registered repo, reporting any failures in a message and otherwise success as a count of the total

---

### 44. Slim commands/task.md, the largest per-invocation context contributor
- **Effort**: 2-4 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 88
- **Research**: [044_slim_task_command_body/reports/01_command-body-extraction-approach.md]
- **Plan**: [044_slim_task_command_body/plans/01_task-command-mode-extraction.md]

**Description**: LOWER PRIORITY (per-invocation cost, not per-session). `commands/task.md` measures 37,465 bytes (~9.4k tokens) loaded on every `/task` invocation, plus ~2.8k tokens of imports it pulls in — the largest single per-invocation context contributor found by the context-loading audit. Slim the command body by moving reference material (long option tables, worked examples, edge-case narratives) into lazily-loaded context files under the core extension's context tree, keeping the command body to the decision logic and dispatch instructions an invocation actually needs. Preserve behavior: every mode (--recover, --expand, --sync, --abandon, multi-task creation) must remain fully specified — either inline or via an explicit pointer the executing agent is instructed to follow. Measure before/after bytes and record them in the implementation summary. CONSTRAINTS: all edits target agent-system/extensions/core/** (source store), never the deployed .claude/** tree; no task-number references in deliverables outside specs/**; do not change command behavior, only where its prose lives.

---

### 43. Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
- **Effort**: 1-3 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: LIVE DEFECT, not an efficiency item: the email extension's five 'non-negotiable' safety context pointers (safety-invariants.md, wrapper-contracts.md, index-architecture.md, staleness-detection.md, archive-mode-risk.md) were written as `@.claude/context/...` imports in the merge-source era — a form that resolves to a nonexistent path and silently loads NOTHING. They have since been normalized to plain backticked paths (still non-loading by design), so the question the audit deferred is now unavoidable: how does safety-invariants.md actually reach an agent before it mutates a mailbox? Decide deliberately between: (a) making the safety pointers genuinely eager in the email extension's CLAUDE.md contribution, accepting roughly 13k tokens of every-session cost in deploys where email is loaded; (b) establishing that the wrapper contracts (five nix-built wrapper binaries as the only mutation path) plus the email skills'/agent's own explicit context-loading instructions already carry the enforcement, and recording that as the documented decision; or (c) a middle path such as eager-loading ONLY safety-invariants.md (the smallest, most critical file) while the rest stay lazy. Verify empirically what skill-email-cleanup, skill-email-sync, and email-implementation-agent load today before choosing. Whatever the choice, record it in the email extension's docs so the next audit does not re-litigate. CONSTRAINTS: all edits target agent-system/extensions/** (source store); no volatile files in any eager prefix; no task-number references in deliverables outside specs/**.

---

### 42. Add verify-deploy gates: broken-@-ref lint and warning-first context-budget gate
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
ITEM (a) IS ALREADY ACHIEVED. grep for '@\.claude|@[a-zA-Z]' across every merge-sources/claudemd.md returns ZERO. The broken-@-ref lint therefore guards an end state that already holds -- it is a REGRESSION GUARD, not a fix for a live problem. Say so in the acceptance criteria rather than describing a defect that no longer exists; an implementer who reads the original wording will go looking for broken refs and find none, then either invent work or stall.
ITEM (b) IS GENUINELY ABSENT AND IS THE REAL CONTENT OF THIS TASK. scripts/lint/ holds five linters, none budget- or @-related, and verify-deploy.sh has no budget hook. The measurement harness this depends on is BUILT AND READY: scripts/measure-eager-context.sh exists, runs clean, and currently reports 64,323 B / ~16.1k tokens of session-start eager context (improved from 74,136 B at the 2026-08-11 review). Wire it into the gate suite with a threshold so the eager-context win cannot silently regress -- it already nearly did, since the 13% rules-diet saving was entirely consumed by skill growth over the same period.
Suggested threshold anchor: fail above the current 64,323 B, and record the number in the gate output so drift direction is visible per run rather than re-derived per review.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Add two context gates to the deploy verification pipeline. (a) Broken-@-ref lint: every `@path` token appearing in generated CLAUDE.md (and in the merge sources that produce it) must either RESOLVE relative to its containing file's directory or be explicitly marked citation-only; a ref that resolves to a nonexistent path is silently inert today (no error, no load) and must fail the gate loudly. The desired end-state for this repo is zero `@`-refs in merge sources (downward normalization to plain backticked paths is already applied), so the lint primarily guards against regression. (b) Warning-first context-budget gate: compute the predicted eager surface (reuse or invoke the measurement harness if it exists by then) and WARN when it exceeds a configured budget; escalate to a hard failure only after the warning tier has proven stable. Consider a per-extension `merge_targets.claudemd.max_bytes` manifest field — NOTE THE SEQUENCING DEPENDENCY: manifest-schema changes must coordinate with the in-flight manifest-schema work (correct-mcp-ownership / extension-manifest efforts); if that work is unsettled when this task starts, implement the budget with an external config and defer the manifest field. CONSTRAINTS: gates must read the source store and the freshly generated output, never trust the possibly-stale deployed .claude/** tree; volatile files (specs/TODO.md, state.json, errors.json) appearing in the eager set is always a FAILURE, not a warning; all edits target agent-system/extensions/**; no task-number references in deliverables outside specs/**.

---

### 39. Upgrade Zotero metadata resolution and plan the Zotero 10 backend swap
- **Effort**: 3-6 hours
- **Status**: [PLANNED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [039_zotero_metadata_resolution_upgrade/reports/02_zotero-metadata-resolution-design.md]
- **Plan**: [039_zotero_metadata_resolution_upgrade/plans/02_zotero-metadata-resolution.md]

**Description**: Upgrade the literature extension's Zotero integration beyond bare write-path activation: add a real metadata-resolution step for web-discovered sources, decide the MCP question, gate auto-attach on storage quota, and record the Zotero 10 backend-swap plan. Grounded in verified Aug-2026 tooling research — see the seed report before re-deriving any landscape claim.

=== WORK ITEMS ===

1. TRANSLATION-SERVER INTEGRATION (the pipeline's thinnest point today). The online ingest bridge currently relies on `zot add --pdf`'s DOI-from-PDF extraction for metadata, which fails on books, preprints without embedded DOIs, and scans. Integrate the official `zotero/translation-server` (HTTP, port 1969; service provisioning is the ~/.dotfiles repo's job — its task 129): call `POST /search` (DOI/ISBN/arXiv ID, preferred when Tier-3 discovery already has an identifier) or `POST /web` (URL fallback) to resolve full Zotero JSON BEFORE item creation, and pass that metadata through the create path. Degrade gracefully (current behavior) when the service is down, and surface which resolution path produced the record.

2. ZOTERO-MCP ADOPTION DECISION. Evaluate adding 54yyyu/zotero-mcp (de-facto standard, ~4.6k stars, hybrid mode = local-API reads + Web-API writes, add-by-DOI/URL/ISBN, OA-PDF cascade) as an INTERACTIVE complement for `/research --lit` sessions. The deterministic scripts remain the pipeline of record — community practice in 2026 is exactly this split. Deliverable is a recorded decision (adopt/defer with reasons); if adopted, registration scope and permission grants follow the grant-at-registration-scope principle already established for MCP servers in the ~/.dotfiles Claude configuration, and the registration itself lands there, not here.

3. STORAGE-QUOTA GATE. Stored-file uploads via the Web API count against the zotero.org 300 MB free tier (948 attachments already exist locally; the account's plan/usage is unverified). Verify quota state and encode an explicit auto-attach policy in the ingest bridge rather than discovering the ceiling by failure. Note the upload flow's `{"exists": 1}` content-hash dedup for PDF bytes.

4. ZOTERO 10 BACKEND-SWAP PLAN (plan, do NOT implement while 10 is beta). Zotero 10 ships native local writes (items + file upload) at `localhost:23119/api/` with consent-based local API keys via `POST /api/local/authorize` — eliminating cloud round-trips and the storage quota for attached files. Record the swap plan against the single write choke-point (`zotero-write.sh`) so callers never change; explicitly reject `/connector/saveItems` as a write contract (undocumented internal protocol).

=== ACCEPTANCE CRITERIA ===

1. Web-discovered sources get translation-server-resolved metadata when an identifier or URL is available, with honest surfacing of which resolution path was used and graceful degradation when the service is unreachable.
2. The MCP decision is recorded with reasons; no MCP registration or grants are hand-edited in this repo either way.
3. Auto-attach policy is explicit and quota-aware; no silent quota-exhaustion failure mode remains.
4. The Zotero 10 swap plan exists in the extension's context docs, names the choke-point, and states what stays constant for callers.

=== BINDING RULES ===

SOURCE-STORE RULE: all edits target agent-system/extensions/literature/**. NEVER edit the deployed .claude/** tree.
DELIVERABLE RULE: no task-number references in deliverables outside specs/**.

---

### 31. Opencode extensions sync mechanism
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED -- the original scope is a poor trade against all three refactor goals. Confirmed today: 804 git-tracked files under .opencode/extensions/ with no generation mechanism, and the live defect is real (.opencode/extensions/web/agents/web-implementation-agent.md:57 still teaches browser_verify_text_visible as a real tool, while the source at agent-system/extensions/web/agents/web-implementation-agent.md:72 explicitly RETRACTS it). But this task's sibling records that .opencode/ is not currently used, and building a full 804-file generator for an unused mirror buys no token efficiency, no performance, and no uniformity.
NARROW TO THREE THINGS: (1) fix the one fake-tool line so the mirror cannot teach a retracted tool as real; (2) add a drift-detection gate so the divergence is visible rather than silent -- this is the durable part; (3) document the divergence policy, i.e. whether .opencode/ is maintained, frozen, or slated for removal.
If the answer to (3) is 'frozen or removal', say so explicitly and this task shrinks further. Deciding that is worth more than generating the mirror.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Give the .opencode/extensions/ mirror a real generation path from the source store, so it stops silently drifting, and fix the live defect that drift has already produced.

SCALE -- MEASURE BEFORE PLANNING: .opencode/extensions/ is 804 git-tracked files mirroring 17 extensions (core, epidemiology, filetypes, formal, founder, latex, lean, memory, nix, nvim, present, python, slidev, typst, web, z3). An earlier estimate of '34 files' was wrong by more than an order of magnitude, so size the work against a fresh count, not against that figure. There is currently NO deploy or sync mechanism for this tree at all -- it is maintained by periodic manual 'mirror' commits, which is why the drift is structural rather than incidental.

THE LIVE DEFECT: .opencode/extensions/web/agents/web-implementation-agent.md (around line 57) still teaches `browser_verify_text_visible` as a real Playwright MCP tool. That tool does not exist. The source store at the corresponding path already retracts it explicitly. Any agent reading the .opencode copy is being taught to call a nonexistent tool. Note carefully: the source store deliberately RETAINS two mentions of that string as corrections that teach the name is fake -- a sync mechanism or cleanup pass must not mistake those for defects and 'fix' them into nonsense.

WORK: decide and implement how this tree is generated or verified. At minimum produce a drift-detection check that fails loudly when .opencode/extensions/ diverges from agent-system/extensions/**; a full generator is preferable if the two trees are genuinely meant to be identical. FIRST establish whether they ARE meant to be identical -- the trees use a different @-reference convention, so a naive byte-for-byte generator may be wrong. If a full sync is not appropriate, a drift-detection gate plus documented divergence rules is an acceptable and honest outcome; say which was chosen and why.

SCOPE BOUNDARY: another task already owns .opencode/scripts/* (dead command-router removal). Stay out of that subtree to avoid a conflicting edit.

VERIFICATION: the fake tool name no longer appears as usable guidance anywhere in .opencode/extensions/; the drift check runs clean, or reports exactly the divergences the chosen policy permits; the check is wired somewhere it will actually run rather than existing as an uninvoked script. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 30. Register obsidian memory mcp server
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: Task 29

**Description**: Register the obsidian-memory MCP server through the new manifest-driven .mcp.json mechanism, and grant its tools at the matching scope.

CURRENT STATE: memory/settings-fragment.json carries a dead `mcpServers` block declaring obsidian-memory (npx -y @anthropic-ai/obsidian-claude-code-mcp@latest, with env OBSIDIAN_WS_PORT). It registers nothing, because settings files are not a registration surface. The memory extension IS loaded in this repository, so unlike the five retired servers this one is wanted and should be made to work.

WORK: move the declaration to the new merge target so it lands in .mcp.json, with an explicit "type": "stdio". Then determine the server's ACTUAL tool names and add matching permission grants to the fragment, applying the grant-at-registration-scope rule. Do NOT guess the tool names and do NOT copy them from any existing documentation: enumerate them empirically by starting the server and issuing a tools/list request. This system has already shipped documentation instructing agents to call MCP tools that never existed, and a naming mismatch between a declared server name and its granted mcp__<name>__* prefix has already been found in another extension -- verify both the server name and every tool name against the running server.

RUNTIME PREREQUISITE, DO NOT PAPER OVER: this server needs OBSIDIAN_WS_PORT set and a running Obsidian instance with the companion plugin. If that prerequisite cannot be satisfied in this environment, wire the declaration correctly, document the prerequisite plainly in the memory extension README, and report the tool-name enumeration as NOT VERIFIED rather than inventing plausible names. A truthful 'could not verify' is the correct outcome here; a fabricated tool list is not.

VERIFICATION: .mcp.json contains the entry after a fixture deploy; `jq empty` on both edited files; doc-lint passes for the memory extension; every granted mcp__ tool name either matches a name observed from the running server or is explicitly marked unverified with the reason. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 29. Generate mcp json from extension manifests
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: Build the deploy-engine mechanism that lets an extension declare an MCP server and have it actually registered, by generating a project-scoped .mcp.json.

WHY THIS IS NEEDED: extensions currently express server declarations as `mcpServers` keys inside settings-fragment.json, which register nothing -- settings files are not a registration surface. Project-scoped .mcp.json IS a real registration surface, and it IS reachable by dispatched subagents (verified by direct experiment; the earlier belief to the contrary rested on a session-start snapshot confound). So the fix is to route declarations to a surface that works, not to abandon the idea of extensions declaring servers.

WORK: add a new manifest merge target -- e.g. `merge_targets.mcp` with a source file per extension -- that the deploy engine collects across all LOADED extensions and writes to the repository-root .mcp.json. Mirror the existing settings merge path (process_merge_targets / merge_settings in merge.lua) rather than inventing a second idiom: the existing path is an additive, idempotent deep-merge that does not clobber pre-existing content, and it deliberately targets a file that is NOT install-once, which is exactly the property needed here. Extend manifest_spec.lua so the new key validates.

REQUIREMENTS THE MECHANISM MUST SATISFY: (a) each generated server entry carries an explicit "type" field -- as of Claude Code v2.1.202 a remote server lacking an explicit type fails fast rather than failing silently, and all current declarations omit it; (b) unloading an extension must REMOVE its servers from .mcp.json, because an additive deep-merge alone never retracts, and a stale grant surviving an unload is an already-observed defect class in this system; (c) the operation must be idempotent -- deploying twice yields a byte-identical .mcp.json; (d) hand-written entries a user added to .mcp.json themselves must survive regeneration, or the file must clearly declare itself generated. Decide (d) explicitly and record the choice.

IMPORTANT CONTEXT: a project-scoped .mcp.json server requires workspace-trust approval before `claude mcp list` will read it (v2.1.196+), and a server added to .mcp.json is invisible to any ALREADY-RUNNING session. Both facts must be documented for users, or the mechanism will be reported as broken when it is working correctly. Verify against a fresh session or `claude -p`, never against the current one.

VERIFICATION: build a scratchpad fixture project, load an extension declaring a trivial stdio server, and confirm .mcp.json is generated correctly; confirm a second deploy is a no-op; confirm unloading removes the entry; confirm `claude mcp get <name>` in the fixture reports Scope: Project config. Do NOT deploy against this repository as part of verification. SOURCE-STORE RULE (binding): all edits target /home/benjamin/.config/nvim/agent-system/extensions/**. Never hand-edit any deployed .claude/** tree -- it is gitignored, disposable, and regenerated from the source store. DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 27. Remove the dead .opencode command router and its self-referential test scripts
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: .opencode/scripts/execute-command.sh is a command router that cannot execute anything and is called by nothing but its own tests. Delete it and the three test scripts that exist only to exercise it.

SCOPE NOTE -- THIS IS NOT THE SYNTAX-ERROR TASK. A duplicated case pattern in this file was already fixed in this repo; the file parses cleanly under `bash -n` today, and separately-tracked metrics-sync work already records that fix as done. Do not re-open it. The work here is deletion of a file that is dead for reasons unrelated to that syntax defect. If someone arrives expecting a one-line syntax repair, that repair has already landed.

MEASURED EVIDENCE (live, this repo, do not re-derive):

(1) Its runtime dependency has never existed. Both live branches of its case statement emit a heredoc that runs
        source "$OPENCODE_ROOT/context/core/patterns/command-integration.sh"
        execute_lean_command "$command_name" "$arguments"
    .opencode/context/core/patterns/command-integration.sh is absent. A repo-wide grep for `execute_lean_command` across all *.sh returns matches ONLY inside execute-command.sh's own two echo strings -- the function is defined nowhere. So every successful dispatch path terminates in a missing source file followed by an undefined function. The router has no working branch; the only reachable non-error outcome is the `*)` unknown-command arm that exits 1.

(2) Nothing invokes it. Files referencing execute-command.sh outside specs/**:
        .opencode/scripts/execute-command.sh    (itself: shebang comment + usage string)
        .opencode/scripts/test-execution-system.sh   (3 references)
        .opencode/scripts/test-execution.sh          (1 reference)
        .opencode/scripts/test-command.sh            (1 reference)
        .opencode/scripts/test-results.md            (prose describing those tests)
    opencode.json contains no reference to it. No file under lua/ references it or .opencode/scripts at all. There is no other live execution path wired to this router -- it is not the mechanism by which .opencode commands actually run.

(3) The three test scripts test nothing else. They are 49, 16, and 10 lines; every reference each one makes is to execute-command.sh. Deleting the router without them would leave three scripts whose entire purpose is invoking a file that no longer exists.

(4) It is stale. Last commit touching .opencode/scripts predates this task by roughly five months.

WORK:
  1. Delete .opencode/scripts/execute-command.sh.
  2. Delete .opencode/scripts/test-execution-system.sh, test-execution.sh, and test-command.sh.
  3. Resolve .opencode/scripts/test-results.md -- it documents results for the deleted tests. Decide explicitly between deleting it and reducing it to a note recording that the router was removed; do not leave it describing tests that no longer exist.
  4. Confirm .opencode/scripts/README.md needs no edit. A grep for execute-command / test-execution / test-command / test-results against it currently returns nothing, so the expected outcome is no change -- but state that you re-checked rather than assuming, since the README is the natural place for a stale pointer to survive.

EDIT TARGET (binding): edit .opencode/** directly. A find across agent-system/ for execute-command.sh and test-execution*.sh returns nothing -- .opencode/ has no source-store counterpart in this repo and is separately git-tracked, so the source-store/deploy-boundary rule that governs .claude/** does not apply here. Do NOT attempt to locate or edit an agent-system source for these files; there is none.

DOWNSTREAM PROPAGATION (in scope to decide, not necessarily to perform): four other repos carry copies of this same router -- Logos/Theory, protocol, ModelChecker, and OpenCode. All four still contain the duplicated case pattern and therefore FAIL `bash -n`, and all four are likewise missing command-integration.sh. This repo is the reload source, so the intended mechanism is that deleting here propagates on the next reload. Verify whether reload actually removes downstream files or only adds and overwrites them -- a reload that never deletes would leave four broken copies in place indefinitely, which is a materially different outcome. Record the finding either way; if propagation does not delete, say so plainly and note what a follow-up would need to cover rather than silently assuming the copies are handled.

ACCEPTANCE: after the change, a repo-wide grep for `execute-command.sh` outside specs/** returns zero hits (or only hits inside a deliberately-retained note from item 3, accounted for individually). `bash -n` passes across every remaining .opencode/scripts/*.sh -- it already does for all thirteen non-router scripts, so this must not regress. assess-repo-health.sh reports build_errors unchanged or lower, and specifically not higher, than its pre-change value; report both numbers rather than asserting improvement.

DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 22. Silence opencode fragment validation spam
- **Status**: [RESEARCHING]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
SUBSTANTIALLY OVERTAKEN, and the remaining half got worse. Re-verified today:
- Defect class (3) is FIXED. merge.lua:1002-1041 now degrades per-agent-key, reports every missing key rather than only the first, and no longer discards a whole fragment. Close it out; do not re-fix.
- Defect class (2) MOVED rather than got fixed. The archived path-fix work changed the lean fragment to reference .claude/agents/lean-research-agent.md instead of .claude/extensions/lean/agents/... -- but that path does not exist either.
- Defect class (1) is WORSE: 30 of 34 {file:} refs across all fragments now point at nonexistent files (was 16 of 18). Only nvim and nix resolve, because those are the extensions loaded in this repo -- which is itself the clue.
REFRAME around the one live question rather than patching paths again: SHOULD opencode-agents.json fragments reference a per-project deploy tree at all? Every {file:} ref is per-repo-deploy-dependent by construction, so any path fix is correct only for the extension set of whichever repo it was fixed in. That is why class (1) keeps regrowing. Answer the design question first; the path corrections fall out of it.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Silence and correct opencode-agents.json fragment validation spam on extension reload.

SYMPTOM (observed live): reloading .claude/ via <leader>al from a project with an
opencode.json.managed marker emits ~60 WARN notifications of the form "Extension 'X'
opencode-agents.json validation failed: Agent 'Y' references missing file: Z. Skipping
fragment." before "Resynced 12 extension(s)".

EMITTER: M.generate_opencode_json in lua/neotex/plugins/ai/shared/extensions/merge.lua
(vim.notify at ~line 994), gated on an opencode.json.managed marker check (~line 931), with
per-fragment validation by M.validate_opencode_fragment (~line 887), which resolves each agent
prompt's {file:PATH} against project_dir.

THREE DISTINCT DEFECT CLASSES (measured against a live project, not assumed):

(1) MISSING DEPLOY TARGETS -- 16 of 18 {file:} refs across python (2), present (5), nix (2),
and filetypes (7) point at .opencode/agent/subagents/*-agent.md files that were never
deployed. The .opencode/agent/subagents/ directory DOES exist and holds 15 agent files
(core, lean, latex, typst, math, logic, physics, formal, meta-builder, planner,
code-reviewer), but none for those four extensions. So this is a partial-deploy gap, not a
wholly absent tree.

(2) LEAN WRONG-PATH BUG (independent of any opencode policy decision) --
agent-system/extensions/lean/opencode-agents.json is the ONLY fragment using a .claude/ path
shape. It references .claude/extensions/lean/agents/lean-research-agent.md and
.claude/extensions/lean/agents/lean-implementation-agent.md, neither of which exists anywhere,
while the CORRECT files .opencode/agent/subagents/lean-research-agent.md and
.opencode/agent/subagents/lean-implementation-agent.md ALREADY EXIST on disk. This is a plain
mis-pathed reference, fixable on its own merits regardless of what is decided about opencode.

(3) NOTIFICATION SPAM AND SIMULTANEOUS UNDER-REPORTING -- the same 5 messages repeat ~12 times
because generation runs once per resynced extension rather than once per reload. Separately,
validate_opencode_fragment iterates with pairs() and returns on the FIRST missing ref, so only
one broken ref per extension is ever named, and WHICH one varies nondeterministically between
runs (python alternates python-research/python-implementation; filetypes alternates
scrape/filetypes-spreadsheet). The true breakage (18 refs) is therefore both over-announced in
aggregate and under-reported per message.

BINDING CONSTRAINT (from the user): .opencode/ is NOT currently used and may be excluded from
scope, BUT the fix MUST NOT damage or delete .opencode/ infrastructure. The opencode-agents.json
fragments, the validator function, the managed-marker gating, and the existing .opencode/ tree
must all survive intact so .opencode/ can be refactored in the future. Prefer suppressing or
gating the noise over removing the mechanism.

ACCEPTANCE: a <leader>al reload from a project carrying an opencode.json.managed marker
produces no validation-failure spam; the lean fragment's two refs resolve to real files;
whatever gating approach is chosen is documented; and no opencode fragment, no validator
function, and no .opencode/ file is deleted.

SOURCE-STORE RULE (binding): edit lua/** for the Lua emitter and agent-system/extensions/** for
the JSON fragments; never edit .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

---

### 20. Metrics sync measures a stale git index, inflating build_errors with phantom paths
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: /todo's repository-metrics sync runs before its git commit, so the health probe measures a tree whose git index still points at pre-move paths. Every archived-away file is counted as a structural failure, inflating build_errors and flipping status to "critical" on a healthy tree.

MEASURED EVIDENCE (live /todo run archiving 20 tasks, this is not inherited): Step 5.6 reported
    {"todo_count":44,"fixme_count":2,"build_errors":89,"status":"critical"}
Re-running the identical probe after the commit reported build_errors: 1. Of the 89, 88 were phantom and exactly 1 was real (a duplicated case pattern in .opencode/scripts/execute-command.sh, fixed separately; the probe then reported build_errors: 0, status "healthy"). So the reported figure was wrong by 88 and the derived status was wrong outright.

CONFIRMED ROOT CAUSE (two independent contributing defects, both must be addressed):

(1) The probe counts paths that no longer exist. assess-repo-health.sh's enumerate_by_glob builds candidates from `git ls-files -z -- "$glob"` and emits "$ROOT/$rel" with no existence check. Both structural loops then guard only emptiness, not existence:
        for f in "${SH_FILES[@]}"; do
          [ -n "$f" ] || continue
          if ! bash -n "$f" >/dev/null 2>&1; then errors=$((errors + 1)); fi
A path present in the index but absent on disk fails `bash -n` / `jq empty` for the trivial reason that there is no file to parse, and is scored as a structural error. This is caller-independent: any uncommitted rename, delete, or move produces the same inflation, so the probe is wrong on its own terms and not merely mis-sequenced. total_candidates is also inflated by the same phantom paths, which perturbs the degenerate zero-candidate branch that emits build_errors: null.

(2) /todo sequences the probe against exactly the tree state that triggers (1). commands/todo.md places Step 5.6 (Sync Repository Metrics, calling assess-repo-health.sh at the documented line) after Step 5D's directory moves and Step 5.7's vault operation, but before Step 6's `git add specs/` + commit. The one caller most likely to have just moved hundreds of files measures before recording them.

WORK:
  1. Make the probe existence-safe: skip candidates that are not present on disk, and exclude them from total_candidates so the null/"unknown" branch stays meaningful. Decide explicitly whether a phantom path should be silently skipped or surfaced as a separate diagnostic field (an index/worktree divergence is itself a signal worth reporting); state the decision and its reasoning.
  2. Re-sequence /todo so the metrics sync reflects the tree it actually commits. Either move Step 5.6 after Step 6, or have Step 6 re-sync afterward. Do not rely on fix 1 alone to paper over the ordering: fix 1 stops the false inflation, but a pre-commit measurement still describes a tree that is about to change.
  3. Check for other callers of assess-repo-health.sh with the same pre-commit exposure and note whether each is affected.

ACCEPTANCE: a /todo run that archives at least one task with a directory reports the same build_errors and status as an identical probe run immediately after its commit, and both match the true count for the tree. Demonstrate both directions -- a genuinely broken file must still be counted (a probe that can only ever report zero is not a fix), and a large batch of moved-but-uncommitted files must contribute zero. Report the measured before/after counts explicitly; never an unqualified green.

REGRESSION LOCK: add a test that stages nothing, moves a tracked *.sh or *.json to a new path, runs the probe, and asserts the moved file contributes no error. Without this the defect silently returns on the next refactor of enumerate_by_glob.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
=== ADDENDUM: SECOND LIVE REPRODUCTION, STRONGER THAN THE ORIGINAL (recorded during a real /todo run) ===

A /todo run archiving 25 tasks and moving 25 directories reproduced the defect with a cleaner
signal than the original measurement. Step 5.6, run at its documented position (after the
directory moves, before the Step 6 commit), reported:
    {"todo_count":44,"fixme_count":2,"build_errors":184,"status":"critical"}
The identical probe re-run immediately after the commit reported:
    {"todo_count":44,"fixme_count":2,"build_errors":0,"status":"healthy"}

ALL 184 WERE PHANTOM. The original measurement had 88 phantom of 89, leaving 1 real error that
slightly muddied the signal. This run has a true count of exactly 0, so the inflation is total
and the derived status is wrong in both fields with no residue to explain away. Use this as the
regression fixture: it is a cleaner before/after pair than the original.

The run also confirms the ordering half of the root cause independently of the existence-check
half. Nothing about the tree changed between the two probes except `git add specs/` plus a
commit, which converted 298 rename entries from index-vs-worktree divergence into recorded
state. No file content was edited between the two measurements.

WORKAROUND APPLIED DURING THAT RUN (not a fix, and it must not be mistaken for one): the operator
inverted Steps 5.6 and 6 by hand, committing first and then probing, so state.json recorded the
true value rather than the phantom one. That inversion is item 2 of this task's WORK list. It was
applied ad hoc to avoid persisting a known-false "critical" into repository_health; the durable
fix, including the existence-safety of item 1 and the regression lock, is still outstanding.

=== SECOND, INDEPENDENT DEFECT IN THE SAME FILE -- STEP 5A EXCEEDS MAX_ARG_STRLEN AT SCALE ===

Found in the same run, and in scope here because it is the same file and the same command. Step
5A ("Update archive/state.json") passes the ENTIRE archivable task set as one shell argument:
    --argjson tasks "$archivable_tasks_json"
Linux caps a SINGLE argument at MAX_ARG_STRLEN (128 KB, 32 pages), independent of the much larger
total ARG_MAX. Archiving 25 tasks produced a 175 KB value and the call died with:
    bash: /run/current-system/sw/bin/bash: Argument list too long
This is a hard failure of the archive insert, not a warning. It fired BEFORE any state was
written, so nothing was lost; had it fired between the archive insert and the Step 5B deletion,
the archivable set would have been removed from active_projects without ever landing in the
archive. The blast radius is therefore data loss, not merely an aborted run.

The trigger is total description bytes, not task count: these task descriptions routinely run
5-10 KB each, so the ceiling arrives at roughly 15-25 tasks. Any repository that lets completed
tasks accumulate will hit it, and it gets worse the longer /todo goes unrun -- the command
becomes unrunnable exactly when it is most needed.

state-write.sh offers no file-based input flag; it supports only --arg and --argjson, both
command-line. So the fix belongs in one of:
  (a) batch the Step 5A insert into chunks that stay under the per-argument ceiling (the ad hoc
      workaround used during this run: five batches of five tasks, 28-50 KB each, all succeeded);
  (b) add a file-based input flag to state-write.sh (jq --slurpfile / --rawfile) and have Step 5A
      use it, which fixes the whole class rather than this one call site;
  (c) have the Step 5A filter read the source tasks itself rather than receiving them as an
      argument.
Direction (b) is worth weighing beyond this call site: any other caller passing a large --argjson
payload through state-write.sh has the same latent ceiling.

ACCEPTANCE FOR THIS SECOND DEFECT: a /todo run archiving at least 30 tasks with realistic
multi-kilobyte descriptions completes its archive insert without an argument-length failure, and
the archive insert and the active_projects deletion cannot end up on opposite sides of a partial
failure.

---

### 14. Prevent implementation-agent fan-out from returning non-terminal status and stale plan markers
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: === REVISED 2026-08-24 (refactor survey) ===
NARROWED: roughly half of this task already landed with the handoff-identity work and must not be redone. skill-orchestrate/SKILL.md:2374,2384 now treats in_progress (and null/empty) as OFF-SCHEMA rather than routing it toward failed_tasks, and orchestrate-recover-outcome.sh:233 emits a clean STATUS_IN_PROGRESS verdict. Verified in the source store today.
WHAT REMAINS is the AGENT-CONTRACT side only, and it is untouched: general-implementation-agent.md contains NO fan-out prohibition, and NO requirement that a sub-agent which commits a phase must update that phase's marker in the same commit. Both gaps are what produced the original symptom -- dispatches fanning out to phase sub-agents and terminating before writing a terminal status, leaving plan markers reading [NOT STARTED] against landed commits.
Rescope to those two contract additions. Do not re-litigate the status-vocabulary half.
=== ORIGINAL DESCRIPTION FOLLOWS ===
Two dispatches in a single batch fanned out to phase sub-agents and terminated before writing a terminal status, costing a recovery cycle each. Recorded as err_1786344051474_RcIhk6.

OBSERVED FAILURE MODE: a dispatched implementation agent spawned per-phase sub-agents, returned while they were still running, and left .return-meta.json at status=in_progress. Per context/formats/return-metadata-file.md that value is early-metadata-only and never a legal terminal dispatch outcome, so orchestrate-recover-outcome.sh correctly declines it (reason STATUS_IN_PROGRESS). The orchestrator contract for an unresolvable dispatch is failed_tasks - which would have been WRONG here, since 6 of 10 phases had in fact been committed. Correct handling came from rules/error-handling.md Delegation Interrupted Recovery (keep status, resume), not from the orchestrator stage contract.

COMPOUNDING DEFECT - STALE PLAN MARKERS: the sub-agents committed phases 3, 4, 5 and 7 but left every one of those phase markers reading [NOT STARTED]. Because the orchestrator phase-marker recovery grep reads exactly those markers, it would have reported 2/10 against a true 6/10. A resume driven by markers alone would have redone committed work. Recovery only succeeded because the actual state was reconstructed from git log and diffs instead.

TWO INDEPENDENT QUESTIONS, BOTH IN SCOPE:
  1. Should a dispatched implementation agent fan out to sub-agents at all? If yes, it must still write a terminal status covering its childrens work; if no, the prohibition belongs in the agent contract, not in per-dispatch prompt text (the workaround used during the incident).
  2. Should a sub-agent that commits a phase be required to update that phases marker in the same commit? Markers and commits diverging silently is the deeper defect - it degrades the recovery path for every future interrupted dispatch, not just fan-out ones.

CONSIDER ALSO: whether the orchestrator should treat status=in_progress plus evidence of committed phase work as PARTIAL/resume rather than routing it toward failed_tasks, so correct handling does not depend on an operator noticing.

ACCEPTANCE: an interrupted fan-out dispatch is either impossible by contract, or leaves markers and terminal status accurate enough that resume needs no manual git archaeology.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.

=== REVISED 2026-08-24 (second live occurrence, extension-agent gap) ===
RECURRED, AND THE CONTRACT GAP IS WIDER THAN THIS TASK'S CURRENT SCOPE. A seven-task lean4 batch
orchestrated in a separate consumer repo reproduced this exact failure mode TWICE in one
implementation cycle: two of seven dispatches performed real work, committed it, and then
terminated WITHOUT writing a terminal handoff, leaving .return-meta.json at status=in_progress.
orchestrate-recover-outcome.sh correctly declined both (STATUS_IN_PROGRESS); both needed a
re-dispatch cycle to resolve, exactly as the original incident did.

SCOPE CORRECTION (the actionable part). Both offending dispatches ran
extensions/lean/agents/lean-implementation-agent.md, NOT
extensions/core/agents/general-implementation-agent.md -- the only agent contract this task's
file_scope currently names. The terminal-status requirement is therefore missing from the
EXTENSION implementation agents as well as the core one, and fixing only the core file would
leave the reproducing path untouched. file_scope is extended accordingly to the lean pair. Treat
the core agent as the normative contract and the extension agents as required conformers; if a
shared include or a single normative statement referenced by all implementation agents is the
better mechanism, prefer that over copying the same paragraph into four files.

MARKER DIVERGENCE RECURRED IN THE OPPOSITE DIRECTION -- fold into question 2, do not treat as a
separate concern. The original incident recorded markers UNDER-claiming (phases committed, markers
still [NOT STARTED]). This batch recorded the inverse: one task's plan carried five of seven
phases marked [COMPLETED] while its sole declared file_scope target was UNMODIFIED against HEAD --
markers OVER-claiming against work that had not landed. A resume driven by those markers would
have skipped real work rather than redone it. Both signs share one root cause, which question 2
already names: markers and committed reality are allowed to diverge silently. Any fix must be
bidirectional -- a marker must not be promotable without the corresponding work being verifiable,
and committed work must not leave its marker unpromoted. The over-claim direction was only caught
because the orchestrator cross-checked the marker count against the working tree; a fix that
merely tightens promotion-on-commit would not have caught it.

WHAT IS ALREADY GOOD AND MUST NOT BE UNDONE. The re-dispatch path worked: both tasks resumed from
their real state and completed, and the resumed dispatches -- when explicitly instructed to write
the handoff FIRST and to re-verify prior phase markers with a real build rather than trust them --
both reported correctly and downgraded nothing falsely. That per-dispatch prompt text is the
workaround this task exists to retire; it is evidence the contract wording works, not a substitute
for putting it in the contract.

ACCEPTANCE (extends, does not replace, the original): the terminal-status requirement and the
fan-out resolution apply to extension implementation agents as well as the core one, demonstrated
against a lean4 dispatch; and marker/reality divergence is caught in BOTH directions.

---

### 13. Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: core-agent-system
- **Dependencies**: None

**Description**: The acceptance criterion "gate-out reports zero format errors and zero auto-repaired fields" is unverifiable as written, because no reporting surface exists. Recorded as err_1786350581339_Q4VnFy.

TRACED PATH: command-gate-out.sh (134 lines) has no counter, aggregate, or exit-code surface for auto-repairs; its only related line is a comment. The real repair path is
    command-gate-out.sh -> skill_validate_task_artifacts (skill-base.sh) -> validate-artifact.sh "$f" "$type" --fix 2>/dev/null
validate-artifact.sh DOES emit a terminal line of the form "[FIXED] N field(s) auto-repaired, E error(s), W warning(s) remaining" and exits 2. But skill_validate_task_artifacts discards stderr, collapses every non-zero exit into a single generic non-blocking WARNING carrying no numeric detail, and always returns 0. command-gate-out.sh therefore receives no signal at all.

PRIMARY HAZARD (the reason this is not merely cosmetic): --fix MUTATES THE ARTIFACT IN PLACE. A repair both happens and goes uncounted, so an artifact can be silently rewritten with nothing anywhere recording that it was. The instrumentation gap and the silent-mutation hazard are the same defect seen from two ends.

WORK:
  1. Propagate validate-artifact.sh fix/error/warning counts through skill_validate_task_artifacts instead of discarding them.
  2. Give command-gate-out.sh a reportable surface for those counts.
  3. Decide explicitly whether --fix should remain in-place-mutating on the gate-out path, or whether a repair should be reported and left for a human. State the decision and its reasoning.

ACCEPTANCE: a task whose artifact required auto-repair produces a gate-out report naming a nonzero repaired-field count, and a task needing none reports zero. Both directions must be demonstrated - a report that can only ever say zero is not instrumentation.

SOURCE-STORE RULE (binding): edit agent-system/extensions/**, never .claude/**.
DELIVERABLE RULE: no task numbers in deliverables outside specs/**.
