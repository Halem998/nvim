# Research Report: Task #562

**Task**: 562 - consult_checklist_report_format
**Started**: 2026-05-13T00:00:00Z
**Completed**: 2026-05-13T00:30:00Z
**Effort**: Medium (focused file-reading research, no web search required)
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/Projects/Logos/Vision/specs/203_legal_consult_revisions/reports/01_legal-consult-revisions.md` (example target report)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md` (primary file to change)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/consult.md` (command file)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-consult/SKILL.md` (skill wrapper)
- `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` (Vision mirror)
- `/home/benjamin/Projects/Logos/Vision/.claude/commands/consult.md` (Vision mirror)
- `/home/benjamin/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` (Vision mirror)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/legal-planning.md`
**Artifacts**:
- `specs/562_consult_checklist_report_format/reports/01_consult-checklist-research.md`
**Standards**: report-format.md, artifact-management.md

---

## Executive Summary

- The example report at Vision/specs/203_legal_consult_revisions/reports/01_legal-consult-revisions.md defines the exact target format: findings organized in four numbered category sections (Translation Gaps, Credibility Concerns, Missing Concerns, Strengths to Preserve), each finding with a `**Decision**: [ ] Accept  [ ] Reject  [ ] Modify: {notes}` checkbox line, and a final Revision Checklist table with `[ ]` status column.
- Two files need modification per repo: the `legal-analysis-agent.md` (primary — Stages 3-6 rewritten) and NOTHING ELSE — the `consult.md` command and `skill-consult/SKILL.md` wrapper require NO changes because the command/skill contract (input → agent delegation → report artifact) is unchanged.
- The new agent flow: Stage 3 reads the document and identifies ALL findings internally (no interactive presentation yet), Stage 4 presents findings ONE AT A TIME per category via AskUserQuestion with Accept/Reject/Modify options, Stage 5 offers a revision pass over any finding, Stage 6 compiles the final checklist report from all decisions.
- For "Modify" decisions, the agent captures the user's modification text in the same AskUserQuestion response — the question offers three labeled options and asks for notes if Modify is selected.
- The Vision project mirror files are IDENTICAL to the nvim extension files — both repos must receive the same change.
- The `legal-planning.md` and `legal-frameworks.md` context files are UNAFFECTED — they support the analysis content, not the report format.
- No changes are needed to `consult.md`, `skill-consult/SKILL.md`, `legal-reasoning-patterns.md`, `legal-frameworks.md`, or `legal-planning.md`.

---

## Context & Scope

### What Is Being Changed

The `/consult --legal` pipeline currently produces a flat translation-analysis report (Stage 6 current format). The goal is to upgrade the agent so that findings are presented interactively one-at-a-time during the consultation session, the user makes Accept/Reject/Modify decisions, and the final compiled report uses the checklist format seen in the example report.

Task 562 scope is limited to: **report format** and **interactive finding presentation flow** in the agent. Task 563 (not yet created at research time) handles task creation behavior — that is explicitly out of scope here.

### What Is NOT Being Changed

- The Socratic dialogue in Stage 2 (user intent gathering) — preserved exactly as-is.
- The `consult.md` command — it dispatches to skill-consult with the same contract.
- The `skill-consult/SKILL.md` wrapper — the delegation and postflight logic is unchanged.
- All context files (legal-reasoning-patterns.md, legal-frameworks.md, legal-planning.md).
- The four-category analysis framework (Translation Gaps, Credibility Concerns, Missing Concerns, Strengths to Preserve) — this is inferred from the example report and should become the canonical category structure.

---

## Findings

### 1. Exact Format Analysis: The Example Report

The example report at `/home/benjamin/Projects/Logos/Vision/specs/203_legal_consult_revisions/reports/01_legal-consult-revisions.md` establishes the following precise structural elements:

#### 1.1 Header Block
```markdown
# Legal Design Consultation: {document title}

