# Research Report: Task #233 (Supplemental)

**Task**: 233 - research_gstack_founder_extension
**Started**: 2026-03-18T12:00:00Z
**Completed**: 2026-03-18T12:45:00Z
**Effort**: 1-2 hours implementation per skill
**Dependencies**: specs/233_research_gstack_founder_extension/reports/01_gstack-founder-integration.md
**Sources/Inputs**: GitHub gstack repository (raw files), WebSearch (market sizing frameworks)
**Artifacts**: specs/233_research_gstack_founder_extension/reports/02_founder-skills-deep-dive.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **gstack's three adapted skills** (/office-hours, /plan-ceo-review, /retro) provide structured frameworks for strategic thinking, not just prompts
- **Key insight**: The value is in the "forcing questions" and decision frameworks, not the code structure
- **New skill opportunities identified**: Market sizing (/founder-market), business model analysis (/founder-model), and go-to-market strategy (/founder-gtm)
- **Recommended approach**: Adapt gstack's question framework pattern for business-focused skills

---

## Part 1: Deep Dive into gstack Adapted Skills

### 1.1 /founder-hours (adapted from /office-hours)

**Purpose**: YC-style product diagnostic and strategic brainstorming session

**What It Does**:
The skill operates as a virtual YC office hours session with two distinct modes based on user context:

| Mode | Trigger | Purpose |
|------|---------|---------|
| **Startup Mode** | User mentions customers, revenue, fundraising | Rigorous demand validation via 6 forcing questions |
| **Builder Mode** | Hackathon, learning, open source, fun | Generative brainstorming focused on delight |

**The Six Forcing Questions (Startup Mode)**:

| Question | Purpose | Push Until |
|----------|---------|------------|
| **Q1: Demand Reality** | "What's the strongest evidence someone actually wants this?" | Specific behavior, payment, workflow dependency |
| **Q2: Status Quo** | "What are users doing right now to solve this?" | Specific workflow, hours wasted, dollars spent |
| **Q3: Desperate Specificity** | "Name the actual human who needs this most. Title?" | Name, role, specific consequence heard directly |
| **Q4: Narrowest Wedge** | "What's the smallest version someone would pay for this week?" | One feature, one workflow, shippable in days |
| **Q5: Observation & Surprise** | "Have you watched someone use this? What surprised you?" | Specific surprise contradicting assumptions |
| **Q6: Future-Fit** | "If the world looks different in 3 years, does your product become more essential or less?" | Specific claim about user world change |

**Smart Routing by Stage**:
- Pre-product founders: Q1, Q2, Q3 (validate demand exists)
- Has users: Q2, Q4, Q5 (find narrowest wedge, observe usage)
- Paying customers: Q4, Q5, Q6 (optimize wedge, verify long-term fit)

**Builder Mode Questions** (one at a time):
- "What's the coolest version?"
- "Who would you show this to?"
- "Fastest path to something usable?"
- "What's closest existing thing, how is yours different?"
- "Unlimited-time 10x version?"

**Operating Principles**:
1. "Specificity is the only currency" - vague answers get pushed
2. Interest != demand; behavior and payment count
3. Users' words trump founder's pitch
4. Status quo (current workaround) is real competitor
5. Narrow beats wide early

**Output Artifact**:
Design document saved to `~/.gstack/projects/{slug}/{user}-{branch}-design-{datetime}.md` containing:
- Problem statement + demand evidence
- Status quo analysis
- Target user & narrowest wedge
- Premises challenged
- Approaches considered (2-3 minimum)
- Recommended approach
- "The Assignment" - one concrete real-world action
- "What I noticed about how you think" - mentor-style observations

**Key Design Pattern**: The skill never batches questions. Each forcing question is asked via individual AskUserQuestion, with explicit push-back if answers are vague.

---

### 1.2 /founder-review (adapted from /plan-ceo-review)

**Purpose**: CEO-level product strategy review with scope management

