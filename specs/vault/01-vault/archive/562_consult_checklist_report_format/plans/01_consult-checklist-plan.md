# Implementation Plan: Upgrade Legal Analysis Agent to Interactive Checklist Format

- **Task**: 562 - consult_checklist_report_format
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/562_consult_checklist_report_format/reports/01_consult-checklist-research.md
- **Artifacts**: plans/01_consult-checklist-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rewrite Stages 3-6 of `legal-analysis-agent.md` to replace the flat translation-analysis report with an interactive checklist workflow. Stage 3 becomes a silent internal analysis pass (no output to user), Stage 4 presents findings one-at-a-time via AskUserQuestion with Accept/Reject/Modify decisions, Stage 5 offers a revision pass over all decisions, and Stage 6 compiles the final checklist report with per-finding decision checkboxes and a Revision Checklist table. After implementing in the nvim extension, the file is copied identically to the Vision project.

### Research Integration

The research report (01_consult-checklist-research.md) provides:
- Exact target report format extracted from the Vision example at `specs/203_legal_consult_revisions/reports/01_legal-consult-revisions.md`
- Decision checkbox rendering rules for all 7 decision types (Accept, Reject, Modify, Address, Skip, Note for later, Accept with notes)
- Revision Checklist table inclusion/exclusion rules
- AskUserQuestion design patterns for per-finding presentation
- Confirmation that only 2 files need changes (same agent file in two repos)
- Stage-by-stage flow design with pseudocode for internal data structures

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

### Literature Source Mapping

No literature source referenced.

## Goals & Non-Goals

**Goals**:
- Replace the flat translation-analysis report format with an interactive checklist consultation
- Present findings one-at-a-time via AskUserQuestion grouped by four canonical categories
- Compile a final checklist report with per-finding `**Decision**:` checkbox lines
- Include a Revision Checklist table of actionable items at report end
- Keep Stages 0, 1, 2, 7 unchanged (except minor metadata additions to Stage 7)
- Ensure both copies of the agent file (nvim extension and Vision project) are identical