**File**: `{file path}`
**Date**: {YYYY-MM-DD}
**Source**: Legal design partner consultation (attorney perspective)

---

## Summary

{2-3 sentence overview of what was reviewed and what categories of findings were identified}

---
```

#### 1.2 Category Sections (Four Fixed Categories in Order)

The four categories are numbered sections, always appearing in this order:
1. Translation Gaps
2. Credibility Concerns
3. Missing Concerns
4. Strengths to Preserve

#### 1.3 Finding Entry Format (Categories 1-2)

Each finding within Translation Gaps and Credibility Concerns has this exact structure:

```markdown
### {N}.{M} {Brief Finding Title} -- {line references or "throughout"}

**Problem**: {One-paragraph description of why attorneys would read this as problematic.}

**Current ({location})**: "{exact quoted text from document}"
**Current ({location})**: "{additional instances if applicable}"

**Suggested**: {Specific replacement language or approach.}

**Note**: {Optional. Additional context, cross-references, or nuances.}

**Decision**: [ ] Accept  [ ] Reject  [ ] Modify
```

For findings with a user decision already made (example shows a completed consultation), the decision line has an `x` in the selected checkbox and may have notes after "Modify:":
```markdown
**Decision**: [x] Accept  [ ] Reject  [ ] Modify
**Decision**: [ ] Accept  [ ] Reject  [x] Modify: {user's modification notes}
**Decision**: [x] Accept: {extended user notes}  [ ] Reject  [ ] Modify
```

Key observation: The decision checkbox format uses `[x]` for selected and `[ ]` for unselected. User notes can appear either after "Modify:" on the same line OR after "Accept:" for cases where the user accepted with clarifying notes.

#### 1.4 Missing Concerns Format (Category 3)

Missing Concerns entries use a different structure — no Decision line, just Gap + Possible addition:

```markdown
### 3.{M} {Brief Title}

**Gap**: {What the document does not address.}

**Possible addition**: {What could be added or addressed.}
```

The Missing Concerns category raises issues for the user to consider; they do not necessarily get Accept/Reject/Modify treatment in the same way. However, per the user's design decisions, the interactive flow should still present these findings one-at-a-time. For Missing Concerns, the decision options should be adapted (e.g., "Address / Skip / Note for later").

#### 1.5 Strengths to Preserve Format (Category 4)

```markdown
## 4. Strengths to Preserve

The consultation identified these as the document's strongest elements -- do not weaken them during revision:

- **{Element name}** ({line references}): {Brief explanation of why this is a strength.}
- ...
```

No Decision checkboxes for Strengths to Preserve — these are informational, presented as a bulleted list.

#### 1.6 Revision Checklist Table

```markdown
## Revision Checklist

| # | Item | Lines | Priority | Status |
|---|------|-------|----------|--------|
| 1 | {Finding title} | {line refs} | High | [ ] |
| 2 | {Finding title} | {line refs} | Medium | [ ] |
...
```

Priority values observed: High, Medium, Low.
Status column uses `[ ]` (always unchecked in the compiled report — user marks these manually in their editor after actually making edits).

#### 1.7 Advisory Footer

```markdown
---

*Advisory: {Brief advisory notice about attorney review.}*
```

---

### 2. File Inventory: What Changes Where

#### Primary Change: `legal-analysis-agent.md`

**Two copies — both must be updated identically:**

| File | Location |
|------|----------|
| `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md` | nvim extension |
| `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` | Vision project |

**What changes**: Stages 3-6 are substantially rewritten. Stage 0 (early metadata), Stage 1 (parse context), Stage 2 (understand intent), Stage 7 (write metadata and return summary) are UNCHANGED. The agent frontmatter (name, description, model, tools, context references, Push-Back Patterns, Error Handling, and Critical Requirements sections) also need minor updates to reflect the new flow.

#### No Change Required

| File | Reason No Change Needed |
|------|------------------------|
| `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/consult.md` | Command dispatches to skill-consult with same contract; report format change is internal to agent |
| `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-consult/SKILL.md` | Thin wrapper; delegation context and postflight unchanged |
| `/home/benjamin/Projects/Logos/Vision/.claude/commands/consult.md` | Same as above |
| `/home/benjamin/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` | Same as above |
| All context files (legal-reasoning-patterns.md, legal-frameworks.md, legal-planning.md) | Support content analysis, not report format |

**Summary**: 2 files to modify (same agent file in two repos).

---

### 3. Stage-by-Stage Flow Design

#### Current Flow (Stages 3-6)

- **Stage 3: Read and Translate** — Reads the document, processes each claim, presents a structured translation analysis report to the user as text output.
- **Stage 4: Reframe and Probe** — Socratic dialogue with AskUserQuestion (one question at a time) to probe specific claims.
- **Stage 5: Validate Consistency** — Internal check, presents inconsistencies if found.
- **Stage 6: Generate Consultation Report** — Writes the flat translation-analysis report to disk.

#### New Flow (Stages 3-6)

##### Stage 3: Internal Analysis (Read and Identify ALL Findings)

The agent reads the document and identifies ALL findings internally WITHOUT presenting them yet. This is a silent internal pass.

For each finding, the agent builds an internal data structure:
```
{
  category: "translation_gaps" | "credibility_concerns" | "missing_concerns" | "strengths_to_preserve",
  number: "1.1", "1.2", ... "2.1", etc.,
  title: "Brief Finding Title",
  problem: "...",
  current_quotes: [{"location": "line N", "text": "..."}],
  suggested: "...",
  note: "...",  // optional
  line_refs: "272, 451, 851" or "throughout",
  priority: "High" | "Medium" | "Low"
}
```

After reading the full document, the agent also compiles:
- The list of Strengths to Preserve (informational, no decision needed)
- Any Missing Concerns (gap-type findings)

At the end of Stage 3, the agent has a complete internal collection of findings organized by category. Nothing is presented to the user yet.

##### Stage 4: Interactive Per-Finding Presentation (New — Replaces Current Stage 4)

The agent presents findings ONE AT A TIME, grouped by category. Categories are presented in order: Translation Gaps, then Credibility Concerns, then Missing Concerns, then Strengths to Preserve.

**Category announcement**: Before presenting the first finding in each category, the agent announces the category to the user as text output (not via AskUserQuestion):

```
--- Translation Gaps ({N} items) ---

These are places where the document's language diverges from how attorneys would interpret it.
I will present each finding and ask for your decision.
```

**Per-finding question format** (for Translation Gaps and Credibility Concerns):

```
AskUserQuestion:
  title: "Finding {N}.{M}: {Finding Title}"
  message: |
    **Problem**: {problem description}

    **Current ({location})**: "{quoted text}"
    [additional Current lines if applicable]

    **Suggested**: {suggested reframing}

    [**Note**: {note if applicable}]

    What is your decision for this finding?

  options:
    - "Accept — apply the suggested reframing as stated"
    - "Reject — keep the current language, no change needed"
    - "Modify — I want a different change (please explain in your response)"
```

**Handling "Modify" responses**: The user selects "Modify" and adds explanation text. Since AskUserQuestion with `options` allows free-text response in addition to selecting an option, the agent captures:
- The selected option: "Modify"
- The user's free-text explanation following their selection

After the user responds, the agent records: `decision = "Modify"`, `user_notes = "{user's explanation text}"`.

**Per-finding question format** (for Missing Concerns):

```
AskUserQuestion:
  title: "Missing Concern {3}.{M}: {Title}"
  message: |
    **Gap**: {gap description}

    **Possible addition**: {suggested addition}

    How would you like to handle this?

  options:
    - "Address — I want to add something to handle this concern"
    - "Skip — this concern does not apply or is intentionally omitted"
    - "Note for later — flag this for future revision"
```

**Strengths to Preserve**: These are presented all at once as text output (not interactive), after all other findings are presented:

```
--- Strengths to Preserve ---

The following elements are strong and should not be weakened during revision:

- **{Element}** ({lines}): {explanation}
...

These require no decision — they are informational.
```

**Decision tracking**: The agent maintains an in-memory decisions list across all AskUserQuestion calls:

```
decisions = [
  {
    category: "translation_gaps",
    finding_number: "1.1",
    finding_title: "...",
    decision: "Accept" | "Reject" | "Modify" | "Address" | "Skip" | "Note for later",
    user_notes: "...",  // empty string if Accept/Reject/Skip
    line_refs: "272, 451, 851",
    priority: "High"
  },
  ...
]
```

##### Stage 5: Revision Pass (New — Replaces Current Stage 5)

After all findings have been presented, the agent offers a revision pass:

```
AskUserQuestion:
  title: "Revision Pass"
  message: |
    All {N} findings have been reviewed. Here is a summary of your decisions:

    **Translation Gaps** ({N_tg} items):
    - {1.1}: {Accept/Reject/Modify}
    - {1.2}: ...

    **Credibility Concerns** ({N_cc} items):
    - {2.1}: {Accept/Reject/Modify}
    ...

    **Missing Concerns** ({N_mc} items):
    - {3.1}: {Address/Skip/Note}
    ...

    Would you like to revisit any finding before I compile the report?

  options:
    - "No — compile the report with these decisions"
    - "Yes — revisit finding {number} (specify in your response)"
```

If the user selects "Yes" and specifies a finding, the agent re-presents that finding with its current decision shown, and the user can change it. This can repeat until the user says "No."

If the user selects "No", proceed to Stage 6.

##### Stage 6: Compile Checklist Report (New — Replaces Current Stage 6)

The agent writes the consultation report using the checklist format. The report is assembled from the `decisions` list gathered in Stage 4.

**Report path**: Same as current — determined by the skill wrapper (task-attached uses task directory, standalone mode uses a temp/default path).

**Report template**:

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

**Decision**: {checkbox line based on user decision — using Address/Skip/Note format}

---

[repeat for each missing concern]

## 4. Strengths to Preserve

{Informational bulleted list — no decision checkboxes.}

---

## Revision Checklist

| # | Item | Lines | Priority | Status |
|---|------|-------|----------|--------|
{rows for each finding that has decision = Accept or Modify (not Reject or Skip)}

---

*Advisory: This consultation models attorney thinking but does not constitute legal advice. {Any domain-specific advisory note.}*
```

**Decision checkbox rendering rules**:

| User Decision | Rendered Checkbox Line |
|--------------|----------------------|
| Accept (no notes) | `**Decision**: [x] Accept  [ ] Reject  [ ] Modify` |
| Accept (with extended notes from Stage 2 intent) | `**Decision**: [x] Accept: {notes}  [ ] Reject  [ ] Modify` |
| Reject | `**Decision**: [ ] Accept  [x] Reject  [ ] Modify` |
| Modify (with user notes) | `**Decision**: [ ] Accept  [ ] Reject  [x] Modify: {user_notes}` |
| Address (Missing Concern) | `**Decision**: [x] Address  [ ] Skip  [ ] Note for later` |
| Skip (Missing Concern) | `**Decision**: [ ] Address  [x] Skip  [ ] Note for later` |
| Note for later (Missing Concern) | `**Decision**: [ ] Address  [ ] Skip  [x] Note for later` |

**Revision Checklist table rules**:
- Include findings where decision = Accept or Modify (these require actual edits to the document)
- Exclude findings where decision = Reject, Skip (no action needed)
- For "Note for later" decisions, include in table with priority = Low and note "(deferred)"
- Row format: `| {sequential #} | {finding title} | {line_refs} | {priority} | [ ] |`
- Status column always `[ ]` — user marks these manually after editing the document

---

### 4. AskUserQuestion Design

#### 4.1 One Question Per Finding

The "no batching" requirement means each AskUserQuestion call presents exactly ONE finding. The agent must NOT present multiple findings in a single question. This is consistent with the current Stage 4 behavior (one question at a time for Socratic probing).

#### 4.2 Options Array Format

AskUserQuestion supports an `options` array that presents labeled choices. The user can select one and optionally add free text. The three options for Translation Gaps and Credibility Concerns:

```
options: [
  "Accept — apply the suggested reframing as stated",
  "Reject — keep the current language, no change needed",
  "Modify — I want a different change (please explain)"
]
```

The agent parses the user's response to determine which option was selected (text matching on the option prefix) and captures any additional text as `user_notes`.

#### 4.3 Handling "Modify" Capture

When the user selects "Modify", they explain their desired change in the response text. The agent stores this as `user_notes` and uses it when rendering the `[x] Modify: {user_notes}` checkbox line.

If the user selects "Modify" but provides no notes, the agent should re-ask:

```
AskUserQuestion:
  title: "Please describe your modification for finding {N}.{M}"
  message: "You selected Modify for '{finding_title}'. What change would you like to make instead of the suggested reframing?"
  options: []  // free text only
```

#### 4.4 Category Grouping UX

The agent announces each category as a text message before presenting the first finding in that category. This provides orientation without consuming an AskUserQuestion call. The agent does NOT ask the user if they want to skip a category — all findings are presented.

#### 4.5 Progress Indicator

The question title should include a count to orient the user:

```
title: "Finding {N}.{M}: {Title} ({current_overall_number} of {total_findings})"
```

Example: `"Finding 1.3: 'Logos' Dual Meaning (3 of 12)"`

---

### 5. Report Compilation Details

#### 5.1 What to Include in Revision Checklist

Only findings requiring document edits go in the Revision Checklist:
- Accept: Yes (user approved the suggested reframing — editor needs to apply it)
- Modify: Yes (user wants a different change — editor needs to apply user's specified change)
- Reject: No (no action needed)
- Address (Missing Concern): Yes (user wants to add something)
- Skip (Missing Concern): No
- Note for later: Yes, with "(deferred)" suffix and Low priority

#### 5.2 Sequential Numbering in Checklist

The Revision Checklist uses sequential integers (1, 2, 3...) not the finding numbers (1.1, 2.1...). This simplifies the user's editing workflow.

#### 5.3 Section Numbering

The four category sections use numbered headings (`## 1. Translation Gaps`, `## 2. Credibility Concerns`, `## 3. Missing Concerns`, `## 4. Strengths to Preserve`).

Individual findings within each section use subsection numbers (`### 1.1`, `### 1.2`, `### 2.1`, etc.) matching the format shown in the example.

---

### 6. Vision Repo Sync Analysis

The Vision project mirror files are IDENTICAL to the nvim extension versions (confirmed by direct read comparison):

| File | nvim extension | Vision project | Status |
|------|---------------|----------------|--------|
| `legal-analysis-agent.md` | identical | identical | Must sync |
| `consult.md` | identical | identical | No change needed |
| `skill-consult/SKILL.md` | identical (except `Agent` vs `Task` tool name) | identical (uses `Task` tool) | No change needed |

**Minor divergence noted**: The nvim extension `skill-consult/SKILL.md` says "Agent tool" in Stage 4, while the Vision version says "Task tool". The `legal-analysis-agent.md` says "Invoked By: skill-consult (via Agent tool)" in nvim but "via Task tool" in Vision. This is an existing pre-task-562 divergence. Task 562 does not need to resolve it — just ensure the agent Stage 3-6 content is identical in both.

**Sync requirement**: After implementing the new agent stages in one repo, copy the `legal-analysis-agent.md` file to the other repo identically.

---

### 7. Current Stage 3 Presentation Issue

In the current agent, Stage 3 says:
> "Present findings as a structured translation analysis."

This means findings are currently presented as text output during Stage 3, before any Socratic dialogue. In the new flow, Stage 3 must NOT present findings — it is a silent internal analysis pass. The presentation moves entirely to Stage 4's AskUserQuestion loop.

---

### 8. Category Structure Formalization

The current agent's Stage 3 does not specify the four-category framework. It uses five "gap categories" from legal-reasoning-patterns.md (terminology, process/timeline, ethical accuracy, reasoning framework, role confusion). The example report uses a different four-category output structure:

1. **Translation Gaps** (subsections classify by linguistic/professional vocabulary)
2. **Credibility Concerns** (claims that trigger skepticism)
3. **Missing Concerns** (topics an attorney buyer would raise)
4. **Strengths to Preserve** (what should not be changed)

The new Stage 3 must instruct the agent to organize findings into these four output categories. The five gap categories from legal-reasoning-patterns.md remain useful as an internal classification tool (for the "Gap Category" label within each finding's Problem description), but the top-level organization in the report uses the four categories.

---

### 9. Metadata Update

The current agent writes `"status": "consulted"` in Stage 7. This should be preserved. The metadata fields need minor additions to track the interactive flow:

```json
{
  "status": "consulted",
  "metadata": {
    ...existing fields...,
    "findings_presented": {N},
    "decisions": {
      "accepted": {count},
      "rejected": {count},
      "modified": {count},
      "addressed": {count},
      "skipped": {count}
    }
  }
}
```

---

## Decisions

1. **Stage 2 preserved exactly**: No changes to the Socratic intent-gathering dialogue.
2. **Stage 3 becomes silent**: All findings are identified internally before any interactive presentation. No text output during Stage 3.
3. **Four categories are canonical**: Translation Gaps, Credibility Concerns, Missing Concerns, Strengths to Preserve — in that order.
4. **AskUserQuestion per finding**: One call per finding, with labeled Accept/Reject/Modify options. Category announcements are text output (not AskUserQuestion).
5. **Missing Concerns use different options**: Address / Skip / Note for later (not Accept/Reject/Modify).
6. **Strengths to Preserve are informational**: Presented as text output, no decision checkboxes.
7. **Revision pass is a summary + optional revisit**: Single AskUserQuestion showing all decisions, offering to revisit any finding.
8. **Report template exactly matches example format**: Per-finding `**Decision**:` lines, Revision Checklist table with `[ ]` status column.
9. **Only 2 files need changes**: Both copies of `legal-analysis-agent.md` (nvim extension + Vision project).
10. **Existing agent tool divergence (Agent vs Task)**: Not fixed by this task, left as-is.

---

## Recommendations

1. **Implement Stage 3 (Internal Analysis) with four-category scaffolding**: The agent must explicitly build an ordered list of findings per category. Add pseudocode that shows building `translation_gaps[]`, `credibility_concerns[]`, `missing_concerns[]`, `strengths[]` arrays during the read pass.

2. **Implement Stage 4 (Interactive Loop) with clear loop structure**: Show the loop structure explicitly in the agent instructions — "for each category in [translation_gaps, credibility_concerns, missing_concerns], for each finding in category, present AskUserQuestion." Make it clear the loop is sequential, not parallel.

3. **Implement Stage 5 (Revision Pass) as a single summary question**: The revision pass question should show the full decision summary so the user can identify which finding to revisit (if any). Keep it to a single AskUserQuestion; if the user asks to revisit, re-present that one finding's question, then return to the revision pass.

4. **Implement Stage 6 (Report Compilation) with exact template**: The report section titles and checkbox format must match the example exactly. Use a clear template in the agent instructions showing the exact markdown to generate for each finding type.

5. **Update Critical Requirements**: The MUST DO and MUST NOT lists need updating — the new flow changes what counts as correct behavior (e.g., "MUST NOT present findings to the user during Stage 3").

6. **Sync both repos immediately**: After implementing in nvim extension, copy to Vision project before committing.

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Long documents produce too many findings for comfortable interactive review | Medium | Stage 3 can identify up to 15-20 high-priority findings; lower-priority findings can be grouped or omitted from interactive flow |
| User provides "Modify" without notes (ambiguous) | Medium | Agent re-asks for modification details (Stage 4.3 above) |
| "Note for later" decisions create confusion in Revision Checklist | Low | Include "(deferred)" label and Low priority in the table |
| Inconsistency between two repo copies during phased implementation | Medium | Always edit nvim extension first, then copy file to Vision project as an atomic step |
| Revision pass becomes lengthy with many findings | Low | Limit the summary display to finding number + decision (one-line per finding), not full detail |

---

## Appendix

### A. Agent Stage Mapping (Current → New)

| Current Stage | Current Name | New Stage | New Name |
|--------------|-------------|-----------|----------|
| Stage 0 | Initialize Early Metadata | Stage 0 | Initialize Early Metadata (UNCHANGED) |
| Stage 1 | Parse Delegation Context | Stage 1 | Parse Delegation Context (UNCHANGED) |
| Stage 2 | Understand Intent | Stage 2 | Understand Intent (UNCHANGED) |
| Stage 3 | Read and Translate | Stage 3 | Internal Analysis — Read and Identify All Findings (REWRITTEN) |
| Stage 4 | Reframe and Probe | Stage 4 | Interactive Per-Finding Presentation (REWRITTEN) |
| Stage 5 | Validate Consistency | Stage 5 | Revision Pass (REWRITTEN) |
| Stage 6 | Generate Consultation Report | Stage 6 | Compile Checklist Report (REWRITTEN) |
| Stage 7 | Write Metadata and Return Summary | Stage 7 | Write Metadata and Return Summary (minor additions) |

### B. Example Finding Q&A Dialogue (Illustrative)

```
[Stage 4, Translation Gaps announced as text]

AskUserQuestion:
  title: "Finding 1.1: 'Language of Thought' (1 of 12)"
  message: |
    **Problem**: Philosophical jargon. No attorney uses this phrase. Reads as marketing fluff
    or academic abstraction.

    **Current (line 272)**: "evaluating claims in a language of thought"
    **Current (line 451)**: "the Logos, a language of thought for verified reasoning"

    **Suggested**: Replace with "formal reasoning framework" or "structured logic" -- terms that
    evoke legal briefs and analytical frameworks, not cognitive science.

    What is your decision for this finding?

  options:
    - "Accept — apply the suggested reframing as stated"
    - "Reject — keep the current language, no change needed"
    - "Modify — I want a different change (please explain)"

User response: "Accept — apply the suggested reframing as stated"
Agent records: decision="Accept", user_notes=""

→ Report renders: **Decision**: [x] Accept  [ ] Reject  [ ] Modify
```

### C. Example Revision Checklist Table Row

For finding 1.3 "Logos Dual Meaning" accepted by the user:

```
| 3 | Disambiguate "Logos" dual meaning | Throughout | Medium | [ ] |
```

For finding 1.2 "Evaluation capability name" modified by user ("use 'truth assessment'"):

```
| 2 | Rename "Evaluation" capability | 451, 745 | Medium | [ ] |
```
(The modification notes appear in the finding's `**Decision**:` line within the report body, not in the table.)

### D. Files Read During Research

All files were read at their canonical absolute paths:
- `/home/benjamin/Projects/Logos/Vision/specs/203_legal_consult_revisions/reports/01_legal-consult-revisions.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/agents/legal-analysis-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/consult.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/skills/skill-consult/SKILL.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/commands/consult.md`
- `/home/benjamin/Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md`
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/legal-planning.md`
