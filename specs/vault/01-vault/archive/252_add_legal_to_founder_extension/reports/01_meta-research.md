# Research Report: Task #252

**Task**: 252 - Add /legal command-skill-agent to founder extension
**Generated**: 2026-03-20
**Source**: /meta interview (auto-generated, consolidated from tasks 252-257)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Add contract review and negotiation legal counsel capability to the founder extension
**Scope**: New command, skill, agent, context files + manifest/index/EXTENSION.md updates
**Affected Components**: 7 new files, 3 modified files in .claude/extensions/founder/
**Domain**: founder extension
**Language**: meta

## Implementation Phases

### Phase 1: Create legal-council-agent

Create `agents/legal-council-agent.md` following the established agent pattern used by market-agent, analyze-agent, and strategy-agent.

**Key Patterns to Follow (from market-agent.md)**:

1. **Frontmatter**: name, description, mcp-servers (if applicable)
2. **Agent Metadata Block**: Name, Purpose, Invoked By, Return Format
3. **Allowed Tools**: AskUserQuestion (one-at-a-time forcing questions), Read, Write, Glob, WebSearch, Bash
4. **Context References**: @-references to legal context files (domain/legal-frameworks.md, patterns/contract-review.md)
5. **Execution Flow**: Stage 0 (early metadata), Stage 1 (parse delegation), Stage 2 (mode selection), Stages 3-5 (forcing questions), Stage 6 (generate report), Stage 7 (write report), Stage 8 (write metadata), Stage 9 (return summary)
6. **Push-Back Patterns**: Table of vague legal answers and specific push-back responses
7. **Error Handling**: User abandonment, partial completion, missing data

**Modes for Legal Agent**:

| Mode | Posture | Focus |
|------|---------|-------|
| REVIEW | Risk assessment | Identify problematic clauses, red flags, missing protections |
| NEGOTIATE | Position building | Counter-terms, leverage points, walk-away conditions |
| TERMS | Drafting assistance | Term sheet review, key terms, standard vs non-standard |
| DILIGENCE | Due diligence | IP assignment, liability, representations & warranties |

**Forcing Questions Structure** (one question at a time via AskUserQuestion):
- Q1: Contract type and parties involved
- Q2: What are your primary concerns or objectives?
- Q3: What is your negotiating position (buyer/seller/partner)?
- Q4: Are there specific clauses you need reviewed?
- Q5: What is the deal value or financial exposure?
- Q6: What jurisdiction governs this agreement?
- Q7: What are your walk-away conditions?
- Q8: Are there precedent agreements or standard terms you expect?