**Non-Goals**:
- Changing the `/consult` command file or `skill-consult/SKILL.md` (contract is unchanged)
- Changing any context files (legal-reasoning-patterns.md, legal-frameworks.md, legal-planning.md)
- Resolving the pre-existing "Agent tool" vs "Task tool" divergence in skill wrappers
- Implementing task creation behavior (that is task 563 scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent instructions become too long, exceeding context budget | M | L | Keep stage descriptions concise; use templates and examples inline rather than duplicating the research report's full detail |
| Inconsistency between nvim and Vision copies after implementation | M | M | Phase 3 does an explicit copy and diff verification |
| AskUserQuestion format details are misspecified | M | L | Research report contains exact option strings and flow; plan reproduces them verbatim for implementation agent |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Rewrite Stages 3-4 (Internal Analysis + Interactive Per-Finding Loop) [COMPLETED]

**Goal**: Replace the current Stage 3 (Read and Translate) and Stage 4 (Reframe and Probe) with the new silent analysis pass and interactive per-finding AskUserQuestion loop.

**Tasks**:
- [ ] Replace Stage 3 heading and content. New heading: `### Stage 3: Internal Analysis (Read and Identify All Findings)`. New content must specify:
  - Read the document (file_path) or use inline_text; skip to Stage 4 for design_question
  - Identify ALL findings silently without presenting any output to the user
  - Organize findings into four category arrays: `translation_gaps[]`, `credibility_concerns[]`, `missing_concerns[]`, `strengths_to_preserve[]`
  - Each finding stores: `category`, `number` (e.g., "1.1"), `title`, `problem`, `current_quotes` (array of `{location, text}`), `suggested`, `note` (optional), `line_refs`, `priority` (High/Medium/Low)
  - Strengths entries store: `element_name`, `line_refs`, `explanation`
  - The five gap categories from legal-reasoning-patterns.md remain available as internal classification tools within Problem descriptions, but the top-level organization uses the four report categories
  - Explicitly state: "Do NOT present findings to the user during this stage. Stage 3 is a silent internal pass."
- [ ] Replace Stage 4 heading and content. New heading: `### Stage 4: Interactive Per-Finding Presentation`. New content must specify:
  - Present findings ONE AT A TIME, grouped by category, in order: Translation Gaps, Credibility Concerns, Missing Concerns, Strengths to Preserve
  - **Category announcement** (text output, not AskUserQuestion) before each category's first finding. Format:
    ```
    --- {Category Name} ({N} items) ---

    {Brief description of what this category covers.}
    I will present each finding and ask for your decision.
    ```
    Category descriptions:
    - Translation Gaps: "These are places where the document's language diverges from how attorneys would interpret it."
    - Credibility Concerns: "These are claims that may trigger attorney skepticism or require stronger grounding."
    - Missing Concerns: "These are topics an attorney buyer would likely raise that the document does not address."
  - **Per-finding AskUserQuestion for Translation Gaps and Credibility Concerns**:
    ```
    AskUserQuestion:
      title: "Finding {N}.{M}: {Title} ({current} of {total})"
      message: |
        **Problem**: {problem description}

        **Current ({location})**: "{quoted text}"
        [additional Current lines if multiple instances]

        **Suggested**: {suggested reframing}

        [**Note**: {note if applicable}]

        What is your decision for this finding?
      options:
        - "Accept -- apply the suggested reframing as stated"
        - "Reject -- keep the current language, no change needed"
        - "Modify -- I want a different change (please explain in your response)"
    ```
  - **Per-finding AskUserQuestion for Missing Concerns**:
    ```
    AskUserQuestion:
      title: "Missing Concern 3.{M}: {Title} ({current} of {total})"
      message: |
        **Gap**: {gap description}

        **Possible addition**: {suggested addition}

        How would you like to handle this?
      options:
        - "Address -- I want to add something to handle this concern"
        - "Skip -- this concern does not apply or is intentionally omitted"
        - "Note for later -- flag this for future revision"
    ```
  - **Handling "Modify" with no notes**: If user selects "Modify" but provides no explanation text, re-ask with a free-text-only question:
    ```
    AskUserQuestion:
      title: "Please describe your modification for finding {N}.{M}"
      message: "You selected Modify for '{finding_title}'. What change would you like to make instead of the suggested reframing?"
    ```
  - **Strengths to Preserve**: Present all at once as text output (not interactive) after all other findings:
    ```
    --- Strengths to Preserve ---

    The following elements are strong and should not be weakened during revision:

    - **{Element}** ({lines}): {explanation}
    ...

    These require no decision -- they are informational.
    ```
  - **Decision tracking**: Maintain an in-memory decisions list:
    ```
    decisions = [
      {
        category: "translation_gaps",
        finding_number: "1.1",
        finding_title: "...",
        decision: "Accept" | "Reject" | "Modify" | "Address" | "Skip" | "Note for later",
        user_notes: "",
        line_refs: "272, 451",
        priority: "High"
      },
      ...
    ]
    ```
  - **Progress indicator**: Question titles must include `({current} of {total})` where `{total}` counts all interactive findings (Translation Gaps + Credibility Concerns + Missing Concerns; excludes Strengths)

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/agents/legal-analysis-agent.md` -- Replace Stage 3 section (lines ~126-149) and Stage 4 section (lines ~151-181)

**Verification**:
- Stage 3 heading reads "Internal Analysis" and contains explicit "Do NOT present findings" instruction
- Stage 4 heading reads "Interactive Per-Finding Presentation"
- AskUserQuestion format includes all three option strings for each category type
- Strengths to Preserve section describes text-only output (no AskUserQuestion)
- Progress indicator format is specified in the question title pattern
- "Modify" re-ask fallback is included

---

### Phase 2: Rewrite Stages 5-6, Update Stage 7 and Critical Requirements [COMPLETED]

**Goal**: Add the revision pass (Stage 5), compile checklist report (Stage 6), update Stage 7 metadata fields, and update the MUST DO / MUST NOT lists to reflect the new flow.

**Tasks**:
- [ ] Replace Stage 5 heading and content. New heading: `### Stage 5: Revision Pass`. New content must specify:
  - Present a single AskUserQuestion showing all decisions as a summary:
    ```
    AskUserQuestion:
      title: "Revision Pass"
      message: |
        All {N} findings have been reviewed. Here is a summary of your decisions:

        **Translation Gaps** ({count} items):
        - 1.1 {title}: {decision}
        - 1.2 {title}: {decision}
        ...

        **Credibility Concerns** ({count} items):
        - 2.1 {title}: {decision}
        ...

        **Missing Concerns** ({count} items):
        - 3.1 {title}: {decision}
        ...

        Would you like to revisit any finding before I compile the report?
      options:
        - "No -- compile the report with these decisions"
        - "Yes -- revisit finding {number} (specify in your response)"
    ```
  - If user selects "Yes" and specifies a finding number, re-present that finding with its current decision shown, allow the user to change it, then return to the revision pass question
  - If user selects "No", proceed to Stage 6
- [ ] Replace Stage 6 heading and content. New heading: `### Stage 6: Compile Checklist Report`. New content must specify:
  - Report path: determined by skill wrapper (same as current)
  - Exact report template:
    ```markdown
    # Legal Design Consultation: {document title or topic}

    **File**: `{file_path or "inline text" or "design question"}`
    **Date**: {YYYY-MM-DD}
    **Source**: Legal design partner consultation (attorney perspective)

    ---

    ## Summary

    {2-3 sentence summary: what was reviewed, how many findings identified, what categories of issues found.}

    ---

    ## 1. Translation Gaps

    ### 1.{M} {Finding Title} -- {line references}

    **Problem**: {problem description}

    **Current ({location})**: "{quoted text}"

    **Suggested**: {suggested reframing}

    [**Note**: {note if applicable}]

    **Decision**: {checkbox line based on user decision}

    ---

    [repeat for each translation gap finding]

    ## 2. Credibility Concerns

    [same structure as Translation Gaps]

    ## 3. Missing Concerns

    ### 3.{M} {Finding Title}

    **Gap**: {gap description}

    **Possible addition**: {suggested addition}

    **Decision**: {checkbox line -- Address/Skip/Note format}

    ---

    ## 4. Strengths to Preserve

    {Bulleted list -- no decision checkboxes}

    - **{Element}** ({lines}): {explanation}

    ---

    ## Revision Checklist

    | # | Item | Lines | Priority | Status |
    |---|------|-------|----------|--------|
    | 1 | {title} | {line_refs} | {priority} | [ ] |

    ---

    *Advisory: This consultation models attorney thinking but does not constitute legal advice. {domain-specific note.}*
    ```
  - **Decision checkbox rendering rules** (include this table in the agent):

    | User Decision | Rendered Checkbox Line |
    |--------------|----------------------|
    | Accept | `**Decision**: [x] Accept  [ ] Reject  [ ] Modify` |
    | Reject | `**Decision**: [ ] Accept  [x] Reject  [ ] Modify` |
    | Modify (with notes) | `**Decision**: [ ] Accept  [ ] Reject  [x] Modify: {user_notes}` |
    | Address | `**Decision**: [x] Address  [ ] Skip  [ ] Note for later` |
    | Skip | `**Decision**: [ ] Address  [x] Skip  [ ] Note for later` |
    | Note for later | `**Decision**: [ ] Address  [ ] Skip  [x] Note for later` |

  - **Revision Checklist table rules**:
    - Include: Accept, Modify, Address decisions (require edits)
    - Include: Note-for-later with priority=Low and "(deferred)" suffix on title
    - Exclude: Reject, Skip (no action needed)
    - Sequential numbering (1, 2, 3...), not finding numbers
    - Status column always `[ ]`
- [ ] Update Stage 7 metadata to add `findings_presented` and `decisions` fields:
  ```json
  {
    "metadata": {
      "...existing fields...",
      "findings_presented": "{N}",
      "decisions": {
        "accepted": "{count}",
        "rejected": "{count}",
        "modified": "{count}",
        "addressed": "{count}",
        "skipped": "{count}"
      }
    }
  }
  ```
- [ ] Update Critical Requirements section -- add to MUST DO:
  - "Present findings ONE AT A TIME via AskUserQuestion in Stage 4"
  - "Build all findings silently in Stage 3 before any user presentation"
  - "Use the four canonical categories in order: Translation Gaps, Credibility Concerns, Missing Concerns, Strengths to Preserve"
  - "Include per-finding `**Decision**:` checkbox lines in the compiled report"
  - "Include Revision Checklist table at end of report"
- [ ] Update Critical Requirements section -- add to MUST NOT:
  - "Present findings to the user during Stage 3 (silent internal pass only)"
  - "Batch multiple findings in one AskUserQuestion call during Stage 4"
  - "Skip the revision pass in Stage 5"
  - "Use the old flat translation-analysis report format in Stage 6"
- [ ] Remove or update any references to the old Stage 3 "translation analysis" output, old Stage 4 "Socratic probing" flow, and old Stage 5 "consistency check" in the Push-Back Patterns, Error Handling, or other sections. Specifically:
  - The Error Handling section's "User Abandons Dialogue" partial_progress should reference the new stage names (e.g., `"stage": "interactive_presentation"` instead of `"reframe_and_probe"`)
  - The "No Document Provided" error handling should note that design_question input skips Stage 3 entirely and goes to a simplified interactive flow

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/agents/legal-analysis-agent.md` -- Replace Stage 5 section (lines ~183-190), Stage 6 section (lines ~192-245), update Stage 7 metadata block, update Critical Requirements section, update Error Handling section

**Verification**:
- Stage 5 contains a single AskUserQuestion with decision summary and "No/Yes" options
- Stage 6 report template matches the target format with all four numbered sections
- Decision checkbox rendering rules table is present
- Revision Checklist table rules specify inclusion/exclusion criteria
- Stage 7 metadata includes `findings_presented` and `decisions` fields
- MUST DO list includes "present findings ONE AT A TIME" and "build all findings silently"
- MUST NOT list includes "present findings during Stage 3" and "batch multiple findings"
- Error Handling references updated stage names

---

### Phase 3: Sync to Vision Project and Verify [COMPLETED]

**Goal**: Copy the modified agent file to the Vision project and verify both copies are identical.

**Tasks**:
- [ ] Copy the modified file:
  ```bash
  cp /home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md \
     /home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md
  ```
- [ ] Verify files are identical:
  ```bash
  diff /home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md \
       /home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md
  ```
  Expected output: no differences (empty diff output)
- [ ] Verify the Vision copy has all the new stage headings by checking for key markers:
  - "Stage 3: Internal Analysis"
  - "Stage 4: Interactive Per-Finding Presentation"
  - "Stage 5: Revision Pass"
  - "Stage 6: Compile Checklist Report"

**Timing**: 10 minutes

**Depends on**: 2

**Files to modify**:
- `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` -- Overwritten with nvim extension copy

**Verification**:
- `diff` between both files produces no output
- Both files contain the four new stage headings

## Testing & Validation

- [ ] Verify the nvim extension agent file contains all four new stage headings (Stage 3: Internal Analysis, Stage 4: Interactive Per-Finding Presentation, Stage 5: Revision Pass, Stage 6: Compile Checklist Report)
- [ ] Verify Stages 0, 1, 2 are unchanged by comparing with the pre-edit version
- [ ] Verify Stage 7 metadata includes `findings_presented` and `decisions` fields
- [ ] Verify Critical Requirements MUST DO list includes interactive presentation requirements
- [ ] Verify Critical Requirements MUST NOT list includes silent Stage 3 requirement
- [ ] Verify the decision checkbox rendering rules table is present in Stage 6
- [ ] Verify the Revision Checklist table inclusion/exclusion rules are present
- [ ] Verify both files (nvim and Vision) are identical via diff

## Artifacts & Outputs

- `specs/562_consult_checklist_report_format/plans/01_consult-checklist-plan.md` (this file)
- `.claude/extensions/founder/agents/legal-analysis-agent.md` (modified)
- `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` (synced copy)

## Rollback/Contingency

Both files are under git version control. If the implementation introduces problems:
- Revert nvim extension agent: `git checkout -- .claude/extensions/founder/agents/legal-analysis-agent.md`
- Revert Vision agent: `cd /home/benjamin/Projects/Logos/Vision && git checkout -- .claude/agents/legal-analysis-agent.md`

The command file (`consult.md`) and skill wrapper (`skill-consult/SKILL.md`) are untouched, so the dispatch contract remains valid regardless of agent content.