**What It Does**:
This is the most comprehensive of the three skills. It provides a structured 11-section analysis framework with four operational modes that give the user explicit control over scope direction.

**The Four Operational Modes**:

| Mode | Posture | When to Use |
|------|---------|-------------|
| **SCOPE EXPANSION** | "Dream big" - enthusiastic recommendations | Exploring what the 10x version looks like |
| **SELECTIVE EXPANSION** | "Cherry-pick" - neutral, hold baseline | Keep baseline, surface individual opportunities |
| **HOLD SCOPE** | "Maximum rigor" - no expansions surfaced | Make current scope bulletproof |
| **SCOPE REDUCTION** | "Strip to essentials" - surgical cuts | Find minimum viable scope |

**Critical constraint**: "In ALL modes, the user is 100% in control. Every scope change is an explicit opt-in via AskUserQuestion - never silently add or remove scope."

**The 11-Section Analysis Structure**:

| Section | Focus | Key Outputs |
|---------|-------|-------------|
| **0: Nuclear Scope Challenge** | Premise challenge, mode selection | Right problem? Existing code leverage? Dream state mapping |
| **1: Architecture Review** | System design, boundaries, flows | Required: Full system architecture diagram |
| **2: Error & Rescue Map** | Every method that can fail | Complete error registry with exception classes |
| **3: Security & Threat Model** | Attack surface, input validation | Authorization, secrets, injection vectors |
| **4: Data Flow & Edge Cases** | Shadow paths, user interactions | ASCII diagrams with nil/empty/error paths |
| **5: Code Quality** | Organization, DRY, complexity | Flag >5 branches cyclomatic complexity |
| **6: Test Review** | Coverage, pyramid, flakiness | Test type for each codepath |
| **7: Performance** | N+1 queries, memory, caching | P99 latency, connection pool analysis |
| **8: Observability** | Logging, metrics, alerting | "What tells you it's working/broken?" |
| **9: Deployment** | Migration safety, rollback | Zero-downtime, feature flags |
| **10: Long-Term** | Technical debt, reversibility | Reversibility rating 1-5 scale |
| **11: Design & UX** | User flow, AI slop risk | Required: User flow diagram (if UI) |

**CEO Cognitive Patterns (Decision Frameworks)**:

| Pattern | Application |
|---------|-------------|
| **Classification instinct** | Reversibility x magnitude (one-way vs. two-way doors) |
| **Inversion** | "How do we win?" + "What makes us fail?" |
| **Focus as subtraction** | What to NOT do |
| **Speed calibration** | 70% information is enough |
| **Leverage obsession** | Find inputs where small effort = massive output |
| **Willfulness** | "The world yields to people who push hard in one direction" |

**Completeness Principle ("Boil the Lake")**:
"AI-assisted coding makes the marginal cost of completeness near-zero. If Option A is the complete implementation and Option B is a shortcut that saves modest effort - always recommend A."

Compression ratios (human team to CC+gstack):
- Boilerplate/scaffolding: 2 days to 15 min (~100x)
- Feature implementation: 1 week to 30 min (~30x)
- Bug fix + test: 4 hours to 15 min (~20x)

**Output Artifacts**:
1. Completion Summary Table (all 11 sections with issue counts)
2. Scope Decisions (Accepted/Deferred/Skipped)
3. Error & Rescue Registry
4. Failure Modes Registry
5. NOT in scope section (explicit rejections)
6. CEO Plan Document (EXPANSION/SELECTIVE modes only)
7. 7+ Mandatory Diagrams (architecture, data flow, state machine, error flow, deployment, rollback, user flow)

---

### 1.3 /founder-retro (adapted from /retro)

**Purpose**: Team retrospective with git-based metrics and trend tracking

**What It Does**:
Collects comprehensive development metrics from git history and produces structured JSON artifacts for trend analysis.

**Metrics Collection (12 parallel git commands)**:

| Category | Metrics |
|----------|---------|
| **Commit timeline** | Hash, author, email, timestamp, subject, file changes |
| **LOC breakdown** | Test vs production (files matching `test/|spec/|__tests__/`) |
| **Session analysis** | Commits grouped by 45-minute gap threshold |
| **File hotspots** | Most frequently changed files |
| **PR extraction** | Pattern matching for `#[0-9]+` in commit subjects |
| **Per-author focus** | Author + filename pairs for area analysis |

**Session Classification**:

| Type | Duration | Meaning |
|------|----------|---------|
| **Deep sessions** | 50+ minutes | Sustained focus work |
| **Medium sessions** | 20-50 minutes | Normal context |
| **Micro sessions** | <20 minutes | Fire-and-forget fixes |

**Per-Contributor Insights**:

For each team member:
- Total commits, insertions, deletions, net LOC
- Top 3 directories touched
- Commit type mix (feat/fix/refactor/test percentages)
- Session patterns and peak hours
- Test discipline (personal test LOC ratio)
- Biggest ship (highest-impact commit/PR)

Current user gets deepest treatment with first-person analysis.

**JSON Artifact Format** (stored in `.context/retros/{YYYY-MM-DD}-{sequence}.json`):

```json
{
  "date": "2026-03-18",
  "window": "7d",
  "metrics": {
    "commits": 47,
    "contributors": 3,
    "prs_merged": 12,
    "insertions": 3200,
    "deletions": 800,
    "net_loc": 2400,
    "test_loc": 1300,
    "test_ratio": 0.41,
    "sessions": 14,
    "deep_sessions": 5,
    "avg_session_minutes": 42,
    "loc_per_session_hour": 350,
    "ai_assisted_commits": 32
  },
  "authors": { ... },
  "streak_days": 47,
  "tweetable": "..."
}
```

**Trend Tracking**:
- Loads prior retro JSON for comparison
- Shows "Last -> Now" with direction arrows
- Weekly bucket breakdown for windows >= 14 days
- Streak counting (consecutive days with >= 1 commit)

---

## Part 2: New Skill Concepts for Business Development

Based on the gstack patterns, here are designs for business-focused skills:

### 2.1 /founder-market (Market Sizing Skill)

**Purpose**: Structured market sizing analysis with TAM/SAM/SOM framework

**Inspired By**: Q1 (Demand Reality) and Q2 (Status Quo) from /office-hours, plus web research on market sizing frameworks

**Workflow Phases**:

**Phase 1: Context Gathering**
- Read any existing business documentation
- Ask: "What problem does your product solve? For whom?"

**Phase 2: TAM Analysis (Total Addressable Market)**

Forcing questions:
- "How many entities worldwide have this problem?" (push for number)
- "What's the maximum anyone would pay to solve this annually?"
- "What data sources support these numbers?" (require citations)

Approaches:
- **Top-Down**: Industry reports to market size to your segment
- **Bottom-Up**: Count real customers x pricing (VCs prefer this)
- **Value Theory**: Pain cost x frequency x affected users

**Phase 3: SAM Analysis (Serviceable Available Market)**

Forcing questions:
- "Which geographies can you actually serve today?"
- "Which segments can you NOT serve? Why?"
- "What's your realistic price point?"

**Phase 4: SOM Analysis (Serviceable Obtainable Market)**

Forcing questions:
- "What's your realistic market share in Year 1? Year 3?"
- "Who are the top 3 competitors for this exact segment?"
- "What's your capture rate assumption?" (push for 0.5-2% if early)

**Phase 5: Validation & Red Flags**

Challenge premises:
- Is TAM > $1B? (VC threshold)
- Is SOM credible (not made up $500M)?
- Is bottom-up used for SAM/SOM?

**Output Artifact**: `market-sizing-{datetime}.md`
- Concentric circles diagram (TAM > SAM > SOM)
- Data sources cited
- Competitor landscape
- Assumptions documented
- Investor-ready one-pager

---