**Output Format**: Research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`

---

### Phase 2: Create skill-legal

Create `skills/skill-legal/SKILL.md` following the thin wrapper pattern used by skill-market, skill-analyze, and skill-strategy.

**Key Patterns to Follow (from skill-market/SKILL.md)**:

1. **Frontmatter**: name, description, allowed-tools (Task, Bash, Edit, Read, Write)
2. **Context Pointers**: Reference to subagent-return.md (do not load eagerly)
3. **Trigger Conditions**: Direct invocation (/legal command), implicit invocation (plan step patterns)
4. **Execution Flow**:
   - Stage 1: Input validation (task_number, validate exists in state.json, validate language is founder)
   - Stage 2: Preflight status update (set to "researching")
   - Stage 3: Create postflight marker (.postflight-pending)
   - Stage 4: Prepare delegation context (task_context, forcing_data, metadata_file_path)
   - Stage 5: Invoke agent via Task tool (legal-council-agent)
   - Stage 6: Parse subagent return (.return-meta.json)
   - Stage 7: Update task status (postflight to "researched")
   - Stage 8: Link artifacts (two-step jq pattern)
   - Stage 9: Git commit
   - Stage 10: Cleanup (remove .postflight-pending, .return-meta.json)
   - Stage 11: Return brief summary

**Trigger Patterns for Legal**:

Plan step language patterns:
- "Review contract terms"
- "Analyze legal implications"
- "Contract review and negotiation"
- "Legal due diligence"

Target mentions:
- "contract review", "legal analysis"
- "term sheet", "negotiation terms"
- "indemnification", "liability", "IP assignment"

**When NOT to Trigger**:
- Market analysis (use skill-market)
- Competitive analysis (use skill-analyze)
- GTM strategy (use skill-strategy)
- General business research (use skill-researcher)

---

### Phase 3: Create /legal command

Create `commands/legal.md` following the pre-task forcing question pattern used by market.md, analyze.md, and strategy.md.

**Key Patterns to Follow (from market.md)**:

1. **Frontmatter**: description, allowed-tools, argument-hint
2. **Syntax Section**: Multiple input types (description, task number, file path, --quick)
3. **Input Types Table**: Description string, task number, file path, --quick flag
4. **Modes Table**: REVIEW, NEGOTIATE, TERMS, DILIGENCE
5. **STAGE 0: Pre-Task Forcing Questions**:
   - Step 0.1: Mode selection via AskUserQuestion
   - Step 0.2: Essential forcing questions (one at a time)
   - Step 0.3: Store forcing_data JSON object
6. **CHECKPOINT 1: GATE IN**:
   - Session ID generation
   - Input type detection
   - Task creation in state.json with task_type: "legal" and forcing_data
   - TODO.md update with forcing data summary
   - Git commit
   - Display summary and STOP for new tasks
7. **STAGE 2: DELEGATE**: Only for task_number or --quick input
8. **CHECKPOINT 2: GATE OUT**: Verify research completed, display result

**Forcing Questions for Legal**:

**Question 1: Contract Type**
```
What type of contract or agreement are you reviewing?
Be specific - "business agreement" is too vague. Is it SaaS, employment, partnership, IP license, NDA, investment?
```
Store as `forcing_data.contract_type`.

**Question 2: Primary Concern**
```
What is your primary objective or concern with this agreement?
Examples: "Limit liability exposure", "Ensure IP protection", "Negotiate better payment terms"
```
Store as `forcing_data.primary_concern`.

**Question 3: Your Position**
```
What is your role in this agreement?
Are you the service provider, customer, investor, employee, or partner?
```
Store as `forcing_data.position`.

**Question 4: Financial Exposure**
```
What is the approximate financial value or exposure of this agreement?
This helps calibrate the depth of review needed.
```
Store as `forcing_data.financial_exposure`.

**Allowed Tools**: `Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion`
**Argument Hint**: `"[description]" | TASK_NUMBER | /path/to/contract.md | --quick [contract type]`

---

### Phase 4: Create legal context files

Create three context files in `.claude/extensions/founder/context/project/founder/`.

#### File 1: domain/legal-frameworks.md

**Purpose**: Contract law basics, negotiation principles, legal terminology for founders

**Content Areas**:
- Common contract types for startups (SaaS, employment, NDA, SAFE, partnership)
- Key legal concepts founders must understand (indemnification, liability caps, IP assignment, non-compete, representations & warranties)
- Negotiation frameworks (BATNA, ZOPA, anchoring, concession patterns)
- Red flag checklist (unlimited liability, broad IP assignment, non-standard terms)
- Jurisdiction considerations
- When to escalate to a real attorney

**Pattern Reference**: `domain/business-frameworks.md` (~240 lines)

#### File 2: patterns/contract-review.md

**Purpose**: Systematic contract review checklist and red flag detection

**Content Areas**:
- Review methodology (clause-by-clause systematic approach)
- Priority sections to review first (liability, IP, termination, payment)
- Common red flags by contract type
- Push-back patterns for legal forcing questions (similar to forcing-questions.md)
- Risk assessment matrix (likelihood x severity)
- Standard vs non-standard clause identification
- Counter-proposal generation patterns

**Pattern Reference**: `patterns/forcing-questions.md` (~221 lines)

#### File 3: templates/contract-analysis.md

**Purpose**: Output template for contract review analysis reports

**Content Areas**:
- Executive summary section
- Clause-by-clause analysis table
- Risk assessment matrix visualization
- Recommended modifications table
- Negotiation position summary
- Walk-away conditions
- Action items with priority

**Pattern Reference**: `templates/market-sizing.md` (~250 lines)

---

### Phase 5: Update manifest.json, index-entries.json, and EXTENSION.md

#### manifest.json Updates

**provides.agents**: Add `"legal-council-agent.md"`
**provides.skills**: Add `"skill-legal"`
**provides.commands**: Add `"legal.md"`
**routing.research**: Add `"founder:legal": "skill-legal"`

#### index-entries.json Updates

Add three new entries:

```json
{
  "path": ".claude/extensions/founder/context/project/founder/domain/legal-frameworks.md",
  "summary": "Contract law basics, negotiation principles, legal terminology for founders",
  "line_count": 250,
  "load_when": {
    "agents": ["legal-council-agent", "founder-plan-agent", "founder-implement-agent"],
    "languages": ["founder"],
    "commands": ["/legal", "/plan", "/implement"]
  }
},
{
  "path": ".claude/extensions/founder/context/project/founder/patterns/contract-review.md",
  "summary": "Systematic contract review checklist, red flags, push-back patterns",
  "line_count": 230,
  "load_when": {
    "agents": ["legal-council-agent", "founder-plan-agent"],
    "languages": ["founder"],
    "commands": ["/legal", "/plan"]
  }
},
{
  "path": ".claude/extensions/founder/context/project/founder/templates/contract-analysis.md",
  "summary": "Output template for contract review analysis reports",
  "line_count": 260,
  "load_when": {
    "agents": ["legal-council-agent", "founder-implement-agent"],
    "languages": ["founder"],
    "commands": ["/legal", "/implement"]
  }
}
```

#### EXTENSION.md Updates

**Commands Table**: Add `/legal` row
```markdown
| `/legal` | `/legal "SaaS agreement review"` | Ask forcing questions, create task (stops at [NOT STARTED]) |
```

**task_type Field Table**: Add legal row
```markdown
| /legal | legal | skill-legal |
```

**Skill-to-Agent Mapping Table**: Add legal row
```markdown
| skill-legal | legal-council-agent | Contract review and negotiation (uses forcing_data) |
```

**Language-Based Routing Table**: Add legal routing row
```markdown
| `/research` (task_type: legal) | founder:legal | skill-legal | legal-council-agent |
```

**Context Files Table**: Add three legal context entries
```markdown
| `context/project/founder/domain/legal-frameworks.md` | Contract law, negotiation principles |
| `context/project/founder/patterns/contract-review.md` | Review checklist, red flags |
| `context/project/founder/templates/contract-analysis.md` | Contract analysis output template |
```

**Pre-Task Forcing Questions Section**: Add /legal workflow example.
**Version**: Bump to v2.2.

---

## Files Summary

| Action | File |
|--------|------|
| Create | `.claude/extensions/founder/agents/legal-council-agent.md` |
| Create | `.claude/extensions/founder/skills/skill-legal/SKILL.md` |
| Create | `.claude/extensions/founder/commands/legal.md` |
| Create | `.claude/extensions/founder/context/project/founder/domain/legal-frameworks.md` |
| Create | `.claude/extensions/founder/context/project/founder/patterns/contract-review.md` |
| Create | `.claude/extensions/founder/context/project/founder/templates/contract-analysis.md` |
| Modify | `.claude/extensions/founder/manifest.json` |
| Modify | `.claude/extensions/founder/index-entries.json` |
| Modify | `.claude/extensions/founder/EXTENSION.md` |

## Effort Assessment

- **Total Estimated Effort**: 9-12 hours
- **Complexity Notes**: Straightforward pattern replication from existing founder components with legal domain adaptation

---

*This research report was consolidated from tasks 252-257 created via /meta command.*
