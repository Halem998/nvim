# Research Report: Task #252

**Task**: Add /legal command-skill-agent to founder extension
**Date**: 2026-03-20
**Mode**: Team Research (2 teammates)
**Session**: sess_1774025146_7e2746

## Summary

Comprehensive research covering both implementation patterns (Teammate A) and legal domain content (Teammate B) for adding a /legal command-skill-agent to the founder extension. The extension requires 7 new files and 3 modified files, following established founder extension patterns exactly. Legal domain content covers AI startup-specific contract law, negotiation frameworks, and escalation criteria with 2025-2026 case law and regulatory developments.

## Key Findings

### Implementation Structure (Teammate A)

#### File Inventory

| Action | File | Pattern Source |
|--------|------|---------------|
| Create | `agents/legal-council-agent.md` | market-agent.md |
| Create | `skills/skill-legal/SKILL.md` | skill-market/SKILL.md |
| Create | `commands/legal.md` | market.md |
| Create | `context/project/founder/domain/legal-frameworks.md` | domain/business-frameworks.md |
| Create | `context/project/founder/patterns/contract-review.md` | patterns/forcing-questions.md |
| Create | `context/project/founder/templates/contract-analysis.md` | templates/market-sizing.md |
| Create | `context/project/founder/templates/typst/contract-analysis.typ` | templates/typst/market-sizing.typ |
| Modify | `manifest.json` | Add to provides + routing |
| Modify | `index-entries.json` | Add context entries |
| Modify | `EXTENSION.md` | Add /legal docs |

#### Execution Flow Patterns (exact replication required)

**Agent (9 stages)**:
- Stage 0: Early metadata (CRITICAL - must be first operation)
- Stage 1: Parse delegation context
- Stage 2: Mode selection via AskUserQuestion
- Stages 3-5: Forcing questions (one at a time, push back on vagueness)
- Stage 6: Generate research report
- Stage 7: Write report to `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
- Stage 8: Write metadata file
- Stage 9: Return brief text summary (NOT JSON)

**Skill (11 stages)**:
- Stage 1: Input validation (task exists, language is founder)
- Stage 2: Preflight status update (researching)
- Stage 3: Create postflight marker
- Stage 4: Prepare delegation context JSON
- Stage 5: Invoke agent via Task tool
- Stage 6: Parse .return-meta.json
- Stage 7: Postflight status update (researched)
- Stage 8: Link artifacts (two-step jq, "| not" pattern)
- Stage 9: Git commit
- Stage 10: Cleanup (.postflight-pending, .return-meta.json)
- Stage 11: Return brief summary

**Command (STAGE 0 + CHECKPOINT 1 + STAGE 2 + CHECKPOINT 2)**:
- STAGE 0: Pre-task forcing questions (mode selection + 4 questions)
- CHECKPOINT 1: Session ID, input detection, task creation, git commit, STOP
- STAGE 2: Delegate to skill (only for task_number or --quick)
- CHECKPOINT 2: Verify, display result

#### Frontmatter Patterns

**Agent**:
```yaml
---
name: legal-council-agent
description: Contract review and negotiation counsel for AI startup founders
---
```

**Skill**:
```yaml
---
name: skill-legal
description: Contract review and legal analysis for founders
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**Command**:
```yaml
---
description: Contract review and negotiation counsel with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/contract.md | --quick [contract type]
---
```

#### Modes (4 required per pattern)

| Mode | Posture | Focus |
|------|---------|-------|
| REVIEW | Risk assessment | Identify problematic clauses, red flags, missing protections |
| NEGOTIATE | Position building | Counter-terms, leverage points, BATNA/ZOPA analysis |
| TERMS | Drafting assistance | Term sheet review, key terms, standard vs non-standard |
| DILIGENCE | Due diligence | IP assignment, liability, representations & warranties |

#### Pre-Task Forcing Questions (STAGE 0 in command)

1. **Contract Type**: What type of contract? (SaaS, employment, partnership, data license, NDA, SAFE, AI/ML service)
2. **Primary Concern**: What is your primary objective? (Limit liability, protect IP, negotiate terms, compliance review)
3. **Your Position**: What is your role? (Service provider, customer, investor, employee, partner)
4. **Financial Exposure**: What is the approximate deal value or exposure?

#### Agent Research Questions (interactive, one at a time)