### 2.2 /founder-model (Business Model Analysis Skill)

**Purpose**: Revenue stream valuation and business model canvas analysis

**Inspired By**: Q4 (Narrowest Wedge), Q6 (Future-Fit), CEO cognitive patterns from /plan-ceo-review

**The Nine Building Blocks** (Business Model Canvas):

| Block | Forcing Question |
|-------|------------------|
| **Customer Segments** | "Who pays? Who uses? Are they the same?" |
| **Value Propositions** | "What specific problem do you solve better than anyone?" |
| **Channels** | "How do customers find you and buy?" |
| **Customer Relationships** | "Self-service, personal, automated, or community?" |
| **Revenue Streams** | "Transaction, subscription, licensing, or freemium?" |
| **Key Resources** | "What assets are absolutely required?" |
| **Key Activities** | "What must you do exceptionally well?" |
| **Key Partnerships** | "What can others do better/cheaper?" |
| **Cost Structure** | "Fixed vs variable? Scale economics?" |

**Revenue Stream Valuation Framework**:

For each revenue stream:
1. **Revenue Type**: One-time vs recurring (MRR/ARR)
2. **Pricing Model**: Per-seat, usage-based, tiered, enterprise
3. **Unit Economics**:
   - CAC (Customer Acquisition Cost)
   - LTV (Lifetime Value)
   - LTV:CAC ratio (target: 3:1 or higher)
   - Payback period (months to recoup CAC)
4. **Revenue Quality Score** (1-10):
   - Recurring = higher
   - Predictable = higher
   - Defensible = higher

**Completeness Principle** applied:
"Evaluate ALL potential revenue streams, not just the obvious one. AI makes modeling additional streams near-zero cost."

Alternative revenue models to always consider:
- SaaS subscription transformation
- Usage-based pricing
- Platform/marketplace fees
- Data licensing
- Premium tier unbundling

**Output Artifact**: `business-model-{datetime}.md`
- Business Model Canvas (ASCII diagram)
- Revenue stream comparison table
- Unit economics for each stream
- Recommendation with rationale
- "What I noticed about your model" observations

---

### 2.3 /founder-gtm (Go-to-Market Strategy Skill)

**Purpose**: Go-to-market strategy development with positioning and channel analysis

**Inspired By**: Q3 (Desperate Specificity), Q5 (Observation & Surprise), mode selection from /plan-ceo-review

**Operational Modes**:

| Mode | Posture | When to Use |
|------|---------|-------------|
| **LAUNCH** | "Maximize splash" | New product, category creation |
| **SCALE** | "Optimize engine" | PMF achieved, scaling up |
| **PIVOT** | "Find new wedge" | Current approach not working |
| **EXPAND** | "Adjacent markets" | Core market captured |

**Phase 1: Positioning**

Forcing questions:
- "For [target customer] who [has problem], [product] is a [category] that [key benefit]. Unlike [competitor], we [differentiator]."
- Push until: specific customer, measurable benefit, named competitor

**Phase 2: Channel Analysis**

For each potential channel:
| Channel | CAC Estimate | Scalability | Time to Results |
|---------|-------------|-------------|-----------------|
| Content/SEO | | | |
| Paid acquisition | | | |
| Sales (inbound) | | | |
| Sales (outbound) | | | |
| Partnerships | | | |
| Viral/referral | | | |
| Community | | | |

Forcing questions:
- "Where do your customers already spend time?"
- "What worked for your closest competitor?"
- "What's your unfair advantage in any channel?"

**Phase 3: Launch Strategy**

Decision framework:
- **Audience size**: Do you have 1,000 true fans to start?
- **PR angle**: Is there a story journalists would tell?
- **Community**: Where do early adopters congregate?
- **Timing**: Is there a forcing function (event, trend)?

**Phase 4: Metrics & Milestones**

Define for each stage:
- **Traction metrics**: What proves PMF?
- **Efficiency metrics**: CAC, conversion rates
- **Quality metrics**: NPS, retention
- **Leading indicators**: What predicts success?

**Output Artifact**: `gtm-strategy-{datetime}.md`
- Positioning statement
- Channel prioritization (top 2-3)
- 90-day launch plan
- Key metrics dashboard template
- Risk registry with mitigations

---

### 2.4 /founder-compete (Competitive Analysis Skill)

**Purpose**: Structured competitor analysis with positioning map

**Inspired By**: Q2 (Status Quo), inversion pattern ("What makes us fail?")

**Competitive Intelligence Framework**:

**Phase 1: Landscape Mapping**

Forcing questions:
- "Who are your direct competitors?" (same problem, same solution)
- "Who are your indirect competitors?" (same problem, different solution)
- "Who are your potential competitors?" (adjacent, could enter)

**Phase 2: Per-Competitor Analysis**

For each competitor:
| Dimension | Analysis |
|-----------|----------|
| **Positioning** | How do they describe themselves? |
| **Strengths** | What do they do better than you? |
| **Weaknesses** | Where are they vulnerable? |
| **Pricing** | Model and price points |
| **Customers** | Who uses them? Why? |
| **Funding/Resources** | Runway, team size |
| **Recent moves** | Last 6 months of changes |

**Phase 3: Positioning Map**

Generate 2x2 matrix on key dimensions:
- Identify axes most relevant to your differentiation
- Plot competitors and your position
- Find "white space" opportunities

**Phase 4: Competitive Strategy**

Decision framework:
- **Attack**: Where can you win directly?
- **Defend**: Where must you match?
- **Ignore**: What battles aren't worth fighting?
- **Differentiate**: What makes you categorically different?

**Output Artifact**: `competitive-analysis-{datetime}.md`
- Competitor landscape table
- 2x2 positioning map (ASCII)
- Per-competitor battle cards
- Strategic recommendations
- "What I noticed" observations

---

## Part 3: Design Patterns for Founder Skills

### 3.1 The Forcing Question Pattern

Every business-focused skill should use forcing questions that:
1. Push for specificity over generality
2. Require evidence over assertion
3. Name real entities (people, companies, numbers)
4. Surface assumptions for challenge

**Anti-patterns to detect and push back on**:
- Category-level answers ("SMBs", "enterprises")
- Interest signals without payment/behavior
- Made-up numbers without sources
- "Everyone needs this" statements

### 3.2 The Mode-Based Operation Pattern

Provide 3-4 operational modes that give user explicit scope control:
- Each mode has a clear "posture"
- Mode selection happens early via AskUserQuestion
- All subsequent questions adapt to mode

### 3.3 The Completeness Principle Applied

For business analysis:
- Evaluate ALL revenue streams, not just the obvious one
- Map ALL competitors, not just the top 2
- Consider ALL channels, not just "what we know"
- Model ALL scenarios, not just the optimistic one

### 3.4 The Decision Framework Pattern

Borrow from CEO cognitive patterns:
- **Two-way doors**: What's reversible? Move fast.
- **One-way doors**: What's irreversible? Be rigorous.
- **Inversion**: Also ask "What makes us fail?"
- **Focus as subtraction**: Explicitly document what NOT to do

### 3.5 The Artifact Pattern

All skills should produce:
1. **Structured document** with consistent sections
2. **Diagrams** (ASCII for portability)
3. **Action item** - one concrete next step
4. **Observations** - mentor-style insights on founder's thinking

---

## Part 4: Extension Structure Recommendation

### 4.1 Proposed Founder Extension Structure