Q1: Contract type and parties involved
Q2: Primary concerns or objectives
Q3: Negotiating position (buyer/seller/partner)
Q4: Specific clauses needing review
Q5: Deal value or financial exposure
Q6: Governing jurisdiction
Q7: Walk-away conditions
Q8: Precedent agreements or standard terms expected

#### Routing Updates

manifest.json routing.research: `"founder:legal": "skill-legal"`

Plan and implement continue to use `founder-plan-agent` and `founder-implement-agent` (shared across all founder task types).

---

### Legal Domain Content (Teammate B)

#### Recommended Context File Structure

Three context files following the domain/patterns/templates convention, with rich AI startup-specific content:

##### domain/legal-frameworks.md (~250 lines)

**Core Legal Concepts for Founders**:
1. **IP Assignment and Work-for-Hire**
   - Work-for-hire only covers copyrightable works; patents/trade secrets need explicit assignment
   - All contractors must sign IP assignment before starting
   - "Prior inventions" schedule required
   - AI-specific: fine-tuned model weights ownership is disputed; RAG libraries may contain licensed materials
   - Copyright Office (May 2025): AI-generated outputs without human authorship may not be copyrightable

2. **Indemnification and Liability Caps**
   - Standard: cap at 12-month fees (inadequate for AI risk)
   - Negotiate: 2-3x annual fees minimum; unlimited for IP and data breach
   - Carve-outs from cap: IP infringement, gross negligence, data breaches
   - Red flags: one-sided indemnification, mandatory arbitration

3. **Data Rights and AI Training**
   - Three categories: input data, output data, training/improvement data
   - Must include: vendor training prohibition (opt-in only), output ownership, deletion timeline
   - Precedent: Fastcase v. Alexi (Nov 2025) on data license for AI training

4. **Non-Compete and Non-Solicitation**
   - No federal ban (FTC rule blocked, appeal dismissed Sep 2025)
   - State-by-state: CA, ND, MN, OK, MT, WY = complete bans
   - For AI startups: use NDAs + trade secret protection as primary defense

5. **Representations and Warranties**
   - Standard "as-is" disclaimers are insufficient for AI
   - Negotiate: regulatory compliance, training data provenance, bias mitigation
   - What you should warrant as AI vendor: data rights, legal compliance, bias processes

6. **Termination**
   - Must include: data return/deletion, transition assistance, license survival
   - Watch for: automatic renewal, unilateral price increases, change-of-control restrictions

**Contract Types for AI Startups**:
- SaaS agreements (vendor or customer)
- Data licensing agreements (AI training specifics)
- AI/ML service agreements (model ownership, improvement rights)
- Employment contracts (AI engineer specifics, side projects, OSS policy)
- SAFE notes (post-money standard, valuation cap, discount, pro-rata, MFN)
- Partnership agreements (technology, data, channel, strategic)

##### patterns/contract-review.md (~230 lines)

**Review Methodology**:
1. Identify ownership: background IP, customer data, generated outputs
2. Trace data flow: what goes in, comes out, vendor retains
3. Check liability exclusions: "as-is" disclaimers
4. Map indemnification: who defends whom
5. Find the exit: termination rights, data deletion, continuity

**Red Flags Checklist by Category**:

| Category | Red Flags |
|----------|-----------|
| Data/IP | Vendor uses your data for training without opt-in; ambiguous output ownership; no deletion obligation |
| Liability | Cap at fees only; one-sided indemnification; mandatory expensive arbitration |
| Business | Unilateral term modifications; auto-renewal < 30 day opt-out; change-of-control consent |
| Investment | Participating preferred (unlimited); full-ratchet anti-dilution; overly broad veto rights |
| Employment | Overbroad IP assignment; non-compete in ban state; no acceleration on CoC |

**Push-Back Patterns for Vague Answers**:

| Vague Pattern | Push-Back |
|---------------|-----------|
| "Standard agreement" | "Standard in what industry? AI contracts have unique terms. What type specifically?" |
| "We need protection" | "Protection from what specifically? IP infringement? Data breach? Liability from AI outputs?" |
| "Fair terms" | "Fair based on what benchmark? What are the 3 terms that matter most to you?" |
| "Reasonable liability" | "What dollar amount? 1x fees? 2x? Unlimited for certain categories?" |

**Attorney Escalation Guide**:
- Always use attorney: incorporation, first funding round, contracts > $100K, regulatory matters
- Attorney review: weaker party position, regulated industries, international contracts
- Self-serve: standard vendor agreements < $50K, NDAs from templates, initial markup before attorney