```
extensions/founder/
  manifest.json
  EXTENSION.md
  index-entries.json

  skills/
    skill-founder-hours/
      SKILL.md           # YC-style strategic guidance (Q1-Q6)
    skill-founder-review/
      SKILL.md           # CEO-level plan review (11 sections)
    skill-founder-retro/
      SKILL.md           # Metrics and retrospective
    skill-founder-market/
      SKILL.md           # TAM/SAM/SOM analysis
    skill-founder-model/
      SKILL.md           # Business model canvas
    skill-founder-gtm/
      SKILL.md           # Go-to-market strategy
    skill-founder-compete/
      SKILL.md           # Competitive analysis

  agents/
    founder-advisor-agent.md    # Routes to appropriate skill

  rules/
    founder-thinking.md         # Strategic thinking patterns

  context/
    project/
      founder/
        README.md
        domain/
          yc-principles.md      # YC startup principles
          business-frameworks.md # Canvas, TAM/SAM/SOM
        patterns/
          forcing-questions.md  # Question frameworks
          decision-making.md    # CEO cognitive patterns
        templates/
          design-doc.md         # Design document template
          market-sizing.md      # Market sizing template
          business-model.md     # Business model canvas
```

### 4.2 Implementation Priority

| Priority | Skill | Effort | Value |
|----------|-------|--------|-------|
| 1 | skill-founder-hours | 2-3 hours | Strategic guidance |
| 2 | skill-founder-market | 2-3 hours | Market sizing |
| 3 | skill-founder-model | 2-3 hours | Revenue analysis |
| 4 | skill-founder-gtm | 2 hours | Go-to-market |
| 5 | skill-founder-compete | 2 hours | Competitive intel |
| 6 | skill-founder-review | 3-4 hours | Comprehensive review |
| 7 | skill-founder-retro | 1-2 hours | Metrics tracking |

### 4.3 Skill Triggering

When to invoke each skill:

| User Says | Route To |
|-----------|----------|
| "I have an idea..." | /founder-hours (startup mode) |
| "How big is this market?" | /founder-market |
| "How should we monetize?" | /founder-model |
| "How do we launch?" | /founder-gtm |
| "Who are our competitors?" | /founder-compete |
| "Review this plan" | /founder-review |
| "How did we do this week?" | /founder-retro |

---

## Decisions

1. **Skill naming**: Use `/founder-*` prefix for all skills (consistent namespace)
2. **Output location**: Store artifacts in `~/.founder/projects/{slug}/` (mirroring gstack's `~/.gstack/`)
3. **Question style**: One question per AskUserQuestion (never batch)
4. **Mode selection**: Always offer modes early; respect user's scope intent
5. **Completeness**: Always model multiple scenarios/options

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Skills feel too heavyweight | Make mode selection optional with sensible defaults |
| Question fatigue | Allow "skip" or "I don't know" with graceful degradation |
| Business jargon alienating | Use gstack's "explain like smart 16-year-old" principle |
| Overlap with existing /research | Position founder skills as strategic analysis, not web research |

---

## References

### gstack Source Files
- [office-hours/SKILL.md](https://github.com/garrytan/gstack/blob/main/office-hours/SKILL.md)
- [plan-ceo-review/SKILL.md](https://github.com/garrytan/gstack/blob/main/plan-ceo-review/SKILL.md)
- [retro/SKILL.md](https://github.com/garrytan/gstack/blob/main/retro/SKILL.md)

### Market Sizing Frameworks
- [TAM SAM SOM Guide (CharliA)](https://www.charlia.io/en/blog/tam-sam-som-market-sizing-complete-guide)
- [Market Sizing Guide (Antler)](https://www.antler.co/blog/tam-sam-som)
- [TAM Calculation Guide (Parallel)](https://www.parallelhq.com/blog/how-to-calculate-tam)

### Business Model Resources
- [AI Business Model Canvas (Siift)](https://siift.ai/blog/ai-business-model-canvas-guide)
- [Business Model Canvas Generator (Creately)](https://creately.com/lp/business-model-canvas-generator/)

---

## Next Steps

1. Run `/plan 233` to create implementation plan for the founder extension
2. Start with skill-founder-hours (most direct gstack adaptation)
3. Add skill-founder-market and skill-founder-model (highest business value)
4. Iterate based on usage