##### templates/contract-analysis.md (~260 lines)

Research report template with:
- Executive summary
- Clause-by-clause analysis table (clause, risk level, recommendation)
- Risk assessment matrix (likelihood x severity)
- Recommended modifications table
- Negotiation position summary with BATNA analysis
- Walk-away conditions
- Action items with priority
- Escalation recommendation (self-serve / attorney review / attorney required)

**Negotiation Frameworks Section**:
- BATNA: best alternative if negotiation fails (with startup-specific examples)
- ZOPA: overlap of acceptable outcomes across multiple dimensions
- Anchoring: first number sets the range; anchor credibly with market data
- Principled negotiation: separate people from problem, focus on interests not positions

---

## Synthesis

### Conflicts Resolved

1. **Mode naming**: Teammate A proposed REVIEW/COMPLY/PROTECT/NEGOTIATE. The initial meta-research proposed REVIEW/NEGOTIATE/TERMS/DILIGENCE. **Resolution**: Use REVIEW/NEGOTIATE/TERMS/DILIGENCE as these map more directly to the forcing question flow and match the pattern of actionable postures (like LAUNCH/SCALE/PIVOT/EXPAND). COMPLY is too narrow; PROTECT overlaps with REVIEW.

2. **Context file count**: Teammate B recommended 5 files (legal-concepts, contract-types, negotiation-playbook, red-flags, escalation-guide). The initial meta-research and Teammate A recommended 3 files (domain, patterns, templates). **Resolution**: Use 3 files following the established domain/patterns/templates convention. Merge Teammate B's 5 topics into the 3-file structure: legal-frameworks.md absorbs concepts + contract types, contract-review.md absorbs red flags + escalation + review methodology, contract-analysis.md provides the output template with negotiation frameworks.

3. **Agent naming**: Teammate A used "legal-agent". Initial meta-research used "legal-council-agent". **Resolution**: Use "legal-council-agent" to distinguish from generic legal tooling and convey the advisory nature.

### Gaps Identified

1. **Typst template**: Teammate A flagged `templates/typst/contract-analysis.typ` as optional. Given that market, competitive analysis, and GTM strategy all have Typst templates, one should be created for consistency. Content: clause analysis table, risk matrix visualization, negotiation position summary.

2. **MCP server integration**: No legal-specific MCP server identified. Unlike market-agent (sec-edgar) and analyze-agent (firecrawl), legal-council-agent has no external data dependency. This is acceptable -- not all agents need MCP servers.

3. **Agentic AI contracting**: Teammate B noted this is an emerging area (Mayer Brown Feb 2026). Context files should include a brief section but note that norms are still forming.

### Recommendations

1. **Implementation order**: Context files first (referenced by agent) -> agent -> skill -> command -> manifest/index -> EXTENSION.md
2. **Reuse founder-plan-agent and founder-implement-agent** for plan/implement phases (no legal-specific plan/implement needed)
3. **Include Typst template** for PDF report generation consistency
4. **Version bump**: EXTENSION.md to v2.2 and manifest.json version to "2.1.0"
5. **Total files**: 7 created + 3 modified = 10 file operations

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Implementation patterns and structure | completed | High on structure, Medium on mode names |
| B | Legal domain content and best practices | completed | High across all topics |

## References

### Legal Sources (Teammate B)
- Fastcase v. Alexi Technologies (Nov 2025) - data licensing precedent
- FTC non-compete ban status (rule blocked 2024, appeal dismissed Sep 2025)
- US Copyright Office AI Training Report (May 2025)
- SAFE market data from Carta Q1 2025 (90% pre-seed, 64% seed)
- EU AI Act compliance requirements in contract R&W clauses
- Mayer Brown (Feb 2026) on agentic AI contracting

### Pattern Sources (Teammate A)
- `.claude/extensions/founder/agents/market-agent.md` - Agent pattern reference
- `.claude/extensions/founder/skills/skill-market/SKILL.md` - Skill pattern reference
- `.claude/extensions/founder/commands/market.md` - Command pattern reference
- `.claude/extensions/founder/context/project/founder/` - Context file patterns
- `.claude/extensions/founder/manifest.json` - Registration patterns
- `.claude/extensions/founder/index-entries.json` - Index entry patterns
